AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local DEFAULT_MODEL = "models/props_junk/wood_crate001a.mdl"

local function getProxyBounds(ent)
    local raw = istable(ent.zscav_proxy_size) and ent.zscav_proxy_size or {}
    local halfX = math.max(tonumber(raw.x) or 56, 8) * 0.5
    local halfY = math.max(tonumber(raw.y) or 56, 8) * 0.5
    local halfZ = math.max(tonumber(raw.z) or 72, 8) * 0.5
    return Vector(-halfX, -halfY, -halfZ), Vector(halfX, halfY, halfZ)
end

local function getContainerModel(ent)
    local explicit = tostring(ent.zscav_world_model or "")
    if explicit ~= "" then
        return explicit
    end

    local worldLoot = ZSCAV and ZSCAV.WorldLoot or nil
    if worldLoot and worldLoot.GetContainerDefByClass then
        local def = worldLoot:GetContainerDefByClass(ent.zscav_pack_class)
        local model = tostring(istable(def) and def.model or "")
        if model ~= "" then
            return model
        end
    end

    return DEFAULT_MODEL
end

function ENT:SetBagUID(uid)
    self.zscav_pack_uid = tostring(uid or "")
end

function ENT:GetBagUID()
    return tostring(self.zscav_pack_uid or "")
end

function ENT:Initialize()
    if self.zscav_proxy then
        self:SetModel(DEFAULT_MODEL)

        local mins, maxs = getProxyBounds(self)
        self:PhysicsInitBox(mins, maxs)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_BBOX)
        self:SetCollisionBounds(mins, maxs)
        self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        self:SetUseType(SIMPLE_USE)
        self:SetNoDraw(true)
        self:DrawShadow(false)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
        end

        self.zscav_pack_class = tostring(self.zscav_pack_class or "")
        self.zscav_pack_uid = tostring(self.zscav_pack_uid or "")
        self.IsSpawned = true
        return
    end

    self:SetModel(getContainerModel(self))

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        if self.zscav_should_freeze then
            phys:EnableMotion(false)
        end
    end

    self.zscav_pack_class = tostring(self.zscav_pack_class or "")
    self.zscav_pack_uid = tostring(self.zscav_pack_uid or "")
    self.IsSpawned = true
end