-- sv_zrp_classes.lua — ZRP custom PlayerClass registry.
--
-- Stores admin-built PlayerClasses as data (data/zbattle/zrp/custom_classes.json),
-- registers them with the homigrad PlayerClass system at boot, and exposes a small
-- networked API the class-builder GUI in cl_zrp_class_builder.lua talks to.
--
-- Built-in classes (Refugee, Police, Combine, etc.) defined in lua/homigrad/playerclass/
-- are read-only here — they live in source files. We can clone them into a custom class.

if not SERVER then return end

local CLASS_DATA_PATH = "zbattle/zrp/custom_classes.json"

ZRP = ZRP or {}
ZRP.CustomClasses = ZRP.CustomClasses or {}     -- [name] = definition table (the saved data)
ZRP.CustomClassDefs = ZRP.CustomClassDefs or {} -- alias for sanity

-- Built-in class names that ship with the codebase (from
-- lua/homigrad/playerclass/classes/sh_*.lua). They appear in the class list
-- as read-only entries; the builder offers Clone but not Edit/Delete on these.
local BUILTIN_CLASSES = {
    "Refugee",
    "Rebel",
    "Gordon",
    "Police",
    "SWAT",
    "Combine",
    "Metrocop",
    "CommanderForces",
    "NationalGuard",
    "Terrorist",
    "Bloodz",
    "Groove",
    "HiddenVip",
    "HeadcrabZombie",
    "Slugcat",
    "Subject617",
}

local function EnsureZRPDir()
    if not file.Exists("zbattle", "DATA") then file.CreateDir("zbattle") end
    if not file.Exists("zbattle/zrp", "DATA") then file.CreateDir("zbattle/zrp") end
end

-- ── Definition validation ────────────────────────────────────────────────────
-- Accepts a raw table (from the GUI or disk) and returns a sanitised definition
-- ready to be stored. Returns nil + reason on failure.

local function NormalizeColor(c)
    if not istable(c) then return {255, 255, 255} end
    local r = math.Clamp(tonumber(c[1]) or 255, 0, 255)
    local g = math.Clamp(tonumber(c[2]) or 255, 0, 255)
    local b = math.Clamp(tonumber(c[3]) or 255, 0, 255)
    return {math.floor(r), math.floor(g), math.floor(b)}
end

local function NormalizeStringList(t)
    if not istable(t) then return {} end
    local out = {}
    local seen = {}
    for _, v in ipairs(t) do
        local s = string.lower(string.Trim(tostring(v or "")))
        if s ~= "" and not seen[s] then
            seen[s] = true
            out[#out + 1] = s
        end
    end
    return out
end

local function NormalizeAmmo(t)
    -- Expected shape: { {ammoType, amount}, ... } — coerce loosely.
    if not istable(t) then return {} end
    local out = {}
    for _, e in ipairs(t) do
        if istable(e) then
            local atype = string.lower(string.Trim(tostring(e[1] or "")))
            local amount = math.Clamp(tonumber(e[2]) or 0, 0, 99999)
            if atype ~= "" and amount > 0 then
                out[#out + 1] = {atype, amount}
            end
        end
    end
    return out
end

function ZRP.ValidateClassDef(raw)
    if not istable(raw) then return nil, "definition must be a table" end

    local name = string.Trim(tostring(raw.name or ""))
    if name == "" then return nil, "name is required" end
    if #name > 32 then return nil, "name too long (max 32)" end
    if string.find(name, "[^%w%s_%-]") then
        return nil, "name may only contain letters, digits, spaces, underscores, hyphens"
    end

    -- Block overwriting built-in class names from data — built-ins are source-defined.
    for _, builtin in ipairs(BUILTIN_CLASSES) do
        if string.lower(builtin) == string.lower(name) then
            return nil, "name conflicts with a built-in class (use a different name or Clone instead)"
        end
    end

    local model = string.Trim(tostring(raw.model or ""))
    if model == "" then return nil, "model path is required" end
    if string.find(model, "%.%.") then return nil, "model path may not contain '..'" end
    if not string.EndsWith(string.lower(model), ".mdl") then
        return nil, "model path must end in .mdl"
    end

    return {
        name        = name,
        model       = model,
        color       = NormalizeColor(raw.color),
        walkSpeed   = math.Clamp(tonumber(raw.walkSpeed) or 200, 50, 800),
        runSpeed    = math.Clamp(tonumber(raw.runSpeed)  or 360, 50, 1500),
        maxHealth   = math.Clamp(tonumber(raw.maxHealth) or 100, 1, 1000),
        weapons     = NormalizeStringList(raw.weapons),
        ammo        = NormalizeAmmo(raw.ammo),
        armor       = NormalizeStringList(raw.armor),
        clonedFrom  = raw.clonedFrom and tostring(raw.clonedFrom) or nil,
        savedAt     = os.time(),
    }
end

-- ── Class registration with homigrad PlayerClass system ──────────────────────
-- player.RegClass returns the class table we attach hooks to. The same name can
-- be re-registered (it returns the existing table); we overwrite our hooks each
-- time so re-saving an edited class updates behavior on next respawn.

function ZRP.RegisterCustomClass(def)
    if not istable(def) or not def.name then return false end

    local CLASS = player.RegClass(def.name)
    CLASS.ZRP_Custom         = true
    CLASS.ZRP_Definition     = def
    CLASS.CanUseDefaultPhrase = true

    function CLASS.On(self, data)
        if CLIENT then return end
        if not IsValid(self) then return end

        if def.color then
            self:SetPlayerColor(Color(def.color[1], def.color[2], def.color[3]):ToVector())
        end
        if def.maxHealth then
            self:SetMaxHealth(def.maxHealth)
            self:SetHealth(def.maxHealth)
        end
        if def.walkSpeed then self:SetWalkSpeed(def.walkSpeed) end
        if def.runSpeed  then self:SetRunSpeed(def.runSpeed)  end
        if def.model and util.IsValidModel(def.model) then
            self:SetModel(def.model)
        end

        local bNoEquipment = istable(data) and data.bNoEquipment
        if not bNoEquipment then
            self:PlayerClassEvent("GiveEquipment", self.subClass)
        end
    end

    function CLASS.Off(self)
        -- No-op: the next class's On() resets model/colors/speed.
    end

    function CLASS.GiveEquipment(self)
        if CLIENT then return end
        if not IsValid(self) then return end

        for _, w in ipairs(def.weapons or {}) do
            self:Give(w)
        end
        for _, a in ipairs(def.ammo or {}) do
            self:GiveAmmo(a[2], a[1], true)
        end
        if def.armor and #def.armor > 0 and hg and hg.AddArmor then
            for _, ar in ipairs(def.armor) do
                hg.AddArmor(self, ar)
            end
            if self.SyncArmor then self:SyncArmor() end
        end
    end

    return true
end

-- ── Persistence ───────────────────────────────────────────────────────────────

function ZRP.SaveCustomClasses()
    EnsureZRPDir()
    local out = {}
    for _, def in pairs(ZRP.CustomClasses) do
        out[#out + 1] = def
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    file.Write(CLASS_DATA_PATH, util.TableToJSON(out, true))
    print("[ZRP] Saved " .. #out .. " custom classes.")
end

function ZRP.LoadCustomClasses()
    EnsureZRPDir()
    ZRP.CustomClasses = {}
    local raw = file.Read(CLASS_DATA_PATH, "DATA")
    if not raw or raw == "" then return end

    local parsed = util.JSONToTable(raw)
    if not istable(parsed) then return end

    for _, rawDef in ipairs(parsed) do
        local def, err = ZRP.ValidateClassDef(rawDef)
        if def then
            ZRP.CustomClasses[def.name] = def
            ZRP.RegisterCustomClass(def)
        else
            print("[ZRP] Skipped invalid custom class on load: " .. tostring(err))
        end
    end
    print("[ZRP] Loaded " .. table.Count(ZRP.CustomClasses) .. " custom classes.")
end

-- ── Class list snapshot for the GUI ──────────────────────────────────────────

function ZRP.GetClassListSnapshot()
    -- Built-in classes are emitted with isBuiltIn=true and minimal metadata.
    -- The GUI greys them out and offers Clone (not Edit/Delete).
    local list = {}

    for _, name in ipairs(BUILTIN_CLASSES) do
        list[#list + 1] = {
            name      = name,
            isBuiltIn = true,
        }
    end

    for _, def in pairs(ZRP.CustomClasses) do
        list[#list + 1] = {
            name       = def.name,
            isBuiltIn  = false,
            model      = def.model,
            color      = def.color,
            walkSpeed  = def.walkSpeed,
            runSpeed   = def.runSpeed,
            maxHealth  = def.maxHealth,
            weapons    = def.weapons,
            ammo       = def.ammo,
            armor      = def.armor,
            clonedFrom = def.clonedFrom,
        }
    end

    table.sort(list, function(a, b)
        if a.isBuiltIn ~= b.isBuiltIn then return a.isBuiltIn end
        return a.name < b.name
    end)

    return list
end

local function SyncClassListToPlayer(ply)
    if not IsValid(ply) then return end
    net.Start("ZRP_ClassListSync")
    net.WriteTable(ZRP.GetClassListSnapshot())
    net.Send(ply)
end

function ZRP.SyncClassListToPlayer(ply)
    SyncClassListToPlayer(ply)
end

-- ── Networked API (admin-gated) ──────────────────────────────────────────────

net.Receive("ZRP_ClassSave", function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local raw = net.ReadTable()
    local def, err = ZRP.ValidateClassDef(raw)
    if not def then
        ply:ChatPrint("[ZRP] Class save failed: " .. tostring(err))
        return
    end

    local existed = ZRP.CustomClasses[def.name] ~= nil
    ZRP.CustomClasses[def.name] = def
    ZRP.RegisterCustomClass(def)
    ZRP.SaveCustomClasses()

    ply:ChatPrint("[ZRP] " .. (existed and "Updated" or "Created") .. " class: " .. def.name
        .. " (applies on next respawn)")
    SyncClassListToPlayer(ply)
end)

net.Receive("ZRP_ClassDelete", function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local name = string.Trim(net.ReadString() or "")
    if name == "" then return end

    -- Block deletion of built-ins.
    for _, builtin in ipairs(BUILTIN_CLASSES) do
        if string.lower(builtin) == string.lower(name) then
            ply:ChatPrint("[ZRP] Cannot delete built-in class: " .. name)
            return
        end
    end

    if not ZRP.CustomClasses[name] then
        ply:ChatPrint("[ZRP] No custom class named: " .. name)
        return
    end

    ZRP.CustomClasses[name] = nil
    -- Note: player.classList[name] still has the old entry, but no one will be
    -- assigned to it after delete; on next server boot it won't be registered.
    -- We can't fully remove from player.classList (the codebase has no API for it).
    ZRP.SaveCustomClasses()

    ply:ChatPrint("[ZRP] Deleted class: " .. name .. " (effective on next map change)")
    SyncClassListToPlayer(ply)
end)

net.Receive("ZRP_ClassTestOnSelf", function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local name = string.Trim(net.ReadString() or "")
    if name == "" then return end

    if not player.classList[name] then
        ply:ChatPrint("[ZRP] Unknown class: " .. name)
        return
    end

    -- Apply to the admin themselves only — never use this on other players.
    if ply.SetPlayerClass then
        ply:SetPlayerClass(name)
        ply:ChatPrint("[ZRP] Set your PlayerClass to: " .. name)
    end
end)

-- ── Open command / boot hook ─────────────────────────────────────────────────

concommand.Add("zrp_open_class_builder", function(ply, _, _, _)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    SyncClassListToPlayer(ply)
    net.Start("ZRP_OpenClassBuilder")
    net.Send(ply)
end)

-- Load custom classes after homigrad's class system has had a chance to register
-- the built-ins. The codebase loads sh_*.lua under lua/homigrad/playerclass/ at
-- module boot, so a 2-second delay is comfortably safe.
hook.Add("Initialize", "ZRP_LoadCustomClasses", function()
    timer.Simple(2, function()
        ZRP.LoadCustomClasses()
    end)
end)
