if CLIENT then return end

ZC_SteamNameCache = ZC_SteamNameCache or {}

local function ToSteamID64(networkid)
    networkid = tostring(networkid or "")
    if networkid == "" or networkid == "BOT" then return nil end
    if string.match(networkid, "^%d+$") then return networkid end
    if util and util.SteamIDTo64 then
        local sid64 = util.SteamIDTo64(networkid)
        if sid64 and sid64 ~= "0" then
            return sid64
        end
    end
    return nil
end

local function CacheSteamNameFromConnect(data)
    if not istable(data) then return end

    local sid64 = ToSteamID64(data.networkid)
    if not sid64 then return end

    local name = tostring(data.name or "")
    if name == "" then return end

    ZC_SteamNameCache[sid64] = name
end

gameevent.Listen("player_connect")
hook.Add("player_connect", "ZC_SteamNameCache_PlayerConnect", CacheSteamNameFromConnect)

hook.Add("PlayerInitialSpawn", "ZC_SteamNameCache_InitialSpawnFallback", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local sid64 = ply:SteamID64()
    if not sid64 or sid64 == "" then return end
    if ZC_SteamNameCache[sid64] and ZC_SteamNameCache[sid64] ~= "" then return end

    ZC_SteamNameCache[sid64] = tostring((ply.Nick and ply:Nick()) or (ply.Name and ply:Name()) or "Unknown")
end)

function ZC_GetSteamName(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return "Unknown" end

    local sid64 = ply:SteamID64()
    if sid64 and sid64 ~= "" then
        local cached = ZC_SteamNameCache[sid64]
        if cached and cached ~= "" then
            return tostring(cached)
        end
    end

    return tostring((ply.Nick and ply:Nick()) or (ply.Name and ply:Name()) or "Unknown")
end
