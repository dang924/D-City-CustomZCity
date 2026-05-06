if SERVER then return end

local OPEN_NET = "ZScavWorldLootOpen"
local MENU_FRAME
local MENU_HOOK_ID = "ZScavWorldLootMenu_Refresh"
local ACTIVE_PAGE = "model"
local SPAWNMENU_PROP_MODEL_CACHE

local FALLBACK_COLORS = {
    Background = Color(20, 26, 29),
    Secondary = Color(33, 42, 47),
    Header = Color(26, 33, 37),
    Text = Color(234, 238, 242),
    Primary = Color(92, 167, 128),
    Green = Color(92, 167, 128),
    Red = Color(176, 84, 84),
    Orange = Color(198, 148, 74),
}

local function getWorldLootLib()
    return ZSCAV and ZSCAV.WorldLoot or nil
end

local function getWorldLootState()
    local lib = getWorldLootLib()
    return lib and lib.GetState and lib.GetState() or {
        placed_spawns = {},
        model_containers = {},
        valuables = {},
    }
end

local function chooseClass(primary, fallback)
    return vgui.GetControlTable(primary) and primary or fallback
end

local function nexusReady()
    return Nexus and Nexus.Colors and Nexus.Colors.Background
end

local function colorFor(key)
    if nexusReady() and Nexus.Colors[key] then
        return Nexus.Colors[key]
    end

    return FALLBACK_COLORS[key] or color_white
end

local function scale(value)
    return nexusReady() and Nexus:Scale(value) or value
end

local function font(size, bold)
    return nexusReady() and Nexus:GetFont(size, nil, bold) or (bold and "DermaDefaultBold" or "DermaDefault")
end

local function isAdminLike(ply)
    return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

local function setStatus(text)
    if IsValid(MENU_FRAME) and IsValid(MENU_FRAME.StatusLabel) then
        MENU_FRAME.StatusLabel:SetText(tostring(text or ""))
    end
end

local function normalizeModel(model)
    local lib = getWorldLootLib()
    if lib and lib.NormalizeModel then
        return lib.NormalizeModel(model)
    end

    model = string.lower(string.Trim(tostring(model or "")))
    return string.gsub(model, "\\", "/")
end

local function cloneLootRows(rows)
    local out = {}
    for _, row in ipairs(istable(rows) and rows or {}) do
        if istable(row) then
            out[#out + 1] = {
                class = tostring(row.class or row.item_class or ""),
                chance = math.Clamp(math.Round(tonumber(row.chance) or 100), 0, 100),
                min = math.Clamp(math.floor(tonumber(row.min) or tonumber(row.count) or 1), 1, 32),
                max = math.Clamp(math.floor(tonumber(row.max) or tonumber(row.count) or 1), 1, 32),
            }
        end
    end
    return out
end

local function prettyClassName(class)
    class = tostring(class or "")
    if class == "" then return "" end

    local worldLoot = getWorldLootLib()
    local groupDef = worldLoot and worldLoot.GetLootGroupDef and worldLoot.GetLootGroupDef(class) or nil
    if istable(groupDef) and tostring(groupDef.label or "") ~= "" then
        return tostring(groupDef.label)
    end

    local gear = ZSCAV and ZSCAV.GetGearDef and ZSCAV:GetGearDef(class) or nil
    if istable(gear) and tostring(gear.name or "") ~= "" then
        return tostring(gear.name)
    end

    local meta = ZSCAV and ZSCAV.GetItemMeta and ZSCAV:GetItemMeta(class) or nil
    if istable(meta) and tostring(meta.name or "") ~= "" then
        return tostring(meta.name)
    end

    local swep = weapons.GetStored and weapons.GetStored(class) or nil
    if istable(swep) and tostring(swep.PrintName or "") ~= "" and swep.PrintName ~= class then
        return tostring(swep.PrintName)
    end

    local sent = scripted_ents.GetStored and scripted_ents.GetStored(class) or nil
    local sentTable = istable(sent) and (sent.t or sent) or nil
    if istable(sentTable) and tostring(sentTable.PrintName or "") ~= "" then
        return tostring(sentTable.PrintName)
    end

    return string.NiceName(class)
end

local function getCatalogClasses()
    local worldLoot = getWorldLootLib()
    if worldLoot and worldLoot.GetLootCatalogClasses then
        return worldLoot.GetLootCatalogClasses()
    end

    return {}
end

local function collectCatalogEntries()
    local entries = {}
    local worldLoot = getWorldLootLib()

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

    for _, class in ipairs(getCatalogClasses()) do
        local gear = ZSCAV and ZSCAV.GetGearDef and ZSCAV:GetGearDef(class) or nil
        local size = ZSCAV and ZSCAV.GetItemSize and ZSCAV:GetItemSize(class) or { w = 1, h = 1 }
        local kind = worldLoot and worldLoot.ClassifyLootCatalogClass and worldLoot.ClassifyLootCatalogClass(class) or nil
        kind = tostring(kind or "item")

        entries[#entries + 1] = {
            class = tostring(class),
            name = prettyClassName(class),
            kind = kind,
            size = string.format("%dx%d", tonumber(size and size.w) or 1, tonumber(size and size.h) or 1),
            detail = kind,
            sortRank = 1,
        }
    end

    table.sort(entries, function(left, right)
        local leftRank = tonumber(left.sortRank) or 99
        local rightRank = tonumber(right.sortRank) or 99
        if leftRank ~= rightRank then
            return leftRank < rightRank
        end

        local leftName = string.lower(tostring(left.name or left.class or ""))
        local rightName = string.lower(tostring(right.name or right.class or ""))
        if leftName == rightName then
            return tostring(left.class or "") < tostring(right.class or "")
        end
        return leftName < rightName
    end)

    return entries
end

local function sendWorldLootAction(action, payload)
    local lib = getWorldLootLib()
    if not lib then
        setStatus("World loot library is not ready yet.")
        return false
    end

    net.Start(lib.Net.Action)
        net.WriteUInt(action, 4)
        net.WriteString(util.TableToJSON(payload or {}, false) or "{}")
    net.SendToServer()
    return true
end

local function getAimedEntityAndModel()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil, "" end

    local trace = ply:GetEyeTrace()
    local ent = trace and trace.Entity or nil
    if not IsValid(ent) then return nil, "" end

    return ent, normalizeModel(ent.GetModel and ent:GetModel() or "")
end

local function createButton(parent, text, colorKey)
    local button = vgui.Create(chooseClass("Nexus:Button", "DButton"), parent)
    button:SetText(text)
    button:SetTall(scale(32))
    if button.SetFont then
        button:SetFont(font(13, true))
    end
    if button.SetColor then
        button:SetColor(colorFor(colorKey or "Primary"))
    end
    return button
end

local function createCard(parent, title, tall)
    local card = vgui.Create("DPanel", parent)
    card:Dock(TOP)
    card:SetTall(tall)
    card:DockMargin(0, 0, 0, scale(10))
    card.Paint = function(_, w, h)
        draw.RoundedBox(scale(8), 0, 0, w, h, colorFor("Secondary"))
        draw.RoundedBoxEx(scale(8), 0, 0, w, scale(34), colorFor("Header"), true, true, false, false)
    end

    local label = vgui.Create("DLabel", card)
    label:Dock(TOP)
    label:SetTall(scale(34))
    label:DockMargin(scale(12), 0, scale(12), 0)
    label:SetFont(font(15, true))
    label:SetTextColor(colorFor("Text"))
    label:SetText(title)

    return card
end

local function setPreviewModel(preview, model)
    if not IsValid(preview) then return end

    model = normalizeModel(model)
    if model == "" or not util.IsValidModel(model) then
        preview:SetModel("models/error.mdl")
        if IsValid(preview.Placeholder) then
            preview.Placeholder:SetText(model == "" and "No prop model selected yet." or "Preview unavailable for this model path.")
            preview.Placeholder:SetVisible(true)
        end
        return
    end

    preview:SetModel(model)
    local entity = preview.Entity
    if not IsValid(entity) then return end

    entity:SetAngles(Angle(0, 30, 0))
    local mins, maxs = entity:GetRenderBounds()
    local center = (mins + maxs) * 0.5
    local radius = math.max((maxs - mins):Length(), 24)
    preview:SetLookAt(center)
    preview:SetCamPos(center + Vector(radius * 1.2, radius * 1.2, radius * 0.38))

    if IsValid(preview.Placeholder) then
        preview.Placeholder:SetVisible(false)
    end
end

local function createModelPreviewCard(parent, title, tall)
    local card = createCard(parent, title, tall)

    local preview = vgui.Create("DModelPanel", card)
    preview:Dock(FILL)
    preview:DockMargin(scale(12), scale(8), scale(12), scale(12))
    preview:SetFOV(28)
    preview:SetAmbientLight(Color(120, 120, 120))
    preview:SetDirectionalLight(BOX_TOP, Color(255, 244, 228))
    preview:SetDirectionalLight(BOX_FRONT, Color(184, 204, 255))
    preview:SetModel("models/error.mdl")
    function preview:LayoutEntity() end

    local placeholder = vgui.Create("DLabel", preview)
    placeholder:Dock(FILL)
    placeholder:SetContentAlignment(5)
    placeholder:SetWrap(true)
    placeholder:SetFont(font(12, false))
    placeholder:SetTextColor(colorFor("Text"))
    placeholder:SetText("No prop model selected yet.")
    preview.Placeholder = placeholder

    return card, preview
end

local function isModelPath(value)
    value = normalizeModel(value)
    return value ~= "" and string.EndsWith(value, ".mdl")
end

local function getModelDisplayName(model, fallback)
    fallback = string.Trim(tostring(fallback or ""))
    if fallback ~= "" then
        return fallback
    end

    local fileName = string.GetFileFromFilename(tostring(model or "")) or ""
    fileName = string.gsub(fileName, "%.mdl$", "")
    fileName = string.gsub(fileName, "[_%-]+", " ")
    fileName = string.Trim(fileName)
    if fileName == "" then
        return tostring(model or "")
    end

    return string.NiceName(fileName)
end

local function addSpawnmenuPropEntry(entries, seen, model, name, category)
    model = normalizeModel(model)
    if not isModelPath(model) then return end

    local existing = seen[model]
    if existing then
        if existing.name == "" and string.Trim(tostring(name or "")) ~= "" then
            existing.name = getModelDisplayName(model, name)
        end
        if existing.category == "" then
            existing.category = string.Trim(tostring(category or ""))
        end
        return
    end

    local entry = {
        model = model,
        name = getModelDisplayName(model, name),
        category = string.Trim(tostring(category or "")),
        file = string.GetFileFromFilename(model) or model,
    }

    seen[model] = entry
    entries[#entries + 1] = entry
end

local function walkSpawnmenuPropSource(node, entries, seen, visited, contextName, contextCategory)
    if node == nil then return end

    if isstring(node) then
        addSpawnmenuPropEntry(entries, seen, node, contextName, contextCategory)
        return
    end

    if not istable(node) or visited[node] then return end
    visited[node] = true

    local model = node.model or node.Model or node.spawnname or node.spawnName or node.filename
    local name = tostring(node.nicename or node.name or node.label or node.PrintName or contextName or "")
    local category = tostring(node.category or node.Category or contextCategory or "")

    if isstring(model) then
        addSpawnmenuPropEntry(entries, seen, model, name, category)
    end

    for key, value in pairs(node) do
        if key ~= "model" and key ~= "Model" and key ~= "spawnname" and key ~= "spawnName"
            and key ~= "filename" and key ~= "nicename" and key ~= "name"
            and key ~= "label" and key ~= "PrintName" and key ~= "category"
            and key ~= "Category" then
            local nextName = contextName
            local nextCategory = contextCategory
            if isstring(key) then
                local label = string.Trim(tostring(key or ""))
                if label ~= "" then
                    if nextName == "" then nextName = label end
                    if nextCategory == "" then nextCategory = label end
                end
            end
            if istable(value) or isstring(value) then
                walkSpawnmenuPropSource(value, entries, seen, visited, nextName, nextCategory)
            end
        end
    end
end

local function collectSpawnmenuPropEntries()
    if istable(SPAWNMENU_PROP_MODEL_CACHE) then
        return SPAWNMENU_PROP_MODEL_CACHE
    end

    local entries = {}
    local seen = {}
    local visited = {}

    if spawnmenu and isfunction(spawnmenu.GetPropTable) then
        walkSpawnmenuPropSource(spawnmenu.GetPropTable(), entries, seen, visited, "", "")
    end

    if list and isfunction(list.Get) then
        walkSpawnmenuPropSource(list.Get("SpawnableProps"), entries, seen, visited, "", "")
    end

    table.sort(entries, function(left, right)
        local leftName = string.lower(tostring(left.name or left.file or left.model or ""))
        local rightName = string.lower(tostring(right.name or right.file or right.model or ""))
        if leftName == rightName then
            return tostring(left.model or "") < tostring(right.model or "")
        end
        return leftName < rightName
    end)

    SPAWNMENU_PROP_MODEL_CACHE = entries
    return entries
end

local function createSpawnmenuPropBrowserCard(parent, title, tall, modelEntry, onPick)
    local card = createCard(parent, title, tall)

    local top = vgui.Create("DPanel", card)
    top:Dock(TOP)
    top:SetTall(scale(70))
    top:DockMargin(scale(12), scale(8), scale(12), 0)
    top.Paint = function() end

    local search = vgui.Create("DTextEntry", top)
    search:Dock(TOP)
    search:SetTall(scale(28))
    if search.SetPlaceholderText then
        search:SetPlaceholderText("Search spawnmenu prop names or model paths...")
    end

    local summary = vgui.Create("DLabel", top)
    summary:Dock(FILL)
    summary:DockMargin(0, scale(6), 0, 0)
    summary:SetFont(font(11, false))
    summary:SetTextColor(colorFor("Text"))
    summary:SetWrap(true)
    summary:SetText("Loading spawnmenu props...")

    local scroll = vgui.Create(chooseClass("Nexus:ScrollPanel", "DScrollPanel"), card)
    scroll:Dock(FILL)
    scroll:DockMargin(scale(12), scale(8), scale(12), scale(12))

    local layoutParent = scroll.GetCanvas and scroll:GetCanvas() or scroll
    local layout = vgui.Create("DIconLayout", layoutParent)
    layout:Dock(TOP)
    layout:SetSpaceX(scale(8))
    layout:SetSpaceY(scale(8))

    local function refreshBrowser()
        if not IsValid(layout) then return end

        layout:Clear()
        local selectedModel = normalizeModel(IsValid(modelEntry) and modelEntry:GetValue() or "")
        local needle = string.lower(string.Trim(IsValid(search) and search:GetValue() or ""))
        local matched = 0
        local shown = 0
        local maxIcons = 180

        for _, entry in ipairs(collectSpawnmenuPropEntries()) do
            local haystack = string.lower(string.format("%s %s %s", tostring(entry.name or ""), tostring(entry.model or ""), tostring(entry.category or "")))
            if needle == "" or string.find(haystack, needle, 1, true) then
                matched = matched + 1
                if shown < maxIcons then
                    shown = shown + 1

                    local button = layout:Add("DButton")
                    button:SetSize(scale(116), scale(136))
                    button:SetText("")
                    button:SetTooltip(string.format("%s\n%s", tostring(entry.name or entry.model or ""), tostring(entry.model or "")))
                    button.Paint = function(self, w, h)
                        local isSelected = normalizeModel(IsValid(modelEntry) and modelEntry:GetValue() or "") == entry.model
                        draw.RoundedBox(scale(8), 0, 0, w, h, colorFor("Header"))
                        surface.SetDrawColor(isSelected and colorFor("Primary") or colorFor("Secondary"))
                        surface.DrawOutlinedRect(0, 0, w, h, 1)
                    end
                    button.DoClick = function()
                        if IsValid(modelEntry) then
                            modelEntry:SetText(entry.model)
                        end
                        if onPick then
                            onPick(entry.model, entry)
                        end
                        setStatus("Selected prop model from the spawnmenu browser.")
                        refreshBrowser()
                    end

                    local icon = vgui.Create("SpawnIcon", button)
                    icon:Dock(TOP)
                    icon:SetTall(scale(90))
                    icon:DockMargin(scale(6), scale(6), scale(6), scale(4))
                    icon:SetModel(entry.model)
                    icon:SetMouseInputEnabled(false)

                    local nameLabel = vgui.Create("DLabel", button)
                    nameLabel:Dock(FILL)
                    nameLabel:DockMargin(scale(6), 0, scale(6), scale(6))
                    nameLabel:SetWrap(true)
                    nameLabel:SetContentAlignment(7)
                    nameLabel:SetFont(font(10, false))
                    nameLabel:SetTextColor(colorFor("Text"))
                    nameLabel:SetText(tostring(entry.name or entry.file or entry.model or ""))
                end
            end
        end

        if matched <= 0 then
            summary:SetText("No spawnmenu props match that search.")
        elseif shown < matched then
            summary:SetText(string.format("Showing first %d of %d matching props. Refine the search to narrow the icon grid.", shown, matched))
        else
            summary:SetText(string.format("%d spawnmenu props match.", matched))
        end

        layout:InvalidateLayout(true)
        if IsValid(scroll) and scroll.InvalidateLayout then
            scroll:InvalidateLayout(true)
        end
    end

    search.OnChange = refreshBrowser
    search.OnValueChange = refreshBrowser

    return card, refreshBrowser
end

local function createLabeledEntry(parent, labelText, placeholder)
    local wrap = vgui.Create("DPanel", parent)
    wrap:Dock(TOP)
    wrap:SetTall(scale(56))
    wrap:DockMargin(scale(12), scale(6), scale(12), 0)
    wrap.Paint = function() end

    local label = vgui.Create("DLabel", wrap)
    label:Dock(TOP)
    label:SetTall(scale(18))
    label:SetFont(font(12, true))
    label:SetTextColor(colorFor("Text"))
    label:SetText(labelText)

    local entry = vgui.Create("DTextEntry", wrap)
    entry:Dock(FILL)
    if entry.SetPlaceholderText and placeholder then
        entry:SetPlaceholderText(placeholder)
    end

    return wrap, entry
end

local function createLabeledTextArea(parent, labelText, placeholder, tall)
    local wrap = vgui.Create("DPanel", parent)
    wrap:Dock(TOP)
    wrap:SetTall(scale(tall or 108))
    wrap:DockMargin(scale(12), scale(6), scale(12), 0)
    wrap.Paint = function() end

    local label = vgui.Create("DLabel", wrap)
    label:Dock(TOP)
    label:SetTall(scale(18))
    label:SetFont(font(12, true))
    label:SetTextColor(colorFor("Text"))
    label:SetText(labelText)

    local entry = vgui.Create("DTextEntry", wrap)
    entry:Dock(FILL)
    entry:SetMultiline(true)
    if entry.SetPlaceholderText and placeholder then
        entry:SetPlaceholderText(placeholder)
    end

    return wrap, entry
end

local function cloneStringList(values)
    local out = {}
    for _, value in ipairs(istable(values) and values or {}) do
        out[#out + 1] = tostring(value or "")
    end
    return out
end

local function createLabeledWang(parent, labelText, minValue, maxValue, value)
    local wrap = vgui.Create("DPanel", parent)
    wrap:Dock(LEFT)
    wrap:SetWide(scale(88))
    wrap:DockMargin(0, 0, scale(8), 0)
    wrap.Paint = function() end

    local label = vgui.Create("DLabel", wrap)
    label:Dock(TOP)
    label:SetTall(scale(18))
    label:SetFont(font(12, true))
    label:SetTextColor(colorFor("Text"))
    label:SetText(labelText)

    local wang = vgui.Create("DNumberWang", wrap)
    wang:Dock(FILL)
    wang:SetMinMax(minValue, maxValue)
    wang:SetValue(value)

    return wrap, wang
end

local function populateCatalogList(editor)
    if not IsValid(editor.catalogList) then return end

    editor.catalogList:Clear()
    local filter = string.lower(string.Trim(IsValid(editor.searchEntry) and editor.searchEntry:GetValue() or ""))

    for _, entry in ipairs(collectCatalogEntries()) do
        local haystack = string.lower(string.format("%s %s %s %s", entry.name, entry.class, entry.kind, entry.detail or ""))
        if filter == "" or string.find(haystack, filter, 1, true) then
            local line = editor.catalogList:AddLine(entry.name, entry.class, entry.kind, entry.size)
            line._class = entry.class
            if editor.selectedCatalogClass == entry.class then
                editor.catalogList:SelectItem(line)
            end
        end
    end
end

local function populateLootList(editor)
    if not IsValid(editor.lootList) then return end

    editor.lootList:Clear()
    for index, row in ipairs(editor.lootRows or {}) do
        local line = editor.lootList:AddLine(
            prettyClassName(row.class),
            tostring(row.class or ""),
            tostring(row.chance or 100),
            tostring(row.min or 1),
            tostring(row.max or 1)
        )
        line._lootIndex = index
        if editor.selectedLootIndex == index then
            editor.lootList:SelectItem(line)
        end
    end
end

local function fillContainerEditor(editor, key, def)
    editor.selectedSavedKey = key
    if IsValid(editor.modelEntry) then
        editor.modelEntry:SetText(tostring(def.model or ""))
    end
    if IsValid(editor.labelEntry) then
        editor.labelEntry:SetText(tostring(def.label or def.name or "Loot Container"))
    end
    if IsValid(editor.chanceWang) then
        editor.chanceWang:SetValue(math.Clamp(math.Round(tonumber(def.spawn_chance) or tonumber(def.chance) or 100), 0, 100))
    end
    if IsValid(editor.gridWWang) then
        editor.gridWWang:SetValue(math.Clamp(math.floor(tonumber(def.grid and def.grid.w or def.gw) or 4), 1, 32))
    end
    if IsValid(editor.gridHWang) then
        editor.gridHWang:SetValue(math.Clamp(math.floor(tonumber(def.grid and def.grid.h or def.gh) or 4), 1, 32))
    end
    editor.lootRows = cloneLootRows(def.loot or {})
    editor.selectedLootIndex = nil
    populateLootList(editor)
end

local function populateContainerSavedList(editor)
    if not IsValid(editor.savedList) then return end

    editor.savedList:Clear()
    local state = getWorldLootState()

    if editor.kind == "placed" then
        for _, def in ipairs(state.placed_spawns or {}) do
            local line = editor.savedList:AddLine(
                tostring(def.label or def.id or "Loot Container"),
                string.format("%dx%d", tonumber(def.grid and def.grid.w) or 0, tonumber(def.grid and def.grid.h) or 0),
                string.format("%.0f%%", tonumber(def.spawn_chance) or 100),
                tostring(def.model or "")
            )
            line._savedKey = tostring(def.id or "")
            line._def = def
            if editor.selectedSavedKey ~= "" and editor.selectedSavedKey == line._savedKey then
                editor.savedList:SelectItem(line)
            end
        end
        return
    end

    local keys = {}
    for model in pairs(state.model_containers or {}) do
        keys[#keys + 1] = model
    end
    table.sort(keys, function(left, right)
        local leftDef = state.model_containers[left] or {}
        local rightDef = state.model_containers[right] or {}
        local leftName = string.lower(tostring(leftDef.label or leftDef.name or left))
        local rightName = string.lower(tostring(rightDef.label or rightDef.name or right))
        if leftName == rightName then
            return tostring(left) < tostring(right)
        end
        return leftName < rightName
    end)

    for _, model in ipairs(keys) do
        local def = state.model_containers[model]
        local line = editor.savedList:AddLine(
            tostring(def.label or def.name or "Loot Container"),
            string.format("%dx%d", tonumber(def.grid and def.grid.w) or 0, tonumber(def.grid and def.grid.h) or 0),
            string.format("%.0f%%", tonumber(def.spawn_chance) or 100),
            tostring(model or def.model or "")
        )
        line._savedKey = tostring(model)
        line._def = def
        if editor.selectedSavedKey ~= "" and editor.selectedSavedKey == line._savedKey then
            editor.savedList:SelectItem(line)
        end
    end
end

local function buildContainerPage(parent, kind)
    local page = vgui.Create(chooseClass("Nexus:ScrollPanel", "DScrollPanel"), parent)
    page:Dock(FILL)
    page:DockMargin(scale(10), scale(10), scale(10), scale(10))
    page:SetVisible(false)

    local editor = {
        kind = kind,
        page = page,
        lootRows = {},
        selectedSavedKey = "",
        selectedCatalogClass = nil,
        selectedLootIndex = nil,
    }

    local intro = vgui.Create("DLabel", page)
    intro:Dock(TOP)
    intro:DockMargin(0, 0, 0, scale(10))
    intro:SetWrap(true)
    intro:SetAutoStretchVertical(true)
    intro:SetFont(font(13, false))
    intro:SetTextColor(colorFor("Text"))
    if kind == "model" then
        intro:SetText("Create reusable loot profiles keyed to a prop model. These profiles let staff convert the currently aimed prop into a ZScav loot container without making every matching raw prop in the world lootable.")
    else
        intro:SetText("Save a specific prop in the map as a persistent loot spawn. Aim at the prop you want to save or update, then push the save button from this page.")
    end

    local body = vgui.Create("DPanel", page)
    body:Dock(TOP)
    body:SetTall(scale(kind == "model" and 1280 or 1040))
    body.Paint = function() end

    local left = vgui.Create("DPanel", body)
    left:SetWide(scale(620))
    left:Dock(LEFT)
    left:DockMargin(0, 0, scale(10), 0)
    left.Paint = function() end

    local right = vgui.Create("DPanel", body)
    right:Dock(FILL)
    right.Paint = function() end

    local targetCard = createCard(left, kind == "model" and "Target Model" or "Target Prop", scale(156))
    local _, modelEntry = createLabeledEntry(targetCard, kind == "model" and "Model Path" or "Aimed Prop Model", "models/props_junk/wood_crate001a.mdl")
    modelEntry:SetText("")
    if kind == "placed" and modelEntry.SetEditable then
        modelEntry:SetEditable(false)
    end
    editor.modelEntry = modelEntry

    local function refreshModelPreview()
        if editor.RefreshPropBrowser then
            editor.RefreshPropBrowser()
        end
    end

    modelEntry.OnValueChange = refreshModelPreview

    local aimRow = vgui.Create("DPanel", targetCard)
    aimRow:Dock(BOTTOM)
    aimRow:SetTall(scale(38))
    aimRow:DockMargin(scale(12), scale(6), scale(12), scale(12))
    aimRow.Paint = function() end

    local aimButton = createButton(aimRow, kind == "model" and "Use Aimed Prop Model" or "Capture Aimed Prop", "Primary")
    aimButton:Dock(LEFT)
    aimButton:SetWide(scale(200))
    aimButton.DoClick = function()
        local ent, model = getAimedEntityAndModel()
        if kind == "placed" and not IsValid(ent) then
            setStatus("Aim at a prop or existing loot container first.")
            return
        end
        if model == "" then
            setStatus("The aimed entity does not expose a valid prop model.")
            return
        end

        editor.modelEntry:SetText(model)
        refreshModelPreview()
        if kind == "placed" then
            setStatus("Captured the currently aimed prop. Save to persist it.")
        else
            setStatus("Captured the prop model for this auto-container profile.")
        end
    end

    local resetButton = createButton(aimRow, "Clear Selection", "Orange")
    resetButton:Dock(RIGHT)
    resetButton:SetWide(scale(140))
    resetButton.DoClick = function()
        editor.selectedSavedKey = ""
        editor.selectedLootIndex = nil
        editor.lootRows = {}
        editor.modelEntry:SetText("")
        refreshModelPreview()
        editor.labelEntry:SetText("Loot Container")
        editor.chanceWang:SetValue(100)
        editor.gridWWang:SetValue(4)
        editor.gridHWang:SetValue(4)
        populateLootList(editor)
        populateContainerSavedList(editor)
        setStatus("Cleared the current editor state.")
    end

    local settingsCard = createCard(left, "Container Settings", scale(222))
    local _, labelEntry = createLabeledEntry(settingsCard, "Display Label", "Loot Container")
    labelEntry:SetText("Loot Container")
    editor.labelEntry = labelEntry

    local gridRow = vgui.Create("DPanel", settingsCard)
    gridRow:Dock(BOTTOM)
    gridRow:SetTall(scale(52))
    gridRow:DockMargin(scale(12), scale(8), scale(12), scale(12))
    gridRow.Paint = function() end

    local _, chanceWang = createLabeledWang(gridRow, "Chance %", 0, 100, 100)
    local _, gridWWang = createLabeledWang(gridRow, "Grid W", 1, 32, 4)
    local _, gridHWang = createLabeledWang(gridRow, "Grid H", 1, 32, 4)
    editor.chanceWang = chanceWang
    editor.gridWWang = gridWWang
    editor.gridHWang = gridHWang

    local catalogCard = createCard(left, "Catalog Browser", scale(360))
    local _, searchEntry = createLabeledEntry(catalogCard, "Search Catalog", "Search ZScav items, gear, classes, or groups")
    editor.searchEntry = searchEntry

    local catalogList = vgui.Create("DListView", catalogCard)
    catalogList:Dock(FILL)
    catalogList:DockMargin(scale(12), scale(8), scale(12), scale(8))
    catalogList:SetMultiSelect(false)
    catalogList:AddColumn("Item")
    catalogList:AddColumn("Class")
    catalogList:AddColumn("Type")
    catalogList:AddColumn("Size")
    editor.catalogList = catalogList

    local rowControls = vgui.Create("DPanel", catalogCard)
    rowControls:Dock(BOTTOM)
    rowControls:SetTall(scale(78))
    rowControls:DockMargin(scale(12), 0, scale(12), scale(12))
    rowControls.Paint = function() end

    local wangRow = vgui.Create("DPanel", rowControls)
    wangRow:Dock(TOP)
    wangRow:SetTall(scale(38))
    wangRow.Paint = function() end

    local _, rowChanceWang = createLabeledWang(wangRow, "Chance", 0, 100, 100)
    local _, rowMinWang = createLabeledWang(wangRow, "Min", 1, 32, 1)
    local _, rowMaxWang = createLabeledWang(wangRow, "Max", 1, 32, 1)

    local addLootButton = createButton(rowControls, "Add Selected Catalog Entry To Loot Table", "Green")
    addLootButton:Dock(BOTTOM)
    addLootButton:SetTall(scale(32))

    if kind == "model" then
        local _, refreshPropBrowser = createSpawnmenuPropBrowserCard(right, "Spawnmenu Prop Browser", scale(430), modelEntry, function()
            refreshModelPreview()
        end)
        editor.RefreshPropBrowser = refreshPropBrowser
    end

    local lootCard = createCard(right, "Loot Table", scale(286))
    local lootList = vgui.Create("DListView", lootCard)
    lootList:Dock(FILL)
    lootList:DockMargin(scale(12), scale(8), scale(12), scale(8))
    lootList:SetMultiSelect(false)
    lootList:AddColumn("Item")
    lootList:AddColumn("Class")
    lootList:AddColumn("Chance")
    lootList:AddColumn("Min")
    lootList:AddColumn("Max")
    editor.lootList = lootList

    local removeLootButton = createButton(lootCard, "Remove Selected Loot Row", "Red")
    removeLootButton:Dock(BOTTOM)
    removeLootButton:DockMargin(scale(12), 0, scale(12), scale(12))
    removeLootButton:SetTall(scale(32))

    local savedCard = createCard(right, kind == "model" and "Saved Model Profiles" or "Saved Placed Spawns", scale(454))
    local savedList = vgui.Create("DListView", savedCard)
    savedList:Dock(FILL)
    savedList:DockMargin(scale(12), scale(8), scale(12), scale(8))
    savedList:SetMultiSelect(false)
    savedList:AddColumn(kind == "model" and "Profile" or "Container")
    savedList:AddColumn("Grid")
    savedList:AddColumn("Chance")
    savedList:AddColumn("Model")
    editor.savedList = savedList

    local actionRow = vgui.Create("DPanel", savedCard)
    actionRow:Dock(BOTTOM)
    actionRow:SetTall(scale(38))
    actionRow:DockMargin(scale(12), 0, scale(12), scale(12))
    actionRow.Paint = function() end

    local saveButton = createButton(actionRow, kind == "model" and "Save Model Profile" or "Save Aimed Prop", "Green")
    saveButton:Dock(LEFT)
    saveButton:SetWide(scale(220))

    local deleteButton = createButton(actionRow, kind == "model" and "Delete Selected Profile" or "Delete Selected Spawn", "Red")
    deleteButton:Dock(RIGHT)
    deleteButton:SetWide(scale(200))

    searchEntry.OnChange = function()
        populateCatalogList(editor)
    end

    catalogList.OnRowSelected = function(_, _, line)
        editor.selectedCatalogClass = line and line._class or nil
    end

    lootList.OnRowSelected = function(_, _, line)
        editor.selectedLootIndex = line and line._lootIndex or nil
    end

    savedList.OnRowSelected = function(_, _, line)
        editor.selectedSavedKey = line and line._savedKey or ""
        if line and line._def then
            fillContainerEditor(editor, editor.selectedSavedKey, line._def)
            refreshModelPreview()
            setStatus(kind == "model" and "Loaded model profile into the editor." or "Loaded placed spawn settings into the editor. Aim at the target prop before saving.")
        end
    end

    addLootButton.DoClick = function()
        if not editor.selectedCatalogClass then
            setStatus("Pick a catalog class or group first.")
            return
        end

        local minCount = math.max(1, math.floor(tonumber(rowMinWang:GetValue()) or 1))
        local maxCount = math.max(minCount, math.floor(tonumber(rowMaxWang:GetValue()) or minCount))
        editor.lootRows[#editor.lootRows + 1] = {
            class = tostring(editor.selectedCatalogClass),
            chance = math.Clamp(math.floor(tonumber(rowChanceWang:GetValue()) or 100), 0, 100),
            min = minCount,
            max = maxCount,
        }
        editor.selectedLootIndex = nil
        populateLootList(editor)
        setStatus("Added the selected catalog entry to the loot table.")
    end

    removeLootButton.DoClick = function()
        if not editor.selectedLootIndex then
            setStatus("Select a loot row to remove.")
            return
        end

        table.remove(editor.lootRows, editor.selectedLootIndex)
        editor.selectedLootIndex = nil
        populateLootList(editor)
        setStatus("Removed the selected loot row.")
    end

    saveButton.DoClick = function()
        local lib = getWorldLootLib()
        if not lib then
            setStatus("World loot library is not ready yet.")
            return
        end

        local payload = {
            label = string.Trim(tostring(labelEntry:GetValue() or "Loot Container")),
            spawn_chance = math.Clamp(math.floor(tonumber(chanceWang:GetValue()) or 100), 0, 100),
            grid = {
                w = math.Clamp(math.floor(tonumber(gridWWang:GetValue()) or 4), 1, 32),
                h = math.Clamp(math.floor(tonumber(gridHWang:GetValue()) or 4), 1, 32),
            },
            loot = cloneLootRows(editor.lootRows),
        }

        if kind == "placed" then
            local ent = getAimedEntityAndModel()
            if not IsValid(ent) then
                setStatus("Aim at the prop or loot container you want to save first.")
                return
            end

            payload.ent_index = ent:EntIndex()
            if editor.selectedSavedKey ~= "" then
                payload.id = editor.selectedSavedKey
            end

            if sendWorldLootAction(lib.ACTION_PLACE_CONTAINER, payload) then
                setStatus("Sent the placed-container update to the server.")
            end
            return
        end

        payload.model = normalizeModel(modelEntry:GetValue())
        if payload.model == "" then
            setStatus("Provide a prop model first.")
            return
        end

        local ent, aimedModel = getAimedEntityAndModel()
        if IsValid(ent) and aimedModel == payload.model then
            payload.ent_index = ent:EntIndex()
        end

        if sendWorldLootAction(lib.ACTION_REGISTER_MODEL_CONTAINER, payload) then
            setStatus("Sent the model profile to the server.")
        end
    end

    deleteButton.DoClick = function()
        local lib = getWorldLootLib()
        if not lib then
            setStatus("World loot library is not ready yet.")
            return
        end

        if kind == "placed" then
            local payload = {}
            if editor.selectedSavedKey ~= "" then
                payload.id = editor.selectedSavedKey
            end

            local ent = getAimedEntityAndModel()
            if IsValid(ent) then
                payload.ent_index = ent:EntIndex()
            end

            if not payload.id and not payload.ent_index then
                setStatus("Select a saved spawn or aim at the target prop first.")
                return
            end

            if sendWorldLootAction(lib.ACTION_REMOVE_CONTAINER, payload) then
                setStatus("Sent the placed-container removal to the server.")
            end
            return
        end

        local model = editor.selectedSavedKey ~= "" and editor.selectedSavedKey or normalizeModel(modelEntry:GetValue())
        if model == "" then
            setStatus("Select a saved model profile or enter a model path first.")
            return
        end

        if sendWorldLootAction(lib.ACTION_UNREGISTER_MODEL_CONTAINER, { model = model }) then
            setStatus("Sent the model-profile removal to the server.")
        end
    end

    editor.Refresh = function()
        populateCatalogList(editor)
        populateLootList(editor)
        populateContainerSavedList(editor)
        refreshModelPreview()
        if editor.RefreshPropBrowser then
            editor.RefreshPropBrowser()
        end
    end

    editor.ApplyFocus = function(focus)
        if not istable(focus) then return end
        local model = normalizeModel(focus.model)
        if model ~= "" then
            editor.modelEntry:SetText(model)
            refreshModelPreview()
            if editor.RefreshPropBrowser then
                editor.RefreshPropBrowser()
            end
            if kind == "model" then
                local def = getWorldLootState().model_containers[model]
                if istable(def) then
                    fillContainerEditor(editor, model, def)
                    refreshModelPreview()
                end
            end
        end
    end

    refreshModelPreview()

    return editor
end

local function fillValuableEditor(page, class, def)
    page.selectedClass = tostring(class or "")
    page.modelEntry:SetText(tostring(def.model or ""))
    page.classEntry:SetText(tostring(def.item_class or class or ""))
    page.nameEntry:SetText(tostring(def.name or prettyClassName(class) or ""))
    page.widthWang:SetValue(math.Clamp(math.floor(tonumber(def.w) or 1), 1, 16))
    page.heightWang:SetValue(math.Clamp(math.floor(tonumber(def.h) or 1), 1, 16))
    page.weightEntry:SetText(tostring(tonumber(def.weight) or 0))
    page.categoryEntry:SetText(tostring(def.category or "valuable"))
end

local function populateValuableList(page)
    if not IsValid(page.savedList) then return end

    page.savedList:Clear()
    local state = getWorldLootState()
    local keys = {}
    for class in pairs(state.valuables or {}) do
        keys[#keys + 1] = class
    end
    table.sort(keys, function(left, right)
        local leftDef = state.valuables[left] or {}
        local rightDef = state.valuables[right] or {}
        local leftName = string.lower(tostring(leftDef.name or left))
        local rightName = string.lower(tostring(rightDef.name or right))
        if leftName == rightName then
            return tostring(left) < tostring(right)
        end
        return leftName < rightName
    end)

    for _, class in ipairs(keys) do
        local def = state.valuables[class]
        local line = page.savedList:AddLine(
            tostring(class),
            tostring(def.name or prettyClassName(class) or class),
            string.format("%dx%d", tonumber(def.w) or 1, tonumber(def.h) or 1),
            tostring(def.category or "valuable"),
            tostring(def.model or "")
        )
        line._class = tostring(class)
        line._def = def
        if page.selectedClass ~= "" and page.selectedClass == line._class then
            page.savedList:SelectItem(line)
        end
    end
end

local function suggestValuableFields(page)
    local lib = getWorldLootLib()
    local model = normalizeModel(page.modelEntry:GetValue())
    if model == "" or not lib then
        setStatus("Set a prop model first.")
        return
    end

    if page.classEntry:GetValue() == "" or string.StartWith(page.classEntry:GetValue(), "zscav_loot_item_") then
        page.classEntry:SetText(tostring(lib.GetSuggestedValuableClassForModel and lib.GetSuggestedValuableClassForModel(model) or ""))
    end
    if page.nameEntry:GetValue() == "" or page.nameEntry:GetValue() == "Prop Item" then
        page.nameEntry:SetText(tostring(lib.GetSuggestedValuableNameForModel and lib.GetSuggestedValuableNameForModel(model) or "Prop Item"))
    end
    setStatus("Applied the suggested item id and name for this model.")
end

local function buildValuablePage(parent)
    local pagePanel = vgui.Create(chooseClass("Nexus:ScrollPanel", "DScrollPanel"), parent)
    pagePanel:Dock(FILL)
    pagePanel:DockMargin(scale(10), scale(10), scale(10), scale(10))
    pagePanel:SetVisible(false)

    local page = {
        page = pagePanel,
        selectedClass = "",
    }

    local intro = vgui.Create("DLabel", pagePanel)
    intro:Dock(TOP)
    intro:DockMargin(0, 0, 0, scale(10))
    intro:SetWrap(true)
    intro:SetAutoStretchVertical(true)
    intro:SetFont(font(13, false))
    intro:SetTextColor(colorFor("Text"))
    intro:SetText("Register prop models as catalog-backed valuable items. Display Name is what players see in inventory and loot prompts; the Item ID can stay machine-readable. Use the quick actions below to save, spawn, or push a selected valuable straight into the aimed loot container.")

    local body = vgui.Create("DPanel", pagePanel)
    body:Dock(TOP)
    body:SetTall(scale(1160))
    body.Paint = function() end

    local left = vgui.Create("DPanel", body)
    left:SetWide(scale(620))
    left:Dock(LEFT)
    left:DockMargin(0, 0, scale(10), 0)
    left.Paint = function() end

    local right = vgui.Create("DPanel", body)
    right:Dock(FILL)
    right.Paint = function() end

    local modelCard = createCard(left, "Prop Model", scale(176))
    local _, modelEntry = createLabeledEntry(modelCard, "Model Path", "models/props_lab/box01a.mdl")
    page.modelEntry = modelEntry

    local function refreshModelPreview()
        if page.RefreshPropBrowser then
            page.RefreshPropBrowser()
        end
    end

    modelEntry.OnValueChange = refreshModelPreview

    local _, refreshPropBrowser = createSpawnmenuPropBrowserCard(right, "Spawnmenu Prop Browser", scale(430), modelEntry, function()
        refreshModelPreview()
    end)
    page.RefreshPropBrowser = refreshPropBrowser

    local modelButtons = vgui.Create("DPanel", modelCard)
    modelButtons:Dock(BOTTOM)
    modelButtons:SetTall(scale(38))
    modelButtons:DockMargin(scale(12), scale(6), scale(12), scale(12))
    modelButtons.Paint = function() end

    local aimButton = createButton(modelButtons, "Use Aimed Prop Model", "Primary")
    aimButton:Dock(LEFT)
    aimButton:SetWide(scale(190))
    aimButton.DoClick = function()
        local _, model = getAimedEntityAndModel()
        if model == "" then
            setStatus("Aim at a prop model first.")
            return
        end

        modelEntry:SetText(model)
        refreshModelPreview()
        setStatus("Captured the prop model.")
    end

    local suggestButton = createButton(modelButtons, "Suggest From Model", "Orange")
    suggestButton:Dock(RIGHT)
    suggestButton:SetWide(scale(170))
    suggestButton.DoClick = function()
        suggestValuableFields(page)
    end

    local detailsCard = createCard(left, "Catalog Item Details", scale(286))
    local _, classEntry = createLabeledEntry(detailsCard, "Internal Item ID", "zscav_loot_item_prop_123456")
    local _, nameEntry = createLabeledEntry(detailsCard, "Display Name", "Prop Item")
    page.classEntry = classEntry
    page.nameEntry = nameEntry

    local sizeRow = vgui.Create("DPanel", detailsCard)
    sizeRow:Dock(TOP)
    sizeRow:SetTall(scale(52))
    sizeRow:DockMargin(scale(12), scale(8), scale(12), 0)
    sizeRow.Paint = function() end

    local _, widthWang = createLabeledWang(sizeRow, "Width", 1, 16, 1)
    local _, heightWang = createLabeledWang(sizeRow, "Height", 1, 16, 1)
    page.widthWang = widthWang
    page.heightWang = heightWang

    local _, weightEntry = createLabeledEntry(detailsCard, "Weight", "0.5")
    if weightEntry.SetNumeric then
        weightEntry:SetNumeric(true)
    end
    weightEntry:SetText("0.5")
    page.weightEntry = weightEntry

    local _, categoryEntry = createLabeledEntry(detailsCard, "Category", "valuable")
    categoryEntry:SetText("valuable")
    page.categoryEntry = categoryEntry

    local actionCard = createCard(left, "Actions", scale(304))
    local actionRow = vgui.Create("DPanel", actionCard)
    actionRow:Dock(FILL)
    actionRow:DockMargin(scale(12), scale(8), scale(12), scale(12))
    actionRow.Paint = function() end

    local quickRow = vgui.Create("DPanel", actionRow)
    quickRow:Dock(TOP)
    quickRow:SetTall(scale(44))
    quickRow:DockMargin(0, 0, 0, scale(8))
    quickRow.Paint = function() end

    local _, countWang = createLabeledWang(quickRow, "Count", 1, 32, 1)
    page.countWang = countWang

    local quickHint = vgui.Create("DLabel", quickRow)
    quickHint:Dock(FILL)
    quickHint:DockMargin(scale(8), scale(18), 0, 0)
    quickHint:SetFont(font(11, false))
    quickHint:SetTextColor(colorFor("Text"))
    quickHint:SetWrap(true)
    quickHint:SetText("Spawn uses this as drop count. Add-to-container saves a guaranteed loot row and also inserts live copies when possible.")

    local saveButton = createButton(actionRow, "Save Profile", "Green")
    saveButton:Dock(TOP)
    saveButton:DockMargin(0, 0, 0, scale(8))

    local saveConfigButton = createButton(actionRow, "Save Profile + Open Config", "Primary")
    saveConfigButton:Dock(TOP)
    saveConfigButton:DockMargin(0, 0, 0, scale(8))

    local spawnButton = createButton(actionRow, "Save Profile + Spawn Near You", "Orange")
    spawnButton:Dock(TOP)
    spawnButton:DockMargin(0, 0, 0, scale(8))

    local addToContainerButton = createButton(actionRow, "Save Profile + Add To Aimed Container", "Primary")
    addToContainerButton:Dock(TOP)

    local savedCard = createCard(right, "Saved Valuable Profiles", scale(604))
    local savedList = vgui.Create("DListView", savedCard)
    savedList:Dock(FILL)
    savedList:DockMargin(scale(12), scale(8), scale(12), scale(8))
    savedList:SetMultiSelect(false)
    savedList:AddColumn("Item ID")
    savedList:AddColumn("Name")
    savedList:AddColumn("Size")
    savedList:AddColumn("Category")
    savedList:AddColumn("Model")
    page.savedList = savedList

    local deleteButton = createButton(savedCard, "Delete Selected Valuable", "Red")
    deleteButton:Dock(BOTTOM)
    deleteButton:DockMargin(scale(12), 0, scale(12), scale(12))
    deleteButton:SetTall(scale(32))

    local function buildValuablePayload(openConfig)
        local model = normalizeModel(modelEntry:GetValue())
        if model == "" then
            setStatus("Provide a prop model first.")
            return nil
        end

        local itemClass = string.Trim(tostring(classEntry:GetValue() or ""))
        if itemClass == "" then
            setStatus("Provide an item id first.")
            return nil
        end

        local previousClass = tostring(page.selectedClass or "")
        page.selectedClass = itemClass
        return {
            model = model,
            item_class = itemClass,
            previous_item_class = previousClass,
            name = string.Trim(tostring(nameEntry:GetValue() or "Prop Item")),
            w = math.Clamp(math.floor(tonumber(widthWang:GetValue()) or 1), 1, 16),
            h = math.Clamp(math.floor(tonumber(heightWang:GetValue()) or 1), 1, 16),
            weight = math.max(0, tonumber(weightEntry:GetValue()) or 0),
            category = string.Trim(tostring(categoryEntry:GetValue() or "valuable")),
            count = math.Clamp(math.floor(tonumber(countWang:GetValue()) or 1), 1, 32),
            open_config = openConfig and true or false,
        }
    end

    local function sendValuable(openConfig)
        local lib = getWorldLootLib()
        if not lib then
            setStatus("World loot library is not ready yet.")
            return
        end

        local payload = buildValuablePayload(openConfig)
        if not payload then return end

        if sendWorldLootAction(lib.ACTION_REGISTER_VALUABLE, payload) then
            setStatus(openConfig and "Saved the valuable profile and requested the config editor." or "Saved the valuable profile.")
        end
    end

    saveButton.DoClick = function()
        sendValuable(false)
    end

    saveConfigButton.DoClick = function()
        sendValuable(true)
    end

    spawnButton.DoClick = function()
        local lib = getWorldLootLib()
        if not lib then
            setStatus("World loot library is not ready yet.")
            return
        end

        local payload = buildValuablePayload(false)
        if not payload then return end

        if sendWorldLootAction(lib.ACTION_SPAWN_VALUABLE, payload) then
            setStatus("Sent the save+spawn request to the server.")
        end
    end

    addToContainerButton.DoClick = function()
        local lib = getWorldLootLib()
        if not lib then
            setStatus("World loot library is not ready yet.")
            return
        end

        local payload = buildValuablePayload(false)
        if not payload then return end

        local ent = getAimedEntityAndModel()
        if not IsValid(ent) then
            setStatus("Aim at a loot container or saved loot prop first.")
            return
        end

        payload.ent_index = ent:EntIndex()
        if sendWorldLootAction(lib.ACTION_ADD_VALUABLE_TO_CONTAINER, payload) then
            setStatus("Sent the save+container-add request to the server.")
        end
    end

    deleteButton.DoClick = function()
        local lib = getWorldLootLib()
        if not lib then
            setStatus("World loot library is not ready yet.")
            return
        end

        local itemClass = page.selectedClass ~= "" and page.selectedClass or string.Trim(tostring(classEntry:GetValue() or ""))
        if itemClass == "" then
            setStatus("Select a saved valuable or enter its class first.")
            return
        end

        if sendWorldLootAction(lib.ACTION_UNREGISTER_VALUABLE, { item_class = itemClass }) then
            setStatus("Sent the valuable-profile removal to the server.")
        end
    end

    savedList.OnRowSelected = function(_, _, line)
        if not line then return end
        fillValuableEditor(page, line._class, line._def or {})
        refreshModelPreview()
        setStatus("Loaded the valuable profile into the editor.")
    end

    page.Refresh = function()
        populateValuableList(page)
        refreshModelPreview()
        if page.RefreshPropBrowser then
            page.RefreshPropBrowser()
        end
    end

    page.ApplyFocus = function(focus)
        if not istable(focus) then return end

        local model = normalizeModel(focus.model)
        if model == "" then return end

        page.modelEntry:SetText(model)
        refreshModelPreview()
        if page.RefreshPropBrowser then
            page.RefreshPropBrowser()
        end
        local existing = getWorldLootLib() and getWorldLootLib().GetWorldItemDefByModel and getWorldLootLib().GetWorldItemDefByModel(model) or nil
        if istable(existing) then
            fillValuableEditor(page, existing.item_class or "", existing)
            refreshModelPreview()
        else
            suggestValuableFields(page)
        end
    end

    refreshModelPreview()

    return page
end

local function populateGroupCatalogList(page)
    if not IsValid(page.catalogList) then return end

    page.catalogList:Clear()
    local filter = string.lower(string.Trim(IsValid(page.searchEntry) and page.searchEntry:GetValue() or ""))

    for _, entry in ipairs(collectCatalogEntries()) do
        if entry.kind ~= "group" then
            local haystack = string.lower(string.format("%s %s %s %s", entry.name, entry.class, entry.kind, entry.detail or ""))
            if filter == "" or string.find(haystack, filter, 1, true) then
                local line = page.catalogList:AddLine(entry.name, entry.class, entry.kind, entry.size)
                line._class = entry.class
                if page.selectedCatalogClass == entry.class then
                    page.catalogList:SelectItem(line)
                end
            end
        end
    end
end

local function populateGroupMemberList(page)
    if not IsValid(page.memberList) then return end

    page.memberList:Clear()
    local lib = getWorldLootLib()

    for index, class in ipairs(page.groupClasses or {}) do
        local size = ZSCAV and ZSCAV.GetItemSize and ZSCAV:GetItemSize(class) or nil
        local line = page.memberList:AddLine(
            prettyClassName(class),
            tostring(class),
            tostring(lib and lib.ClassifyLootCatalogClass and lib.ClassifyLootCatalogClass(class) or "item"),
            string.format("%dx%d", tonumber(size and size.w) or 1, tonumber(size and size.h) or 1)
        )
        line._memberIndex = index
        if page.selectedMemberIndex == index then
            page.memberList:SelectItem(line)
        end
    end

    if IsValid(page.memberInfoLabel) then
        page.memberInfoLabel:SetText(string.format("%d member class%s in this group.", #page.groupClasses, #page.groupClasses == 1 and "" or "es"))
    end
end

local function populateSavedGroupList(page)
    if not IsValid(page.savedList) then return end

    page.savedList:Clear()
    local lib = getWorldLootLib()
    if not lib or not lib.GetLootGroupCatalog then return end

    for _, def in ipairs(lib.GetLootGroupCatalog()) do
        local source = def.overridden and "Override" or (def.builtin and "Builtin" or "Custom")
        local line = page.savedList:AddLine(
            tostring(def.label or def.token or "Loot Group"),
            tostring(def.token or ""),
            tostring(def.count or 0),
            source,
            tostring(def.description or "")
        )
        line._token = tostring(def.token or "")
        line._def = def
        if page.selectedGroupToken ~= "" and page.selectedGroupToken == line._token then
            page.savedList:SelectItem(line)
        end
    end
end

local function fillLootGroupEditor(page, token, def)
    local lib = getWorldLootLib()
    if not lib then return end

    token = lib.NormalizeLootGroupToken(token)
    if token == "" then return end

    def = istable(def) and def or (lib.GetLootGroupDef and lib.GetLootGroupDef(token) or nil)
    if not istable(def) then return end

    page.selectedGroupToken = token
    page.selectedCatalogClass = nil
    page.selectedMemberIndex = nil
    page.groupClasses = cloneStringList(lib.GetLootGroupMembers and lib.GetLootGroupMembers(token) or def.classes or {})
    page.tokenEntry:SetText(token)
    page.labelEntry:SetText(tostring(def.label or ""))
    page.descriptionEntry:SetText(tostring(def.description or ""))
    populateGroupMemberList(page)
    populateSavedGroupList(page)
end

local function clearLootGroupEditor(page)
    page.selectedGroupToken = ""
    page.selectedCatalogClass = nil
    page.selectedMemberIndex = nil
    page.groupClasses = {}
    page.tokenEntry:SetText("")
    page.labelEntry:SetText("")
    page.descriptionEntry:SetText("")
    populateGroupMemberList(page)
    populateSavedGroupList(page)
end

local function buildLootGroupPayload(page)
    local lib = getWorldLootLib()
    if not lib then
        setStatus("World loot library is not ready yet.")
        return nil
    end

    local label = string.Trim(tostring(page.labelEntry:GetValue() or ""))
    local token = lib.NormalizeLootGroupToken(page.tokenEntry:GetValue())
    if token == "" and label ~= "" then
        token = lib.NormalizeLootGroupToken(label)
        page.tokenEntry:SetText(token)
    end
    if token == "" then
        setStatus("Provide a loot group token or label first.")
        return nil
    end

    local classes = cloneStringList(page.groupClasses)
    classes = lib.NormalizeLootGroupClasses and lib.NormalizeLootGroupClasses(classes) or classes
    if #classes <= 0 then
        setStatus("Add at least one catalog item to this group first.")
        return nil
    end

    return {
        token = token,
        label = label ~= "" and label or string.NiceName(string.sub(token, 2)),
        description = string.Trim(tostring(page.descriptionEntry:GetValue() or "")),
        classes = classes,
    }
end

local function buildLootGroupPage(parent)
    local pagePanel = vgui.Create(chooseClass("Nexus:ScrollPanel", "DScrollPanel"), parent)
    pagePanel:Dock(FILL)
    pagePanel:DockMargin(scale(10), scale(10), scale(10), scale(10))
    pagePanel:SetVisible(false)

    local page = {
        page = pagePanel,
        selectedGroupToken = "",
        selectedCatalogClass = nil,
        selectedMemberIndex = nil,
        groupClasses = {},
    }

    local intro = vgui.Create("DLabel", pagePanel)
    intro:Dock(TOP)
    intro:DockMargin(0, 0, 0, scale(10))
    intro:SetWrap(true)
    intro:SetAutoStretchVertical(true)
    intro:SetFont(font(13, false))
    intro:SetTextColor(colorFor("Text"))
    intro:SetText("Edit the built-in loot groups by saving an override on the same token, or create completely new groups for container loot tables. Deleting an override resets a built-in group back to its default class pool.")

    local body = vgui.Create("DPanel", pagePanel)
    body:Dock(TOP)
    body:SetTall(scale(1240))
    body.Paint = function() end

    local left = vgui.Create("DPanel", body)
    left:SetWide(scale(620))
    left:Dock(LEFT)
    left:DockMargin(0, 0, scale(10), 0)
    left.Paint = function() end

    local right = vgui.Create("DPanel", body)
    right:Dock(FILL)
    right.Paint = function() end

    local detailsCard = createCard(left, "Group Details", scale(306))
    local _, tokenEntry = createLabeledEntry(detailsCard, "Group Token", "@rare_medical")
    local _, labelEntry = createLabeledEntry(detailsCard, "Display Label", "Rare Medical")
    local _, descriptionEntry = createLabeledTextArea(detailsCard, "Description", "Used in loot tables as a reusable random pool.", 102)
    page.tokenEntry = tokenEntry
    page.labelEntry = labelEntry
    page.descriptionEntry = descriptionEntry

    local detailHint = vgui.Create("DLabel", detailsCard)
    detailHint:Dock(BOTTOM)
    detailHint:SetTall(scale(38))
    detailHint:DockMargin(scale(12), scale(6), scale(12), scale(12))
    detailHint:SetFont(font(11, false))
    detailHint:SetTextColor(colorFor("Text"))
    detailHint:SetWrap(true)
    detailHint:SetText("Tip: save over @weapons, @ammo, @gear, etc. to override the existing group. Delete that override later to restore the default behavior.")

    local actionCard = createCard(left, "Actions", scale(182))
    local actionRow = vgui.Create("DPanel", actionCard)
    actionRow:Dock(FILL)
    actionRow:DockMargin(scale(12), scale(8), scale(12), scale(12))
    actionRow.Paint = function() end

    local saveGroupButton = createButton(actionRow, "Save Group", "Green")
    saveGroupButton:Dock(TOP)
    saveGroupButton:DockMargin(0, 0, 0, scale(8))

    local newGroupButton = createButton(actionRow, "New Group", "Orange")
    newGroupButton:Dock(TOP)
    newGroupButton:DockMargin(0, 0, 0, scale(8))

    local deleteGroupButton = createButton(actionRow, "Delete Or Reset Selected Group", "Red")
    deleteGroupButton:Dock(TOP)

    local catalogCard = createCard(left, "Catalog Browser", scale(590))
    local _, searchEntry = createLabeledEntry(catalogCard, "Search Members", "Search items or gear to add to this group")
    page.searchEntry = searchEntry

    local catalogList = vgui.Create("DListView", catalogCard)
    catalogList:Dock(FILL)
    catalogList:DockMargin(scale(12), scale(8), scale(12), scale(8))
    catalogList:SetMultiSelect(false)
    catalogList:AddColumn("Item")
    catalogList:AddColumn("Class")
    catalogList:AddColumn("Type")
    catalogList:AddColumn("Size")
    page.catalogList = catalogList

    local addMemberButton = createButton(catalogCard, "Add Selected Catalog Entry To Group", "Primary")
    addMemberButton:Dock(BOTTOM)
    addMemberButton:DockMargin(scale(12), 0, scale(12), scale(12))
    addMemberButton:SetTall(scale(32))

    local membersCard = createCard(right, "Group Members", scale(408))
    local memberInfoLabel = vgui.Create("DLabel", membersCard)
    memberInfoLabel:Dock(TOP)
    memberInfoLabel:SetTall(scale(22))
    memberInfoLabel:DockMargin(scale(12), scale(8), scale(12), 0)
    memberInfoLabel:SetFont(font(11, false))
    memberInfoLabel:SetTextColor(colorFor("Text"))
    memberInfoLabel:SetText("0 member classes in this group.")
    page.memberInfoLabel = memberInfoLabel

    local memberList = vgui.Create("DListView", membersCard)
    memberList:Dock(FILL)
    memberList:DockMargin(scale(12), scale(8), scale(12), scale(8))
    memberList:SetMultiSelect(false)
    memberList:AddColumn("Item")
    memberList:AddColumn("Class")
    memberList:AddColumn("Type")
    memberList:AddColumn("Size")
    page.memberList = memberList

    local removeMemberButton = createButton(membersCard, "Remove Selected Member", "Red")
    removeMemberButton:Dock(BOTTOM)
    removeMemberButton:DockMargin(scale(12), 0, scale(12), scale(12))
    removeMemberButton:SetTall(scale(32))

    local savedCard = createCard(right, "Saved Loot Groups", scale(594))
    local savedList = vgui.Create("DListView", savedCard)
    savedList:Dock(FILL)
    savedList:DockMargin(scale(12), scale(8), scale(12), scale(12))
    savedList:SetMultiSelect(false)
    savedList:AddColumn("Label")
    savedList:AddColumn("Token")
    savedList:AddColumn("Members")
    savedList:AddColumn("Source")
    savedList:AddColumn("Description")
    page.savedList = savedList

    labelEntry.OnValueChange = function()
        if string.Trim(tostring(tokenEntry:GetValue() or "")) == "" then
            local lib = getWorldLootLib()
            if lib and lib.NormalizeLootGroupToken then
                tokenEntry:SetText(lib.NormalizeLootGroupToken(labelEntry:GetValue()))
            end
        end
    end

    searchEntry.OnChange = function()
        populateGroupCatalogList(page)
    end

    catalogList.OnRowSelected = function(_, _, line)
        page.selectedCatalogClass = line and line._class or nil
    end

    memberList.OnRowSelected = function(_, _, line)
        page.selectedMemberIndex = line and line._memberIndex or nil
    end

    savedList.OnRowSelected = function(_, _, line)
        if not line then return end
        fillLootGroupEditor(page, line._token, line._def)
        setStatus("Loaded loot group into the editor.")
    end

    addMemberButton.DoClick = function()
        if not page.selectedCatalogClass then
            setStatus("Pick a catalog item first.")
            return
        end

        local itemClass = tostring(page.selectedCatalogClass)
        for _, class in ipairs(page.groupClasses) do
            if class == itemClass then
                setStatus("That class is already in this loot group.")
                return
            end
        end

        page.groupClasses[#page.groupClasses + 1] = itemClass
        table.sort(page.groupClasses)
        page.selectedMemberIndex = nil
        populateGroupMemberList(page)
        setStatus("Added the selected catalog item to this loot group.")
    end

    removeMemberButton.DoClick = function()
        if not page.selectedMemberIndex then
            setStatus("Select a member row to remove.")
            return
        end

        table.remove(page.groupClasses, page.selectedMemberIndex)
        page.selectedMemberIndex = nil
        populateGroupMemberList(page)
        setStatus("Removed the selected class from this loot group.")
    end

    saveGroupButton.DoClick = function()
        local lib = getWorldLootLib()
        if not lib then
            setStatus("World loot library is not ready yet.")
            return
        end

        local payload = buildLootGroupPayload(page)
        if not payload then return end

        page.selectedGroupToken = tostring(payload.token or "")
        page.groupClasses = cloneStringList(payload.classes)
        if sendWorldLootAction(lib.ACTION_REGISTER_LOOT_GROUP, payload) then
            setStatus("Sent the loot-group save to the server.")
        end
    end

    newGroupButton.DoClick = function()
        clearLootGroupEditor(page)
        setStatus("Cleared the loot-group editor for a new definition.")
    end

    deleteGroupButton.DoClick = function()
        local lib = getWorldLootLib()
        if not lib then
            setStatus("World loot library is not ready yet.")
            return
        end

        local token = page.selectedGroupToken ~= "" and page.selectedGroupToken or lib.NormalizeLootGroupToken(page.tokenEntry:GetValue())
        if token == "" then
            setStatus("Select a saved loot group or enter its token first.")
            return
        end

        if sendWorldLootAction(lib.ACTION_UNREGISTER_LOOT_GROUP, { token = token }) then
            setStatus("Sent the loot-group delete/reset request to the server.")
        end
    end

    page.Refresh = function()
        populateGroupCatalogList(page)
        populateGroupMemberList(page)
        populateSavedGroupList(page)
    end

    page.ApplyFocus = function(focus)
        if not istable(focus) then return end
        local lib = getWorldLootLib()
        if not lib then return end

        local token = lib.NormalizeLootGroupToken(focus.group_token or focus.token)
        if token ~= "" and lib.IsLootGroupToken and lib.IsLootGroupToken(token) then
            fillLootGroupEditor(page, token)
        end
    end

    populateGroupCatalogList(page)
    populateGroupMemberList(page)
    populateSavedGroupList(page)

    return page
end

local function switchPage(name)
    ACTIVE_PAGE = name or ACTIVE_PAGE or "model"
    if not IsValid(MENU_FRAME) or not istable(MENU_FRAME.Pages) then return end

    for pageName, page in pairs(MENU_FRAME.Pages) do
        if page and page.page and page.page.SetVisible then
            page.page:SetVisible(pageName == ACTIVE_PAGE)
        end
        if page and page.Button and page.Button.SetColor then
            page.Button:SetColor(colorFor(pageName == ACTIVE_PAGE and "Primary" or "Orange"))
        end
    end
end

local function applyFocus(focus)
    if not istable(focus) then return end

    if focus.page == "placed" or focus.page == "model" or focus.page == "valuable" or focus.page == "groups" then
        switchPage(focus.page)
    end

    local active = IsValid(MENU_FRAME) and MENU_FRAME.Pages and MENU_FRAME.Pages[ACTIVE_PAGE] or nil
    if active and active.ApplyFocus then
        active.ApplyFocus(focus)
    end
end

local function refreshAllPages()
    if not IsValid(MENU_FRAME) or not istable(MENU_FRAME.Pages) then return end
    for _, page in pairs(MENU_FRAME.Pages) do
        if page and page.Refresh then
            page.Refresh()
        end
    end
end

local function openMenu(focus)
    if not isAdminLike(LocalPlayer()) then return end

    if IsValid(MENU_FRAME) then
        MENU_FRAME:MakePopup()
        MENU_FRAME:Center()
        refreshAllPages()
        applyFocus(focus)
        return
    end

    local frame = vgui.Create(chooseClass("Nexus:Frame", "DFrame"))
    frame:SetSize(
        math.min(ScrW() - scale(24), math.max(1180, math.floor(ScrW() * 0.94))),
        math.min(ScrH() - scale(24), math.max(760, math.floor(ScrH() * 0.92)))
    )
    if frame.SetSizable then
        frame:SetSizable(true)
    end
    frame:Center()
    if frame.SetTitle then
        frame:SetTitle("ZScav Loot Authoring")
    else
        frame.Title = "ZSCAV LOOT AUTHORING"
    end
    frame:MakePopup()
    frame.Pages = {}
    MENU_FRAME = frame

    local header = vgui.Create("DPanel", frame)
    header:Dock(TOP)
    header:SetTall(scale(72))
    header:DockMargin(scale(12), 0, scale(12), scale(10))
    header.Paint = function(_, w, h)
        draw.RoundedBox(scale(8), 0, 0, w, h, colorFor("Secondary"))
    end

    local title = vgui.Create("DLabel", header)
    title:Dock(TOP)
    title:DockMargin(scale(14), scale(10), scale(14), 0)
    title:SetTall(scale(24))
    title:SetFont(font(17, true))
    title:SetTextColor(colorFor("Text"))
    title:SetText("Model-based world loot profiles for ZScav")

    local subtitle = vgui.Create("DLabel", header)
    subtitle:Dock(FILL)
    subtitle:DockMargin(scale(14), 0, scale(14), scale(10))
    subtitle:SetWrap(true)
    subtitle:SetFont(font(12, false))
    subtitle:SetTextColor(colorFor("Text"))
    subtitle:SetText("Use `zscav_loot_gui`, `zscav_loot_menu`, `zc_loot_gui`, or chat aliases like `!zloot` to reopen this menu. Model profiles and prop valuables write back into the live ZScav catalog and world-loot state.")

    local nav = vgui.Create("DPanel", frame)
    nav:Dock(TOP)
    nav:SetTall(scale(40))
    nav:DockMargin(scale(12), 0, scale(12), scale(10))
    nav.Paint = function() end

    local body = vgui.Create("DPanel", frame)
    body:Dock(FILL)
    body:DockMargin(scale(12), 0, scale(12), scale(10))
    body.Paint = function(_, w, h)
        draw.RoundedBox(scale(8), 0, 0, w, h, colorFor("Background"))
    end

    local statusBar = vgui.Create("DPanel", frame)
    statusBar:Dock(BOTTOM)
    statusBar:SetTall(scale(36))
    statusBar:DockMargin(scale(12), 0, scale(12), scale(12))
    statusBar.Paint = function(_, w, h)
        draw.RoundedBox(scale(8), 0, 0, w, h, colorFor("Secondary"))
    end

    local statusLabel = vgui.Create("DLabel", statusBar)
    statusLabel:Dock(FILL)
    statusLabel:DockMargin(scale(12), 0, scale(12), 0)
    statusLabel:SetFont(font(12, false))
    statusLabel:SetTextColor(colorFor("Text"))
    statusLabel:SetText("Ready.")
    frame.StatusLabel = statusLabel

    local function addPageButton(pageName, text)
        local button = createButton(nav, text, pageName == ACTIVE_PAGE and "Primary" or "Orange")
        button:Dock(LEFT)
        button:SetWide(scale(170))
        button:DockMargin(0, 0, scale(8), 0)
        button.DoClick = function()
            switchPage(pageName)
        end
        return button
    end

    frame.Pages.model = buildContainerPage(body, "model")
    frame.Pages.placed = buildContainerPage(body, "placed")
    frame.Pages.valuable = buildValuablePage(body)
    frame.Pages.groups = buildLootGroupPage(body)

    frame.Pages.model.Button = addPageButton("model", "Model Containers")
    frame.Pages.placed.Button = addPageButton("placed", "Placed Spawns")
    frame.Pages.valuable.Button = addPageButton("valuable", "Prop Valuables")
    frame.Pages.groups.Button = addPageButton("groups", "Loot Groups")

    frame.OnRemove = function()
        hook.Remove("ZScavWorldLoot_ClientUpdated", MENU_HOOK_ID)
        MENU_FRAME = nil
    end

    hook.Add("ZScavWorldLoot_ClientUpdated", MENU_HOOK_ID, function()
        refreshAllPages()
    end)

    refreshAllPages()
    switchPage(ACTIVE_PAGE)
    applyFocus(focus)
end

net.Receive(OPEN_NET, function()
    local focus = util.JSONToTable(net.ReadString() or "{}") or {}
    openMenu(focus)
end)