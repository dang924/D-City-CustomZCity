if SERVER then return end

local MODE = MODE

local hiddenLoadoutFrame = nil
local hiddenLoadoutPayload = nil
local hiddenLoadoutBackdrop = nil

local PREVIEW_HOLD_ACTIVITIES = {
    pistol = ACT_HL2MP_IDLE_PISTOL,
    revolver = ACT_HL2MP_IDLE_REVOLVER,
    smg = ACT_HL2MP_IDLE_SMG1,
    ar2 = ACT_HL2MP_IDLE_AR2,
    shotgun = ACT_HL2MP_IDLE_SHOTGUN,
    rpg = ACT_HL2MP_IDLE_RPG,
    crossbow = ACT_HL2MP_IDLE_CROSSBOW,
    grenade = ACT_HL2MP_IDLE_GRENADE,
    melee = ACT_HL2MP_IDLE_MELEE,
    melee2 = ACT_HL2MP_IDLE_MELEE2,
    knife = ACT_HL2MP_IDLE_KNIFE,
    slam = ACT_HL2MP_IDLE_SLAM,
    passive = ACT_HL2MP_IDLE_PASSIVE,
    fist = ACT_HL2MP_IDLE_FIST,
    duel = ACT_HL2MP_IDLE_DUEL,
    normal = ACT_HL2MP_IDLE,
}

local COL_BG = Color(15, 18, 24)
local COL_PANEL = Color(24, 28, 36)
local COL_PANEL_DARK = Color(16, 19, 25)
local COL_BORDER = Color(48, 56, 70)
local COL_ACCENT = Color(75, 155, 235)
local COL_ACCENT_HOT = Color(95, 180, 255)
local COL_SUCCESS = Color(82, 184, 111)
local COL_DANGER = Color(198, 78, 78)
local COL_WARN = Color(215, 170, 82)
local COL_TEXT = Color(230, 236, 244)
local COL_TEXT_DIM = Color(143, 153, 170)

surface.CreateFont("HiddenLoadout_Title", {
    font = "Tahoma",
    size = 21,
    weight = 800,
})

surface.CreateFont("HiddenLoadout_Label", {
    font = "Tahoma",
    size = 14,
    weight = 700,
})

surface.CreateFont("HiddenLoadout_Small", {
    font = "Tahoma",
    size = 12,
    weight = 500,
})

surface.CreateFont("HiddenLoadout_Mono", {
    font = "Courier New",
    size = 12,
    weight = 500,
})

local function unpackVector(data)
    if not istable(data) then
        return vector_origin
    end

    return Vector(tonumber(data.x) or 0, tonumber(data.y) or 0, tonumber(data.z) or 0)
end

local function unpackAngle(data)
    if not istable(data) then
        return angle_zero
    end

    return Angle(tonumber(data.p) or 0, tonumber(data.y) or 0, tonumber(data.r) or 0)
end

local function buildEntryMaps(payload)
    local maps = {
        primary = {},
        secondary = {},
        armor = {},
    }

    for _, entry in ipairs(payload.primary or {}) do
        maps.primary[tostring(entry.class or "")] = entry
    end

    for _, entry in ipairs(payload.secondary or {}) do
        maps.secondary[tostring(entry.class or "")] = entry
    end

    for slotName, entries in pairs(payload.armor or {}) do
        maps.armor[slotName] = {}
        for _, entry in ipairs(entries or {}) do
            maps.armor[slotName][tostring(entry.key or "")] = entry
        end
    end

    return maps
end

local function normalizeSelection(payload, maps, selection)
    local normalized = {
        primary = "",
        secondary = "",
        armor = {},
    }

    selection = istable(selection) and selection or {}
    selection.armor = istable(selection.armor) and selection.armor or {}

    local defaultLoadout = MODE:GetDefaultHiddenLoadout()
    local defaultArmor = istable(defaultLoadout.armor) and defaultLoadout.armor or {}

    normalized.primary = tostring(selection.primary or defaultLoadout.primary or "")
    normalized.secondary = selection.secondary ~= nil and tostring(selection.secondary) or tostring(defaultLoadout.secondary or "")

    if normalized.primary ~= "" and not maps.primary[normalized.primary] then
        normalized.primary = tostring(defaultLoadout.primary or "")
    end

    if normalized.secondary ~= "" and not maps.secondary[normalized.secondary] then
        normalized.secondary = tostring(defaultLoadout.secondary or "")
    end

    if normalized.primary ~= "" and not maps.primary[normalized.primary] then
        normalized.primary = ""
    end

    if normalized.secondary ~= "" and not maps.secondary[normalized.secondary] then
        normalized.secondary = ""
    end

    for _, slotName in ipairs(MODE:GetHiddenLoadoutSlots()) do
        local armorKey = MODE:NormalizeHiddenArmorKey(selection.armor[slotName] or defaultArmor[slotName])
        if armorKey ~= "" and not (maps.armor[slotName] and maps.armor[slotName][armorKey]) then
            armorKey = MODE:NormalizeHiddenArmorKey(defaultArmor[slotName])
        end

        if armorKey ~= "" and not (maps.armor[slotName] and maps.armor[slotName][armorKey]) then
            armorKey = ""
        end

        normalized.armor[slotName] = armorKey
    end

    return normalized
end

local function calculateSelectionCost(payload, maps, selection)
    local totalCost = 0

    if selection.primary ~= "" and maps.primary[selection.primary] then
        totalCost = totalCost + (tonumber(maps.primary[selection.primary].score) or 0)
    end

    if selection.secondary ~= "" and maps.secondary[selection.secondary] then
        totalCost = totalCost + (tonumber(maps.secondary[selection.secondary].score) or 0)
    end

    for _, slotName in ipairs(MODE:GetHiddenLoadoutSlots()) do
        local armorKey = selection.armor[slotName]
        local entry = maps.armor[slotName] and maps.armor[slotName][armorKey] or nil
        if entry then
            totalCost = totalCost + (tonumber(entry.score) or 0)
        end
    end

    return totalCost
end

local function isPreviewPistolHoldType(storedWeapon, holdType)
    if istable(storedWeapon) and isfunction(storedWeapon.IsPistolHoldType) then
        local ok, result = pcall(storedWeapon.IsPistolHoldType, storedWeapon)
        if ok then
            return result and true or false
        end
    end

    return holdType == "pistol" or holdType == "revolver" or holdType == "duel"
end

local function getPreviewWeaponInfo(entry)
    if not istable(entry) then
        return nil
    end

    local className = tostring(entry.class or "")
    local storedWeapon = weapons and isfunction(weapons.GetStored) and weapons.GetStored(className) or nil
    local holdType = string.lower(tostring(storedWeapon and storedWeapon.HoldType or ""))

    if holdType == "" then
        holdType = ((tonumber(storedWeapon and storedWeapon.weaponInvCategory) or 0) == 2) and "pistol" or "smg"
    end

    local isPistol = isPreviewPistolHoldType(storedWeapon, holdType)
    local defaultHold = isPistol and "pistol_hold2" or "ak_hold"
    local rightHold = string.lower(tostring((storedWeapon and (storedWeapon.HoldRH or storedWeapon.hold_type)) or defaultHold))
    local leftHold = string.lower(tostring((storedWeapon and (storedWeapon.HoldLH or storedWeapon.hold_type)) or rightHold))
    local modelPath = tostring((storedWeapon and (storedWeapon.WorldModel or storedWeapon.WorldModelFake or storedWeapon.WorldModelReal)) or entry.model or "")

    if rightHold == "" then
        rightHold = defaultHold
    end

    if leftHold == "" then
        leftHold = rightHold
    end

    if modelPath == "" then
        modelPath = tostring(entry.model or "")
    end

    if modelPath == "" then
        return nil
    end

    return {
        class = className,
        model = modelPath,
        activity = PREVIEW_HOLD_ACTIVITIES[holdType] or ACT_HL2MP_IDLE,
        rightHold = rightHold,
        leftHold = leftHold,
        useLeftHand = not isPistol and holdType ~= "knife" and holdType ~= "melee" and holdType ~= "melee2" and holdType ~= "fist" and holdType ~= "normal" and holdType ~= "slam",
        poseKey = table.concat({className, modelPath, holdType, rightHold, leftHold}, "|"),
    }
end

local function getPreviewWeaponTransform(entity)
    if not IsValid(entity) then
        return nil, nil
    end

    local attachmentIndex = entity:LookupAttachment("anim_attachment_RH")
    if attachmentIndex and attachmentIndex > 0 then
        local attachment = entity:GetAttachment(attachmentIndex)
        if attachment then
            return attachment.Pos, attachment.Ang
        end
    end

    local boneIndex = entity:LookupBone("ValveBiped.Bip01_R_Hand")
    local boneMatrix = boneIndex and entity:GetBoneMatrix(boneIndex) or nil
    if boneMatrix then
        return boneMatrix:GetTranslation(), boneMatrix:GetAngles()
    end

    return nil, nil
end

local function formatWeaponStats(entry)
    if not entry then
        return "No weapon selected."
    end

    return string.format(
        "Score %d  |  %s  |  %d dmg  |  %d RPM  |  %d clip  |  %d pen  |  %.1f wt",
        tonumber(entry.score) or 0,
        tostring(entry.caliber or "Unknown caliber"),
        tonumber(entry.damage) or 0,
        tonumber(entry.rpm) or 0,
        tonumber(entry.clip) or 0,
        tonumber(entry.penetration) or 0,
        tonumber(entry.weight) or 0
    )
end

local function formatArmorStats(entry)
    if not entry then
        return "No armor selected."
    end

    return string.format(
        "Score %d  |  %.1f protection  |  %.1f mass",
        tonumber(entry.score) or 0,
        tonumber(entry.protection) or 0,
        tonumber(entry.mass) or 0
    )
end

local function formatPublicPresetTimestamp(updatedAt)
    local stamp = tonumber(updatedAt) or 0
    if stamp <= 0 then
        return "-"
    end

    return os.date("%m/%d %H:%M", stamp)
end

local function buildSelectionSnapshot(selection)
    local snapshot = {
        primary = tostring(selection and selection.primary or ""),
        secondary = tostring(selection and selection.secondary or ""),
        armor = {},
    }
    local armor = istable(selection and selection.armor) and selection.armor or {}

    for _, slotName in ipairs(MODE:GetHiddenLoadoutSlots()) do
        snapshot.armor[slotName] = MODE:NormalizeHiddenArmorKey(armor[slotName])
    end

    return snapshot
end

local function selectionsEqual(left, right)
    local leftSnapshot = buildSelectionSnapshot(left)
    local rightSnapshot = buildSelectionSnapshot(right)

    if leftSnapshot.primary ~= rightSnapshot.primary then
        return false
    end

    if leftSnapshot.secondary ~= rightSnapshot.secondary then
        return false
    end

    for _, slotName in ipairs(MODE:GetHiddenLoadoutSlots()) do
        if leftSnapshot.armor[slotName] ~= rightSnapshot.armor[slotName] then
            return false
        end
    end

    return true
end

local function cloneColor(colorValue, alpha)
    if not colorValue then
        return Color(255, 255, 255, alpha or 255)
    end

    return Color(colorValue.r or 255, colorValue.g or 255, colorValue.b or 255, alpha or colorValue.a or 255)
end

local function themeColor(nexusKey, fallback, alpha)
    local source = fallback

    if istable(Nexus) and istable(Nexus.Colors) and Nexus.Colors[nexusKey] then
        source = Nexus.Colors[nexusKey]
    end

    return cloneColor(source, alpha)
end

local function brightenColor(colorValue, amount)
    amount = tonumber(amount) or 0

    return Color(
        math.Clamp((colorValue.r or 0) + amount, 0, 255),
        math.Clamp((colorValue.g or 0) + amount, 0, 255),
        math.Clamp((colorValue.b or 0) + amount, 0, 255),
        colorValue.a or 255
    )
end

local function entryMatchesFilter(entry, filterText)
    local trimmed = string.Trim(string.lower(tostring(filterText or "")))
    if trimmed == "" then
        return true
    end

    local haystack = table.concat({
        tostring(entry.name or ""),
        tostring(entry.author or ""),
        tostring(entry.class or ""),
        tostring(entry.key or ""),
        tostring(entry.caliber or ""),
    }, " ")

    return string.find(string.lower(haystack), trimmed, 1, true) ~= nil
end

local function setEntryPlaceholder(entry, text)
    entry._hiddenPlaceholder = tostring(text or "")

    if entry.SetPlaceholderText then
        entry:SetPlaceholderText(entry._hiddenPlaceholder)
    end
end

local function styleSearchEntry(entry)
    if not IsValid(entry) then
        return
    end

    entry:SetFont("HiddenLoadout_Small")
    entry:SetTextColor(COL_TEXT)
    entry:SetDrawLanguageID(false)
    entry.Paint = function(selfEntry, w, h)
        local outline = selfEntry:HasFocus() and themeColor("Primary", COL_ACCENT) or themeColor("Outline", COL_BORDER)

        draw.RoundedBox(6, 0, 0, w, h, themeColor("Secondary", COL_PANEL_DARK))
        surface.SetDrawColor(outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        selfEntry:DrawTextEntryText(COL_TEXT, outline, COL_TEXT)

        if selfEntry:GetValue() == "" and not selfEntry:HasFocus() and selfEntry._hiddenPlaceholder ~= "" then
            draw.SimpleText(selfEntry._hiddenPlaceholder, "HiddenLoadout_Small", 8, h * 0.5, COL_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end

local function styleActionButton(button, label, baseColor)
    if not IsValid(button) then
        return
    end

    button:SetText("")
    button._hiddenBaseColor = cloneColor(baseColor)
    button._hiddenLabel = tostring(label or "")
    button.Paint = function(selfButton, w, h)
        local fill = cloneColor(selfButton._hiddenOverrideColor or selfButton._hiddenBaseColor or baseColor)

        if not selfButton:IsEnabled() then
            fill = themeColor("Secondary", COL_PANEL_DARK)
        elseif selfButton:IsDown() then
            fill = brightenColor(fill, -24)
        elseif selfButton:IsHovered() then
            fill = brightenColor(fill, 18)
        end

        draw.RoundedBox(6, 0, 0, w, h, fill)
        surface.SetDrawColor(themeColor("Outline", COL_BORDER))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(selfButton._hiddenLabel, "HiddenLoadout_Label", w * 0.5, h * 0.5, COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function computeResponsiveSpan(screenSize, fraction, minSize, screenPadding)
    local maxSize = math.max(screenSize - screenPadding * 2, 480)
    local desired = math.max(math.floor(screenSize * fraction), math.min(minSize, maxSize))
    return math.min(desired, maxSize)
end

local function computeCardWidth(availableWidth, gap, minWidth, maxColumns)
    availableWidth = math.max(math.floor(availableWidth or 0), minWidth or 160)
    gap = math.max(math.floor(gap or 0), 0)
    minWidth = math.max(math.floor(minWidth or 160), 120)
    maxColumns = math.max(math.floor(maxColumns or 1), 1)

    for columns = maxColumns, 1, -1 do
        local width = math.floor((availableWidth - gap * (columns - 1)) / columns)
        if width >= minWidth or columns == 1 then
            return math.max(width, minWidth)
        end
    end

    return minWidth
end

local function ensureHiddenLoadoutBackdrop()
    if not IsValid(hiddenLoadoutBackdrop) then
        hiddenLoadoutBackdrop = vgui.Create("EditablePanel")
        hiddenLoadoutBackdrop.Paint = function(_, w, h)
            surface.SetDrawColor(0, 0, 0, 255)
            surface.DrawRect(0, 0, w, h)
        end
    end

    hiddenLoadoutBackdrop:SetPos(0, 0)
    hiddenLoadoutBackdrop:SetSize(ScrW(), ScrH())
    hiddenLoadoutBackdrop:SetVisible(true)
    hiddenLoadoutBackdrop:SetMouseInputEnabled(true)
    hiddenLoadoutBackdrop:SetKeyboardInputEnabled(false)

    return hiddenLoadoutBackdrop
end

local function removeHiddenLoadoutBackdrop()
    if IsValid(hiddenLoadoutBackdrop) then
        hiddenLoadoutBackdrop:Remove()
        hiddenLoadoutBackdrop = nil
    end
end

local CARD = {}

function CARD:Init()
    self:SetText("")
    self:SetSize(198, 136)

    self.Icon = self:Add("SpawnIcon")
    self.Icon:SetPos(8, 8)
    self.Icon:SetSize(64, 64)
    self.Icon:SetMouseInputEnabled(false)

    self.Placeholder = self:Add("DLabel")
    self.Placeholder:SetPos(8, 8)
    self.Placeholder:SetSize(64, 64)
    self.Placeholder:SetFont("HiddenLoadout_Small")
    self.Placeholder:SetTextColor(COL_TEXT_DIM)
    self.Placeholder:SetContentAlignment(5)
    self.Placeholder:SetText("NO\nMODEL")

    self.Title = self:Add("DLabel")
    self.Title:SetPos(80, 10)
    self.Title:SetSize(82, 38)
    self.Title:SetFont("HiddenLoadout_Label")
    self.Title:SetTextColor(COL_TEXT)
    self.Title:SetWrap(true)
    self.Title:SetAutoStretchVertical(true)

    self.Meta = self:Add("DLabel")
    self.Meta:SetPos(80, 52)
    self.Meta:SetSize(82, 26)
    self.Meta:SetFont("HiddenLoadout_Small")
    self.Meta:SetTextColor(COL_TEXT_DIM)
    self.Meta:SetWrap(true)
    self.Meta:SetAutoStretchVertical(true)

    self.Detail = self:Add("DLabel")
    self.Detail:SetPos(8, 84)
    self.Detail:SetSize(154, 24)
    self.Detail:SetFont("HiddenLoadout_Small")
    self.Detail:SetTextColor(COL_TEXT_DIM)
    self.Detail:SetWrap(true)
    self.Detail:SetAutoStretchVertical(true)
end

function CARD:SetEntry(entry, variant)
    self.Entry = entry or {}
    self.Variant = variant or "weapon"

    local name = tostring(self.Entry.name or self.Entry.class or self.Entry.key or "Unknown")
    self.Title:SetText(name)
    self:SetTooltip(name)

    if self.Variant == "armor" then
        self.Meta:SetText(string.format("Score %d | Prot %.1f", tonumber(self.Entry.score) or 0, tonumber(self.Entry.protection) or 0))
        self.Detail:SetText(string.format("Mass %.1f | %s", tonumber(self.Entry.mass) or 0, string.upper(tostring(self.Entry.key or "none"))))
    else
        self.Meta:SetText(string.format("Score %d | %s", tonumber(self.Entry.score) or 0, tostring(self.Entry.caliber or "Unspecified")))
        self.Detail:SetText(string.format("%d dmg | %d RPM | Pen %d", tonumber(self.Entry.damage) or 0, tonumber(self.Entry.rpm) or 0, tonumber(self.Entry.penetration) or 0))
    end

    local modelPath = tostring(self.Entry.model or "")
    local hasModel = modelPath ~= ""
    self.Icon:SetVisible(hasModel)
    self.Placeholder:SetVisible(not hasModel)

    if hasModel then
        self.Icon:SetModel(modelPath)
    end
end

function CARD:SetSelected(isSelected)
    self.Selected = isSelected and true or false
end

function CARD:PerformLayout(w, h)
    local pad = 8
    local iconSize = math.Clamp(math.floor(math.min(w, h) * 0.42), 58, 88)
    local rightX = pad + iconSize + pad
    local rightW = math.max(w - rightX - pad, 48)

    self.Icon:SetPos(pad, pad)
    self.Icon:SetSize(iconSize, iconSize)

    self.Placeholder:SetPos(pad, pad)
    self.Placeholder:SetSize(iconSize, iconSize)

    self.Title:SetPos(rightX, pad)
    self.Title:SetSize(rightW, math.max(28, math.floor(h * 0.28)))

    self.Meta:SetPos(rightX, pad + math.floor(iconSize * 0.58))
    self.Meta:SetSize(rightW, math.max(24, math.floor(h * 0.2)))

    local detailY = math.max(pad + iconSize + 8, h - 34)
    self.Detail:SetPos(pad, detailY)
    self.Detail:SetSize(w - pad * 2, math.max(24, h - detailY - pad))
end

function CARD:DoClick()
    if isfunction(self.OnChoose) then
        self:OnChoose(self.Entry)
    end
end

function CARD:Paint(w, h)
    local fill = themeColor("Secondary", COL_PANEL)
    local outline = themeColor("Outline", COL_BORDER)

    if self.Selected then
        fill = themeColor("Primary", COL_ACCENT)
        outline = brightenColor(fill, 35)
    elseif self:IsHovered() then
        fill = brightenColor(fill, 10)
    end

    draw.RoundedBox(8, 0, 0, w, h, fill)
    surface.SetDrawColor(outline)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

vgui.Register("ZBHiddenLoadoutChoiceCard", CARD, "DButton")

local PREVIEW = {}

function PREVIEW:Init()
    self.ArmorModels = {}
    self.WeaponModel = nil
    self.WeaponData = nil
    self.Selection = {
        armor = {},
    }
    self.EntryMaps = {
        primary = {},
        secondary = {},
        armor = {},
    }

    self:SetFOV(34)
    self:SetCamPos(Vector(84, 0, 42))
    self:SetLookAt(Vector(0, 0, 38))

    local playerModel = IsValid(LocalPlayer()) and LocalPlayer():GetModel() or "models/player/group01/male_04.mdl"
    self:SetModel(playerModel)
end

function PREVIEW:IsFemaleModel()
    local entity = self.Entity
    local modelPath = IsValid(entity) and string.lower(entity:GetModel() or "") or ""
    return string.find(modelPath, "female", 1, true) ~= nil
end

function PREVIEW:ClearAttachmentModels()
    for key, model in pairs(self.ArmorModels or {}) do
        if IsValid(model) then
            model:Remove()
        end
        self.ArmorModels[key] = nil
    end

    if IsValid(self.WeaponModel) then
        self.WeaponModel:Remove()
    end

    self.WeaponModel = nil
end

function PREVIEW:OnRemove()
    self:ClearAttachmentModels()
end

function PREVIEW:SetPreviewState(payload, maps, selection)
    self.Selection = selection or {
        armor = {},
    }
    self.EntryMaps = maps or self.EntryMaps

    local modelPath = tostring((payload and payload.playerModel) or "")
    if modelPath == "" then
        modelPath = IsValid(LocalPlayer()) and LocalPlayer():GetModel() or "models/player/group01/male_04.mdl"
    end

    if not IsValid(self.Entity) or self.Entity:GetModel() ~= modelPath then
        self:SetModel(modelPath)
        self._sequenceSet = false
        self._sequenceActivity = nil
    end

    self:SyncWeaponModel()
end

function PREVIEW:SyncWeaponModel()
    local entry = self.EntryMaps.primary[self.Selection.primary] or self.EntryMaps.secondary[self.Selection.secondary]
    local weaponData = getPreviewWeaponInfo(entry)
    local poseKey = weaponData and weaponData.poseKey or ""

    if self._previewPoseKey ~= poseKey and IsValid(self.Entity) then
        self:SetModel(self.Entity:GetModel())
        self._sequenceSet = false
        self._sequenceActivity = nil
    end

    self._previewPoseKey = poseKey
    self.WeaponData = weaponData

    if not weaponData then
        if IsValid(self.WeaponModel) then
            self.WeaponModel:Remove()
            self.WeaponModel = nil
        end
        return
    end

    if not IsValid(self.WeaponModel) or self.WeaponModel:GetModel() ~= weaponData.model then
        if IsValid(self.WeaponModel) then
            self.WeaponModel:Remove()
        end

        self.WeaponModel = ClientsideModel(weaponData.model, RENDERGROUP_BOTH)
        self.WeaponModel:SetNoDraw(true)
    end
end

function PREVIEW:EnsureArmorModel(slotName, entry)
    if not entry or tostring(entry.model or "") == "" then
        local oldModel = self.ArmorModels[slotName]
        if IsValid(oldModel) then
            oldModel:Remove()
        end
        self.ArmorModels[slotName] = nil
        return nil
    end

    local model = self.ArmorModels[slotName]
    if not IsValid(model) or model:GetModel() ~= entry.model then
        if IsValid(model) then
            model:Remove()
        end

        model = ClientsideModel(entry.model, RENDERGROUP_BOTH)
        model:SetNoDraw(true)
        self.ArmorModels[slotName] = model
    end

    local targetScale = self:IsFemaleModel() and (tonumber(entry.femscale) or tonumber(entry.scale) or 1) or (tonumber(entry.scale) or 1)
    if model._hiddenScale ~= targetScale then
        model:SetModelScale(targetScale, 0)
        model._hiddenScale = targetScale
    end

    local targetMaterial = tostring(entry.material or "")
    if model._hiddenMaterial ~= targetMaterial then
        model:SetSubMaterial(0, targetMaterial ~= "" and targetMaterial or nil)
        model._hiddenMaterial = targetMaterial
    end

    return model
end

function PREVIEW:LayoutEntity(entity)
    if not IsValid(entity) then
        return
    end

    local desiredActivity = self.WeaponData and self.WeaponData.activity or ACT_HL2MP_IDLE

    if not self._sequenceSet or self._sequenceActivity ~= desiredActivity then
        local idleSequence = entity:SelectWeightedSequence(desiredActivity)
        if not idleSequence or idleSequence < 0 then
            idleSequence = entity:LookupSequence("idle_all_01")
        end

        if idleSequence and idleSequence >= 0 then
            entity:ResetSequence(idleSequence)
            entity:SetCycle(0)
            entity:ResetSequenceInfo()
        end

        self._sequenceActivity = desiredActivity
        self._sequenceSet = true
    end

    entity:SetAngles(Angle(0, RealTime() * 14 % 360, 0))
    entity:FrameAdvance(FrameTime())
end

function PREVIEW:PostDrawModel(entity)
    if not IsValid(entity) then
        return
    end

    if self.WeaponData and hg then
        if isfunction(hg.set_holdrh) then
            hg.set_holdrh(entity, self.WeaponData.rightHold)
        end

        if self.WeaponData.useLeftHand and isfunction(hg.set_hold) then
            hg.set_hold(entity, self.WeaponData.leftHold)
        end
    end

    if IsValid(self.WeaponModel) then
        local weaponPos, weaponAng = getPreviewWeaponTransform(entity)
        if weaponPos and weaponAng then
            self.WeaponModel:SetRenderOrigin(weaponPos)
            self.WeaponModel:SetRenderAngles(weaponAng)
            self.WeaponModel:DrawModel()
        end
    end

    local isFemale = self:IsFemaleModel()
    for _, slotName in ipairs(MODE:GetHiddenLoadoutSlots()) do
        local armorKey = self.Selection.armor[slotName]
        local entry = self.EntryMaps.armor[slotName] and self.EntryMaps.armor[slotName][armorKey] or nil
        local armorModel = self:EnsureArmorModel(slotName, entry)
        if not IsValid(armorModel) or not entry then
            continue
        end

        local boneIndex = entity:LookupBone(tostring(entry.bone or ""))
        local boneMatrix = boneIndex and entity:GetBoneMatrix(boneIndex) or nil
        if not boneMatrix then
            continue
        end

        local bonePos = boneMatrix:GetTranslation()
        local boneAng = boneMatrix:GetAngles()

        if isFemale and istable(entry.femPos) then
            local femPos = unpackVector(entry.femPos)
            bonePos:Add(boneAng:Forward() * femPos.x + boneAng:Up() * femPos.y + boneAng:Right() * femPos.z)
        end

        local renderPos, renderAng = LocalToWorld(unpackVector(entry.pos), unpackAngle(entry.ang), bonePos, boneAng)
        armorModel:SetRenderOrigin(renderPos)
        armorModel:SetRenderAngles(renderAng)
        armorModel:DrawModel()
    end
end

vgui.Register("ZBHiddenLoadoutPreview", PREVIEW, "DModelPanel")

local PANEL = {}

function PANEL:Init()
    self:SetSize(1180, 760)
    self:SetTitle("")
    self:ShowCloseButton(false)

    self.Payload = {}
    self.EntryMaps = {
        primary = {},
        secondary = {},
        armor = {},
    }
    self.Selection = {
        armor = {},
    }
    self.OriginalSelection = {
        armor = {},
    }
    self.PublicPresetMap = {}
    self.SelectedPublicPresetId = nil
    self.IsOverBudget = false
    self.HasPendingChanges = false
    self.LastWarnSecond = nil
    self.WarningFlashUntil = 0

    self.Preview = vgui.Create("ZBHiddenLoadoutPreview", self)
    self.Preview:SetPos(12, 52)
    self.Preview:SetSize(390, 640)

    self.PreviewTitle = vgui.Create("DLabel", self)
    self.PreviewTitle:SetPos(12, 18)
    self.PreviewTitle:SetSize(390, 24)
    self.PreviewTitle:SetFont("HiddenLoadout_Title")
    self.PreviewTitle:SetTextColor(COL_TEXT)
    self.PreviewTitle:SetText("IRIS Loadout Builder")

    self.PreviewHint = vgui.Create("DLabel", self)
    self.PreviewHint:SetPos(12, 698)
    self.PreviewHint:SetSize(390, 46)
    self.PreviewHint:SetFont("HiddenLoadout_Small")
    self.PreviewHint:SetTextColor(COL_TEXT_DIM)
    self.PreviewHint:SetWrap(true)
    self.PreviewHint:SetAutoStretchVertical(true)
    self.PreviewHint:SetText("Use the model cards to compare gear quickly. Your saved IRIS loadout applies when Hidden prep ends.")

    self.BudgetLabel = vgui.Create("DLabel", self)
    self.BudgetLabel:SetPos(420, 18)
    self.BudgetLabel:SetSize(350, 24)
    self.BudgetLabel:SetFont("HiddenLoadout_Title")
    self.BudgetLabel:SetTextColor(COL_TEXT)

    self.StatusLabel = vgui.Create("DLabel", self)
    self.StatusLabel:SetPos(780, 20)
    self.StatusLabel:SetSize(388, 20)
    self.StatusLabel:SetFont("HiddenLoadout_Small")
    self.StatusLabel:SetTextColor(COL_TEXT_DIM)
    self.StatusLabel:SetContentAlignment(6)

    self.Sheet = vgui.Create("DPropertySheet", self)
    self.Sheet:SetPos(420, 52)
    self.Sheet:SetSize(748, 560)

    self.PrimaryPanel = vgui.Create("DPanel", self.Sheet)
    self.PrimaryPanel:Dock(FILL)
    self.PrimaryPanel.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, COL_PANEL)
    end
    self.Sheet:AddSheet("Primary", self.PrimaryPanel, "icon16/gun.png")

    self.PrimarySearch = vgui.Create("DTextEntry", self.PrimaryPanel)
    self.PrimarySearch:SetPos(12, 12)
    self.PrimarySearch:SetSize(724, 26)
    setEntryPlaceholder(self.PrimarySearch, "Filter primary weapons by name, class, or caliber")
    styleSearchEntry(self.PrimarySearch)

    self.PrimaryCardsScroll = vgui.Create("DScrollPanel", self.PrimaryPanel)
    self.PrimaryCardsScroll:SetPos(12, 46)
    self.PrimaryCardsScroll:SetSize(724, 414)

    self.PrimaryCards = vgui.Create("DIconLayout", self.PrimaryCardsScroll)
    self.PrimaryCards:Dock(TOP)
    self.PrimaryCards:SetSpaceY(8)
    self.PrimaryCards:SetSpaceX(8)

    self.PrimaryStats = vgui.Create("DLabel", self.PrimaryPanel)
    self.PrimaryStats:SetPos(12, 472)
    self.PrimaryStats:SetSize(724, 72)
    self.PrimaryStats:SetFont("HiddenLoadout_Mono")
    self.PrimaryStats:SetTextColor(COL_TEXT_DIM)
    self.PrimaryStats:SetWrap(true)
    self.PrimaryStats:SetAutoStretchVertical(true)

    self.SecondaryPanel = vgui.Create("DPanel", self.Sheet)
    self.SecondaryPanel:Dock(FILL)
    self.SecondaryPanel.Paint = self.PrimaryPanel.Paint
    self.Sheet:AddSheet("Sidearm", self.SecondaryPanel, "icon16/gun.png")

    self.SecondarySearch = vgui.Create("DTextEntry", self.SecondaryPanel)
    self.SecondarySearch:SetPos(12, 12)
    self.SecondarySearch:SetSize(724, 26)
    setEntryPlaceholder(self.SecondarySearch, "Filter sidearms by name, class, or caliber")
    styleSearchEntry(self.SecondarySearch)

    self.SecondaryCardsScroll = vgui.Create("DScrollPanel", self.SecondaryPanel)
    self.SecondaryCardsScroll:SetPos(12, 46)
    self.SecondaryCardsScroll:SetSize(724, 414)

    self.SecondaryCards = vgui.Create("DIconLayout", self.SecondaryCardsScroll)
    self.SecondaryCards:Dock(TOP)
    self.SecondaryCards:SetSpaceY(8)
    self.SecondaryCards:SetSpaceX(8)

    self.SecondaryStats = vgui.Create("DLabel", self.SecondaryPanel)
    self.SecondaryStats:SetPos(12, 472)
    self.SecondaryStats:SetSize(724, 72)
    self.SecondaryStats:SetFont("HiddenLoadout_Mono")
    self.SecondaryStats:SetTextColor(COL_TEXT_DIM)
    self.SecondaryStats:SetWrap(true)
    self.SecondaryStats:SetAutoStretchVertical(true)

    self.ArmorPanel = vgui.Create("DPanel", self.Sheet)
    self.ArmorPanel:Dock(FILL)
    self.ArmorPanel.Paint = self.PrimaryPanel.Paint
    self.Sheet:AddSheet("Armor", self.ArmorPanel, "icon16/shield.png")

    self.ArmorSections = {}
    self.ArmorStats = {}

    self.ArmorScroll = vgui.Create("DPanel", self.ArmorPanel)
    self.ArmorScroll:SetPos(12, 12)
    self.ArmorScroll:SetSize(724, 532)
    self.ArmorScroll.Paint = nil

    for _, slotName in ipairs(MODE:GetHiddenLoadoutSlots()) do
        local section = vgui.Create("DPanel", self.ArmorScroll)
        section:SetSize(172, 236)
        section.Paint = function(_, w, h)
            draw.RoundedBox(6, 0, 0, w, h, COL_PANEL_DARK)
            surface.SetDrawColor(COL_BORDER)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local slotLabel = section:Add("DLabel")
        slotLabel:SetPos(12, 10)
        slotLabel:SetSize(160, 20)
        slotLabel:SetFont("HiddenLoadout_Label")
        slotLabel:SetTextColor(COL_TEXT)
        slotLabel:SetText(string.upper(slotName))

        local selectedLabel = section:Add("DLabel")
        selectedLabel:SetPos(12, 30)
        selectedLabel:SetSize(148, 28)
        selectedLabel:SetFont("HiddenLoadout_Small")
        selectedLabel:SetTextColor(COL_TEXT_DIM)
        selectedLabel:SetWrap(true)
        selectedLabel:SetAutoStretchVertical(true)
        selectedLabel:SetText("Selected: None")

        local searchEntry = section:Add("DTextEntry")
        searchEntry:SetPos(12, 64)
        searchEntry:SetSize(148, 26)
        setEntryPlaceholder(searchEntry, "Filter " .. slotName .. " armor by name or key")
        styleSearchEntry(searchEntry)

        local cardsScroll = section:Add("DScrollPanel")
        cardsScroll:SetPos(12, 98)
        cardsScroll:SetSize(148, 100)

        local cardsLayout = cardsScroll:Add("DIconLayout")
        cardsLayout:Dock(TOP)
        cardsLayout:SetSpaceY(6)
        cardsLayout:SetSpaceX(6)

        local statsLabel = section:Add("DLabel")
        statsLabel:SetPos(12, 204)
        statsLabel:SetSize(148, 28)
        statsLabel:SetFont("HiddenLoadout_Mono")
        statsLabel:SetTextColor(COL_TEXT_DIM)
        statsLabel:SetWrap(true)
        statsLabel:SetAutoStretchVertical(true)

        self.ArmorSections[slotName] = {
            Panel = section,
            Search = searchEntry,
            CardsScroll = cardsScroll,
            Cards = cardsLayout,
            SelectedLabel = selectedLabel,
        }
        self.ArmorStats[slotName] = statsLabel
    end

    self.PublicPanel = vgui.Create("DPanel", self.Sheet)
    self.PublicPanel:Dock(FILL)
    self.PublicPanel.Paint = self.PrimaryPanel.Paint
    self.Sheet:AddSheet("Public", self.PublicPanel, "icon16/group.png")

    self.PublicSearch = vgui.Create("DTextEntry", self.PublicPanel)
    setEntryPlaceholder(self.PublicSearch, "Filter public presets by name or author")
    styleSearchEntry(self.PublicSearch)

    self.PublicList = vgui.Create("DListView", self.PublicPanel)
    self.PublicList:SetMultiSelect(false)
    self.PublicList:AddColumn("Preset")
    self.PublicList:AddColumn("Author")
    self.PublicList:AddColumn("Cost")
    self.PublicList:AddColumn("Updated")

    self.PublicInfo = vgui.Create("DLabel", self.PublicPanel)
    self.PublicInfo:SetFont("HiddenLoadout_Small")
    self.PublicInfo:SetTextColor(COL_TEXT)
    self.PublicInfo:SetWrap(true)
    self.PublicInfo:SetAutoStretchVertical(true)
    self.PublicInfo:SetText("Public presets can be imported into your current selection. Click Save afterwards to make one your active round loadout.")

    self.PublicNameEntry = vgui.Create("DTextEntry", self.PublicPanel)
    setEntryPlaceholder(self.PublicNameEntry, "Public preset name (3-32 chars)")
    styleSearchEntry(self.PublicNameEntry)

    self.PublicApplyButton = vgui.Create("DButton", self.PublicPanel)
    styleActionButton(self.PublicApplyButton, "Use Preset", COL_ACCENT)

    self.PublicPublishButton = vgui.Create("DButton", self.PublicPanel)
    styleActionButton(self.PublicPublishButton, "Publish Current", COL_SUCCESS)

    self.SummaryLabel = vgui.Create("DLabel", self)
    self.SummaryLabel:SetPos(420, 622)
    self.SummaryLabel:SetSize(520, 110)
    self.SummaryLabel:SetFont("HiddenLoadout_Small")
    self.SummaryLabel:SetTextColor(COL_TEXT)
    self.SummaryLabel:SetWrap(true)
    self.SummaryLabel:SetAutoStretchVertical(true)

    self.SaveButton = vgui.Create("DButton", self)
    self.SaveButton:SetPos(952, 622)
    self.SaveButton:SetSize(104, 32)
    styleActionButton(self.SaveButton, "Save", COL_SUCCESS)

    self.ResetButton = vgui.Create("DButton", self)
    self.ResetButton:SetPos(952, 662)
    self.ResetButton:SetSize(104, 32)
    styleActionButton(self.ResetButton, "Reset", COL_WARN)

    self.CloseButton = vgui.Create("DButton", self)
    self.CloseButton:SetPos(1064, 622)
    self.CloseButton:SetSize(104, 32)
    styleActionButton(self.CloseButton, "Close", COL_DANGER)

    local function refreshPrimaryCards()
        self:PopulateWeaponCards("primary")
    end
    self.PrimarySearch.OnChange = refreshPrimaryCards
    self.PrimarySearch.OnValueChange = refreshPrimaryCards

    local function refreshSecondaryCards()
        self:PopulateWeaponCards("secondary")
    end
    self.SecondarySearch.OnChange = refreshSecondaryCards
    self.SecondarySearch.OnValueChange = refreshSecondaryCards

    local function refreshPublicPresets()
        self:PopulatePublicPresets()
    end
    self.PublicSearch.OnChange = refreshPublicPresets
    self.PublicSearch.OnValueChange = refreshPublicPresets

    for slotName, section in pairs(self.ArmorSections) do
        local function refreshArmorCards()
            self:PopulateArmorCards(slotName)
        end

        section.Search.OnChange = refreshArmorCards
        section.Search.OnValueChange = refreshArmorCards
    end

    self.PublicList.OnRowSelected = function(_, _, line)
        if not line then
            return
        end

        self.SelectedPublicPresetId = tostring(line.HiddenPresetId or "")
        self:RefreshState()
    end

    self.SaveButton.DoClick = function()
        self:SaveSelection()
    end

    self.ResetButton.DoClick = function()
        self.Selection = table.Copy(self.OriginalSelection)
        self:PopulateControls()
        self:RefreshState()
    end

    self.CloseButton.DoClick = function()
        self:Close()
    end

    self.PublicApplyButton.DoClick = function()
        self:ApplySelectedPublicPreset()
    end

    self.PublicPublishButton.DoClick = function()
        self:PublishCurrentSelection()
    end

    self:ApplyResponsiveFrame()
    self:MakePopup()
    self:InvalidateLayout(true)
end

function PANEL:ApplyResponsiveFrame()
    local isPrepModal = istable(self.Payload) and self.Payload.canEdit
    local padding = isPrepModal and 0 or 12
    local frameW = computeResponsiveSpan(ScrW(), isPrepModal and 1 or 0.92, 1180, padding)
    local frameH = computeResponsiveSpan(ScrH(), isPrepModal and 1 or 0.9, 760, padding)

    if IsValid(hiddenLoadoutBackdrop) then
        hiddenLoadoutBackdrop:SetSize(ScrW(), ScrH())
    end

    self:SetSize(frameW, frameH)
    self:Center()
end

function PANEL:OnScreenSizeChanged()
    self:ApplyResponsiveFrame()
    self:InvalidateLayout(true)
end

function PANEL:UpdateChoiceCardSizes()
    local gap = 8

    local function applyCardSize(layout, availableWidth, minWidth, maxColumns)
        if not IsValid(layout) then
            return
        end

        local cardWidth = computeCardWidth(availableWidth, gap, minWidth, maxColumns)
        local cardHeight = math.Clamp(math.floor(cardWidth * 0.68), 128, 176)

        for _, child in ipairs(layout:GetChildren()) do
            if child.SetEntry then
                child:SetSize(cardWidth, cardHeight)
                child:InvalidateLayout(true)
            elseif child.SetWide then
                child:SetWide(math.max(availableWidth, minWidth))
            end
        end

        layout:InvalidateLayout(true)
        layout:SizeToChildren(false, true)
    end

    local primaryWidth = IsValid(self.PrimaryCardsScroll) and self.PrimaryCardsScroll:GetWide() or 0
    local secondaryWidth = IsValid(self.SecondaryCardsScroll) and self.SecondaryCardsScroll:GetWide() or 0

    applyCardSize(self.PrimaryCards, primaryWidth, 196, primaryWidth >= 940 and 4 or 3)
    applyCardSize(self.SecondaryCards, secondaryWidth, 196, secondaryWidth >= 940 and 4 or 3)

    for _, slotName in ipairs(MODE:GetHiddenLoadoutSlots()) do
        local section = self.ArmorSections[slotName]
        if section and IsValid(section.CardsScroll) then
            local armorWidth = section.CardsScroll:GetWide()
            applyCardSize(section.Cards, armorWidth, 108, armorWidth >= 320 and 2 or 1)
        end
    end
end

function PANEL:PerformLayout(w, h)
    if not IsValid(self.PreviewTitle) then
        return
    end

    local pad = math.Clamp(math.floor(w * 0.014), 12, 20)
    local topBarH = math.Clamp(math.floor(h * 0.04), 24, 34)
    local previewW = math.Clamp(math.floor(w * 0.31), 250, 470)
    if w <= 1024 then
        previewW = math.Clamp(math.floor(w * 0.28), 220, 360)
    end

    local contentX = pad + previewW + pad
    local contentW = math.max(w - contentX - pad, 320)
    local topY = pad
    local contentY = topY + topBarH + 10
    local bottomAreaH = math.Clamp(math.floor(h * 0.18), 118, 150)
    local hintH = math.Clamp(math.floor(h * 0.085), 46, 72)
    local previewH = math.max(h - contentY - hintH - pad * 2, 220)
    local sheetH = math.max(h - contentY - bottomAreaH - pad * 2, 240)
    local summaryY = contentY + sheetH + 10
    local summaryH = math.max(h - summaryY - pad, 70)
    local buttonGap = 10
    local buttonW = math.Clamp(math.floor(contentW * 0.16), 118, 170)
    local buttonH = math.Clamp(math.floor(summaryH * 0.38), 34, 42)
    local buttonLeftX = contentX + contentW - (buttonW * 2) - buttonGap
    local buttonRightX = contentX + contentW - buttonW
    local secondRowY = summaryY + buttonH + buttonGap
    local summaryW = math.max(buttonLeftX - contentX - 12, 200)

    self.PreviewTitle:SetPos(pad, topY)
    self.PreviewTitle:SetSize(previewW, topBarH)

    self.BudgetLabel:SetPos(contentX, topY)
    self.BudgetLabel:SetSize(math.max(contentW * 0.5, 220), topBarH)

    self.StatusLabel:SetPos(contentX + math.max(contentW - 280, 120), topY)
    self.StatusLabel:SetSize(math.min(280, contentW), topBarH)

    self.Preview:SetPos(pad, contentY)
    self.Preview:SetSize(previewW, previewH)

    self.PreviewHint:SetPos(pad, contentY + previewH + 8)
    self.PreviewHint:SetSize(previewW, hintH)

    self.Sheet:SetPos(contentX, contentY)
    self.Sheet:SetSize(contentW, sheetH)

    self.SummaryLabel:SetPos(contentX, summaryY)
    self.SummaryLabel:SetSize(summaryW, summaryH)

    self.SaveButton:SetPos(buttonLeftX, summaryY)
    self.SaveButton:SetSize(buttonW, buttonH)

    self.CloseButton:SetPos(buttonRightX, summaryY)
    self.CloseButton:SetSize(buttonW, buttonH)

    self.ResetButton:SetPos(buttonLeftX, secondRowY)
    self.ResetButton:SetSize(buttonW, buttonH)

    local panelPad = 12
    local searchH = 28
    local statsH = 60
    local tabsApproxH = 34
    local panelW = math.max(contentW - panelPad * 2, 120)
    local panelH = math.max(sheetH - tabsApproxH, 120)
    local cardsY = panelPad + searchH + 8
    local cardsH = math.max(panelH - cardsY - statsH - panelPad, 110)

    self.PrimarySearch:SetPos(panelPad, panelPad)
    self.PrimarySearch:SetSize(panelW, searchH)
    self.PrimaryCardsScroll:SetPos(panelPad, cardsY)
    self.PrimaryCardsScroll:SetSize(panelW, cardsH)
    self.PrimaryStats:SetPos(panelPad, cardsY + cardsH + 8)
    self.PrimaryStats:SetSize(panelW, statsH)

    self.SecondarySearch:SetPos(panelPad, panelPad)
    self.SecondarySearch:SetSize(panelW, searchH)
    self.SecondaryCardsScroll:SetPos(panelPad, cardsY)
    self.SecondaryCardsScroll:SetSize(panelW, cardsH)
    self.SecondaryStats:SetPos(panelPad, cardsY + cardsH + 8)
    self.SecondaryStats:SetSize(panelW, statsH)

    self.ArmorScroll:SetPos(panelPad, panelPad)
    self.ArmorScroll:SetSize(panelW, math.max(panelH - panelPad * 2, 120))

    local armorSectionGap = 10
    local armorSectionW = math.max(math.floor((self.ArmorScroll:GetWide() - armorSectionGap * (#MODE:GetHiddenLoadoutSlots() - 1)) / math.max(#MODE:GetHiddenLoadoutSlots(), 1)), 120)
    local armorSectionH = self.ArmorScroll:GetTall()
    local armorCardsY = 98
    local armorStatsH = 44
    local armorCardsH = math.max(armorSectionH - armorCardsY - armorStatsH - 12, 90)

    for index, slotName in ipairs(MODE:GetHiddenLoadoutSlots()) do
        local section = self.ArmorSections[slotName]
        local statsLabel = self.ArmorStats[slotName]
        if section and IsValid(section.Panel) then
            local sectionX = (index - 1) * (armorSectionW + armorSectionGap)

            section.Panel:SetPos(sectionX, 0)
            section.Panel:SetSize(armorSectionW, armorSectionH)
            section.SelectedLabel:SetPos(12, 30)
            section.SelectedLabel:SetSize(math.max(armorSectionW - 24, 88), 30)
            section.Search:SetPos(12, 64)
            section.Search:SetSize(math.max(armorSectionW - 24, 84), searchH)
            section.CardsScroll:SetPos(12, armorCardsY)
            section.CardsScroll:SetSize(math.max(armorSectionW - 24, 84), armorCardsH)

            if IsValid(statsLabel) then
                statsLabel:SetPos(12, armorCardsY + armorCardsH + 8)
                statsLabel:SetSize(math.max(armorSectionW - 24, 84), armorStatsH)
            end
        end
    end

    local publicInfoH = 60
    local publicEntryH = searchH
    local publicButtonH = 36
    local publicListY = panelPad + searchH + 8
    local publicButtonsY = panelH - panelPad - publicButtonH
    local publicNameY = publicButtonsY - 8 - publicEntryH
    local publicInfoY = publicNameY - 8 - publicInfoH
    local publicListH = math.max(publicInfoY - publicListY - 8, 24)
    local publicButtonW = math.max(math.floor((panelW - 8) * 0.5), 120)

    self.PublicSearch:SetPos(panelPad, panelPad)
    self.PublicSearch:SetSize(panelW, searchH)
    self.PublicList:SetPos(panelPad, publicListY)
    self.PublicList:SetSize(panelW, publicListH)
    self.PublicInfo:SetPos(panelPad, publicInfoY)
    self.PublicInfo:SetSize(panelW, publicInfoH)
    self.PublicNameEntry:SetPos(panelPad, publicNameY)
    self.PublicNameEntry:SetSize(panelW, publicEntryH)
    self.PublicApplyButton:SetPos(panelPad, publicButtonsY)
    self.PublicApplyButton:SetSize(publicButtonW, publicButtonH)
    self.PublicPublishButton:SetPos(panelPad + panelW - publicButtonW, publicButtonsY)
    self.PublicPublishButton:SetSize(publicButtonW, publicButtonH)

    self:UpdateChoiceCardSizes()
end

function PANEL:UpdateModalState()
    local isPrepModal = self:CanCurrentlyEdit()

    if IsValid(self.CloseButton) then
        self.CloseButton:SetVisible(not isPrepModal)
        self.CloseButton:SetEnabled(not isPrepModal)
    end

    if IsValid(hiddenLoadoutBackdrop) then
        hiddenLoadoutBackdrop:SetVisible(true)
        hiddenLoadoutBackdrop:SetMouseInputEnabled(isPrepModal)
    end
end

function PANEL:GetCurrentSelectionPayload()
    return buildSelectionSnapshot(self.Selection)
end

function PANEL:GetPrepRemaining()
    return math.max((tonumber(self.Payload.prepEndsAt) or 0) - CurTime(), 0)
end

function PANEL:CanCurrentlyEdit()
    return self.Payload.canEdit and self:GetPrepRemaining() > 0
end

function PANEL:HasUnsavedChanges()
    return not selectionsEqual(self.Selection, self.OriginalSelection)
end

function PANEL:GetSelectedPublicPreset()
    local presetId = tostring(self.SelectedPublicPresetId or "")
    if presetId == "" then
        return nil
    end

    return self.PublicPresetMap[presetId]
end

function PANEL:Paint(w, h)
    if istable(Nexus) and isfunction(Nexus.DrawRoundedGradient) then
        Nexus:DrawRoundedGradient(0, 0, w, h, themeColor("Background", COL_BG), themeColor("Secondary", COL_PANEL, 42), 8)
    else
        draw.RoundedBox(8, 0, 0, w, h, COL_BG)
    end

    surface.SetDrawColor(COL_BORDER)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

function PANEL:BuildChoiceCards(layout, entries, variant, selectedValue, onChoose, filterText)
    if not IsValid(layout) then
        return
    end

    layout:Clear()

    local matches = 0
    for _, entry in ipairs(entries or {}) do
        if not entryMatchesFilter(entry, filterText) then
            continue
        end

        matches = matches + 1

        local card = layout:Add("ZBHiddenLoadoutChoiceCard")
        card:SetEntry(entry, variant)
        card:SetSelected(tostring(entry[variant == "armor" and "key" or "class"] or "") == tostring(selectedValue or ""))
        card.OnChoose = function(_, chosenEntry)
            onChoose(chosenEntry)
        end
    end

    if matches == 0 then
        local emptyLabel = layout:Add("DLabel")
        emptyLabel:SetSize(640, 28)
        emptyLabel:SetFont("HiddenLoadout_Label")
        emptyLabel:SetTextColor(COL_TEXT_DIM)
        emptyLabel:SetText("No loadout items match the current filter.")
    end

    layout:InvalidateLayout(true)
    layout:SizeToChildren(false, true)
    self:UpdateChoiceCardSizes()
end

function PANEL:UpdateChoiceSelectionStates()
    local function updateLayout(layout, selectedValue, keyName)
        if not IsValid(layout) then
            return
        end

        for _, child in ipairs(layout:GetChildren()) do
            if child.SetSelected and istable(child.Entry) then
                child:SetSelected(tostring(child.Entry[keyName] or "") == tostring(selectedValue or ""))
            end
        end
    end

    updateLayout(self.PrimaryCards, self.Selection.primary, "class")
    updateLayout(self.SecondaryCards, self.Selection.secondary, "class")

    for _, slotName in ipairs(MODE:GetHiddenLoadoutSlots()) do
        local section = self.ArmorSections[slotName]
        if section then
            updateLayout(section.Cards, self.Selection.armor[slotName], "key")
        end
    end
end

function PANEL:GetWeaponCardEntries(slotName)
    local entries = {
        {
            class = "",
            name = "None",
            score = 0,
            caliber = "",
            damage = 0,
            rpm = 0,
            penetration = 0,
            model = "",
        },
    }

    for _, entry in ipairs(self.Payload[slotName] or {}) do
        entries[#entries + 1] = entry
    end

    return entries
end

function PANEL:PopulateWeaponCards(slotName)
    local layout = (slotName == "primary") and self.PrimaryCards or self.SecondaryCards
    local searchEntry = (slotName == "primary") and self.PrimarySearch or self.SecondarySearch
    local selectedClass = tostring(self.Selection[slotName] or "")

    self:BuildChoiceCards(
        layout,
        self:GetWeaponCardEntries(slotName),
        "weapon",
        selectedClass,
        function(entry)
            self.Selection[slotName] = tostring(entry.class or "")
            self:RefreshState()
        end,
        IsValid(searchEntry) and searchEntry:GetValue() or ""
    )
end

function PANEL:PopulateArmorCards(slotName)
    local section = self.ArmorSections[slotName]
    if not section or not IsValid(section.Cards) then
        return
    end

    local selectedKey = tostring(self.Selection.armor[slotName] or "")
    self:BuildChoiceCards(
        section.Cards,
        (self.Payload.armor and self.Payload.armor[slotName]) or {},
        "armor",
        selectedKey,
        function(entry)
            self.Selection.armor[slotName] = tostring(entry.key or "")
            self:RefreshState()
        end,
        IsValid(section.Search) and section.Search:GetValue() or ""
    )
end

function PANEL:PopulatePublicPresets()
    if not IsValid(self.PublicList) then
        return
    end

    local filterText = IsValid(self.PublicSearch) and self.PublicSearch:GetValue() or ""
    local selectedId = tostring(self.SelectedPublicPresetId or "")
    local targetLine = nil

    self.PublicPresetMap = {}
    self.PublicList:Clear()

    for _, preset in ipairs(self.Payload.publicPresets or {}) do
        if not entryMatchesFilter(preset, filterText) then
            continue
        end

        local line = self.PublicList:AddLine(
            tostring(preset.name or "Unnamed"),
            tostring(preset.author or "Anonymous Operative"),
            tostring(preset.cost or 0),
            formatPublicPresetTimestamp(preset.updatedAt)
        )
        line.HiddenPresetId = tostring(preset.id or "")
        self.PublicPresetMap[line.HiddenPresetId] = preset

        if line.HiddenPresetId == selectedId then
            targetLine = line
        end
    end

    if targetLine then
        self.PublicList:SelectItem(targetLine)
    elseif selectedId ~= "" and not self.PublicPresetMap[selectedId] then
        self.SelectedPublicPresetId = nil
    end
end

function PANEL:SetPublicPresets(list)
    self.Payload.publicPresets = istable(list) and list or {}
    self:PopulatePublicPresets()
    self:UpdatePublicPresetInfo()
end

function PANEL:UpdatePublicPresetInfo()
    if not IsValid(self.PublicInfo) then
        return
    end

    local selectedPreset = self:GetSelectedPublicPreset()
    if not selectedPreset then
        self.PublicInfo:SetText("Public presets can be imported into your current selection. Click Save afterwards to make one your active round loadout.")
        return
    end

    local imported = normalizeSelection(self.Payload, self.EntryMaps, selectedPreset.selection)
    local primaryEntry = self.EntryMaps.primary[imported.primary]
    local secondaryEntry = self.EntryMaps.secondary[imported.secondary]
    local lines = {
        string.format("Preset: %s", tostring(selectedPreset.name or "Unnamed")),
        string.format("Author: %s | Cost %d / %d", tostring(selectedPreset.author or "Anonymous Operative"), tonumber(selectedPreset.cost) or 0, tonumber(self.Payload.budget) or 0),
        string.format("Primary: %s | Sidearm: %s", primaryEntry and primaryEntry.name or "None", secondaryEntry and secondaryEntry.name or "None"),
        "Use Preset imports this into your current selection. Click Save to make it your active Hidden round loadout.",
    }

    self.PublicInfo:SetText(table.concat(lines, "\n"))
end

function PANEL:ApplySelectedPublicPreset()
    if not self:CanCurrentlyEdit() then
        chat.AddText(COL_DANGER, "[Hidden] The prep phase already ended.")
        return
    end

    local selectedPreset = self:GetSelectedPublicPreset()
    if not selectedPreset then
        chat.AddText(COL_WARN, "[Hidden] Select a public preset first.")
        return
    end

    self.Selection = normalizeSelection(self.Payload, self.EntryMaps, selectedPreset.selection)
    self:RefreshState()
    chat.AddText(COL_SUCCESS, "[Hidden] Imported public preset: ", color_white, tostring(selectedPreset.name or "Unnamed"))
end

function PANEL:PublishCurrentSelection()
    if not self:CanCurrentlyEdit() then
        chat.AddText(COL_DANGER, "[Hidden] The prep phase already ended.")
        return
    end

    local presetName = IsValid(self.PublicNameEntry) and string.Trim(self.PublicNameEntry:GetValue() or "") or ""
    if #presetName < 3 then
        chat.AddText(COL_WARN, "[Hidden] Public preset names need at least 3 characters.")
        return
    end

    local payload = {
        name = presetName,
        loadout = self:GetCurrentSelectionPayload(),
    }

    local json = util.TableToJSON(payload)
    if not isstring(json) or util.NetworkStringToID("hidden_loadout_publish") == 0 then
        chat.AddText(COL_DANGER, "[Hidden] Public preset publishing is not available yet.")
        return
    end

    net.Start("hidden_loadout_publish")
    net.WriteString(json)
    net.SendToServer()
end

function PANEL:UpdateStatusState()
    if not IsValid(self.StatusLabel) then
        return
    end

    local canEdit = self:CanCurrentlyEdit()
    local prepRemaining = self:GetPrepRemaining()
    local unsaved = self:HasUnsavedChanges()
    local statusText = "Loadout editing is locked."
    local statusColor = COL_TEXT_DIM

    if not canEdit then
        if prepRemaining <= 0 then
            statusText = "Prep expired. Loadout editing is locked."
        end

        self.LastWarnSecond = nil
        self.WarningFlashUntil = 0
        if IsValid(self.SaveButton) then
            self.SaveButton._hiddenOverrideColor = nil
        end
    else
        statusText = string.format("Prep ends in %s", string.FormattedTime(prepRemaining, "%02i:%02i"))
        if unsaved then
            statusText = statusText .. " | Unsaved changes"
            statusColor = COL_WARN
        end

        if unsaved and prepRemaining <= 20 then
            local warningSecond = math.max(math.ceil(prepRemaining), 0)
            if warningSecond > 0 and warningSecond % 5 == 0 and self.LastWarnSecond ~= warningSecond then
                self.LastWarnSecond = warningSecond
                self.WarningFlashUntil = CurTime() + 1.15
                surface.PlaySound("buttons/blip1.wav")
            end

            if CurTime() < (self.WarningFlashUntil or 0) then
                local blinkOn = math.floor(CurTime() * 12) % 2 == 0
                statusColor = blinkOn and COL_DANGER or COL_WARN
                statusText = string.format("Prep ends in %s | UNSAVED CHANGES", string.FormattedTime(prepRemaining, "%02i:%02i"))
                if IsValid(self.SaveButton) then
                    self.SaveButton._hiddenOverrideColor = blinkOn and COL_DANGER or COL_WARN
                end
            elseif IsValid(self.SaveButton) then
                self.SaveButton._hiddenOverrideColor = nil
            end
        else
            self.LastWarnSecond = nil
            self.WarningFlashUntil = 0
            if IsValid(self.SaveButton) then
                self.SaveButton._hiddenOverrideColor = nil
            end
        end
    end

    self.StatusLabel:SetText(statusText)
    self.StatusLabel:SetTextColor(statusColor)
end

function PANEL:Think()
    self:UpdateStatusState()
    self:UpdateModalState()

    if IsValid(self.SaveButton) then
        self.SaveButton:SetEnabled(self:CanCurrentlyEdit() and not self.IsOverBudget)
    end

    if IsValid(self.PublicApplyButton) then
        self.PublicApplyButton:SetEnabled(self:CanCurrentlyEdit() and self:GetSelectedPublicPreset() ~= nil)
    end

    if IsValid(self.PublicPublishButton) then
        self.PublicPublishButton:SetEnabled(self:CanCurrentlyEdit() and not self.IsOverBudget)
    end
end

function PANEL:PopulateControls()
    self:PopulateWeaponCards("primary")
    self:PopulateWeaponCards("secondary")

    for _, slotName in ipairs(MODE:GetHiddenLoadoutSlots()) do
        self:PopulateArmorCards(slotName)
    end

    self:PopulatePublicPresets()
end

function PANEL:SetPayload(payload)
    self.Payload = payload or {}
    self.EntryMaps = buildEntryMaps(self.Payload)
    self.Selection = normalizeSelection(self.Payload, self.EntryMaps, self.Payload.selection)
    self.OriginalSelection = table.Copy(self.Selection)
    self.LastWarnSecond = nil
    self.WarningFlashUntil = 0

    if IsValid(self.PrimarySearch) then
        self.PrimarySearch:SetText("")
    end

    if IsValid(self.SecondarySearch) then
        self.SecondarySearch:SetText("")
    end

    if IsValid(self.PublicSearch) then
        self.PublicSearch:SetText("")
    end

    for _, slotName in ipairs(MODE:GetHiddenLoadoutSlots()) do
        local section = self.ArmorSections[slotName]
        if section and IsValid(section.Search) then
            section.Search:SetText("")
        end
    end

    self:ApplyResponsiveFrame()
    self:PopulateControls()
    self:RefreshState()
end

function PANEL:RefreshState()
    local budget = tonumber(self.Payload.budget) or 0
    local totalCost = calculateSelectionCost(self.Payload, self.EntryMaps, self.Selection)
    local overBudget = totalCost > budget
    self.IsOverBudget = overBudget
    self.HasPendingChanges = self:HasUnsavedChanges()

    self.BudgetLabel:SetText(string.format("Budget %d / %d", totalCost, budget))
    self.BudgetLabel:SetTextColor(overBudget and COL_DANGER or COL_SUCCESS)

    local primaryEntry = self.EntryMaps.primary[self.Selection.primary]
    local secondaryEntry = self.EntryMaps.secondary[self.Selection.secondary]
    self.PrimaryStats:SetText(formatWeaponStats(primaryEntry))
    self.SecondaryStats:SetText(formatWeaponStats(secondaryEntry))

    local summaryLines = {
        string.format("Primary: %s", primaryEntry and primaryEntry.name or "None"),
        string.format("Sidearm: %s", secondaryEntry and secondaryEntry.name or "None"),
    }

    for _, slotName in ipairs(MODE:GetHiddenLoadoutSlots()) do
        local armorEntry = self.EntryMaps.armor[slotName] and self.EntryMaps.armor[slotName][self.Selection.armor[slotName]] or nil
        local armorName = armorEntry and armorEntry.name or "None"
        summaryLines[#summaryLines + 1] = string.format("%s: %s", string.upper(slotName), armorName)

        local section = self.ArmorSections[slotName]
        if section and IsValid(section.SelectedLabel) then
            section.SelectedLabel:SetText(string.format("Selected: %s", armorName))
        end

        local statsLabel = self.ArmorStats[slotName]
        if IsValid(statsLabel) then
            statsLabel:SetText(formatArmorStats(armorEntry))
        end
    end

    summaryLines[#summaryLines + 1] = self.HasPendingChanges and "Status: Unsaved changes pending. Click Save before prep ends." or "Status: Personal loadout saved."

    self.SummaryLabel:SetText(table.concat(summaryLines, "\n"))
    self.SaveButton:SetEnabled(self:CanCurrentlyEdit() and not overBudget)
    self.PublicApplyButton:SetEnabled(self:CanCurrentlyEdit() and self:GetSelectedPublicPreset() ~= nil)
    self.PublicPublishButton:SetEnabled(self:CanCurrentlyEdit() and not overBudget)
    self:UpdatePublicPresetInfo()
    self:UpdateStatusState()
    self:UpdateChoiceSelectionStates()
    self.Preview:SetPreviewState(self.Payload, self.EntryMaps, self.Selection)
end

function PANEL:SaveSelection()
    if not self:CanCurrentlyEdit() then
        chat.AddText(COL_DANGER, "[Hidden] The prep phase already ended.")
        return
    end

    local payload = self:GetCurrentSelectionPayload()

    local json = util.TableToJSON(payload)
    if not isstring(json) or util.NetworkStringToID("hidden_loadout_save") == 0 then
        chat.AddText(COL_DANGER, "[Hidden] Hidden loadout save is not available yet.")
        return
    end

    net.Start("hidden_loadout_save")
    net.WriteString(json)
    net.SendToServer()
end

function PANEL:Close()
    if self:CanCurrentlyEdit() then
        return
    end

    self:Remove()
end

function PANEL:OnRemove()
    removeHiddenLoadoutBackdrop()
end

vgui.Register("ZBHiddenLoadoutEditor", PANEL, "DFrame")

local function openHiddenLoadoutEditor(payload)
    hiddenLoadoutPayload = payload

    local backdrop = ensureHiddenLoadoutBackdrop()

    if not IsValid(hiddenLoadoutFrame) then
        hiddenLoadoutFrame = vgui.Create("ZBHiddenLoadoutEditor", backdrop)
    end

    hiddenLoadoutFrame:SetPayload(payload)
    hiddenLoadoutFrame:SetVisible(true)
    hiddenLoadoutFrame:MakePopup()
end

net.Receive("hidden_loadout_sync", function()
    local raw = net.ReadString()
    local payload = util.JSONToTable(raw or "")
    if not istable(payload) then
        return
    end

    openHiddenLoadoutEditor(payload)
end)

net.Receive("hidden_public_presets_sync", function()
    local raw = net.ReadString()
    local payload = util.JSONToTable(raw or "")
    if not istable(payload) then
        return
    end

    if istable(hiddenLoadoutPayload) then
        hiddenLoadoutPayload.publicPresets = payload
    end

    if IsValid(hiddenLoadoutFrame) then
        hiddenLoadoutFrame:SetPublicPresets(payload)
    end
end)

net.Receive("hidden_prep_state", function()
    local isPreparation = net.ReadBool()
    if isPreparation then
        return
    end

    if IsValid(hiddenLoadoutFrame) then
        hiddenLoadoutFrame:Close()
        hiddenLoadoutFrame = nil
    end

    removeHiddenLoadoutBackdrop()
end)

concommand.Add("zb_hidden_loadout", function()
    if util.NetworkStringToID("hidden_loadout_request") == 0 then
        chat.AddText(COL_DANGER, "[Hidden] The Hidden loadout builder is not pooled yet.")
        return
    end

    net.Start("hidden_loadout_request")
    net.SendToServer()
end)