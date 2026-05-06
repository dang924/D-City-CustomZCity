-- shared.lua - ZRP container entity shared definitions.

ENT.Base = "base_entity"
ENT.Type = "anim"
ENT.PrintName = "ZRP Container"
ENT.Author = "ZCity"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "Looted")
    self:NetworkVar("Float", 0, "ResetAt")
    self:NetworkVar("String", 0, "ZRP_Model")
end
