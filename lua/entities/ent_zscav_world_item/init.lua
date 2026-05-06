AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local DEFAULT_MODEL = "models/props_junk/cardboard_box003a.mdl"

local function getWorldModel(ent)
    local explicit = tostring(ent.zscav_world_model or "")
    if explicit ~= "" then
        return explicit
    end

    local worldLoot = ZSCAV and ZSCAV.WorldLoot or nil
    if worldLoot and worldLoot.GetWorldModelForEntry then
        local model = tostring(worldLoot:GetWorldModelForEntry(ent.zscav_world_entry or ent.zscav_pack_class) or "")
        if model ~= "" then
            return model
        end
    end

    return DEFAULT_MODEL
end

function ENT:Initialize()
    self:SetModel(getWorldModel(self))

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end

    if istable(self.zscav_world_entry) then
        self.zscav_world_entry = table.Copy(self.zscav_world_entry)
        self.zscav_pack_class = tostring(self.zscav_world_entry.class or self.zscav_pack_class or "")
    else
        self.zscav_world_entry = nil
        self.zscav_pack_class = tostring(self.zscav_pack_class or "")
    end

    self.IsSpawned = true
end