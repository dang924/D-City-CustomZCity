local NET_OPEN = "ZScavTraderTerminalOpen"
local NET_STATE = "ZScavTraderTerminalState"
local NET_ACTION = "ZScavTraderTerminalAction"

local FRAME = nil
local PRESET_FRAME = nil
local STATE = nil
local SELECTED_PLAYER_SID64 = ""
local SELECTED_CATALOG_CLASS = ""
local SELECTED_PRESET_ID = ""
local SELECTED_OFFER_INDEX = nil
local SELECTED_PRESET_PLAYER_INDEX = nil
local SELECTED_PRESET_TRADER_INDEX = nil
local DRAFT_PRESET_ID = ""
local DRAFT_PRESET_PLAYER_ITEMS = {}
local DRAFT_PRESET_TRADER_ITEMS = {}
local TICKET_ITEM_CLASS = "zscav_vendor_ticket"

local nearbyList
local sessionPlayerOfferView
local sessionTraderOfferView
local presetList
local presetPlayerItemList
local presetTraderItemList
local catalogList
local nowServingLabel
local statusLabel
local vendorStatusButton
local nextServingButton
local presetNameEntry
local presetCooldownWang
local catalogSearchEntry
local catalogCountWang
local presetEditorCatalogList
local presetEditorCatalogSearchEntry
local presetEditorCatalogCountWang
local presetEditorCustomClassEntry

local COL_TERM_BG = Color(18, 22, 26, 242)
local COL_TERM_HEADER = Color(26, 31, 36, 250)
local COL_TERM_PANEL = Color(26, 31, 36, 235)
local COL_TERM_INSET = Color(14, 17, 20, 235)
local COL_TERM_EDGE = Color(70, 78, 92, 220)
local COL_TERM_BUTTON = Color(62, 68, 78, 230)
local COL_TERM_TEXT = Color(242, 238, 228)
local COL_TERM_DIM = Color(176, 180, 186)
local COL_TERM_ACCENT = Color(118, 96, 52, 235)

local function TS(value)
    if Nexus and Nexus.Scale then
        return Nexus:Scale(value)
    end

    return value
end

local function TF(size, weight, bold)
    if Nexus and Nexus.GetFont then
        return Nexus:GetFont(size, weight, bold)
    end

    return bold and "DermaDefaultBold" or "DermaDefault"
end

local function TR(radius)
    return math.max(4, math.floor(TS(radius)))
end

local function styleScrollBar(owner)
    local bar = IsValid(owner) and owner.GetVBar and owner:GetVBar() or nil
    if not IsValid(bar) or bar._zsTraderStyled then return end

    bar._zsTraderStyled = true
    bar:SetWide(TS(8))
    bar.Paint = function(_, w, h)
        draw.RoundedBox(TR(6), 0, 0, w, h, Color(10, 12, 15, 180))
    end

    if IsValid(bar.btnUp) then
        bar.btnUp.Paint = function() end
    end

    if IsValid(bar.btnDown) then
        bar.btnDown.Paint = function() end
    end

    if IsValid(bar.btnGrip) then
        bar.btnGrip.Paint = function(_, w, h)
            draw.RoundedBox(TR(6), 0, 0, w, h, Color(102, 110, 124, 215))
        end
    end
end

local function styleLabel(label, size, bold, color, align)
    if not IsValid(label) then return end

    label:SetFont(TF(size, nil, bold))
    label:SetTextColor(color or COL_TERM_TEXT)
    if align ~= nil then
        label:SetContentAlignment(align)
    end
end

local function styleButton(button, accent)
    if not IsValid(button) or button._zsTraderStyled then return end

    button._zsTraderStyled = true

    local rawSetText = button.SetText
    function button:SetText(text)
        self._zsTraderText = tostring(text or "")
        rawSetText(self, "")
    end

    button:SetFont(TF(13, nil, true))
    button:SetText(button:GetText() or "")
    button.Paint = function(self, w, h)
        local enabled = self:IsEnabled()
        local fill = accent or COL_TERM_BUTTON
        if not enabled then
            fill = Color(38, 42, 48, 215)
        elseif self:IsDown() then
            fill = accent and Color(136, 112, 62, 240) or Color(78, 86, 98, 235)
        elseif self:IsHovered() then
            fill = accent and Color(150, 124, 70, 238) or Color(90, 98, 112, 236)
        end

        draw.RoundedBox(TR(8), 0, 0, w, h, fill)
        surface.SetDrawColor(enabled and COL_TERM_EDGE or Color(56, 60, 66, 210))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(self._zsTraderText or "", TF(12, nil, true), w * 0.5, h * 0.5, enabled and COL_TERM_TEXT or COL_TERM_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local function styleEntry(entry)
    if not IsValid(entry) or entry._zsTraderStyled then return end

    entry._zsTraderStyled = true
    entry:SetFont(TF(13))
    entry:SetTextColor(COL_TERM_TEXT)
    entry:SetCursorColor(COL_TERM_TEXT)
    entry:SetHighlightColor(Color(198, 164, 94, 120))
    entry.Paint = function(self, w, h)
        draw.RoundedBox(TR(6), 0, 0, w, h, self:HasFocus() and Color(18, 21, 25, 245) or COL_TERM_INSET)
        surface.SetDrawColor(self:HasFocus() and Color(162, 134, 74, 220) or COL_TERM_EDGE)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local placeholder = self.GetPlaceholderText and tostring(self:GetPlaceholderText() or "") or ""
        if placeholder ~= "" and tostring(self:GetText() or "") == "" and not self:HasFocus() then
            draw.SimpleText(placeholder, TF(12), TS(8), h * 0.5, Color(132, 136, 142), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        self:DrawTextEntryText(COL_TERM_TEXT, Color(198, 164, 94, 120), COL_TERM_TEXT)
    end
end

local function styleListLine(line)
    if not IsValid(line) or line._zsTraderStyled then return end

    line._zsTraderStyled = true
    line:SetTall(math.max(22, TS(24)))
    line.Paint = function(self, w, h)
        local selected = self.m_bSelected == true
        local fill = selected and Color(98, 82, 46, 235) or (self:IsHovered() and Color(48, 54, 62, 228) or Color(24, 28, 34, 210))
        draw.RoundedBox(TR(6), 0, 0, w, h, fill)
    end

    for _, column in ipairs(line.Columns or {}) do
        if IsValid(column) then
            if column.SetFontInternal then
                column:SetFontInternal(TF(12))
            elseif column.SetFont then
                column:SetFont(TF(12))
            end
            if column.SetTextColor then
                column:SetTextColor(COL_TERM_TEXT)
            end
        end
    end
end

local function styleListView(list)
    if not IsValid(list) or list._zsTraderStyled then return end

    list._zsTraderStyled = true
    if list.SetHeaderHeight then
        list:SetHeaderHeight(math.max(22, TS(24)))
    end
    list.Paint = function(_, w, h)
        draw.RoundedBox(TR(8), 0, 0, w, h, COL_TERM_INSET)
        surface.SetDrawColor(COL_TERM_EDGE)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local originalPerformLayout = list.PerformLayout
    list.PerformLayout = function(self, ...)
        if originalPerformLayout then
            originalPerformLayout(self, ...)
        end

        styleScrollBar(self)

        for _, column in ipairs(self.Columns or {}) do
            local header = column.Header or column
            if IsValid(header) and not header._zsTraderStyled then
                header._zsTraderStyled = true
                header._zsTraderLabel = tostring((header.GetText and header:GetText()) or (column.GetName and column:GetName()) or "")
                if header.SetText then
                    header:SetText("")
                end
                header.Paint = function(panel, w, h)
                    draw.RoundedBox(0, 0, 0, w, h, panel:IsHovered() and Color(48, 54, 62, 235) or Color(34, 38, 44, 240))
                    surface.SetDrawColor(COL_TERM_EDGE)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    draw.SimpleText(panel._zsTraderLabel or "", TF(12, nil, true), TS(8), h * 0.5, COL_TERM_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
            end
        end

        for _, line in ipairs(self:GetLines() or {}) do
            styleListLine(line)
        end
    end

    styleScrollBar(list)
end

local function sendAction(action, args)
    net.Start(NET_ACTION)
        net.WriteString(action)
        net.WriteTable(args or {})
    net.SendToServer()
end

local function prettyClassName(class)
    class = tostring(class or "")
    if class == "" then return "Unknown" end

    local gear = ZSCAV.GetGearDef and ZSCAV:GetGearDef(class) or nil
    if gear and tostring(gear.name or "") ~= "" then
        return tostring(gear.name)
    end

    local meta = ZSCAV.GetItemMeta and ZSCAV:GetItemMeta(class) or nil
    if meta and tostring(meta.name or meta.PrintName or "") ~= "" then
        return tostring(meta.name or meta.PrintName)
    end

    local wep = weapons.GetStored(class)
    if wep and tostring(wep.PrintName or "") ~= "" then
        return tostring(wep.PrintName)
    end

    local ent = scripted_ents.GetStored(class)
    if ent and ent.t and tostring(ent.t.PrintName or "") ~= "" then
        return tostring(ent.t.PrintName)
    end

    return class
end

local function cloneEntries(entries)
    local out = {}
    for _, entry in ipairs(entries or {}) do
        out[#out + 1] = {
            class = tostring(entry.class or ""),
            count = math.Clamp(math.floor(tonumber(entry.count) or 1), 1, 64),
        }
    end
    return out
end

local function trimText(text, maxLen)
    text = tostring(text or "")
    maxLen = math.max(1, math.floor(tonumber(maxLen) or 18))
    if #text <= maxLen then
        return text
    end
    if maxLen <= 3 then
        return string.sub(text, 1, maxLen)
    end
    return string.sub(text, 1, maxLen - 3) .. "..."
end

local function formatCooldownLabel(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if seconds <= 0 then return "None" end
    if string.NiceTime then
        return string.NiceTime(seconds)
    end
    if seconds < 60 then
        return tostring(seconds) .. "s"
    end

    local minutes = math.floor(seconds / 60)
    local remain = seconds % 60
    if remain <= 0 then
        return tostring(minutes) .. "m"
    end
    return string.format("%dm %ds", minutes, remain)
end

local function summarizeEntries(entries, emptyText)
    local parts = {}

    for index, entry in ipairs(entries or {}) do
        local count = math.max(1, math.floor(tonumber(entry.count) or 1))
        parts[#parts + 1] = string.format("%dx %s", count, prettyClassName(entry.class))
        if index >= 4 then
            break
        end
    end

    if #parts <= 0 then
        return tostring(emptyText or "None")
    end

    local remainder = math.max(0, #(entries or {}) - #parts)
    local summary = table.concat(parts, ", ")
    if remainder > 0 then
        summary = summary .. string.format(", +%d more", remainder)
    end

    return summary
end

local function buildTradePreviewPlacements(entries, cols)
    cols = math.max(1, math.floor(tonumber(cols) or 1))

    local occupied = {}
    local placements = {}
    local maxRow = 0

    local function fitsAt(gridX, gridY, width, height)
        if gridX + width > cols then
            return false
        end

        for row = gridY, gridY + height - 1 do
            occupied[row] = occupied[row] or {}
            for col = gridX, gridX + width - 1 do
                if occupied[row][col] then
                    return false
                end
            end
        end

        return true
    end

    local function occupy(gridX, gridY, width, height)
        for row = gridY, gridY + height - 1 do
            occupied[row] = occupied[row] or {}
            for col = gridX, gridX + width - 1 do
                occupied[row][col] = true
            end
        end

        maxRow = math.max(maxRow, gridY + height)
    end

    for index, entry in ipairs(entries or {}) do
        local entryW = math.max(1, math.floor(tonumber(entry.w) or 1))
        local entryH = math.max(1, math.floor(tonumber(entry.h) or 1))
        local foundX, foundY = 0, 0
        local placed = false

        for row = 0, 255 do
            for col = 0, math.max(0, cols - entryW) do
                if fitsAt(col, row, entryW, entryH) then
                    foundX, foundY = col, row
                    placed = true
                    break
                end
            end
            if placed then break end
        end

        occupy(foundX, foundY, entryW, entryH)
        placements[#placements + 1] = {
            index = index,
            entry = entry,
            x = foundX,
            y = foundY,
            w = entryW,
            h = entryH,
        }
    end

    return placements, math.max(1, maxRow)
end

local function updateTradePreviewLayout(preview)
    if not IsValid(preview) then return end

    local width = preview:GetWide()
    if width <= 0 then return end

    local pad = TS(10)
    local gap = TS(6)
    local cell = math.max(34, TS(42))
    local usable = math.max(cell, width - pad * 2)
    local cols = math.max(4, math.floor((usable + gap) / (cell + gap)))
    local placements, rows = buildTradePreviewPlacements(preview.entries or {}, cols)
    local gridW = cols * (cell + gap) - gap
    local gridH = rows * (cell + gap) - gap
    local tall = pad * 2 + gridH

    preview._layout = {
        pad = pad,
        gap = gap,
        cell = cell,
        cols = cols,
        rows = rows,
        gridX = pad + math.max(0, math.floor((usable - gridW) * 0.5)),
        gridY = pad,
        placements = placements,
    }

    if preview:GetTall() ~= tall then
        preview:SetTall(tall)
        local parent = preview:GetParent()
        if IsValid(parent) and parent.InvalidateLayout then
            parent:InvalidateLayout(true)
        end
    end
end

local function createTradePreview(parent, title, emptyText, onSelect)
    local wrap = parent:Add("DPanel")
    wrap.Paint = function(_, w, h)
        draw.RoundedBox(TR(8), 0, 0, w, h, COL_TERM_PANEL)
        surface.SetDrawColor(COL_TERM_EDGE)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local titleLabel = wrap:Add("DLabel")
    titleLabel:Dock(TOP)
    titleLabel:DockMargin(TS(10), TS(10), TS(10), TS(2))
    titleLabel:SetText(tostring(title or "Preview"))
    titleLabel:SetFont(TF(15, nil, true))
    titleLabel:SetTextColor(COL_TERM_TEXT)

    local infoLabel = wrap:Add("DLabel")
    infoLabel:Dock(TOP)
    infoLabel:DockMargin(TS(10), 0, TS(10), TS(6))
    infoLabel:SetWrap(true)
    infoLabel:SetAutoStretchVertical(true)
    infoLabel:SetText("")
    infoLabel:SetFont(TF(12))
    infoLabel:SetTextColor(COL_TERM_DIM)

    local scroll = wrap:Add("DScrollPanel")
    scroll:Dock(FILL)
    scroll:DockMargin(TS(8), 0, TS(8), TS(8))
    styleScrollBar(scroll)

    local preview = scroll:Add("DPanel")
    preview:Dock(TOP)
    preview:SetTall(TS(120))
    preview:SetMouseInputEnabled(onSelect ~= nil)
    preview.entries = {}
    preview.emptyText = tostring(emptyText or "No items.")
    preview.selectedIndex = nil

    function preview:SetEntries(entries)
        self.entries = {}
        for _, entry in ipairs(entries or {}) do
            self.entries[#self.entries + 1] = table.Copy(entry)
        end
        self._layout = nil
        updateTradePreviewLayout(self)
    end

    function preview:SetSelectedIndex(index)
        self.selectedIndex = tonumber(index)
    end

    preview.Think = function(self)
        updateTradePreviewLayout(self)
    end

    preview.Paint = function(self, w, h)
        local layout = self._layout or {}
        local cell = layout.cell or 42
        local gap = layout.gap or 6
        local pad = layout.pad or 10
        local gridX = layout.gridX or pad
        local gridY = layout.gridY or pad
        local rows = layout.rows or 1
        local cols = layout.cols or 4

        draw.RoundedBox(TR(8), 0, 0, w, h, Color(20, 24, 30, 210))

        for row = 0, rows - 1 do
            for col = 0, cols - 1 do
                local cellX = gridX + col * (cell + gap)
                local cellY = gridY + row * (cell + gap)
                draw.RoundedBox(TR(6), cellX, cellY, cell, cell, Color(36, 42, 52, 235))
                surface.SetDrawColor(Color(74, 84, 102, 180))
                surface.DrawOutlinedRect(cellX, cellY, cell, cell, 1)
            end
        end

        if #(self.entries or {}) <= 0 then
            draw.SimpleText(self.emptyText, TF(13, nil, true), w * 0.5, h * 0.5, Color(170, 178, 188), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        for _, placed in ipairs(layout.placements or {}) do
            local entry = placed.entry
            local cardX = gridX + placed.x * (cell + gap)
            local cardY = gridY + placed.y * (cell + gap)
            local cardW = placed.w * (cell + gap) - gap
            local cardH = placed.h * (cell + gap) - gap
            local accent = (ZSCAV.GetGearDef and ZSCAV:GetGearDef(entry.class)) and Color(102, 132, 108) or Color(92, 106, 124)
            local fill = Color(44, 52, 64, 245)
            local border = Color(86, 98, 118, 220)

            if tonumber(self.selectedIndex) == tonumber(placed.index) then
                fill = Color(70, 58, 34, 250)
                border = Color(220, 188, 108, 240)
            end

            draw.RoundedBox(6, cardX, cardY, cardW, cardH, fill)
            draw.RoundedBox(5, cardX + 4, cardY + 4, math.min(cardW - 8, 12), cardH - 8, accent)
            surface.SetDrawColor(border)
            surface.DrawOutlinedRect(cardX, cardY, cardW, cardH, 1)

            local count = math.max(1, math.floor(tonumber(entry.count) or 1))
            draw.SimpleText(trimText(prettyClassName(entry.class), math.max(8, math.floor(cardW / 9))), TF(12, nil, true), cardX + 22, cardY + 6, Color(234, 238, 242))
            draw.SimpleText(string.upper(trimText(tostring(entry.class or ""), math.max(10, math.floor(cardW / 9)))), TF(11), cardX + 22, cardY + cardH - 8, Color(170, 178, 188), 0, TEXT_ALIGN_BOTTOM)
            draw.SimpleText(string.format("%dx%d", placed.w, placed.h), TF(12, nil, true), cardX + cardW - 6, cardY + 6, Color(176, 184, 198), TEXT_ALIGN_RIGHT)

            if count > 1 then
                draw.RoundedBox(5, cardX + cardW - 28, cardY + cardH - 24, 22, 18, Color(32, 36, 44, 245))
                draw.SimpleText("x" .. tostring(count), TF(12, nil, true), cardX + cardW - 17, cardY + cardH - 15, Color(232, 236, 242), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end

    preview.OnMousePressed = function(self, code)
        if code ~= MOUSE_LEFT or not onSelect then return end
        updateTradePreviewLayout(self)

        local mx, my = self:CursorPos()
        for _, placed in ipairs(self._layout and self._layout.placements or {}) do
            local cell = self._layout.cell or 42
            local gap = self._layout.gap or 6
            local gridX = self._layout.gridX or 10
            local gridY = self._layout.gridY or 10
            local cardX = gridX + placed.x * (cell + gap)
            local cardY = gridY + placed.y * (cell + gap)
            local cardW = placed.w * (cell + gap) - gap
            local cardH = placed.h * (cell + gap) - gap

            if mx >= cardX and mx <= cardX + cardW and my >= cardY and my <= cardY + cardH then
                self.selectedIndex = placed.index
                onSelect(placed.index, placed.entry)
                return
            end
        end
    end

    function wrap:SetEntries(entries)
        preview:SetEntries(entries)
    end

    function wrap:SetInfoText(text)
        infoLabel:SetText(tostring(text or ""))
    end

    function wrap:SetSelectedIndex(index)
        preview:SetSelectedIndex(index)
    end

    return wrap
end

local function getCatalogClasses()
    local out = {}
    local seen = {}

    local function add(class)
        class = tostring(class or "")
        if class == "" or class == "zscav_mailbox_container" or class == "zscav_trade_player_offer" or class == TICKET_ITEM_CLASS then
            return
        end
        if seen[class] then return end
        seen[class] = true
        out[#out + 1] = class
    end

    for class in pairs(ZSCAV.ItemMeta or {}) do add(class) end
    for class in pairs(ZSCAV.GearItems or {}) do add(class) end
    for class in pairs(ZSCAV.ItemSizes or {}) do add(class) end

    table.sort(out, function(left, right)
        return string.lower(prettyClassName(left)) < string.lower(prettyClassName(right))
    end)

    return out
end

local function setStatus(text)
    if IsValid(statusLabel) then
        statusLabel:SetText(tostring(text or ""))
    end
end

local function formatNowServingLabel(number, waitingCount)
    number = math.max(0, math.floor(tonumber(number) or 0))
    waitingCount = math.max(0, math.floor(tonumber(waitingCount) or 0))
    if waitingCount > 0 then
        return string.format("NOW SERVING: (%d) | WAITING: %d", number, waitingCount)
    end
    return string.format("NOW SERVING: (%d)", number)
end

local function loadPresetDraft(preset)
    preset = istable(preset) and preset or nil
    DRAFT_PRESET_ID = preset and tostring(preset.id or "") or ""
    DRAFT_PRESET_PLAYER_ITEMS = cloneEntries(preset and preset.player_items or {})
    DRAFT_PRESET_TRADER_ITEMS = cloneEntries(preset and (preset.trader_items or preset.items) or {})
    SELECTED_PRESET_PLAYER_INDEX = nil
    SELECTED_PRESET_TRADER_INDEX = nil

    if IsValid(presetNameEntry) then
        presetNameEntry:SetText(preset and tostring(preset.name or "") or "")
    end
    if IsValid(presetCooldownWang) then
        presetCooldownWang:SetValue(math.max(0, math.floor(tonumber(preset and preset.cooldown_seconds or 0) or 0)))
    end
    if IsValid(PRESET_FRAME) and PRESET_FRAME.UpdateDraftMeta then
        PRESET_FRAME:UpdateDraftMeta()
    end
end

local function refreshPresetItemList()
    if IsValid(presetPlayerItemList) then
        presetPlayerItemList:Clear()
        for index, item in ipairs(DRAFT_PRESET_PLAYER_ITEMS) do
            local row = presetPlayerItemList:AddLine(prettyClassName(item.class), tostring(item.count), tostring(item.class))
            row.tradePresetIndex = index
        end
    end

    if IsValid(presetTraderItemList) then
        presetTraderItemList:Clear()
        for index, item in ipairs(DRAFT_PRESET_TRADER_ITEMS) do
            local row = presetTraderItemList:AddLine(prettyClassName(item.class), tostring(item.count), tostring(item.class))
            row.tradePresetIndex = index
        end
    end

    if IsValid(PRESET_FRAME) and PRESET_FRAME.UpdateDraftMeta then
        PRESET_FRAME:UpdateDraftMeta()
    end
end

local function refreshPresetList()
    if not IsValid(presetList) then return end
    presetList:Clear()

    for _, preset in ipairs(STATE and STATE.presets or {}) do
        local row = presetList:AddLine(
            tostring(preset.name or "Preset"),
            tostring(#(preset.player_items or {})),
            tostring(#(preset.trader_items or preset.items or {})),
            formatCooldownLabel(preset.cooldown_seconds)
        )
        row.tradePresetID = tostring(preset.id or "")
    end
end

local function refreshNearbyList()
    if not IsValid(nearbyList) then return end
    nearbyList:Clear()

    for _, playerRow in ipairs(STATE and STATE.nearby_players or {}) do
        local accessText = playerRow.has_trader_access and "Yes" or "No"
        local canTradeText = playerRow.vendor_available and "Vendor" or (playerRow.can_trade and "Ready" or "Busy")
        local row = nearbyList:AddLine(
            tostring(playerRow.name or "Player"),
            tostring(playerRow.distance or 0),
            accessText,
            canTradeText
        )
        row.tradeTargetSID64 = tostring(playerRow.sid64 or "")
    end
end

local function refreshCatalogList()
    if not IsValid(catalogList) then return end
    catalogList:Clear()

    local filter = string.lower(string.Trim(IsValid(catalogSearchEntry) and catalogSearchEntry:GetValue() or ""))
    for _, class in ipairs(getCatalogClasses()) do
        local name = prettyClassName(class)
        local haystack = string.lower(name .. " " .. class)
        if filter == "" or string.find(haystack, filter, 1, true) then
            local row = catalogList:AddLine(name, class)
            row.tradeCatalogClass = class
        end
    end
end

local function refreshSessionLists()
    SELECTED_OFFER_INDEX = nil

    local session = STATE and STATE.active_session or nil
    if not session then
        local availableVendorCount = #(STATE and STATE.available_vendors or {})
        if STATE and STATE.vendor_status_active then
            setStatus(string.format("No active trade session. Vendor duty is active%s.", tostring(STATE.safe_zone_name or "") ~= "" and (" in " .. tostring(STATE.safe_zone_name)) or ""))
        elseif availableVendorCount > 0 then
            setStatus(string.format("No active trade session. %d vendor%s on duty%s.", availableVendorCount, availableVendorCount == 1 and " is" or "s are", tostring(STATE.safe_zone_name or "") ~= "" and (" in " .. tostring(STATE.safe_zone_name)) or ""))
        else
            setStatus("No active trade session.")
        end
        if IsValid(sessionPlayerOfferView) then
            sessionPlayerOfferView:SetEntries({})
            sessionPlayerOfferView:SetInfoText("No active player basket.")
        end
        if IsValid(sessionTraderOfferView) then
            sessionTraderOfferView:SetEntries({})
            sessionTraderOfferView:SetInfoText("No trader offer loaded.")
        end
        return
    end

    local status = string.format("Trading with %s | Player %s", tostring(session.player_name or "Player"), session.player_ready and "READY" or "NOT READY")
    if tostring(session.active_preset_name or "") ~= "" then
        status = status .. " | Preset: " .. tostring(session.active_preset_name)
    end
    setStatus(status)

    if IsValid(sessionPlayerOfferView) then
        sessionPlayerOfferView:SetEntries(session.player_offer_items or {})
        if #(session.required_player_items or {}) > 0 then
            local requirementText = summarizeEntries(session.required_player_items, "No required payment.")
            if session.required_offer_ok then
                sessionPlayerOfferView:SetInfoText("Required payment: " .. requirementText .. ". Basket matches preset requirements.")
            else
                sessionPlayerOfferView:SetInfoText(tostring(session.required_offer_message or "") .. " Required payment: " .. requirementText)
            end
        else
            sessionPlayerOfferView:SetInfoText("Custom trade payment basket. Current offer: " .. summarizeEntries(session.player_offer_items, "nothing added yet"))
        end
    end

    if IsValid(sessionTraderOfferView) then
        sessionTraderOfferView:SetEntries(session.trader_items or {})
        local traderInfo = "Offer summary: " .. summarizeEntries(session.trader_items, "no trader items yet")
        local cooldownSeconds = math.max(0, math.floor(tonumber(session.preset_cooldown_seconds) or 0))
        if tostring(session.active_preset_name or "") ~= "" then
            traderInfo = "Preset reward: " .. summarizeEntries(session.trader_items, "no trader items yet")
            if cooldownSeconds > 0 then
                traderInfo = traderInfo .. ". Cooldown after redemption: " .. formatCooldownLabel(cooldownSeconds) .. "."
            end
        end
        sessionTraderOfferView:SetInfoText(traderInfo)
        sessionTraderOfferView:SetSelectedIndex(SELECTED_OFFER_INDEX)
    end
end

local function findPresetByID(presetID)
    presetID = tostring(presetID or "")
    for _, preset in ipairs(STATE and STATE.presets or {}) do
        if tostring(preset.id or "") == presetID then
            return preset
        end
    end
end

local function getPresetEditorSelectedClass()
    local customClass = string.Trim(IsValid(presetEditorCustomClassEntry) and presetEditorCustomClassEntry:GetValue() or "")
    if customClass ~= "" then
        return customClass
    end

    return tostring(SELECTED_CATALOG_CLASS or "")
end

local function getPresetEditorSelectedCount()
    local countSource = IsValid(presetEditorCatalogCountWang) and presetEditorCatalogCountWang or catalogCountWang
    return math.max(1, math.floor(tonumber(IsValid(countSource) and countSource:GetValue() or 1) or 1))
end

local function addDraftEntryToPresetSide(side)
    local class = string.Trim(getPresetEditorSelectedClass())
    if class == "" then
        setStatus("Select a catalog item or type a class name first.")
        return false
    end

    local count = getPresetEditorSelectedCount()
    if side == "player" then
        DRAFT_PRESET_PLAYER_ITEMS[#DRAFT_PRESET_PLAYER_ITEMS + 1] = {
            class = class,
            count = count,
        }
        SELECTED_PRESET_PLAYER_INDEX = #DRAFT_PRESET_PLAYER_ITEMS
    else
        DRAFT_PRESET_TRADER_ITEMS[#DRAFT_PRESET_TRADER_ITEMS + 1] = {
            class = class,
            count = count,
        }
        SELECTED_PRESET_TRADER_INDEX = #DRAFT_PRESET_TRADER_ITEMS
    end

    refreshPresetItemList()
    return true
end

local function removeDraftEntryFromPresetSide(side)
    if side == "player" then
        if not SELECTED_PRESET_PLAYER_INDEX or not DRAFT_PRESET_PLAYER_ITEMS[SELECTED_PRESET_PLAYER_INDEX] then return false end
        table.remove(DRAFT_PRESET_PLAYER_ITEMS, SELECTED_PRESET_PLAYER_INDEX)
        SELECTED_PRESET_PLAYER_INDEX = nil
    else
        if not SELECTED_PRESET_TRADER_INDEX or not DRAFT_PRESET_TRADER_ITEMS[SELECTED_PRESET_TRADER_INDEX] then return false end
        table.remove(DRAFT_PRESET_TRADER_ITEMS, SELECTED_PRESET_TRADER_INDEX)
        SELECTED_PRESET_TRADER_INDEX = nil
    end

    refreshPresetItemList()
    return true
end

local function saveDraftPresetToServer()
    if not (IsValid(presetNameEntry) and IsValid(presetCooldownWang)) then return end

    sendAction("save_preset", {
        preset = {
            id = DRAFT_PRESET_ID,
            name = string.Trim(presetNameEntry:GetValue() or ""),
            player_items = cloneEntries(DRAFT_PRESET_PLAYER_ITEMS),
            trader_items = cloneEntries(DRAFT_PRESET_TRADER_ITEMS),
            cooldown_seconds = math.max(0, math.floor(tonumber(presetCooldownWang:GetValue()) or 0)),
        }
    })
end

local function refreshPresetEditorCatalogList()
    if not IsValid(presetEditorCatalogList) then return end
    presetEditorCatalogList:Clear()

    local filter = string.lower(string.Trim(IsValid(presetEditorCatalogSearchEntry) and presetEditorCatalogSearchEntry:GetValue() or ""))
    for _, class in ipairs(getCatalogClasses()) do
        local name = prettyClassName(class)
        local haystack = string.lower(name .. " " .. class)
        if filter == "" or string.find(haystack, filter, 1, true) then
            local row = presetEditorCatalogList:AddLine(name, class)
            row.tradeCatalogClass = class
        end
    end
end

local function closePresetEditor()
    if IsValid(PRESET_FRAME) then
        PRESET_FRAME:Remove()
    end
end

local function openPresetEditor(preset)
    if preset ~= nil then
        loadPresetDraft(preset)
    elseif DRAFT_PRESET_ID == "" and #DRAFT_PRESET_PLAYER_ITEMS == 0 and #DRAFT_PRESET_TRADER_ITEMS == 0 then
        local selectedPreset = findPresetByID(SELECTED_PRESET_ID)
        if selectedPreset then
            loadPresetDraft(selectedPreset)
        end
    end

    if IsValid(PRESET_FRAME) then
        PRESET_FRAME:MakePopup()
        if PRESET_FRAME.UpdateDraftMeta then
            PRESET_FRAME:UpdateDraftMeta()
        end
        refreshPresetItemList()
        refreshPresetEditorCatalogList()
        return PRESET_FRAME
    end

    local frameW = math.min(1320, math.floor(ScrW() * 0.88))
    local frameH = math.min(840, math.floor(ScrH() * 0.9))
    local leftWide = math.Clamp(math.floor(frameW * 0.42), 420, 520)
    local headerTall = TS(48)
    local actionButtonTall = TS(32)

    PRESET_FRAME = vgui.Create("DFrame")
    PRESET_FRAME:SetSize(frameW, frameH)
    PRESET_FRAME:Center()
    PRESET_FRAME:SetTitle("")
    PRESET_FRAME:SetDraggable(true)
    PRESET_FRAME:SetDeleteOnClose(true)
    PRESET_FRAME:ShowCloseButton(true)
    PRESET_FRAME:MakePopup()
    PRESET_FRAME.Paint = function(_, w, h)
        draw.RoundedBox(TR(12), 0, 0, w, h, COL_TERM_BG)
        surface.SetDrawColor(8, 10, 12, 230)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.RoundedBoxEx(TR(12), 0, 0, w, headerTall, COL_TERM_HEADER, true, true, false, false)
    end
    PRESET_FRAME.OnRemove = function()
        PRESET_FRAME = nil
        presetNameEntry = nil
        presetCooldownWang = nil
        presetPlayerItemList = nil
        presetTraderItemList = nil
        presetEditorCatalogList = nil
        presetEditorCatalogSearchEntry = nil
        presetEditorCatalogCountWang = nil
        presetEditorCustomClassEntry = nil
    end

    PRESET_FRAME.btnClose:SetText("")
    PRESET_FRAME.btnClose.Paint = function(self, w, h)
        draw.SimpleText("x", TF(18, nil, true), w * 0.5, h * 0.5, self:IsHovered() and Color(255, 235, 235) or Color(214, 210, 198), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local titleLabel = PRESET_FRAME:Add("DLabel")
    titleLabel:SetPos(TS(16), TS(10))
    titleLabel:SetText("Preset Editor")
    titleLabel:SizeToContents()
    styleLabel(titleLabel, 18, true, COL_TERM_TEXT)

    local subtitleLabel = PRESET_FRAME:Add("DLabel")
    subtitleLabel:SetPos(TS(16), TS(28))
    subtitleLabel:SetText("Build preset payments and rewards in a dedicated workspace.")
    subtitleLabel:SizeToContents()
    styleLabel(subtitleLabel, 13, false, COL_TERM_DIM)
    PRESET_FRAME.subtitleLabel = subtitleLabel

    local shell = PRESET_FRAME:Add("DPanel")
    shell:Dock(FILL)
    shell:DockMargin(TS(12), TS(58), TS(12), TS(12))
    shell.Paint = function() end

    local left = shell:Add("DPanel")
    left:Dock(LEFT)
    left:SetWide(leftWide)
    left:DockMargin(0, 0, TS(8), 0)
    left.Paint = function(_, w, h)
        draw.RoundedBox(TR(10), 0, 0, w, h, COL_TERM_PANEL)
    end

    local right = shell:Add("DPanel")
    right:Dock(FILL)
    right.Paint = function(_, w, h)
        draw.RoundedBox(TR(10), 0, 0, w, h, COL_TERM_PANEL)
    end

    local catalogLabel = left:Add("DLabel")
    catalogLabel:Dock(TOP)
    catalogLabel:DockMargin(TS(12), TS(12), TS(12), TS(4))
    catalogLabel:SetText("Catalog Browser")

    presetEditorCatalogSearchEntry = left:Add("DTextEntry")
    presetEditorCatalogSearchEntry:Dock(TOP)
    presetEditorCatalogSearchEntry:DockMargin(TS(12), 0, TS(12), TS(4))
    presetEditorCatalogSearchEntry:SetPlaceholderText("Search catalog or type a barter class below...")
    presetEditorCatalogSearchEntry.OnChange = function()
        refreshPresetEditorCatalogList()
    end

    local catalogControls = left:Add("DPanel")
    catalogControls:Dock(BOTTOM)
    catalogControls:SetTall(TS(118))
    catalogControls:DockMargin(TS(12), TS(8), TS(12), TS(12))
    catalogControls.Paint = function() end

    local customClassLabel = catalogControls:Add("DLabel")
    customClassLabel:Dock(TOP)
    customClassLabel:SetText("Custom class for valuables / crafting / barter items")

    presetEditorCustomClassEntry = catalogControls:Add("DTextEntry")
    presetEditorCustomClassEntry:Dock(TOP)
    presetEditorCustomClassEntry:DockMargin(0, TS(4), 0, TS(4))
    presetEditorCustomClassEntry:SetPlaceholderText("Optional exact class name override")

    local countRow = catalogControls:Add("DPanel")
    countRow:Dock(TOP)
    countRow:SetTall(TS(28))
    countRow:DockMargin(0, 0, 0, TS(6))
    countRow.Paint = function() end

    local countLabel = countRow:Add("DLabel")
    countLabel:Dock(LEFT)
    countLabel:SetWide(TS(88))
    countLabel:SetText("Stack Count")

    presetEditorCatalogCountWang = countRow:Add("DNumberWang")
    presetEditorCatalogCountWang:Dock(LEFT)
    presetEditorCatalogCountWang:SetWide(TS(72))
    presetEditorCatalogCountWang:SetMinMax(1, 32)
    presetEditorCatalogCountWang:SetValue(1)

    local addRow = catalogControls:Add("DPanel")
    addRow:Dock(TOP)
    addRow:SetTall(actionButtonTall)
    addRow.Paint = function() end

    local addPlayerButton = addRow:Add("DButton")
    addPlayerButton:Dock(LEFT)
    addPlayerButton:SetWide(math.floor((leftWide - TS(36)) * 0.5))
    addPlayerButton:SetText("Add To Player Pays")
    addPlayerButton.DoClick = function()
        addDraftEntryToPresetSide("player")
    end

    local addTraderButton = addRow:Add("DButton")
    addTraderButton:Dock(FILL)
    addTraderButton:DockMargin(TS(6), 0, 0, 0)
    addTraderButton:SetText("Add To Trader Gives")
    addTraderButton.DoClick = function()
        addDraftEntryToPresetSide("trader")
    end

    presetEditorCatalogList = left:Add("DListView")
    presetEditorCatalogList:Dock(FILL)
    presetEditorCatalogList:DockMargin(TS(12), 0, TS(12), 0)
    presetEditorCatalogList:AddColumn("Item")
    presetEditorCatalogList:AddColumn("Class")
    presetEditorCatalogList.OnRowSelected = function(_, _, row)
        SELECTED_CATALOG_CLASS = tostring(row.tradeCatalogClass or "")
        if IsValid(presetEditorCustomClassEntry) and string.Trim(presetEditorCustomClassEntry:GetValue() or "") ~= "" then
            presetEditorCustomClassEntry:SetText("")
        end
    end

    local draftLabel = right:Add("DLabel")
    draftLabel:Dock(TOP)
    draftLabel:DockMargin(TS(12), TS(12), TS(12), TS(4))
    draftLabel:SetText("Preset Draft")

    local summaryLabel = right:Add("DLabel")
    summaryLabel:Dock(TOP)
    summaryLabel:DockMargin(TS(12), 0, TS(12), TS(6))
    summaryLabel:SetText("")
    PRESET_FRAME.summaryLabel = summaryLabel

    presetNameEntry = right:Add("DTextEntry")
    presetNameEntry:Dock(TOP)
    presetNameEntry:DockMargin(TS(12), 0, TS(12), TS(6))
    presetNameEntry:SetPlaceholderText("Preset name")
    presetNameEntry.OnChange = function()
        if IsValid(PRESET_FRAME) and PRESET_FRAME.UpdateDraftMeta then
            PRESET_FRAME:UpdateDraftMeta()
        end
    end

    local cooldownRow = right:Add("DPanel")
    cooldownRow:Dock(TOP)
    cooldownRow:SetTall(TS(28))
    cooldownRow:DockMargin(TS(12), 0, TS(12), TS(6))
    cooldownRow.Paint = function() end

    local cooldownLabel = cooldownRow:Add("DLabel")
    cooldownLabel:Dock(LEFT)
    cooldownLabel:SetWide(TS(126))
    cooldownLabel:SetText("Cooldown (sec)")

    presetCooldownWang = cooldownRow:Add("DNumberWang")
    presetCooldownWang:Dock(LEFT)
    presetCooldownWang:SetWide(TS(84))
    presetCooldownWang:SetMinMax(0, 31536000)
    presetCooldownWang:SetValue(0)
    presetCooldownWang.OnValueChanged = function()
        if IsValid(PRESET_FRAME) and PRESET_FRAME.UpdateDraftMeta then
            PRESET_FRAME:UpdateDraftMeta()
        end
    end

    local cooldownHint = cooldownRow:Add("DLabel")
    cooldownHint:Dock(FILL)
    cooldownHint:SetText("Per-player wait after redeeming this preset")

    local draftSplit = right:Add("DPanel")
    draftSplit:Dock(FILL)
    draftSplit:DockMargin(TS(12), 0, TS(12), 0)
    draftSplit.Paint = function() end

    local playerWrap = draftSplit:Add("DPanel")
    playerWrap:Dock(LEFT)
    playerWrap:SetWide(math.max(260, math.floor((frameW - leftWide - TS(52)) * 0.48)))
    playerWrap:DockMargin(0, 0, TS(6), 0)
    playerWrap.Paint = function() end

    local traderWrap = draftSplit:Add("DPanel")
    traderWrap:Dock(FILL)
    traderWrap.Paint = function() end

    local playerLabel = playerWrap:Add("DLabel")
    playerLabel:Dock(TOP)
    playerLabel:SetText("Player Pays")

    presetPlayerItemList = playerWrap:Add("DListView")
    presetPlayerItemList:Dock(FILL)
    presetPlayerItemList:AddColumn("Item")
    presetPlayerItemList:AddColumn("Count"):SetFixedWidth(TS(54))
    presetPlayerItemList:AddColumn("Class")
    presetPlayerItemList.OnRowSelected = function(_, _, row)
        SELECTED_PRESET_PLAYER_INDEX = tonumber(row.tradePresetIndex)
    end

    local traderLabel = traderWrap:Add("DLabel")
    traderLabel:Dock(TOP)
    traderLabel:SetText("Trader Gives")

    presetTraderItemList = traderWrap:Add("DListView")
    presetTraderItemList:Dock(FILL)
    presetTraderItemList:AddColumn("Item")
    presetTraderItemList:AddColumn("Count"):SetFixedWidth(TS(54))
    presetTraderItemList:AddColumn("Class")
    presetTraderItemList.OnRowSelected = function(_, _, row)
        SELECTED_PRESET_TRADER_INDEX = tonumber(row.tradePresetIndex)
    end

    local actionWrap = right:Add("DPanel")
    actionWrap:Dock(BOTTOM)
    actionWrap:SetTall(TS(114))
    actionWrap:DockMargin(TS(12), TS(8), TS(12), TS(12))
    actionWrap.Paint = function() end

    local actionRowOne = actionWrap:Add("DPanel")
    actionRowOne:Dock(TOP)
    actionRowOne:SetTall(actionButtonTall)
    actionRowOne.Paint = function() end

    local newDraftButton = actionRowOne:Add("DButton")
    newDraftButton:Dock(LEFT)
    newDraftButton:SetWide(TS(148))
    newDraftButton:SetText("New Draft")
    newDraftButton.DoClick = function()
        SELECTED_PRESET_ID = ""
        loadPresetDraft(nil)
        refreshPresetItemList()
    end

    local saveDraftButton = actionRowOne:Add("DButton")
    saveDraftButton:Dock(FILL)
    saveDraftButton:DockMargin(TS(6), 0, 0, 0)
    saveDraftButton:SetText("Save Draft")
    saveDraftButton.DoClick = function()
        saveDraftPresetToServer()
    end

    local actionRowTwo = actionWrap:Add("DPanel")
    actionRowTwo:Dock(TOP)
    actionRowTwo:SetTall(actionButtonTall)
    actionRowTwo:DockMargin(0, TS(6), 0, 0)
    actionRowTwo.Paint = function() end

    local removePlayerButton = actionRowTwo:Add("DButton")
    removePlayerButton:Dock(LEFT)
    removePlayerButton:SetWide(TS(148))
    removePlayerButton:SetText("Remove Player Item")
    removePlayerButton.DoClick = function()
        removeDraftEntryFromPresetSide("player")
    end

    local removeTraderButton = actionRowTwo:Add("DButton")
    removeTraderButton:Dock(FILL)
    removeTraderButton:DockMargin(TS(6), 0, 0, 0)
    removeTraderButton:SetText("Remove Trader Item")
    removeTraderButton.DoClick = function()
        removeDraftEntryFromPresetSide("trader")
    end

    local actionRowThree = actionWrap:Add("DPanel")
    actionRowThree:Dock(TOP)
    actionRowThree:SetTall(actionButtonTall)
    actionRowThree:DockMargin(0, TS(6), 0, 0)
    actionRowThree.Paint = function() end

    local applyPresetButton = actionRowThree:Add("DButton")
    applyPresetButton:Dock(LEFT)
    applyPresetButton:SetWide(TS(180))
    applyPresetButton:SetText("Apply Selected Preset")
    applyPresetButton.DoClick = function()
        if SELECTED_PRESET_ID == "" then return end
        sendAction("apply_preset", { preset_id = SELECTED_PRESET_ID })
    end

    local deletePresetButton = actionRowThree:Add("DButton")
    deletePresetButton:Dock(FILL)
    deletePresetButton:DockMargin(TS(6), 0, 0, 0)
    deletePresetButton:SetText("Delete Selected")
    deletePresetButton.DoClick = function()
        if SELECTED_PRESET_ID == "" then return end
        sendAction("delete_preset", { preset_id = SELECTED_PRESET_ID })
    end

    styleLabel(catalogLabel, 14, true, COL_TERM_TEXT)
    styleLabel(customClassLabel, 12, false, COL_TERM_DIM)
    styleLabel(countLabel, 12, true, COL_TERM_TEXT)
    styleLabel(draftLabel, 14, true, COL_TERM_TEXT)
    styleLabel(summaryLabel, 12, false, COL_TERM_DIM)
    styleLabel(cooldownLabel, 12, true, COL_TERM_TEXT)
    styleLabel(cooldownHint, 12, false, COL_TERM_DIM)
    styleLabel(playerLabel, 13, true, COL_TERM_TEXT)
    styleLabel(traderLabel, 13, true, COL_TERM_TEXT)

    styleEntry(presetEditorCatalogSearchEntry)
    styleEntry(presetEditorCustomClassEntry)
    styleEntry(presetEditorCatalogCountWang)
    styleEntry(presetNameEntry)
    styleEntry(presetCooldownWang)

    styleListView(presetEditorCatalogList)
    styleListView(presetPlayerItemList)
    styleListView(presetTraderItemList)

    styleButton(addPlayerButton, COL_TERM_ACCENT)
    styleButton(addTraderButton, COL_TERM_ACCENT)
    styleButton(newDraftButton)
    styleButton(saveDraftButton, COL_TERM_ACCENT)
    styleButton(removePlayerButton)
    styleButton(removeTraderButton)
    styleButton(applyPresetButton, COL_TERM_ACCENT)
    styleButton(deletePresetButton)

    PRESET_FRAME.UpdateDraftMeta = function(self)
        if not IsValid(self) then return end

        local draftName = string.Trim(IsValid(presetNameEntry) and presetNameEntry:GetValue() or "")
        local draftMode = DRAFT_PRESET_ID ~= "" and "Editing selected preset" or "New preset draft"
        if draftName ~= "" then
            draftMode = draftMode .. " - " .. draftName
        end

        if IsValid(self.subtitleLabel) then
            self.subtitleLabel:SetText(draftMode)
            self.subtitleLabel:SizeToContents()
        end

        if IsValid(self.summaryLabel) then
            local cooldownLabelText = formatCooldownLabel(IsValid(presetCooldownWang) and presetCooldownWang:GetValue() or 0)
            self.summaryLabel:SetText(string.format(
                "Player pays: %d item%s | Trader gives: %d item%s | Cooldown: %s",
                #DRAFT_PRESET_PLAYER_ITEMS,
                #DRAFT_PRESET_PLAYER_ITEMS == 1 and "" or "s",
                #DRAFT_PRESET_TRADER_ITEMS,
                #DRAFT_PRESET_TRADER_ITEMS == 1 and "" or "s",
                cooldownLabelText
            ))
        end
    end

    refreshPresetEditorCatalogList()
    refreshPresetItemList()
    PRESET_FRAME:UpdateDraftMeta()
    return PRESET_FRAME
end

local function ensureFrame()
    if IsValid(FRAME) then return FRAME end

    local frameW = math.min(1560, math.floor(ScrW() * (ScrW() < 1500 and 0.985 or 0.97)))
    local frameH = math.min(930, math.floor(ScrH() * 0.95))
    local compactLayout = frameW < 1320 or frameH < 820
    local frameMargin = TS(compactLayout and 8 or 12)
    local panelGap = TS(compactLayout and 4 or 6)
    local leftWide = math.Clamp(math.floor(frameW * (compactLayout and 0.21 or 0.24)), compactLayout and TS(220) or 270, compactLayout and TS(320) or 360)
    local rightWide = math.Clamp(math.floor(frameW * (compactLayout and 0.27 or 0.32)), compactLayout and TS(300) or 420, compactLayout and TS(430) or 520)
    local centerWide = math.max(TS(compactLayout and 300 or 360), frameW - leftWide - rightWide - frameMargin * 2 - panelGap * 2)
    local playerOfferWide = math.Clamp(math.floor(centerWide * (compactLayout and 0.42 or 0.5)), compactLayout and TS(180) or 250, compactLayout and TS(280) or 360)
    local topBarTall = math.Clamp(math.floor(frameH * (compactLayout and 0.05 or 0.055)), compactLayout and 36 or 40, 48)
    local actionButtonTall = math.Clamp(math.floor(frameH * 0.038), 30, 36)
    local nearbyButtonsTall = math.Clamp(math.floor(frameH * 0.17), 122, 146)
    local traderButtonsTall = math.Clamp(math.floor(frameH * 0.13), 96, 114)
    local catalogTall = math.Clamp(math.floor(frameH * (compactLayout and 0.29 or 0.33)), compactLayout and 180 or 220, 310)
    local presetTall = math.Clamp(math.floor(frameH * 0.26), 190, 280)
    local presetButtonsTall = math.Clamp(math.floor(frameH * 0.14), 102, 132)
    local refreshButtonWide = math.Clamp(math.floor(frameW * (compactLayout and 0.068 or 0.075)), TS(84), TS(118))
    local nextButtonWide = math.Clamp(math.floor(frameW * (compactLayout and 0.068 or 0.075)), TS(84), TS(118))
    local nowServingWide = compactLayout and TS(184) or TS(238)
    local vendorStatusWide = compactLayout and TS(176) or TS(220)
    local sessionActionWide = compactLayout and TS(104) or 126
    local nearbyDistWide = compactLayout and TS(42) or 50
    local nearbyAccessWide = compactLayout and TS(54) or 60
    local nearbyStateWide = compactLayout and TS(56) or 60

    FRAME = vgui.Create("DFrame")
    FRAME:SetSize(frameW, frameH)
    FRAME:Center()
    FRAME:SetTitle("")
    FRAME:SetDraggable(true)
    FRAME:SetDeleteOnClose(true)
    FRAME:ShowCloseButton(true)
    FRAME:MakePopup()
    FRAME.Paint = function(_, w, h)
        draw.RoundedBox(TR(12), 0, 0, w, h, COL_TERM_BG)
        surface.SetDrawColor(8, 10, 12, 230)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.RoundedBoxEx(TR(12), 0, 0, w, TS(48), COL_TERM_HEADER, true, true, false, false)
    end
    FRAME.OnRemove = function()
        FRAME = nil
        closePresetEditor()
    end

    FRAME.btnClose:SetText("")
    FRAME.btnClose.Paint = function(self, w, h)
        draw.SimpleText("x", TF(18, nil, true), w * 0.5, h * 0.5, self:IsHovered() and Color(255, 235, 235) or Color(214, 210, 198), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local titleLabel = FRAME:Add("DLabel")
    titleLabel:SetPos(TS(16), TS(12))
    titleLabel:SetText("Trader Terminal")
    titleLabel:SizeToContents()
    styleLabel(titleLabel, 18, true, COL_TERM_TEXT)
    FRAME.titleLabel = titleLabel

    local subtitleLabel = FRAME:Add("DLabel")
    subtitleLabel:SetPos(TS(16), TS(30))
    subtitleLabel:SetText("Loading terminal state...")
    subtitleLabel:SizeToContents()
    styleLabel(subtitleLabel, 13, false, COL_TERM_DIM)
    FRAME.subtitleLabel = subtitleLabel

    local topBar = FRAME:Add("DPanel")
    topBar:Dock(TOP)
    topBar:SetTall(topBarTall)
    topBar:DockMargin(frameMargin, TS(54), frameMargin, TS(compactLayout and 6 or 8))
    topBar.Paint = function(_, w, h)
        draw.RoundedBox(TR(10), 0, 0, w, h, COL_TERM_PANEL)
    end

    local refreshButton = topBar:Add("DButton")
    refreshButton:Dock(RIGHT)
    refreshButton:SetWide(refreshButtonWide)
    refreshButton:SetText("Refresh")
    refreshButton.DoClick = function()
        sendAction("refresh", {})
    end

    nextServingButton = topBar:Add("DButton")
    nextServingButton:Dock(RIGHT)
    nextServingButton:SetWide(nextButtonWide)
    nextServingButton:DockMargin(0, 0, TS(compactLayout and 6 or 8), 0)
    nextServingButton:SetText("Next")
    nextServingButton.DoClick = function()
        sendAction("advance_now_serving", {})
    end

    nowServingLabel = topBar:Add("DLabel")
    nowServingLabel:Dock(RIGHT)
    nowServingLabel:SetWide(nowServingWide)
    nowServingLabel:SetContentAlignment(6)
    nowServingLabel:SetText(formatNowServingLabel(0))

    vendorStatusButton = topBar:Add("DButton")
    vendorStatusButton:Dock(RIGHT)
    vendorStatusButton:SetWide(vendorStatusWide)
    vendorStatusButton:DockMargin(0, 0, TS(compactLayout and 6 or 8), 0)
    vendorStatusButton:SetText("Enable Vendor Status")
    vendorStatusButton.DoClick = function()
        sendAction("set_vendor_status", {})
    end

    statusLabel = topBar:Add("DLabel")
    statusLabel:Dock(FILL)
    statusLabel:SetText("Loading terminal state...")

    local shell = FRAME:Add("DPanel")
    shell:Dock(FILL)
    shell:DockMargin(frameMargin, 0, frameMargin, frameMargin)
    shell.Paint = function() end

    local left = shell:Add("DPanel")
    left:Dock(LEFT)
    left:SetWide(leftWide)
    left:DockMargin(0, 0, panelGap, 0)
    left.Paint = function(_, w, h)
        draw.RoundedBox(TR(10), 0, 0, w, h, COL_TERM_PANEL)
    end

    local center = shell:Add("DPanel")
    center:Dock(FILL)
    center:DockMargin(0, 0, panelGap, 0)
    center.Paint = function(_, w, h)
        draw.RoundedBox(TR(10), 0, 0, w, h, COL_TERM_PANEL)
    end

    local right = shell:Add("DPanel")
    right:Dock(RIGHT)
    right:SetWide(rightWide)
    right.Paint = function(_, w, h)
        draw.RoundedBox(TR(10), 0, 0, w, h, COL_TERM_PANEL)
    end

    local nearbyLabel = left:Add("DLabel")
    nearbyLabel:Dock(TOP)
    nearbyLabel:DockMargin(TS(10), TS(10), TS(10), TS(4))
    nearbyLabel:SetText("Nearby Players")

    nearbyList = left:Add("DListView")
    nearbyList:Dock(FILL)
    nearbyList:DockMargin(TS(10), 0, TS(10), 0)
    nearbyList:AddColumn("Player")
    nearbyList:AddColumn("Dist"):SetFixedWidth(nearbyDistWide)
    nearbyList:AddColumn("Access"):SetFixedWidth(nearbyAccessWide)
    nearbyList:AddColumn("State"):SetFixedWidth(nearbyStateWide)
    nearbyList.OnRowSelected = function(_, _, row)
        SELECTED_PLAYER_SID64 = tostring(row.tradeTargetSID64 or "")
    end

    local nearbyButtons = left:Add("DPanel")
    nearbyButtons:Dock(BOTTOM)
    nearbyButtons:SetTall(nearbyButtonsTall)
    nearbyButtons:DockMargin(TS(10), 6, TS(10), TS(10))
    nearbyButtons.Paint = function() end

    local startButton = nearbyButtons:Add("DButton")
    startButton:Dock(TOP)
    startButton:SetTall(actionButtonTall)
    startButton:SetText("Start Trade Session")
    startButton.DoClick = function()
        if SELECTED_PLAYER_SID64 == "" then return end
        sendAction("start_session", { target_sid64 = SELECTED_PLAYER_SID64 })
    end

    local ticketButton = nearbyButtons:Add("DButton")
    ticketButton:Dock(TOP)
    ticketButton:SetTall(actionButtonTall)
    ticketButton:DockMargin(0, 4, 0, 0)
    ticketButton:SetText("Issue Service Ticket")
    ticketButton.DoClick = function()
        local targetSID64 = tostring(SELECTED_PLAYER_SID64 or "")
        if targetSID64 == "" then
            targetSID64 = tostring(STATE and STATE.active_session and STATE.active_session.player_sid64 or "")
        end
        if targetSID64 == "" then return end
        sendAction("issue_ticket", { target_sid64 = targetSID64 })
    end

    local grantButton = nearbyButtons:Add("DButton")
    grantButton:Dock(TOP)
    grantButton:SetTall(actionButtonTall)
    grantButton:DockMargin(0, 4, 0, 0)
    grantButton:SetText("Grant Trader Access")
    grantButton.DoClick = function()
        if SELECTED_PLAYER_SID64 == "" then return end
        sendAction("grant_access", { target_sid64 = SELECTED_PLAYER_SID64 })
    end

    local revokeButton = nearbyButtons:Add("DButton")
    revokeButton:Dock(TOP)
    revokeButton:SetTall(actionButtonTall)
    revokeButton:DockMargin(0, 4, 0, 0)
    revokeButton:SetText("Revoke Trader Access")
    revokeButton.DoClick = function()
        if SELECTED_PLAYER_SID64 == "" then return end
        sendAction("revoke_access", { target_sid64 = SELECTED_PLAYER_SID64 })
    end

    local sessionLabel = center:Add("DLabel")
    sessionLabel:Dock(TOP)
    sessionLabel:DockMargin(TS(10), TS(10), TS(10), TS(4))
    sessionLabel:SetText("Active Session")

    local sessionSplit = center:Add("DPanel")
    sessionSplit:Dock(FILL)
    sessionSplit:DockMargin(TS(10), 0, TS(10), TS(10))
    sessionSplit.Paint = function() end

    local playerOfferWrap = sessionSplit:Add("DPanel")
    playerOfferWrap:Dock(LEFT)
    playerOfferWrap:SetWide(playerOfferWide)
    playerOfferWrap:DockMargin(0, 0, 6, 0)
    playerOfferWrap.Paint = function() end

    local traderOfferWrap = sessionSplit:Add("DPanel")
    traderOfferWrap:Dock(FILL)
    traderOfferWrap.Paint = function() end

    sessionPlayerOfferView = createTradePreview(playerOfferWrap, "Player Basket", "Player has not added any payment items.")
    sessionPlayerOfferView:Dock(FILL)

    sessionTraderOfferView = createTradePreview(traderOfferWrap, "Trader Offer", "Trader has not listed any reward items.", function(index)
        SELECTED_OFFER_INDEX = tonumber(index)
        if IsValid(sessionTraderOfferView) then
            sessionTraderOfferView:SetSelectedIndex(SELECTED_OFFER_INDEX)
        end
    end)
    sessionTraderOfferView:Dock(FILL)

    local traderButtons = traderOfferWrap:Add("DPanel")
    traderButtons:Dock(BOTTOM)
    traderButtons:SetTall(traderButtonsTall)
    traderButtons:DockMargin(0, 6, 0, 0)
    traderButtons.Paint = function() end

    local completeButton = traderButtons:Add("DButton")
    completeButton:Dock(TOP)
    completeButton:SetTall(actionButtonTall)
    completeButton:SetText("Complete Trade")
    completeButton.DoClick = function()
        sendAction("complete_trade", {})
    end

    local cancelButton = traderButtons:Add("DButton")
    cancelButton:Dock(TOP)
    cancelButton:SetTall(actionButtonTall)
    cancelButton:DockMargin(0, 4, 0, 0)
    cancelButton:SetText("Cancel Trade")
    cancelButton.DoClick = function()
        sendAction("cancel_session", {})
    end

    local clearButton = traderButtons:Add("DButton")
    clearButton:Dock(LEFT)
    clearButton:DockMargin(0, 8, 4, 0)
    clearButton:SetWide(sessionActionWide)
    clearButton:SetText("Clear Offer")
    clearButton.DoClick = function()
        sendAction("clear_offer", {})
    end

    local removeButton = traderButtons:Add("DButton")
    removeButton:Dock(FILL)
    removeButton:DockMargin(4, 8, 0, 0)
    removeButton:SetText("Remove Selected")
    removeButton.DoClick = function()
        if not SELECTED_OFFER_INDEX then return end
        sendAction("remove_offer_index", { index = SELECTED_OFFER_INDEX })
    end

    local catalogLabel = right:Add("DLabel")
    catalogLabel:Dock(TOP)
    catalogLabel:DockMargin(TS(10), TS(10), TS(10), TS(4))
    catalogLabel:SetText("Catalog")

    catalogSearchEntry = right:Add("DTextEntry")
    catalogSearchEntry:Dock(TOP)
    catalogSearchEntry:DockMargin(TS(10), 0, TS(10), TS(4))
    catalogSearchEntry:SetPlaceholderText("Search catalog...")
    catalogSearchEntry.OnChange = function()
        refreshCatalogList()
    end

    catalogList = right:Add("DListView")
    catalogList:Dock(TOP)
    catalogList:SetTall(catalogTall)
    catalogList:DockMargin(TS(10), 0, TS(10), 0)
    catalogList:AddColumn("Item")
    catalogList:AddColumn("Class")
    catalogList.OnRowSelected = function(_, _, row)
        SELECTED_CATALOG_CLASS = tostring(row.tradeCatalogClass or "")
    end

    local catalogControls = right:Add("DPanel")
    catalogControls:Dock(TOP)
    catalogControls:SetTall(32)
    catalogControls:DockMargin(TS(10), 6, TS(10), 10)
    catalogControls.Paint = function() end

    catalogCountWang = catalogControls:Add("DNumberWang")
    catalogCountWang:Dock(LEFT)
    catalogCountWang:SetWide(56)
    catalogCountWang:SetMinMax(1, 32)
    catalogCountWang:SetValue(1)

    local addOfferButton = catalogControls:Add("DButton")
    addOfferButton:Dock(FILL)
    addOfferButton:DockMargin(6, 0, 0, 0)
    addOfferButton:SetText("Add Selected To Offer")
    addOfferButton.DoClick = function()
        if SELECTED_CATALOG_CLASS == "" then return end
        sendAction("add_offer_item", {
            class = SELECTED_CATALOG_CLASS,
            count = math.max(1, math.floor(tonumber(catalogCountWang:GetValue()) or 1)),
        })
    end

    local presetLabel = right:Add("DLabel")
    presetLabel:Dock(TOP)
    presetLabel:DockMargin(TS(10), 0, TS(10), TS(4))
    presetLabel:SetText("Preset Trades")

    presetList = right:Add("DListView")
    presetList:Dock(TOP)
    presetList:SetTall(presetTall)
    presetList:DockMargin(TS(10), 0, TS(10), TS(4))
    presetList:AddColumn("Preset")
    presetList:AddColumn("Pays"):SetFixedWidth(48)
    presetList:AddColumn("Gives"):SetFixedWidth(48)
    presetList:AddColumn("Cooldown"):SetFixedWidth(78)
    presetList.OnRowSelected = function(_, _, row)
        SELECTED_PRESET_ID = tostring(row.tradePresetID or "")
        loadPresetDraft(findPresetByID(SELECTED_PRESET_ID))
        refreshPresetItemList()
    end

    local presetInfoLabel = right:Add("DLabel")
    presetInfoLabel:Dock(TOP)
    presetInfoLabel:DockMargin(TS(10), 0, TS(10), TS(8))
    presetInfoLabel:SetWrap(true)
    presetInfoLabel:SetAutoStretchVertical(true)
    presetInfoLabel:SetText("Preset drafting now opens in a dedicated editor window so class search, barter entries, and reward lists stay readable.")

    local presetButtons = right:Add("DPanel")
    presetButtons:Dock(BOTTOM)
    presetButtons:SetTall(presetButtonsTall)
    presetButtons:DockMargin(TS(10), 6, TS(10), TS(10))
    presetButtons.Paint = function() end

    local presetEditRow = presetButtons:Add("DPanel")
    presetEditRow:Dock(TOP)
    presetEditRow:SetTall(actionButtonTall)
    presetEditRow.Paint = function() end

    local presetNewButton = presetEditRow:Add("DButton")
    presetNewButton:Dock(LEFT)
    presetNewButton:SetWide(TS(140))
    presetNewButton:SetText("New Draft")
    presetNewButton.DoClick = function()
        SELECTED_PRESET_ID = ""
        loadPresetDraft(nil)
        refreshPresetItemList()
        openPresetEditor()
    end

    local presetEditButton = presetEditRow:Add("DButton")
    presetEditButton:Dock(FILL)
    presetEditButton:DockMargin(TS(6), 0, 0, 0)
    presetEditButton:SetText("Open Preset Editor")
    presetEditButton.DoClick = function()
        local preset = findPresetByID(SELECTED_PRESET_ID)
        openPresetEditor(preset)
    end

    local presetActionRow = presetButtons:Add("DPanel")
    presetActionRow:Dock(TOP)
    presetActionRow:SetTall(actionButtonTall)
    presetActionRow:DockMargin(0, TS(6), 0, 0)
    presetActionRow.Paint = function() end

    local presetDeleteButton = presetActionRow:Add("DButton")
    presetDeleteButton:Dock(LEFT)
    presetDeleteButton:SetWide(TS(140))
    presetDeleteButton:SetText("Delete Selected")
    presetDeleteButton.DoClick = function()
        if SELECTED_PRESET_ID == "" then return end
        sendAction("delete_preset", { preset_id = SELECTED_PRESET_ID })
    end

    local presetApplyButton = presetActionRow:Add("DButton")
    presetApplyButton:Dock(FILL)
    presetApplyButton:DockMargin(TS(6), 0, 0, 0)
    presetApplyButton:SetText("Apply Selected Preset")
    presetApplyButton.DoClick = function()
        if SELECTED_PRESET_ID == "" then return end
        sendAction("apply_preset", { preset_id = SELECTED_PRESET_ID })
    end

    styleLabel(nearbyLabel, 14, true, COL_TERM_TEXT)
    styleLabel(sessionLabel, 14, true, COL_TERM_TEXT)
    styleLabel(catalogLabel, 14, true, COL_TERM_TEXT)
    styleLabel(presetLabel, 14, true, COL_TERM_TEXT)
    styleLabel(presetInfoLabel, 12, false, COL_TERM_DIM)
    styleLabel(statusLabel, 12, false, COL_TERM_TEXT, 4)
    styleLabel(nowServingLabel, 12, true, COL_TERM_TEXT, 6)

    styleButton(refreshButton, COL_TERM_ACCENT)
    styleButton(nextServingButton, COL_TERM_ACCENT)
    styleButton(vendorStatusButton, COL_TERM_ACCENT)
    styleButton(startButton, COL_TERM_ACCENT)
    styleButton(ticketButton, COL_TERM_ACCENT)
    styleButton(grantButton)
    styleButton(revokeButton)
    styleButton(completeButton, COL_TERM_ACCENT)
    styleButton(cancelButton)
    styleButton(clearButton)
    styleButton(removeButton)
    styleButton(addOfferButton, COL_TERM_ACCENT)
    styleButton(presetNewButton)
    styleButton(presetEditButton, COL_TERM_ACCENT)
    styleButton(presetDeleteButton)
    styleButton(presetApplyButton, COL_TERM_ACCENT)

    styleEntry(catalogSearchEntry)
    styleEntry(catalogCountWang)

    styleListView(nearbyList)
    styleListView(catalogList)
    styleListView(presetList)

    refreshCatalogList()
    return FRAME
end

local function applyState(snapshot, shouldOpen)
    STATE = istable(snapshot) and snapshot or {}

    if shouldOpen then
        ensureFrame()
    elseif not IsValid(FRAME) then
        return
    end

    refreshNearbyList()
    refreshPresetList()
    refreshPresetItemList()
    refreshSessionLists()
    refreshCatalogList()
    refreshPresetEditorCatalogList()

    if IsValid(nowServingLabel) then
        nowServingLabel:SetText(formatNowServingLabel(
            STATE and STATE.now_serving_number or 0,
            STATE and STATE.waiting_ticket_count or 0
        ))
    end

    if IsValid(nextServingButton) then
        local canAdvance = (STATE and STATE.can_use) == true and (STATE and STATE.can_advance_now_serving) == true
        nextServingButton:SetText(((STATE and STATE.waiting_ticket_count) or 0) > 0 and "Next" or "Queue Empty")
        nextServingButton:SetEnabled(canAdvance)
    end

    if IsValid(vendorStatusButton) then
        local active = STATE and STATE.vendor_status_active == true
        local inSafeZone = STATE and STATE.in_safe_zone == true
        if active then
            vendorStatusButton:SetText("Vendor Status Active")
            vendorStatusButton:SetEnabled(false)
        elseif inSafeZone then
            vendorStatusButton:SetText("Enable Vendor Status")
            vendorStatusButton:SetEnabled(true)
        else
            vendorStatusButton:SetText("Vendor Status: Safe Zone Only")
            vendorStatusButton:SetEnabled(false)
        end
    end

    if IsValid(FRAME) and IsValid(FRAME.subtitleLabel) then
        local subtitle = (STATE and STATE.can_manage) and "Staff controls and live queue" or "Player-facing terminal"
        if STATE and tostring(STATE.safe_zone_name or "") ~= "" then
            subtitle = subtitle .. " - " .. tostring(STATE.safe_zone_name)
        end

        FRAME.subtitleLabel:SetText(subtitle)
        FRAME.subtitleLabel:SizeToContents()
    end
end

net.Receive(NET_OPEN, function()
    local snapshot = util.JSONToTable(net.ReadString() or "") or {}
    applyState(snapshot, true)
end)

net.Receive(NET_STATE, function()
    local snapshot = util.JSONToTable(net.ReadString() or "") or {}
    applyState(snapshot, false)
end)