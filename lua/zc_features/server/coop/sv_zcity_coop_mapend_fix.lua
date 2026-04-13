-- Z-City Coop Map End Fix
-- Workaround for maps without trigger_changelevel entities
-- Z-City crashes on maps with no changelevel triggers (attempt to index nil 'map')

if CLIENT then return end

local function hasManagedChangelevelSystem()
    if ZC_MapRoute and isfunction(ZC_MapRoute.ResolveNextMap) then
        return true
    end

    local initHooks = hook.GetTable().InitPostEntity or {}
    if initHooks["ZC_CoopInit_svchangelevelfix"] then
        return true
    end

    return false
end

local function currentRoundIsCoop()
    if not isfunction(CurrentRound) then return false end
    local ok, round = pcall(CurrentRound)
    return ok and istable(round) and round.name == "coop"
end

local function spawnSafeMapEnd(pos, ang, targetMap, mins, maxs)
    local mapend = ents.Create("coop_mapend")
    if not IsValid(mapend) then return false end

    local worldMins = mins
    local worldMaxs = maxs

    if not isvector(worldMins) or not isvector(worldMaxs) then
        local half = Vector(96, 96, 96)
        worldMins = pos - half
        worldMaxs = pos + half
    end

    mapend.min = worldMins
    mapend.max = worldMaxs

    mapend:SetPos(pos)
    mapend:SetAngles(ang or angle_zero)
    if isstring(targetMap) and targetMap ~= "" then
        mapend.map = targetMap
    end
    mapend:Spawn()
    mapend:Activate()

    return IsValid(mapend)
end

local function installLegacyFallback()
    if hasManagedChangelevelSystem() then
        print("[DCityPatch] Legacy coop mapend fallback skipped (managed changelevel system active)")
        return
    end

    hook.Remove("PostCleanupMap", "changelevel_generate")
    hook.Add("PostCleanupMap", "DCityPatch_CoopMapEnd_Safe", function()
        if hasManagedChangelevelSystem() then return end
        if not currentRoundIsCoop() then return end
        if IsValid(ents.FindByClass("coop_mapend")[1]) then return end

        local changelevelEnts = ents.FindByClass("trigger_changelevel")

        if #changelevelEnts > 0 then
            local playerPos = Vector(0, 0, 0)
            local playerCount = 0

            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:Alive() then
                    playerPos = playerPos + ply:GetPos()
                    playerCount = playerCount + 1
                end
            end

            if playerCount > 0 then
                playerPos = playerPos / playerCount
            else
                local spawn = ents.FindByClass("info_player_start")[1]
                if IsValid(spawn) then
                    playerPos = spawn:GetPos()
                end
            end

            local furthestDist = -math.huge
            local furthestEnt = nil

            for _, ent in ipairs(changelevelEnts) do
                if not IsValid(ent) then continue end
                if ent.map == game.GetMap() then continue end

                local min, max = ent:WorldSpaceAABB()
                local center = max - ((max - min) / 2)
                local dist = center:Distance(playerPos)
                if dist > furthestDist then
                    furthestDist = dist
                    furthestEnt = ent
                end
            end

            if IsValid(furthestEnt) then
                local min, max = furthestEnt:WorldSpaceAABB()
                local center = max - ((max - min) / 2)
                if spawnSafeMapEnd(center, furthestEnt:GetAngles(), furthestEnt.map, min, max) then
                    print("[DCityPatch] Legacy fallback created coop_mapend from trigger_changelevel")
                end
            end

            return
        end

        local min = Vector(math.huge, math.huge, math.huge)
        local max = Vector(-math.huge, -math.huge, -math.huge)

        for _, ent in ipairs(ents.GetAll()) do
            if not IsValid(ent) or ent:IsWorld() or ent:IsPlayer() then continue end
            local pos = ent:GetPos()

            if pos.x < min.x then min.x = pos.x end
            if pos.y < min.y then min.y = pos.y end
            if pos.z < min.z then min.z = pos.z end
            if pos.x > max.x then max.x = pos.x end
            if pos.y > max.y then max.y = pos.y end
            if pos.z > max.z then max.z = pos.z end
        end

        local center = Vector(0, 0, 100)
        if max.x > min.x and max.y > min.y then
            center = max - ((max - min) / 2)
        end

        if spawnSafeMapEnd(center, angle_zero, "") then
            print("[DCityPatch] Legacy fallback created center coop_mapend (no changelevel triggers)")
        end
    end)

    print("[DCityPatch] Legacy coop mapend fallback installed")
end

timer.Simple(0, installLegacyFallback)
