if SERVER then return end

-- Repair only missing spawnmenu Weapon entries without touching existing ones.
-- This avoids destructive list rewrites while recovering classes that dropped out.

local function BuildWeaponEntry(swep, className)
    if not istable(swep) or not isstring(className) or className == "" then return nil end

    return {
        ClassName = className,
        PrintName = swep.PrintName or className,
        Category = swep.Category or "Other",
        Spawnable = swep.Spawnable ~= false,
        AdminOnly = swep.AdminOnly == true,
        AdminSpawnable = swep.AdminSpawnable == true,
        IconOverride = swep.IconOverride,
    }
end

local function EntryNeedsRepair(existing, expected)
    if not istable(existing) then return true end

    return existing.PrintName ~= expected.PrintName
        or existing.Category ~= expected.Category
        or existing.Spawnable ~= expected.Spawnable
        or existing.AdminOnly ~= expected.AdminOnly
        or existing.AdminSpawnable ~= expected.AdminSpawnable
        or existing.IconOverride ~= expected.IconOverride
end

local function RepairMissingWeaponEntries(verbose)
    local allSweps = weapons.GetList()
    if not istable(allSweps) then return 0 end

    local weaponList = list.Get("Weapon") or {}
    local repaired = 0
    local missing = 0
    local stale = 0

    for _, swep in pairs(allSweps) do
        local className = swep and swep.ClassName
        if isstring(className) and className ~= "" then
            local entry = BuildWeaponEntry(swep, className)
            local existing = weaponList[className]

            if entry and EntryNeedsRepair(existing, entry) then
                list.Set("Weapon", className, entry)
                repaired = repaired + 1

                if existing == nil then
                    missing = missing + 1
                else
                    stale = stale + 1
                end
            end
        end
    end

    if repaired > 0 then
        hook.Run("SpawnMenuRebuild")
    end

    if verbose then
        MsgC(Color(100, 200, 255), "[ZC Spawnmenu Repair] Repaired: " .. tostring(repaired) .. " (missing: " .. tostring(missing) .. ", stale: " .. tostring(stale) .. ")\n")
    end

    return repaired
end

local function DebugWeaponListHealth()
    local allSweps = weapons.GetList()
    local weaponList = list.Get("Weapon") or {}
    if not istable(allSweps) then
        MsgC(Color(255, 120, 120), "[ZC Spawnmenu Repair] weapons.GetList() unavailable\n")
        return
    end

    local total = 0
    local expectedSpawnable = 0
    local missing = 0
    local stale = 0

    for _, swep in pairs(allSweps) do
        local className = swep and swep.ClassName
        if not isstring(className) or className == "" then continue end

        total = total + 1
        local expected = BuildWeaponEntry(swep, className)
        if expected and expected.Spawnable then
            expectedSpawnable = expectedSpawnable + 1
        end

        local existing = weaponList[className]
        if existing == nil then
            missing = missing + 1
        elseif expected and EntryNeedsRepair(existing, expected) then
            stale = stale + 1
        end
    end

    MsgC(Color(100, 200, 255), "[ZC Spawnmenu Repair] total=" .. total .. " spawnable_expected=" .. expectedSpawnable .. " missing=" .. missing .. " stale=" .. stale .. "\n")
end

hook.Add("InitPostEntity", "ZC_RepairMissingWeaponEntries_Init", function()
    timer.Simple(1, function()
        RepairMissingWeaponEntries(false)
    end)
end)

hook.Add("OnReloaded", "ZC_RepairMissingWeaponEntries_Reload", function()
    timer.Simple(0, function()
        RepairMissingWeaponEntries(false)
    end)
end)

concommand.Add("zc_spawnmenu_repair_weapons", function()
    RepairMissingWeaponEntries(true)
end)

concommand.Add("zc_spawnmenu_weapon_health", function()
    DebugWeaponListHealth()
end)
