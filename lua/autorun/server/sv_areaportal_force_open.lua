if CLIENT then return end

ZC_AreaPortalsForce = ZC_AreaPortalsForce or {}

local API = ZC_AreaPortalsForce

local CV_ENABLED_NAME = "zc_areaportals_force_open"
local CV_INTERVAL_NAME = "zc_areaportals_force_open_interval"

local cvEnabled = ConVarExists(CV_ENABLED_NAME)
    and GetConVar(CV_ENABLED_NAME)
    or CreateConVar(CV_ENABLED_NAME, "1", FCVAR_ARCHIVE, "Force all func_areaportal entities open continuously.", 0, 1)

local cvInterval = ConVarExists(CV_INTERVAL_NAME)
    and GetConVar(CV_INTERVAL_NAME)
    or CreateConVar(CV_INTERVAL_NAME, "10", FCVAR_ARCHIVE, "Seconds between areaportal open refreshes.", 2, 120)

local function IsEnabled()
    return cvEnabled and cvEnabled:GetBool() or false
end

local function IsWhitelistedMap()
    local map = string.lower(game.GetMap() or "")
    if string.find(map, "_town_", 1, true) ~= nil then return true end
    if string.match(map, "^d3_c17_") then return true end
    return false
end

local function OpenAllAreaPortals()
    if not IsWhitelistedMap() then return 0 end

    local count = 0
    for _, portal in ipairs(ents.FindByClass("func_areaportal")) do
        if not IsValid(portal) then continue end
        portal:Fire("Open")
        count = count + 1
    end
    return count
end

local function RefreshTimer()
    if not IsWhitelistedMap() then
        timer.Remove("ZC_AreaPortalsForceOpenTick")
        return
    end

    local interval = cvInterval and cvInterval:GetFloat() or 10
    interval = math.max(2, interval)

    if timer.Exists("ZC_AreaPortalsForceOpenTick") then
        timer.Adjust("ZC_AreaPortalsForceOpenTick", interval, 0)
        return
    end

    timer.Create("ZC_AreaPortalsForceOpenTick", interval, 0, function()
        if not IsEnabled() then return end
        OpenAllAreaPortals()
    end)
end

function API.SetEnabled(enabled)
    local val = enabled and "1" or "0"
    RunConsoleCommand(CV_ENABLED_NAME, val)

    if enabled then
        local opened = OpenAllAreaPortals()
        return opened
    end

    return 0
end

function API.IsEnabled()
    return IsEnabled()
end

function API.OpenNow()
    return OpenAllAreaPortals()
end

hook.Add("InitPostEntity", "ZC_AreaPortalsForceOpen_Init", function()
    RefreshTimer()
    if not IsWhitelistedMap() then return end
    if not IsEnabled() then return end
    timer.Simple(0, OpenAllAreaPortals)
end)

hook.Add("PostCleanupMap", "ZC_AreaPortalsForceOpen_PostCleanup", function()
    RefreshTimer()
    if not IsWhitelistedMap() then return end
    if not IsEnabled() then return end
    timer.Simple(0, OpenAllAreaPortals)
end)

cvars.AddChangeCallback(CV_ENABLED_NAME, function(_, _, newValue)
    if tonumber(newValue) ~= 1 then return end
    OpenAllAreaPortals()
end, "ZC_AreaPortalsForceOpenEnabled")

cvars.AddChangeCallback(CV_INTERVAL_NAME, function()
    RefreshTimer()
end, "ZC_AreaPortalsForceOpenInterval")
