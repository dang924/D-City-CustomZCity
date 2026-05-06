-- Persistent player stash entity for ZScav.

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_entity"
ENT.PrintName = "ZScav Player Stash"
ENT.Author    = "ZCity"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Category  = "ZScav"

ENT.Model = "models/props/cs_militia/boxes_frontroom.mdl"

if CLIENT then
    util.PrecacheModel(ENT.Model)
end

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "BagUID")
    self:NetworkVar("String", 1, "OwnerSID64")
    self:NetworkVar("Bool",   0, "IsFrozen")
end

local function IsSharedWorldStash(ent)
    if not ent then return false end
    if ZSCAV and ZSCAV.IsSharedWorldStashOwner then
        return ZSCAV:IsSharedWorldStashOwner(ent:GetOwnerSID64())
    end

    local sharedOwner = ZSCAV and tostring(ZSCAV.SharedPlayerStashWorldOwner or "") or ""
    return sharedOwner ~= "" and tostring(ent:GetOwnerSID64() or "") == sharedOwner
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)

        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local sharedWorldStash = IsSharedWorldStash(self)
        local uid = self:GetBagUID()
        if not sharedWorldStash and (uid == nil or uid == "") and ZSCAV and ZSCAV.CreateBag then
            uid = ZSCAV:CreateBag(self:GetClass())
            self:SetBagUID(uid)
        end

        if not sharedWorldStash and self:GetOwnerSID64() == "" and ZSCAV and ZSCAV.ResolvePlayerStashOwnerSID64 then
            local ownerSID64 = tostring(ZSCAV:ResolvePlayerStashOwnerSID64(self) or "")
            if ownerSID64 ~= "" then
                self:SetOwnerSID64(ownerSID64)
            end
        end

        timer.Simple(0, function()
            if IsValid(self) then
                self:ApplyFrozenState(self:GetIsFrozen(), false)
            end
        end)
    end

    function ENT:ApplyFrozenState(frozen, saveState)
        frozen = frozen and true or false
        self:SetIsFrozen(frozen)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(not frozen)
            if not frozen then
                phys:Wake()
            end
        end

        if saveState and ZSCAV and ZSCAV.SavePlayerStashEntity then
            ZSCAV:SavePlayerStashEntity(self)
        end
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        if not ZSCAV or not ZSCAV.IsActive or not ZSCAV:IsActive() then
            activator:ChatPrint("[ZScav] Stash can only be opened during ZScav.")
            return
        end

        local sharedWorldStash = IsSharedWorldStash(self)
        if not sharedWorldStash and self:GetOwnerSID64() == "" and ZSCAV.ResolvePlayerStashOwnerSID64 then
            local ownerSID64 = tostring(ZSCAV:ResolvePlayerStashOwnerSID64(self, activator) or "")
            if ownerSID64 ~= "" then
                self:SetOwnerSID64(ownerSID64)
            end
        end

        local sid = tostring(activator:SteamID64() or "")
        if sid == "" then return end

        local uid
        local err
        if ZSCAV.GetAccessiblePlayerStashUID then
            uid, err = ZSCAV:GetAccessiblePlayerStashUID(activator)
        elseif ZSCAV.GetCanonicalPlayerStashUID then
            uid, err = ZSCAV:GetCanonicalPlayerStashUID(sid, true)
        end
        if tostring(err or "") == "stash_loading" then
            activator:ChatPrint("[ZScav] Stash data is still loading, try again in a moment.")
            return
        end
        uid = tostring(uid or "")

        if not sharedWorldStash and uid ~= "" and self.SetBagUID and self:GetBagUID() ~= uid then
            self:SetBagUID(uid)
        end
        if not uid or uid == "" then return end

        local helpers = ZSCAV and ZSCAV.ServerHelpers or nil
        local openDeferred = helpers and helpers.OpenContainerForPlayerDeferred or nil
        if isfunction(openDeferred) then
            openDeferred(activator, uid, self:GetClass(), self)
            return
        end

        if ZSCAV and isfunction(ZSCAV.OpenContainerForPlayer) then
            ZSCAV:OpenContainerForPlayer(activator, uid, self:GetClass(), self)
            return
        end

        activator:ChatPrint("[ZScav] Container system still initializing. Try again.")
    end

    function ENT:OnPhysgunFreeze(weapon, physobj, ply)
        self:ApplyFrozenState(true, true)
        return true
    end

    function ENT:PhysgunDrop(ply)
        timer.Simple(0, function()
            if not IsValid(self) then return end
            local phys = self:GetPhysicsObject()
            if IsValid(phys) then
                self:SetIsFrozen(not phys:IsMotionEnabled())
            end
            if ZSCAV and ZSCAV.SavePlayerStashEntity then
                ZSCAV:SavePlayerStashEntity(self)
            end
        end)
    end

    function ENT:Think()
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            self:SetIsFrozen(not phys:IsMotionEnabled())
        end

        local p = self:GetPos()
        local a = self:GetAngles()
        local sig = string.format("%.1f|%.1f|%.1f|%.1f|%.1f|%.1f|%d",
            p.x, p.y, p.z, a.p, a.y, a.r, self:GetIsFrozen() and 1 or 0)

        if sig ~= self.zscav_last_sig and (self.zscav_next_save or 0) <= CurTime() then
            self.zscav_last_sig = sig
            self.zscav_next_save = CurTime() + 0.5
            if ZSCAV and ZSCAV.SavePlayerStashEntity then
                ZSCAV:SavePlayerStashEntity(self)
            end
        end

        self:NextThink(CurTime() + 1)
        return true
    end

    function ENT:OnRemove()
        if self.zscav_skip_save then return end
        if ZSCAV and ZSCAV.SavePlayerStashEntity then
            ZSCAV:SavePlayerStashEntity(self)
        end
    end
end

function ENT:Draw()
    self:DrawModel()
end
