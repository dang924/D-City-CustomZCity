ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Refill Crate"
ENT.Spawnable = false
ENT.IsZPickup = true
ENT.Model = "models/Items/item_item_crate.mdl"

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "UsesLeft")
    self:NetworkVar("Int", 1, "UsesMax")
    self:NetworkVar("Float", 0, "NextUseTime")
    self:NetworkVar("String", 0, "CrateKind")
end
