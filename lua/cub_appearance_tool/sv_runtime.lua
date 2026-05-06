if CLIENT then return end

hg = hg or {}
hg.AppearanceTool = hg.AppearanceTool or {}

local TOOLMODULE = hg.AppearanceTool
local NET = TOOLMODULE.Net

util.AddNetworkString(NET.ApplyAppearance)
util.AddNetworkString(NET.ClearAppearance)
util.AddNetworkString(NET.SelectSelf)
util.AddNetworkString(NET.SaveConfig)
util.AddNetworkString(NET.RequestConfig)
util.AddNetworkString(NET.SyncConfig)
util.AddNetworkString(NET.OpenConfigurator)
util.AddNetworkString(NET.ImportPreset)

TOOLMODULE.Runtime = TOOLMODULE.Runtime or {}

local Runtime = TOOLMODULE.Runtime
Runtime.PlayerOverlays = Runtime.PlayerOverlays or setmetatable({}, { __mode = "k" })
Runtime.RagdollOverlays = Runtime.RagdollOverlays or setmetatable({}, { __mode = "k" })

local function CapturePlayerState(ent)
    return {
        curAppearance = TOOLMODULE.CopyAppearance(ent.CurAppearance),
        cachedAppearance = TOOLMODULE.CopyAppearance(ent.CachedAppearance)
    }
end

local function RestorePlayerState(ent, snapshot)
    if not IsValid(ent) or not istable(snapshot) then return end

    ent.CurAppearance = TOOLMODULE.CopyAppearance(snapshot.curAppearance)
    ent.CachedAppearance = TOOLMODULE.CopyAppearance(snapshot.cachedAppearance)
end

local function CaptureRagdollState(ent)
    local snapshot = {
        playerName = ent:GetNWString("PlayerName", ""),
        playerColor = ent:GetNWVector("PlayerColor", Vector(1, 1, 1)),
        accessories = ent.GetNetVar and ent:GetNetVar("Accessories", nil) or nil,
        curAppearance = TOOLMODULE.CopyAppearance(ent.CurAppearance),
        subMaterials = {},
        bodygroups = {}
    }

    local mats = ent:GetMaterials()
    for i = 1, #mats do
        snapshot.subMaterials[i - 1] = ent:GetSubMaterial(i - 1)
    end

    local bodygroups = ent:GetBodyGroups()
    for bodygroupIndex = 1, #bodygroups do
        snapshot.bodygroups[bodygroupIndex - 1] = ent:GetBodygroup(bodygroupIndex - 1)
    end

    return snapshot
end

local function RestoreRagdollState(ent, snapshot)
    if not IsValid(ent) or not istable(snapshot) then return end

    ent:SetNWString("PlayerName", snapshot.playerName or "")
    ent:SetNWVector("PlayerColor", snapshot.playerColor or Vector(1, 1, 1))
    if ent.SetNetVar then
        ent:SetNetVar("Accessories", snapshot.accessories)
    end

    ent:SetSubMaterial()
    for subMaterialIndex, subMaterial in pairs(snapshot.subMaterials or {}) do
        ent:SetSubMaterial(subMaterialIndex, subMaterial or "")
    end

    for bodygroupIndex, value in pairs(snapshot.bodygroups or {}) do
        ent:SetBodygroup(bodygroupIndex, value or 0)
    end

    ent.CurAppearance = TOOLMODULE.CopyAppearance(snapshot.curAppearance)
end

local function SyncConfig(ply)
    if not IsValid(ply) then return end

    net.Start(NET.SyncConfig)
        net.WriteTable(TOOLMODULE.NormalizeAppearance(ply.HGAppearanceToolConfig or TOOLMODULE.GetDefaultAppearance()))
    net.Send(ply)
end

function TOOLMODULE.SetSelectedTarget(ply, ent)
    if not IsValid(ply) then return end

    local targetType = TOOLMODULE.GetTargetType(ent)
    if targetType == TOOLMODULE.TargetType.none then
        ent = NULL
    end

    ply:SetNWEntity(TOOLMODULE.SelectionNWKey, ent or NULL)
    ply:SetNWInt(TOOLMODULE.SelectionTypeNWKey, targetType)
end

function TOOLMODULE.ToggleSelectedTarget(ply, ent)
    if not IsValid(ply) then return false end

    local current = ply:GetNWEntity(TOOLMODULE.SelectionNWKey)
    if IsValid(current) and current == ent then
        TOOLMODULE.SetSelectedTarget(ply, nil)
        return false
    end

    TOOLMODULE.SetSelectedTarget(ply, ent)
    return true
end

function TOOLMODULE.GetSelectedTarget(ply)
    if not IsValid(ply) then return nil end

    local ent = ply:GetNWEntity(TOOLMODULE.SelectionNWKey)
    if not TOOLMODULE.IsSupportedTarget(ent) then
        return nil, TOOLMODULE.TargetType.none
    end

    return ent, TOOLMODULE.GetTargetType(ent)
end

function Runtime.StoreOverlay(ent, appearance, applier, originalState)
    if not IsValid(ent) then return end

    local payload = {
        appliedBy = applier,
        appearance = TOOLMODULE.CopyAppearance(appearance),
        appliedAt = CurTime()
    }

    if ent:IsPlayer() then
        payload.originalState = originalState or (Runtime.PlayerOverlays[ent] and Runtime.PlayerOverlays[ent].originalState)
        Runtime.PlayerOverlays[ent] = payload
    elseif ent:IsRagdoll() then
        payload.originalState = originalState or (Runtime.RagdollOverlays[ent] and Runtime.RagdollOverlays[ent].originalState)
        Runtime.RagdollOverlays[ent] = payload
    end
end

function Runtime.ClearOverlay(ent)
    if not IsValid(ent) then return end

    if ent:IsPlayer() then
        Runtime.PlayerOverlays[ent] = nil
    elseif ent:IsRagdoll() then
        Runtime.RagdollOverlays[ent] = nil
    end
end

local function ApplyAppearanceToRagdoll(ent, appearance)
    appearance = TOOLMODULE.NormalizeAppearance(appearance)
    local rawModel = ent:GetModel() or ""
    local modelKey = string.lower(rawModel)

    local tMdl = (hg.Appearance.FuckYouModels and hg.Appearance.FuckYouModels[1] and (hg.Appearance.FuckYouModels[1][rawModel] or hg.Appearance.FuckYouModels[1][modelKey]))
        or (hg.Appearance.FuckYouModels and hg.Appearance.FuckYouModels[2] and (hg.Appearance.FuckYouModels[2][rawModel] or hg.Appearance.FuckYouModels[2][modelKey]))

    if not istable(tMdl) then return false end

    ent:SetNWString("PlayerName", appearance.AName or "")
    ent:SetNWVector("PlayerColor", TOOLMODULE.GetPreviewColor(appearance))
    ent:SetNetVar("Accessories", appearance.AAttachments or {})
    ent:SetSubMaterial()

    local mats = ent:GetMaterials()
    for key, slotMaterial in pairs(tMdl.submatSlots or {}) do
        local slot = 0
        for i = 1, #mats do
            if mats[i] == slotMaterial then
                slot = i - 1
                break
            end
        end

        local clothesList = hg.Appearance.Clothes[tMdl.sex and 2 or 1] or {}
        ent:SetSubMaterial(slot, clothesList[appearance.AClothes[key]] or clothesList.normal or "")
        ent:SetNWString("Colthes" .. key, appearance.AClothes[key] or "normal")
    end

    for i = 1, #mats do
        local facemapSlot = hg.Appearance.FacemapsSlots[mats[i]]
        if facemapSlot and facemapSlot[appearance.AFacemap] then
            ent:SetSubMaterial(i - 1, facemapSlot[appearance.AFacemap])
        end
    end

    ent:SetBodyGroups("00000000000000000000")
    appearance.ABodygroups = appearance.ABodygroups or {}

    local bodygroups = ent:GetBodyGroups()
    for bodygroupIndex, bodygroupData in ipairs(bodygroups) do
        local selectedName = appearance.ABodygroups[bodygroupData.name]
        if not selectedName then continue end

        local bodygroupDefs = hg.Appearance.Bodygroups[bodygroupData.name]
        bodygroupDefs = bodygroupDefs and bodygroupDefs[tMdl.sex and 2 or 1]
        bodygroupDefs = bodygroupDefs and bodygroupDefs[selectedName]
        if not bodygroupDefs then continue end

        for submodelIndex = 0, #bodygroupData.submodels do
            if bodygroupDefs[1] == bodygroupData.submodels[submodelIndex] then
                ent:SetBodygroup(bodygroupIndex - 1, submodelIndex)
                break
            end
        end
    end

    ent.CurAppearance = TOOLMODULE.CopyAppearance(appearance)
    return true
end

function Runtime.ApplyOverlay(ent, appearance, applier)
    if not IsValid(ent) then return false end

    appearance = TOOLMODULE.NormalizeAppearance(appearance)
    if not TOOLMODULE.ValidateAppearance(appearance) then return false end

    if ent:IsPlayer() then
        if not isfunction(hg.Appearance.ForceApplyAppearance) then return false end
        local originalState = (Runtime.PlayerOverlays[ent] and Runtime.PlayerOverlays[ent].originalState) or CapturePlayerState(ent)
        hg.Appearance.ForceApplyAppearance(ent, appearance)
        Runtime.StoreOverlay(ent, appearance, applier, originalState)
        return true
    end

    if ent:IsRagdoll() and TOOLMODULE.IsSupportedRagdoll(ent) then
        local originalState = (Runtime.RagdollOverlays[ent] and Runtime.RagdollOverlays[ent].originalState) or CaptureRagdollState(ent)
        if not ApplyAppearanceToRagdoll(ent, appearance) then return false end
        Runtime.StoreOverlay(ent, appearance, applier, originalState)
        return true
    end

    return false
end

function Runtime.RestorePlayer(ent)
    if not IsValid(ent) or not ent:IsPlayer() then return end

    local payload = Runtime.PlayerOverlays[ent]
    Runtime.PlayerOverlays[ent] = nil
    RestorePlayerState(ent, payload and payload.originalState)

    if not isfunction(hg.Appearance.ApplyAppearance) then return end
    hg.Appearance.ApplyAppearance(ent, nil, nil, nil, true)
end

function Runtime.ClearEntityOverlay(ent)
    if not IsValid(ent) then return end

    if ent:IsPlayer() then
        Runtime.RestorePlayer(ent)
        return
    end

    if ent:IsRagdoll() then
        local payload = Runtime.RagdollOverlays[ent]
        Runtime.RagdollOverlays[ent] = nil
        RestoreRagdollState(ent, payload and payload.originalState)
    end
end

local previousForceApplyAppearance = hg.Appearance and hg.Appearance.ForceApplyAppearance
if isfunction(previousForceApplyAppearance) and not TOOLMODULE.__ForceApplyWrapped then
    TOOLMODULE.__ForceApplyWrapped = true

    function hg.Appearance.ForceApplyAppearance(ply, tbl, noModelChange, ...)
        Runtime.PlayerOverlays[ply] = nil
        return previousForceApplyAppearance(ply, tbl, noModelChange, ...)
    end
end

local playerMeta = FindMetaTable("Player")
local previousSetPlayerClass = playerMeta and playerMeta.SetPlayerClass
if isfunction(previousSetPlayerClass) and not TOOLMODULE.__SetPlayerClassWrapped then
    TOOLMODULE.__SetPlayerClassWrapped = true

    function playerMeta:SetPlayerClass(...)
        if Runtime.PlayerOverlays[self] then
            RestorePlayerState(self, Runtime.PlayerOverlays[self].originalState)
            Runtime.PlayerOverlays[self] = nil
        end

        return previousSetPlayerClass(self, ...)
    end
end

hook.Add("Player Spawn", "HG.ZCAT.ResetOverlayOnSpawn", function(ply)
    if not IsValid(ply) then return end
    if Runtime.PlayerOverlays[ply] then
        Runtime.RestorePlayer(ply)
    end
end)

hook.Add("PlayerSpawn", "HG.ZCAT.ResetOverlayOnSandboxSpawn", function(ply)
    if not IsValid(ply) then return end
    if Runtime.PlayerOverlays[ply] then
        Runtime.RestorePlayer(ply)
    end
end)

hook.Add("PostPostPlayerDeath", "HG.ZCAT.ResetOverlayOnDeath", function(ply)
    if not IsValid(ply) then return end
    if Runtime.PlayerOverlays[ply] then
        RestorePlayerState(ply, Runtime.PlayerOverlays[ply].originalState)
        Runtime.PlayerOverlays[ply] = nil
    end
end)

hook.Add("EntityRemoved", "HG.ZCAT.ClearRemovedRagdollOverlay", function(ent)
    if not IsValid(ent) or not ent:IsRagdoll() then return end
    Runtime.RagdollOverlays[ent] = nil
end)

net.Receive(NET.SaveConfig, function(_, ply)
    local appearance = net.ReadTable()
    appearance = TOOLMODULE.NormalizeAppearance(appearance)
    if not TOOLMODULE.ValidateAppearance(appearance) then return end

    ply.HGAppearanceToolConfig = TOOLMODULE.CopyAppearance(appearance)
    SyncConfig(ply)
end)

net.Receive(NET.RequestConfig, function(_, ply)
    SyncConfig(ply)
end)

net.Receive(NET.SelectSelf, function(_, ply)
    TOOLMODULE.ToggleSelectedTarget(ply, ply)
end)

net.Receive(NET.ApplyAppearance, function(_, ply)
    local transmitted = net.ReadTable()
    local appearance = TOOLMODULE.NormalizeAppearance(transmitted or ply.HGAppearanceToolConfig or TOOLMODULE.GetDefaultAppearance())
    local target = ply:GetNWEntity(TOOLMODULE.SelectionNWKey)

    if not TOOLMODULE.IsSupportedTarget(target) then return end

    if TOOLMODULE.ValidateAppearance(appearance) then
        ply.HGAppearanceToolConfig = TOOLMODULE.CopyAppearance(appearance)
    end

    Runtime.ApplyOverlay(target, appearance, ply)
end)

net.Receive(NET.ClearAppearance, function(_, ply)
    local target = ply:GetNWEntity(TOOLMODULE.SelectionNWKey)
    if not TOOLMODULE.IsSupportedTarget(target) then return end

    Runtime.ClearEntityOverlay(target)
end)

hook.Add("PlayerInitialSpawn", "HG.ZCAT.SendInitialConfig", function(ply)
    timer.Simple(1, function()
        if not IsValid(ply) then return end
        SyncConfig(ply)
    end)
end)
