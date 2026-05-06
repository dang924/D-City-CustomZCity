-- sh_dod_gamemode.lua — Day of Defeat shared definitions (loadable on demand)

zb = zb or {}
zb.Points = zb.Points or {}

-- ── Map point groups ───────────────────────────────────────────────────────────
-- Spawn points reuse TDM's existing groups.
-- Flag zones use DOD_FLAG_1 through DOD_FLAG_8.

for i = 1, 8 do
    local key = "DOD_FLAG_" .. i
    zb.Points[key] = zb.Points[key] or {}
    zb.Points[key].Color = Color(200, 200, 50)
    zb.Points[key].Name  = key
end

-- ── Flag state constants ───────────────────────────────────────────────────────

DOD_STATE_NEUTRAL   = 0   -- grey, uncaptured
DOD_STATE_TEAM0     = 1   -- owned by team 0 (Axis / T)
DOD_STATE_TEAM1     = 2   -- owned by team 1 (Allies / CT)
DOD_STATE_CONTESTED = 3   -- being actively fought over (UI hint only)

-- ── Team identity ─────────────────────────────────────────────────────────────

DOD_TEAM = {
    [0] = { name = "Axis",   color = Color(180, 60,  60),  playerclass = "terrorist", role = "Axis",   roleColor = Color(180, 60, 60)  },
    [1] = { name = "Allies", color = Color(60,  100, 180), playerclass = "swat",      role = "Allies", roleColor = Color(60, 100, 180) },
}

-- ── DoD class definitions (shared so client can read them for the picker UI) ──

DOD_CLASSES = {
    {
        id          = "rifleman",
        name        = "Rifleman",
        desc        = "Standard infantry. Reliable bolt-action rifle, good at mid range.",
        weapons     = {
            [0] = { "weapon_kar98",  "weapon_p38",       "weapon_m67",       "weapon_bandage_sh", "weapon_tourniquet" },
            [1] = { "weapon_752_m1garand", "weapon_m1911", "weapon_m67",      "weapon_bandage_sh", "weapon_tourniquet" },
        },
        attachments = {},
        armor       = { "vest2", "helmet1" },
        maxPerTeam  = nil,  -- unlimited
    },
    {
        id          = "assault",
        name        = "Assault",
        desc        = "Close-quarters fighter. Submachine gun with high rate of fire.",
        weapons     = {
            [0] = { "weapon_mp40",   "weapon_p38",       "weapon_m67",       "weapon_bandage_sh", "weapon_tourniquet" },
            [1] = { "weapon_thompson","weapon_m1911",    "weapon_m67",       "weapon_bandage_sh", "weapon_tourniquet" },
        },
        attachments = {},
        armor       = { "vest3", "helmet1" },
        maxPerTeam  = nil,
    },
    {
        id          = "support",
        name        = "Support",
        desc        = "Versatile rifleman with an automatic rifle. Good suppression capability.",
        weapons     = {
            [0] = { "weapon_akm",    "weapon_p38",       "weapon_m67",       "weapon_bandage_sh", "weapon_tourniquet" },
            [1] = { "weapon_m4a1",   "weapon_m1911",     "weapon_m67",       "weapon_bandage_sh", "weapon_tourniquet" },
        },
        attachments = {},
        armor       = { "vest3", "helmet1" },
        maxPerTeam  = nil,
    },
    {
        id          = "machinegunner",
        name        = "Machine Gunner",
        desc        = "Heavy suppression. Powerful LMG but slow movement. 2 per team max.",
        weapons     = {
            [0] = { "weapon_pkm",    "weapon_p38",       "weapon_bandage_sh", "weapon_tourniquet" },
            [1] = { "weapon_m249",   "weapon_m1911",     "weapon_bandage_sh", "weapon_tourniquet" },
        },
        attachments = {},
        armor       = { "vest4" },
        maxPerTeam  = 2,
    },
    {
        id          = "sniper",
        name        = "Sniper",
        desc        = "Long-range precision. Effective at distance, vulnerable up close. 2 per team max.",
        weapons     = {
            [0] = { "weapon_kar98",  "weapon_p38",       "weapon_bandage_sh", "weapon_tourniquet" },
            [1] = { "weapon_svd",    "weapon_m1911",     "weapon_bandage_sh", "weapon_tourniquet" },
        },
        attachments = {
            [0] = { "optic12" },
            [1] = {},
        },
        armor       = { "vest1" },
        maxPerTeam  = 2,
    },
    {
        id          = "rocket",
        name        = "Rocket",
        desc        = "Anti-armour and suppression. RPG-7 with limited ammo. 1 per team max.",
        weapons     = {
            [0] = { "weapon_hg_rpg", "weapon_skorpion",  "weapon_bandage_sh", "weapon_tourniquet" },
            [1] = { "weapon_hg_rpg", "weapon_skorpion",  "weapon_bandage_sh", "weapon_tourniquet" },
        },
        attachments = {},
        armor       = { "vest2", "helmet1" },
        maxPerTeam  = 1,
    },
}

-- Fast lookup by id
DOD_CLASS_BY_ID = {}
for _, cls in ipairs(DOD_CLASSES) do
    DOD_CLASS_BY_ID[cls.id] = cls
end

-- ── Net strings ───────────────────────────────────────────────────────────────

if SERVER then
    util.AddNetworkString("DOD_FlagSync")
    util.AddNetworkString("DOD_FlagInit")
    util.AddNetworkString("DOD_WaveCountdown")
    util.AddNetworkString("DOD_MatchScore")
    util.AddNetworkString("DOD_RoundResult")
    util.AddNetworkString("DOD_SelectClass")
    util.AddNetworkString("DOD_ClassState")
    util.AddNetworkString("DOD_OpenClassPicker")
    util.AddNetworkString("DOD_OpenTeamPicker")
    util.AddNetworkString("DOD_JoinTeam")
    util.AddNetworkString("DOD_TeamCounts")
    util.AddNetworkString("DOD_LoadoutEditor_Open")
    util.AddNetworkString("DOD_LoadoutEditor_List")
    util.AddNetworkString("DOD_LoadoutEditor_Edit")
    util.AddNetworkString("DOD_LoadoutEditor_Saved")
    util.AddNetworkString("DOD_ConfigMenu_Open")
    util.AddNetworkString("DOD_ConfigMenu_Request")
    util.AddNetworkString("DOD_ConfigMenu_State")
    util.AddNetworkString("DOD_ConfigMenu_Apply")
end

print("[DoD] Shared definitions loaded")
