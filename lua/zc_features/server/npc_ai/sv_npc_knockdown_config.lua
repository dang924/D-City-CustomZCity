-- sv_npc_knockdown_config.lua
-- Server-side persistence and scaling for NPC knockdown thresholds.
-- Exposes _G.ZC_GetKnockdownThresholds() for sv_npc_knockdown.lua to call at runtime.
-- Driven by ConVars (FCVAR_ARCHIVE = survives map changes) and editable via !manageclasses.

if CLIENT then return end

util.AddNetworkString("ZC_RequestKnockdownConfig")
util.AddNetworkString("ZC_SendKnockdownConfig")
util.AddNetworkString("ZC_SaveKnockdownConfig")

-- ── ConVars ───────────────────────────────────────────────────────────────────

CreateConVar("zc_knockdown_ref_players",     "4",    FCVAR_ARCHIVE,
    "Reference player count for knockdown threshold scaling.", 0, 128)
CreateConVar("zc_knockdown_harm_base",       "2.10", FCVAR_ARCHIVE,
    "Harm multiplier (dmg/100) required for instant NPC knockdown at reference player count. Higher = harder to knock down.", 0.5, 5.0)
CreateConVar("zc_knockdown_harm_perplayer",  "0.10", FCVAR_ARCHIVE,
    "Additional harm threshold added per player above reference count. Higher value = harder with more players.", 0, 0.5)
CreateConVar("zc_knockdown_blood_base",      "1900", FCVAR_ARCHIVE,
    "Blood level below which an NPC is knocked down at reference player count. Lower = harder to knock down.", 100, 5000)
CreateConVar("zc_knockdown_blood_perplayer", "-100", FCVAR_ARCHIVE,
    "Blood threshold change per player above reference. Negative means threshold falls (harder to trigger knockdown).", -300, 0)
CreateConVar("zc_knockdown_leg_base",        "0.85", FCVAR_ARCHIVE,
    "Leg-damage fraction required for leg-shot knockdown at reference player count. Higher = harder.", 0.3, 2.0)
CreateConVar("zc_knockdown_leg_perplayer",   "0.04", FCVAR_ARCHIVE,
    "Additional leg threshold per player above reference.", 0, 0.2)

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function readFloat(name, fb)
    local cv = GetConVar(name)
    return cv and (tonumber(cv:GetFloat()) or fb) or fb
end

local function readInt(name, fb)
    local cv = GetConVar(name)
    return cv and (tonumber(cv:GetInt()) or fb) or fb
end

local function getActivePlayerCount()
    local n = 0
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Team() ~= TEAM_SPECTATOR then n = n + 1 end
    end
    return n
end

-- ── Config table ──────────────────────────────────────────────────────────────

local function getKnockdownConfig()
    return {
        refPlayers     = math.max(0, readInt  ("zc_knockdown_ref_players",     4)),
        harmBase       = math.Clamp(readFloat ("zc_knockdown_harm_base",       2.10), 0.5, 5.0),
        harmPerPlayer  = math.Clamp(readFloat ("zc_knockdown_harm_perplayer",  0.10), 0,   0.5),
        bloodBase      = math.Clamp(readFloat ("zc_knockdown_blood_base",      1900), 100, 5000),
        bloodPerPlayer = math.Clamp(readFloat ("zc_knockdown_blood_perplayer", -100), -300, 0),
        legBase        = math.Clamp(readFloat ("zc_knockdown_leg_base",        0.85), 0.3, 2.0),
        legPerPlayer   = math.Clamp(readFloat ("zc_knockdown_leg_perplayer",   0.04), 0,   0.2),
    }
end

-- ── Threshold cache ───────────────────────────────────────────────────────────

local THRESH_CACHE_TTL  = 0.2
local threshCacheExpire = 0
local threshCachePacked = { harm = 2.10, blood = 1900, leg = 0.85 }

local function rebuildThreshCache()
    local cfg    = getKnockdownConfig()
    local delta  = getActivePlayerCount() - cfg.refPlayers
    threshCachePacked = {
        harm  = math.Clamp(cfg.harmBase  + delta * cfg.harmPerPlayer,  0.5,  5.0),
        blood = math.Clamp(cfg.bloodBase + delta * cfg.bloodPerPlayer, 100, 5000),
        leg   = math.Clamp(cfg.legBase   + delta * cfg.legPerPlayer,   0.3,  2.0),
    }
    threshCacheExpire = CurTime() + THRESH_CACHE_TTL
end

local function getThresholds()
    if CurTime() >= threshCacheExpire then rebuildThreshCache() end
    return threshCachePacked
end

hook.Add("PostCleanupMap", "ZC_KnockdownConfig_InvalidateCache", function()
    threshCacheExpire = 0
end)

-- ── Globals ───────────────────────────────────────────────────────────────────

_G.ZC_GetKnockdownThresholds = getThresholds
_G.ZC_GetKnockdownConfig     = getKnockdownConfig

-- ── Net: send config to a player ─────────────────────────────────────────────

local function sendKnockdownConfig(ply)
    if not IsValid(ply) then return end
    net.Start("ZC_SendKnockdownConfig")
    net.WriteTable(getKnockdownConfig())
    net.Send(ply)
end

net.Receive("ZC_RequestKnockdownConfig", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    sendKnockdownConfig(ply)
end)

-- ── Net: save config from panel ───────────────────────────────────────────────

net.Receive("ZC_SaveKnockdownConfig", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local p = net.ReadTable() or {}

    local refP  = math.Clamp(math.floor(tonumber(p.refPlayers)     or 4),    0,    128)
    local harmB = math.Clamp(tonumber(p.harmBase)                  or 2.10,  0.5,  5.0)
    local harmD = math.Clamp(tonumber(p.harmPerPlayer)             or 0.10,  0,    0.5)
    local bloB  = math.Clamp(math.floor(tonumber(p.bloodBase)      or 1900), 100, 5000)
    local bloD  = math.Clamp(math.floor(tonumber(p.bloodPerPlayer) or -100), -300,   0)
    local legB  = math.Clamp(tonumber(p.legBase)                   or 0.85,  0.3,  2.0)
    local legD  = math.Clamp(tonumber(p.legPerPlayer)              or 0.04,  0,    0.2)

    RunConsoleCommand("zc_knockdown_ref_players",     tostring(refP))
    RunConsoleCommand("zc_knockdown_harm_base",       string.format("%.2f", harmB))
    RunConsoleCommand("zc_knockdown_harm_perplayer",  string.format("%.3f", harmD))
    RunConsoleCommand("zc_knockdown_blood_base",      tostring(bloB))
    RunConsoleCommand("zc_knockdown_blood_perplayer", tostring(bloD))
    RunConsoleCommand("zc_knockdown_leg_base",        string.format("%.2f", legB))
    RunConsoleCommand("zc_knockdown_leg_perplayer",   string.format("%.3f", legD))

    threshCacheExpire = 0
    sendKnockdownConfig(ply)
end)
