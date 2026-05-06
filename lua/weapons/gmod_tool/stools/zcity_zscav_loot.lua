TOOL.Category = "ZCity"
TOOL.Tab = "Utilities"
TOOL.Name = "#tool.zcity_zscav_loot.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar = {
    mode = "place_container",
    label = "Loot Container",
    chance = "100",
    gw = "4",
    gh = "4",
    proxy_w = "56",
    proxy_d = "56",
    proxy_h = "72",
    loot_json = "[]",
    item_class = "artifact",
    item_name = "Artifact",
    item_w = "1",
    item_h = "1",
    item_weight = "0.5",
    item_category = "valuable",
}

TOOL.Information = {
    { name = "left" },
    { name = "right" },
}

if CLIENT then
    language.Add("tool.zcity_zscav_loot.name", "ZScav Loot Authoring Tool")
    language.Add("tool.zcity_zscav_loot.desc", "Save placed loot containers, register auto-container prop models, and create prop-backed valuable items for ZScav.")
    language.Add("tool.zcity_zscav_loot.left", "Apply the current mode to the prop you are aiming at")
    language.Add("tool.zcity_zscav_loot.right", "Remove the saved container/profile for the prop or selected row")
end

local function canEdit(ply)
    if not IsValid(ply) then return false end
    return ply:IsAdmin() or ply:IsSuperAdmin()
end

local function getWorldLootLib()
    return ZSCAV and ZSCAV.WorldLoot or nil
end

local function decodeLootRows(tool)
    return util.JSONToTable(tool:GetClientInfo("loot_json") or "[]") or {}
end

local function buildPayload(tool, trace)
    local mode = string.Trim(tostring(tool:GetClientInfo("mode") or "place_container"))
    local hitPos = trace.HitPos or vector_origin
    local payload = {
        ent_index = IsValid(trace.Entity) and trace.Entity:EntIndex() or -1,
        pos = {
            x = math.Round(hitPos.x, 3),
            y = math.Round(hitPos.y, 3),
            z = math.Round(hitPos.z, 3),
        },
    }

    local placedID = IsValid(trace.Entity) and string.Trim(tostring(trace.Entity.zscav_loot_placed_id or "")) or ""
    if placedID ~= "" then
        payload.id = placedID
    end

    if mode == "place_container" or mode == "model_container" or mode == "brush_proxy" then
        payload.label = tool:GetClientInfo("label")
        payload.spawn_chance = tonumber(tool:GetClientInfo("chance")) or 100
        payload.grid = {
            w = math.Clamp(math.floor(tonumber(tool:GetClientInfo("gw")) or 4), 1, 32),
            h = math.Clamp(math.floor(tonumber(tool:GetClientInfo("gh")) or 4), 1, 32),
        }
        payload.loot = decodeLootRows(tool)

        if mode == "brush_proxy" then
            local owner = tool:GetOwner()
            payload.proxy = true
            payload.proxy_size = {
                x = math.Clamp(math.Round(tonumber(tool:GetClientInfo("proxy_w")) or 56), 8, 256),
                y = math.Clamp(math.Round(tonumber(tool:GetClientInfo("proxy_d")) or 56), 8, 256),
                z = math.Clamp(math.Round(tonumber(tool:GetClientInfo("proxy_h")) or 72), 8, 256),
            }
            payload.ang = {
                p = 0,
                y = IsValid(owner) and owner:EyeAngles().y or 0,
                r = 0,
            }
            payload.model = tostring(IsValid(trace.Entity) and (trace.Entity.zscav_source_model or (trace.Entity.GetModel and trace.Entity:GetModel() or "")) or "")
        end
    else
        payload.item_class = tool:GetClientInfo("item_class")
        payload.name = tool:GetClientInfo("item_name")
        payload.w = math.Clamp(math.floor(tonumber(tool:GetClientInfo("item_w")) or 1), 1, 16)
        payload.h = math.Clamp(math.floor(tonumber(tool:GetClientInfo("item_h")) or 1), 1, 16)
        payload.weight = math.max(0, tonumber(tool:GetClientInfo("item_weight")) or 0)
        payload.category = tool:GetClientInfo("item_category")
    end

    return mode, payload
end

local function getActionForMode(mode, removing)
    local lib = getWorldLootLib()
    if not lib then return nil end

    if mode == "place_container" or mode == "brush_proxy" then
        return removing and lib.ACTION_REMOVE_CONTAINER or lib.ACTION_PLACE_CONTAINER
    end
    if mode == "model_container" then
        return removing and lib.ACTION_UNREGISTER_MODEL_CONTAINER or lib.ACTION_REGISTER_MODEL_CONTAINER
    end
    if mode == "valuable" then
        return removing and lib.ACTION_UNREGISTER_VALUABLE or lib.ACTION_REGISTER_VALUABLE
    end

    return nil
end

local function netSend(action, payload)
    local lib = getWorldLootLib()
    if not lib then return false end

    net.Start(lib.Net.Action)
        net.WriteUInt(action, 4)
        net.WriteString(util.TableToJSON(payload or {}, false) or "{}")
    net.SendToServer()
    return true
end

function TOOL:LeftClick(trace)
    if SERVER then return false end

    local owner = self:GetOwner()
    if not canEdit(owner) then return false end
    local mode = string.Trim(tostring(self:GetClientInfo("mode") or "place_container"))
    local requiresEntity = mode ~= "brush_proxy"
    if not trace.Hit or (requiresEntity and not IsValid(trace.Entity)) then
        chat.AddText(Color(255, 200, 60), "[ZScav] Aim at a prop or existing loot entity first.")
        return false
    end

    local _, payload = buildPayload(self, trace)
    local action = getActionForMode(mode, false)
    if not action then return false end

    netSend(action, payload)
    return true
end

function TOOL:RightClick(trace)
    if SERVER then return false end

    local owner = self:GetOwner()
    if not canEdit(owner) then return false end
    local mode = string.Trim(tostring(self:GetClientInfo("mode") or "place_container"))
    local requiresEntity = mode ~= "brush_proxy"
    if not trace.Hit or (requiresEntity and not IsValid(trace.Entity)) then
        chat.AddText(Color(255, 200, 60), "[ZScav] Aim at a prop or use the saved lists in the tool panel.")
        return false
    end

    local _, payload = buildPayload(self, trace)
    local action = getActionForMode(mode, true)
    if not action then return false end

    netSend(action, payload)
    return true
end

if CLIENT then
    local function getState()
        local lib = getWorldLootLib()
        return lib and lib.GetState and lib.GetState() or {
            placed_spawns = {},
            model_containers = {},
            valuables = {},
        }
    end

    local function setConVar(name, value)
        RunConsoleCommand("zcity_zscav_loot_" .. name, tostring(value or ""))
    end

    local function getModeConVar()
        return GetConVarString("zcity_zscav_loot_mode") or "place_container"
    end

    local function loadContainerFields(def, lootRows)
        if not istable(def) then return end

        setConVar("label", tostring(def.label or def.name or "Loot Container"))
        setConVar("chance", tostring(math.Round(tonumber(def.spawn_chance) or tonumber(def.chance) or 100, 2)))
        setConVar("gw", tostring(math.floor(tonumber(def.grid and def.grid.w or def.gw) or 4)))
        setConVar("gh", tostring(math.floor(tonumber(def.grid and def.grid.h or def.gh) or 4)))
        if istable(def.proxy_size) then
            setConVar("proxy_w", tostring(math.Round(tonumber(def.proxy_size.x) or 56)))
            setConVar("proxy_d", tostring(math.Round(tonumber(def.proxy_size.y) or 56)))
            setConVar("proxy_h", tostring(math.Round(tonumber(def.proxy_size.z) or 72)))
        end
        setConVar("loot_json", util.TableToJSON(lootRows or def.loot or {}, false) or "[]")
    end

    local function loadValuableFields(def)
        if not istable(def) then return end

        setConVar("item_class", tostring(def.item_class or def.class or "artifact"))
        setConVar("item_name", tostring(def.name or "Artifact"))
        setConVar("item_w", tostring(math.floor(tonumber(def.w) or 1)))
        setConVar("item_h", tostring(math.floor(tonumber(def.h) or 1)))
        setConVar("item_weight", tostring(tonumber(def.weight) or 0.5))
        setConVar("item_category", tostring(def.category or "valuable"))
    end

    local function collectCatalogEntries()
        local worldLoot = getWorldLootLib()
        local entries = {}
        for _, group in ipairs(worldLoot and worldLoot.GetLootGroupCatalog and worldLoot.GetLootGroupCatalog() or {}) do
            entries[#entries + 1] = {
                class = tostring(group.token or ""),
                name = tostring(group.label or group.token or "Loot Group"),
                kind = "group",
                size = string.format("%d classes", tonumber(group.count) or 0),
                detail = tostring(group.description or ""),
                sortRank = 0,
            }
        end

        for _, class in ipairs(worldLoot and worldLoot.GetLootCatalogClasses and worldLoot.GetLootCatalogClasses() or {}) do
            local meta = ZSCAV and ZSCAV.GetItemMeta and ZSCAV:GetItemMeta(class) or nil
            local gear = ZSCAV and ZSCAV.GetGearDef and ZSCAV:GetGearDef(class) or nil
            local size = ZSCAV and ZSCAV.GetItemSize and ZSCAV:GetItemSize(class) or { w = 1, h = 1 }
            local groupDef = worldLoot and worldLoot.GetLootGroupDef and worldLoot.GetLootGroupDef(class) or nil
            local kind = worldLoot and worldLoot.ClassifyLootCatalogClass and worldLoot.ClassifyLootCatalogClass(class) or "item"

            entries[#entries + 1] = {
                class = string.lower(string.Trim(tostring(class or ""))),
                name = tostring((groupDef and groupDef.label) or (meta and meta.name) or (gear and gear.name) or string.NiceName(class) or class),
                kind = tostring(kind or "item"),
                size = string.format("%dx%d", tonumber(size and size.w) or 1, tonumber(size and size.h) or 1),
                detail = tostring(kind or "item"),
                sortRank = 1,
            }
        end

        table.sort(entries, function(a, b)
            local aRank = tonumber(a.sortRank) or 99
            local bRank = tonumber(b.sortRank) or 99
            if aRank ~= bRank then
                return aRank < bRank
            end
            if a.name == b.name then
                return a.class < b.class
            end
            return a.name < b.name
        end)

        return entries
    end

    local function drawPlacedSpawnMarker(def)
        if not istable(def) or not istable(def.pos) then return end

        local pos = Vector(tonumber(def.pos.x) or 0, tonumber(def.pos.y) or 0, tonumber(def.pos.z) or 0)
        local ang = Angle(tonumber(def.ang and def.ang.p) or 0, tonumber(def.ang and def.ang.y) or 0, tonumber(def.ang and def.ang.r) or 0)
        local label = string.Trim(tostring(def.label or def.id or "Loot"))
        local chance = tonumber(def.spawn_chance) or 100

        if def.proxy and istable(def.proxy_size) then
            local halfX = math.max(tonumber(def.proxy_size.x) or 56, 8) * 0.5
            local halfY = math.max(tonumber(def.proxy_size.y) or 56, 8) * 0.5
            local halfZ = math.max(tonumber(def.proxy_size.z) or 72, 8) * 0.5
            render.DrawWireframeBox(pos, ang, Vector(-halfX, -halfY, -halfZ), Vector(halfX, halfY, halfZ), Color(92, 220, 162), true)
        end

        cam.Start3D2D(pos + Vector(0, 0, 2), Angle(0, 0, 0), 1)
            surface.SetDrawColor(92, 220, 162, 110)
            for segment = 0, 35 do
                local a1 = (segment / 36) * math.pi * 2
                local a2 = ((segment + 1) / 36) * math.pi * 2
                surface.DrawLine(
                    math.cos(a1) * 34, math.sin(a1) * 34,
                    math.cos(a2) * 34, math.sin(a2) * 34
                )
            end
        cam.End3D2D()

        local yawToCam = (EyePos() - pos):Angle().y
        cam.Start3D2D(pos + Vector(0, 0, 34), Angle(0, yawToCam - 90, 90), 0.18)
            draw.SimpleText(label, "DermaDefaultBold", 0, -8, Color(92, 220, 162), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(string.format("%dx%d  |  %.0f%%", tonumber(def.grid and def.grid.w) or 0, tonumber(def.grid and def.grid.h) or 0, chance), "DermaDefault", 0, 12, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end

    local function getProxyPreviewBounds(ply)
        if not IsValid(ply) then return nil end

        local trace = ply:GetEyeTrace()
        if not (trace and trace.Hit) then return nil end

        local width = math.max(tonumber(GetConVarString("zcity_zscav_loot_proxy_w")) or 56, 8)
        local depth = math.max(tonumber(GetConVarString("zcity_zscav_loot_proxy_d")) or 56, 8)
        local height = math.max(tonumber(GetConVarString("zcity_zscav_loot_proxy_h")) or 72, 8)
        return trace.HitPos, Angle(0, ply:EyeAngles().y, 0), Vector(-width * 0.5, -depth * 0.5, -height * 0.5), Vector(width * 0.5, depth * 0.5, height * 0.5)
    end

    hook.Add("PostDrawTranslucentRenderables", "ZScavLootTool_PlaceMarkers", function(_drawingDepth, skybox, skybox3D)
        if skybox or skybox3D then return end

        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        local wep = lp:GetActiveWeapon()
        if not (IsValid(wep) and wep:GetClass() == "gmod_tool") then return end
        if lp:GetInfo("gmod_toolmode") ~= "zcity_zscav_loot" then return end

        for _, def in ipairs(getState().placed_spawns or {}) do
            drawPlacedSpawnMarker(def)
        end

        if getModeConVar() == "brush_proxy" then
            local pos, ang, mins, maxs = getProxyPreviewBounds(lp)
            if pos and mins and maxs then
                render.DrawWireframeBox(pos, ang, mins, maxs, Color(255, 210, 96), true)
            end
        end
    end)

    function TOOL.BuildCPanel(panel)
        panel:Help("Mode 1 saves persistent map containers with optional spawn chance. Mode 2 registers a prop model so future spawnmenu props of that model become loot containers automatically. Mode 3 turns a prop model into a catalog-backed valuable pickup item. Loot-table pickers now also include reusable group rows like weapons, ammo, gear, and general loot.")

        local hookID = "ZScavLootToolPanel_" .. tostring(panel)
        local catalogEntries = collectCatalogEntries()
        local lootRows = util.JSONToTable(GetConVarString("zcity_zscav_loot_loot_json") or "[]") or {}
        local selectedCatalogClass = nil
        local selectedLootLine = nil
        local selectedPlacedID = nil
        local selectedModel = nil
        local selectedValuableClass = nil

        local function setLootRows(rows)
            lootRows = istable(rows) and rows or {}
            setConVar("loot_json", util.TableToJSON(lootRows, false) or "[]")
        end

        local modeLabel = vgui.Create("DLabel")
        modeLabel:SetWrap(true)
        modeLabel:SetAutoStretchVertical(true)
        modeLabel:SetFont("DermaDefault")
        modeLabel:SetTextColor(color_white)
        panel:AddItem(modeLabel)

        local modeCombo = vgui.Create("DComboBox")
        modeCombo:SetSortItems(false)
        modeCombo:AddChoice("Place Persistent Container", "place_container")
        modeCombo:AddChoice("Place Brush Contact Box", "brush_proxy")
        modeCombo:AddChoice("Register Auto-Container Model", "model_container")
        modeCombo:AddChoice("Register Valuable Model", "valuable")
        modeCombo:SetValue("Place Persistent Container")
        panel:AddItem(modeCombo)

        local containerForm = vgui.Create("DForm")
        containerForm:SetLabel("Container Settings")
        panel:AddItem(containerForm)

        local labelEntry = vgui.Create("DTextEntry")
        labelEntry:SetValue(GetConVarString("zcity_zscav_loot_label") or "Loot Container")
        labelEntry:SetUpdateOnType(true)
        labelEntry.OnValueChange = function(self, value)
            setConVar("label", value)
        end
        containerForm:AddItem(labelEntry)

        local chanceSlider = vgui.Create("DNumSlider")
        chanceSlider:SetText("Spawn Chance")
        chanceSlider:SetMin(0)
        chanceSlider:SetMax(100)
        chanceSlider:SetDecimals(0)
        chanceSlider:SetValue(tonumber(GetConVarString("zcity_zscav_loot_chance")) or 100)
        chanceSlider.OnValueChanged = function(self, value)
            setConVar("chance", math.Round(value))
        end
        containerForm:AddItem(chanceSlider)

        local gridWSlider = vgui.Create("DNumSlider")
        gridWSlider:SetText("Grid Width")
        gridWSlider:SetMin(1)
        gridWSlider:SetMax(16)
        gridWSlider:SetDecimals(0)
        gridWSlider:SetValue(tonumber(GetConVarString("zcity_zscav_loot_gw")) or 4)
        gridWSlider.OnValueChanged = function(self, value)
            setConVar("gw", math.Round(value))
        end
        containerForm:AddItem(gridWSlider)

        local gridHSlider = vgui.Create("DNumSlider")
        gridHSlider:SetText("Grid Height")
        gridHSlider:SetMin(1)
        gridHSlider:SetMax(16)
        gridHSlider:SetDecimals(0)
        gridHSlider:SetValue(tonumber(GetConVarString("zcity_zscav_loot_gh")) or 4)
        gridHSlider.OnValueChanged = function(self, value)
            setConVar("gh", math.Round(value))
        end
        containerForm:AddItem(gridHSlider)

        local proxyWidthSlider = vgui.Create("DNumSlider")
        proxyWidthSlider:SetText("Contact Box Width")
        proxyWidthSlider:SetMin(8)
        proxyWidthSlider:SetMax(256)
        proxyWidthSlider:SetDecimals(0)
        proxyWidthSlider:SetValue(tonumber(GetConVarString("zcity_zscav_loot_proxy_w")) or 56)
        proxyWidthSlider.OnValueChanged = function(self, value)
            setConVar("proxy_w", math.Round(value))
        end
        containerForm:AddItem(proxyWidthSlider)

        local proxyDepthSlider = vgui.Create("DNumSlider")
        proxyDepthSlider:SetText("Contact Box Depth")
        proxyDepthSlider:SetMin(8)
        proxyDepthSlider:SetMax(256)
        proxyDepthSlider:SetDecimals(0)
        proxyDepthSlider:SetValue(tonumber(GetConVarString("zcity_zscav_loot_proxy_d")) or 56)
        proxyDepthSlider.OnValueChanged = function(self, value)
            setConVar("proxy_d", math.Round(value))
        end
        containerForm:AddItem(proxyDepthSlider)

        local proxyHeightSlider = vgui.Create("DNumSlider")
        proxyHeightSlider:SetText("Contact Box Height")
        proxyHeightSlider:SetMin(8)
        proxyHeightSlider:SetMax(256)
        proxyHeightSlider:SetDecimals(0)
        proxyHeightSlider:SetValue(tonumber(GetConVarString("zcity_zscav_loot_proxy_h")) or 72)
        proxyHeightSlider.OnValueChanged = function(self, value)
            setConVar("proxy_h", math.Round(value))
        end
        containerForm:AddItem(proxyHeightSlider)

        local searchEntry = vgui.Create("DTextEntry")
        searchEntry:SetUpdateOnType(true)
        if searchEntry.SetPlaceholderText then
            searchEntry:SetPlaceholderText("Search ZScav catalog classes or groups")
        end
        containerForm:AddItem(searchEntry)

        local catalogList = vgui.Create("DListView")
        catalogList:SetTall(180)
        catalogList:SetMultiSelect(false)
        catalogList:AddColumn("Name")
        catalogList:AddColumn("Class")
        catalogList:AddColumn("Type")
        catalogList:AddColumn("Size")
        containerForm:AddItem(catalogList)

        local rowChance = vgui.Create("DNumSlider")
        rowChance:SetText("Selected Loot Entry Chance")
        rowChance:SetMin(0)
        rowChance:SetMax(100)
        rowChance:SetDecimals(0)
        rowChance:SetValue(100)
        containerForm:AddItem(rowChance)

        local rowMin = vgui.Create("DNumSlider")
        rowMin:SetText("Selected Loot Entry Min Count")
        rowMin:SetMin(1)
        rowMin:SetMax(8)
        rowMin:SetDecimals(0)
        rowMin:SetValue(1)
        containerForm:AddItem(rowMin)

        local rowMax = vgui.Create("DNumSlider")
        rowMax:SetText("Selected Loot Entry Max Count")
        rowMax:SetMin(1)
        rowMax:SetMax(8)
        rowMax:SetDecimals(0)
        rowMax:SetValue(1)
        containerForm:AddItem(rowMax)

        local addLootButton = vgui.Create("DButton")
        addLootButton:SetText("Add Selected Catalog Entry To Loot Table")
        addLootButton:SetTall(24)
        containerForm:AddItem(addLootButton)

        local lootList = vgui.Create("DListView")
        lootList:SetTall(170)
        lootList:SetMultiSelect(false)
        lootList:AddColumn("Name")
        lootList:AddColumn("Class")
        lootList:AddColumn("Chance")
        lootList:AddColumn("Min")
        lootList:AddColumn("Max")
        containerForm:AddItem(lootList)

        local removeLootButton = vgui.Create("DButton")
        removeLootButton:SetText("Remove Selected Loot Row")
        removeLootButton:SetTall(24)
        containerForm:AddItem(removeLootButton)

        local valuableForm = vgui.Create("DForm")
        valuableForm:SetLabel("Valuable Settings")
        panel:AddItem(valuableForm)

        local itemClassEntry = vgui.Create("DTextEntry")
        itemClassEntry:SetValue(GetConVarString("zcity_zscav_loot_item_class") or "artifact")
        itemClassEntry:SetUpdateOnType(true)
        itemClassEntry.OnValueChange = function(self, value)
            setConVar("item_class", value)
        end
        valuableForm:AddItem(itemClassEntry)

        local itemNameEntry = vgui.Create("DTextEntry")
        itemNameEntry:SetValue(GetConVarString("zcity_zscav_loot_item_name") or "Artifact")
        itemNameEntry:SetUpdateOnType(true)
        itemNameEntry.OnValueChange = function(self, value)
            setConVar("item_name", value)
        end
        valuableForm:AddItem(itemNameEntry)

        local itemWSlider = vgui.Create("DNumSlider")
        itemWSlider:SetText("Item Width")
        itemWSlider:SetMin(1)
        itemWSlider:SetMax(8)
        itemWSlider:SetDecimals(0)
        itemWSlider:SetValue(tonumber(GetConVarString("zcity_zscav_loot_item_w")) or 1)
        itemWSlider.OnValueChanged = function(self, value)
            setConVar("item_w", math.Round(value))
        end
        valuableForm:AddItem(itemWSlider)

        local itemHSlider = vgui.Create("DNumSlider")
        itemHSlider:SetText("Item Height")
        itemHSlider:SetMin(1)
        itemHSlider:SetMax(8)
        itemHSlider:SetDecimals(0)
        itemHSlider:SetValue(tonumber(GetConVarString("zcity_zscav_loot_item_h")) or 1)
        itemHSlider.OnValueChanged = function(self, value)
            setConVar("item_h", math.Round(value))
        end
        valuableForm:AddItem(itemHSlider)

        local itemWeightSlider = vgui.Create("DNumSlider")
        itemWeightSlider:SetText("Item Weight")
        itemWeightSlider:SetMin(0)
        itemWeightSlider:SetMax(20)
        itemWeightSlider:SetDecimals(2)
        itemWeightSlider:SetValue(tonumber(GetConVarString("zcity_zscav_loot_item_weight")) or 0.5)
        itemWeightSlider.OnValueChanged = function(self, value)
            setConVar("item_weight", string.format("%.2f", tonumber(value) or 0))
        end
        valuableForm:AddItem(itemWeightSlider)

        local itemCategoryEntry = vgui.Create("DTextEntry")
        itemCategoryEntry:SetValue(GetConVarString("zcity_zscav_loot_item_category") or "valuable")
        itemCategoryEntry:SetUpdateOnType(true)
        itemCategoryEntry.OnValueChange = function(self, value)
            setConVar("item_category", value)
        end
        valuableForm:AddItem(itemCategoryEntry)

        local savedForm = vgui.Create("DForm")
        savedForm:SetLabel("Saved World Loot State")
        panel:AddItem(savedForm)

        local placedList = vgui.Create("DListView")
        placedList:SetTall(130)
        placedList:SetMultiSelect(false)
        placedList:AddColumn("Placed Containers")
        placedList:AddColumn("Grid")
        placedList:AddColumn("Chance")
        placedList:AddColumn("Model")
        savedForm:AddItem(placedList)

        local deletePlacedButton = vgui.Create("DButton")
        deletePlacedButton:SetText("Delete Selected Placed Container")
        deletePlacedButton:SetTall(24)
        savedForm:AddItem(deletePlacedButton)

        local modelList = vgui.Create("DListView")
        modelList:SetTall(130)
        modelList:SetMultiSelect(false)
        modelList:AddColumn("Auto-Container Models")
        modelList:AddColumn("Grid")
        modelList:AddColumn("Model")
        savedForm:AddItem(modelList)

        local deleteModelButton = vgui.Create("DButton")
        deleteModelButton:SetText("Delete Selected Auto-Container Model")
        deleteModelButton:SetTall(24)
        savedForm:AddItem(deleteModelButton)

        local valuableList = vgui.Create("DListView")
        valuableList:SetTall(130)
        valuableList:SetMultiSelect(false)
        valuableList:AddColumn("Valuable Class")
        valuableList:AddColumn("Name")
        valuableList:AddColumn("Size")
        valuableList:AddColumn("Model")
        savedForm:AddItem(valuableList)

        local deleteValuableButton = vgui.Create("DButton")
        deleteValuableButton:SetText("Delete Selected Valuable Profile")
        deleteValuableButton:SetTall(24)
        savedForm:AddItem(deleteValuableButton)

        local function refreshCatalogList()
            if not IsValid(catalogList) then return end

            local filter = string.lower(string.Trim(searchEntry:GetValue() or ""))
            catalogList:Clear()

            for _, entry in ipairs(catalogEntries) do
                local haystack = string.lower(entry.name .. " " .. entry.class .. " " .. entry.kind .. " " .. tostring(entry.detail or ""))
                if filter == "" or haystack:find(filter, 1, true) then
                    local line = catalogList:AddLine(entry.name, entry.class, entry.kind, entry.size)
                    line._class = entry.class
                    if entry.class == selectedCatalogClass then
                        catalogList:SelectItem(line)
                    end
                end
            end
        end

        local function refreshLootList()
            if not IsValid(lootList) then return end

            lootList:Clear()
            for index, row in ipairs(lootRows or {}) do
                local meta = ZSCAV and ZSCAV.GetItemMeta and ZSCAV:GetItemMeta(row.class) or nil
                local gear = ZSCAV and ZSCAV.GetGearDef and ZSCAV:GetGearDef(row.class) or nil
                local groupDef = worldLoot and worldLoot.GetLootGroupDef and worldLoot.GetLootGroupDef(row.class) or nil
                local name = tostring((groupDef and groupDef.label) or (meta and meta.name) or (gear and gear.name) or string.NiceName(row.class) or row.class)
                local line = lootList:AddLine(name, row.class, tostring(row.chance or 100), tostring(row.min or 1), tostring(row.max or 1))
                line._lootIndex = index
                if selectedLootLine == index then
                    lootList:SelectItem(line)
                end
            end
        end

        local function refreshSavedLists()
            local state = getState()

            if IsValid(placedList) then
                placedList:Clear()
                for _, def in ipairs(state.placed_spawns or {}) do
                    local line = placedList:AddLine(
                        tostring(def.label or def.id or "Loot Container"),
                        string.format("%dx%d", tonumber(def.grid and def.grid.w) or 0, tonumber(def.grid and def.grid.h) or 0),
                        string.format("%.0f%%", tonumber(def.spawn_chance) or 100),
                        tostring(def.model or "")
                    )
                    line._placedID = tostring(def.id or "")
                    line._def = def
                end
            end

            if IsValid(modelList) then
                modelList:Clear()
                for model, def in pairs(state.model_containers or {}) do
                    local line = modelList:AddLine(
                        tostring(def.label or def.name or "Loot Container"),
                        string.format("%dx%d", tonumber(def.grid and def.grid.w) or 0, tonumber(def.grid and def.grid.h) or 0),
                        tostring(model or def.model or "")
                    )
                    line._model = tostring(model or def.model or "")
                    line._def = def
                end
            end

            if IsValid(valuableList) then
                valuableList:Clear()
                for class, def in pairs(state.valuables or {}) do
                    local line = valuableList:AddLine(
                        tostring(class),
                        tostring(def.name or string.NiceName(class) or class),
                        string.format("%dx%d", tonumber(def.w) or 1, tonumber(def.h) or 1),
                        tostring(def.model or "")
                    )
                    line._itemClass = tostring(class)
                    line._def = def
                end
            end
        end

        local function updateModeUI(mode)
            mode = tostring(mode or "place_container")
            local containerMode = mode ~= "valuable"
            local proxyMode = mode == "brush_proxy"

            containerForm:SetVisible(containerMode)
            valuableForm:SetVisible(not containerMode)
            proxyWidthSlider:SetVisible(proxyMode)
            proxyDepthSlider:SetVisible(proxyMode)
            proxyHeightSlider:SetVisible(proxyMode)

            if mode == "place_container" then
                modeLabel:SetText("Left click a spawned prop to save it as a persistent map loot container. Right click that prop or a saved row to remove it. Spawn chance rerolls when the map or raid cycle refreshes.")
            elseif mode == "brush_proxy" then
                modeLabel:SetText("Left click an existing map prop or brush target to place an invisible contact box that opens a ZScav container. The box uses the size sliders below and is previewed live in the world while this mode is active.")
            elseif mode == "model_container" then
                modeLabel:SetText("Left click a prop model to register it as an auto-container profile. Future spawnmenu props using that model will convert into loot containers immediately.")
            else
                modeLabel:SetText("Left click a prop model to register it as a ZScav valuable item. The model becomes a pickup item with the class, size, and weight defined below.")
            end

            modeLabel:SizeToContentsY()
        end

        modeCombo.OnSelect = function(_, _, label, data)
            setConVar("mode", data)
            updateModeUI(data)
            modeCombo:SetValue(label)
        end

        searchEntry.OnValueChange = function()
            refreshCatalogList()
        end

        catalogList.OnRowSelected = function(_, _, line)
            selectedCatalogClass = line and line._class or nil
        end
        catalogList.DoDoubleClick = function(_, _, line)
            selectedCatalogClass = line and line._class or nil
            addLootButton:DoClick()
        end

        addLootButton.DoClick = function()
            if not selectedCatalogClass then return end

            local minCount = math.max(1, math.Round(tonumber(rowMin:GetValue()) or 1))
            local maxCount = math.max(minCount, math.Round(tonumber(rowMax:GetValue()) or minCount))
            lootRows[#lootRows + 1] = {
                class = selectedCatalogClass,
                chance = math.Clamp(math.Round(tonumber(rowChance:GetValue()) or 100), 0, 100),
                min = minCount,
                max = maxCount,
            }
            setLootRows(lootRows)
            refreshLootList()
        end

        lootList.OnRowSelected = function(_, _, line)
            selectedLootLine = line and line._lootIndex or nil
        end

        removeLootButton.DoClick = function()
            if not selectedLootLine then return end
            table.remove(lootRows, selectedLootLine)
            selectedLootLine = nil
            setLootRows(lootRows)
            refreshLootList()
        end

        placedList.OnRowSelected = function(_, _, line)
            selectedPlacedID = line and line._placedID or nil
            local def = line and line._def or nil
            if def then
                local nextMode = def.proxy and "brush_proxy" or "place_container"
                setConVar("mode", nextMode)
                updateModeUI(nextMode)
                modeCombo:SetValue(def.proxy and "Place Brush Contact Box" or "Place Persistent Container")
                loadContainerFields(def, def.loot or {})
                lootRows = util.JSONToTable(GetConVarString("zcity_zscav_loot_loot_json") or "[]") or {}
                refreshLootList()
            end
        end

        modelList.OnRowSelected = function(_, _, line)
            selectedModel = line and line._model or nil
            local def = line and line._def or nil
            if def then
                setConVar("mode", "model_container")
                updateModeUI("model_container")
                modeCombo:SetValue("Register Auto-Container Model")
                loadContainerFields(def, def.loot or {})
                lootRows = util.JSONToTable(GetConVarString("zcity_zscav_loot_loot_json") or "[]") or {}
                refreshLootList()
            end
        end

        valuableList.OnRowSelected = function(_, _, line)
            selectedValuableClass = line and line._itemClass or nil
            local def = line and line._def or nil
            if def then
                setConVar("mode", "valuable")
                updateModeUI("valuable")
                modeCombo:SetValue("Register Valuable Model")
                loadValuableFields(def)
            end
        end

        deletePlacedButton.DoClick = function()
            if not selectedPlacedID then return end
            local lib = getWorldLootLib()
            if not lib then return end
            netSend(lib.ACTION_REMOVE_CONTAINER, { id = selectedPlacedID })
        end

        deleteModelButton.DoClick = function()
            if not selectedModel then return end
            local lib = getWorldLootLib()
            if not lib then return end
            netSend(lib.ACTION_UNREGISTER_MODEL_CONTAINER, { model = selectedModel })
        end

        deleteValuableButton.DoClick = function()
            if not selectedValuableClass then return end
            local lib = getWorldLootLib()
            if not lib then return end
            netSend(lib.ACTION_UNREGISTER_VALUABLE, { item_class = selectedValuableClass })
        end

        local currentMode = getModeConVar()
        if currentMode == "brush_proxy" then
            modeCombo:SetValue("Place Brush Contact Box")
        elseif currentMode == "model_container" then
            modeCombo:SetValue("Register Auto-Container Model")
        elseif currentMode == "valuable" then
            modeCombo:SetValue("Register Valuable Model")
        else
            currentMode = "place_container"
            modeCombo:SetValue("Place Persistent Container")
        end

        updateModeUI(currentMode)
        refreshCatalogList()
        refreshLootList()
        refreshSavedLists()

        hook.Add("ZScavWorldLoot_ClientUpdated", hookID, function()
            catalogEntries = collectCatalogEntries()
            refreshCatalogList()
            refreshSavedLists()
        end)

        local oldOnRemove = panel.OnRemove
        panel.OnRemove = function(self)
            hook.Remove("ZScavWorldLoot_ClientUpdated", hookID)
            if isfunction(oldOnRemove) then
                oldOnRemove(self)
            end
        end
    end
end