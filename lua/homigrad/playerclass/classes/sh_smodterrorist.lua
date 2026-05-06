local NADECLASS = "weapon_hg_grenade_tpik"
local CLASS = player.RegClass("smodterrorist")
local random_lines = {}
for i = 1, 166 do random_lines[i] = "playerclasses/smodterrorist/moving-" .. i .. ".wav" end
local pain_lines = {}
for i = 1, 37 do pain_lines[i] = "playerclasses/smodterrorist/pain-" .. i .. ".wav" end
local gear_footsteps = {}
for i = 1, 48 do gear_footsteps[i] = "playerclasses/smodterrorist/gear" .. i .. ".wav" end
local moan_lines = {}
for i = 1, 204 do moan_lines[i] = "playerclasses/smodterrorist/die-" .. i .. ".wav" end
if CLIENT then
    for _, snd in ipairs(gear_footsteps) do
        util.PrecacheSound(snd)
    end
else
    for _, snd in ipairs(gear_footsteps) do
        util.PrecacheSound(snd)
    end
end
function CLASS.Off(self)
    if CLIENT then return end
end
function CLASS.Guilt(self, Victim)
    if CLIENT then return end
    if Victim:GetPlayerClass() == self:GetPlayerClass() then return 1 end
    return 1
end
hook.Add("HG_PlayerFootstep", "smodterrorist_footsteps", function(ply, pos, foot, sound, volume, rf)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply.PlayerClassName ~= "smodterrorist" then return end
    local ent = hg.GetCurrentCharacter(ply)
    if ent == ply then
        if #gear_footsteps == 0 then return end
        local random_sound = gear_footsteps[math.random(#gear_footsteps)]
        local final_volume = math.Clamp(volume * 1.5, 0.5, 1.0)
        EmitSound(random_sound, pos, ply:EntIndex(), CHAN_BODY, final_volume, 100, 0, math.random(95, 105))
        return true
    end
end)
local smodterrorist_subclasses = {
    medic = {
        weapons = {
            { weapon = "weapon_m4a1", ammo_mult = 4 },
{ weapon = "weapon_m9beretta", ammo_mult = 2 },
            {weapon = "weapon_bandage_sh"},
            {weapon = "weapon_bigbandage_sh"},
            {weapon = "weapon_bloodbag"},
            {weapon = "weapon_needle"},
            {weapon = "weapon_medkit_sh"},
            {weapon = "weapon_morphine"},
            {weapon = "weapon_painkillers"},
            {weapon = "weapon_tourniquet"}
        },
        armor = {"ent_armor_vest4"},
        nade = {{class = NADECLASS, count = 2}},
    },
    cqb = {
        weapons = {
            { weapon = "weapon_remington870", ammo_mult = 5 },
            { weapon = "weapon_hk_usp", ammo_mult = 2 }
        },
        armor = {"ent_armor_vest1"},
        nade = {{class = NADECLASS, count = 1}},
    },
    marksman = {
        weapons = {{weapon = "weapon_sr25", ammo_mult = 3},
            { weapon = "weapon_m9beretta", ammo_mult = 2 }
},
        armor = {"ent_armor_vest4"},
        nade = {{class = NADECLASS, count = 1}},
    },
    assault = {
        weapons = {{weapon = "weapon_m4a1", ammo_mult = 4},
            { weapon = "weapon_m9beretta", ammo_mult = 2 }},
        armor = {"ent_armor_vest3"},
        nade = {{class = NADECLASS, count = 2}},
    },
    support = {
        weapons = {{weapon = "weapon_m249", ammo_mult = 5},
{ weapon = "weapon_m9beretta", ammo_mult = 2 }},
        armor = {"ent_armor_vest1"},
        nade = {{class = NADECLASS, count = 2}},
    },
    sniper = {
        weapons = {{weapon = "weapon_m98b", ammo_mult = 2},
            { weapon = "weapon_hk_usp", ammo_mult = 2 }},
        armor = {"ent_armor_vest4"},
        nade = {{class = NADECLASS, count = 0}},
    },
}
local function giveSubClassLoadout(ply, subclass)
    local cfg = smodterrorist_subclasses[subclass]
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
    self:SetPlayerColor(Color(100,0,0):ToVector())
        self:SetModel("models/smod_tactical/combine_shock_trooper"..math.random(1,3)..".mdl")
    self:Give("weapon_walkie_talkie")
    self:Give("weapon_melee")
    local inv = self:GetNetVar("Inventory", {})
    inv["Weapons"] = inv["Weapons"] or {}
    inv["Weapons"]["hg_sling"] = true
    self:SetNetVar("Inventory", inv)
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
hook.Add("HG_ReplacePhrase", "SMODTerroristPhrases", function(ent, phrase, pitch)
    local ply = ent:IsPlayer() and ent or (ent:IsRagdoll() and hg.RagdollOwner(ent))
    if not IsValid(ply) or ply.PlayerClassName ~= "smodterrorist" then return end
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
hook.Add("HG_ReplaceBurnPhrase", "SMODTerroristBurnPhrases", function(ply, phrase)
    if ply.PlayerClassName ~= "smodterrorist" then return end
        return ply, table.Random(moan_lines)
end)
return CLASS