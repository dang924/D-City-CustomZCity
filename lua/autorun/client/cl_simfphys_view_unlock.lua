if SERVER then return end

local function LowerClass(ent)
    if not IsValid(ent) then return "" end
    return string.lower(ent:GetClass() or "")
end

local function IsSimfphysSeat(ply)
    if not IsValid(ply) then return false end

    if ply.IsDrivingSimfphys and ply:IsDrivingSimfphys() then
        return true
    end

    if not ply:InVehicle() then return false end

    local seat = ply:GetVehicle()
    if not IsValid(seat) then return false end

    local parent = seat:GetParent()
    if not IsValid(parent) then return false end

    local cls = LowerClass(parent)
    if string.find(cls, "gmod_sent_vehicle_fphysics", 1, true) then
        return true
    end

    if simfphys and simfphys.IsCar and simfphys.IsCar(parent) then
        return true
    end

    return false
end

-- Bypass fakeCameraAngles2 angle_zero lock for SimFPhys seats only.
hook.Add("HG.InputMouseApply", "ZC_SimfphysViewUnlock", function(tbl)
    local ply = LocalPlayer()
    if not IsSimfphysSeat(ply) then return end
    return true
end, HOOK_HIGH)
