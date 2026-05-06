if not SERVER then return end

local function notifyPermaPropsTeleport(ply, text)
    text = tostring(text or "")
    if not IsValid(ply) then
        if text ~= "" then
            print("[PermaProps] " .. text)
        end
        return
    end

    if isfunction(ply.PermaPropMessage) then
        ply:PermaPropMessage(text)
        return
    end

    ply:ChatPrint("[PermaProps] " .. text)
end

local function installPermaPropsTeleportGuard()
    local system = rawget(_G, "PermaPropsSystem")
    if not istable(system) or not isfunction(system.GetEntByID) or not isfunction(system.TeleportToProp) then
        return false
    end
    if system._zcTeleportGuardInstalled then
        return true
    end

    system._zcTeleportGuardInstalled = true

    function system:TeleportToProp(id, ply)
        if not IsValid(ply) then return false end

        local ent = self:GetEntByID(id)
        if not IsValid(ent) then
            notifyPermaPropsTeleport(ply, "Could not find a live prop entity for that saved row.")
            return false
        end

        local pos = ent:GetPos()
        if not isvector(pos) then
            notifyPermaPropsTeleport(ply, "Could not resolve a teleport position for that prop.")
            return false
        end

        ply:SetPos(pos + Vector(0, 0, 100))
        notifyPermaPropsTeleport(ply, "Successfully teleported to the entity.")
        return true
    end

    return true
end

hook.Add("PermaPropsSystem.SQLReady", "ZC_PermapropsTeleportGuard", function()
    timer.Simple(0, installPermaPropsTeleportGuard)
end)

hook.Add("Initialize", "ZC_PermapropsTeleportGuard_Init", installPermaPropsTeleportGuard)
hook.Add("InitPostEntity", "ZC_PermapropsTeleportGuard", installPermaPropsTeleportGuard)

timer.Create("ZC_PermapropsTeleportGuardRetry", 1, 10, function()
    if installPermaPropsTeleportGuard() then
        timer.Remove("ZC_PermapropsTeleportGuardRetry")
    end
end)