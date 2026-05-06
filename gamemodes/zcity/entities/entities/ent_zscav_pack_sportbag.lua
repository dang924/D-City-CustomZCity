-- ZScav backpack pickup entity: Sportbag (small).
-- The actual gear/grid behaviour lives in sh_zscav_catalog.lua under
-- ZSCAV.GearItems[ENT.ClassName]; this file only provides a world prop
-- you can pick up while the ZScav round is active.

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_entity"
ENT.PrintName = "Sportbag"
ENT.Author    = "ZCity"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.Category  = "ZScav - Backpacks"

ENT.Model = "models/player/backpack_sportbag/bp_forward_body_lod0.mdl"

-- Precache so the engine has a model handle ready when first spawned.
if CLIENT then
    util.PrecacheModel(ENT.Model)
end

if SERVER then
    -- Make the model + materials downloadable for clients without the
    -- backpacks content pack mounted. (Content pack 3 should already cover
    -- this on production servers; resource.AddSingleFile is a safety net.)
    resource.AddSingleFile(ENT.Model)
    resource.AddSingleFile("models/player/backpack_sportbag/bp_forward_body_lod0.phy")
    resource.AddSingleFile("models/player/backpack_sportbag/bp_forward_body_lod0.vvd")
    resource.AddSingleFile("models/player/backpack_sportbag/bp_forward_body_lod0.dx80.vtx")
    resource.AddSingleFile("models/player/backpack_sportbag/bp_forward_body_lod0.dx90.vtx")
    resource.AddSingleFile("models/player/backpack_sportbag/bp_forward_body_lod0.sw.vtx")
end

function ENT:SetupDataTables()
    -- Persisted bag identity. Empty until the server assigns one in
    -- Initialize, after which clients can look up display + contents.
    self:NetworkVar("String", 0, "BagUID")
end

-- Shared Initialize: SetModel must run on BOTH server and client or the
-- clientside copy renders nothing ("invisible" pickup).
function ENT:Initialize()
    self:SetModel(self.Model)

    if SERVER then
        local uid = self:GetBagUID()
        if (uid == nil or uid == "") and ZSCAV and ZSCAV.CreateBag then
            uid = ZSCAV:CreateBag(self:GetClass())
            self:SetBagUID(uid)
        end

        -- Replace ourselves with a real prop_ragdoll. See paratus pack
        -- for the full rationale -- short version: only ragdoll physics
        -- positions every bone hull where the player-mesh visibly is, so
        -- the bag actually drops to the floor instead of floating.
        if not self.zscav_no_morph then
            ZSCAV:SpawnPackRagdoll(self:GetClass(), self:GetPos(),
                self:GetAngles(), uid, self.Model)
            self:Remove()
            return
        end

        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self.IsSpawned = true
    end
end

if SERVER then
    -- We deliberately do NOT delete the SQL row when the entity is
    -- removed; the bag may have been picked up into a player inventory
    -- and we need its contents to persist by UID.
    function ENT:OnRemove() end
end

function ENT:Draw()
    self:DrawModel()
end
