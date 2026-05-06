-- ZScav backpack pickup entity: Pilgrim backpack (large).

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_entity"
ENT.PrintName = "Pilgrim Backpack"
ENT.Author    = "ZCity"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.Category  = "ZScav - Backpacks"

local MODEL_BASENAME = "models/player/backpack_pilgrim/bp_piligrimm_body_lod0"
ENT.Model = MODEL_BASENAME .. ".mdl"

if CLIENT then
    util.PrecacheModel(ENT.Model)
end

if SERVER then
    resource.AddSingleFile(ENT.Model)
    for _, ext in ipairs({ ".phy", ".vvd", ".dx90.vtx", ".dx80.vtx", ".sw.vtx" }) do
        local path = MODEL_BASENAME .. ext
        if file.Exists(path, "GAME") then
            resource.AddSingleFile(path)
        end
    end

    for _, path in ipairs({
        "materials/models/player/backpack_pilgrim/backpack_piligrimm_DIF.vmt",
        "materials/models/player/backpack_pilgrim/backpack_piligrimm_DIF.vtf",
        "materials/models/player/backpack_pilgrim/backpack_piligrimm_dif.vmt",
        "materials/models/player/backpack_pilgrim/backpack_piligrimm_dif.vtf",
    }) do
        if file.Exists(path, "GAME") then
            resource.AddSingleFile(path)
        end
    end
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