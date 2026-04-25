if CLIENT then return end

ZC_PATCH_COMBINE_CLASSES = ZC_PATCH_COMBINE_CLASSES or {
    ["Combine"] = true,
    ["Metrocop"] = true,
}

ZC_PATCH_NON_REBEL_CLASSES = ZC_PATCH_NON_REBEL_CLASSES or {
    ["Combine"] = true,
    ["Metrocop"] = true,
    ["headcrabzombie"] = true,
}

ZC_PATCH_REBEL_ROLE_NAMES = ZC_PATCH_REBEL_ROLE_NAMES or {
    ["rebel"] = true,
    ["refugee"] = true,
    ["freeman"] = true,
    ["medic"] = true,
    ["grenadier"] = true,
}

ZC_PATCH_COMBINE_ROLE_NAMES = ZC_PATCH_COMBINE_ROLE_NAMES or {
    ["combine"] = true,
    ["metrocop"] = true,
    ["soldier"] = true,
    ["elite"] = true,
    ["ordinal"] = true,
}

local function NormalizePatchFactionText(value)
    return string.lower(string.Trim(tostring(value or "")))
end

function ZC_GetPatchPlayerClassName(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return "" end

    local className = tostring(ply.PlayerClassName or "")
    if className ~= "" then
        return className
    end

    local ok, value = pcall(function()
        return ply:GetPlayerClass()
    end)

    if ok and value ~= nil then
        return tostring(value)
    end

    return ""
end

function ZC_GetPatchPlayerRoleName(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return "" end

    local roleName = ply.Role or ""
    if istable(roleName) then
        roleName = roleName.name or ""
    end

    roleName = tostring(roleName)
    if roleName ~= "" then
        return roleName
    end

    if istable(ply.role) and ply.role.name then
        return tostring(ply.role.name)
    end

    local ok, value = pcall(function()
        if not ply.GetNWString then return "" end
        return ply:GetNWString("Role", "")
    end)

    if ok and value ~= nil then
        return tostring(value)
    end

    return ""
end

function ZC_IsPatchCombineClassName(className)
    return isstring(className) and ZC_PATCH_COMBINE_CLASSES[className] == true
end

function ZC_IsPatchNonRebelClassName(className)
    return isstring(className) and ZC_PATCH_NON_REBEL_CLASSES[className] == true
end

function ZC_IsPatchRebelClassName(className)
    if not isstring(className) or className == "" then return false end
    return not ZC_IsPatchNonRebelClassName(className)
end

function ZC_IsPatchCombineRoleName(roleName)
    return ZC_PATCH_COMBINE_ROLE_NAMES[NormalizePatchFactionText(roleName)] == true
end

function ZC_IsPatchRebelRoleName(roleName)
    return ZC_PATCH_REBEL_ROLE_NAMES[NormalizePatchFactionText(roleName)] == true
end

function ZC_IsPatchCombinePlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    return ZC_IsPatchCombineClassName(ZC_GetPatchPlayerClassName(ply))
        or ZC_IsPatchCombineRoleName(ZC_GetPatchPlayerRoleName(ply))
end

function ZC_IsPatchRebelPlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end

    return ZC_IsPatchRebelClassName(ZC_GetPatchPlayerClassName(ply))
        or ZC_IsPatchRebelRoleName(ZC_GetPatchPlayerRoleName(ply))
end