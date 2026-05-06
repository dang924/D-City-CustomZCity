if SERVER then return end

hg = hg or {}
hg.Appearance = hg.Appearance or {}
hg.AppearanceTool = hg.AppearanceTool or {}

local APmodule = hg.Appearance
local TOOLMODULE = hg.AppearanceTool
local PANEL = {}

local colors = {}
colors.secondary = Color(25, 25, 35, 195)
colors.mainText = Color(255, 255, 255, 255)
colors.selectionBG = Color(20, 130, 25, 225)
colors.scrollbarBG = Color(20, 20, 30, 200)
colors.scrollbarGrip = Color(70, 70, 90, 255)
colors.scrollbarGripHover = Color(100, 100, 130, 255)
colors.scrollbarBorder = Color(100, 100, 120, 200)
colors.presetBG = Color(35, 35, 45, 220)
colors.presetHover = Color(50, 50, 65, 240)

local presetsDir = "zcity/appearances/presets/"

local function CopyInto(target, source)
    target = istable(target) and target or {}
    local normalized = TOOLMODULE.NormalizeAppearance(istable(source) and table.Copy(source) or source)
    table.Empty(target)
    table.Merge(target, normalized)
    return target
end

local function SavePreset(strName, tblAppearance)
    file.CreateDir(presetsDir)
    file.Write(presetsDir .. strName .. ".json", util.TableToJSON(tblAppearance, true))
end

local function LoadPreset(strName)
    if not file.Exists(presetsDir .. strName .. ".json", "DATA") then return nil end
    return util.JSONToTable(file.Read(presetsDir .. strName .. ".json", "DATA"))
end

local function GetPresetList()
    file.CreateDir(presetsDir)
    local files = file.Find(presetsDir .. "*.json", "DATA")
    local presets = {}

    for _, fileName in ipairs(files or {}) do
        presets[#presets + 1] = string.StripExtension(fileName)
    end

    table.sort(presets, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return presets
end

local function CreateStyledScrollPanel(parent)
    local scroll = vgui.Create("DScrollPanel", parent)
    local sbar = scroll:GetVBar()
    sbar:SetWide(ScreenScale(4))
    sbar:SetHideButtons(true)

    function sbar:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, colors.scrollbarBG)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    function sbar.btnGrip:Paint(w, h)
        local col = self:IsHovered() and colors.scrollbarGripHover or colors.scrollbarGrip
        draw.RoundedBox(4, 2, 2, w - 4, h - 4, col)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 1)
    end

    return scroll
end

local function OpenSelectionList(title, items, onSelect)
    local frame = vgui.Create("DFrame")
    frame:SetTitle(title or "")
    frame:SetSize(ScreenScale(120), ScreenScale(110))
    frame:Center()
    frame:MakePopup()
    frame:SetDraggable(false)

    function frame:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(18, 18, 24, 248))
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end

    local scroll = CreateStyledScrollPanel(frame)
    scroll:Dock(FILL)
    scroll:DockMargin(ScreenScale(2), ScreenScale(2), ScreenScale(2), ScreenScale(2))

    for _, item in ipairs(items or {}) do
        local button = vgui.Create("DButton", scroll)
        button:Dock(TOP)
        button:DockMargin(2, 2, 2, 0)
        button:SetTall(ScreenScale(14))
        button:SetText(item.label or tostring(item.value))
        button:SetFont("ZCity_Tiny")
        button:SetTextColor(colors.mainText)

        function button:Paint(w, h)
            local bgCol = self:IsHovered() and colors.presetHover or colors.presetBG
            draw.RoundedBox(4, 0, 0, w, h, bgCol)
            surface.SetDrawColor(colors.scrollbarBorder)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        function button:DoClick()
            if onSelect then
                onSelect(item.value, item.label)
            end
            frame:Close()
        end
    end

    return frame
end

local function EnsureAppearanceTableDefaults(panel)
    if not IsValid(panel) then return nil end

    local normalized = TOOLMODULE.NormalizeAppearance(panel.AppearanceTable or {})
    if istable(panel.AppearanceTable) then
        table.Empty(panel.AppearanceTable)
        table.Merge(panel.AppearanceTable, normalized)
    else
        panel.AppearanceTable = normalized
    end

    panel.AppearanceTable.AClothes = panel.AppearanceTable.AClothes or {}
    panel.AppearanceTable.ABodygroups = panel.AppearanceTable.ABodygroups or {}
    panel.AppearanceTable.AAttachments = panel.AppearanceTable.AAttachments or {"none", "none", "none"}

    return panel.AppearanceTable
end

local function FindSubMaterialSlot(materials, materialName)
    if not istable(materials) or not materialName then return nil end

    for matIndex, modelMat in ipairs(materials) do
        if modelMat == materialName then
            return matIndex - 1
        end
    end
end

local function GetAppearanceSexIndex(modelName)
    if APmodule.PlayerModels and APmodule.PlayerModels[2] and APmodule.PlayerModels[2][modelName] then
        return 2
    end

    return 1
end

local function GetSelectedBodygroupValue(appearanceTable, bodygroupName)
    if not appearanceTable or not appearanceTable.ABodygroups or not bodygroupName then return nil end

    return appearanceTable.ABodygroups[bodygroupName]
        or appearanceTable.ABodygroups[string.upper(bodygroupName)]
        or appearanceTable.ABodygroups[string.lower(bodygroupName)]
end

local function ApplyCubCompatiblePreviewAppearance(ent, modelData, appearanceTable)
    if not IsValid(ent) or not istable(modelData) then return end

    local modelName = appearanceTable and appearanceTable.AModel
    local sexIndex = GetAppearanceSexIndex(modelName)
    local materials = ent:GetMaterials()
    local clothesTable = APmodule.Clothes and APmodule.Clothes[sexIndex] or {}
    local appearanceClothes = appearanceTable and appearanceTable.AClothes or {}

    if modelData.submatSlots then
        for slotName, materialName in pairs(modelData.submatSlots) do
            local selectedClothesId
            if slotName == "hands" then
                local selectedHands = GetSelectedBodygroupValue(appearanceTable, "HANDS")
                selectedClothesId = selectedHands and "hands" or "normal"
            else
                selectedClothesId = appearanceClothes[slotName] or "normal"
            end

            local texturePath = clothesTable[selectedClothesId] or clothesTable.normal
            local slotIndex = FindSubMaterialSlot(materials, materialName)

            if slotIndex ~= nil and texturePath then
                ent:SetSubMaterial(slotIndex, texturePath)
            end
        end
    end

    local facemapName = appearanceTable and appearanceTable.AFacemap
    if facemapName and facemapName ~= "Default" then
        local facemapSlots = {}
        local modelKey = string.lower(modelData.mdl or "")
        local multi = hg.Appearance.MultiFacemaps and hg.Appearance.MultiFacemaps[modelKey]

        if multi and multi[facemapName] then
            facemapSlots = multi[facemapName]
        else
            local modelSlot = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[modelKey]
            local slotVariants = modelSlot and hg.Appearance.FacemapsSlots and hg.Appearance.FacemapsSlots[modelSlot]
            if slotVariants and slotVariants[facemapName] then
                facemapSlots = { [modelSlot] = slotVariants[facemapName] }
            end
        end

        for slotName, texturePath in pairs(facemapSlots) do
            local slotIndex = FindSubMaterialSlot(materials, slotName)
            if slotIndex ~= nil and texturePath then
                ent:SetSubMaterial(slotIndex, texturePath)
            end
        end
    end

    local availableBodygroups = hg.Appearance.Bodygroups or {}
    for _, bg in ipairs(ent:GetBodyGroups() or {}) do
        local bodygroupName = bg.name
        local selectedVariant = GetSelectedBodygroupValue(appearanceTable, bodygroupName)
        if not selectedVariant then continue end

        local bodygroupBySex = availableBodygroups[bodygroupName] and availableBodygroups[bodygroupName][sexIndex]
        local bodygroupData = bodygroupBySex and bodygroupBySex[selectedVariant]
        if not bodygroupData then continue end

        local pointItem = bodygroupData.ID and hg.PointShop and hg.PointShop.Items and hg.PointShop.Items[bodygroupData.ID]
        local pointData = pointItem and pointItem.DATA
        if pointData then
            for subMatIndex, subMatPath in pairs(pointData) do
                local matIndex = tonumber(subMatIndex)
                if matIndex ~= nil and isstring(subMatPath) and subMatPath ~= "" then
                    ent:SetSubMaterial(matIndex, subMatPath)
                end
            end
        end

        local targetSubmodel = bodygroupData[1]
        if not targetSubmodel then continue end

        for subIndex = 0, #bg.submodels do
            if bg.submodels[subIndex] == targetSubmodel then
                ent:SetBodygroup(bg.id, subIndex)
                break
            end
        end
    end
end

local function CreateStyledAccessoryMenu(title)
    local menu = vgui.Create("DFrame")
    menu:SetTitle(title or "")
    menu:SetSize(ScreenScale(90), ScreenScale(140))
    local cx, cy = input.GetCursorPos()
    menu:SetPos(cx, cy)
    menu:MakePopup()
    menu:SetDraggable(false)
    menu:ShowCloseButton(false)

    function menu:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(15, 15, 20, 250))
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end

    local function IsPanelInsideMenu(panelToCheck)
        while IsValid(panelToCheck) do
            if panelToCheck == menu then return true end
            panelToCheck = panelToCheck:GetParent()
        end
        return false
    end

    function menu:OnFocusChanged(gained)
        if gained then return end
        timer.Simple(0, function()
            if not IsValid(self) then return end

            local focusedPanel = vgui.GetKeyboardFocus()
            local hoveredPanel = vgui.GetHoveredPanel()
            if IsPanelInsideMenu(focusedPanel) or IsPanelInsideMenu(hoveredPanel) then return end

            self:Close()
        end)
    end

    local scroll = CreateStyledScrollPanel(menu)
    scroll:Dock(FILL)
    scroll:DockMargin(ScreenScale(2), ScreenScale(2), ScreenScale(2), ScreenScale(2))

    local iconLayout = vgui.Create("DIconLayout", scroll)
    iconLayout:Dock(TOP)
    iconLayout:SetSpaceX(ScreenScale(2))
    iconLayout:SetSpaceY(ScreenScale(2))

    menu.IconLayout = iconLayout

    function menu:AddAccessoryIcon(model, accessorKey, accessoryData, onSelect)
        local ico = vgui.Create("DPanel", self.IconLayout)
        local icoSize = ScreenScale(36)
        ico:SetSize(icoSize, icoSize)

        function ico:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 40, 255))
            surface.SetDrawColor(colors.scrollbarBorder)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local spawnIcon = vgui.Create("DModelPanel", ico)
        spawnIcon:Dock(FILL)
        spawnIcon:DockMargin(2, 2, 2, 2)
        spawnIcon:SetModel(model or "models/error.mdl")
        spawnIcon:SetFOV(15)
        spawnIcon:SetLookAt(accessoryData.vpos or Vector(0, 0, 0))
        spawnIcon:SetTooltip(string.NiceName((accessoryData and (accessoryData.name or accessoryData.PrintName)) or accessorKey or "Accessory"))

        function spawnIcon:PreDrawModel()
            if accessoryData and accessoryData.bSetColor then
                local colorDraw = accessoryData.vecColorOveride or (LocalPlayer().GetPlayerColor and LocalPlayer():GetPlayerColor() or LocalPlayer():GetNWVector("PlayerColor", Vector(1, 1, 1)))
                render.SetColorModulation(colorDraw[1], colorDraw[2], colorDraw[3])
            end
        end

        function spawnIcon:PostDrawModel()
            if accessoryData and accessoryData.bSetColor then
                render.SetColorModulation(1, 1, 1)
            end
        end

        timer.Simple(0, function()
            if not IsValid(spawnIcon) or not IsValid(spawnIcon.Entity) then return end
            spawnIcon.Entity:SetSkin((isfunction(accessoryData.skin) and accessoryData.skin()) or (accessoryData.skin or 0))
            spawnIcon.Entity:SetBodyGroups(accessoryData.bodygroups or "0000000")
            if accessoryData.SubMat then
                spawnIcon.Entity:SetSubMaterial(0, accessoryData.SubMat)
            end
        end)

        function spawnIcon:DoClick()
            if onSelect then
                onSelect(accessorKey)
            end
            menu:Close()
        end
    end

    function menu:AddNoneOption(onSelect)
        local button = vgui.Create("DButton", self.IconLayout)
        local icoSize = ScreenScale(36)
        button:SetSize(icoSize, icoSize)
        button:SetText("None")
        button:SetFont("ZCity_Tiny")
        button:SetTextColor(colors.mainText)

        function button:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 40, 255))
            surface.SetDrawColor(colors.scrollbarBorder)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        function button:DoClick()
            if onSelect then
                onSelect("none")
            end
            menu:Close()
        end
    end

    return menu
end

function PANEL:SetAppearance(tblAppearance)
    self.AppearanceTable = CopyInto(self.AppearanceTable or {}, tblAppearance or TOOLMODULE.GetClientConfig())
    APmodule.CurrentEditTable = self.AppearanceTable
end

function PANEL:RefreshFromAppearance()
    if not self.NameEntry or not self.ModelSelector then return end

    local appearance = self.AppearanceTable or TOOLMODULE.GetClientConfig()
    self.NameEntry:SetText(appearance.AName or "")
    self.ModelSelector:SetText(appearance.AModel or "")
end

function PANEL:CloseImportMenus()
    if IsValid(self.ImportMenu) then
        self.ImportMenu:Close()
    end
    if IsValid(self.PresetMenu) then
        self.PresetMenu:Close()
    end
end

function PANEL:OpenAppearanceImportMenu()
    self:CloseImportMenus()

    local items = {}
    for _, name in ipairs((TOOLMODULE.GetImportList and TOOLMODULE.GetImportList()) or {}) do
        items[#items + 1] = { label = name, value = name }
    end

    self.ImportMenu = OpenSelectionList("Load Appearance JSON", items, function(value)
        local loaded = TOOLMODULE.LoadImport and TOOLMODULE.LoadImport(value)
        if not loaded then return end

        self:SetAppearance(loaded)
        self:RefreshFromAppearance()
    end)
end

function PANEL:OpenPresetImportMenu()
    self:CloseImportMenus()

    local items = {}
    for _, name in ipairs((TOOLMODULE.GetPresetImportList and TOOLMODULE.GetPresetImportList()) or {}) do
        items[#items + 1] = { label = name, value = name }
    end

    self.PresetMenu = OpenSelectionList("Load Preset JSON", items, function(value)
        local loaded = TOOLMODULE.LoadPresetImport and TOOLMODULE.LoadPresetImport(value)
        if not loaded then return end

        self:SetAppearance(loaded)
        self:RefreshFromAppearance()
    end)
end

function PANEL:OpenModelSelector(anchor)
    local appearance = EnsureAppearanceTableDefaults(self)
    if not appearance then return end

    self.modelPosID = "All"
    if isfunction(hg.Appearance.OpenModelMenu) then
        local menu = hg.Appearance.OpenModelMenu(anchor or self, appearance.AModel, function(modelName)
            appearance.AModel = modelName
            if IsValid(self.ModelSelector) then
                self.ModelSelector:SetText(modelName or "")
            end
        end, appearance, function()
            self.modelPosID = "All"
        end)

        if IsValid(menu) then
            return menu
        end
    end
end

function PANEL:OpenPartSelector(part, anchor)
    local appearance = EnsureAppearanceTableDefaults(self)
    if not appearance then return end

    local current
    local onSelect
    local positionByPart = {
        main = "Torso",
        pants = "Legs",
        boots = "Boots",
        gloves = "Hands",
        facemap = "Face"
    }

    self.modelPosID = positionByPart[part] or "All"

    if part == "main" then
        current = appearance.AClothes.main
        onSelect = function(id)
            appearance.AClothes.main = id
        end
    elseif part == "pants" then
        current = appearance.AClothes.pants
        onSelect = function(id)
            appearance.AClothes.pants = id
        end
    elseif part == "boots" then
        current = appearance.AClothes.boots
        onSelect = function(id)
            appearance.AClothes.boots = id
        end
    elseif part == "gloves" then
        current = appearance.ABodygroups.HANDS or "Default"
        onSelect = function(id)
            appearance.ABodygroups.HANDS = id
        end
    elseif part == "facemap" then
        current = appearance.AFacemap or "Default"
        onSelect = function(id)
            appearance.AFacemap = id
        end
    end

    local function onClose()
        self.modelPosID = "All"
    end

    if part == "facemap" and isfunction(hg.Appearance.OpenFacemapMenu) then
        local menu = hg.Appearance.OpenFacemapMenu(anchor or self, current, onSelect, appearance, onClose)
        if IsValid(menu) then
            return menu
        end
    elseif (part == "main" or part == "pants" or part == "boots") and isfunction(hg.Appearance.OpenClothesMenu) then
        local menu = hg.Appearance.OpenClothesMenu(anchor or self, part, current, onSelect, appearance, onClose)
        if IsValid(menu) then
            return menu
        end
    end

    local modelData = APmodule.PlayerModels[1][appearance.AModel] or APmodule.PlayerModels[2][appearance.AModel]
    local sexIndex = modelData and modelData.sex and 2 or 1

    local menu = DermaMenu()
    if part == "gloves" then
        for k in SortedPairs((APmodule.Bodygroups.HANDS and APmodule.Bodygroups.HANDS[sexIndex]) or {}) do
            menu:AddOption(k, function()
                onSelect(k)
            end)
        end
    elseif part == "facemap" then
        local facemapModel = modelData and modelData.mdl and APmodule.FacemapsModels[modelData.mdl]
        for k in SortedPairs((facemapModel and APmodule.FacemapsSlots[facemapModel]) or {}) do
            menu:AddOption(k, function()
                onSelect(k)
            end)
        end
    else
        for k in SortedPairs(APmodule.Clothes[sexIndex] or {}) do
            menu:AddOption(k, function()
                onSelect(k)
            end)
        end
    end

    menu:Open()
    function menu:OnRemove()
        onClose()
    end

    return menu
end

function PANEL:OpenBodygroupsShowcase()
    local appearance = EnsureAppearanceTableDefaults(self)
    if not appearance then return end

    if isfunction(hg.Appearance.OpenBodygroupsShowcaseMenu) then
        return hg.Appearance.OpenBodygroupsShowcaseMenu(appearance)
    end
end

function PANEL:OpenShowcase()
    local appearance = EnsureAppearanceTableDefaults(self)
    if not appearance then return end

    if isfunction(hg.Appearance.OpenShowcaseMenu) then
        return hg.Appearance.OpenShowcaseMenu(appearance)
    end
end

function PANEL:OpenAllFacemaps()
    local appearance = EnsureAppearanceTableDefaults(self)
    if not appearance then return end

    if isfunction(hg.Appearance.OpenAllFacemapsMenu) then
        return hg.Appearance.OpenAllFacemapsMenu(appearance)
    end
end

function PANEL:OpenAppearanceTools(anchor)
    if not istable(TOOLMODULE.Menu) or not isfunction(TOOLMODULE.Menu.OpenActionsDropdown) then return nil end

    return TOOLMODULE.Menu.OpenActionsDropdown(self, anchor, {
        "model_selector",
        "bodygroups",
        "all_facemaps",
        "showcase"
    })
end

function PANEL:Init()
    self:SetBorder(false)
    self:SetDraggable(false)
    self:SetName("HG_AppearanceMenu")
    self.UIMode = istable(TOOLMODULE.Menu) and TOOLMODULE.Menu.GetPreferredMode and TOOLMODULE.Menu.GetPreferredMode() or "vanilla"
    self.modelPosID = "All"
    self.AppearanceTable = CopyInto({}, TOOLMODULE.GetClientConfig())
    self.__HGScaleOwnerPanel = self
    APmodule.CurrentEditTable = self.AppearanceTable

    local sizeX, sizeY = self:GetWide(), self:GetTall()
    local main = self
    local tMdl = APmodule.PlayerModels[1][self.AppearanceTable.AModel] or APmodule.PlayerModels[2][self.AppearanceTable.AModel]

    local viewer = vgui.Create("DModelPanel", self)
    viewer:SetSize(sizeX / 2.2, sizeY)
    viewer:SetModel(util.IsValidModel(tostring(tMdl and tMdl.mdl or "")) and tostring(tMdl.mdl) or "models/player/group01/female_01.mdl")
    viewer:SetFOV(75)
    viewer:SetLookAng(Angle(11, 180, 0))
    viewer:SetCamPos(Vector(100, 0, 55))
    viewer:Dock(FILL)
    self.Viewer = viewer

    local offsets = {
        ["All"] = 1,
        ["Head"] = 1.15,
        ["Face"] = 1.1,
        ["Torso"] = 0.9,
        ["Legs"] = 0.4,
        ["Boots"] = 0.1,
        ["Hands"] = 0.5
    }

    function viewer:OnMouseWheeled(delta)
        self.SmoothFOVDelta = self:GetFOV() - delta * 5
    end

    function viewer:Think()
        sizeX, sizeY = main:GetWide(), main:GetTall()
        self.SmoothFOV = LerpFT(0.05, self.SmoothFOV or self:GetFOV(), main.modelPosID == "All" and 75 or 35)
        self.LookAngles = LerpFT(0.05, self.LookAngles or 11, main.modelPosID == "All" and 11 or 0)
        self:SetFOV(self.SmoothFOV)
        self:SetLookAng(Angle(self.LookAngles, 180, 0))
        self.OffsetY = LerpFT(0.1, self.OffsetY or 0, offsets[main.modelPosID] or 1)
    end

    local funpos1x
    local funpos3x

    function viewer:LayoutEntity(entity)
        local lookX, lookY = input.GetCursorPos()
        lookX = lookX / math.max(sizeX, 1) - 0.5
        lookY = lookY / math.max(sizeY, 1) - 0.5

        entity.Angles = entity.Angles or Angle(0, 0, 0)
        entity.Angles = LerpAngle(FrameTime() * 5, entity.Angles, Angle(lookY * 2, (self.Rotate and -179 or 0) - lookX * 75, 0))

        local tbl = main.AppearanceTable
        local modelData = APmodule.PlayerModels[1][tbl.AModel] or APmodule.PlayerModels[2][tbl.AModel]
        if not modelData then return end

        entity:SetNWVector("PlayerColor", Vector(tbl.AColor.r / 255, tbl.AColor.g / 255, tbl.AColor.b / 255))
        entity:SetAngles(entity.Angles)
        entity:SetSequence(entity:LookupSequence("idle_suitcase"))
        entity:SetSubMaterial()
        self:SetCamPos(Vector(100, 0, 55 * (self.OffsetY or 1)))

        if entity:GetModel() ~= modelData.mdl then
            entity:SetModel(modelData.mdl)
            self:SetModel(modelData.mdl)
        end

        ApplyCubCompatiblePreviewAppearance(entity, modelData, tbl)

        if hg.Appearance.ApplyPreviewScale then
            hg.Appearance.ApplyPreviewScale(entity, tbl)
        end

        if IsValid(entity) and entity:LookupBone("ValveBiped.Bip01_Head1") then
            funpos1x = lookX * 25
            funpos3x = -lookX * 75
        end
    end

    function viewer:PostDrawModel(entity)
        for _, attach in ipairs(main.AppearanceTable.AAttachments or {}) do
            DrawAccesories(entity, entity, attach, hg.Accessories[attach], false, true)
        end
        entity:SetupBones()
    end

    local topPanel = vgui.Create("DPanel", viewer)
    topPanel:Dock(TOP)
    topPanel:DockMargin(ScreenScale(100), 0, ScreenScale(100), 0)
    topPanel:SetSize(1, ScreenScale(15))
    function topPanel:Paint(w, h)
        draw.RoundedBox(0, 0, 0, w, h, colors.secondary)
    end

    local modelSelector = vgui.Create("DComboBox", topPanel)
    modelSelector:SetFont("ZCity_Tiny")
    modelSelector:Dock(FILL)
    modelSelector:SetContentAlignment(5)
    modelSelector:SetText(self.AppearanceTable.AModel)
    self.ModelSelector = modelSelector

    function modelSelector:OnSelect(_, str)
        main.AppearanceTable.AModel = str
        APmodule.CurrentEditTable = main.AppearanceTable
    end

    for k in SortedPairs(APmodule.PlayerModels[1]) do
        modelSelector:AddChoice(k)
    end
    for k in SortedPairs(APmodule.PlayerModels[2]) do
        modelSelector:AddChoice(k)
    end

    local bottomContainer = vgui.Create("DPanel", viewer)
    bottomContainer:Dock(BOTTOM)
    bottomContainer:SetSize(1, ScreenScale(70))
    bottomContainer:DockMargin(ScreenScale(44), 0, ScreenScale(44), ScreenScale(8))
    function bottomContainer:Paint() end

    local controlsPanel = vgui.Create("DPanel", bottomContainer)
    controlsPanel:Dock(BOTTOM)
    controlsPanel:SetSize(1, ScreenScale(15))
    function controlsPanel:Paint() end

    local applyButton = vgui.Create("DButton", controlsPanel)
    applyButton:SetSize(ScreenScale(80), ScreenScale(15))
    applyButton:SetFont("ZCity_Tiny")
    applyButton:SetText("Apply To Tool")
    applyButton:Dock(LEFT)
    function applyButton:DoClick()
        TOOLMODULE.SetClientConfig(table.Copy(main.AppearanceTable))
        surface.PlaySound("pwb2/weapons/iron.wav")
        if IsValid(main:GetParent()) and main:GetParent().Close then
            main:GetParent():Close()
        else
            main:Remove()
        end
    end
    function applyButton:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, colors.selectionBG)
        surface.SetDrawColor(Color(30, 160, 35, 255))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local rotateButton = vgui.Create("DButton", controlsPanel)
    rotateButton:SetSize(ScreenScale(72), ScreenScale(15))
    rotateButton:SetFont("ZCity_Tiny")
    rotateButton:SetText("Rotate")
    rotateButton:Dock(LEFT)
    rotateButton:DockMargin(ScreenScale(4), 0, 0, 0)
    function rotateButton:DoClick()
        viewer.Rotate = not viewer.Rotate
        surface.PlaySound("pwb2/weapons/iron.wav")
    end
    function rotateButton:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, colors.secondary)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local saveAnchorButton = vgui.Create("DButton", self)
    saveAnchorButton:SetText("Save")
    saveAnchorButton:SetSize(ScreenScale(80), ScreenScale(15))
    saveAnchorButton:SetAlpha(0)
    saveAnchorButton:SetMouseInputEnabled(false)
    saveAnchorButton:SetKeyboardInputEnabled(false)
    function saveAnchorButton:Paint() end
    function saveAnchorButton:Think()
        if not IsValid(applyButton) then return end
        local x, y = applyButton:LocalToScreen(0, 0)
        local lx, ly = main:ScreenToLocal(x, y)
        self:SetPos(lx, ly)
        self:SetSize(applyButton:GetWide(), applyButton:GetTall())
    end

    local nameEntry = vgui.Create("DTextEntry", controlsPanel)
    nameEntry:SetFont("ZCity_Tiny")
    nameEntry:SetText(self.AppearanceTable.AName)
    nameEntry:Dock(FILL)
    nameEntry:DockMargin(ScreenScale(4), 0, ScreenScale(4), 0)
    nameEntry:SetContentAlignment(5)
    self.NameEntry = nameEntry
    function nameEntry:OnChange()
        main.AppearanceTable.AName = self:GetValue()
    end
    function nameEntry:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(20, 20, 25, 240))
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(colors.mainText, colors.selectionBG, colors.mainText)
    end

    local importPanel = vgui.Create("DPanel", bottomContainer)
    importPanel:SetSize(ScreenScale(72), ScreenScale(16))
    function importPanel:Paint() end
    function importPanel:Think()
        if not IsValid(rotateButton) then return end
        local x, y = rotateButton:LocalToScreen(0, 0)
        local lx, ly = bottomContainer:ScreenToLocal(x, y)
        self:SetPos(lx, math.max(0, ly - self:GetTall() - ScreenScale(2)))
        self:SetWide(rotateButton:GetWide())
    end

    local loadAppearanceButton = vgui.Create("DButton", importPanel)
    loadAppearanceButton:Dock(LEFT)
    loadAppearanceButton:SetWide(math.floor(importPanel:GetWide() / 2) - ScreenScale(1))
    loadAppearanceButton:SetFont("ZCity_Tiny")
    loadAppearanceButton:SetText("Main")
    function loadAppearanceButton:Paint(w, h)
        local bgCol = self:IsHovered() and colors.presetHover or colors.presetBG
        draw.RoundedBox(4, 0, 0, w, h, bgCol)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    function loadAppearanceButton:DoClick()
        main:OpenAppearanceImportMenu()
    end

    local loadPresetButton = vgui.Create("DButton", importPanel)
    loadPresetButton:Dock(FILL)
    loadPresetButton:DockMargin(ScreenScale(2), 0, 0, 0)
    loadPresetButton:SetFont("ZCity_Tiny")
    loadPresetButton:SetText("Preset")
    function loadPresetButton:Paint(w, h)
        local bgCol = self:IsHovered() and colors.presetHover or colors.presetBG
        draw.RoundedBox(4, 0, 0, w, h, bgCol)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    function loadPresetButton:DoClick()
        main:OpenPresetImportMenu()
    end

    local modelButton = vgui.Create("DButton", viewer)
    modelButton:SetSize(ScreenScale(92), ScreenScale(16))
    modelButton:SetFont("ZCity_Tiny")
    modelButton:SetText("APPEARANCE TOOLS")
    modelButton.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, colors.secondary)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    function modelButton:Think()
        self:SetPos(sizeX - self:GetWide() - ScreenScale(8), ScreenScale(8))
    end
    function modelButton:DoClick()
        main:OpenAppearanceTools(self)
    end
    self.AppearanceToolsBtn = modelButton

    if self.UIMode == "cub" then
        local function CreateHiddenPlaceholder(fieldName)
            local placeholder = vgui.Create("DButton", self)
            placeholder:SetSize(1, 1)
            placeholder:SetText("")
            placeholder:SetAlpha(0)
            placeholder:SetMouseInputEnabled(false)
            placeholder:SetKeyboardInputEnabled(false)
            function placeholder:Paint() end
            self[fieldName] = placeholder
        end

        CreateHiddenPlaceholder("ModelSelectorBtn")
        CreateHiddenPlaceholder("ShowcaseBtn")
        CreateHiddenPlaceholder("AllFacemapsBtn")
        CreateHiddenPlaceholder("BodygroupsBtn")
    end

    local accessoryMenus = {}
    local function CloseAccessoryMenus()
        for _, menu in ipairs(accessoryMenus) do
            if IsValid(menu) then
                menu:Close()
            end
        end
        accessoryMenus = {}
    end

    local function CreateAccessoryButton(text, placement, slotIndex, posId, yOffset)
        local button = vgui.Create("DButton", viewer)
        button:SetSize(ScreenScale(100), ScreenScale(16))
        button:SetFont("ZCity_Tiny")
        button:SetText(text)

        function button:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, colors.secondary)
            surface.SetDrawColor(colors.scrollbarBorder)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        function button:Think()
            if funpos1x then
                self:SetPos(sizeX * 0.17 + funpos1x, sizeY * 0.2 + yOffset)
            end
        end

        function button:DoClick()
            main.modelPosID = posId
            CloseAccessoryMenus()

            local selectorMenu = CreateStyledAccessoryMenu("Select " .. text)
            accessoryMenus[#accessoryMenus + 1] = selectorMenu

            for k, v in SortedPairs(hg.Accessories or {}) do
                if v.placement ~= placement and not (placement == "head" and v.placement == "ears") and not (placement == "torso" and v.placement == "spine") then continue end
                selectorMenu:AddAccessoryIcon(v.model, k, v, function(accessorKey)
                    if not IsValid(main) or not istable(main.AppearanceTable) then return end
                    main.AppearanceTable.AAttachments = main.AppearanceTable.AAttachments or {"none", "none", "none"}
                    main.AppearanceTable.AAttachments[slotIndex] = accessorKey
                end)
            end

            selectorMenu:AddNoneOption(function()
                if not IsValid(main) or not istable(main.AppearanceTable) then return end
                main.AppearanceTable.AAttachments = main.AppearanceTable.AAttachments or {"none", "none", "none"}
                main.AppearanceTable.AAttachments[slotIndex] = "none"
            end)

            function selectorMenu:OnClose()
                main.modelPosID = "All"
            end
        end

        return button
    end

    CreateAccessoryButton("Hats", "head", 1, "Head", 0)
    CreateAccessoryButton("Face", "face", 2, "Face", ScreenScale(32))
    CreateAccessoryButton("Body", "torso", 3, "Torso", ScreenScale(64))

    local function PaintPreviewButton(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, colors.secondary)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local function CreateFallbackMenuButton(text, yOffset, posId, generator)
        local button = vgui.Create("DButton", viewer)
        button:SetSize(ScreenScale(100), ScreenScale(16))
        button:SetFont("ZCity_Tiny")
        button:SetText(text)
        button.Paint = PaintPreviewButton

        function button:Think()
            if funpos3x then
                self:SetPos(sizeX * 0.62 - funpos3x, sizeY * 0.2 + yOffset)
            end
        end

        function button:DoClick()
            main.modelPosID = posId
            local menu = generator(self)
            if IsValid(menu) then
                function menu:OnRemove()
                    main.modelPosID = "All"
                end
            else
                main.modelPosID = "All"
            end
        end

        return button
    end

    CreateFallbackMenuButton("Jacket", 0, "Torso", function(button)
        if istable(TOOLMODULE.Menu) and isfunction(TOOLMODULE.Menu.OpenClothes) then
            return TOOLMODULE.Menu.OpenClothes(main, "main", button)
        end
        return main:OpenPartSelector("main", button)
    end)

    CreateFallbackMenuButton("Pants", ScreenScale(32), "Legs", function(button)
        if istable(TOOLMODULE.Menu) and isfunction(TOOLMODULE.Menu.OpenClothes) then
            return TOOLMODULE.Menu.OpenClothes(main, "pants", button)
        end
        return main:OpenPartSelector("pants", button)
    end)

    CreateFallbackMenuButton("Boots", ScreenScale(64), "Boots", function(button)
        if istable(TOOLMODULE.Menu) and isfunction(TOOLMODULE.Menu.OpenClothes) then
            return TOOLMODULE.Menu.OpenClothes(main, "boots", button)
        end
        return main:OpenPartSelector("boots", button)
    end)

    CreateFallbackMenuButton("Gloves", ScreenScale(96), "Hands", function(button)
        if istable(TOOLMODULE.Menu) and isfunction(TOOLMODULE.Menu.OpenGloves) then
            return TOOLMODULE.Menu.OpenGloves(main, button)
        end
        return main:OpenPartSelector("gloves", button)
    end)

    CreateFallbackMenuButton("Facemap", ScreenScale(128), "Face", function(button)
        if istable(TOOLMODULE.Menu) and isfunction(TOOLMODULE.Menu.OpenFacemap) then
            return TOOLMODULE.Menu.OpenFacemap(main, button)
        end
        return main:OpenPartSelector("facemap", button)
    end)

    if self.UIMode == "cub" then
        local randomizeButton = vgui.Create("DButton", self)
        randomizeButton:SetText("")
        randomizeButton:SetFont("ZCity_Tiny")
        randomizeButton.IconMaterial = Material("icon16/arrow_refresh.png", "smooth")

        function randomizeButton:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, colors.secondary)
            surface.SetDrawColor(colors.scrollbarBorder)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            if self.IconMaterial then
                local size = math.max(8, math.floor(h * 0.62))
                local pad = math.floor((h - size) * 0.5)
                surface.SetMaterial(self.IconMaterial)
                surface.SetDrawColor(235, 235, 245, 255)
                surface.DrawTexturedRect(pad, pad, size, size)
            end
        end

        function randomizeButton:Think()
            local margin = ScreenScale(6)
            self:SetSize(math.floor(ScreenScale(11)), math.floor(ScreenScale(11)))
            self:SetPos(margin, main:GetTall() - self:GetTall() - margin)
        end

        function randomizeButton:DoClick()
            local randomAppearance = APmodule.GetRandomAppearance and APmodule.GetRandomAppearance() or {}
            main:SetAppearance(randomAppearance)
            main:RefreshFromAppearance()
            main.modelPosID = "All"
            surface.PlaySound("player/weapon_draw_0" .. math.random(2, 5) .. ".wav")
        end

        self.RandomizeAppearanceBtn = randomizeButton
    end

    if istable(TOOLMODULE.Menu) and TOOLMODULE.Menu.IsScaleToolsAvailable and TOOLMODULE.Menu.IsScaleToolsAvailable() then
        timer.Simple(0, function()
            if not IsValid(main) then return end
            hg.Appearance.Sliders.AttachScaleBlock(main)
            hg.Appearance.Sliders.RefreshScaleBlock(main)
        end)
    end

    self:CallbackAppearance()
end

function PANEL:Think()
    APmodule.CurrentEditTable = self.AppearanceTable
end

function PANEL:CallbackAppearance()
end

function PANEL:OnRemove()
    self:CloseImportMenus()
    if IsValid(self.AppearanceToolsMenu) then
        self.AppearanceToolsMenu:Close()
    end
end

vgui.Register("ZCAT_AppearanceMenu", PANEL, "ZFrame")
