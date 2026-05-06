-- init.lua — ZRP container entity server logic.

local DEFAULT_MODEL  = "models/props_junk/wood_crate001a.mdl"
local CONTAINER_HP   = 250
local USE_RANGE      = 96   -- units; max distance for a Use interaction
local INVENTORY_CHECK_INTERVAL = 0.25

function ENT:Initialize()
    local mdl = self:GetZRP_Model()
    if mdl == "" then mdl = DEFAULT_MODEL end
    self:SetModel(mdl)

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    self:SetMaxHealth(CONTAINER_HP)
    self:SetHealth(CONTAINER_HP)
    self:SetUseType(SIMPLE_USE)

    self:SetLooted(false)
    self:SetResetAt(0)
    self.ZRP_InventoryWatching = false
    if ZRP and ZRP.ClearContainerInventory then
        ZRP.ClearContainerInventory(self)
    end
end

-- ── Use (player opens the container) ─────────────────────────────────────────

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if self:GetLooted() then
        activator:ChatPrint("This container is empty. Check back later.")
        return
    end
    if activator:GetPos():Distance(self:GetPos()) > USE_RANGE then return end

    if not ZRP then return end

    if not self.ZRP_LootGenerated then
        ZRP.GenerateContainerInventory(self, self:GetModel(), self.ZRP_LootData or self.ZRP_LootOverride)
    end

    if ZRP.IsInventoryEmpty(self.inventory, self.armors) then
        activator:ChatPrint("Container is empty.")
        return
    end

    activator:OpenInventory(self)
    self:EmitSound("items/ammocrate_open.wav")
    self.ZRP_InventoryWatching = true
    self:NextThink(CurTime() + INVENTORY_CHECK_INTERVAL)
end

function ENT:ZRP_MarkLooted()
    if self:GetLooted() then return end

    self.ZRP_InventoryWatching = false
    self:SetLooted(true)
    self:SetResetAt(CurTime() + (self.ZRP_ResetDelay or 900))

    if ZRP and ZRP.ClearContainerInventory then
        ZRP.ClearContainerInventory(self)
    end

    if self.ZRP_ContainerID and ZRP and ZRP.OnContainerLooted then
        ZRP.OnContainerLooted(self.ZRP_ContainerID)
    end
end

function ENT:Think()
    if self.ZRP_InventoryWatching and not self:GetLooted() and ZRP and ZRP.IsInventoryEmpty(self.inventory, self.armors) then
        self:ZRP_MarkLooted()
    end

    self:NextThink(CurTime() + INVENTORY_CHECK_INTERVAL)
    return true
end

-- ── Reset (called by ZRP timer after loot delay expires) ──────────────────────

function ENT:ZRP_Reset()
    self:SetLooted(false)
    self:SetResetAt(0)
    self:SetHealth(self:GetMaxHealth())
    self.ZRP_InventoryWatching = false
    if ZRP and ZRP.ClearContainerInventory then
        ZRP.ClearContainerInventory(self)
    end
end

-- ── Damage / destruction ──────────────────────────────────────────────────────

function ENT:OnTakeDamage(dmginfo)
    self:SetHealth(self:Health() - dmginfo:GetDamage())
    if self:Health() <= 0 then
        -- Spawn props-style break effect.
        local effectdata = EffectData()
        effectdata:SetOrigin(self:GetPos())
        effectdata:SetMagnitude(1)
        effectdata:SetScale(1)
        effectdata:SetRadius(32)
        util.Effect("PropBreakableChunks", effectdata)

        self:Remove()
    end
end

function ENT:OnRemove()
    if self.ZRP_SilentRemove then return end
    if self.ZRP_ContainerID and ZRP and ZRP.OnContainerDestroyed then
        ZRP.OnContainerDestroyed(self.ZRP_ContainerID)
    end
end
