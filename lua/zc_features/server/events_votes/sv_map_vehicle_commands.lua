if CLIENT then return end

-- Spawns a vehicle for players on maps that require one (e.g. d2_coast).
-- !car  → d2_coast_01 through d2_coast_10  (simfphys car, randomized)
-- One car per player at a time; old car is removed when a new one is requested.
-- 30-second per-player cooldown to prevent spam.

local CAR_CLASSES = {
    "sim_fphys_v8elite",
    "sim_fphys_pwvolga",
    "sim_fphys_pwhatchback",
}

local CAR_MAPS = {
    ["d2_coast_01"] = true,
    ["d2_coast_02"] = true,
    ["d2_coast_03"] = true,
    ["d2_coast_04"] = true,
    ["d2_coast_04_d"] = true,
    ["d2_coast_05"] = true,
    ["d2_coast_06"] = true,
    ["d2_coast_07"] = true,
    ["d2_coast_08"] = true,
    ["d2_coast_09"] = true,
    ["d2_coast_10"] = true,
}

local SPAWN_OFFSET_FORWARD = 150 -- units in front
local SPAWN_OFFSET_UP      = 30  -- units above ground
local COOLDOWN             = 30  -- seconds between spawns per player

local playerCooldowns = {}  -- [steamid] = next allowed spawn time
local playerCars      = {}  -- [steamid] = owned car entity

local function currentMap()
    return string.lower(game.GetMap())
end

local function steamKey(ply)
    return ply:SteamID64() or tostring(ply:EntIndex())
end

local function removePlayerCar(key)
    local car = playerCars[key]
    if IsValid(car) then
        car:Remove()
    end
    playerCars[key] = nil
end

local function shuffledCarClasses()
    local classes = table.Copy(CAR_CLASSES)

    for index = #classes, 2, -1 do
        local swapIndex = math.random(index)
        classes[index], classes[swapIndex] = classes[swapIndex], classes[index]
    end

    return classes
end

local function spawnConfiguredCar(class, spawnPos, spawnAng)
    if simfphys and simfphys.SpawnVehicleSimple then
        local ok, vehicle = pcall(simfphys.SpawnVehicleSimple, class, spawnPos, spawnAng)
        if ok and IsValid(vehicle) then
            return vehicle, nil
        end
    end

    local vehicle = ents.Create(class)
    if not IsValid(vehicle) then
        return nil, "unknown class '" .. class .. "'"
    end

    vehicle:SetPos(spawnPos)
    vehicle:SetAngles(spawnAng)
    vehicle:Spawn()
    vehicle:Activate()

    if not IsValid(vehicle) then
        return nil, "spawn failed for class '" .. class .. "'"
    end

    return vehicle, nil
end

local function spawnCarFor(ply)
    if not IsValid(ply) or not ply:Alive() then
        ply:ChatPrint("[!car] You must be alive to spawn a car.")
        return
    end

    local map = currentMap()
    if not CAR_MAPS[map] then
        ply:ChatPrint("[!car] Cars are not available on this map.")
        return
    end

    local key = steamKey(ply)
    local now = CurTime()

    if (playerCooldowns[key] or 0) > now then
        local remain = math.ceil(playerCooldowns[key] - now)
        ply:ChatPrint("[!car] Wait " .. remain .. "s before spawning another car.")
        return
    end

    -- Remove existing car
    removePlayerCar(key)

    -- Spawn in front of the player, on the ground
    local fwd   = ply:GetForward()
    fwd.z       = 0
    if fwd:LengthSqr() < 0.01 then fwd = Vector(1, 0, 0) end
    fwd:Normalize()

    local spawnPos = ply:GetPos() + fwd * SPAWN_OFFSET_FORWARD + Vector(0, 0, SPAWN_OFFSET_UP)

    -- Trace down to snap to ground
    local tr = util.TraceLine({
        start  = spawnPos + Vector(0, 0, 64),
        endpos = spawnPos - Vector(0, 0, 256),
        mask   = MASK_SOLID_BRUSHONLY,
    })
    if tr.Hit then
        spawnPos = tr.HitPos + Vector(0, 0, SPAWN_OFFSET_UP)
    end

    local spawnAng = Angle(0, ply:GetAngles().y, 0)
    local car
    local lastError = "no configured vehicle could be spawned"

    for _, class in ipairs(shuffledCarClasses()) do
        car, lastError = spawnConfiguredCar(class, spawnPos, spawnAng)
        if IsValid(car) then
            break
        end
    end

    if not IsValid(car) then
        ply:ChatPrint("[!car] Failed to spawn vehicle (" .. lastError .. ").")
        return
    end

    playerCars[key]      = car
    playerCooldowns[key] = now + COOLDOWN

    ply:ChatPrint("[!car] Your car has been spawned.")
end

-- Register via chat command router or fall back to direct HG_PlayerSay hook
local function handleCarCommand(ply)
    spawnCarFor(ply)
    return true -- consume the message
end

if ZC_RegisterExactChatCommand then
    ZC_RegisterExactChatCommand("!car", handleCarCommand)
else
    hook.Add("HG_PlayerSay", "DCityPatch_MapCarCommand", function(ply, txtTbl, text)
        if string.lower(string.Trim(text)) ~= "!car" then return end
        handleCarCommand(ply)
        return ""
    end)
end

-- Clean up on disconnect
hook.Add("PlayerDisconnected", "DCityPatch_MapCarCleanup", function(ply)
    local key = steamKey(ply)
    removePlayerCar(key)
    playerCooldowns[key] = nil
end)
