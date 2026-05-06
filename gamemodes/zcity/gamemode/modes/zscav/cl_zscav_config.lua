-- ZScav admin config menu (client). Triggered via concommand zscav_config
-- which is registered server-side; the server sends the current snapshot
-- and we let the admin tweak grid sizes / item w,h,weight, then apply.

local PANEL
local PENDING_FOCUS_CLASS
local PENDING_FOCUS_TAB

local function clampInt(n, lo, hi)
    n = tonumber(n) or 0
    n = math.floor(n + 0.5)
    if n < lo then n = lo end
    if n > hi then n = hi end
    return n
end

local function DrawGrid(pnl, w, h, title)
    surface.SetDrawColor(34, 34, 34, 255)
    surface.DrawRect(0, 0, pnl:GetWide(), pnl:GetTall())

    draw.SimpleText(title or "", "DermaDefaultBold", 8, 6, Color(225, 225, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    w = clampInt(w, 0, 32)
    h = clampInt(h, 0, 32)
    if w <= 0 or h <= 0 then
        draw.SimpleText("none", "DermaDefault", 8, 24, Color(170, 170, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        return
    end

    local availW = pnl:GetWide() - 16
    local availH = pnl:GetTall() - 32
    local cell = math.floor(math.min(availW / math.max(w, 1), availH / math.max(h, 1)))
    cell = math.max(5, math.min(cell, 24))
    local gw = cell * w
    local gh = cell * h
    local ox = 8 + math.floor((availW - gw) * 0.5)
    local oy = 24 + math.floor((availH - gh) * 0.5)

    surface.SetDrawColor(50, 56, 62, 255)
    surface.DrawRect(ox, oy, gw, gh)
    surface.SetDrawColor(95, 105, 116, 255)
    for x = 0, w do
        local px = ox + x * cell
        surface.DrawLine(px, oy, px, oy + gh)
    end
    for y = 0, h do
        local py = oy + y * cell
        surface.DrawLine(ox, py, ox + gw, py)
    end
end

local function BuildCompartmentArray(v, baseKeys)
    local valid = {}
    for _, name in ipairs(baseKeys) do valid[name] = true end

    local out = {}
    if istable(v.compartments) then
        for _, c in ipairs(v.compartments) do
            if istable(c) and isstring(c.name) and valid[c.name] then
                out[#out + 1] = {
                    name = c.name,
                    w = clampInt(c.w, 0, 32),
                    h = clampInt(c.h, 0, 32),
                }
            end
        end
        if #out > 0 then return out end
    end

    if istable(v.grants) then
        local keys = {}
        for name in pairs(v.grants) do
            if valid[name] then keys[#keys + 1] = name end
        end
        table.sort(keys)
        for _, name in ipairs(keys) do
            local g = v.grants[name] or {}
            out[#out + 1] = {
                name = name,
                w = clampInt(g.w, 0, 32),
                h = clampInt(g.h, 0, 32),
            }
        end
    end

    return out
end

local function WriteCompartmentArray(v, arr)
    local out = {}
    local grants = {}

    for _, c in ipairs(arr or {}) do
        if isstring(c.name) and c.name ~= "" then
            local row = {
                name = c.name,
                w = clampInt(c.w, 0, 32),
                h = clampInt(c.h, 0, 32),
            }
            out[#out + 1] = row
            grants[row.name] = { w = row.w, h = row.h }
        end
    end

    if #out > 0 then
        v.compartments = out
        v.grants = grants
    else
        v.compartments = nil
        v.grants = nil
    end
end

local function MakeGridPreview(parent, title)
    local pnl = vgui.Create("DPanel", parent)
    pnl:SetTall(120)
    pnl.gridTitle = title
    pnl.gridW = 0
    pnl.gridH = 0
    pnl.Paint = function(self)
        DrawGrid(self, self.gridW or 0, self.gridH or 0, self.gridTitle)
    end
    return pnl
end

local function BlocksOverlap(a, b)
    return a.x < (b.x + b.w)
        and (a.x + a.w) > b.x
        and a.y < (b.y + b.h)
        and (a.y + a.h) > b.y
end

local function SanitizeLayoutBlocks(layoutBlocks, gw, gh)
    local out = {}
    gw = clampInt(gw, 1, 32)
    gh = clampInt(gh, 1, 32)
    if not istable(layoutBlocks) then return out end

    for _, b in ipairs(layoutBlocks) do
        if istable(b) then
            local row = {
                x = clampInt(b.x, 0, gw - 1),
                y = clampInt(b.y, 0, gh - 1),
                w = clampInt(b.w, 1, 8),
                h = clampInt(b.h, 1, 8),
            }
            if row.x + row.w <= gw and row.y + row.h <= gh then
                out[#out + 1] = row
            end
        end
    end
    return out
end

local function FindFirstFit(blocks, bw, bh, gw, gh)
    bw = clampInt(bw, 1, 8)
    bh = clampInt(bh, 1, 8)
    gw = clampInt(gw, 1, 32)
    gh = clampInt(gh, 1, 32)

    for y = 0, gh - bh do
        for x = 0, gw - bw do
            local candidate = { x = x, y = y, w = bw, h = bh }
            local hit = false
            for _, b in ipairs(blocks or {}) do
                if BlocksOverlap(candidate, b) then
                    hit = true
                    break
                end
            end
            if not hit then return x, y end
        end
    end
    return nil, nil
end

local function BuildPanel(snapshot, focusClass, focusTab)
    if IsValid(PANEL) then PANEL:Remove() end

    local frame = vgui.Create("DFrame")
    frame:SetSize(1180, 740)
    frame:SetSizable(true)
    frame:SetMinWidth(980)
    frame:SetMinHeight(620)
    frame:Center()
    frame:SetTitle("ZScav Catalog Config")
    frame:MakePopup()
    PANEL = frame

    local footer = vgui.Create("DPanel", frame)
    footer:SetTall(42)
    footer:Dock(BOTTOM)
    footer:DockMargin(6, 4, 6, 6)
    footer.Paint = function() end

    local sheet = vgui.Create("DPropertySheet", frame)
    sheet:Dock(FILL)
    sheet:DockMargin(6, 6, 6, 0)

    -- ---------- Tab 1: Base Grids ----------
    local pBase = vgui.Create("DPanel", sheet)
    pBase.Paint = function() end
    sheet:AddSheet("Base Grids", pBase, "icon16/page_white_stack.png")

    local baseEdits = {}
    for _, key in ipairs({ "backpack", "pocket", "vest" }) do
        local row = vgui.Create("DPanel", pBase)
        row:SetTall(30)
        row:Dock(TOP)
        row:DockMargin(8, 4, 8, 0)
        row.Paint = function() end

        local lbl = vgui.Create("DLabel", row)
        lbl:SetText(key)
        lbl:SetWide(120)
        lbl:Dock(LEFT)

        local wlbl = vgui.Create("DLabel", row)
        wlbl:SetText("W:")
        wlbl:SetWide(20)
        wlbl:Dock(LEFT)

        local w = vgui.Create("DNumberWang", row)
        w:SetMinMax(0, 32)
        w:SetWide(60)
        w:Dock(LEFT)
        w:SetValue((snapshot.BaseGrids[key] or {}).w or 0)

        local hlbl = vgui.Create("DLabel", row)
        hlbl:SetText(" H:")
        hlbl:SetWide(24)
        hlbl:Dock(LEFT)

        local h = vgui.Create("DNumberWang", row)
        h:SetMinMax(0, 32)
        h:SetWide(60)
        h:Dock(LEFT)
        h:SetValue((snapshot.BaseGrids[key] or {}).h or 0)

        baseEdits[key] = { w = w, h = h }
    end

    -- ---------- Tab 2: Item Meta ----------
    local function makeItemMetaTab(title, source, allowSlot)
        local p = vgui.Create("DPanel", sheet)
        p.Paint = function() end
        local tabData = sheet:AddSheet(title, p, "icon16/table.png")

        local inspector = vgui.Create("DPanel", p)
        inspector:Dock(RIGHT)
        inspector:SetWide(260)
        inspector:DockMargin(8, 0, 0, 0)
        inspector.Paint = function() end

        local selectedLbl = vgui.Create("DLabel", inspector)
        selectedLbl:Dock(TOP)
        selectedLbl:SetText("(no selection)")
        selectedLbl:SetTall(24)

        local itemPrev = MakeGridPreview(inspector, "Inventory Footprint")
        itemPrev:Dock(TOP)
        itemPrev:DockMargin(0, 4, 0, 0)

        local list = vgui.Create("DListView", p)
        list:Dock(FILL)
        list:AddColumn("Class")
        list:AddColumn("W"):SetFixedWidth(42)
        list:AddColumn("H"):SetFixedWidth(42)
        list:AddColumn("Weight"):SetFixedWidth(64)
        if allowSlot then list:AddColumn("Slot"):SetFixedWidth(90) end

        local sorted = {}
        for k in pairs(source) do sorted[#sorted + 1] = k end
        table.sort(sorted)

        local rowMap = {}
        for _, class in ipairs(sorted) do
            local v = source[class] or {}
            local cells = { class, tostring(v.w or ""), tostring(v.h or ""), tostring(v.weight or "") }
            if allowSlot then cells[#cells + 1] = tostring(v.slot or "") end
            local line = list:AddLine(unpack(cells))
            rowMap[line] = class
        end

        local edit = vgui.Create("DPanel", p)
        edit:SetTall(40)
        edit:Dock(BOTTOM)
        edit:DockMargin(0, 4, 0, 0)
        edit.Paint = function() end

        local cur = vgui.Create("DLabel", edit)
        cur:SetWide(140)
        cur:Dock(LEFT)
        cur:SetText("(no selection)")

        local function num(label, lo, hi, decimals)
            local lbl = vgui.Create("DLabel", edit)
            lbl:SetText(label)
            lbl:SetWide(16)
            lbl:Dock(LEFT)
            local nw = vgui.Create("DNumberWang", edit)
            nw:SetMinMax(lo, hi)
            nw:SetWide(52)
            nw:Dock(LEFT)
            if decimals then nw:SetDecimals(decimals) end
            nw:SetValue(0)
            return nw
        end

        local wEd = num("W:", 0, 16)
        local hEd = num("H:", 0, 16)
        local wtEd = num("Wt:", 0, 100, 2)

        local slotEd
        if allowSlot then
            slotEd = vgui.Create("DTextEntry", edit)
            slotEd:SetWide(72)
            slotEd:Dock(LEFT)
            slotEd:SetPlaceholderText("slot")
        end

        local apply = vgui.Create("DButton", edit)
        apply:SetText("Apply Row")
        apply:SetWide(96)
        apply:Dock(RIGHT)

        local copyBtn = vgui.Create("DButton", edit)
        copyBtn:SetText("Copy Config")
        copyBtn:SetWide(96)
        copyBtn:Dock(RIGHT)
        copyBtn:DockMargin(0, 0, 4, 0)

        local selectedClass
        local function refreshPreview(v)
            itemPrev.gridW = tonumber(v.w) or 0
            itemPrev.gridH = tonumber(v.h) or 0
            itemPrev:InvalidateLayout(true)
            itemPrev:InvalidateParent(true)
        end

        local function loadInto(class)
            selectedClass = class
            local v = source[class] or {}
            cur:SetText(class)
            selectedLbl:SetText(class)
            wEd:SetValue(tonumber(v.w) or 0)
            hEd:SetValue(tonumber(v.h) or 0)
            wtEd:SetValue(tonumber(v.weight) or 0)
            if slotEd then slotEd:SetText(tostring(v.slot or "")) end
            refreshPreview(v)
        end

        list.OnRowSelected = function(_self, _i, line)
            local class = rowMap[line]
            if class then loadInto(class) end
        end

        apply.DoClick = function()
            if not selectedClass then return end
            local v = source[selectedClass] or {}
            local nw = wEd:GetValue()
            local nh = hEd:GetValue()
            v.w = nw > 0 and nw or nil
            v.h = nh > 0 and nh or nil
            v.weight = wtEd:GetValue()
            if slotEd then
                local s = string.Trim(slotEd:GetValue() or "")
                v.slot = s ~= "" and s or nil
            end
            source[selectedClass] = v
            refreshPreview(v)
            for line2, cls in pairs(rowMap) do
                if cls == selectedClass then
                    line2:SetColumnText(2, tostring(v.w or ""))
                    line2:SetColumnText(3, tostring(v.h or ""))
                    line2:SetColumnText(4, tostring(v.weight or ""))
                    if allowSlot then line2:SetColumnText(5, tostring(v.slot or "")) end
                    break
                end
            end
        end

        copyBtn.DoClick = function()
            if not selectedClass then return end
            local menu = DermaMenu()
            local added = 0

            local sorted = {}
            for class in pairs(source) do sorted[#sorted + 1] = class end
            table.sort(sorted)

            for _, class in ipairs(sorted) do
                if class ~= selectedClass then
                    local src = source[class]
                    if istable(src) and (tonumber(src.w) or 0) > 0 and (tonumber(src.h) or 0) > 0 then
                        added = added + 1
                        menu:AddOption(class, function()
                            local dst = source[selectedClass] or {}
                            dst.w = tonumber(src.w) or dst.w
                            dst.h = tonumber(src.h) or dst.h
                            if src.weight ~= nil then dst.weight = tonumber(src.weight) or dst.weight end
                            if allowSlot then
                                local s = tostring(src.slot or "")
                                dst.slot = (s ~= "") and s or dst.slot
                            end
                            source[selectedClass] = dst
                            loadInto(selectedClass)
                            for line2, cls in pairs(rowMap) do
                                if cls == selectedClass then
                                    line2:SetColumnText(2, tostring(dst.w or ""))
                                    line2:SetColumnText(3, tostring(dst.h or ""))
                                    line2:SetColumnText(4, tostring(dst.weight or ""))
                                    if allowSlot then line2:SetColumnText(5, tostring(dst.slot or "")) end
                                    break
                                end
                            end
                        end)
                    end
                end
            end

            if added == 0 then
                menu:AddOption("(no configured entries)", function() end):SetEnabled(false)
            end
            menu:Open()
        end

        return {
            tab = tabData,
            list = list,
            rowMap = rowMap,
            loadInto = loadInto,
        }
    end

    local itemMetaRef = makeItemMetaTab("Item Meta", snapshot.ItemMeta or {}, true)

    -- ---------- Tab 3: Gear Items ----------
    local pGear = vgui.Create("DPanel", sheet)
    pGear.Paint = function() end
    local gearTab = sheet:AddSheet("Gear Items", pGear, "icon16/table.png")

    local gearSrc = snapshot.GearItems or {}
    local baseKeys = {}
    for k in pairs(snapshot.BaseGrids or {}) do baseKeys[#baseKeys + 1] = k end
    table.sort(baseKeys)

    local inspector = vgui.Create("DPanel", pGear)
    inspector:Dock(RIGHT)
    inspector:SetWide(360)
    inspector:DockMargin(8, 0, 0, 0)
    inspector.Paint = function() end

    -- Scrollable container so the layout builder is always reachable regardless of window height
    local inspScroll = vgui.Create("DScrollPanel", inspector)
    inspScroll:Dock(FILL)

    local infoLbl = vgui.Create("DLabel", inspScroll)
    infoLbl:Dock(TOP)
    infoLbl:SetTall(22)
    infoLbl:SetText("(no selection)")

    local footprintPrev = MakeGridPreview(inspScroll, "Item Footprint")
    footprintPrev:Dock(TOP)
    footprintPrev:DockMargin(0, 4, 0, 0)

    local internalPrev = MakeGridPreview(inspScroll, "Internal Storage")
    internalPrev:Dock(TOP)
    internalPrev:DockMargin(0, 4, 0, 0)

    local compPreview = vgui.Create("DPanel", inspScroll)
    compPreview:SetTall(0)
    compPreview:Dock(TOP)
    compPreview:DockMargin(0, 0, 0, 0)
    compPreview:SetVisible(false)
    compPreview.compRows = {}
    compPreview.Paint = function(self, w, h)
        surface.SetDrawColor(34, 34, 34, 255)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText("Compartments (ordered)", "DermaDefaultBold", 8, 6, Color(225, 225, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        if #self.compRows == 0 then
            draw.SimpleText("none", "DermaDefault", 8, 24, Color(170, 170, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            return
        end
        local y = 24
        for i, row in ipairs(self.compRows) do
            draw.SimpleText(i .. ". " .. tostring(row.name) .. "  " .. tostring(row.w) .. "x" .. tostring(row.h), "DermaDefault", 8, y, Color(215, 215, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            y = y + 16
            if y > h - 14 then break end
        end
    end

    local compHeader = vgui.Create("DPanel", inspScroll)
    compHeader:SetTall(0)
    compHeader:Dock(TOP)
    compHeader:DockMargin(0, 0, 0, 0)
    compHeader:SetVisible(false)
    compHeader.Paint = function() end

    local compTitle = vgui.Create("DLabel", compHeader)
    compTitle:Dock(LEFT)
    compTitle:SetText("Compartment Editor (drag rows to reorder)")
    compTitle:SetWide(260)

    local compAdd = vgui.Create("DButton", compHeader)
    compAdd:Dock(RIGHT)
    compAdd:SetWide(110)
    compAdd:SetText("Add")

    local compScroll = vgui.Create("DScrollPanel", inspScroll)
    compScroll:SetTall(0)
    compScroll:Dock(TOP)
    compScroll:DockMargin(0, 0, 0, 0)
    compScroll:SetVisible(false)

    local layoutHeader = vgui.Create("DPanel", inspScroll)
    layoutHeader:SetTall(28)
    layoutHeader:Dock(TOP)
    layoutHeader:DockMargin(0, 4, 0, 2)
    layoutHeader.Paint = function(self, w, h)
        surface.SetDrawColor(50, 50, 50, 255)
        surface.DrawRect(0, 0, w, h)
    end

    local layoutTitle = vgui.Create("DLabel", layoutHeader)
    layoutTitle:Dock(LEFT)
    layoutTitle:SetWide(108)
    layoutTitle:SetText("Layout Builder")

    local add11 = vgui.Create("DButton", layoutHeader)
    add11:Dock(LEFT)
    add11:SetWide(48)
    add11:SetText("1x1")

    local add12 = vgui.Create("DButton", layoutHeader)
    add12:Dock(LEFT)
    add12:SetWide(48)
    add12:SetText("1x2")

    local add13 = vgui.Create("DButton", layoutHeader)
    add13:Dock(LEFT)
    add13:SetWide(48)
    add13:SetText("1x3")

    local add22 = vgui.Create("DButton", layoutHeader)
    add22:Dock(LEFT)
    add22:SetWide(48)
    add22:SetText("2x2")

    local clearLayout = vgui.Create("DButton", layoutHeader)
    clearLayout:Dock(RIGHT)
    clearLayout:SetWide(40)
    clearLayout:SetText("CLR")

    -- Fixed-height canvas — always fully visible once scrolled to, no longer collapses
    local layoutCanvas = vgui.Create("DPanel", inspScroll)
    layoutCanvas:SetTall(260)
    layoutCanvas:Dock(TOP)
    layoutCanvas:DockMargin(0, 0, 0, 8)

    local listHost = vgui.Create("DPanel", pGear)
    listHost:Dock(FILL)
    listHost.Paint = function() end

    local gearList = vgui.Create("DListView", listHost)
    gearList:Dock(FILL)
    gearList:AddColumn("Class")
    gearList:AddColumn("InvW"):SetFixedWidth(46)
    gearList:AddColumn("InvH"):SetFixedWidth(46)
    gearList:AddColumn("Weight"):SetFixedWidth(58)
    gearList:AddColumn("Comp"):SetFixedWidth(54)
    gearList:AddColumn("IntW"):SetFixedWidth(46)
    gearList:AddColumn("IntH"):SetFixedWidth(46)
    gearList:AddColumn("Blks"):SetFixedWidth(52)

    local gearSorted = {}
    for k in pairs(gearSrc) do gearSorted[#gearSorted + 1] = k end
    table.sort(gearSorted)

    local gearRowMap = {}
    for _, class in ipairs(gearSorted) do
        local v = gearSrc[class] or {}
        local line = gearList:AddLine(
            class,
            tostring(v.w or ""),
            tostring(v.h or ""),
            tostring(v.weight or ""),
            v.compartment and "yes" or "",
            tostring((v.internal or {}).w or ""),
            tostring((v.internal or {}).h or ""),
            tostring(#(v.layoutBlocks or {}))
        )
        gearRowMap[line] = class
    end

    local gearEdit = vgui.Create("DPanel", listHost)
    gearEdit:SetTall(42)
    gearEdit:Dock(BOTTOM)
    gearEdit:DockMargin(0, 4, 0, 0)
    gearEdit.Paint = function() end

    local gearCur = vgui.Create("DLabel", gearEdit)
    gearCur:SetWide(120)
    gearCur:Dock(LEFT)
    gearCur:SetText("(no selection)")

    local function gearNum(label, lo, hi, decimals)
        local lbl = vgui.Create("DLabel", gearEdit)
        lbl:SetText(label)
        lbl:SetWide(24)
        lbl:Dock(LEFT)
        local nw = vgui.Create("DNumberWang", gearEdit)
        nw:SetMinMax(lo, hi)
        nw:SetWide(40)
        nw:Dock(LEFT)
        if decimals then nw:SetDecimals(decimals) end
        nw:SetValue(0)
        return nw
    end

    local gearW = gearNum("InvW", 0, 16)
    local gearH = gearNum("InvH", 0, 16)
    local gearWt = gearNum("Wt", 0, 100, 2)

    local compWrap = vgui.Create("DPanel", gearEdit)
    compWrap:SetWide(64)
    compWrap:Dock(LEFT)
    compWrap.Paint = function() end
    local compChk = vgui.Create("DCheckBoxLabel", compWrap)
    compChk:SetText("Comp")
    compChk:SetPos(2, 12)
    compChk:SizeToContents()

    local intW = gearNum("IntW", 0, 32)
    local intH = gearNum("IntH", 0, 32)

    local gearApply = vgui.Create("DButton", gearEdit)
    gearApply:SetText("Apply Row")
    gearApply:SetWide(92)
    gearApply:Dock(RIGHT)

    local gearCopy = vgui.Create("DButton", gearEdit)
    gearCopy:SetText("Copy Config")
    gearCopy:SetWide(92)
    gearCopy:Dock(RIGHT)
    gearCopy:DockMargin(0, 0, 4, 0)

    local gearSelectedClass
    local compRows = {}
    local layoutBlocks = {}
    local dragBlock = nil
    local dragDX = 0
    local dragDY = 0

    local function internalGridSize()
        local gw = clampInt(intW:GetValue(), 1, 32)
        local gh = clampInt(intH:GetValue(), 1, 32)
        return gw, gh
    end

    local function normalizeLayoutBlocks()
        local gw, gh = internalGridSize()
        layoutBlocks = SanitizeLayoutBlocks(layoutBlocks, gw, gh)
    end

    local function layoutBounds(blocks)
        local maxW, maxH = 0, 0
        for _, b in ipairs(blocks or {}) do
            maxW = math.max(maxW, (b.x or 0) + (b.w or 0))
            maxH = math.max(maxH, (b.y or 0) + (b.h or 0))
        end
        return maxW, maxH
    end

    local function blockAtCell(cx, cy)
        for i = #layoutBlocks, 1, -1 do
            local b = layoutBlocks[i]
            if cx >= b.x and cx < b.x + b.w and cy >= b.y and cy < b.y + b.h then
                return i, b
            end
        end
        return nil, nil
    end

    local function canPlaceBlock(idx, x, y, w, h)
        local gw, gh = internalGridSize()
        if x < 0 or y < 0 or x + w > gw or y + h > gh then return false end
        local probe = { x = x, y = y, w = w, h = h }
        for i, b in ipairs(layoutBlocks) do
            if i ~= idx and BlocksOverlap(probe, b) then
                return false
            end
        end
        return true
    end

    local function getCanvasMetrics(self)
        local gw, gh = internalGridSize()
        local pad = 8
        local availW = self:GetWide() - pad * 2
        local availH = self:GetTall() - 28
        local cell = math.floor(math.min(availW / gw, availH / gh))
        cell = math.max(8, math.min(cell, 28))
        local pw = cell * gw
        local ph = cell * gh
        local ox = pad + math.floor((availW - pw) * 0.5)
        local oy = 22 + math.floor((availH - ph) * 0.5)
        return gw, gh, cell, ox, oy
    end

    layoutCanvas.Paint = function(self, w, h)
        surface.SetDrawColor(34, 34, 34, 255)
        surface.DrawRect(0, 0, w, h)
        if intW:GetValue() == 0 and intH:GetValue() == 0 then
            draw.SimpleText("Set IntW / IntH to define the grid size, then add blocks.", "DermaDefault", w * 0.5, h * 0.5, Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end
        draw.SimpleText("Drag blocks to position. Right-click block to rotate.", "DermaDefault", 8, 4, Color(210, 210, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local gw, gh, cell, ox, oy = getCanvasMetrics(self)
        surface.SetDrawColor(46, 52, 58, 255)
        surface.DrawRect(ox, oy, gw * cell, gh * cell)
        surface.SetDrawColor(92, 100, 110, 255)
        for x = 0, gw do
            local px = ox + x * cell
            surface.DrawLine(px, oy, px, oy + gh * cell)
        end
        for y = 0, gh do
            local py = oy + y * cell
            surface.DrawLine(ox, py, ox + gw * cell, py)
        end

        for i, b in ipairs(layoutBlocks) do
            local bx = ox + b.x * cell
            local by = oy + b.y * cell
            local bw = b.w * cell
            local bh = b.h * cell
            local col = (i == dragBlock) and Color(255, 180, 90, 210) or Color(100, 170, 250, 190)
            surface.SetDrawColor(col.r, col.g, col.b, col.a)
            surface.DrawRect(bx + 1, by + 1, bw - 2, bh - 2)
            surface.SetDrawColor(240, 240, 240, 220)
            surface.DrawOutlinedRect(bx, by, bw, bh, 1)
            draw.SimpleText(b.w .. "x" .. b.h, "DermaDefaultBold", bx + bw * 0.5, by + bh * 0.5, Color(245, 245, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    layoutCanvas.OnMousePressed = function(self, code)
        local mx, my = self:LocalCursorPos()
        local gw, gh, cell, ox, oy = getCanvasMetrics(self)
        local cx = math.floor((mx - ox) / cell)
        local cy = math.floor((my - oy) / cell)
        if cx < 0 or cy < 0 or cx >= gw or cy >= gh then
            dragBlock = nil
            return
        end

        local idx, block = blockAtCell(cx, cy)
        if code == MOUSE_RIGHT then
            if idx and block then
                local nw, nh = block.h, block.w
                if canPlaceBlock(idx, block.x, block.y, nw, nh) then
                    block.w = nw
                    block.h = nh
                end
            end
            return
        end

        if code ~= MOUSE_LEFT then return end
        if idx and block then
            dragBlock = idx
            dragDX = cx - block.x
            dragDY = cy - block.y
            self:MouseCapture(true)
        else
            dragBlock = nil
        end
    end

    layoutCanvas.OnCursorMoved = function(self, mx, my)
        if not dragBlock then return end
        if not input.IsMouseDown(MOUSE_LEFT) then
            self:MouseCapture(false)
            dragBlock = nil
            return
        end

        local _, _, cell, ox, oy = getCanvasMetrics(self)
        local cx = math.floor((mx - ox) / cell)
        local cy = math.floor((my - oy) / cell)
        local b = layoutBlocks[dragBlock]
        if not b then return end

        local nx = cx - dragDX
        local ny = cy - dragDY
        if canPlaceBlock(dragBlock, nx, ny, b.w, b.h) then
            b.x = nx
            b.y = ny
        end
    end

    layoutCanvas.OnMouseReleased = function(self, code)
        if code == MOUSE_LEFT then
            self:MouseCapture(false)
            dragBlock = nil
        end
    end

    local function setCompRows(entries)
        for _, row in ipairs(compRows) do
            if IsValid(row) then row:Remove() end
        end
        compRows = {}

        local canvas = compScroll:GetCanvas()
        for i, c in ipairs(entries or {}) do
            local row = vgui.Create("DPanel", canvas)
            row:SetTall(30)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 4)
            row:SetZPos(i)
            row.Paint = function(self, w, h)
                surface.SetDrawColor(48, 48, 48, 255)
                surface.DrawRect(0, 0, w, h)
            end
            row:Droppable("ZScavCompartmentRow")

            local dragLbl = vgui.Create("DLabel", row)
            dragLbl:SetWide(38)
            dragLbl:Dock(LEFT)
            dragLbl:SetText("drag")

            local name = vgui.Create("DComboBox", row)
            name:SetWide(120)
            name:Dock(LEFT)
            for _, key in ipairs(baseKeys) do name:AddChoice(key) end
            name:SetValue(c.name or "")

            local wLbl = vgui.Create("DLabel", row)
            wLbl:SetWide(18)
            wLbl:Dock(LEFT)
            wLbl:SetText("W")

            local wEd = vgui.Create("DNumberWang", row)
            wEd:SetMinMax(0, 32)
            wEd:SetWide(52)
            wEd:Dock(LEFT)
            wEd:SetValue(tonumber(c.w) or 0)

            local hLbl = vgui.Create("DLabel", row)
            hLbl:SetWide(18)
            hLbl:Dock(LEFT)
            hLbl:SetText("H")

            local hEd = vgui.Create("DNumberWang", row)
            hEd:SetMinMax(0, 32)
            hEd:SetWide(52)
            hEd:Dock(LEFT)
            hEd:SetValue(tonumber(c.h) or 0)

            local del = vgui.Create("DButton", row)
            del:SetText("X")
            del:SetWide(26)
            del:Dock(RIGHT)
            del.DoClick = function()
                if not IsValid(row) then return end
                row:Remove()
                for idx, r in ipairs(compRows) do
                    if r == row then
                        table.remove(compRows, idx)
                        break
                    end
                end
            end

            row.nameBox = name
            row.wBox = wEd
            row.hBox = hEd
            compRows[#compRows + 1] = row
        end
    end

    local function collectCompRows()
        local out = {}
        table.sort(compRows, function(a, b)
            return (a:GetZPos() or 0) < (b:GetZPos() or 0)
        end)
        for idx, row in ipairs(compRows) do
            if IsValid(row) then
                row:SetZPos(idx)
                local name = tostring(row.nameBox:GetValue() or "")
                if name ~= "" then
                    out[#out + 1] = {
                        name = name,
                        w = row.wBox:GetValue(),
                        h = row.hBox:GetValue(),
                    }
                end
            end
        end
        return out
    end

    compScroll:GetCanvas():Receiver("ZScavCompartmentRow", function(_canvas, panels, dropped, _menu, _x, y)
        if not dropped then return end
        local dragged = panels and panels[1]
        if not IsValid(dragged) then return end

        local sorted = {}
        for _, row in ipairs(compRows) do
            if IsValid(row) and row ~= dragged then sorted[#sorted + 1] = row end
        end

        local insertAt = #sorted + 1
        for i, row in ipairs(sorted) do
            local _, ry = row:GetPos()
            if y < (ry + row:GetTall() * 0.5) then
                insertAt = i
                break
            end
        end

        table.insert(sorted, insertAt, dragged)
        compRows = sorted
        for i, row in ipairs(compRows) do row:SetZPos(i) end
    end)

    compAdd.DoClick = function()
        local entry = {
            name = baseKeys[1] or "backpack",
            w = 0,
            h = 0,
        }
        local cur = collectCompRows()
        cur[#cur + 1] = entry
        setCompRows(cur)
    end

    local function refreshGearPreview(v)
        local entries = collectCompRows()
        footprintPrev.gridW = tonumber(v.w) or 0
        footprintPrev.gridH = tonumber(v.h) or 0
        internalPrev.gridW = tonumber((v.internal or {}).w) or 0
        internalPrev.gridH = tonumber((v.internal or {}).h) or 0
        compPreview.compRows = entries
        normalizeLayoutBlocks()
        footprintPrev:InvalidateLayout(true)
        internalPrev:InvalidateLayout(true)
        compPreview:InvalidateLayout(true)
        layoutCanvas:InvalidateLayout(true)
    end

    local function addLayoutPreset(pw, ph)
        local gw, gh = internalGridSize()
        normalizeLayoutBlocks()
        local x, y = FindFirstFit(layoutBlocks, pw, ph, gw, gh)
        if x == nil then return end
        layoutBlocks[#layoutBlocks + 1] = { x = x, y = y, w = pw, h = ph }
        layoutCanvas:InvalidateLayout(true)
    end

    add11.DoClick = function() addLayoutPreset(1, 1) end
    add12.DoClick = function() addLayoutPreset(1, 2) end
    add13.DoClick = function() addLayoutPreset(1, 3) end
    add22.DoClick = function() addLayoutPreset(2, 2) end
    clearLayout.DoClick = function()
        layoutBlocks = {}
        layoutCanvas:InvalidateLayout(true)
    end

    local function refreshGearListRow(class)
        local v = gearSrc[class] or {}
        for line2, cls in pairs(gearRowMap) do
            if cls == class then
                line2:SetColumnText(2, tostring(v.w or ""))
                line2:SetColumnText(3, tostring(v.h or ""))
                line2:SetColumnText(4, tostring(v.weight or ""))
                line2:SetColumnText(5, v.compartment and "yes" or "")
                line2:SetColumnText(6, tostring((v.internal or {}).w or ""))
                line2:SetColumnText(7, tostring((v.internal or {}).h or ""))
                line2:SetColumnText(8, tostring(#(v.layoutBlocks or {})))
                break
            end
        end
    end

    local function loadGear(class)
        gearSelectedClass = class
        local v = gearSrc[class] or {}
        local entries = BuildCompartmentArray(v, baseKeys)

        -- Resolve grid size for the layout canvas.
        -- Priority: explicit internal → layout block bounds → grants.vest (legacy rig).
        local rawW = tonumber((v.internal or {}).w) or 0
        local rawH = tonumber((v.internal or {}).h) or 0
        if rawW <= 0 or rawH <= 0 then
            if istable(v.layoutBlocks) and #v.layoutBlocks > 0 then
                local lw, lh = 0, 0
                for _, b in ipairs(v.layoutBlocks) do
                    lw = math.max(lw, (b.x or 0) + (b.w or 0))
                    lh = math.max(lh, (b.y or 0) + (b.h or 0))
                end
                if lw > 0 then rawW = lw end
                if lh > 0 then rawH = lh end
            end
            if (rawW <= 0 or rawH <= 0) and istable(v.grants) and istable(v.grants.vest) then
                rawW = rawW > 0 and rawW or (tonumber(v.grants.vest.w) or 0)
                rawH = rawH > 0 and rawH or (tonumber(v.grants.vest.h) or 0)
            end
        end
        local gw = math.max(1, rawW)
        local gh = math.max(1, rawH)

        gearCur:SetText(class)
        infoLbl:SetText(class)
        gearW:SetValue(tonumber(v.w) or 0)
        gearH:SetValue(tonumber(v.h) or 0)
        gearWt:SetValue(tonumber(v.weight) or 0)
        compChk:SetChecked(v.compartment == true)
        intW:SetValue(rawW)
        intH:SetValue(rawH)
        layoutBlocks = SanitizeLayoutBlocks(v.layoutBlocks, gw, gh)
        dragBlock = nil
        setCompRows(entries)
        refreshGearPreview(v)
    end

    gearList.OnRowSelected = function(_self, _i, line)
        local class = gearRowMap[line]
        if class then loadGear(class) end
    end

    gearApply.DoClick = function()
        if not gearSelectedClass then return end
        local v = gearSrc[gearSelectedClass] or {}

        local iw = gearW:GetValue()
        local ih = gearH:GetValue()
        local nw = intW:GetValue()
        local nh = intH:GetValue()

        v.w = iw > 0 and iw or nil
        v.h = ih > 0 and ih or nil
        v.weight = gearWt:GetValue()
        v.compartment = compChk:GetChecked() and true or nil

        if nw > 0 and nh > 0 then
            v.internal = v.internal or {}
            v.internal.w = nw
            v.internal.h = nh
        else
            v.internal = nil
        end

        normalizeLayoutBlocks()
        v.layoutBlocks = (#layoutBlocks > 0) and table.Copy(layoutBlocks) or nil
        if v.layoutBlocks then
            local lw, lh = layoutBounds(v.layoutBlocks)
            v.compartment = true
            v.internal = {
                w = math.max(1, lw or 1),
                h = math.max(1, lh or 1),
            }
        end
        gearSrc[gearSelectedClass] = v

        refreshGearListRow(gearSelectedClass)
        refreshGearPreview(v)
    end

    gearCopy.DoClick = function()
        if not gearSelectedClass then return end
        local menu = DermaMenu()
        local added = 0

        local sorted = {}
        for class in pairs(gearSrc) do sorted[#sorted + 1] = class end
        table.sort(sorted)

        for _, class in ipairs(sorted) do
            if class ~= gearSelectedClass then
                local src = gearSrc[class]
                if istable(src) and (tonumber(src.w) or 0) > 0 and (tonumber(src.h) or 0) > 0 then
                    added = added + 1
                    menu:AddOption(class, function()
                        local dst = gearSrc[gearSelectedClass] or {}

                        -- Copy footprint + storage + compartment settings.
                        dst.w = tonumber(src.w) or dst.w
                        dst.h = tonumber(src.h) or dst.h
                        dst.compartment = src.compartment and true or nil

                        if istable(src.internal) then
                            dst.internal = {
                                w = tonumber(src.internal.w) or nil,
                                h = tonumber(src.internal.h) or nil,
                            }
                        else
                            dst.internal = nil
                        end

                        dst.compartments = istable(src.compartments) and table.Copy(src.compartments) or nil
                        dst.grants = istable(src.grants) and table.Copy(src.grants) or nil
                        dst.layoutBlocks = istable(src.layoutBlocks) and table.Copy(src.layoutBlocks) or nil

                        gearSrc[gearSelectedClass] = dst
                        loadGear(gearSelectedClass)
                        refreshGearListRow(gearSelectedClass)
                        refreshGearPreview(dst)
                    end)
                end
            end
        end

        if added == 0 then
            menu:AddOption("(no configured entries)", function() end):SetEnabled(false)
        end
        menu:Open()
    end

    local save = vgui.Create("DButton", footer)
    save:SetText("Apply & Save")
    save:SetWide(160)
    save:Dock(RIGHT)
    save:DockMargin(0, 6, 0, 6)

    save.DoClick = function()
        for key, edits in pairs(baseEdits) do
            snapshot.BaseGrids[key] = snapshot.BaseGrids[key] or {}
            snapshot.BaseGrids[key].w = edits.w:GetValue()
            snapshot.BaseGrids[key].h = edits.h:GetValue()
        end

        -- Pull latest visible row edits into the selected gear item before save.
        if gearSelectedClass then
            local v = gearSrc[gearSelectedClass] or {}
            v.w = gearW:GetValue() > 0 and gearW:GetValue() or nil
            v.h = gearH:GetValue() > 0 and gearH:GetValue() or nil
            v.weight = gearWt:GetValue()
            v.compartment = compChk:GetChecked() and true or nil
            if intW:GetValue() > 0 and intH:GetValue() > 0 then
                v.internal = { w = intW:GetValue(), h = intH:GetValue() }
            else
                v.internal = nil
            end
            normalizeLayoutBlocks()
            v.layoutBlocks = (#layoutBlocks > 0) and table.Copy(layoutBlocks) or nil
            if v.layoutBlocks then
                local lw, lh = layoutBounds(v.layoutBlocks)
                v.compartment = true
                v.internal = {
                    w = math.max(1, lw or 1),
                    h = math.max(1, lh or 1),
                }
            end
            gearSrc[gearSelectedClass] = v
        end

        local payload = util.TableToJSON(snapshot)
        net.Start("ZScavCfgApply")
            net.WriteUInt(#payload, 32)
            net.WriteData(payload, #payload)
        net.SendToServer()

        notification.AddLegacy("[ZScav] Catalog sent.", NOTIFY_GENERIC, 3)
    end

    frame.ZScavFocusClass = function(_frame, class, tabHint)
        class = tostring(class or ""):lower()
        tabHint = tostring(tabHint or ""):lower()
        if class == "" then return end

        local function selectIn(list, rowMap, loader)
            for line, cls in pairs(rowMap or {}) do
                if tostring(cls or ""):lower() == class then
                    if IsValid(list) and list.SelectItem then list:SelectItem(line) end
                    if loader then loader(cls) end
                    return true
                end
            end
            return false
        end

        local preferGear = (tabHint == "gear")
        local hit = false
        if preferGear then
            if gearTab and gearTab.Tab then sheet:SetActiveTab(gearTab.Tab) end
            hit = selectIn(gearList, gearRowMap, loadGear)
            if not hit and itemMetaRef and itemMetaRef.tab and itemMetaRef.tab.Tab then
                sheet:SetActiveTab(itemMetaRef.tab.Tab)
                hit = selectIn(itemMetaRef.list, itemMetaRef.rowMap, itemMetaRef.loadInto)
            end
        else
            if itemMetaRef and itemMetaRef.tab and itemMetaRef.tab.Tab then
                sheet:SetActiveTab(itemMetaRef.tab.Tab)
                hit = selectIn(itemMetaRef.list, itemMetaRef.rowMap, itemMetaRef.loadInto)
            end
            if not hit and gearTab and gearTab.Tab then
                sheet:SetActiveTab(gearTab.Tab)
                hit = selectIn(gearList, gearRowMap, loadGear)
            end
        end
    end

    if focusClass and focusClass ~= "" then
        timer.Simple(0, function()
            if IsValid(frame) and frame.ZScavFocusClass then
                frame:ZScavFocusClass(focusClass, focusTab)
            end
        end)
    end
end

net.Receive("ZScavCfgFocus", function()
    local class = tostring(net.ReadString() or ""):lower()
    local tab = tostring(net.ReadString() or ""):lower()
    PENDING_FOCUS_CLASS = class ~= "" and class or nil
    PENDING_FOCUS_TAB = tab ~= "" and tab or nil

    if IsValid(PANEL) and PANEL.ZScavFocusClass and PENDING_FOCUS_CLASS then
        PANEL:ZScavFocusClass(PENDING_FOCUS_CLASS, PENDING_FOCUS_TAB)
    end
end)

net.Receive("ZScavCfgOpen", function()
    local sz = net.ReadUInt(32)
    local raw = net.ReadData(sz)
    local snap = util.JSONToTable(raw or "")
    if not istable(snap) then return end
    snap.BaseGrids = snap.BaseGrids or {}
    snap.ItemMeta = snap.ItemMeta or {}
    snap.GearItems = snap.GearItems or {}
    BuildPanel(snap, PENDING_FOCUS_CLASS, PENDING_FOCUS_TAB)
    PENDING_FOCUS_CLASS = nil
    PENDING_FOCUS_TAB = nil
end)
