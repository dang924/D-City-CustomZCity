ZSCAV = ZSCAV or {}
ZSCAV.ServerHelpers = ZSCAV.ServerHelpers or {}

local helpers = ZSCAV.ServerHelpers
local INSTANCE_PREFIX = "zscavwi"

local function IsGeneratedInstanceClass(className)
    className = tostring(className or "")
    return className:match("^" .. INSTANCE_PREFIX .. "_%d+_.+$") ~= nil
end

local function GetInstanceAlias(className)
    className = tostring(className or "")
    return className:match("^" .. INSTANCE_PREFIX .. "_%d+_(.+)$")
end

local function GetScaledClassAlias(className)
    className = tostring(className or "")
    return className:match("^zscav_i%d+_(.+)$")
end

function ZSCAV:IsGeneratedWeaponInstanceClass(className)
    return IsGeneratedInstanceClass(className)
end

function ZSCAV:GetWeaponBaseClass(classOrEnt)
    local className = classOrEnt
    if IsValid(classOrEnt) then
        className = classOrEnt:GetClass()
    end

    className = tostring(className or "")
    local alias = GetInstanceAlias(className)
    if not alias or alias == "" then
        alias = GetScaledClassAlias(className)
    end
    if alias and alias ~= "" then
        return tostring(alias):lower()
    end
    return className:lower()
end

function ZSCAV:CopyWeaponState(state)
    if not istable(state) then
        return { attachments = {} }
    end

    local out = table.Copy(state)
    out.attachments = istable(out.attachments) and table.Copy(out.attachments) or {}
    return out
end

local function CopyIntegerField(out, source, key, minimum)
    if not (istable(source) and source[key] ~= nil) then return end

    local number = math.floor(tonumber(source[key]) or 0)
    if minimum ~= nil then
        number = math.max(minimum, number)
    end

    out[key] = number
end

local function CopyStringField(out, source, key)
    if not (istable(source) and source[key] ~= nil) then return end

    local value = tostring(source[key] or "")
    if value == "" then return end

    out[key] = value
end

local function CopyTableField(out, source, key)
    if not (istable(source) and istable(source[key])) then return end

    out[key] = table.Copy(source[key])
end

local function ResolveEntryRotated(className, entry)
    if not istable(entry) then return nil end
    if entry.rotated ~= nil then
        return entry.rotated and true or false
    end

    local w = tonumber(entry.w)
    local h = tonumber(entry.h)
    if not w or not h then return nil end
    if w == h then return false end

    if ZSCAV and ZSCAV.GetItemSize then
        local sizeSource = entry
        if not istable(sizeSource) then
            sizeSource = className
        elseif tostring(sizeSource.class or "") == "" then
            sizeSource = table.Copy(sizeSource)
            sizeSource.class = className
        end

        local size = ZSCAV:GetItemSize(sizeSource)
        local baseW = tonumber(size and size.w)
        local baseH = tonumber(size and size.h)
        if baseW and baseH then
            if baseW == baseH then
                return false
            end
            if w == baseW and h == baseH then
                return false
            end
            if w == baseH and h == baseW then
                return true
            end
        end
    end

    return nil
end

function ZSCAV:CopyItemEntry(entry, overrides)
    entry = istable(entry) and entry or { class = tostring(entry or "") }

    local out = {
        class = tostring(entry.class or ""),
    }

    if out.class == "" then
        return nil
    end

    if entry.uid and tostring(entry.uid) ~= "" then
        out.uid = tostring(entry.uid)
    end
    if entry.weapon_uid and tostring(entry.weapon_uid) ~= "" then
        out.weapon_uid = tostring(entry.weapon_uid)
    end
    if istable(entry.weapon_state) then
        out.weapon_state = self:CopyWeaponState(entry.weapon_state)
    end
    if entry.actual_class and tostring(entry.actual_class) ~= "" then
        out.actual_class = tostring(entry.actual_class)
    end

    CopyIntegerField(out, entry, "x", 0)
    CopyIntegerField(out, entry, "y", 0)
    CopyIntegerField(out, entry, "w", 1)
    CopyIntegerField(out, entry, "h", 1)
    CopyIntegerField(out, entry, "med_hp", 0)
    CopyIntegerField(out, entry, "med_uses", 0)
    CopyStringField(out, entry, "slot")
    CopyStringField(out, entry, "corpse_slot_kind")
    CopyStringField(out, entry, "corpse_slot_id")
    CopyStringField(out, entry, "corpse_section")
    CopyStringField(out, entry, "corpse_grid")
    CopyIntegerField(out, entry, "corpse_grid_x", 0)
    CopyIntegerField(out, entry, "corpse_grid_y", 0)
    CopyTableField(out, entry, "ticket_data")

    local rotated = ResolveEntryRotated(out.class, entry)
    if rotated ~= nil then
        out.rotated = rotated
    end

    if istable(overrides) then
        for key, value in pairs(overrides) do
            out[key] = value
        end
    end

    if tostring(out.slot or "") == "" then
        out.slot = nil
    end

    rotated = ResolveEntryRotated(out.class, out)
    if rotated ~= nil then
        out.rotated = rotated
    else
        out.rotated = nil
    end

    return out
end

helpers.GetWeaponBaseClass = function(classOrEnt)
    return ZSCAV:GetWeaponBaseClass(classOrEnt)
end

helpers.CopyWeaponState = function(state)
    return ZSCAV:CopyWeaponState(state)
end

helpers.CopyItemEntry = function(entry, overrides)
    return ZSCAV:CopyItemEntry(entry, overrides)
end

if SERVER then
    local registerWeapon = weapons.Register
    local getStoredWeapon = weapons.GetStored
    local listSet = list.Set
    local instanceCounter = 0

    function ZSCAV:NewWeaponInstanceUID()
        local t = os.time()
        local r = math.random(0, 0xFFFFFF)
        return string.format("w%08x%06x%02x", t, r, math.random(0, 0xFF))
    end

    function ZSCAV:EnsureWeaponEntryRuntime(entry, wep)
        if not istable(entry) then return nil end

        local baseClass = self:GetWeaponBaseClass(IsValid(wep) and wep or entry.class)
        if baseClass == "" then return nil end

        entry.class = baseClass
        entry.weapon_uid = tostring(entry.weapon_uid or (IsValid(wep) and wep.zscav_weapon_uid) or "")
        if entry.weapon_uid == "" then
            entry.weapon_uid = self:NewWeaponInstanceUID()
        end

        entry.weapon_state = self:CopyWeaponState(entry.weapon_state)
        entry.actual_class = tostring(entry.actual_class or (IsValid(wep) and wep:GetClass()) or "")

        if IsValid(wep) then
            wep.zscav_weapon_uid = entry.weapon_uid
            wep.zscav_base_class = baseClass
        end

        return entry
    end

    function ZSCAV:CaptureWeaponState(ply, wep, entry)
        local state = self:CopyWeaponState(entry and entry.weapon_state)
        local fallbackState = nil

        if not IsValid(wep) then
            return state
        end

        if istable(wep.zscav_world_entry) and istable(wep.zscav_world_entry.weapon_state) then
            fallbackState = self:CopyWeaponState(wep.zscav_world_entry.weapon_state)
        end

        if self.GetInstalledWeaponAttachments then
            state.attachments = self:GetInstalledWeaponAttachments(wep)
        end

        if fallbackState and self.NormalizeWeaponAttachments and self.GetWeaponAttachmentSlots then
            local className = self:GetWeaponBaseClass(wep)
            local liveAttachments = self:NormalizeWeaponAttachments(className, state.attachments)
            local fallbackAttachments = self:NormalizeWeaponAttachments(className, fallbackState.attachments)
            local hasLiveAttachment = false
            local hasFallbackAttachment = false

            for _, placement in ipairs(self:GetWeaponAttachmentSlots()) do
                if self:NormalizeAttachmentKey(liveAttachments[placement]) ~= "" then
                    hasLiveAttachment = true
                end
                if self:NormalizeAttachmentKey(fallbackAttachments[placement]) ~= "" then
                    hasFallbackAttachment = true
                end
            end

            if not hasLiveAttachment and hasFallbackAttachment then
                state.attachments = fallbackAttachments
            end
        end

        if wep.Clip1 then
            local clip1 = tonumber(wep:Clip1())
            if clip1 and clip1 >= 0 then
                state.clip1 = math.floor(clip1)
            end
        end

        if wep.Clip2 then
            local clip2 = tonumber(wep:Clip2())
            if clip2 and clip2 >= 0 then
                state.clip2 = math.floor(clip2)
            end
        end

        if IsValid(ply) and ply:IsPlayer() then
            local ammo1 = wep.GetPrimaryAmmoType and tonumber(wep:GetPrimaryAmmoType()) or -1
            if ammo1 and ammo1 >= 0 then
                state.reserve1 = math.max(0, tonumber(ply:GetAmmoCount(ammo1)) or 0)
            end

            local ammo2 = wep.GetSecondaryAmmoType and tonumber(wep:GetSecondaryAmmoType()) or -1
            if ammo2 and ammo2 >= 0 then
                state.reserve2 = math.max(0, tonumber(ply:GetAmmoCount(ammo2)) or 0)
            end
        end

        if fallbackState then
            if state.clip1 == nil and fallbackState.clip1 ~= nil then
                state.clip1 = fallbackState.clip1
            end
            if state.clip2 == nil and fallbackState.clip2 ~= nil then
                state.clip2 = fallbackState.clip2
            end
            if state.reserve1 == nil and fallbackState.reserve1 ~= nil then
                state.reserve1 = fallbackState.reserve1
            end
            if state.reserve2 == nil and fallbackState.reserve2 ~= nil then
                state.reserve2 = fallbackState.reserve2
            end
        end

        return state
    end

    function ZSCAV:ApplyWeaponState(_ply, wep, entry)
        if not IsValid(wep) or not istable(entry) or not istable(entry.weapon_state) then return end

        local state = entry.weapon_state
        if self.ApplyWeaponAttachments then
            self:ApplyWeaponAttachments(_ply, wep, state.attachments)
        end
        if state.clip1 ~= nil and wep.SetClip1 then
            wep:SetClip1(math.max(0, math.floor(tonumber(state.clip1) or 0)))
        end
        if state.clip2 ~= nil and wep.SetClip2 then
            wep:SetClip2(math.max(0, math.floor(tonumber(state.clip2) or 0)))
        end
    end

    function ZSCAV:CreateWeaponInstanceClass(baseClass)
        baseClass = self:GetWeaponBaseClass(baseClass)
        if baseClass == "" or IsGeneratedInstanceClass(baseClass) then return nil end

        local stored = getStoredWeapon(baseClass)
        if not stored then return nil end

        instanceCounter = instanceCounter + 1
        local generated = string.format("%s_%d_%s", INSTANCE_PREFIX, instanceCounter, baseClass)
        registerWeapon(stored, generated)
        listSet("Weapon", generated, nil)
        return generated
    end

    function ZSCAV:FindHeldWeaponByUID(ply, weaponUID)
        weaponUID = tostring(weaponUID or "")
        if weaponUID == "" or not IsValid(ply) then return NULL end

        for _, wep in ipairs(ply:GetWeapons()) do
            if IsValid(wep) and tostring(wep.zscav_weapon_uid or "") == weaponUID then
                return wep
            end
        end

        return NULL
    end

    function ZSCAV:FindHeldWeaponByActualClass(ply, actualClass)
        actualClass = tostring(actualClass or "")
        if actualClass == "" or not IsValid(ply) then return NULL end

        for _, wep in ipairs(ply:GetWeapons()) do
            if IsValid(wep) and tostring(wep:GetClass() or "") == actualClass then
                return wep
            end
        end

        return NULL
    end

    function ZSCAV:FindHeldWeaponForEntry(ply, entry)
        if not IsValid(ply) or not istable(entry) then return NULL end

        local byUID = self:FindHeldWeaponByUID(ply, entry.weapon_uid)
        if IsValid(byUID) then return byUID end

        local byActual = self:FindHeldWeaponByActualClass(ply, entry.actual_class)
        if IsValid(byActual) then return byActual end

        local wantedClass = self:GetWeaponBaseClass(entry.class)
        if wantedClass == "" then return NULL end

        for _, wep in ipairs(ply:GetWeapons()) do
            if IsValid(wep) and not (self.ShouldBypassInventoryPickup and self:ShouldBypassInventoryPickup(wep)) then
                if self:GetWeaponBaseClass(wep) == wantedClass then
                    self:EnsureWeaponEntryRuntime(entry, wep)
                    return wep
                end
            end
        end

        return NULL
    end

    function ZSCAV:SelectWeaponEntry(ply, entry)
        local wep = self:FindHeldWeaponForEntry(ply, entry)
        if not IsValid(wep) then return false, NULL end

        ply:SelectWeapon(wep:GetClass())
        return true, wep
    end

    function ZSCAV:StripWeaponEntry(ply, entry)
        local wep = self:FindHeldWeaponForEntry(ply, entry)
        if not IsValid(wep) then return false, NULL end

        self:EnsureWeaponEntryRuntime(entry, wep)
        entry.weapon_state = self:CaptureWeaponState(ply, wep, entry)
        entry.actual_class = tostring(wep:GetClass() or "")
        ply:StripWeapon(wep:GetClass())
        return true, wep
    end

    function ZSCAV:GiveWeaponInstance(ply, entry)
        if not IsValid(ply) or not istable(entry) then return NULL end

        self:EnsureWeaponEntryRuntime(entry)
        local baseClass = self:GetWeaponBaseClass(entry.class)
        if baseClass == "" then return NULL end

        local actualClass = self:CreateWeaponInstanceClass(baseClass) or baseClass
        local weapon = ents.Create(actualClass)
        if not IsValid(weapon) then return NULL end

        weapon:SetAngles(ply:GetAngles())
        weapon:SetPos(ply:GetPos())
        weapon:Spawn()
        weapon:Activate()

        self:EnsureWeaponEntryRuntime(entry, weapon)
        entry.actual_class = tostring(weapon:GetClass() or actualClass)

        if weapon:IsWeapon() then
            ply:PickupWeapon(weapon, false)
        end

        timer.Simple(0, function()
            if not IsValid(weapon) then return end
            ZSCAV:ApplyWeaponState(ply, weapon, entry)
        end)

        return weapon
    end

    helpers.NewWeaponInstanceUID = function()
        return ZSCAV:NewWeaponInstanceUID()
    end

    helpers.EnsureWeaponEntryRuntime = function(entry, wep)
        return ZSCAV:EnsureWeaponEntryRuntime(entry, wep)
    end

    helpers.CaptureWeaponState = function(ply, wep, entry)
        return ZSCAV:CaptureWeaponState(ply, wep, entry)
    end

    helpers.FindHeldWeaponForEntry = function(ply, entry)
        return ZSCAV:FindHeldWeaponForEntry(ply, entry)
    end

    helpers.SelectWeaponEntry = function(ply, entry)
        return ZSCAV:SelectWeaponEntry(ply, entry)
    end

    helpers.StripWeaponEntry = function(ply, entry)
        return ZSCAV:StripWeaponEntry(ply, entry)
    end

    helpers.GiveWeaponInstance = function(ply, entry)
        return ZSCAV:GiveWeaponInstance(ply, entry)
    end
end

if CLIENT then
    hook.Add("OnEntityCreated", "ZSCAV_RegisterWeaponInstanceClass", function(ent)
        if not IsValid(ent) or not ent:IsWeapon() or not ent:IsScripted() then return end

        local className = tostring(ent:GetClass() or "")
        if not IsGeneratedInstanceClass(className) then return end

        local alias = GetInstanceAlias(className)
        if not alias or alias == "" then return end

        local stored = weapons.GetStored(alias)
        if not stored then return end

        weapons.Register(stored, className)
        list.Set("Weapon", className, nil)
    end)
end