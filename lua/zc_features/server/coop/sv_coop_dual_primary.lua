-- Allows specific coop roles to hold two primary weapons without editing base Homigrad files.

if not SERVER then return end

local function GetWeaponInv()
    if not hg then return nil end
    -- Some forks expose this as weaponinventory; support both safely.
    return hg.weaponInv or hg.weaponinventory
end

local function GetPlayerClassName(ply)
    local className = tostring(ply.PlayerClassName or "")
    if className ~= "" then return className end

    local ok, value = pcall(function()
        return ply:GetPlayerClass()
    end)

    if ok and value ~= nil then
        return tostring(value)
    end

    return ""
end

local function GetPlayerRoleName(ply)
    local roleName = tostring(ply.Role or ply.role or "")
    if roleName ~= "" then
        return roleName
    end

    local ok, value = pcall(function()
        return ply:GetNWString("Role")
    end)
    if ok and value ~= nil then
        return tostring(value)
    end

    return ""
end

local function IsGordonLikePlayer(ply)
    local className = string.lower(GetPlayerClassName(ply))
    if className == "gordon" or className == "freeman" then
        return true
    end

    local roleName = string.lower(GetPlayerRoleName(ply))
    return roleName == "freeman" or roleName == "gordon"
end

local function HasDualPrimaryPrivilege(ply)
    if not IsValid(ply) then return false end

    if IsGordonLikePlayer(ply) then
        return true
    end

    local className = string.lower(GetPlayerClassName(ply))
    local subClass = string.lower(tostring(ply.subClass or ""))
    if subClass ~= "grenadier" then
        return false
    end

    return className == "rebel"
end

local function RefreshWeaponLimits(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local weaponInv = GetWeaponInv()
    if not weaponInv or not weaponInv.CreateLimit then return end

    ply.weaponInv = ply.weaponInv or {}
    ply.ammoInv = ply.ammoInv or {}

    local primaryLimit = HasDualPrimaryPrivilege(ply) and 2 or 1

    weaponInv.CreateLimit(ply, 1, primaryLimit)
    weaponInv.CreateLimit(ply, 2, 2)
    weaponInv.CreateLimit(ply, 3, 1)
    weaponInv.CreateLimit(ply, 4, 1)
    weaponInv.CreateLimit(ply, 5, 1)
    weaponInv.CreateLimit(ply, 6, 1)

    if weaponInv.Sync then
        weaponInv.Sync(ply)
    end
end

local function PatchCanInsertForDualPrimary()
    local weaponInv = GetWeaponInv()
    if not weaponInv or not isfunction(weaponInv.CanInsert) then return false end
    if weaponInv._ZC_CoopDualPrimaryCanInsertPatched then return true end

    local originalCanInsert = weaponInv.CanInsert
    weaponInv.CanInsert = function(ply, wep)
        if SERVER and IsValid(ply) and ply:IsPlayer() and IsValid(wep) then
            local category = wep.weaponInvCategory
            if category == 1 then
                local desiredLimit = HasDualPrimaryPrivilege(ply) and 2 or 1
                ply.weaponInv = ply.weaponInv or {}
                local slot = ply.weaponInv[category]
                if istable(slot) then
                    slot.limit = desiredLimit
                else
                    RefreshWeaponLimits(ply)
                    slot = ply.weaponInv[category]
                    if istable(slot) then
                        slot.limit = desiredLimit
                    end
                end
            end
        end

        return originalCanInsert(ply, wep)
    end

    weaponInv._ZC_CoopDualPrimaryCanInsertPatched = true
    return true
end

hook.Add("WeaponsInv Loadout", "ZC_CoopDualPrimaryLimits", function(ply)
    -- Defer one tick: during the spawn flow, SetPlayerClass (which triggers this hook)
    -- is called BEFORE AssignSubClass sets ply.subClass. The explicit
    -- ZC_RefreshWeaponInvLimits call in SpawnAsRebel runs immediately after and will
    -- apply the correct limit. Here we just set a baseline so the inventory is
    -- initialised safely, then re-apply with the correct class info on the next tick.
    RefreshWeaponLimits(ply)
    timer.Simple(0, function()
        if IsValid(ply) then
            RefreshWeaponLimits(ply)
        end
    end)
    return true
end)

_G.ZC_RefreshWeaponInvLimits = RefreshWeaponLimits
_G.ZC_PlayerHasDualPrimaryPrivilege = HasDualPrimaryPrivilege

hook.Add("InitPostEntity", "ZC_CoopDualPrimaryPatchCanInsert", function()
    if PatchCanInsertForDualPrimary() then
        hook.Remove("InitPostEntity", "ZC_CoopDualPrimaryPatchCanInsert")
    end
end)

hook.Add("HomigradRun", "ZC_CoopDualPrimaryPatchCanInsert", function()
    PatchCanInsertForDualPrimary()
    timer.Simple(0, PatchCanInsertForDualPrimary)
end)