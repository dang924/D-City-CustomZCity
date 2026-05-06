hg = hg or {}
hg.AppearanceTool = hg.AppearanceTool or {}

local TOOLMODULE = hg.AppearanceTool

TOOLMODULE.ConfigDataDir = "zcity/appearance_tool/"
TOOLMODULE.ImportDir = TOOLMODULE.ConfigDataDir .. "imports/"
TOOLMODULE.SelectionNWKey = "HG_ZCityAppearanceTool_Target"
TOOLMODULE.SelectionTypeNWKey = "HG_ZCityAppearanceTool_TargetType"
TOOLMODULE.ModeTag = "zcity_appearance_tool"

TOOLMODULE.Net = TOOLMODULE.Net or {
    ApplyAppearance = "HG.ZCAT.ApplyAppearance",
    ClearAppearance = "HG.ZCAT.ClearAppearance",
    SelectSelf = "HG.ZCAT.SelectSelf",
    SaveConfig = "HG.ZCAT.SaveConfig",
    RequestConfig = "HG.ZCAT.RequestConfig",
    SyncConfig = "HG.ZCAT.SyncConfig",
    OpenConfigurator = "HG.ZCAT.OpenConfigurator",
    ImportPreset = "HG.ZCAT.ImportPreset"
}

TOOLMODULE.TargetType = TOOLMODULE.TargetType or {
    none = 0,
    player = 1,
    ragdoll = 2
}

local NULL_VECTOR = Vector(1, 1, 1)

function TOOLMODULE.GetDefaultAppearance()
    hg.Appearance = hg.Appearance or {}

    if hg.Appearance.NormalizeAppearanceTable then
        return hg.Appearance.NormalizeAppearanceTable(hg.Appearance.GetRandomAppearance and hg.Appearance.GetRandomAppearance() or {})
    end

    return table.Copy((hg.Appearance and hg.Appearance.SkeletonAppearanceTable) or {})
end

function TOOLMODULE.NormalizeAppearance(tbl)
    hg.Appearance = hg.Appearance or {}

    if hg.Appearance.NormalizeAppearanceTable then
        return hg.Appearance.NormalizeAppearanceTable(tbl)
    end

    local normalized = istable(tbl) and table.Copy(tbl) or {}
    local skeleton = hg.Appearance.SkeletonAppearanceTable or {}

    normalized.AModel = normalized.AModel or skeleton.AModel
    normalized.AName = normalized.AName or skeleton.AName or "Unnamed"
    normalized.AColor = normalized.AColor or skeleton.AColor or Color(255, 255, 255)
    normalized.AClothes = istable(normalized.AClothes) and normalized.AClothes or table.Copy(skeleton.AClothes or {})
    normalized.AAttachments = istable(normalized.AAttachments) and normalized.AAttachments or table.Copy(skeleton.AAttachments or {"none", "none", "none"})
    normalized.ABodygroups = istable(normalized.ABodygroups) and normalized.ABodygroups or table.Copy(skeleton.ABodygroups or {})
    normalized.AFacemap = normalized.AFacemap or skeleton.AFacemap or "Default"

    return normalized
end

function TOOLMODULE.ValidateAppearance(tbl)
    hg.Appearance = hg.Appearance or {}

    if hg.Appearance.AppearanceValidater then
        return hg.Appearance.AppearanceValidater(tbl)
    end

    return istable(tbl)
end

function TOOLMODULE.CopyAppearance(tbl)
    if not istable(tbl) then return nil end
    return table.Copy(tbl)
end

function TOOLMODULE.GetTargetType(ent)
    if not IsValid(ent) then
        return TOOLMODULE.TargetType.none
    end

    if ent:IsPlayer() then
        return TOOLMODULE.TargetType.player
    end

    if ent:IsRagdoll() then
        return TOOLMODULE.TargetType.ragdoll
    end

    return TOOLMODULE.TargetType.none
end

function TOOLMODULE.IsSupportedPlayer(ent)
    return IsValid(ent) and ent:IsPlayer()
end

function TOOLMODULE.IsSupportedRagdoll(ent)
    if not IsValid(ent) or not ent:IsRagdoll() then return false end

    hg.Appearance = hg.Appearance or {}
    local rawModel = ent:GetModel() or ""
    local mdl = string.lower(rawModel)
    if mdl == "" then return false end

    local modelsBySex = hg.Appearance.FuckYouModels or {}
    return (modelsBySex[1] and (modelsBySex[1][rawModel] or modelsBySex[1][mdl]))
        or (modelsBySex[2] and (modelsBySex[2][rawModel] or modelsBySex[2][mdl]))
end

function TOOLMODULE.IsSupportedTarget(ent)
    return TOOLMODULE.IsSupportedPlayer(ent) or TOOLMODULE.IsSupportedRagdoll(ent)
end

function TOOLMODULE.GetPreviewColor(tbl)
    tbl = TOOLMODULE.NormalizeAppearance(tbl)
    local clr = tbl.AColor or Color(255, 255, 255)
    return Vector(clr.r / 255, clr.g / 255, clr.b / 255)
end

function TOOLMODULE.GetPlayerColorFallback(ent)
    if not IsValid(ent) then return NULL_VECTOR end

    if ent.GetPlayerColor then
        return ent:GetPlayerColor()
    end

    return ent:GetNWVector("PlayerColor", NULL_VECTOR)
end

function TOOLMODULE.GetClientConfig()
    TOOLMODULE.ClientConfig = TOOLMODULE.NormalizeAppearance(TOOLMODULE.ClientConfig or TOOLMODULE.GetDefaultAppearance())
    return TOOLMODULE.ClientConfig
end

function TOOLMODULE.SetClientConfig(tbl)
    TOOLMODULE.ClientConfig = table.Copy(TOOLMODULE.NormalizeAppearance(tbl))
    return TOOLMODULE.ClientConfig
end

function TOOLMODULE.RequestConfigSync()
end
