-- ZScav backpack pickup entity: MOLLE assault pack (medium).

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_entity"
ENT.PrintName = "MOLLE Pack"
ENT.Author    = "ZCity"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.Category  = "ZScav - Backpacks"

ENT.Model = "models/player/backpack_molle/bp_max_fuchs_body_lod0.mdl"

if CLIENT then
    util.PrecacheModel(ENT.Model)
end

if SERVER then
    resource.AddSingleFile(ENT.Model)
    resource.AddSingleFile("models/player/backpack_molle/bp_max_fuchs_body_lod0.phy")
    resource.AddSingleFile("models/player/backpack_molle/bp_max_fuchs_body_lod0.vvd")
    resource.AddSingleFile("models/player/backpack_molle/bp_max_fuchs_body_lod0.dx80.vtx")
    resource.AddSingleFile("models/player/backpack_molle/bp_max_fuchs_body_lod0.dx90.vtx")
    resource.AddSingleFile("models/player/backpack_molle/bp_max_fuchs_body_lod0.sw.vtx")
end

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "BagUID")
end

function ENT:Initialize()
    self:SetModel(self.Model)

    if SERVER then
        local uid = self:GetBagUID()
        if (uid == nil or uid == "") and ZSCAV and ZSCAV.CreateBag then
            uid = ZSCAV:CreateBag(self:GetClass())
            self:SetBagUID(uid)
        end

        -- See paratus pack for rationale -- replace ourselves with a
        -- prop_ragdoll so the bag actually drops on its bone hulls.
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
    function ENT:OnRemove() end
end

function ENT:Draw()
    self:DrawModel()
end
