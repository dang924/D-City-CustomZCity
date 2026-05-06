-- shared.lua — ZRP container entity shared definitions.

ENT.Base     = "base_entity"
ENT.Type     = "anim"
ENT.PrintName = "ZRP Container"
ENT.Author   = "ZCity"
ENT.Spawnable = false  -- staff-placed via LootEditor stool only

-- Network vars: looted state and time-to-reset (for client HUD rendering).
function ENT:SetupDataTables()
    self:NetworkVar("Bool",   0, "Looted")
    self:NetworkVar("Float",  0, "ResetAt")   -- CurTime() when the container resets (0 = not looted)
    self:NetworkVar("String", 0, "ZRP_Model") -- model path chosen at spawn time
end
