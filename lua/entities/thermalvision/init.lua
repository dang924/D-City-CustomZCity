AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")


function ENT:Initialize()
    if SERVER then
        self:SetModel("models/props_lab/reciever01b.mdl") 
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if phys:IsValid() then
            phys:Wake()
        end

    end
end


function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    activator:SetNWInt("thermal_equipped", "1")
    self:EmitSound("items/ammo_pickup.wav")
    activator:ChatPrint("You picked up : Thermal Vision (bind : enable_thermal_vision)")
    self:Remove()
end

function ENT:Draw()
    self:DrawModel()
end