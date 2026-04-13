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

function ZC_IsPatchCombinePlayer(ply)
    return IsValid(ply) and ply:IsPlayer() and ZC_IsPatchCombineClassName(ply.PlayerClassName)
end

function ZC_IsPatchRebelPlayer(ply)
    return IsValid(ply) and ply:IsPlayer() and ZC_IsPatchRebelClassName(ply.PlayerClassName)
end