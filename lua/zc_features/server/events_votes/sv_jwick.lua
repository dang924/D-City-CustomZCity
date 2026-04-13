-- John Wick vs Everyone — Server
-- One player is John Wick: bulletproof suit, only vulnerable to high caliber and headshots.
-- Guards spawn with low-cal pistols/SMGs. VIP gets elite bodyguards with armor.
-- Bystanders (14+ players) spawn unarmed and are expected to flee.

-- John Wick playermodel FastDL resources
resource.AddFile("models/wick_chapter2/wick_chapter2.mdl")
resource.AddFile("models/wick_chapter2/wick_chapter2.phy")
resource.AddFile("models/wick_chapter2/wick_chapter2.dx80.vtx")
resource.AddFile("models/wick_chapter2/wick_chapter2.dx90.vtx")
resource.AddFile("models/wick_chapter2/wick_chapter2.sw.vtx")
resource.AddFile("models/wick_chapter2/wick_chapter2.vvd")
resource.AddFile("models/wick_chapter2/wick_chapter2_c_arms.mdl")
resource.AddFile("models/wick_chapter2/wick_chapter2_c_arms.dx80.vtx")
resource.AddFile("models/wick_chapter2/wick_chapter2_c_arms.dx90.vtx")
resource.AddFile("models/wick_chapter2/wick_chapter2_c_arms.sw.vtx")
resource.AddFile("models/wick_chapter2/wick_chapter2_c_arms.vvd")

-- Materials
resource.AddFile("materials/models/wick_chapter2/wick/eye_lightwarp.vtf")
resource.AddFile("materials/models/wick_chapter2/wick/pyro_lightwarp.vtf")
resource.AddFile("materials/models/wick_chapter2/wick/shared/base_m_caucasian_wrp.vtf")
resource.AddFile("materials/models/wick_chapter2/wick/shared/black.vtf")
resource.AddFile("materials/models/wick_chapter2/wick/shared/clothes_wrp2.vtf")
resource.AddFile("materials/models/wick_chapter2/wick/shared/eye_lightwarp.vtf")
resource.AddFile("materials/models/wick_chapter2/wick/shared/eyeball_ao.vtf")
resource.AddFile("materials/models/wick_chapter2/wick/shared/flat_exponent.vtf")
resource.AddFile("materials/models/wick_chapter2/wick/shared/flat_normal.vtf")
resource.AddFile("materials/models/wick_chapter2/wick/shared/mechanic_eye_ao.vtf")
resource.AddFile("materials/models/wick_chapter2/wick/shared/phong_exp.vtf")
resource.AddFile("materials/models/wick_chapter2/wick/shared/phong_exp2.vtf")
resource.AddFile("materials/models/wick_chapter2/wick/shared/white.vtf")
resource.AddFile("materials/models/wick_chapter2/wick/characters/john_wick/m_med_assassin_suit_1.vmt")
resource.AddFile("materials/models/wick_chapter2/wick/characters/john_wick/m_med_assassin_suit.vmt")
resource.AddFile("materials/models/wick_chapter2/wick/characters/john_wick/m_med_assassin_suit_head.vmt")
resource.AddFile("materials/models/wick_chapter2/wick/characters/john_wick/m_med_assassin_suit_skin.vmt")
resource.AddFile("materials/models/wick_chapter2/wick/characters/john_wick/m_med_assassin_suit_hair.vmt")


local SHIELD_MAX        = 100   -- max stamina
local SHIELD_DRAIN      = 25    -- drain per second while held
local SHIELD_REGEN      = 15    -- regen per second when released
local SHIELD_MIN_TO_USE = 10    -- minimum stamina needed to start shielding
local SHIELD_DAMAGE_MUL = 0.15  -- body shots through shield do 15% damage (suit + lapel)

-- Hold to shield — +/- concommand pair like +duck, +attack etc.
-- Server-side: apply shield state. Client also needs these registered
-- so the engine recognises the +command and sends it while the key is held.
if SERVER then
    concommand.Add("+jwick_shield", function(ply)
        local isJohnEvent = JWick.Active and ply.JWickRole == "john"
        local isJohnClass = ply.PlayerClassName == "John"
        if not isJohnEvent and not isJohnClass then return end
        if not IsValid(ply) then return end
        if not ply:Alive() then return end
        if (ply.JWick_ShieldStamina or SHIELD_MAX) < SHIELD_MIN_TO_USE then return end
        ply.JWick_Shielding = true
    end)

    concommand.Add("-jwick_shield", function(ply)
        ply.JWick_Shielding = false
    end)
else
    -- Client registration — required for +command to work as a hold key
    concommand.Add("+jwick_shield", function() end)
    concommand.Add("-jwick_shield", function() end)
end

if CLIENT then return end

-- Resolve the actual player entity from PreHomigradDamage args.
-- When a player has a FakeRagdoll, the first arg may be the ragdoll entity.
-- We resolve back to the real player via ent.ply or organism owner.
local function ResolveJohnPly(ply, ent)
    if IsValid(ply) and ply:IsPlayer() and ply.JWickRole == "john" then
        return ply
    end
    -- ent may be the real player entity when ply is a ragdoll
    if IsValid(ent) and ent:IsPlayer() and ent.JWickRole == "john" then
        return ent
    end
    -- try organism owner
    if IsValid(ply) and ply.organism and IsValid(ply.organism.owner) then
        local owner = ply.organism.owner
        if owner:IsPlayer() and owner.JWickRole == "john" then return owner end
    end
    return nil
end


-- ── Configuration ─────────────────────────────────────────────────────────────



-- High caliber ammo types that bypass the bulletproof suit
-- Add or remove entries to tune difficulty
local HIGH_CALIBER = {
    ["7.62x39 mm"]       = true,
    ["7.62x39mm"]        = true,
    ["7.62x51 mm"]       = true,
    ["7.62x54 mm"]       = true,
    [".338 lapua magnum"]= true,
    ["12.7x55 mm"]       = true,
    ["12.7x108 mm"]      = true,
    ["14.5x114mm b32"]   = true,
    [".50 action express"]= true,
}

-- How much damage the suit absorbs for high-cal body shots (0=full block, 1=no block)
local HIGHCAL_BODY_SCALE  = 0.35  -- high cal body shots do 35% damage
local LOWCAL_BLOCK        = true  -- true = block all low-cal entirely

-- Max number of elite bodyguards (get armor)
local MAX_ELITE_GUARDS = 5

-- Player threshold above which bystanders start being assigned
local BYSTANDER_THRESHOLD = 14

-- Guard loadout pools
local GUARD_PISTOLS = {
    "weapon_glock17", "weapon_m9beretta", "weapon_hk_usp",
    "weapon_cz75", "weapon_pl15", "weapon_px4beretta",
}
local GUARD_SMGS = {
    "weapon_mp7", "weapon_mp5", "weapon_uzi",
    "weapon_tmp", "weapon_tec9", "weapon_ab10",
}
-- High caliber rifles only — no LMGs
local ELITE_PRIMARIES = {
    "weapon_akm", "weapon_ak203", "weapon_sks",
    "weapon_draco", "weapon_dracovska",
}

-- Guaranteed high-cal weapon for at least one guard (rifles only, no LMGs)
local HIGHCAL_RIFLES = {
    "weapon_akm", "weapon_ak203", "weapon_sr25",
    "weapon_svd", "weapon_mosin", "weapon_kar98",
    "weapon_sks", "weapon_deagle",
}

-- John's loadout (high-end weapons — he's John Wick)
local JOHN_WEAPONS = {
    "weapon_m9beretta",   -- his signature pistol
    "weapon_hk416",       -- rifle
    "weapon_deagle",      -- heavy pistol
}

-- ── State ─────────────────────────────────────────────────────────────────────

JWick = JWick or {}
JWick.John     = nil  -- player entity
JWick.VIP      = nil  -- player entity
JWick.Active   = false

-- ── Net strings ───────────────────────────────────────────────────────────────

util.AddNetworkString("JWick_SetRole")    -- tells client their role (john/guard/vip/bystander/elite)
util.AddNetworkString("JWick_Start")      -- tells all clients the event started
util.AddNetworkString("JWick_End")        -- tells all clients the event ended
util.AddNetworkString("JWick_ShieldSync") -- syncs John's shield stamina to client

-- ── Loadout helpers ───────────────────────────────────────────────────────────

local function StripAndGive(ply, weapons, armor)
    ply:StripWeapons()

    local inv = ply:GetNetVar("Inventory", {})
    inv.Weapons     = { ["hg_sling"] = true, ["hg_flashlight"] = true }
    inv.Armor       = {}
    inv.Attachments = inv.Attachments or {}
    ply:SetNetVar("Inventory", inv)

    if ply.armors then
        for placement, _ in pairs(ply.armors) do
            pcall(function() hg.DropArmorForce(ply, placement) end)
        end
    end

    for _, wep in ipairs(weapons) do
        local w = ply:Give(wep)
        if IsValid(w) and w.GetMaxClip1 and w:GetMaxClip1() > 0 then
            ply:GiveAmmo(w:GetMaxClip1() * 4, w:GetPrimaryAmmoType(), true)
        end
    end

    ply:Give("weapon_hands_sh")

    if armor then
        ply.armors = ply.armors or {}
        if armor.vest    then hg.AddArmor(ply, armor.vest)    end
        if armor.helmet  then hg.AddArmor(ply, armor.helmet)  end
        if pcall(function() ply:SyncArmor() end) then end
    end
end

local function GiveJohnLoadout(ply)
    StripAndGive(ply, JOHN_WEAPONS, nil)
    ply:SetHealth(200)
    ply:SetMaxHealth(200)
end

local function GiveGuardLoadout(ply, isElite)
    -- Apply swat playerclass for model/appearance
    ply:SetPlayerClass("swat")
    timer.Simple(0.2, function()
        if not IsValid(ply) then return end
        local pistol  = GUARD_PISTOLS[math.random(#GUARD_PISTOLS)]
        local weapons = { pistol }
        if isElite then
            table.insert(weapons, ELITE_PRIMARIES[math.random(#ELITE_PRIMARIES)])
        else
            if math.random(2) == 1 then
                table.insert(weapons, GUARD_SMGS[math.random(#GUARD_SMGS)])
            end
        end
        local armor = isElite and { vest = "vest5", helmet = "helmet1" } or nil
        StripAndGive(ply, weapons, armor)
        ply:SetHealth(isElite and 120 or 80)
        ply:SetMaxHealth(isElite and 120 or 80)
    end)
end

local function GiveVIPLoadout(ply)
    -- Refugee model, stripped weapons, only a pistol
    ply:SetPlayerClass("Refugee")
    timer.Simple(0.2, function()
        if not IsValid(ply) then return end
        StripAndGive(ply, { GUARD_PISTOLS[math.random(#GUARD_PISTOLS)] }, nil)
        ply:SetHealth(100)
        ply:SetMaxHealth(100)
    end)
end

local function GiveBystanderLoadout(ply)
    -- Refugee model, no weapons
    ply:SetPlayerClass("Refugee")
    timer.Simple(0.2, function()
        if not IsValid(ply) then return end
        StripAndGive(ply, {}, nil)
        ply:SetHealth(80)
        ply:SetMaxHealth(80)
    end)
end

-- ── Role assignment ───────────────────────────────────────────────────────────

function AssignRoles(johnPly, vipPly)
    local players = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and ply ~= johnPly and ply ~= vipPly then
            table.insert(players, ply)
        end
    end

    -- Shuffle
    for i = #players, 2, -1 do
        local j = math.random(i)
        players[i], players[j] = players[j], players[i]
    end

    local totalOthers = #players
    local numElite    = math.min(MAX_ELITE_GUARDS, math.floor(totalOthers * 0.2))
    local numBystanders = 0
    if (totalOthers + 2) > BYSTANDER_THRESHOLD then
        numBystanders = math.max(0, (totalOthers + 2) - BYSTANDER_THRESHOLD)
    end

    -- Set John — SetPlayerClass handles model, FakeRagdoll, view offset,
    -- NPC relationships, and organism setup via sh_john_class.lua
    JWick.John = johnPly
    johnPly.JWickRole = "john"
    johnPly:SetPlayerClass("John")
    timer.Simple(0.3, function()
        if not IsValid(johnPly) then return end
        GiveJohnLoadout(johnPly)
        net.Start("JWick_SetRole") net.WriteString("john") net.Send(johnPly)
    end)

    -- Set VIP
    JWick.VIP = vipPly
    vipPly.JWickRole = "vip"
    timer.Simple(0.1, function()
        if not IsValid(vipPly) then return end
        GiveVIPLoadout(vipPly)
        net.Start("JWick_SetRole") net.WriteString("vip") net.Send(vipPly)
        vipPly:ChatPrint("[J.WICK] You are the VIP. Stay alive.")
    end)

    -- Set guards and bystanders
    -- First non-elite guard always gets a high-cal rifle so John is beatable
    local highCalAssigned = false

    for i, ply in ipairs(players) do
        local isBystander = i > (totalOthers - numBystanders)
        local isElite     = (not isBystander) and (i <= numElite)
        local role        = isBystander and "bystander" or (isElite and "elite" or "guard")

        local forceHighCal = false
        if not isBystander and not isElite and not highCalAssigned then
            forceHighCal    = true
            highCalAssigned = true
        end

        ply.JWickRole = role
        local p   = ply
        local r   = role
        local e   = isElite
        local b   = isBystander
        local fhc = forceHighCal
        timer.Simple(0.1, function()
            if not IsValid(p) then return end
            if b then
                GiveBystanderLoadout(p)
                p:ChatPrint("[J.WICK] You are a bystander. Run and hide.")
            elseif fhc then
                local pistol = GUARD_PISTOLS[math.random(#GUARD_PISTOLS)]
                local rifle  = HIGHCAL_RIFLES[math.random(#HIGHCAL_RIFLES)]
                StripAndGive(p, { pistol, rifle }, nil)
                p:SetHealth(80) p:SetMaxHealth(80)
                p:ChatPrint("[J.WICK] You are a guard with a high caliber rifle. Make it count.")
            else
                GiveGuardLoadout(p, e)
                if e then
                    p:ChatPrint("[J.WICK] You are an ELITE guard. Protect the VIP.")
                else
                    p:ChatPrint("[J.WICK] You are a guard. Protect the VIP.")
                end
            end
            net.Start("JWick_SetRole") net.WriteString(r) net.Send(p)
        end)
    end

    JWick.Active = true
    net.Start("JWick_Start") net.Broadcast()

    PrintMessage(HUD_PRINTTALK, "[J.WICK] John Wick event started! " ..
        johnPly:Nick() .. " is John. " .. vipPly:Nick() .. " is the VIP.")
end

-- ── Unbreaking will — pain suppression ──────────────────────────────────────
-- John Wick's willpower mirrors Gordon's HEV morphine system.
-- org.analgesia at max (1.0) multiplies the shock-to-ragdoll threshold by 5x,
-- suppresses organ-damage stuns, and prevents limping.
-- We keep it pinned to 1.0 on every damage event and via a slow Think ticker.

hook.Add("HomigradDamage", "JWick_Willpower", function(ply, dmgInfo, hitgroup, ent, harm)
    local john = ResolveJohnPly(ply, ent)
    if not john or not john.organism then return end
    if not JWick.Active and john.PlayerClassName ~= "John" then return end

    -- Headshots should not be suppressed by willpower
    if hitgroup == HITGROUP_HEAD or hitgroup == 1 then return end

    -- Pin analgesia to max so stun threshold stays 5x higher
    john.organism.analgesia = 1.0

    -- Cap shock so consecutive body hits never stack to ragdoll threshold
    john.organism.shock = math.min(john.organism.shock, 5)
end)

-- Intercept organ-level damage for John's skull.
-- PreTraceOrganBulletDamage fires per-organ before the damage function runs.
-- Setting hook_info.restricted = true skips the organ entirely.
-- This is the correct level to block skull damage — PreHomigradDamage
-- operates on dmgInfo which doesn't control the organ trace system.
hook.Add("PreTraceOrganBulletDamage", "JWick_SkullIntercept", function(org, bone, dmg, dmgInfo, box, dir, hit, ricochet, organ, hook_info)
    if not org or not org.owner then return end
    local john = org.owner
    if not IsValid(john) or not john:IsPlayer() then return end
    if john.JWickRole ~= "john" and john.PlayerClassName ~= "John" then return end
    if JWick.Active and john.JWickRole ~= "john" then return end  -- during event, only apply to event John

    local organName = organ and organ[1]
    if organName ~= "skull" and organName ~= "brain" then return end

    if john.JWick_Shielding then
        -- Shield covers head — block skull and brain damage entirely
        hook_info.restricted = true
        hook_info.dmg = 0
    else
        -- Not shielding — skull hit kills John instantly
        hook_info.restricted = true
        hook_info.dmg = 0
        timer.Simple(0, function()
            if IsValid(john) and john:Alive() then
                if john.organism then
                    john.organism.consciousness = 0
                    john.organism.blood         = 0
                    john.organism.shock         = 999
                end
                hg.ExplodeHead(john)
            end
        end)
    end
end)

-- Slow ticker to re-pin analgesia in case anything decays it between hits.
-- Does NOT restore if analgesia was zeroed by a headshot — gives the damage
-- pipeline a full tick to process the skull damage before analgesia returns.
local willpowerNextThink = 0
local willpowerLastThink = CurTime()
local WILLPOWER_INTERVAL = 0.1
hook.Add("Think", "JWick_WillpowerRegen", function()
    local now = CurTime()
    if now < willpowerNextThink then return end
    local dt = math.max(now - willpowerLastThink, 0)
    willpowerLastThink = now
    willpowerNextThink = now + WILLPOWER_INTERVAL

    for _, ply in ipairs(player.GetAll()) do
        local isJohnEvent = JWick.Active and ply.JWickRole == "john"
        local isJohnClass = ply.PlayerClassName == "John"
        if not isJohnEvent and not isJohnClass then continue end
        if not IsValid(ply) or not ply:Alive() then continue end
        local org = ply.organism
        if not org then continue end

        if org.analgesia > 0 and org.analgesia < 1.0 then
            org.analgesia = math.min(org.analgesia + dt * 2, 1.0)
        end

        org.bleed = 0
        if org.wounds then
            for k, wound in pairs(org.wounds) do
                wound[1] = 0
            end
        end

        if org.blood and org.blood > 0 and org.blood < 5000 then
            org.blood = math.min(org.blood + dt * 50, 5000)
        end

        if org.lungsL then
            org.lungsL[1] = math.max(org.lungsL[1] - dt * 2, 0)
            org.lungsL[2] = math.max(org.lungsL[2] - dt * 2, 0)
        end
        if org.lungsR then
            org.lungsR[1] = math.max(org.lungsR[1] - dt * 2, 0)
            org.lungsR[2] = math.max(org.lungsR[2] - dt * 2, 0)
        end
        if org.pneumothorax and org.pneumothorax > 0 then
            org.pneumothorax = math.max(org.pneumothorax - dt * 2, 0)
        end
        if org.o2 then
            org.o2[1] = org.o2.range or 100
        end
        org.lungsfunction = true
    end
end)

-- ── Suit lapel shield ────────────────────────────────────────────────────────
-- John raises his lapel to block incoming bullets.
-- Requires the player to bind a key to "jwick_shield" (hold to activate).
-- Same pattern as ZCity's hg_kick concommand — bind it in console:
--   bind <key> "+jwick_shield"
-- Drains stamina while held; regenerates when released.
-- Blocks IN_ATTACK while shielding so John can't fire simultaneously.


-- Think: drain/regen stamina, block firing, sync to client
local shieldNextThink = 0
local shieldLastThink = CurTime()
local SHIELD_THINK_INTERVAL = 0.05
hook.Add("Think", "JWick_ShieldThink", function()
    local now = CurTime()
    if now < shieldNextThink then return end
    local dt = math.max(now - shieldLastThink, 0)
    shieldLastThink = now
    shieldNextThink = now + SHIELD_THINK_INTERVAL

    for _, ply in ipairs(player.GetAll()) do
        local isJohnEvent = JWick.Active and ply.JWickRole == "john"
        local isJohnClass = ply.PlayerClassName == "John"
        if not isJohnEvent and not isJohnClass then continue end
        if not IsValid(ply) or not ply:Alive() then continue end
        ply.JWick_ShieldStamina = ply.JWick_ShieldStamina or SHIELD_MAX

        if ply.JWick_Shielding and ply.JWick_ShieldStamina >= SHIELD_MIN_TO_USE then
            ply.JWick_ShieldStamina = math.max(ply.JWick_ShieldStamina - SHIELD_DRAIN * dt, 0)
            if ply.JWick_ShieldStamina < SHIELD_MIN_TO_USE then
                ply.JWick_Shielding = false
            end
        else
            ply.JWick_Shielding = false
            ply.JWick_ShieldStamina = math.min(ply.JWick_ShieldStamina + SHIELD_REGEN * dt, SHIELD_MAX)
        end

        ply:SetNWFloat("JWick_ShieldStamina", ply.JWick_ShieldStamina)
        ply:SetNWBool("JWick_Shielding",      ply.JWick_Shielding or false)
    end
end)

-- Block firing while shield is raised via SetupMove
hook.Add("SetupMove", "JWick_ShieldInput", function(ply, mv, cmd)
    local isJohnEvent = JWick.Active and ply.JWickRole == "john"
    local isJohnClass = ply.PlayerClassName == "John"
    if not isJohnEvent and not isJohnClass then return end
    if not ply.JWick_Shielding then return end
    cmd:RemoveKey(IN_ATTACK)
end)

-- Reset on death or event end
hook.Add("PlayerDeath", "JWick_ShieldReset", function(ply)
    if ply.JWickRole ~= "john" and ply.PlayerClassName ~= "John" then return end
    ply.JWick_Shielding     = false
    ply.JWick_ShieldStamina = SHIELD_MAX
end)

-- ── Bulletproof suit ──────────────────────────────────────────────────────────

hook.Add("PreHomigradDamage", "JWick_BulletproofSuit", function(ply, dmgInfo, hitgroup, ent, harm)
    local john = ResolveJohnPly(ply, ent)
    if not john then return end

    -- Only apply suit outside event if player has John class
    if not JWick.Active and john.PlayerClassName ~= "John" then return end
    if not john then return end

    -- Headshots handled at organ level via PreTraceOrganBulletDamage
    -- (skull/brain intercept above). Just pass through here.
    if hitgroup == HITGROUP_HEAD or hitgroup == 1 then return end

    -- Explosions and fire bypass suit
    if dmgInfo:IsDamageType(DMG_BLAST) or dmgInfo:IsDamageType(DMG_BURN) then return end

    -- Check ammo type from inflictor weapon
    local inflictor = dmgInfo:GetInflictor()
    local ammoType  = ""
    if IsValid(inflictor) and inflictor:IsWeapon() and inflictor.Primary then
        ammoType = string.lower(inflictor.Primary.Ammo or "")
    end

    -- Shield (lapel raised) — blocks all body shots
    if john.JWick_Shielding then
        dmgInfo:ScaleDamage(SHIELD_DAMAGE_MUL)
        net.Start("JWick_SetRole") net.WriteString("blocked") net.Send(john)
        return
    end

    -- Suit body protection
    if HIGH_CALIBER[ammoType] then
        dmgInfo:ScaleDamage(HIGHCAL_BODY_SCALE)
    elseif LOWCAL_BLOCK then
        dmgInfo:ScaleDamage(0)
        net.Start("JWick_SetRole") net.WriteString("blocked") net.Send(john)
    end
end)

-- ── VIP weapon restriction ───────────────────────────────────────────────────
-- VIP can only pick up handguns — no rifles, SMGs, or heavy weapons.

local VIP_ALLOWED_AMMO = {
    ["9x19 mm parabellum"] = true,
    ["9x19mm parabellum"]  = true,
    ["9x18 mm"]            = true,
    ["9x17 mm"]            = true,
    ["4.6x30 mm"]          = true,
    ["7.65x17 mm"]         = true,
    [".40 sw"]             = true,
    [".45 acp"]            = true,
    [".38 special"]        = true,
    [".357 magnum"]        = true,
    [".50 action express"] = true,
}

hook.Add("PlayerCanPickupWeapon", "JWick_VIPRestrict", function(ply, wep)
    if not JWick.Active then return end
    if not IsValid(ply) or ply.JWickRole ~= "vip" then return end

    -- Always allow utility items with no ammo type
    if not wep.Primary then return end
    local ammo = string.lower(wep.Primary.Ammo or "")
    if ammo == "" or ammo == "none" then return end

    -- Block anything that isn't a pistol-caliber weapon
    if not VIP_ALLOWED_AMMO[ammo] then
        return false
    end
end)

-- ── Headshot debug ───────────────────────────────────────────────────────────
-- Prints every hit on John with hitgroup, bone, ammo, and damage.
-- Remove once headshots are confirmed working.

hook.Add("HomigradDamage", "JWick_HeadshotDebug", function(ply, dmgInfo, hitgroup, ent, harm)
    if not JWick.Active then return end
    local john = ResolveJohnPly(ply, ent)
    if not john then return end

    local inflictor = dmgInfo:GetInflictor()
    local ammo = ""
    if IsValid(inflictor) and inflictor:IsWeapon() and inflictor.Primary then
        ammo = inflictor.Primary.Ammo or ""
    end

    print(string.format(
        "[JWick Debug] Hit John | hitgroup=%s (HITGROUP_HEAD=%s) | dmg=%.1f | ammo=%s | ply_arg=%s | ent_arg=%s",
        tostring(hitgroup),
        tostring(HITGROUP_HEAD),
        dmgInfo:GetDamage(),
        ammo,
        IsValid(ply) and ply:GetClass() or "invalid",
        IsValid(ent) and ent:GetClass() or "invalid"
    ))
end)

-- PreHomigradDamage debug — confirms headshot bypass is reached
hook.Add("PreHomigradDamage", "JWick_PreDebug", function(ply, dmgInfo, hitgroup, ent, harm)
    if not JWick.Active then return end
    local john = ResolveJohnPly(ply, ent)
    if not john then return end
    if hitgroup ~= HITGROUP_HEAD and hitgroup ~= 1 then return end
    print(string.format(
        "[JWick HeadshotDebug] PRE-hook headshot | dmg_before_suit=%.1f | will_bypass=%s",
        dmgInfo:GetDamage(),
        tostring(hitgroup == HITGROUP_HEAD or hitgroup == 1)
    ))
end)

-- ── Win conditions ────────────────────────────────────────────────────────────

local function CheckWinCondition()
    if not JWick.Active then return end

    if not IsValid(JWick.John) or not JWick.John:Alive() then
        PrintMessage(HUD_PRINTTALK, "[J.WICK] John Wick has been eliminated! Guards win!")
        JWick.Active = false
        net.Start("JWick_End") net.WriteString("guards") net.Broadcast()
        return
    end

    if not IsValid(JWick.VIP) or not JWick.VIP:Alive() then
        PrintMessage(HUD_PRINTTALK, "[J.WICK] The VIP has been eliminated! John Wick wins!")
        JWick.Active = false
        net.Start("JWick_End") net.WriteString("john") net.Broadcast()
        return
    end
end

hook.Add("PlayerDeath", "JWick_DeathDebug", function(ply)
    if ply.JWickRole == "john" then
        print("[JWick] John died — killer: " .. 
            (IsValid(ply:GetObserverTarget()) and ply:GetObserverTarget():Nick() or "unknown"))
    end
end)

hook.Add("PlayerDeath", "JWick_WinCheck", function(ply)
    timer.Simple(0.5, CheckWinCondition)
end)

-- Clean up roles on disconnect
hook.Add("PlayerDisconnected", "JWick_Cleanup", function(ply)
    if ply.JWickRole then ply.JWickRole = nil end
    timer.Simple(0.5, CheckWinCondition)
end)

-- ── End event ─────────────────────────────────────────────────────────────────

function EndEvent()
    JWick.Active = false

    -- Reset John's model back via SetPlayerClass so ZCity restores appearance
    if IsValid(JWick.John) and JWick.John:Alive() then
        local class = JWick.John.PlayerClassName or "Rebel"
        timer.Simple(0.1, function()
            if IsValid(JWick.John) then
                JWick.John:SetPlayerClass(class)
            end
        end)
    end

    JWick.John = nil
    JWick.VIP  = nil

    for _, ply in ipairs(player.GetAll()) do
        ply.JWickRole     = nil
        ply.JWick_Shielding    = false
        ply.JWick_ShieldStamina = SHIELD_MAX
    end
    net.Start("JWick_End") net.WriteString("manual") net.Broadcast()
    PrintMessage(HUD_PRINTTALK, "[J.WICK] Event ended.")
end

-- ── Chat commands handled by sh_ulx_jwick.lua ───────────────────────────────
-- !jwick, !jwickset, !jwickend are all registered there via ULX.
-- Do NOT add a duplicate HG_PlayerSay hook here — it would double-fire.
