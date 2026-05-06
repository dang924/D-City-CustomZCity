if SERVER then return end

ZSCAV = ZSCAV or {}

local REFRESH_INTERVAL = 0.15
local GRID_LABELS = {
    backpack = "Backpack",
    pocket = "Pockets",
    secure = "Secure Container",
    vest = "Tactical Rig",
}

local function GetSlotCandidates(expected)
    local candidates = ZSCAV.GetCompatibleWeaponSlots and ZSCAV:GetCompatibleWeaponSlots(expected) or nil
    if not istable(candidates) or #candidates <= 0 then return nil end
    return candidates
end

local function GetInv()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end
    return ply:GetNetVar("ZScavInv", nil)
end

local function SendAction(action, args)
    net.Start("ZScavInvAction")
        net.WriteString(action)
        net.WriteTable(args or {})
    net.SendToServer()
end

local function SendContainerAction(action, args)
    net.Start("ZScavContainerAction")
        net.WriteString(action)
        net.WriteTable(args or {})
    net.SendToServer()
end

local function PrettyName(class)
    class = tostring(class or "")

    local wep = weapons.Get(class)
    if wep and wep.PrintName and wep.PrintName ~= "" then return wep.PrintName end

    local gear = ZSCAV:GetGearDef(class)
    if gear and gear.name then return gear.name end

    local meta = ZSCAV.GetItemMeta and ZSCAV:GetItemMeta(class) or nil
    if meta and meta.name then return meta.name end

    return class
end

local function CopyRef(ref)
    return table.Copy(ref or {})
end

local function BuildRefFromEntry(ref, entry, location)
    local out = CopyRef(ref)
    out.weapon_uid = tostring(entry and entry.weapon_uid or out.weapon_uid or "")
    out.class = tostring(entry and entry.class or out.class or "")

    if location == "slot" then
        out.slot = tostring(ref.slot or "")
        out.grid = nil
        out.index = nil
        out.grid_x = nil
        out.grid_y = nil
        out.target_uid = nil
        out.target_index = nil
        return out
    end

    if location == "container" then
        out.target_uid = tostring(ref and (ref.target_uid or ref.container_uid) or out.target_uid or "")
        out.target_index = tonumber(ref and (ref.target_index or ref.container_index) or out.target_index)
        out.container_class = tostring(ref and ref.container_class or out.container_class or "")
        out.slot = nil
        out.grid = nil
        out.index = nil
        out.grid_x = nil
        out.grid_y = nil
        return out
    end

    out.grid = tostring(ref.grid or out.grid or "")
    out.index = tonumber(ref.index or out.index)
    out.grid_x = tonumber(entry and entry.x or ref.grid_x)
    out.grid_y = tonumber(entry and entry.y or ref.grid_y)
    return out
end

local function ResolveContainerWeaponEntry(ref)
    if not ZSCAV.GetOpenContainerStates then return nil end

    local states = ZSCAV.GetOpenContainerStates()
    if not istable(states) then return nil end

    local targetUID = tostring(ref and (ref.target_uid or ref.container_uid) or "")
    local targetIndex = tonumber(ref and (ref.target_index or ref.container_index))
    local weaponUID = tostring(ref and ref.weapon_uid or "")

    local function matches(entry)
        if not (istable(entry) and entry.class) then return false end
        if weaponUID ~= "" and tostring(entry.weapon_uid or "") ~= weaponUID then
            return false
        end
        return true
    end

    local function buildRef(uid, index, entry, state)
        return BuildRefFromEntry({
            target_uid = uid,
            target_index = index,
            container_class = state and state.class,
        }, entry, "container")
    end

    local function findInState(uid, state)
        if not (uid ~= "" and istable(state)) then return nil end

        local contents = state.contents or {}
        if targetIndex then
            local indexedEntry = contents[targetIndex]
            if matches(indexedEntry) then
                return indexedEntry, buildRef(uid, targetIndex, indexedEntry, state)
            end
        end

        if weaponUID ~= "" then
            for index, entry in ipairs(contents) do
                if matches(entry) then
                    return entry, buildRef(uid, index, entry, state)
                end
            end
        end

        return nil
    end

    if targetUID ~= "" then
        local entry, resolvedRef = findInState(targetUID, states[targetUID])
        if entry then return entry, resolvedRef end
    end

    if weaponUID ~= "" then
        for uid, state in pairs(states) do
            if uid ~= targetUID then
                local entry, resolvedRef = findInState(uid, state)
                if entry then return entry, resolvedRef end
            end
        end
    end

    return nil
end

local function ResolveWeaponEntry(inv, ref)
    if not (istable(inv) and istable(ref)) then return nil end

    local weaponUID = tostring(ref.weapon_uid or "")
    if weaponUID ~= "" then
        for slotName, entry in pairs(inv.weapons or {}) do
            if entry and tostring(entry.weapon_uid or "") == weaponUID then
                return entry, BuildRefFromEntry({ slot = slotName }, entry, "slot")
            end
        end

        for _, gridName in ipairs({ "vest", "backpack", "pocket", "secure" }) do
            for index, entry in ipairs(inv[gridName] or {}) do
                if entry and tostring(entry.weapon_uid or "") == weaponUID then
                    return entry, BuildRefFromEntry({ grid = gridName, index = index }, entry, "grid")
                end
            end
        end
    end

    local slot = tostring(ref.slot or "")
    if slot ~= "" then
        local entry = inv.weapons and inv.weapons[slot]
        if entry then
            return entry, BuildRefFromEntry({ slot = slot }, entry, "slot")
        end
    end

    local containerEntry, containerRef = ResolveContainerWeaponEntry(ref)
    if containerEntry then
        return containerEntry, containerRef
    end

    local grid = tostring(ref.grid or "")
    local index = tonumber(ref.index)
    if grid ~= "" and index then
        local entry = inv[grid] and inv[grid][index]
        if entry then
            return entry, BuildRefFromEntry({ grid = grid, index = index }, entry, "grid")
        end
    end

    local wantedClass = tostring(ref.class or "")
    local wantedX = tonumber(ref.grid_x)
    local wantedY = tonumber(ref.grid_y)
    if grid ~= "" and wantedClass ~= "" and wantedX ~= nil and wantedY ~= nil then
        for actualIndex, entry in ipairs(inv[grid] or {}) do
            if entry and tostring(entry.class or "") == wantedClass
                and tonumber(entry.x) == wantedX
                and tonumber(entry.y) == wantedY then
                return entry, BuildRefFromEntry({ grid = grid, index = actualIndex }, entry, "grid")
            end
        end
    end

    return nil
end

local function ResolvePreviewModel(className)
    className = ZSCAV.GetWeaponBaseClass and ZSCAV:GetWeaponBaseClass(className) or tostring(className or "")
    local stored = weapons.GetStored(className) or weapons.Get(className)
    if not stored then return nil end

    local model = tostring(stored.WorldModel or stored.ViewModel or "")
    if model == "" or not util.IsValidModel(model) then
        return nil
    end

    return model
end

local function ConfigurePreview(panel, modelPath)
    if not IsValid(panel) then return end
    if not modelPath or modelPath == "" then
        panel:SetVisible(false)
        return
    end

    panel:SetVisible(true)
    panel:SetModel(modelPath)
    panel.LayoutEntity = function() end

    local ent = panel.Entity
    if not IsValid(ent) then return end

    local mins, maxs = ent:GetRenderBounds()
    local center = (mins + maxs) * 0.5
    local size = math.max((maxs - mins):Length(), 16)
    panel:SetFOV(34)
    panel:SetLookAt(center)
    panel:SetCamPos(center + Vector(size * 1.2, size * 0.55, size * 0.35))
end

local function PredictEquipRef(inv, entry)
    if not (istable(inv) and istable(entry)) then return nil end

    local expected = ZSCAV:GetEquipWeaponSlot(entry.class)
    local candidates = GetSlotCandidates(expected)
    if not candidates then return nil end

    for _, slotName in ipairs(candidates) do
        if not (inv.weapons and inv.weapons[slotName]) then
            return {
                slot = slotName,
                weapon_uid = tostring(entry.weapon_uid or ""),
                class = tostring(entry.class or ""),
            }
        end
    end

    return nil
end

local function HasAttachmentPlacement(className, placement)
    className = ZSCAV.GetWeaponBaseClass and ZSCAV:GetWeaponBaseClass(className) or tostring(className or "")
    local stored = weapons.GetStored(className)
    return istable(stored) and istable(stored.availableAttachments) and istable(stored.availableAttachments[placement])
end

local function CollectAttachmentInventorySignature(inv)
    local out = {}
    if not istable(inv) then return out end

    for _, gridName in ipairs({ "backpack", "pocket", "vest", "secure" }) do
        for index, entry in ipairs(inv[gridName] or {}) do
            if entry and entry.class and ZSCAV:IsAttachmentItemClass(entry) then
                out[#out + 1] = {
                    kind = "grid",
                    grid = gridName,
                    index = index,
                    class = entry.class,
                }
            end
        end
    end

    return out
end

local function CollectCompatibleAttachments(inv, className, placement)
    local out = {}
    local allowed = {}
    local options = ZSCAV:BuildWeaponAttachmentOptions(className)

    for _, option in ipairs(options[placement] or {}) do
        local key = ZSCAV:NormalizeAttachmentKey(option.key)
        if key ~= "" then
            allowed[key] = true
        end
    end

    for _, gridName in ipairs({ "backpack", "pocket", "vest", "secure" }) do
        for index, entry in ipairs(inv[gridName] or {}) do
            if entry and entry.class and ZSCAV:IsAttachmentItemClass(entry) then
                local attKey = ZSCAV:NormalizeAttachmentKey(entry)
                if allowed[attKey] then
                    out[#out + 1] = {
                        label = string.format("%s - %s", PrettyName(entry.actual_class or entry.class), GRID_LABELS[gridName] or gridName),
                        grid = gridName,
                        index = index,
                        key = attKey,
                    }
                end
            end
        end
    end

    table.sort(out, function(left, right)
        local leftLabel = string.lower(tostring(left.label or ""))
        local rightLabel = string.lower(tostring(right.label or ""))
        if leftLabel ~= rightLabel then
            return leftLabel < rightLabel
        end

        local leftSource = string.format("%s:%s:%s", tostring(left.grid or left.from_uid or ""), tostring(left.index or left.from_index or ""), tostring(left.key or ""))
        local rightSource = string.format("%s:%s:%s", tostring(right.grid or right.from_uid or ""), tostring(right.index or right.from_index or ""), tostring(right.key or ""))
        return leftSource < rightSource
    end)

    return out
end

local function CreateActionButton(parent, leftMargin, text, onClick)
    local button = parent:Add("DButton")
    button:Dock(LEFT)
    button:DockMargin(leftMargin or 0, 0, 0, 0)
    button:SetWide(Nexus:Scale(118))
    button:SetText("")
    button._label = text or ""
    button.DoClick = onClick
    button.Paint = function(self, w, h)
        local bg = self:IsDown() and Color(122, 94, 48, 235)
            or self:IsHovered() and Color(114, 88, 46, 220)
            or Color(76, 63, 40, 205)
        draw.RoundedBox(8, 0, 0, w, h, bg)
        draw.SimpleText(self._label, Nexus:GetFont(14, nil, true), w * 0.5, h * 0.5, Color(245, 240, 228), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return button
end

function ZSCAV.CloseWeaponInspect()
    if IsValid(ZSCAV.WeaponInspectFrame) then
        ZSCAV.WeaponInspectFrame:Remove()
    end
end

function ZSCAV.OpenWeaponInspect(ref)
    local inv = GetInv()
    local entry, resolvedRef = ResolveWeaponEntry(inv, ref)
    if not (entry and resolvedRef) then return end

    ZSCAV.CloseWeaponInspect()

    local parent = IsValid(ZSCAV.InventoryPanelRef) and ZSCAV.InventoryPanelRef or nil
    local frame = vgui.Create("DFrame", parent)
    ZSCAV.WeaponInspectFrame = frame
    frame:SetSize(Nexus:Scale(900), Nexus:Scale(590))
    frame:Center()
    frame:SetDraggable(true)
    frame:MakePopup()
    frame:SetDeleteOnClose(true)
    frame:SetTitle("")
    frame:ShowCloseButton(true)
    frame.ref = CopyRef(resolvedRef)
    frame._missingSince = nil
    frame._nextRefresh = 0
    frame._lastSignature = nil

    frame.OnRemove = function(self)
        if ZSCAV.WeaponInspectFrame == self then
            ZSCAV.WeaponInspectFrame = nil
        end
    end

    frame.Paint = function(self, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(18, 22, 26, 242))
        surface.SetDrawColor(8, 10, 12, 230)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.RoundedBoxEx(12, 0, 0, w, Nexus:Scale(44), Color(26, 31, 36, 250), true, true, false, false)
    end

    frame.btnClose:SetText("")
    frame.btnClose.Paint = function(self, w, h)
        draw.SimpleText("x", Nexus:GetFont(18, nil, true), w * 0.5, h * 0.5, self:IsHovered() and Color(255, 235, 235) or Color(214, 210, 198), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local title = frame:Add("DLabel")
    title:SetFont(Nexus:GetFont(18, nil, true))
    title:SetTextColor(Color(242, 238, 228))
    title:SetPos(Nexus:Scale(16), Nexus:Scale(10))
    title:SetText("Weapon Inspect")
    title:SizeToContents()
    frame.titleLabel = title

    local subTitle = frame:Add("DLabel")
    subTitle:SetFont(Nexus:GetFont(13))
    subTitle:SetTextColor(Color(176, 180, 186))
    subTitle:SetPos(Nexus:Scale(16), Nexus:Scale(28))
    subTitle:SetText("")
    subTitle:SizeToContents()
    frame.subTitleLabel = subTitle

    local left = frame:Add("DPanel")
    left:SetPos(Nexus:Scale(16), Nexus:Scale(58))
    left:SetSize(Nexus:Scale(288), Nexus:Scale(516))
    left.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(26, 31, 36, 235))
    end

    local preview = left:Add("DModelPanel")
    preview:SetPos(Nexus:Scale(12), Nexus:Scale(12))
    preview:SetSize(left:GetWide() - Nexus:Scale(24), Nexus:Scale(272))
    preview.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(14, 17, 20, 235))
        if IsValid(self.Entity) then
            self:DrawModel()
        else
            draw.SimpleText("No preview model", Nexus:GetFont(13), w * 0.5, h * 0.5, Color(156, 160, 166), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    frame.previewPanel = preview

    local info = left:Add("DPanel")
    info:SetPos(Nexus:Scale(12), Nexus:Scale(296))
    info:SetSize(left:GetWide() - Nexus:Scale(24), Nexus:Scale(92))
    info.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(14, 17, 20, 235))
    end

    local locationLabel = info:Add("DLabel")
    locationLabel:SetFont(Nexus:GetFont(14, nil, true))
    locationLabel:SetTextColor(Color(225, 228, 218))
    locationLabel:SetPos(Nexus:Scale(10), Nexus:Scale(10))
    locationLabel:SetText("")
    locationLabel:SizeToContents()
    frame.locationLabel = locationLabel

    local attachmentSummary = info:Add("DLabel")
    attachmentSummary:SetFont(Nexus:GetFont(13))
    attachmentSummary:SetTextColor(Color(166, 170, 176))
    attachmentSummary:SetPos(Nexus:Scale(10), Nexus:Scale(34))
    attachmentSummary:SetSize(info:GetWide() - Nexus:Scale(20), Nexus:Scale(46))
    attachmentSummary:SetWrap(true)
    attachmentSummary:SetAutoStretchVertical(true)
    frame.attachmentSummaryLabel = attachmentSummary

    local hint = left:Add("DLabel")
    hint:SetFont(Nexus:GetFont(12))
    hint:SetTextColor(Color(156, 160, 166))
    hint:SetPos(Nexus:Scale(12), Nexus:Scale(404))
    hint:SetSize(left:GetWide() - Nexus:Scale(24), Nexus:Scale(92))
    hint:SetWrap(true)
    hint:SetAutoStretchVertical(true)
    hint:SetText("Detach actions move attachments to backpack first, then pockets, then tactical rig. If no space is available, the weapon stays unchanged.")

    local right = frame:Add("DPanel")
    right:SetPos(Nexus:Scale(320), Nexus:Scale(58))
    right:SetSize(frame:GetWide() - Nexus:Scale(336), Nexus:Scale(516))
    right.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(26, 31, 36, 235))
    end

    local actions = right:Add("DPanel")
    actions:Dock(TOP)
    actions:SetTall(Nexus:Scale(42))
    actions:DockMargin(Nexus:Scale(12), Nexus:Scale(12), Nexus:Scale(12), Nexus:Scale(10))
    actions.Paint = nil

    local scroll = right:Add("DScrollPanel")
    scroll:Dock(FILL)
    scroll:DockMargin(Nexus:Scale(12), 0, Nexus:Scale(12), Nexus:Scale(12))
    do
        local bar = scroll:GetVBar()
        if bar then bar:SetWide(Nexus:Scale(8)) end
    end
    frame.slotCanvas = scroll:GetCanvas()

    function frame:GetActionArgs(extra)
        local args = CopyRef(self.ref)
        args.weapon_uid = tostring(args.weapon_uid or "")
        if istable(extra) then
            for key, value in pairs(extra) do
                args[key] = value
            end
        end
        return args
    end

    function frame:BuildSlotCard(container, entryData, invData, placement, currentKey)
        local card = container:Add("DPanel")
        card:Dock(TOP)
        card:SetTall(Nexus:Scale(116))
        card:DockMargin(0, 0, 0, Nexus:Scale(8))
        card.Paint = function(_, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(14, 17, 20, 235))
        end

        local slotTitle = card:Add("DLabel")
        slotTitle:Dock(TOP)
        slotTitle:DockMargin(Nexus:Scale(12), Nexus:Scale(10), Nexus:Scale(12), Nexus:Scale(4))
        slotTitle:SetFont(Nexus:GetFont(15, nil, true))
        slotTitle:SetTextColor(Color(236, 232, 220))
        slotTitle:SetText(ZSCAV:GetWeaponAttachmentSlotLabel(placement))
        slotTitle:SizeToContentsY()

        local currentRow = card:Add("DPanel")
        currentRow:Dock(TOP)
        currentRow:SetTall(Nexus:Scale(24))
        currentRow:DockMargin(Nexus:Scale(12), 0, Nexus:Scale(12), Nexus:Scale(8))
        currentRow.Paint = nil

        local currentText = currentRow:Add("DLabel")
        currentText:Dock(FILL)
        currentText:SetFont(Nexus:GetFont(13))
        currentText:SetTextColor(Color(174, 178, 184))
        currentText:SetText("Installed: " .. (currentKey ~= "" and ZSCAV:GetAttachmentName(currentKey) or "None"))

        if tostring(self.ref and self.ref.target_uid or "") ~= "" then
            local note = card:Add("DLabel")
            note:Dock(TOP)
            note:DockMargin(Nexus:Scale(12), 0, Nexus:Scale(12), 0)
            note:SetFont(Nexus:GetFont(12))
            note:SetTextColor(Color(138, 142, 148))
            note:SetWrap(true)
            note:SetAutoStretchVertical(true)
            note:SetText("Move this weapon into your inventory to modify attachments.")
            return
        end

        local canRemove = ZSCAV:CanRemoveWeaponAttachment(entryData.class, placement)
        if currentKey ~= "" then
            local detachButton = currentRow:Add("DButton")
            detachButton:Dock(RIGHT)
            detachButton:SetWide(Nexus:Scale(96))
            detachButton:SetText("")
            detachButton.Paint = function(self, w, h)
                local bg = canRemove and (self:IsHovered() and Color(96, 70, 42, 220) or Color(70, 52, 34, 205)) or Color(50, 54, 58, 180)
                draw.RoundedBox(6, 0, 0, w, h, bg)
                draw.SimpleText(canRemove and "Detach" or "Locked", Nexus:GetFont(12, nil, true), w * 0.5, h * 0.5, Color(242, 238, 228), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            detachButton.DoClick = function()
                if not canRemove then return end
                SendAction("inspect_attach_detach", self:GetActionArgs({ placement = placement }))
                self._nextRefresh = 0
            end
        end

        local compatible = CollectCompatibleAttachments(invData, entryData.class, placement)
        if #compatible == 0 then
            local empty = card:Add("DLabel")
            empty:Dock(TOP)
            empty:DockMargin(Nexus:Scale(12), 0, Nexus:Scale(12), 0)
            empty:SetFont(Nexus:GetFont(12))
            empty:SetTextColor(Color(138, 142, 148))
            empty:SetWrap(true)
            empty:SetAutoStretchVertical(true)
            empty:SetText("No compatible attachment items in your inventory or secure container.")
            return
        end

        local installRow = card:Add("DPanel")
        installRow:Dock(TOP)
        installRow:SetTall(Nexus:Scale(28))
        installRow:DockMargin(Nexus:Scale(12), 0, Nexus:Scale(12), 0)
        installRow.Paint = nil

        local combo = installRow:Add("DComboBox")
        combo:Dock(FILL)
        combo:SetValue("Choose attachment item")
        for index, item in ipairs(compatible) do
            combo:AddChoice(item.label, item, index == 1)
            if index == 1 then
                combo._selectedData = item
            end
        end
        combo.OnSelect = function(_, _, _, data)
            combo._selectedData = data
        end

        local install = installRow:Add("DButton")
        install:Dock(RIGHT)
        install:DockMargin(Nexus:Scale(8), 0, 0, 0)
        install:SetWide(Nexus:Scale(96))
        install:SetText("")
        install.Paint = function(self, w, h)
            local bg = self:IsHovered() and Color(92, 82, 48, 220) or Color(68, 62, 40, 205)
            draw.RoundedBox(6, 0, 0, w, h, bg)
            draw.SimpleText("Install", Nexus:GetFont(12, nil, true), w * 0.5, h * 0.5, Color(244, 240, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        install.DoClick = function()
            local selected = combo._selectedData
            if not selected then return end

            local args = self:GetActionArgs({
                placement = placement,
                attachment_key = ZSCAV:NormalizeAttachmentKey(selected.key or selected.entry),
            })

            args.attachment_grid = selected.grid
            args.attachment_index = selected.index
            SendAction("inspect_attach_install", args)

            self._nextRefresh = 0
        end
    end

    function frame:RefreshContents(force)
        local invData = GetInv()
        if not invData then
            self:Remove()
            return
        end

        local entryData, updatedRef = ResolveWeaponEntry(invData, self.ref)
        if not entryData then
            self._missingSince = self._missingSince or RealTime()
            if RealTime() - self._missingSince > 0.5 then
                self:Remove()
            end
            return
        end

        self._missingSince = nil
        self.ref = updatedRef

        local attachments = entryData.weapon_state and entryData.weapon_state.attachments or {}
        local signature = util.TableToJSON({
            ref = self.ref,
            class = entryData.class,
            attachments = attachments,
            attachment_items = CollectAttachmentInventorySignature(invData),
        }) or ""
        if not force and signature == self._lastSignature then
            return
        end
        self._lastSignature = signature

        self.titleLabel:SetText("Weapon Inspect: " .. PrettyName(entryData.class))
        self.titleLabel:SizeToContents()

        local size = ZSCAV:GetItemSize(entryData) or { w = 1, h = 1 }
        local weight = ZSCAV:GetItemWeight(entryData) or 0
        self.subTitleLabel:SetText(string.format("%dx%d | %.2f kg", tonumber(size.w) or 1, tonumber(size.h) or 1, tonumber(weight) or 0))
        self.subTitleLabel:SizeToContents()

        local location = self.ref.slot and ("Equipped: " .. string.upper(tostring(self.ref.slot)))
            or (tostring(self.ref.target_uid or "") ~= "" and ("Stored in " .. PrettyName(tostring((ZSCAV.GetOpenContainerState and ZSCAV.GetOpenContainerState(self.ref.target_uid) and ZSCAV.GetOpenContainerState(self.ref.target_uid).class) or self.ref.container_class or "container"))))
            or ("Stored in " .. string.upper(tostring(self.ref.grid or "inventory")))
        self.locationLabel:SetText(location)
        self.locationLabel:SizeToContents()

        local installedNames = {}
        for _, placement in ipairs(ZSCAV:GetWeaponAttachmentSlots()) do
            local attKey = ZSCAV:NormalizeAttachmentKey(attachments[placement])
            if attKey ~= "" then
                installedNames[#installedNames + 1] = ZSCAV:GetAttachmentName(attKey)
            end
        end
        self.attachmentSummaryLabel:SetText(#installedNames > 0 and ("Installed: " .. table.concat(installedNames, ", ")) or "Installed: None")

        local modelPath = ResolvePreviewModel(entryData.class)
        if modelPath ~= self._modelPath then
            self._modelPath = modelPath
            ConfigurePreview(self.previewPanel, modelPath)
        end

        actions:Clear()
        local equipText = self.ref.slot and "Unequip" or "Equip"
        local equipButton = CreateActionButton(actions, 0, equipText, function()
            local currentInv = GetInv()
            local currentEntry = select(1, ResolveWeaponEntry(currentInv, self.ref))
            if not currentEntry then return end

            local requestRef = CopyRef(self.ref)
            if self.ref.slot then
                SendAction("inspect_toggle_equip", requestRef)
                self:Remove()
                return
            end

            local predicted = PredictEquipRef(currentInv, currentEntry)
            SendAction("inspect_toggle_equip", requestRef)
            if predicted then
                self.ref = predicted
                self._nextRefresh = 0
            else
                self:Remove()
            end
        end)
        equipButton._label = equipText

        CreateActionButton(actions, Nexus:Scale(8), "Detach All", function()
            SendAction("inspect_attach_detach_all", self:GetActionArgs())
            self._nextRefresh = 0
        end)

        CreateActionButton(actions, Nexus:Scale(8), "Unload", function()
            SendAction("inspect_unload", self:GetActionArgs())
        end)

        local dropButton = CreateActionButton(actions, Nexus:Scale(8), "Drop Weapon", function()
            SendAction("inspect_drop_weapon", self:GetActionArgs())
            self:Remove()
        end)
        dropButton:SetWide(Nexus:Scale(128))

        self.slotCanvas:Clear()

        local slotCount = 0
        for _, placement in ipairs(ZSCAV:GetWeaponAttachmentSlots()) do
            local currentKey = ZSCAV:NormalizeAttachmentKey(attachments[placement])
            if HasAttachmentPlacement(entryData.class, placement) or currentKey ~= "" then
                slotCount = slotCount + 1
                self:BuildSlotCard(self.slotCanvas, entryData, invData, placement, currentKey)
            end
        end

        if slotCount == 0 then
            local empty = self.slotCanvas:Add("DLabel")
            empty:Dock(TOP)
            empty:DockMargin(Nexus:Scale(8), Nexus:Scale(12), Nexus:Scale(8), 0)
            empty:SetWrap(true)
            empty:SetAutoStretchVertical(true)
            empty:SetFont(Nexus:GetFont(13))
            empty:SetTextColor(Color(158, 162, 168))
            empty:SetText("This weapon has no configurable attachment slots.")
        end
    end

    frame.Think = function(self)
        if not IsValid(ZSCAV.InventoryPanelRef) then
            self:Remove()
            return
        end

        if RealTime() < (self._nextRefresh or 0) then return end
        self._nextRefresh = RealTime() + REFRESH_INTERVAL
        self:RefreshContents(false)
    end

    frame:RefreshContents(true)
 end
