-- cl_zrp_loot_editor.lua — ZRP Staff Loot & Container Editor panel.
-- Opened via the server command zrp_open_editor (admin only).

if SERVER then return end

-- ── Client loot state (received from server) ──────────────────────────────────

local ZRP_CL = {
    lootData   = { global = { items = {}, blacklist = {}, whitelist = {} }, profiles = {} },
    containers = {},
    worldData  = { scanned = {}, adopted = {} },  -- populated by ZRP_WorldPropSync
    panel      = nil,  -- active VGUI panel
}

-- Expose a read-only accessor so other client panels (e.g. event mode
-- container manager in cl_event.lua) can surface the same scanned/adopted
-- world prop list without duplicating the net plumbing.
function _G.ZRP_GetWorldData()
    return ZRP_CL.worldData or { scanned = {}, adopted = {} }
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function IsAdmin()
    return IsValid(LocalPlayer()) and LocalPlayer():IsAdmin()
end

local function SendContainerSetActive(id, enabled)
    id = tonumber(id)
    if not id then return end
    net.Start("ZRP_ContainerSetActive")
    net.WriteUInt(math.max(0, math.floor(id)), 16)
    net.WriteBool(enabled and true or false)
    net.SendToServer()
end

local function SendContainerActivate(id)
    id = tonumber(id)
    if not id then return end
    net.Start("ZRP_ContainerActivate")
    net.WriteUInt(math.max(0, math.floor(id)), 16)
    net.SendToServer()
end

local function SendContainerSyncRequest()
    net.Start("ZRP_ContainerRequestSync")
    net.SendToServer()
end

local function GuessLootCategory(cls)
    cls = string.lower(cls or "")
    if cls == "" then return "Other" end

    if string.find(cls, "attachment", 1, true) or string.StartWith(cls, "att_") then
        return "Attachments"
    end
    if string.StartWith(cls, "ent_armor_") or string.find(cls, "armor", 1, true) or string.find(cls, "helmet", 1, true) or string.find(cls, "vest", 1, true) then
        return "Armor"
    end
    if string.StartWith(cls, "ent_ammo_") or string.find(cls, "ammo", 1, true) then
        return "Ammo"
    end
    if string.find(cls, "cloth", 1, true) or string.find(cls, "outfit", 1, true) or string.find(cls, "jacket", 1, true) or string.find(cls, "pants", 1, true) or string.find(cls, "shirt", 1, true) then
        return "Clothes"
    end
    if string.find(cls, "bandage", 1, true) or string.find(cls, "med", 1, true) or string.find(cls, "pain", 1, true) or string.find(cls, "blood", 1, true) or string.find(cls, "tourniquet", 1, true) or string.find(cls, "afak", 1, true) then
        return "Medical"
    end
    if string.StartWith(cls, "weapon_") then
        return "Weapons"
    end
    if string.StartWith(cls, "ent_") then
        return "Entities"
    end

    return "Other"
end

local function BuildLootRegistry(lootData)
    local cats = {
        Weapons = {}, Armor = {}, Ammo = {}, Attachments = {},
        Clothes = {}, Entities = {}, Medical = {}, Other = {}
    }
    local seen = {}

    local function addClass(cls, forcedCategory)
        cls = string.lower(string.Trim(tostring(cls or "")))
        if cls == "" or seen[cls] then return end
        seen[cls] = true
        local cat = forcedCategory or GuessLootCategory(cls)
        if not cats[cat] then cat = "Other" end
        cats[cat][#cats[cat] + 1] = cls
    end

    for _, w in ipairs(weapons.GetList() or {}) do
        local cls = w.ClassName or w.Classname or w.class or w.PrintName
        if isstring(cls) and string.StartWith(string.lower(cls), "weapon_") then
            addClass(cls, "Weapons")
        end
    end

    for className, _ in pairs(scripted_ents.GetList() or {}) do
        addClass(className)
    end

    for _, entry in ipairs((lootData and lootData.items) or {}) do
        addClass(entry[2])
    end

    if ZRP and ZRP.DEFAULT_LOOT_TABLE then
        for _, entry in ipairs(ZRP.DEFAULT_LOOT_TABLE) do
            addClass(entry[2])
        end
    end

    for _, list in pairs(cats) do
        table.sort(list)
    end

    return cats
end

local function GetGlobalLootData()
    return ZRP_CL.lootData.global or { items = {}, blacklist = {}, whitelist = {} }
end

local function GetLootProfiles()
    return ZRP_CL.lootData.profiles or {}
end

local function NormalizeLootDataClient(data)
    data = data or {}

    local out = {
        items = {},
        blacklist = {},
        whitelist = {},
    }

    for _, entry in ipairs(data.items or {}) do
        local weight = math.Clamp(tonumber(entry[1]) or 0, 1, 255)
        local cls = string.lower(string.Trim(tostring(entry[2] or "")))
        if cls ~= "" then
            out.items[#out.items + 1] = { weight, cls }
        end
    end

    for cls, state in pairs(data.blacklist or {}) do
        cls = string.lower(string.Trim(tostring(cls or "")))
        if state and cls ~= "" then
            out.blacklist[cls] = true
        end
    end

    for cls, state in pairs(data.whitelist or {}) do
        cls = string.lower(string.Trim(tostring(cls or "")))
        if state and cls ~= "" then
            out.whitelist[cls] = true
        end
    end

    return out
end

local function ParseLootTarget(target)
    local raw = string.lower(string.Trim(tostring(target or "")))
    if raw == "" then return "global", nil end

    if string.StartWith(raw, "container:") then
        local id = tonumber(string.sub(raw, 11))
        return "container", id
    end

    if string.StartWith(raw, "model:") then
        return "model", string.sub(raw, 7)
    end

    return "model", raw
end

local function GetContainerById(id)
    id = tonumber(id)
    if not id then return nil end

    for _, cfg in ipairs(ZRP_CL.containers or {}) do
        if tonumber(cfg.id) == id then
            return cfg
        end
    end

    return nil
end

local function BuildEffectiveLootItemsFromData(data, fallbackItems)
    data = NormalizeLootDataClient(data)
    local base = (#data.items > 0) and data.items or (fallbackItems or {})
    local out = {}
    local hasWhitelist = next(data.whitelist or {}) ~= nil

    for _, entry in ipairs(base) do
        local cls = string.lower(string.Trim(tostring(entry[2] or "")))
        if cls == "" then continue end
        if hasWhitelist and not data.whitelist[cls] then continue end
        if data.blacklist[cls] then continue end
        out[#out + 1] = { math.Clamp(tonumber(entry[1]) or 0, 1, 255), cls }
    end

    return out
end

local function GetLootDataForTarget(target)
    local targetType, targetValue = ParseLootTarget(target)

    if targetType == "global" then
        return NormalizeLootDataClient(GetGlobalLootData())
    end

    if targetType == "container" then
        local cfg = GetContainerById(targetValue)
        return NormalizeLootDataClient((cfg and cfg.lootData) or nil)
    end

    local model = string.lower(string.Trim(tostring(targetValue or "")))
    return NormalizeLootDataClient(GetLootProfiles()[model] or nil)
end

local function GetEffectiveLootItemsForTarget(target)
    local defaults = BuildEffectiveLootItemsFromData({ items = (ZRP and ZRP.DEFAULT_LOOT_TABLE) or {} }, nil)
    local globalEffective = BuildEffectiveLootItemsFromData(GetGlobalLootData(), defaults)

    local targetType, targetValue = ParseLootTarget(target)
    if targetType == "global" then
        return globalEffective
    end

    if targetType == "model" then
        local modelData = GetLootProfiles()[string.lower(string.Trim(tostring(targetValue or "")))]
        return BuildEffectiveLootItemsFromData(modelData, globalEffective)
    end

    local cfg = GetContainerById(targetValue)
    local model = cfg and string.lower(string.Trim(tostring(cfg.model or ""))) or ""
    local modelData = model ~= "" and GetLootProfiles()[model] or nil
    local modelEffective = BuildEffectiveLootItemsFromData(modelData, globalEffective)
    return BuildEffectiveLootItemsFromData(cfg and cfg.lootData or nil, modelEffective)
end

local function GetLootTargets()
    local targets = {
        { label = "Global Loot Table", value = "" },
    }

    local seenModels = {}
    local function addModelTarget(model)
        model = string.lower(string.Trim(tostring(model or "")))
        if model == "" or seenModels[model] then return end
        seenModels[model] = true
        targets[#targets + 1] = {
            label = "Model: " .. model,
            value = "model:" .. model,
        }
    end

    for model, _ in pairs(GetLootProfiles()) do
        addModelTarget(model)
    end

    for _, cfg in ipairs(ZRP_CL.containers or {}) do
        addModelTarget(cfg.model)
    end

    for _, entry in ipairs((ZRP_CL.worldData and ZRP_CL.worldData.scanned) or {}) do
        addModelTarget(entry.model)
    end

    for _, entry in ipairs((ZRP_CL.worldData and ZRP_CL.worldData.adopted) or {}) do
        addModelTarget(entry.model)
    end

    table.sort(targets, function(a, b)
        return string.lower(a.label) < string.lower(b.label)
    end)

    table.sort(ZRP_CL.containers or {}, function(a, b)
        return tonumber(a.id or 0) < tonumber(b.id or 0)
    end)

    for _, cfg in ipairs(ZRP_CL.containers or {}) do
        targets[#targets + 1] = {
            label = string.format("Container #%d (%s)", tonumber(cfg.id) or 0, tostring(cfg.model or "?")),
            value = "container:" .. tostring(cfg.id or 0),
        }
    end

    return targets
end

-- ── Net receivers ──────────────────────────────────────────────────────────────

net.Receive("ZRP_LootSync", function()
    ZRP_CL.lootData = net.ReadTable() or { global = { items = {}, blacklist = {}, whitelist = {} }, profiles = {} }
    -- Refresh panel if open.
    if IsValid(ZRP_CL.panel) and ZRP_CL.panel.RefreshLoot then
        ZRP_CL.panel:RefreshLoot()
    end
end)

net.Receive("ZRP_ContainerSync", function()
    ZRP_CL.containers = net.ReadTable() or {}
    if IsValid(ZRP_CL.panel) and ZRP_CL.panel.RefreshContainers then
        ZRP_CL.panel:RefreshContainers()
    end
end)

net.Receive("ZRP_WorldPropSync", function()
    ZRP_CL.worldData = net.ReadTable() or { scanned = {}, adopted = {} }
    if IsValid(ZRP_CL.panel) and ZRP_CL.panel.RefreshWorld then
        ZRP_CL.panel:RefreshWorld()
    end
    -- Notify other panels (e.g. event mode container manager) that scan data
    -- has changed. They can read ZRP_CL.worldData directly.
    hook.Run("ZRP_WorldDataUpdated", ZRP_CL.worldData)
end)

net.Receive("ZRP_OpenEditor", function()
    if not IsAdmin() then return end
    ZRP_CL.OpenEditor()
end)

-- ── Panel builder ─────────────────────────────────────────────────────────────

function ZRP_CL.OpenEditor()
    if IsValid(ZRP_CL.panel) then ZRP_CL.panel:Remove() end

    local PANEL_W, PANEL_H = 800, 560
    local sw, sh = ScrW(), ScrH()

    local frame = vgui.Create("DFrame")
    frame:SetTitle("ZRP Loot & Container Editor")
    frame:SetSize(PANEL_W, PANEL_H)
    frame:SetPos(sw * 0.5 - PANEL_W * 0.5, sh * 0.5 - PANEL_H * 0.5)
    frame:SetDraggable(true)
    frame:MakePopup()
    ZRP_CL.panel = frame

    -- ── Tab sheet ──────────────────────────────────────────────────────────────
    local tabs = vgui.Create("DPropertySheet", frame)
    tabs:Dock(FILL)
    tabs:DockMargin(4, 0, 4, 4)

    -- ┌─────────────────────────────────────────────────────────────────────────┐
    -- │  Tab 1: Loot Table                                                      │
    -- └─────────────────────────────────────────────────────────────────────────┘
    local lootPanel = vgui.Create("DPanel")
    lootPanel:SetPaintBackground(false)
    tabs:AddSheet("Loot Table", lootPanel, "icon16/package.png")

    local selectedLootTarget = ""
    local lootRegistry = BuildLootRegistry(GetLootDataForTarget(selectedLootTarget))

    local selectorWrap = vgui.Create("DPanel", lootPanel)
    selectorWrap:Dock(TOP)
    selectorWrap:SetTall(224)
    selectorWrap:DockMargin(0, 4, 0, 4)
    selectorWrap:SetPaintBackground(false)

    local topBar = vgui.Create("DPanel", selectorWrap)
    topBar:Dock(TOP)
    topBar:SetTall(24)
    topBar:SetPaintBackground(false)

    local weightLbl = vgui.Create("DLabel", topBar)
    weightLbl:Dock(LEFT)
    weightLbl:SetWide(95)
    weightLbl:SetText("Spawn Weight:")

    local weightEntry = vgui.Create("DTextEntry", topBar)
    weightEntry:Dock(LEFT)
    weightEntry:SetWide(60)
    weightEntry:DockMargin(0, 0, 6, 0)
    weightEntry:SetPlaceholderText("wt")
    weightEntry:SetValue("5")

    local targetLbl = vgui.Create("DLabel", topBar)
    targetLbl:Dock(LEFT)
    targetLbl:SetWide(75)
    targetLbl:SetText("Edit Target:")

    local targetCombo = vgui.Create("DComboBox", topBar)
    targetCombo:Dock(LEFT)
    targetCombo:SetWide(260)
    targetCombo:DockMargin(0, 0, 6, 0)

    local refreshScanBtn = vgui.Create("DButton", topBar)
    refreshScanBtn:Dock(LEFT)
    refreshScanBtn:SetWide(120)
    refreshScanBtn:SetText("Refresh Lists")

    local resetBtn = vgui.Create("DButton", topBar)
    resetBtn:Dock(RIGHT)
    resetBtn:SetWide(110)
    resetBtn:SetText("Reset Target")
    resetBtn:DockMargin(4, 0, 0, 0)
    resetBtn.DoClick = function()
        local target = selectedLootTarget or ""
        if target == "" then
            RunConsoleCommand("zrp_loot_reset_target")
        else
            RunConsoleCommand("zrp_loot_reset_target", target)
        end
    end

    local selectorRows = vgui.Create("DPanel", selectorWrap)
    selectorRows:Dock(TOP)
    selectorRows:SetTall(170)
    selectorRows:SetPaintBackground(false)

    local categoryOrder = {
        "Weapons", "Armor", "Ammo", "Attachments", "Clothes", "Entities", "Medical", "Other"
    }
    local categoryCombos = {}

    local function AddLootClass(cls)
        local wt = tonumber(string.Trim(weightEntry:GetValue())) or 5
        cls = string.Trim(cls or "")
        if cls == "" then return end
        net.Start("ZRP_LootAdd")
        net.WriteString(cls)
        net.WriteUInt(math.Clamp(wt, 1, 255), 8)
        net.WriteString(selectedLootTarget or "")
        net.SendToServer()
    end

    local function SetSelectedLootTarget(targetValue)
        selectedLootTarget = string.Trim(tostring(targetValue or ""))
        if selectedLootTarget == "" then
            targetCombo:SetValue("Global Loot Table")
            return
        end
        targetCombo:SetValue(selectedLootTarget)
    end

    local function RefillLootTargets()
        local previous = selectedLootTarget or ""
        targetCombo:Clear()
        for _, entry in ipairs(GetLootTargets()) do
            targetCombo:AddChoice(entry.label, entry.value)
        end

        SetSelectedLootTarget(previous)
    end

    local function RefillCategoryCombos()
        lootRegistry = BuildLootRegistry(GetLootDataForTarget(selectedLootTarget))

        for _, cat in ipairs(categoryOrder) do
            local combo = categoryCombos[cat]
            if IsValid(combo) then
                combo:Clear()
                combo.ZRP_SelectedClass = nil
                combo:SetValue(cat .. " (" .. #(lootRegistry[cat] or {}) .. ")")

                for _, cls in ipairs(lootRegistry[cat] or {}) do
                    combo:AddChoice(cls, cls)
                end
            end
        end
    end

    targetCombo.OnSelect = function(_, _, value, data)
        selectedLootTarget = data or ""
        targetCombo:SetValue(value)
        if lootPanel.RefreshLoot then
            lootPanel:RefreshLoot()
        end
    end

    local function AddCategoryRow(cat)
        local row = vgui.Create("DPanel", selectorRows)
        row:Dock(TOP)
        row:SetTall(20)
        row:DockMargin(0, 0, 0, 2)
        row:SetPaintBackground(false)

        local lbl = vgui.Create("DLabel", row)
        lbl:Dock(LEFT)
        lbl:SetWide(90)
        lbl:SetText(cat .. ":")

        local combo = vgui.Create("DComboBox", row)
        combo:Dock(LEFT)
        combo:SetWide(510)
        combo.ZRP_SelectedClass = nil
        combo.OnSelect = function(_, _, _, data)
            combo.ZRP_SelectedClass = data
        end
        categoryCombos[cat] = combo

        local addBtn = vgui.Create("DButton", row)
        addBtn:Dock(RIGHT)
        addBtn:SetWide(80)
        addBtn:SetText("Add")
        addBtn.DoClick = function()
            AddLootClass(combo.ZRP_SelectedClass)
        end
    end

    for _, cat in ipairs(categoryOrder) do
        AddCategoryRow(cat)
    end

    refreshScanBtn.DoClick = function()
        RefillLootTargets()
        RefillCategoryCombos()
    end

    RefillLootTargets()
    RefillCategoryCombos()

    -- Manual class add row (still supports any arbitrary class).
    local addRow = vgui.Create("DPanel", lootPanel)
    addRow:Dock(TOP)
    addRow:SetTall(30)
    addRow:DockMargin(0, 0, 0, 4)
    addRow:SetPaintBackground(false)

    local classEntry = vgui.Create("DTextEntry", addRow)
    classEntry:Dock(LEFT)
    classEntry:SetWide(430)
    classEntry:DockMargin(0, 0, 4, 0)
    classEntry:SetPlaceholderText("manual class add  e.g. weapon_glock18c")

    local addBtn = vgui.Create("DButton", addRow)
    addBtn:Dock(LEFT)
    addBtn:SetWide(140)
    addBtn:SetText("Add Manual Class")
    addBtn.DoClick = function()
        AddLootClass(classEntry:GetValue())
    end

    -- Loot list.
    local list = vgui.Create("DListView", lootPanel)
    list:Dock(FILL)
    list:SetMultiSelect(false)
    list:AddColumn("Weight"):SetWidth(60)
    list:AddColumn("Class"):SetWidth(270)
    list:AddColumn("Blacklist"):SetWidth(70)
    list:AddColumn("Whitelist"):SetWidth(70)
    list:AddColumn(""):SetWidth(60)

    local function RefreshLoot()
        local targetLootData = GetLootDataForTarget(selectedLootTarget)
        list:Clear()
        RefillLootTargets()
        RefillCategoryCombos()
        for i, entry in ipairs(targetLootData.items) do
            local cls = entry[2]
            local wt  = entry[1]
            local bl  = targetLootData.blacklist[cls] and "YES" or "-"
            local wl  = targetLootData.whitelist[cls] and "YES" or "-"
            local ln  = list:AddLine(tostring(wt), cls, bl, wl, "[X]")
            ln.ZRP_Idx = i
            ln.ZRP_Cls = cls
        end
        -- Also show default items (greyed) if no custom items loaded.
        if #targetLootData.items == 0 then
            local effectiveItems = GetEffectiveLootItemsForTarget(selectedLootTarget)
            for _, entry in ipairs(effectiveItems) do
                local suffix = (selectedLootTarget == "") and "  (default/effective)" or "  (inherited/effective)"
                local ln = list:AddLine(tostring(entry[1]), entry[2] .. suffix, "-", "-", "")
                ln:SetEnabled(false)
            end
        end
    end
    lootPanel.RefreshLoot = RefreshLoot

    list.OnRowSelected = function(_, _, row)
        if not row.ZRP_Idx then return end
        -- Right-click menu handled below.
    end

    list.OnRowRightClick = function(_, idx, row)
        if not row.ZRP_Idx then return end
        local menu = DermaMenu()
        local targetLootData = GetLootDataForTarget(selectedLootTargetModel)

        menu:AddOption("Toggle Blacklist", function()
            local cur = targetLootData.blacklist[row.ZRP_Cls]
            net.Start("ZRP_LootSetBlacklist")
            net.WriteString(row.ZRP_Cls)
            net.WriteBool(not cur)
            net.WriteString(selectedLootTarget or "")
            net.SendToServer()
        end)

        menu:AddOption("Toggle Whitelist", function()
            local cur = targetLootData.whitelist[row.ZRP_Cls]
            net.Start("ZRP_LootSetWhitelist")
            net.WriteString(row.ZRP_Cls)
            net.WriteBool(not cur)
            net.WriteString(selectedLootTarget or "")
            net.SendToServer()
        end)

        menu:AddSpacer()

        menu:AddOption("Set Weight…", function()
            Derma_StringRequest(
                "Set Weight",
                "Enter new weight for " .. row.ZRP_Cls .. ":",
                tostring(targetLootData.items[row.ZRP_Idx] and targetLootData.items[row.ZRP_Idx][1] or 5),
                function(txt)
                    local w = tonumber(txt)
                    if not w then return end
                    net.Start("ZRP_LootSetWeight")
                    net.WriteUInt(row.ZRP_Idx, 16)
                    net.WriteUInt(math.Clamp(w, 1, 255), 8)
                    net.WriteString(selectedLootTarget or "")
                    net.SendToServer()
                end
            )
        end)

        menu:AddSpacer()

        menu:AddOption("Remove Item", function()
            net.Start("ZRP_LootRemove")
            net.WriteUInt(row.ZRP_Idx, 16)
            net.WriteString(selectedLootTarget or "")
            net.SendToServer()
        end)

        menu:Open()
    end

    RefreshLoot()

    -- ┌─────────────────────────────────────────────────────────────────────────┐
    -- │  Tab 2: Containers                                                      │
    -- └─────────────────────────────────────────────────────────────────────────┘
    local contPanel = vgui.Create("DPanel")
    contPanel:SetPaintBackground(false)
    tabs:AddSheet("Containers", contPanel, "icon16/box.png")

    local infoLbl = vgui.Create("DLabel", contPanel)
    infoLbl:Dock(TOP)
    infoLbl:SetTall(24)
    infoLbl:SetText("  Use the ZRP LootEditor tool (Toolgun) to place containers. Select one below for quick actions.")
    infoLbl:DockMargin(0, 4, 0, 4)
    infoLbl:SetFont("DermaDefault")
    infoLbl:SetTextColor(Color(180, 180, 180))

    local actionBar = vgui.Create("DPanel", contPanel)
    actionBar:Dock(TOP)
    actionBar:SetTall(26)
    actionBar:SetPaintBackground(false)
    actionBar:DockMargin(0, 0, 0, 4)

    local statusLbl = vgui.Create("DLabel", actionBar)
    statusLbl:Dock(RIGHT)
    statusLbl:SetWide(280)
    statusLbl:SetTextColor(Color(170, 200, 170))
    statusLbl:SetContentAlignment(6)
    statusLbl:SetText("No container selected")

    local refreshBtn = vgui.Create("DButton", actionBar)
    refreshBtn:Dock(LEFT)
    refreshBtn:SetWide(70)
    refreshBtn:SetText("Refresh")

    local enableBtn = vgui.Create("DButton", actionBar)
    enableBtn:Dock(LEFT)
    enableBtn:SetWide(60)
    enableBtn:SetText("Enable")
    enableBtn:DockMargin(4, 0, 0, 0)

    local disableBtn = vgui.Create("DButton", actionBar)
    disableBtn:Dock(LEFT)
    disableBtn:SetWide(60)
    disableBtn:SetText("Disable")
    disableBtn:DockMargin(4, 0, 0, 0)

    local activateBtn = vgui.Create("DButton", actionBar)
    activateBtn:Dock(LEFT)
    activateBtn:SetWide(90)
    activateBtn:SetText("Activate Now")
    activateBtn:DockMargin(4, 0, 0, 0)

    local editLootBtn = vgui.Create("DButton", actionBar)
    editLootBtn:Dock(LEFT)
    editLootBtn:SetWide(95)
    editLootBtn:SetText("Edit Loot")
    editLootBtn:DockMargin(4, 0, 0, 0)

    local removeBtn = vgui.Create("DButton", actionBar)
    removeBtn:Dock(LEFT)
    removeBtn:SetWide(65)
    removeBtn:SetText("Remove")
    removeBtn:DockMargin(4, 0, 0, 0)

    local clist = vgui.Create("DListView", contPanel)
    clist:Dock(FILL)
    clist:SetMultiSelect(false)
    clist:AddColumn("ID"):SetWidth(40)
    clist:AddColumn("Model"):SetWidth(280)
    clist:AddColumn("Position"):SetWidth(180)
    clist:AddColumn("Delay"):SetWidth(70)
    clist:AddColumn("State"):SetWidth(80)

    local function RefreshContainers()
        clist:Clear()
        for _, cfg in ipairs(ZRP_CL.containers) do
            local pos = cfg.pos and
                string.format("%.0f, %.0f, %.0f", cfg.pos[1], cfg.pos[2], cfg.pos[3]) or "?"
            local ln = clist:AddLine(
                tostring(cfg.id),
                cfg.model or "?",
                pos,
                cfg.respawnDelay and tostring(cfg.respawnDelay) .. "s" or "default",
                (cfg.enabled == false and "Disabled") or (cfg.active and "Active" or "Inactive")
            )
            ln.ZRP_CID = cfg.id
            ln.ZRP_Enabled = (cfg.enabled ~= false)
        end
        RefillLootTargets()
        statusLbl:SetText("Container list refreshed")
    end
    contPanel.RefreshContainers = RefreshContainers

    local function GetSelectedContainerRow()
        local lineId = clist:GetSelectedLine()
        if not lineId then return nil end
        local row = clist:GetLine(lineId)
        if not IsValid(row) or not row.ZRP_CID then return nil end
        return row
    end

    local function GetSelectedContainerIdOrWarn(actionName)
        local row = GetSelectedContainerRow()
        if not row then
            statusLbl:SetText("Select a container first")
            notification.AddLegacy("[ZRP] Select a container first for " .. actionName .. ".", NOTIFY_HINT, 3)
            return nil
        end
        statusLbl:SetText("Container #" .. row.ZRP_CID .. " selected")
        return row.ZRP_CID, row
    end

    refreshBtn.DoClick = function()
        SendContainerSyncRequest()
        statusLbl:SetText("Requested server refresh")
    end

    enableBtn.DoClick = function()
        local id = GetSelectedContainerIdOrWarn("Enable")
        if not id then return end
        SendContainerSetActive(id, true)
        statusLbl:SetText("Enabling container #" .. id .. "...")
    end

    disableBtn.DoClick = function()
        local id = GetSelectedContainerIdOrWarn("Disable")
        if not id then return end
        SendContainerSetActive(id, false)
        statusLbl:SetText("Disabling container #" .. id .. "...")
    end

    activateBtn.DoClick = function()
        local id = GetSelectedContainerIdOrWarn("Activate")
        if not id then return end
        SendContainerActivate(id)
        statusLbl:SetText("Activating container #" .. id .. "...")
    end

    editLootBtn.DoClick = function()
        local id = GetSelectedContainerIdOrWarn("Edit Loot")
        if not id then return end
        SetSelectedLootTarget("container:" .. tostring(id))
        if lootPanel.RefreshLoot then
            lootPanel:RefreshLoot()
        end
        if tabs and tabs.Items and tabs.Items[1] and tabs.Items[1].Tab then
            tabs:SetActiveTab(tabs.Items[1].Tab)
        end
    end

    removeBtn.DoClick = function()
        local id = GetSelectedContainerIdOrWarn("Remove")
        if not id then return end
        Derma_Query(
            "Remove container #" .. id .. "?",
            "Confirm",
            "Yes", function()
                RunConsoleCommand("zrp_container_remove", tostring(id))
            end,
            "No", function() end
        )
    end

    clist.OnRowSelected = function(_, _, row)
        if not row or not row.ZRP_CID then return end
        statusLbl:SetText("Selected #" .. row.ZRP_CID .. (row.ZRP_Enabled and " (enabled)" or " (disabled)"))
    end

    clist.OnRowRightClick = function(_, _, row)
        if not row.ZRP_CID then return end
        local id = row.ZRP_CID
        local menu = DermaMenu()

        menu:AddOption("Set Respawn Delay…", function()
            Derma_StringRequest(
                "Set Respawn Delay",
                "Enter delay in seconds for container #" .. id .. ":",
                "900",
                function(txt)
                    local d = tonumber(txt)
                    if not d then return end
                    RunConsoleCommand("zrp_container_setdelay", tostring(id), tostring(math.max(1, d)))
                end
            )
        end)

        menu:AddSpacer()

        menu:AddOption(row.ZRP_Enabled and "Disable Container" or "Enable Container", function()
            SendContainerSetActive(id, not row.ZRP_Enabled)
        end)

        menu:AddOption("Activate / Reset Now", function()
            SendContainerActivate(id)
        end)

        menu:AddOption("Edit Loot Table", function()
            SetSelectedLootTarget("container:" .. tostring(id))
            if lootPanel.RefreshLoot then
                lootPanel:RefreshLoot()
            end
            if tabs and tabs.Items and tabs.Items[1] and tabs.Items[1].Tab then
                tabs:SetActiveTab(tabs.Items[1].Tab)
            end
        end)

        menu:AddSpacer()

        menu:AddOption("Remove Container", function()
            Derma_Query(
                "Remove container #" .. id .. "?",
                "Confirm",
                "Yes", function()
                    RunConsoleCommand("zrp_container_remove", tostring(id))
                end,
                "No", function() end
            )
        end)

        menu:Open()
    end

    RefreshContainers()

    -- ┌─────────────────────────────────────────────────────────────────────────┐
    -- │  Tab 3: World Props                                                     │
    -- │  Top half: scanned unadopted props.  Bottom half: adopted containers.   │
    -- └─────────────────────────────────────────────────────────────────────────┘
    local worldPanel = vgui.Create("DPanel")
    worldPanel:SetPaintBackground(false)
    tabs:AddSheet("World Props", worldPanel, "icon16/world.png")

    -- ── Scanned (top) ─────────────────────────────────────────────────────────
    local scanHdr = vgui.Create("DLabel", worldPanel)
    scanHdr:Dock(TOP)
    scanHdr:SetTall(20)
    scanHdr:DockMargin(2, 4, 0, 0)
    scanHdr:SetFont("DermaDefaultBold")
    scanHdr:SetTextColor(Color(160, 200, 230))
    scanHdr:SetText("  Scanned World Props  (match loot_boxes, not yet adopted)")

    local scanList = vgui.Create("DListView", worldPanel)
    scanList:Dock(TOP)
    scanList:SetTall(170)
    scanList:SetMultiSelect(false)
    scanList:AddColumn("EntIdx"):SetWidth(55)
    scanList:AddColumn("Model"):SetWidth(300)
    scanList:AddColumn("Position"):SetWidth(220)

    -- ── Adopted (bottom) ──────────────────────────────────────────────────────
    local adoptHdr = vgui.Create("DLabel", worldPanel)
    adoptHdr:Dock(TOP)
    adoptHdr:SetTall(20)
    adoptHdr:DockMargin(2, 6, 0, 0)
    adoptHdr:SetFont("DermaDefaultBold")
    adoptHdr:SetTextColor(Color(160, 200, 230))
    adoptHdr:SetText("  Adopted World Containers  (persistent; survive round restarts)")

    local adoptList = vgui.Create("DListView", worldPanel)
    adoptList:Dock(FILL)
    adoptList:SetMultiSelect(false)
    adoptList:AddColumn("ID"):SetWidth(38)
    adoptList:AddColumn("Model"):SetWidth(250)
    adoptList:AddColumn("Position"):SetWidth(160)
    adoptList:AddColumn("Delay"):SetWidth(60)
    adoptList:AddColumn("Looted"):SetWidth(55)

    local function RefreshWorld()
        scanList:Clear()
        for _, entry in ipairs(ZRP_CL.worldData.scanned or {}) do
            local pos = entry.pos and
                string.format("%.0f, %.0f, %.0f", entry.pos[1], entry.pos[2], entry.pos[3]) or "?"
            local ln = scanList:AddLine(
                tostring(entry.entindex or "?"),
                entry.model or "?",
                pos
            )
            ln.ZRP_EntIndex = entry.entindex
        end

        adoptList:Clear()
        for _, entry in ipairs(ZRP_CL.worldData.adopted or {}) do
            local pos = entry.pos and
                string.format("%.0f, %.0f, %.0f", entry.pos[1], entry.pos[2], entry.pos[3]) or "?"
            local ln = adoptList:AddLine(
                tostring(entry.idx or "?"),
                entry.model or "?",
                pos,
                entry.respawnDelay and (entry.respawnDelay .. "s") or "default",
                entry.looted and "Yes" or "No"
            )
            ln.ZRP_WorldIdx = entry.idx
        end
        RefillLootTargets()
    end
    worldPanel.RefreshWorld = RefreshWorld

    -- Right-click: adopt scanned prop.
    scanList.OnRowRightClick = function(_, _, row)
        if not row.ZRP_EntIndex then return end
        local menu = DermaMenu()
        menu:AddOption("Adopt as ZRP Container", function()
            RunConsoleCommand("zrp_adopt_worldprop", tostring(row.ZRP_EntIndex))
        end)
        menu:Open()
    end
    -- Double-click shortcut.
    scanList.OnRowSelected = function(_, _, row)
        if not row.ZRP_EntIndex then return end
        -- Selection only; double-click not needed since right-click is quick.
    end

    -- Right-click: manage adopted container.
    adoptList.OnRowRightClick = function(_, _, row)
        if not row.ZRP_WorldIdx then return end
        local id = row.ZRP_WorldIdx
        local menu = DermaMenu()

        menu:AddOption("Set Reset Delay…", function()
            Derma_StringRequest(
                "Set Reset Delay",
                "Seconds for world container #" .. id .. ":",
                "900",
                function(txt)
                    local d = tonumber(txt)
                    if not d then return end
                    RunConsoleCommand("zrp_worldprop_setdelay", tostring(id), tostring(math.max(1, d)))
                end
            )
        end)

        menu:AddSpacer()

        menu:AddOption("Remove Adoption", function()
            Derma_Query(
                "Remove world container #" .. id .. "?\nThe map prop will stay, but it will no longer give loot.",
                "Confirm",
                "Yes", function() RunConsoleCommand("zrp_remove_worldprop", tostring(id)) end,
                "No",  function() end
            )
        end)

        menu:Open()
    end

    RefreshWorld()

    -- ┌─────────────────────────────────────────────────────────────────────────┐
    -- │  Tab 4: Help                                                            │
    -- └─────────────────────────────────────────────────────────────────────────┘
    local helpPanel = vgui.Create("DPanel")
    helpPanel:SetPaintBackground(false)
    tabs:AddSheet("Help", helpPanel, "icon16/information.png")

    local helpText = vgui.Create("DTextEntry", helpPanel)
    helpText:Dock(FILL)
    helpText:DockMargin(4, 4, 4, 4)
    helpText:SetMultiline(true)
    helpText:SetEditable(false)
    helpText:SetFont("DermaDefaultBold")
    helpText:SetValue([[
ZRP — Persistent Survival / Roleplay Mode
==========================================

RESPAWN
  Players respawn 10 seconds after death at a random SAFE_SPAWN point.
  Place SAFE_SPAWN points using the Point Editor tool (ZBattle category).

LOOT TABLE
    Switch between the global loot table and per-model tables.
  • Add / remove items with this panel.
  • Blacklist: item never spawns.
  • Whitelist: ONLY whitelisted items spawn (when whitelist is non-empty).
  • Weights control spawn frequency (higher = more common).
    • "Reset Target" clears only the currently selected table.
    • Per-model tables inherit the global pool until you customize them.

ZRP CONTAINERS (Containers tab)
  Toolgun → ZBattle → ZRP LootEditor:
    LMB  — Place a new ZRP container entity at crosshair.
    RMB on a ZRP container  — Remove it.
  Containers saved per-map.  Persist across round restarts.

WORLD PROPS (World Props tab)
  Any existing map prop whose model matches the loot_boxes list can be
  adopted as a ZRP container — it stays in place and gives loot when [E] is used.
    Toolgun RMB on a world prop  — Adopt it instantly.
    "World Props" tab → right-click scanned prop → Adopt as ZRP Container.
    "World Props" tab → right-click adopted entry → Set Delay / Remove Adoption.
  Adopted world containers survive round restarts (saved per-map).

STARTING ZRP
  !zrpstart  or ULX force-mode to "zrp".
]])
end

-- ── Console command to open editor manually ───────────────────────────────────
concommand.Add("zrp_open_editor_cl", function()
    if not IsAdmin() then return end
    RunConsoleCommand("zrp_open_editor")
end)
