local NADECLASS = "weapon_hg_grenade_tpik"
local CLASS = player.RegClass("smodpmc")
local random_lines = {}
for i = 1, 34 do random_lines[i] = "playerclasses/pmc/" .. i .. ".mp3" end
local pain_lines = {}
for i = 1, 16 do pain_lines[i] = "playerclasses/pmc/pain" .. i .. ".mp3" end
local burn_lines = {}
for i = 12, 16 do burn_lines[i] = "playerclasses/pmc/pain" .. i .. ".mp3" end
local moan_lines = {}
for i = 1, 13 do moan_lines[i] = "playerclasses/pmc/moan" .. i .. ".mp3" end
local desertMaps = {}
local DESERT_FILE = "pmc_desert_maps.txt"
if SERVER then
    local content = file.Read(DESERT_FILE, "DATA")
    if content then
        for mapName in string.gmatch(content, "[^\n]+") do
            mapName = mapName:Trim()
            if mapName ~= "" then
                desertMaps[mapName] = true
            end
        end
    end
    local function SaveDesertMaps()
        local lines = {}
        for mapName, isDesert in pairs(desertMaps) do
            if isDesert then
                table.insert(lines, mapName)
            end
        end
        file.Write(DESERT_FILE, table.concat(lines, "\n"))
    end
    concommand.Add("zcitypmc_thismapisdesert", function(ply, cmd, args)
        local map = game.GetMap()
        desertMaps[map] = not desertMaps[map]
        local status = desertMaps[map] and "DESERT" or "NORMAL"
        print("[PMC] Map " .. map .. " is now marked as " .. status)
        SaveDesertMaps()
        if IsValid(ply) then
            ply:ChatPrint("Map " .. map .. " desert mode: " .. tostring(desertMaps[map]) .. " (saved)")
        end
    end)
end
function CLASS.Off(self)
    if CLIENT then return end
end
function CLASS.Guilt(self, Victim)
    if CLIENT then return end
    if Victim:GetPlayerClass() == self:GetPlayerClass() then return 1 end
    return 1
end
hook.Add("HG_PlayerFootstep", "pmc_footsteps", function(ply, pos, foot, sound, volume, rf)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply.PlayerClassName ~= "smodpmc" then return end
    local ent = hg.GetCurrentCharacter(ply)
    if not (ply:IsWalking() or ply:Crouching()) and ent == ply then
        local snd = "zcitysnd/" .. string.Replace(sound, "player/footsteps", "player/footsteps_military/")
        if SoundDuration(snd) <= 0 then snd = sound end
        EmitSound(snd, pos, ply:EntIndex(), CHAN_AUTO, volume, 75, nil, math.random(95, 105))
        return true
    end
end)
local pmc_subclasses = {
    medic = {
        weapons = {
            {weapon = "weapon_mp7", ammo_mult = 3},
            {weapon = "weapon_bandage_sh"},
            {weapon = "weapon_bigbandage_sh"},
            {weapon = "weapon_bloodbag"},
            {weapon = "weapon_needle"},
            {weapon = "weapon_medkit_sh"},
            {weapon = "weapon_morphine"},
            {weapon = "weapon_painkillers"},
            {weapon = "weapon_tourniquet"},
        },
        armor = {"ent_armor_vest3"},
        nade = {{class = NADECLASS, count = 0}},
    },
    cqb = {
        weapons = {{weapon = "weapon_m590a1", ammo_mult = 4}},
        armor = {"ent_armor_vest1"},
        nade = {{class = NADECLASS, count = 4}},
    },
    marksman = {
        weapons = {{weapon = "weapon_mini14", ammo_mult = 4}},
        armor = {"ent_armor_vest3"},
        nade = {},
    },
    assault = {
        weapons = {{weapon = "weapon_m4a1", ammo_mult = 5}},
        armor = {"ent_armor_vest1"},
        nade = {{class = NADECLASS, count = 2}},
    },
    support = {
        weapons = {{weapon = "weapon_m249", ammo_mult = 6}},
        armor = {"ent_armor_vest1"},
        nade = {{class = NADECLASS, count = 2}},
    },
    sniper = {
        weapons = {{weapon = "weapon_sr25", ammo_mult = 3}},
        armor = {"ent_armor_vest3"},
        nade = {{class = NADECLASS, count = 0}},
    },
}
local function giveSubClassLoadout(ply, subclass)
    local cfg = pmc_subclasses[subclass]
    if not cfg then return end
    for _, item in ipairs(cfg.weapons) do
        if item.weapon_random_pool then
            local randWep = item.weapon_random_pool[math.random(#item.weapon_random_pool)]
            local wep = ply:Give(randWep)
            if wep and item.ammo_mult then
                ply:GiveAmmo(wep:GetMaxClip1() * item.ammo_mult, wep:GetPrimaryAmmoType(), true)
            end
        else
            local wep = ply:Give(item.weapon)
            if wep then
                if item.ammo_mult then
                    ply:GiveAmmo(wep:GetMaxClip1() * item.ammo_mult, wep:GetPrimaryAmmoType(), true)
                end
                if item.attachment then
                    hg.AddAttachmentForce(ply, wep, item.attachment)
                end
            end
        end
    end
    for _, nadeData in ipairs(cfg.nade or {}) do
        local wep = ply:Give(nadeData.class)
        if IsValid(wep) and nadeData.count then
            wep.count = nadeData.count
        end
    end
    for _, armorName in ipairs(cfg.armor or {}) do
        hg.AddArmor(ply, armorName)
    end
hg.AddArmor(ply, "ent_armor_helmet5")
ply:SyncArmor()
end
function CLASS.On(self, data)
    if CLIENT then return end
    ApplyAppearance(self, nil, nil, nil, true)
    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    Appearance.AAttachments = ""
    Appearance.AClothes = ""
    self:SetNetVar("Accessories", "")
    self:SetSubMaterial()
    self.CurAppearance = Appearance
    self:SetNWString("PlayerName","PMC "..Appearance.AName)
    self:SetPlayerColor(Color(0,0,137):ToVector())
    local map = game.GetMap()
    if desertMaps[map] then
        self:SetModel("models/smod_tactical/player/pmc_01.mdl")
    else
        self:SetModel("models/smod_tactical/player/pmc_02.mdl")
    end
self:SetBodygroup(2,0)
self:SetBodygroup(3,math.random(0,1))
    self:Give("weapon_walkie_talkie")
    self:Give("weapon_melee")
    local inv = self:GetNetVar("Inventory", {})
    inv["Weapons"] = inv["Weapons"] or {}
    inv["Weapons"]["hg_sling"] = true
    self:SetNetVar("Inventory", inv)
local pistol = self:Give("weapon_m9beretta")
    if pistol then
        self:GiveAmmo(pistol:GetMaxClip1() * 4, pistol:GetPrimaryAmmoType(), true)
    end
    local subclasses = {"medic", "cqb", "marksman", "assault", "support", "sniper"}
    local chosen = subclasses[math.random(#subclasses)]
    giveSubClassLoadout(self, chosen)
    local inv = self:GetNetVar("Inventory", {})
    inv["Weapons"] = inv["Weapons"] or {}
    inv["Weapons"]["hg_sling"] = true
    self:SetNetVar("Inventory", inv)
end
local function giveSubClassLoadout(ply, subclass)
    local cfg = pmc_subclasses[subclass]
    if not cfg then return end

    for _, item in ipairs(cfg.weapons) do
        local wepClass = item.weapon
        if item.weapon_random_pool then
            wepClass = item.weapon_random_pool[math.random(#item.weapon_random_pool)]
        end
        local wep = ply:Give(wepClass)
        if IsValid(wep) then
            if item.ammo_mult and wep.GetMaxClip1 then
                ply:GiveAmmo(wep:GetMaxClip1() * item.ammo_mult, wep:GetPrimaryAmmoType(), true)
            end
            if item.remove_attachments or item.attachment then
                timer.Simple(0, function()
                    if IsValid(wep) and IsValid(ply) and wep:GetOwner() == ply then
                        -- Remove unwanted attachments first
                        if item.remove_attachments then
                            for _, att in ipairs(item.remove_attachments) do
                                RemoveAttachmentFromWeapon(wep, att)
                            end
                        end
                        -- Add desired attachment
                        if item.attachment then
                            hg.AddAttachmentForce(wep, ply, item.attachment)
                        end
                    end
                end)
            end
        end
    end
  for _, nadeData in ipairs(cfg.nade or {}) do
        local wep = ply:Give(nadeData.class)
        if IsValid(wep) and nadeData.count then
            wep.count = nadeData.count
        end
    end
    for _, armorName in ipairs(cfg.armor or {}) do
        hg.AddArmor(ply, armorName)
    end
    ply:SyncArmor()
end
hook.Add("HG_ReplacePhrase", "PMCPhrases", function(ent, phrase, pitch)
    local ply = ent:IsPlayer() and ent or (ent:IsRagdoll() and hg.RagdollOwner(ent))
    if not IsValid(ply) or ply.PlayerClassName ~= "smodpmc" then return end
    local org = ply.organism
    local inpainscream = org and org.pain > 60 and org.pain < 100
    local inpain = org and org.pain > 100
    local new_phrase
    if inpainscream then
        new_phrase = table.Random(pain_lines)
    elseif inpain then
        new_phrase = table.Random(moan_lines)
    else
        new_phrase = table.Random(random_lines)
    end
    ply._nextSound = inpain and (inpainscream and table.Random(pain_lines) or table.Random(moan_lines)) or table.Random(random_lines)
    return ent, new_phrase, muffed, pitch
end)
hook.Add("HG_ReplaceBurnPhrase", "PMCBurnPhrases", function(ply, phrase)
    if ply.PlayerClassName ~= "smodpmc" then return end
        return ply, table.Random(burn_lines)
end)
return CLASS