-- sv_event_menu.lua — Server side of the Event Admin Menu
-- Handles all net receives and executes actions on players.
-- Default loadout presets are defined below. Superadmins can add, edit, and
-- delete presets in-game; changes are saved to data/zc_event_loadouts.json
-- and loaded automatically on server start, overriding the defaults.

if CLIENT then return end

local function EventLog(msg)
    if ulx and ulx.logString then
        ulx.logString(msg)
        return
    end

    print("[ZC EventMenu] " .. tostring(msg))
end

-- ── Default loadout presets ───────────────────────────────────────────────────
-- These ship with the addon. Superadmins can override/extend them in-game.
-- In-game changes are written to data/zc_event_loadouts.json and take
-- precedence over this table on next load.

-- ── Default loadout presets ───────────────────────────────────────────────────
-- Each preset: { weapons = { ... }, group = "GroupName", armor = { torso=..., head=..., ears=..., face=... } }
-- armor values are either a plain key string ("vest1") or a random variable
-- ({"$random","vest1","vest2"}) — resolved the same way weapons are.
-- Omit a slot entirely to leave it unchanged on the player.

local DEFAULT_LOADOUTS = {
    ["Rebel Assault"] = {
        group = "Rebel",
        weapons = {
            "weapon_ak74",
            "weapon_glock17",
            "weapon_bandage_sh",
            "weapon_hg_grenade_tpik",
        },
    },
    ["Rebel Medic"] = {
        group = "Rebel",
        weapons = {
            "weapon_mp5",
            "weapon_glock17",
            "weapon_medkit_sh",
            "weapon_bandage_sh",
            "weapon_morphine",
        },
    },
    ["Rebel Sniper"] = {
        group = "Rebel",
        weapons = {
            "weapon_mosin",
            "weapon_makarov",
            "weapon_bandage_sh",
        },
    },
    ["Rebel Grenadier"] = {
        group = "Rebel",
        weapons = {
            "weapon_m4a1",
            "weapon_deagle",
            "weapon_hg_grenade_tpik",
            "weapon_hg_grenade_tpik",
            "weapon_hg_smokenade_tpik",
            "weapon_bandage_sh",
        },
    },
    ["Combine Soldier"] = {
        group = "Combine",
        weapons = {
            "weapon_ar2",
            "weapon_pistol",
            "weapon_frag",
        },
    },
    ["Combine Elite"] = {
        group = "Combine",
        weapons = {
            "weapon_ar2",
            "weapon_pistol",
            "weapon_frag",
            "weapon_frag",
        },
    },
    ["Metropolice"] = {
        group = "Metrocop",
        weapons = {
            "weapon_smg1",
            "weapon_pistol",
        },
    },
    ["Light Pistol"] = {
        group = "",
        weapons = {
            "weapon_glock17",
            "weapon_bandage_sh",
        },
    },
    ["Unarmed"] = {
        group = "",
        weapons = {},
    },
}

-- ── Persistence ───────────────────────────────────────────────────────────────

local SAVE_PATH = "zc_event_loadouts.json"

local function SaveLoadouts()
    -- Serialise ZC_EventLoadouts to JSON and write to the data folder.
    -- util.TableToJSON produces a flat object: { "Name": ["class1", ...], ... }
    local ok, result = pcall(util.TableToJSON, ZC_EventLoadouts, true)
    if not ok then
        print("[ZC EventMenu] Failed to serialise loadouts: " .. tostring(result))
        return
    end
    file.Write(SAVE_PATH, result)
    print("[ZC EventMenu] Loadouts saved to data/" .. SAVE_PATH)
end

local function LoadLoadouts()
    ZC_EventLoadouts = {}
    for name, preset in pairs(DEFAULT_LOADOUTS) do
        ZC_EventLoadouts[name] = {
            group   = preset.group,
            weapons = table.Copy(preset.weapons),
            armor   = table.Copy(preset.armor or {}),
        }
    end

    if not file.Exists(SAVE_PATH, "DATA") then return end
    local raw = file.Read(SAVE_PATH, "DATA")
    if not raw or raw == "" then return end

    local ok, saved = pcall(util.JSONToTable, raw)
    if not ok or type(saved) ~= "table" then
        print("[ZC EventMenu] Could not parse " .. SAVE_PATH .. " — using defaults.")
        return
    end

    for name, data in pairs(saved) do
        if type(data) == "table" then
            if data.weapons then
                -- New format: { group, weapons, armor }
                ZC_EventLoadouts[name] = {
                    group   = type(data.group) == "string" and data.group or "",
                    weapons = data.weapons,
                    armor   = type(data.armor) == "table" and data.armor or {},
                }
            else
                -- Old flat array format — migrate with empty group and no armor
                ZC_EventLoadouts[name] = { group = "", weapons = data, armor = {} }
            end
        end
    end
    print("[ZC EventMenu] Loaded " .. table.Count(ZC_EventLoadouts) .. " loadout presets.")
end

LoadLoadouts()

-- ── Network strings ───────────────────────────────────────────────────────────

util.AddNetworkString("ZC_EventMenu_Open")
util.AddNetworkString("ZC_EventMenu_LoadoutList")
util.AddNetworkString("ZC_EventMenu_PlayerList")
util.AddNetworkString("ZC_EventMenu_Action")
util.AddNetworkString("ZC_EventMenu_Feedback")
util.AddNetworkString("ZC_EventMenu_LoadoutEdit")   -- superadmin → server: edit request
util.AddNetworkString("ZC_EventMenu_LoadoutSaved")  -- server → client: confirm + push new list
util.AddNetworkString("ZC_EventMenu_ClassEdit")     -- superadmin → server: add/remove class
util.AddNetworkString("ZC_EventMenu_ClassList")     -- server → client: current class list
util.AddNetworkString("ZC_EventMenu_EventState")    -- server → client: current event state (0=standby,1=prep,2=live)
util.AddNetworkString("ZC_EventMenu_OpenRebelLoadoutEditor") -- server → client: open Rebel-only loadout editor

-- ── Event state ───────────────────────────────────────────────────────────────
-- 0 = STANDBY  — not in event gamemode, or event gamemode loaded but not started
-- 1 = PREP     — event gamemode just fired, godmode ON, AI OFF (waiting for admin)
-- 2 = LIVE     — event_start pressed, godmode OFF, AI ON

ZC_EventRunning = ZC_EventRunning or false  -- kept for backwards compat
ZC_EventState   = ZC_EventState   or 0      -- 0/1/2

local function BroadcastEventState()
    net.Start("ZC_EventMenu_EventState")
        net.WriteUInt(ZC_EventState, 2)
    net.Broadcast()
end

-- Full server cleanup: remove props, ragdolls, corpses, fires, grenades, etc.
local function EventCleanup()
    -- Stand up any ragdolled players before removing prop_ragdolls.
    -- If a player's FakeRagdoll entity gets removed while org.otrub is still
    -- true, ZCity loses the ragdoll reference but the organism stays downed —
    -- the player is permanently stuck unable to ragdoll or unragdoll.
    -- This happens when e.g. a strider explosion ragdolls a player and an admin
    -- hits event_stop before they are revived.
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end
        if IsValid(ply.FakeRagdoll) then
            if hg and hg.FakeUp then hg.FakeUp(ply, true, true) end
        elseif ply.organism and (ply.organism.otrub or ply.organism.needfake or ply.organism.needotrub) then
            -- Organism thinks player is downed but no ragdoll entity exists — clear the state
            ply.organism.otrub     = false
            ply.organism.needotrub = false
            ply.organism.needfake  = false
        end
    end

    local removeClasses = {
        -- Ragdolls / corpses
        "prop_ragdoll",
        -- Fires
        "env_fire", "entityflame",
        -- Grenades and explosive projectiles
        "npc_grenade_frag", "grenade_ar2", "npc_manhack",
        "env_explosion",
        -- Smoke / effects
        "env_smokestack",
        -- Misc loose props that pile up during events
        "prop_physics",
    }
    local removed = 0
    for _, class in ipairs(removeClasses) do
        for _, ent in ipairs(ents.FindByClass(class)) do
            if IsValid(ent) then
                ent:Remove()
                removed = removed + 1
            end
        end
    end
    -- Remove all NPCs except bullseyes
    for _, npc in ipairs(ents.GetAll()) do
        if not IsValid(npc) then continue end
        if not npc:IsNPC() then continue end
        if npc:GetClass() == "npc_bullseye" then continue end
        npc:Remove()
        removed = removed + 1
    end
    print("[ZC Event] Cleanup removed " .. removed .. " entities.")
end

-- Apply godmode state and heal everyone
local function ApplyGodmodeToAll(enabled)
    ZC_OrgGodMode = enabled
    if enabled then
        -- Heal all alive players back to full
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:Alive() then continue end
            if ply.organism then hg.organism.Clear(ply.organism) end
            ply:SetHealth(100)
        end
    end
end

-- On round/gamemode start: only apply event-menu state when actually in the Event gamemode.
-- In every other gamemode (coop, homicide, defense, etc.) do nothing — let ZCity run normally.
local function OnRoundStart()
    local mode = zb and zb.CROUND
    if mode ~= "event" then return end

    -- Event gamemode loaded — enter PREP state: godmode ON, waiting for admin
    ZC_EventRunning = false
    ZC_EventState   = 1
    ApplyGodmodeToAll(true)
    BroadcastEventState()
    print("[ZC Event] Event gamemode started — PREP state (godmode ON).")
end

hook.Add("ZB_PreRoundStart", "ZC_EventMenu_RoundStartState", OnRoundStart)
hook.Add("PostCleanupMap",   "ZC_EventMenu_MapStartState",   OnRoundStart)
hook.Add("InitPostEntity",   "ZC_EventMenu_InitState", function()
    timer.Simple(2, OnRoundStart)
end)

-- ── Helpers ───────────────────────────────────────────────────────────────────

local TEAM_ROLES = {
    { name = "Alpha",   color = Color(220, 60,  60)  },
    { name = "Bravo",   color = Color(60,  120, 220) },
    { name = "Charlie", color = Color(60,  200, 60)  },
    { name = "Delta",   color = Color(220, 160, 0)   },
}
local TEAM_NUMBER_MAP = { [1]="Alpha", [2]="Bravo", [3]="Charlie", [4]="Delta" }

-- Persistent team assignments (reset on round/map change)
ZC_EventPlayerTeams = ZC_EventPlayerTeams or {}

hook.Add("PostCleanupMap",   "ZC_EventMenu_TeamReset", function() ZC_EventPlayerTeams = {} end)
hook.Add("ZB_PreRoundStart", "ZC_EventMenu_TeamReset", function() ZC_EventPlayerTeams = {} end)
hook.Add("PlayerDisconnected", "ZC_EventMenu_TeamReset", function(ply)
    ZC_EventPlayerTeams[ply:SteamID64()] = nil
end)

local function Feedback(admin, msg)
    net.Start("ZC_EventMenu_Feedback")
        net.WriteString(msg)
    net.Send(admin)
end

local function ResetOrganism(ply)
    if not IsValid(ply) or not ply:Alive() then return false end
    if not ply.organism then return false end
    hg.organism.Clear(ply.organism)
    if ply.organism.otrub and hg.FakeUp then hg.FakeUp(ply, true) end
    return true
end

local function TrimClassToken(value)
    return string.Trim(tostring(value or ""))
end

local function ResolveCanonicalEventClassName(className)
    local requested = TrimClassToken(className)
    if requested == "" then return nil end

    local requestedLower = string.lower(requested)

    if istable(player and player.classList) then
        for existing in pairs(player.classList) do
            if string.lower(existing) == requestedLower then
                return existing
            end
        end
    end

    for _, existing in ipairs(ZC_EventClasses or {}) do
        local name = tostring(existing)
        if string.lower(name) == requestedLower then
            return name
        end
    end

    return requested
end

local function IsRegisteredPlayerClass(className)
    if not isstring(className) or className == "" then return false end

    if istable(player and player.classList) and player.classList[className] then
        return true
    end

    if istable(player and player.classList) then
        local want = string.lower(className)
        for existing in pairs(player.classList) do
            if string.lower(existing) == want then
                return true
            end
        end
    end

    return false
end

local function SetClassInPlace(ply, class)
    if not IsValid(ply) then return end

    local canonical = ResolveCanonicalEventClassName(class)
    if not canonical then return end

    local function applyWithRetry(attempt)
        if not IsValid(ply) then return end

        if not IsRegisteredPlayerClass(canonical) then
            if attempt < 10 then
                timer.Simple(0.25, function()
                    applyWithRetry(attempt + 1)
                end)
            else
                print("[ZC EventMenu] WARNING: class '" .. tostring(canonical) .. "' is not registered for " .. tostring(ply:Nick()))
            end
            return
        end

        if ply:Alive() then
            local pos = ply:GetPos()
            local ang = ply:GetAngles()
            ply.gottarespawn = true
            ply:Spawn()
            timer.Simple(0, function()
                if not IsValid(ply) then return end
                ply:SetPos(pos)
                ply:SetEyeAngles(ang)
                ply:SetPlayerClass(canonical)
                ply:Give("weapon_hands_sh")
                ply:SelectWeapon("weapon_hands_sh")
            end)
        else
            ply:SetPlayerClass(canonical)
        end
    end

    applyWithRetry(0)
end

local ARMOR_SLOTS = { "torso", "head", "ears", "face" }

local function ResolveRandom(entry)
    if type(entry) == "table" and entry[1] == "$random" and #entry >= 2 then
        return entry[math.random(2, #entry)]
    end
    return entry
end

local function ApplyLoadoutPreset(ply, presetName)
    if not IsValid(ply) then return false end
    local preset = ZC_EventLoadouts[presetName]
    if not preset then return false end
    local weapons = preset.weapons or preset
    local armor   = preset.armor or {}

    ply:SetSuppressPickupNotices(true)
    ply.noSound = true

    -- Strip weapons
    ply:StripWeapons()
    local inv = ply:GetNetVar("Inventory", {})
    inv["Weapons"] = { ["hg_sling"] = true, ["hg_flashlight"] = true }
    ply:SetNetVar("Inventory", inv)

    -- Strip existing armor from all slots
    if ply.armors then
        for _, slot in ipairs(ARMOR_SLOTS) do
            if ply.armors[slot] then
                pcall(function() hg.DropArmorForce(ply, slot) end)
            end
        end
    end

    -- Give weapons
    for _, entry in ipairs(weapons) do
        local wclass = ResolveRandom(entry)
        if type(wclass) == "string" and wclass ~= "" then
            ply:Give(wclass)
        end
    end
    ply:Give("weapon_hands_sh")
    ply:SelectWeapon("weapon_hands_sh")

    -- Apply armor
    local hasArmor = false
    for _, slot in ipairs(ARMOR_SLOTS) do
        local entry = armor[slot]
        if entry then
            local key = ResolveRandom(entry)
            if type(key) == "string" and key ~= "" then
                pcall(function() hg.AddArmor(ply, key) end)
                hasArmor = true
            end
        end
    end
    if hasArmor then
        pcall(function() ply:SyncArmor() end)
    end

    timer.Simple(0.1, function()
        if IsValid(ply) then
            ply.noSound = false
            ply:SetSuppressPickupNotices(false)
        end
    end)
    return true
end

local function NormalizeGroupToken(token)
    return string.lower(string.Trim(tostring(token or "")))
end

local function BuildPresetPoolForGroups(groups, includeUniversal)
    local groupSet = {}
    local exact = {}
    local universal = {}

    if istable(groups) then
        for _, g in ipairs(groups) do
            local clean = NormalizeGroupToken(g)
            if clean ~= "" then groupSet[clean] = true end
        end
    end

    for name, preset in pairs(ZC_EventLoadouts or {}) do
        local g = NormalizeGroupToken(preset and preset.group or "")
        if g ~= "" and groupSet[g] then
            exact[#exact + 1] = name
        elseif includeUniversal and g == "" then
            universal[#universal + 1] = name
        end
    end

    if #exact > 0 then return exact end
    return universal
end

function ZC_ApplyRandomEventLoadoutForGroups(ply, groups, includeUniversal)
    if not IsValid(ply) then return false, nil end

    local pool = BuildPresetPoolForGroups(groups, includeUniversal == true)
    if #pool <= 0 then return false, nil end

    local presetName = pool[math.random(#pool)]
    if not presetName then return false, nil end

    if ApplyLoadoutPreset(ply, presetName) then
        return true, presetName
    end

    return false, nil
end

-- ── Send current player list to admin ─────────────────────────────────────────

local function SendPlayerList(admin)
    local players = {}
    for _, ply in ipairs(player.GetAll()) do
        if ply:IsBot() then continue end
        table.insert(players, ply)
    end

    net.Start("ZC_EventMenu_PlayerList")
        net.WriteUInt(#players, 8)
        for _, ply in ipairs(players) do
            net.WriteString(ply:Nick())
            net.WriteString(ply:SteamID64())
            net.WriteString(ply.PlayerClassName or "")
            net.WriteString(ZC_EventPlayerTeams[ply:SteamID64()] or "")
            net.WriteBool(ply:Alive())
            net.WriteBool(ply:Team() == TEAM_SPECTATOR)
        end
    net.Send(admin)
end

-- ── Class list ────────────────────────────────────────────────────────────────
-- Persisted to data/zc_event_classes.json. Defaults are the five base classes;
-- superadmins can add/remove entries in-game.

local CLASS_SAVE_PATH    = "zc_event_classes.json"
local DEFAULT_CLASSES    = { "Rebel", "Refugee", "Gordon", "Combine", "Metrocop" }

ZC_EventClasses = {}

local function BuildMergedEventClassList(saved)
    local out = {}
    local seen = {}

    local function addOne(name)
        name = TrimClassToken(name)
        if name == "" then return end

        local key = string.lower(name)
        if seen[key] then return end

        seen[key] = true
        out[#out + 1] = name
    end

    for _, name in ipairs(DEFAULT_CLASSES) do
        addOne(name)
    end

    if istable(saved) then
        for _, name in ipairs(saved) do
            addOne(name)
        end
    end

    if istable(player and player.classList) then
        for name in pairs(player.classList) do
            addOne(name)
        end
    end

    table.sort(out, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return out
end

local function SyncEventClassesFromRegistry(reason)
    local before = #ZC_EventClasses
    ZC_EventClasses = BuildMergedEventClassList(ZC_EventClasses)

    if #ZC_EventClasses > before then
        print("[ZC EventMenu] Synced class list from registry (" .. before .. " -> " .. #ZC_EventClasses .. ")" .. (reason and (" [" .. reason .. "]") or ""))
        return true
    end

    return false
end

local function SaveClasses()
    local ok, result = pcall(util.TableToJSON, ZC_EventClasses, true)
    if not ok then print("[ZC EventMenu] Failed to save classes: " .. tostring(result)); return end
    file.Write(CLASS_SAVE_PATH, result)
end

local function LoadClasses()
    ZC_EventClasses = table.Copy(DEFAULT_CLASSES)
    if not file.Exists(CLASS_SAVE_PATH, "DATA") then
        ZC_EventClasses = BuildMergedEventClassList(ZC_EventClasses)
        SaveClasses()
        return
    end

    local raw = file.Read(CLASS_SAVE_PATH, "DATA")
    if raw and raw ~= "" then
        local ok, saved = pcall(util.JSONToTable, raw)
        if ok and type(saved) == "table" then
            ZC_EventClasses = saved
        end
    end

    ZC_EventClasses = BuildMergedEventClassList(ZC_EventClasses)
    SaveClasses()
    print("[ZC EventMenu] Loaded " .. #ZC_EventClasses .. " class options.")
end

LoadClasses()

local function SendClassList(admin)
    net.Start("ZC_EventMenu_ClassList")
        net.WriteUInt(#ZC_EventClasses, 8)
        for _, cls in ipairs(ZC_EventClasses) do net.WriteString(cls) end
    net.Send(admin)
end

local function PushClassListToAdmins()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:IsAdmin() then SendClassList(ply) end
    end
end

local function StartupSyncEventClasses(reason)
    if not SyncEventClassesFromRegistry(reason) then return end
    SaveClasses()
    PushClassListToAdmins()
end

local function ScheduleStartupClassSync(reason)
    local timerName = "ZC_EventMenu_ClassSync_" .. tostring(reason or "runtime")
    timer.Create(timerName, 0.5, 10, function()
        local changed = SyncEventClassesFromRegistry(reason)

        if changed then
            SaveClasses()
            PushClassListToAdmins()
        end

        if istable(player and player.classList) and table.Count(player.classList) > 0 then
            timer.Remove(timerName)
        end
    end)
end

hook.Add("InitPostEntity", "ZC_EventMenu_ClassSyncInit", function()
    StartupSyncEventClasses("init")
    ScheduleStartupClassSync("init")
end)

hook.Add("PostCleanupMap", "ZC_EventMenu_ClassSyncMapStart", function()
    timer.Simple(0.25, function()
        StartupSyncEventClasses("mapstart")
        ScheduleStartupClassSync("mapstart")
    end)
end)

hook.Add("ZB_PreRoundStart", "ZC_EventMenu_ClassSyncRoundStart", function()
    timer.Simple(0.25, function()
        StartupSyncEventClasses("roundstart")
    end)
end)

-- ── Send loadout list to admin ────────────────────────────────────────────────

local function EncodeRandomEntry(entry)
    if type(entry) == "table" and entry[1] == "$random" then
        local choices = {}
        for i = 2, #entry do table.insert(choices, entry[i]) end
        return "$random:" .. table.concat(choices, ",")
    end
    return tostring(entry)
end

local function SendLoadoutList(admin)
    local names = {}
    for name, _ in pairs(ZC_EventLoadouts) do table.insert(names, name) end
    table.sort(names)

    net.Start("ZC_EventMenu_LoadoutList")
        net.WriteUInt(#names, 8)
        for _, name in ipairs(names) do
            local preset = ZC_EventLoadouts[name]
            local weps   = preset.weapons or preset
            local armor  = preset.armor or {}
            net.WriteString(name)
            net.WriteString(preset.group or "")
            -- Weapons
            net.WriteUInt(#weps, 8)
            for _, entry in ipairs(weps) do
                net.WriteString(EncodeRandomEntry(entry))
            end
            -- Armor (4 slots: torso, head, ears, face)
            for _, slot in ipairs(ARMOR_SLOTS) do
                local entry = armor[slot]
                if entry then
                    net.WriteString(EncodeRandomEntry(entry))
                else
                    net.WriteString("")  -- empty = no armor for this slot
                end
            end
        end
    net.Send(admin)
end

-- ── Open menu request ─────────────────────────────────────────────────────────

local function OpenEventMenuFor(admin)
    if not IsValid(admin) or not admin:IsAdmin() then return end

    SendPlayerList(admin)
    SendLoadoutList(admin)
    SendClassList(admin)

    net.Start("ZC_EventMenu_EventState")
        net.WriteUInt(ZC_EventState, 2)
    net.Send(admin)

    net.Start("ZC_EventMenu_Open")
    net.Send(admin)
end

-- Exposed globally so the ULX module can call it directly without the bounce
ZC_OpenEventMenuFor = OpenEventMenuFor

local function OpenRebelLoadoutEditorFor(admin)
    if not IsValid(admin) or not admin:IsAdmin() then return end

    SendLoadoutList(admin)
    SendClassList(admin)

    net.Start("ZC_EventMenu_OpenRebelLoadoutEditor")
    net.Send(admin)
end

-- Exposed globally so the ULX module can open the Rebel-only loadout editor.
ZC_OpenRebelLoadoutEditorFor = OpenRebelLoadoutEditorFor

net.Receive("ZC_EventMenu_Open", function(len, admin)
    if not IsValid(admin) then return end
    if not admin:IsAdmin() then return end
    OpenEventMenuFor(admin)
end)

-- ── Class editor (superadmin only) ────────────────────────────────────────────

net.Receive("ZC_EventMenu_ClassEdit", function(len, admin)
    if not IsValid(admin) then return end
    if not admin:IsAdmin() then Feedback(admin, "Class editing requires Admin."); return end

    local op  = net.ReadString()
    local arg = string.Trim(net.ReadString())

    if op == "add" then
        if arg == "" then Feedback(admin, "Class name cannot be empty."); return end
        for _, cls in ipairs(ZC_EventClasses) do
            if string.lower(cls) == string.lower(arg) then
                Feedback(admin, "Class '" .. arg .. "' already in list."); return
            end
        end
        table.insert(ZC_EventClasses, arg)
        SaveClasses()
        PushClassListToAdmins()
        EventLog(admin:Nick() .. " added class to event menu: " .. arg)

    elseif op == "remove" then
        local idx = tonumber(arg)
        if not idx or not ZC_EventClasses[idx] then Feedback(admin, "Invalid class index."); return end
        local removed = ZC_EventClasses[idx]
        table.remove(ZC_EventClasses, idx)
        SaveClasses()
        PushClassListToAdmins()
        EventLog(admin:Nick() .. " removed class from event menu: " .. removed)
    end
end)

-- ── Action dispatcher ─────────────────────────────────────────────────────────

net.Receive("ZC_EventMenu_Action", function(len, admin)
    if not IsValid(admin) then return end
    if not admin:IsAdmin() then return end

    local action  = net.ReadString()
    local steamid = net.ReadString()   -- may be "" for broadcast actions
    local arg     = net.ReadString()   -- class name, loadout name, role name, team count, etc.

    -- Resolve target player(s)
    local function FindBySteamID(sid)
        for _, ply in ipairs(player.GetAll()) do
            if ply:SteamID64() == sid then return ply end
        end
    end

    local target = steamid ~= "" and FindBySteamID(steamid) or nil

    -- ── Per-player actions ─────────────────────────────────────────────────────

    if action == "setclass" then
        if not IsValid(target) then Feedback(admin, "Player not found."); return end
        SetClassInPlace(target, arg)
        target:ChatPrint("[Event] Your class has been set to: " .. arg)
        Feedback(admin, target:Nick() .. " → class: " .. arg)
        EventLog(admin:Nick() .. " set class of " .. target:Nick() .. " to " .. arg)

    elseif action == "loadout" then
        if not IsValid(target) then Feedback(admin, "Player not found."); return end
        if not ApplyLoadoutPreset(target, arg) then
            Feedback(admin, "Unknown loadout preset: " .. arg)
            return
        end
        target:ChatPrint("[Event] You received loadout: " .. arg)
        Feedback(admin, target:Nick() .. " → loadout: " .. arg)
        EventLog(admin:Nick() .. " gave loadout '" .. arg .. "' to " .. target:Nick())

    elseif action == "loadout_all" then
        -- arg = preset name; applies to all non-spectator non-bot players
        local count = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:IsBot() then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end
            if ApplyLoadoutPreset(ply, arg) then
                ply:ChatPrint("[Event] You received loadout: " .. arg)
                count = count + 1
            end
        end
        PrintMessage(HUD_PRINTTALK, "[Event] Loadout '" .. arg .. "' given to " .. count .. " players by " .. admin:Nick())
        EventLog(admin:Nick() .. " gave loadout '" .. arg .. "' to all (" .. count .. ")")

    elseif action == "loadout_team" then
        -- arg = "TeamName|PresetName"
        local teamName, presetName = string.match(arg, "^(.+)|(.+)$")
        if not teamName or not presetName then Feedback(admin, "Bad loadout_team arg."); return end
        local count = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:IsBot() then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end
            if ZC_EventPlayerTeams[ply:SteamID64()] == teamName then
                if ApplyLoadoutPreset(ply, presetName) then
                    ply:ChatPrint("[Event] You received loadout: " .. presetName)
                    count = count + 1
                end
            end
        end
        Feedback(admin, "Loadout '" .. presetName .. "' → Team " .. teamName .. " (" .. count .. " players)")
        EventLog(admin:Nick() .. " gave loadout '" .. presetName .. "' to Team " .. teamName .. " (" .. count .. ")")

    elseif action == "setrole" then
        if not IsValid(target) then Feedback(admin, "Player not found."); return end
        zb.GiveRole(target, arg, Color(190, 15, 15))
        target:ChatPrint("[Event] Your role has been set to: " .. arg)
        Feedback(admin, target:Nick() .. " → role: " .. arg)
        EventLog(admin:Nick() .. " set role of " .. target:Nick() .. " to " .. arg)

    elseif action == "healplayer" then
        if not IsValid(target) then Feedback(admin, "Player not found."); return end
        if not ResetOrganism(target) then
            Feedback(admin, target:Nick() .. " is not alive or has no organism.")
            return
        end
        target:ChatPrint("[Event] Your health has been fully restored.")
        Feedback(admin, target:Nick() .. " → organism reset")
        EventLog(admin:Nick() .. " reset organism for " .. target:Nick())

    elseif action == "healall" then
        local count = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:IsBot() then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end
            if ResetOrganism(ply) then count = count + 1 end
        end
        PrintMessage(HUD_PRINTTALK, "[Event] " .. admin:Nick() .. " healed all players (" .. count .. ")")
        EventLog(admin:Nick() .. " healed all players (" .. count .. ")")

    elseif action == "resetplayer" then
        if not IsValid(target) then Feedback(admin, "Player not found."); return end
        local pos = target:GetPos()
        local ang = target:GetAngles()
        target:Spawn()
        timer.Simple(0.1, function()
            if not IsValid(target) then return end
            target:SetPos(pos)
            target:SetEyeAngles(ang)
            ResetOrganism(target)
        end)
        target:ChatPrint("[Event] You have been fully reset.")
        Feedback(admin, target:Nick() .. " → full reset")
        EventLog(admin:Nick() .. " applied full reset to " .. target:Nick())

    elseif action == "resetall" then
        local count = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:IsBot() then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end
            if not ply:Alive() then continue end
            if ResetOrganism(ply) then count = count + 1 end
        end
        PrintMessage(HUD_PRINTTALK, "[Event] " .. admin:Nick() .. " reset all organisms (" .. count .. ")")
        EventLog(admin:Nick() .. " reset all organisms (" .. count .. ")")

    elseif action == "unragdoll" then
        local function DoUnragdoll(ply)
            if not IsValid(ply) or not ply:Alive() then return false end
            if not IsValid(ply.FakeRagdoll) then return false end
            if hg and hg.FakeUp then hg.FakeUp(ply, true, true) end
            return true
        end
        if IsValid(target) then
            if DoUnragdoll(target) then
                target:ChatPrint("[Event] You were forced upright by " .. admin:Nick())
                Feedback(admin, target:Nick() .. " → un-ragdolled")
            else
                Feedback(admin, target:Nick() .. " is not ragdolled.")
            end
            EventLog(admin:Nick() .. " force un-ragdolled " .. target:Nick())
        else
            local count = 0
            for _, ply in ipairs(player.GetAll()) do
                if not ply:IsBot() and DoUnragdoll(ply) then count = count + 1 end
            end
            Feedback(admin, "Un-ragdolled " .. count .. " player(s)")
            EventLog(admin:Nick() .. " force un-ragdolled all (" .. count .. ")")
        end

    elseif action == "tphere" then
        if not IsValid(target) then Feedback(admin, "Player not found."); return end
        -- Force un-ragdoll first so the position change actually sticks
        if IsValid(target.FakeRagdoll) and hg and hg.FakeUp then
            hg.FakeUp(target, true, true)
        end
        local pos = admin:GetPos()
        local ang = admin:GetAngles()
        local offset = Vector(math.Rand(-60, 60), math.Rand(-60, 60), 0)
        -- Small delay so FakeUp's spawn cycle completes before we reposition
        timer.Simple(0.15, function()
            if not IsValid(target) then return end
            target:SetPos(pos + offset)
            target:SetEyeAngles(ang)
            target:SetLocalVelocity(Vector(0, 0, 0))
        end)
        target:ChatPrint("[Event] You were teleported to " .. admin:Nick())
        Feedback(admin, target:Nick() .. " → teleported to you")
        EventLog(admin:Nick() .. " teleported " .. target:Nick() .. " to themselves")

    elseif action == "tpteam" then
        -- arg = team name; teleports that team to admin
        local adminPos = admin:GetPos()
        local adminAng = admin:GetAngles()
        local moved = {}
        for i, ply in ipairs(player.GetAll()) do
            if ply:IsBot() then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end
            if ZC_EventPlayerTeams[ply:SteamID64()] ~= arg then continue end
            -- Un-ragdoll first
            if IsValid(ply.FakeRagdoll) and hg and hg.FakeUp then
                hg.FakeUp(ply, true, true)
            end
            local angle  = #moved * (360 / 8)
            local dist   = 60 + math.floor(#moved / 8) * 60
            local offset = Vector(math.cos(math.rad(angle)) * dist, math.sin(math.rad(angle)) * dist, 0)
            local p = ply
            local finalPos = adminPos + offset
            timer.Simple(0.15, function()
                if not IsValid(p) then return end
                p:SetPos(finalPos)
                p:SetEyeAngles(adminAng)
                p:SetLocalVelocity(Vector(0, 0, 0))
            end)
            ply:ChatPrint("[Event] Your team was teleported.")
            table.insert(moved, ply:Nick())
        end
        Feedback(admin, "Teleported Team " .. arg .. " (" .. #moved .. " players)")
        EventLog(admin:Nick() .. " teleported Team " .. arg .. " to themselves")

    elseif action == "split" then
        -- arg = number of teams as string
        local numTeams = math.Clamp(tonumber(arg) or 2, 2, 4)
        local players = {}
        for _, ply in ipairs(player.GetAll()) do
            if ply:IsBot() then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end
            table.insert(players, ply)
        end
        if #players == 0 then Feedback(admin, "No eligible players to split."); return end

        -- Shuffle
        for i = #players, 2, -1 do
            local j = math.random(i)
            players[i], players[j] = players[j], players[i]
        end

        local teams = {}
        for i = 1, numTeams do teams[i] = {} end
        for i, ply in ipairs(players) do
            table.insert(teams[((i-1) % numTeams) + 1], ply)
        end

        ZC_EventPlayerTeams = {}
        for t, members in ipairs(teams) do
            local role = TEAM_ROLES[t]
            for _, ply in ipairs(members) do
                ZC_EventPlayerTeams[ply:SteamID64()] = role.name
                zb.GiveRole(ply, "Team " .. role.name, role.color)
            end
        end

        PrintMessage(HUD_PRINTTALK, "[Event] Players split into " .. numTeams .. " teams by " .. admin:Nick())
        for t, members in ipairs(teams) do
            local names = {}
            for _, ply in ipairs(members) do table.insert(names, ply:Nick()) end
            PrintMessage(HUD_PRINTTALK, "  Team " .. TEAM_ROLES[t].name .. ": " .. table.concat(names, ", "))
        end
        EventLog(admin:Nick() .. " split players into " .. numTeams .. " teams")

        -- Refresh the menu with updated team assignments
        SendPlayerList(admin)

    elseif action == "setclass_team" then
        -- arg = "TeamName|ClassName"
        local teamName, className = string.match(arg, "^(.+)|(.+)$")
        if not teamName or not className then Feedback(admin, "Bad setclass_team arg."); return end
        local count = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:IsBot() then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end
            if ZC_EventPlayerTeams[ply:SteamID64()] == teamName then
                SetClassInPlace(ply, className)
                ply:ChatPrint("[Event] Your class has been set to: " .. className)
                count = count + 1
            end
        end
        Feedback(admin, "Class '" .. className .. "' → Team " .. teamName .. " (" .. count .. " players)")
        EventLog(admin:Nick() .. " set class of Team " .. teamName .. " to " .. className .. " (" .. count .. ")")

    elseif action == "frespawn" then
        -- Force respawn: single player or all
        local function DoRespawn(ply)
            if not IsValid(ply) then return end
            ply.gottarespawn = true
            ply:Spawn()
            if hg and hg.Appearance and hg.Appearance.ForceApplyAppearance and ply.CurAppearance then
                timer.Simple(0.1, function()
                    if IsValid(ply) then hg.Appearance.ForceApplyAppearance(ply, ply.CurAppearance) end
                end)
            end
            local hands = ply:Give("weapon_hands_sh")
            if IsValid(hands) then ply:SelectWeapon("weapon_hands_sh") end
        end

        if IsValid(target) then
            DoRespawn(target)
            target:ChatPrint("[Event] You were force respawned by " .. admin:Nick())
            Feedback(admin, target:Nick() .. " → force respawned")
            EventLog(admin:Nick() .. " force respawned " .. target:Nick())
        else
            local count = 0
            for _, ply in ipairs(player.GetAll()) do
                if ply:IsBot() then continue end
                if ply:Team() == TEAM_SPECTATOR then continue end
                DoRespawn(ply)
                count = count + 1
            end
            PrintMessage(HUD_PRINTTALK, "[Event] " .. admin:Nick() .. " force respawned all players (" .. count .. ")")
            EventLog(admin:Nick() .. " force respawned all players (" .. count .. ")")
        end

    elseif action == "event_start" then
        if ZC_EventRunning then Feedback(admin, "Event already running."); return end
        ZC_EventRunning = true
        ZC_EventState   = 2
        ApplyGodmodeToAll(false)
        BroadcastEventState()
        PrintMessage(HUD_PRINTTALK, "[Event] Event started by " .. admin:Nick() .. " — godmode disabled.")
        EventLog(admin:Nick() .. " started the event (godmode off)")

    elseif action == "event_stop" then
        if not ZC_EventRunning then Feedback(admin, "No event is running."); return end
        ZC_EventRunning = false
        ZC_EventState   = 1
        ApplyGodmodeToAll(true)
        EventCleanup()
        BroadcastEventState()
        PrintMessage(HUD_PRINTTALK, "[Event] Event stopped by " .. admin:Nick() .. " — godmode restored, server cleaned up.")
        EventLog(admin:Nick() .. " stopped the event (godmode on, cleanup done)")

    elseif action == "refresh" then
        SendPlayerList(admin)
        net.Start("ZC_EventMenu_EventState")
            net.WriteUInt(ZC_EventState, 2)
        net.Send(admin)
    end
end)

-- ── Loadout editor (superadmin only) ─────────────────────────────────────────
-- Operations:
--   create    arg = preset name
--   delete    arg = preset name
--   setgroup  arg = "PresetName|GroupName"
--   addwep    arg = "PresetName|weapon_class"
--   removewep arg = "PresetName|index"
--   addvar    arg = "PresetName|choice1|choice2|..."
--   addvaroption    arg = "PresetName|varIndex|classname"
--   removevaroption arg = "PresetName|varIndex|choiceIndex"
--   setarmor  arg = "PresetName|slot|key"           (plain key — use "$random" to set random)
--   setarmorvar arg = "PresetName|slot|choice1|choice2|..."
--   cleararmor arg = "PresetName|slot"
--   rename    arg = "OldName|NewName"

local function PushLoadoutSavedToAdmins()
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end
        if not ply:IsAdmin() then continue end
        SendLoadoutList(ply)
        net.Start("ZC_EventMenu_LoadoutSaved")
        net.Send(ply)
    end
end

-- Helper: get weapons table from preset, handling both old and new structure
local function PresetWeapons(name)
    local p = ZC_EventLoadouts[name]
    if not p then return nil end
    return p.weapons or p
end

net.Receive("ZC_EventMenu_LoadoutEdit", function(len, admin)
    if not IsValid(admin) then return end
    if not admin:IsSuperAdmin() then Feedback(admin, "Loadout editing requires Superadmin."); return end

    local op  = net.ReadString()
    local arg = net.ReadString()

    if op == "create" then
        local name = string.Trim(arg)
        if name == "" then Feedback(admin, "Preset name cannot be empty."); return end
        if ZC_EventLoadouts[name] then Feedback(admin, "Preset '" .. name .. "' already exists."); return end
        ZC_EventLoadouts[name] = { group = "", weapons = {} }
        SaveLoadouts()
        PushLoadoutSavedToAdmins()
        EventLog(admin:Nick() .. " created loadout preset: " .. name)

    elseif op == "delete" then
        local name = string.Trim(arg)
        if not ZC_EventLoadouts[name] then Feedback(admin, "Preset '" .. name .. "' not found."); return end
        ZC_EventLoadouts[name] = nil
        SaveLoadouts()
        PushLoadoutSavedToAdmins()
        EventLog(admin:Nick() .. " deleted loadout preset: " .. name)

    elseif op == "setgroup" then
        local name, group = string.match(arg, "^(.+)|(.*)$")
        if not name then Feedback(admin, "Bad setgroup arg."); return end
        name  = string.Trim(name)
        group = string.Trim(group or "")
        if not ZC_EventLoadouts[name] then Feedback(admin, "Preset '" .. name .. "' not found."); return end
        ZC_EventLoadouts[name].group = group
        SaveLoadouts()
        PushLoadoutSavedToAdmins()
        EventLog(admin:Nick() .. " set group of '" .. name .. "' to '" .. group .. "'")

    elseif op == "addwep" then
        local name, wclass = string.match(arg, "^(.+)|(.+)$")
        if not name or not wclass then Feedback(admin, "Bad addwep arg."); return end
        name   = string.Trim(name)
        wclass = string.Trim(wclass)
        local weps = PresetWeapons(name)
        if not weps then Feedback(admin, "Preset '" .. name .. "' not found."); return end
        if wclass == "" then Feedback(admin, "Weapon class cannot be empty."); return end
        table.insert(weps, wclass)
        SaveLoadouts()
        PushLoadoutSavedToAdmins()
        EventLog(admin:Nick() .. " added '" .. wclass .. "' to loadout: " .. name)

    elseif op == "removewep" then
        local name, idxStr = string.match(arg, "^(.+)|(%d+)$")
        if not name or not idxStr then Feedback(admin, "Bad removewep arg."); return end
        name = string.Trim(name)
        local idx  = tonumber(idxStr)
        local weps = PresetWeapons(name)
        if not weps then Feedback(admin, "Preset '" .. name .. "' not found."); return end
        if not weps[idx] then Feedback(admin, "No weapon at index " .. idx .. "."); return end
        local removed = weps[idx]
        table.remove(weps, idx)
        SaveLoadouts()
        PushLoadoutSavedToAdmins()
        EventLog(admin:Nick() .. " removed '" .. tostring(removed) .. "' from loadout: " .. name)

    elseif op == "addvar" then
        local parts = string.Explode("|", arg)
        local name  = string.Trim(table.remove(parts, 1))
        local weps  = PresetWeapons(name)
        if not weps then Feedback(admin, "Preset '" .. name .. "' not found."); return end
        if #parts == 0 then Feedback(admin, "Add at least one choice."); return end
        local entry = { "$random" }
        for _, choice in ipairs(parts) do
            local c = string.Trim(choice)
            if c ~= "" then table.insert(entry, c) end
        end
        if #entry < 2 then Feedback(admin, "Variable needs at least one non-empty choice."); return end
        table.insert(weps, entry)
        SaveLoadouts()
        PushLoadoutSavedToAdmins()
        EventLog(admin:Nick() .. " added random variable to loadout '" .. name .. "'")

    elseif op == "addvaroption" then
        local name, idxStr, choice = string.match(arg, "^(.+)|(%d+)|(.+)$")
        if not name or not idxStr or not choice then Feedback(admin, "Bad addvaroption arg."); return end
        name   = string.Trim(name)
        choice = string.Trim(choice)
        local idx  = tonumber(idxStr)
        local weps = PresetWeapons(name)
        if not weps then Feedback(admin, "Preset '" .. name .. "' not found."); return end
        local entry = weps[idx]
        if type(entry) ~= "table" or entry[1] ~= "$random" then Feedback(admin, "Slot " .. idx .. " is not a random variable."); return end
        if choice == "" then Feedback(admin, "Choice cannot be empty."); return end
        table.insert(entry, choice)
        SaveLoadouts()
        PushLoadoutSavedToAdmins()
        EventLog(admin:Nick() .. " added choice '" .. choice .. "' to variable in '" .. name .. "' slot " .. idx)

    elseif op == "removevaroption" then
        local name, idxStr, choiceIdxStr = string.match(arg, "^(.+)|(%d+)|(%d+)$")
        if not name or not idxStr or not choiceIdxStr then Feedback(admin, "Bad removevaroption arg."); return end
        name = string.Trim(name)
        local idx       = tonumber(idxStr)
        local choiceIdx = tonumber(choiceIdxStr) + 1
        local weps      = PresetWeapons(name)
        if not weps then Feedback(admin, "Preset '" .. name .. "' not found."); return end
        local entry = weps[idx]
        if type(entry) ~= "table" or entry[1] ~= "$random" then Feedback(admin, "Slot " .. idx .. " is not a random variable."); return end
        if not entry[choiceIdx] then Feedback(admin, "No choice at that index."); return end
        if #entry <= 2 then
            table.remove(weps, idx)
            Feedback(admin, "Last choice removed — variable slot deleted.")
        else
            local removed = entry[choiceIdx]
            table.remove(entry, choiceIdx)
            Feedback(admin, "Removed choice '" .. removed .. "'.")
        end
        SaveLoadouts()
        PushLoadoutSavedToAdmins()
        EventLog(admin:Nick() .. " removed choice from variable in '" .. name .. "' slot " .. idx)

    elseif op == "setarmor" then
        -- arg = "PresetName|slot|key"
        local name, slot, key = string.match(arg, "^(.+)|([a-z]+)|(.+)$")
        if not name or not slot or not key then Feedback(admin, "Bad setarmor arg."); return end
        name = string.Trim(name); key = string.Trim(key)
        if not ZC_EventLoadouts[name] then Feedback(admin, "Preset '" .. name .. "' not found."); return end
        if not table.HasValue(ARMOR_SLOTS, slot) then Feedback(admin, "Invalid slot '" .. slot .. "'."); return end
        ZC_EventLoadouts[name].armor = ZC_EventLoadouts[name].armor or {}
        ZC_EventLoadouts[name].armor[slot] = key
        SaveLoadouts(); PushLoadoutSavedToAdmins()
        EventLog(admin:Nick() .. " set armor " .. slot .. "='" .. key .. "' on loadout '" .. name .. "'")

    elseif op == "setarmorvar" then
        -- arg = "PresetName|slot|choice1|choice2|..."
        local parts = string.Explode("|", arg)
        local name  = string.Trim(table.remove(parts, 1))
        local slot  = table.remove(parts, 1)
        if not ZC_EventLoadouts[name] then Feedback(admin, "Preset '" .. name .. "' not found."); return end
        if not table.HasValue(ARMOR_SLOTS, slot) then Feedback(admin, "Invalid slot '" .. (slot or "") .. "'."); return end
        if #parts == 0 then Feedback(admin, "Need at least one choice."); return end
        local entry = { "$random" }
        for _, c in ipairs(parts) do local t = string.Trim(c); if t ~= "" then table.insert(entry, t) end end
        if #entry < 2 then Feedback(admin, "No valid choices."); return end
        ZC_EventLoadouts[name].armor = ZC_EventLoadouts[name].armor or {}
        ZC_EventLoadouts[name].armor[slot] = entry
        SaveLoadouts(); PushLoadoutSavedToAdmins()
        EventLog(admin:Nick() .. " set armor var on " .. slot .. " in loadout '" .. name .. "'")

    elseif op == "cleararmor" then
        -- arg = "PresetName|slot"
        local name, slot = string.match(arg, "^(.+)|([a-z]+)$")
        if not name or not slot then Feedback(admin, "Bad cleararmor arg."); return end
        name = string.Trim(name)
        if not ZC_EventLoadouts[name] then Feedback(admin, "Preset '" .. name .. "' not found."); return end
        if ZC_EventLoadouts[name].armor then
            ZC_EventLoadouts[name].armor[slot] = nil
        end
        SaveLoadouts(); PushLoadoutSavedToAdmins()
        EventLog(admin:Nick() .. " cleared armor slot " .. slot .. " on loadout '" .. name .. "'")

    elseif op == "addarmvaropt" then
        -- arg = "PresetName|slot|choice"
        local name, slot, choice = string.match(arg, "^(.+)|([a-z]+)|(.+)$")
        if not name or not slot or not choice then Feedback(admin, "Bad addarmvaropt arg."); return end
        name = string.Trim(name); choice = string.Trim(choice)
        if not ZC_EventLoadouts[name] then Feedback(admin, "Preset '" .. name .. "' not found."); return end
        local armor = ZC_EventLoadouts[name].armor or {}
        ZC_EventLoadouts[name].armor = armor
        local entry = armor[slot]
        if type(entry) ~= "table" then
            Feedback(admin, "Slot '" .. slot .. "' is not a random variable."); return
        end
        if entry[1] == "$random" then
            table.insert(entry, choice)
        elseif entry.type == "random" and istable(entry.choices) then
            table.insert(entry.choices, choice)
            armor[slot] = { "$random", unpack(entry.choices) }
        else
            Feedback(admin, "Slot '" .. slot .. "' is not a random variable."); return
        end
        SaveLoadouts(); PushLoadoutSavedToAdmins()
        EventLog(admin:Nick() .. " added armor var choice '" .. choice .. "' to " .. slot .. " on '" .. name .. "'")

    elseif op == "removearmvaropt" then
        -- arg = "PresetName|slot|choiceIndex" (1-based)
        local name, slot, idxStr = string.match(arg, "^(.+)|([a-z]+)|(%d+)$")
        if not name or not slot or not idxStr then Feedback(admin, "Bad removearmvaropt arg."); return end
        name = string.Trim(name)
        local idx = tonumber(idxStr)
        if not ZC_EventLoadouts[name] then Feedback(admin, "Preset '" .. name .. "' not found."); return end
        local armor = ZC_EventLoadouts[name].armor or {}
        local entry = armor[slot]
        if type(entry) ~= "table" then
            Feedback(admin, "Slot '" .. slot .. "' is not a random variable."); return
        end
        local choices
        if entry[1] == "$random" then
            choices = entry
            idx = idx + 1
        elseif entry.type == "random" and istable(entry.choices) then
            choices = { "$random", unpack(entry.choices) }
        else
            Feedback(admin, "Slot '" .. slot .. "' is not a random variable."); return
        end
        if not choices[idx] then Feedback(admin, "No choice at index " .. (tonumber(idxStr) or idx) .. "."); return end
        if #choices <= 2 then
            -- Last choice — clear the whole slot
            armor[slot] = nil
            Feedback(admin, "Last choice removed — armor slot cleared.")
        else
            table.remove(choices, idx)
            armor[slot] = choices
        end
        SaveLoadouts(); PushLoadoutSavedToAdmins()
        EventLog(admin:Nick() .. " removed armor var choice " .. idx .. " from " .. slot .. " on '" .. name .. "'")

    elseif op == "rename" then
        local oldName, newName = string.match(arg, "^(.+)|(.+)$")
        if not oldName or not newName then Feedback(admin, "Bad rename arg."); return end
        oldName = string.Trim(oldName)
        newName = string.Trim(newName)
        if not ZC_EventLoadouts[oldName] then Feedback(admin, "Preset '" .. oldName .. "' not found."); return end
        if ZC_EventLoadouts[newName] then Feedback(admin, "Preset '" .. newName .. "' already exists."); return end
        if newName == "" then Feedback(admin, "New name cannot be empty."); return end
        ZC_EventLoadouts[newName] = ZC_EventLoadouts[oldName]
        ZC_EventLoadouts[oldName] = nil
        SaveLoadouts()
        PushLoadoutSavedToAdmins()
        EventLog(admin:Nick() .. " renamed loadout '" .. oldName .. "' to '" .. newName .. "'")
    end
end)

-- ── !loadout — player self-service loadout picker ─────────────────────────────
-- Players type !loadout in chat to open a menu of presets whose group exactly
-- matches their current PlayerClassName (case-insensitive), plus presets with
-- group="" which are "universal" and shown to everyone.
-- Admins using !loadout are treated the same as regular players — they see their
-- class loadouts. Superadmins can assign any loadout to any player via the Event
-- Admin Menu instead.

util.AddNetworkString("ZC_PlayerLoadout_Open")
util.AddNetworkString("ZC_PlayerLoadout_List")
util.AddNetworkString("ZC_PlayerLoadout_Apply")

local loadoutsEnabledCvar = ConVarExists("zc_player_loadouts_enabled")
    and GetConVar("zc_player_loadouts_enabled")
    or CreateConVar("zc_player_loadouts_enabled", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Enable players using !loadout menu.", 0, 1)

local function ArePlayerLoadoutsEnabled()
    return not loadoutsEnabledCvar or loadoutsEnabledCvar:GetBool()
end

local function SetPlayerLoadoutsEnabled(enabled)
    local value = enabled and "1" or "0"
    RunConsoleCommand("zc_player_loadouts_enabled", value)
end

local function SendPlayerLoadoutList(ply)
    local cls = string.lower(ply.PlayerClassName or "")

    local presets = {}
    for name, preset in pairs(ZC_EventLoadouts) do
        local group = string.lower(preset.group or "")
        -- Show: universal (group="") OR exact class match
        if group == "" or group == cls then
            table.insert(presets, { name = name, group = preset.group or "" })
        end
    end
    table.sort(presets, function(a, b)
        if a.group ~= b.group then return a.group < b.group end
        return a.name < b.name
    end)

    net.Start("ZC_PlayerLoadout_List")
        net.WriteUInt(#presets, 8)
        for _, p in ipairs(presets) do
            net.WriteString(p.name)
            net.WriteString(p.group)
        end
    net.Send(ply)

    net.Start("ZC_PlayerLoadout_Open")
    net.Send(ply)
end

hook.Add("HG_PlayerSay", "ZC_PlayerLoadout_Command", function(ply, txtTbl, text)
    local trimmed = string.lower(string.Trim(text))
    local args = string.Explode(" ", trimmed, false)
    local cmd = args[1] or ""

    if cmd ~= "!loadout" and cmd ~= "/loadout" then return end
    txtTbl[1] = ""

    if not ArePlayerLoadoutsEnabled() then
        ply:ChatPrint("[Loadout] Player loadouts are currently disabled by admin.")
        return ""
    end

    if not ply:Alive() then
        ply:ChatPrint("[Loadout] You must be alive to change your loadout.")
        return ""
    end

    SendPlayerLoadoutList(ply)
    return ""
end)

net.Receive("ZC_PlayerLoadout_Apply", function(len, ply)
    if not IsValid(ply) then return end
    if not ArePlayerLoadoutsEnabled() then
        ply:ChatPrint("[Loadout] Player loadouts are currently disabled by admin.")
        return
    end
    if not ply:Alive() then return end
    local presetName = net.ReadString()
    if not ZC_EventLoadouts[presetName] then return end
    -- Re-validate server-side: only class match or universal
    local cls   = string.lower(ply.PlayerClassName or "")
    local group = string.lower(ZC_EventLoadouts[presetName].group or "")
    if group ~= "" and group ~= cls then
        ply:ChatPrint("[Loadout] That loadout is not available for your class.")
        return
    end
    if ApplyLoadoutPreset(ply, presetName) then
        ply:ChatPrint("[Loadout] Loadout applied: " .. presetName)
    end
end)

-- ── Ragdoll orphan safety net ──────────────────────────────────────────────────
-- If a prop_ragdoll that belongs to a player gets removed by the game engine
-- (e.g. strider explosion physics, map cleanup) while org.otrub is still true,
-- ZCity loses the FakeRagdoll reference but the organism stays downed — the
-- player is permanently stuck. This hook catches that and clears the state.
hook.Add("EntityRemoved", "ZC_EventMenu_RagdollOrphanFix", function(ent)
    if not IsValid(ent) then return end
    if ent:GetClass() ~= "prop_ragdoll" then return end
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or not ply:Alive() then continue end
        if ply.FakeRagdoll ~= ent then continue end
        -- This ragdoll belonged to this player — clear downed state
        if ply.organism then
            ply.organism.otrub     = false
            ply.organism.needotrub = false
            ply.organism.needfake  = false
            ply.organism.alive     = true
        end
        ply.FakeRagdoll = nil
        break
    end
end)

-- ── Weapon fire suppression during PREP (EventState == 1) ─────────────────────
-- Strips IN_ATTACK and IN_ATTACK2 from player input before weapons see it.
-- Physgun (weapon_physgun) and toolgun (gmod_tool) are exempt so admins can
-- still manipulate props during setup.
-- Uses SetupMove which fires every tick serverside before movement is processed.

local FIRE_EXEMPT = {
    ["weapon_physgun"] = true,
    ["gmod_tool"]      = true,
}

hook.Add("SetupMove", "ZC_EventPrep_BlockFire", function(ply, mv, cmd)
    if ZC_EventState ~= 1 then return end  -- only block during PREP
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and FIRE_EXEMPT[wep:GetClass()] then return end
    cmd:RemoveKey(IN_ATTACK)
    cmd:RemoveKey(IN_ATTACK2)
end)
