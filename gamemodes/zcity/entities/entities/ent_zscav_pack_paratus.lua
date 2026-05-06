-- ZScav backpack pickup entity: Paratus 3-day (large).

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_entity"
ENT.PrintName = "Paratus 3-Day"
ENT.Author    = "ZCity"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.Category  = "ZScav - Backpacks"

local MODEL_BASENAME = "models/player/backpack_paratus_3_day/bp_paratus_3_day_body_lod0"
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
end

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "BagUID")
end

-- We register as a normal SENT so the spawnmenu / admin tools can
-- spawn us, and so all sv_zscav.lua code paths that reference
-- self:GetClass() keep working when items are dropped from inventory.
-- The actual ground entity is a `prop_ragdoll` because the model is a
-- multi-bone ragdoll (player-format mesh) -- only ragdoll physics
-- positions every bone hull where the visible mesh actually is. With
-- ENT.Type = "anim" the engine only loads the first hull and the mesh
-- ends up floating well above its physics box.
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

        -- Marker-mode (zscav_no_morph): keep the SENT itself solid so
        -- something else (preview ent, dev tools) can use it.
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
