AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_entity"
ENT.PrintName = "ZScav Ticket Machine"
ENT.Author = "ZCity"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.Category = "ZScav"
ENT.Model = "models/props/cs_assault/ticketmachine.mdl"

if CLIENT then
    util.PrecacheModel(ENT.Model)
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        local lib = ZSCAV and ZSCAV.TraderTerminal or nil
        if not lib or not lib.HandleTicketMachineUse then return end
        lib:HandleTicketMachineUse(self, activator)
    end
end

function ENT:Draw()
    self:DrawModel()
end