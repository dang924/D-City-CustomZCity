local NADECLASS = "weapon_hg_rgd_tpik"
local CLASS = player.RegClass("islamicterrorist")
local random_lines = {}
for i = 1, 17 do random_lines[i] = "playerclasses/islam/" .. i .. ".mp3" end
local pain_lines = {}
for i = 1, 6 do pain_lines[i] = "playerclasses/islam/pain" .. i .. ".mp3" end
local moan_lines = {}
for i = 1, 4 do moan_lines[i] = "playerclasses/islam/moan" .. i .. ".mp3" end
function CLASS.Off(self)
    if CLIENT then return end
end
local names = {
    "Ali", "Khalid", "Akram", "Majid", "Amir", "Malik", "Alim", "Nasir", "Hamza", "Omar", "Anwar", "Nizar", "Hassan", "Salah", "Farid", "Nawaf", "Hussein", "Tariq", "Marwan", "Omar", "Imran", "Aariz", "Adil", "Osman", "Ismail", "Ashan", "Harun", "Qamar", "Idris", "Basir", "Essa", "Tariq", "Zamir", "Faris", "Hamza", "Iskandar", "Rashid", "Tahir", "Zayn", "Hani", "Samir", "Nasim", "Taj", "Yusuf", "Zaid", "Navid", "Jamal", "Sabri", "Abdullah", "Abdurrahman", "Fayez", "Ilyas", "Kais", "Musa", "Nayef", "Raed", "Safwan", "Talal", "Uzair", "Wahid", "Yaqub", "Zuhair", "Nabeel", "Othman", "Qadir", "Sami", "Yaser", "Zahid", "Ibrahim", "Kareem", "Jalal", "Taha", "Usman", "Waleed", "Yahya", "Zakariya", "Abbas", "Bilal", "Dawood", "Faisal", "Ghaith", "Haris", "Jabir", "Suleiman", "Muhammad", "Rayan", "Ayaan", "Ahmed", "Aiman", "Akbar", "Akram", "Almas", "Amal", "Amani", "Anwar", "Ashfaq", "Ata", "Bassam", "Binyamin", "Ebrahim", "Esmail", "Fadil", "Fahim", "Fakhri", "Haider", "Hamid", "Hasan", "Hasib", "Hidayat", "Idris", "Ihsan", "Imad", "Iksandar", "Jabbar", "Jabr", "Jafar", "Kamal", "Karim", "Khaleel", "Khaled", "Khaliq", "Maalik", "Mahmood", "Malak", "Maytham", "Mirza", "Mukhtar", "Murtaza", "Mustafa", "Nabil", "Nadeem", "Nazim", "Nadir", "Qasim", "Rabi", "Rahman", "Rajab", "Rayyan", "Ridwan", "Safi", "Sakhr", "Salah", "Salman", "Sultan", "Tabassum", "Tahmid", "Talib", "Tarik", "Tufayl", "Wafai", "Wahid", "Walid", "Zafar", "Zahir", "Zakaria", "Zakariyya", "Ziya", "Zulfiqar"
}
local terrorist_subclasses = {
    infantry = {
        weapons = {
            {weapon_random_pool = {"weapon_ak74", "weapon_m16a2"}, ammo_mult = 4},
        },
        armor = {"ent_armor_vest1"},
        nade = { {class = NADECLASS, count = 3} },
    },
    sniper = {
        weapons = {
            {weapon = "weapon_svd", ammo_mult = 4, attachment = "optic11"},
        },
        armor = {},
        nade = {},
    },
    heavy = {
        weapons = {
            {weapon_random_pool = {"weapon_hg_rpg", "weapon_pkm"}, ammo_mult = 5},
        },
        armor = {"ent_armor_vest1"},
        nade = {},
    },
}
local function giveSubClassLoadout(ply, subclass)
    local cfg = terrorist_subclasses[subclass]
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
    local name = table.Random(names)
    self:SetNWString("PlayerName", name)
    self:SetPlayerColor(Color(0,0,0):ToVector())
    self:SetModel("models/player/phoenix.mdl")
    self:Give("weapon_walkie_talkie")
    self:Give("weapon_melee")
    local mak = self:Give("weapon_makarov")
    if mak then
        self:GiveAmmo(mak:GetMaxClip1() * 4, mak:GetPrimaryAmmoType(), true)
    end
    local subclasses = {"sniper", "infantry", "heavy"}
    local chosen = subclasses[math.random(#subclasses)]
    giveSubClassLoadout(self, chosen)
    local inv = self:GetNetVar("Inventory", {})
    inv["Weapons"] = inv["Weapons"] or {}
    inv["Weapons"]["hg_sling"] = true
    self:SetNetVar("Inventory", inv)
end
function CLASS.Guilt(self, Victim)
    if CLIENT then return end
    if Victim:GetPlayerClass() == self:GetPlayerClass() then
        return 1
    end
    return 1
end
hook.Add("HG_ReplacePhrase", "IslamicTerroristPhrases", function(ent, phrase, pitch)
    local ply = ent:IsPlayer() and ent or (ent:IsRagdoll() and hg.RagdollOwner(ent))
    if not IsValid(ply) or ply.PlayerClassName ~= "islamicterrorist" then return end
    local org = ply.organism
    local inpainscream = org and org.pain > 60 and org.pain < 100
    local inpain = org and org.pain > 100
    local new_phrase
    local text_phrase
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
return CLASS