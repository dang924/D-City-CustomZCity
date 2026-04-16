-- ZCity Buy Menu — Client
-- Opens a shop panel when the server sends ZC_BuyMenu_Open.

local shopItems   = {}
local killRewards = {}
local playerMoney = 0
local shopFrame   = nil
local canEditPrices = false
local canEditKillRewards = false
local sortAscending = false  -- false = high-to-low (default), true = low-to-high
local activePriceEditorRebuild = nil
local activeRewardEditorRebuild = nil

local COL_BG       = Color(15, 15, 15, 245)
local COL_HEADER   = Color(25, 25, 25, 255)
local COL_PANEL    = Color(22, 22, 22, 255)
local COL_ITEM     = Color(30, 30, 30, 255)
local COL_ITEM_HVR = Color(45, 45, 45, 255)
local COL_ACCENT   = Color(200, 150, 50, 255)
local COL_MONEY    = Color(100, 220, 100, 255)
local COL_TOO_POOR = Color(200, 60, 60, 255)
local COL_WHITE    = Color(255, 255, 255, 255)
local COL_GREY     = Color(160, 160, 160, 255)
local COL_DIVIDER  = Color(50, 50, 50, 255)

-- Use hg.attachmentsIcons as the definitive source of icons (keys like "supressor1", "holo1", etc.)
local function GetAttachmentIcons()
    return (hg and istable(hg.attachmentsIcons) and hg.attachmentsIcons) or {}
end

local DEFAULT_CATEGORIES = {
    "Weapons - Assault Rifles",
    "Weapons - Carbines",
    "Weapons - Explosive",
    "Weapons - Grenade Launchers",
    "Weapons - Machine-Pistols",
    "Weapons - Machineguns",
    "Weapons - Melee",
    "Weapons - Pistols",
    "Weapons - Shotguns",
    "Weapons - Sniper Rifles",
    "Medical",
    "Armor",
    "Attachments",
}

local CATEGORY_SHORT = {
    ["Weapons - Assault Rifles"] = "Assault Rifles",
    ["Weapons - Carbines"] = "Carbines",
    ["Weapons - Explosive"] = "Explosive",
    ["Weapons - Grenade Launchers"] = "Launchers",
    ["Weapons - Machine-Pistols"] = "Machine Pistols",
    ["Weapons - Machineguns"] = "Machineguns",
    ["Weapons - Melee"] = "Melee",
    ["Weapons - Pistols"] = "Pistols",
    ["Weapons - Shotguns"] = "Shotguns",
    ["Weapons - Sniper Rifles"] = "Snipers",
    Medical = "Medical",
    Armor = "Armor",
    Attachments = "Attachments",
}

local function CategoryShortName(cat)
    return CATEGORY_SHORT[cat] or tostring(cat or "Other")
end

local function PopulateCategoryChoices(combo, selectedCategory)
    if not IsValid(combo) then return end

    combo:Clear()
    for _, cat in ipairs(DEFAULT_CATEGORIES) do
        combo:AddChoice(CategoryShortName(cat), cat, cat == selectedCategory)
    end

    if isstring(selectedCategory) and selectedCategory ~= "" then
        local found = false
        for _, cat in ipairs(DEFAULT_CATEGORIES) do
            if cat == selectedCategory then
                found = true
                break
            end
        end

        if not found then
            combo:AddChoice(CategoryShortName(selectedCategory), selectedCategory, true)
        end

        combo:SetValue(CategoryShortName(selectedCategory))
    else
        combo:SetValue("Select tab...")
    end
end

local function ResolveAttachmentName(attKey)
    local dict = (hg and (hg.attachmentslaunguage or hg.attachmentslanguage)) or nil
    if istable(dict) and isstring(dict[attKey]) and dict[attKey] ~= "" then
        return dict[attKey]
    end
    -- Fallback: titlecase the key
    local s = string.gsub(tostring(attKey or ""), "_", " ")
    s = string.gsub(s, "(%a)([%w_']*)", function(a, b)
        return string.upper(a) .. string.lower(b)
    end)
    return s ~= "" and s or tostring(attKey or "")
end

local function GetWeaponAttachmentTable(wep)
    if not IsValid(wep) then return nil end
    if istable(wep.availableAttachments) then return wep.availableAttachments end

    local className = wep.GetClass and wep:GetClass() or nil
    if isstring(className) and className ~= "" then
        local stored = weapons.GetStored(className)
        if istable(stored) and istable(stored.availableAttachments) then
            return stored.availableAttachments
        end
    end

    return nil
end

local function IsMountTypeCompatible(availableMountType, attachmentMountType)
    if not availableMountType or not attachmentMountType then return false end
    if istable(availableMountType) then
        return table.HasValue(availableMountType, attachmentMountType)
    end
    return tostring(availableMountType) == tostring(attachmentMountType)
end

local function BuildEquippedAttachmentEntries(wep)
    local available = GetWeaponAttachmentTable(wep)
    if not istable(available) then return {} end

    local icons = GetAttachmentIcons()
    local hgAttachments = (hg and istable(hg.attachments) and hg.attachments) or {}
    local out = {}
    local seen = {}

    local function AddEntry(attKey, placement)
        if not isstring(attKey) then return end
        attKey = string.lower(attKey)
        if attKey == "" or attKey == "empty" or seen[attKey] then return end
        if not icons[attKey] then return end

        seen[attKey] = true
        out[#out + 1] = {
            key = attKey,
            name = ResolveAttachmentName(attKey),
            placement = tostring(placement or ""),
            icon = icons[attKey],
        }
    end

    for placement, options in pairs(available) do
        if not istable(options) then continue end
        -- Only iterate numeric (integer) keys - string keys are metadata (mount, mountType, etc.)
        for i = 1, #options do
            local option = options[i]
            if istable(option) and isstring(option[1]) then
                AddEntry(option[1], placement)
            end
        end

        -- ZCity supports mountType-based optic swaps even when not listed as numeric options.
        local placementTbl = hgAttachments[placement]
        local mountType = options.mountType
        if istable(placementTbl) and mountType then
            for key, attData in pairs(placementTbl) do
                if not isstring(key) or not istable(attData) then continue end
                if IsMountTypeCompatible(mountType, attData.mountType) then
                    AddEntry(key, placement)
                end
            end
        end

        -- Some weapons expose sparse underbarrel metadata. Make sure all underbarrel
        -- laser options are still listed in the quick-apply icon strip.
        if istable(placementTbl) and tostring(placement) == "underbarrel" then
            for key, attData in pairs(placementTbl) do
                if not isstring(key) then continue end
                local keyLower = string.lower(key)
                if not string.find(keyLower, "laser", 1, true) then continue end

                if mountType and istable(attData) and attData.mountType then
                    if IsMountTypeCompatible(mountType, attData.mountType) then
                        AddEntry(key, placement)
                    end
                elseif not mountType then
                    AddEntry(key, placement)
                end
            end
        end
    end

    -- Include currently installed attachments so users can swap even if the weapon table is sparse.
    if IsValid(wep) and istable(wep.attachments) then
        for placement, att in pairs(wep.attachments) do
            if istable(att) and isstring(att[1]) then
                AddEntry(att[1], placement)
            end
        end
    end

    table.sort(out, function(a, b)
        if a.placement ~= b.placement then return a.placement < b.placement end
        return a.name < b.name
    end)

    return out
end

-- ── Net receivers ─────────────────────────────────────────────────────────────

local function QueueBuyMenuRebuild()
    if not IsValid(shopFrame) or not shopFrame.RebuildItems then return end

    shopFrame:RebuildItems()

    timer.Simple(0.05, function()
        if not IsValid(shopFrame) or not shopFrame.RebuildItems then return end
        shopFrame:RebuildItems()
    end)

    timer.Simple(0.2, function()
        if not IsValid(shopFrame) or not shopFrame.RebuildItems then return end
        shopFrame:RebuildItems()
    end)
end

net.Receive("ZC_BuyMenu_MoneyUpdate", function()
    playerMoney = net.ReadInt(32)
    if IsValid(shopFrame) then
        shopFrame:UpdateMoney(playerMoney)
    end
end)

net.Receive("ZC_BuyMenu_PostPurchaseRefresh", function()
    QueueBuyMenuRebuild()
end)

net.Receive("ZC_BuyMenu_ItemList", function()
    shopItems = {}
    killRewards = {}
    local count = net.ReadUInt(16)
    for i = 1, count do
        shopItems[i] = {
            label    = net.ReadString(),
            class    = net.ReadString(),
            price    = net.ReadUInt(16),
            category = net.ReadString(),
            attKey   = net.ReadString(),  -- empty string for weapon items
            itemType = net.ReadString(),
            armorSlot = net.ReadString(),
            index    = i,
        }
    end
    playerMoney = net.ReadInt(32)
    canEditPrices = net.ReadBool()
    canEditKillRewards = net.ReadBool()

    local rewardCount = net.ReadUInt(16)
    for i = 1, rewardCount do
        killRewards[i] = {
            label = net.ReadString(),
            key = net.ReadString(),
            rewardType = net.ReadString(),
            defaultReward = net.ReadUInt(16),
            currentReward = net.ReadUInt(16),
        }
    end

    if IsValid(shopFrame) and shopFrame.RebuildItems then
        shopFrame:RebuildItems()
    end

    if isfunction(activePriceEditorRebuild) then
        activePriceEditorRebuild()
    end

    if isfunction(activeRewardEditorRebuild) then
        activeRewardEditorRebuild()
    end
end)

net.Receive("ZC_BuyMenu_Open", function()
    if IsValid(shopFrame) then shopFrame:Remove() end
    OpenBuyMenu()
end)

-- ── Buy menu panel ────────────────────────────────────────────────────────────

function OpenBuyMenu()
    if IsValid(shopFrame) then shopFrame:Remove() end

    local sw, sh = ScrW(), ScrH()
    local fw, fh = math.min(sw * 0.6, 760), math.min(sh * 0.78, 580)

    local categories = {}
    do
        local seen = {}
        for _, cat in ipairs(DEFAULT_CATEGORIES) do
            seen[cat] = true
            categories[#categories + 1] = cat
        end
        for _, item in ipairs(shopItems) do
            if item.category and item.category ~= "" and not seen[item.category] then
                seen[item.category] = true
                categories[#categories + 1] = item.category
            end
        end
    end

    local tabH       = 26
    local tabRows    = 3
    local tabsPerRow = math.max(1, math.ceil(#categories / tabRows))
    local headerH    = 36
    local tabAreaH   = tabH * tabRows
    local scrollY    = headerH + tabAreaH + 4
    local scrollH    = fh - scrollY - 8

    local frame = vgui.Create("DFrame")
    shopFrame   = frame
    frame:SetSize(fw, fh)
    frame:SetPos(sw / 2 - fw / 2, sh / 2 - fh / 2)
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:SetDeleteOnClose(true)
    frame:MakePopup()

    function frame:Paint(w, h)
        draw.RoundedBox(6, 0, 0, w, h, COL_BG)
        draw.RoundedBox(6, 0, 0, w, headerH, COL_HEADER)
        surface.SetDrawColor(COL_ACCENT)
        surface.DrawRect(0, headerH, w, 2)
    end

    -- ── Header ────────────────────────────────────────────────────────────────

    local titleLbl = vgui.Create("DLabel", frame)
    titleLbl:SetPos(12, 0)
    titleLbl:SetSize(fw - 80, headerH)
    titleLbl:SetText("ZCity Shop")
    titleLbl:SetFont("HomigradFontLarge")
    titleLbl:SetTextColor(COL_ACCENT)
    titleLbl:SetContentAlignment(4)

    local moneyLbl = vgui.Create("DLabel", frame)
    moneyLbl:SetPos(fw - 180, 0)
    moneyLbl:SetSize(160, headerH)
    moneyLbl:SetText("$" .. playerMoney)
    moneyLbl:SetFont("HomigradFontMedium")
    moneyLbl:SetTextColor(COL_MONEY)
    moneyLbl:SetContentAlignment(6)

    function frame:UpdateMoney(amount)
        playerMoney = amount
        moneyLbl:SetText("$" .. amount)
    end

    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(fw - 34, 6)
    closeBtn:SetSize(26, 24)
    closeBtn:SetText("✕")
    closeBtn:SetFont("HomigradFontMedium")
    closeBtn:SetTextColor(COL_GREY)
    function closeBtn:Paint(w, h)
        if self:IsHovered() then
            draw.RoundedBox(4, 0, 0, w, h, Color(80, 20, 20, 200))
        end
    end
    function closeBtn:DoClick() frame:Remove() end

    -- Sort toggle button
    local sortBtn = vgui.Create("DButton", frame)
    sortBtn:SetPos(fw - 110, 6)
    sortBtn:SetSize(26, 24)
    sortBtn:SetText("↕")
    sortBtn:SetFont("HomigradFontSmall")
    sortBtn:SetTextColor(COL_GREY)
    sortBtn:SetTooltip("Toggle price sort: High→Low / Low→High")
    function sortBtn:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(80, 80, 120, 200) or Color(40, 40, 60, 150))
    end
    function sortBtn:DoClick()
        sortAscending = not sortAscending
        frame:RebuildItems()
    end

    local function OpenPriceEditor()
        local editor = vgui.Create("DFrame")
        editor:SetSize(math.min(ScrW() * 0.65, 880), math.min(ScrH() * 0.78, 620))
        editor:Center()
        editor:SetTitle("Shop Price Editor")
        editor:MakePopup()
        editor.OnRemove = function()
            if activePriceEditorRebuild then
                activePriceEditorRebuild = nil
            end
        end

        local search = vgui.Create("DTextEntry", editor)
        search:SetPos(10, 34)
        search:SetSize(editor:GetWide() - 20, 24)
        search:SetPlaceholderText("Filter by item label, class, or category...")

        local topControls = vgui.Create("DPanel", editor)
        topControls:SetPos(10, 64)
        topControls:SetSize(editor:GetWide() - 20, 58)
        topControls.Paint = function() end

        local wepChoices = vgui.Create("DComboBox", topControls)
        wepChoices:SetPos(0, 0)
        wepChoices:SetSize(math.floor(topControls:GetWide() * 0.45), 24)
        wepChoices:SetValue("Select weapon class...")

        local categoryChoices = vgui.Create("DComboBox", topControls)
                local selectedClass
                local selectedCategory

                wepChoices.OnSelect = function(_, _, _, data)
                    selectedClass = tostring(data or "")
                end

                categoryChoices.OnSelect = function(_, _, _, data)
                    selectedCategory = tostring(data or "")
                end

        categoryChoices:SetPos(math.floor(topControls:GetWide() * 0.45) + 8, 0)
        categoryChoices:SetSize(math.floor(topControls:GetWide() * 0.22), 24)
        PopulateCategoryChoices(categoryChoices)

        local labelEntry = vgui.Create("DTextEntry", topControls)
        labelEntry:SetPos(math.floor(topControls:GetWide() * 0.67) + 16, 0)
        labelEntry:SetSize(math.floor(topControls:GetWide() * 0.2), 24)
        labelEntry:SetPlaceholderText("Custom label (optional)")

        local addBtn = vgui.Create("DButton", topControls)
        addBtn:SetPos(topControls:GetWide() - 84, 0)
        addBtn:SetSize(84, 24)
        addBtn:SetText("Add")
        addBtn:SetFont("HomigradFontSmall")
        addBtn:SetTextColor(Color(20, 20, 20))
        addBtn.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(220, 170, 70, 255) or COL_ACCENT)
        end

        local list = vgui.Create("DScrollPanel", editor)
        list:SetPos(10, 126)
        list:SetSize(editor:GetWide() - 20, editor:GetTall() - 136)

        local allWeapons = {}
        for _, wep in ipairs(weapons.GetList() or {}) do
            local cls = wep.ClassName or wep.Classname or wep.class
            if not isstring(cls) or cls == "" then continue end
            if string.sub(cls, 1, 7) ~= "weapon_" then continue end
            local printName = (isstring(wep.PrintName) and wep.PrintName ~= "") and wep.PrintName or cls
            allWeapons[#allWeapons + 1] = { class = cls, label = printName }
        end
        table.sort(allWeapons, function(a, b)
            return string.lower(a.label) < string.lower(b.label)
        end)
        for _, item in ipairs(allWeapons) do
            wepChoices:AddChoice(item.label .. " [" .. item.class .. "]", item.class)
        end

        local function BuildRows()
            list:Clear()
            local query = string.lower(string.Trim(search:GetValue() or ""))
            local y = 0
            local rowH = 34

            for idx, item in ipairs(shopItems) do
                local hay = string.lower((item.label or "") .. " " .. (item.class or "") .. " " .. (item.category or ""))
                if query ~= "" and not string.find(hay, query, 1, true) then continue end

                local row = vgui.Create("DPanel", list)
                row:SetPos(0, y)
                row:SetSize(list:GetWide() - 16, rowH)
                function row:Paint(w, h)
                    draw.RoundedBox(4, 0, 0, w, h, COL_ITEM)
                    surface.SetDrawColor(COL_DIVIDER)
                    surface.DrawRect(0, h - 1, w, 1)
                end

                local lbl = vgui.Create("DLabel", row)
                lbl:SetPos(8, 0)
                lbl:SetSize(math.floor(row:GetWide() * 0.34), rowH)
                lbl:SetText("[" .. tostring(item.category or "") .. "] " .. tostring(item.label or item.class or "?"))
                lbl:SetFont("HomigradFontVSmall")
                lbl:SetTextColor(COL_WHITE)
                lbl:SetContentAlignment(4)

                local entry = vgui.Create("DTextEntry", row)
                entry:SetPos(math.floor(row:GetWide() * 0.35), 6)
                entry:SetSize(76, rowH - 12)
                entry:SetNumeric(true)
                entry:SetValue(tostring(item.price or 0))

                local categoryCombo = vgui.Create("DComboBox", row)
                categoryCombo:SetPos(math.floor(row:GetWide() * 0.35) + 84, 5)
                categoryCombo:SetSize(170, rowH - 10)
                PopulateCategoryChoices(categoryCombo, item.category)

                local selectedRowCategory = tostring(item.category or "")
                categoryCombo.OnSelect = function(_, _, _, data)
                    selectedRowCategory = tostring(data or "")
                end

                local removeBtn = vgui.Create("DButton", row)
                removeBtn:SetPos(row:GetWide() - 172, 5)
                removeBtn:SetSize(76, rowH - 10)
                removeBtn:SetText("Remove")
                removeBtn:SetFont("HomigradFontSmall")
                removeBtn:SetTextColor(Color(20, 20, 20))
                removeBtn.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(170, 70, 70, 255) or Color(145, 55, 55, 255))
                end
                removeBtn.DoClick = function()
                    net.Start("ZC_BuyMenu_AdminRemoveEntry")
                        net.WriteUInt(idx, 16)
                    net.SendToServer()
                    table.remove(shopItems, idx)
                    BuildRows()
                    frame:RebuildItems()
                end

                local btn = vgui.Create("DButton", row)
                btn:SetPos(row:GetWide() - 88, 5)
                btn:SetSize(80, rowH - 10)
                btn:SetText("Save")
                btn:SetFont("HomigradFontSmall")
                btn:SetTextColor(Color(20, 20, 20))
                btn.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(220, 170, 70, 255) or COL_ACCENT)
                end
                btn.DoClick = function()
                    local v = math.Clamp(tonumber(entry:GetValue()) or 0, 0, 20000)
                    net.Start("ZC_BuyMenu_AdminSetPrice")
                        net.WriteUInt(idx, 16)
                        net.WriteUInt(v, 16)
                    net.SendToServer()

                    if selectedRowCategory ~= "" and selectedRowCategory ~= tostring(item.category or "") then
                        net.Start("ZC_BuyMenu_AdminSetCategory")
                            net.WriteUInt(idx, 16)
                            net.WriteString(selectedRowCategory)
                        net.SendToServer()
                    end

                    item.price = v
                    if selectedRowCategory ~= "" then
                        item.category = selectedRowCategory
                        lbl:SetText("[" .. tostring(item.category or "") .. "] " .. tostring(item.label or item.class or "?"))
                    end
                    frame:RebuildItems()
                end

                y = y + rowH + 2
            end
        end

        activePriceEditorRebuild = function()
            if not IsValid(editor) then
                activePriceEditorRebuild = nil
                return
            end
            BuildRows()
        end

        addBtn.DoClick = function()
            if not selectedClass or selectedClass == "" or not selectedCategory or selectedCategory == "" then return end

            local customLabel = string.Trim(labelEntry:GetValue() or "")
            local displayLabel = customLabel ~= "" and customLabel or tostring(wepChoices:GetText() or selectedClass)
            displayLabel = string.gsub(displayLabel, "%s*%[[^%]]+%]%s*$", "")

            net.Start("ZC_BuyMenu_AdminAddEntry")
                net.WriteString(tostring(selectedClass))
                net.WriteString(displayLabel)
                net.WriteString(tostring(selectedCategory))
            net.SendToServer()

            shopItems[#shopItems + 1] = {
                label = displayLabel,
                class = tostring(selectedClass),
                price = 400,
                category = tostring(selectedCategory),
                attKey = "",
                itemType = "weapon",
                armorSlot = "",
                index = #shopItems + 1,
            }

            BuildRows()
            frame:RebuildItems()
        end

        search.OnValueChange = BuildRows
        BuildRows()
    end

    local function OpenRewardEditor()
        local editor = vgui.Create("DFrame")
        editor:SetSize(math.min(ScrW() * 0.62, 840), math.min(ScrH() * 0.76, 600))
        editor:Center()
        editor:SetTitle("Kill Reward Editor")
        editor:MakePopup()
        editor.OnRemove = function()
            if activeRewardEditorRebuild then
                activeRewardEditorRebuild = nil
            end
        end

        local search = vgui.Create("DTextEntry", editor)
        search:SetPos(10, 34)
        search:SetSize(editor:GetWide() - 20, 24)
        search:SetPlaceholderText("Filter by label, class tag, or reward type...")

        local list = vgui.Create("DScrollPanel", editor)
        list:SetPos(10, 64)
        list:SetSize(editor:GetWide() - 20, editor:GetTall() - 74)

        local function BuildRows()
            list:Clear()
            local query = string.lower(string.Trim(search:GetValue() or ""))
            local y = 0
            local rowH = 38

            for _, reward in ipairs(killRewards) do
                local rewardTypeName = reward.rewardType == "vj" and "VJ Class" or "NPC"
                local hay = string.lower((reward.label or "") .. " " .. (reward.key or "") .. " " .. rewardTypeName)
                if query ~= "" and not string.find(hay, query, 1, true) then continue end

                local row = vgui.Create("DPanel", list)
                row:SetPos(0, y)
                row:SetSize(list:GetWide() - 16, rowH)
                function row:Paint(w, h)
                    draw.RoundedBox(4, 0, 0, w, h, COL_ITEM)
                    surface.SetDrawColor(COL_DIVIDER)
                    surface.DrawRect(0, h - 1, w, 1)
                end

                local lbl = vgui.Create("DLabel", row)
                lbl:SetPos(8, 0)
                lbl:SetSize(math.floor(row:GetWide() * 0.36), rowH)
                lbl:SetText("[" .. rewardTypeName .. "] " .. tostring(reward.label or reward.key or "?"))
                lbl:SetFont("HomigradFontVSmall")
                lbl:SetTextColor(COL_WHITE)
                lbl:SetContentAlignment(4)

                local keyLbl = vgui.Create("DLabel", row)
                keyLbl:SetPos(math.floor(row:GetWide() * 0.36), 0)
                keyLbl:SetSize(math.floor(row:GetWide() * 0.2), rowH)
                keyLbl:SetText(tostring(reward.key or ""))
                keyLbl:SetFont("HomigradFontVSmall")
                keyLbl:SetTextColor(COL_GREY)
                keyLbl:SetContentAlignment(4)

                local entry = vgui.Create("DTextEntry", row)
                entry:SetPos(math.floor(row:GetWide() * 0.57), 7)
                entry:SetSize(72, rowH - 14)
                entry:SetNumeric(true)
                entry:SetValue(tostring(reward.currentReward or 0))

                local defaultBtn = vgui.Create("DButton", row)
                defaultBtn:SetPos(row:GetWide() - 170, 5)
                defaultBtn:SetSize(76, rowH - 10)
                defaultBtn:SetText("Default")
                defaultBtn:SetFont("HomigradFontSmall")
                defaultBtn:SetTextColor(Color(20, 20, 20))
                defaultBtn.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(120, 120, 120, 255) or Color(95, 95, 95, 255))
                end
                defaultBtn.DoClick = function()
                    entry:SetValue(tostring(reward.defaultReward or 0))
                end

                local saveBtn = vgui.Create("DButton", row)
                saveBtn:SetPos(row:GetWide() - 88, 5)
                saveBtn:SetSize(80, rowH - 10)
                saveBtn:SetText("Save")
                saveBtn:SetFont("HomigradFontSmall")
                saveBtn:SetTextColor(Color(20, 20, 20))
                saveBtn.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(220, 170, 70, 255) or COL_ACCENT)
                end
                saveBtn.DoClick = function()
                    local value = math.Clamp(tonumber(entry:GetValue()) or 0, 0, 20000)

                    net.Start("ZC_BuyMenu_AdminSetKillReward")
                        net.WriteString(tostring(reward.rewardType or "npc"))
                        net.WriteString(tostring(reward.key or ""))
                        net.WriteUInt(value, 16)
                    net.SendToServer()

                    reward.currentReward = value
                    entry:SetValue(tostring(value))
                end

                y = y + rowH + 2
            end
        end

        activeRewardEditorRebuild = function()
            if not IsValid(editor) then
                activeRewardEditorRebuild = nil
                return
            end
            BuildRows()
        end

        search.OnValueChange = BuildRows
        BuildRows()
    end

    if canEditPrices then
        local priceBtn = vgui.Create("DButton", frame)
        priceBtn:SetPos(fw - 235, 6)
        priceBtn:SetSize(88, 24)
        priceBtn:SetText("PRICES")
        priceBtn:SetFont("HomigradFontSmall")
        priceBtn:SetTextColor(Color(20, 20, 20, 255))
        function priceBtn:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(220, 170, 70, 255) or COL_ACCENT)
        end
        function priceBtn:DoClick()
            OpenPriceEditor()
        end
    end

    if canEditKillRewards then
        local rewardBtn = vgui.Create("DButton", frame)
        rewardBtn:SetPos(fw - 331, 6)
        rewardBtn:SetSize(88, 24)
        rewardBtn:SetText("REWARDS")
        rewardBtn:SetFont("HomigradFontSmall")
        rewardBtn:SetTextColor(Color(20, 20, 20, 255))
        function rewardBtn:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and Color(220, 170, 70, 255) or COL_ACCENT)
        end
        function rewardBtn:DoClick()
            OpenRewardEditor()
        end
    end

    -- ── Scroll panel ──────────────────────────────────────────────────────────

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(0, scrollY)
    scroll:SetSize(fw, scrollH)

    local scrollSbar = scroll:GetVBar()
    function scrollSbar:Paint(w, h)         draw.RoundedBox(4, 0, 0, w, h, Color(20,20,20,200)) end
    function scrollSbar.btnUp:Paint(w, h)   draw.RoundedBox(4, 0, 0, w, h, Color(40,40,40,200)) end
    function scrollSbar.btnDown:Paint(w, h) draw.RoundedBox(4, 0, 0, w, h, Color(40,40,40,200)) end
    function scrollSbar.btnGrip:Paint(w, h) draw.RoundedBox(4, 0, 0, w, h, COL_ACCENT) end

    local itemContainer = vgui.Create("DPanel", scroll)
    itemContainer:SetSize(fw - 12, 0)
    function itemContainer:Paint() end

    -- ── Item builder ──────────────────────────────────────────────────────────

    local currentCategory = categories[1] or "Weapons - Pistols"
    
    -- Store on frame so OpenPriceEditor callbacks can access it
    function frame:RebuildItems()
        itemContainer:Clear()

        local yOff = 4

        local activeWep = IsValid(LocalPlayer()) and LocalPlayer():GetActiveWeapon() or nil
        local activeClass = IsValid(activeWep) and string.lower(tostring(activeWep:GetClass() or "")) or ""
        local activeAttachments = IsValid(activeWep) and BuildEquippedAttachmentEntries(activeWep) or {}

        -- Collect items in current category and sort by price
        local displayItems = {}
        for _, item in ipairs(shopItems) do
            if item.category == currentCategory then
                displayItems[#displayItems + 1] = item
            end
        end

        -- Sort by price: descending by default (highest first), ascending if sortAscending=true
        table.sort(displayItems, function(a, b)
            if sortAscending then
                return (a.price or 0) < (b.price or 0)
            else
                return (a.price or 0) > (b.price or 0)
            end
        end)

        for _, item in ipairs(displayItems) do
            local canAfford = playerMoney >= item.price
            local showAttachments = IsValid(activeWep)
                and (item.itemType == "weapon" or item.itemType == nil or item.itemType == "")
                and isstring(item.class)
                and string.lower(item.class) == activeClass
                and #activeAttachments > 0

            local rowW = fw - 30
            local iconSize = 26
            local spacing = 4
            local startX = 14
            local topBandH = 34
            local yIcons = 54
            local attachmentAreaRight = rowW - 118
            local attachmentAreaWidth = math.max(iconSize, attachmentAreaRight - startX)
            local iconsPerRow = math.max(1, math.floor((attachmentAreaWidth + spacing) / (iconSize + spacing)))
            local iconRows = showAttachments and math.max(1, math.ceil(#activeAttachments / iconsPerRow)) or 0
            local rowH = showAttachments and math.max(88, yIcons + iconRows * (iconSize + spacing) + 6) or 44

            local row = vgui.Create("DPanel", itemContainer)
            row:SetPos(6, yOff)
            row:SetSize(rowW, rowH)

            function row:Paint(w, h)
                draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and COL_ITEM_HVR or COL_ITEM)
                surface.SetDrawColor(COL_DIVIDER)
                surface.DrawRect(0, h - 1, w, 1)
            end

            local textLbl = vgui.Create("DLabel", row)
            textLbl:SetPos(16, 0)
            textLbl:SetSize(math.floor(rowW * 0.42), topBandH)
            textLbl:SetText(item.label)
            textLbl:SetFont("HomigradFontMedium")
            textLbl:SetTextColor(COL_WHITE)
            textLbl:SetContentAlignment(4)

            local classLbl = vgui.Create("DLabel", row)
            classLbl:SetPos(math.floor(rowW * 0.42), 0)
            classLbl:SetSize(math.floor(rowW * 0.22), topBandH)
            classLbl:SetText(item.class)
            classLbl:SetFont("HomigradFontVSmall")
            classLbl:SetTextColor(COL_GREY)
            classLbl:SetContentAlignment(4)

            local priceLbl = vgui.Create("DLabel", row)
            priceLbl:SetPos(rowW - 182, 0)
            priceLbl:SetSize(86, topBandH)
            priceLbl:SetText("$" .. item.price)
            priceLbl:SetFont("HomigradFontMedium")
            priceLbl:SetTextColor(canAfford and COL_MONEY or COL_TOO_POOR)
            priceLbl:SetContentAlignment(6)

            -- Use a factory function to correctly capture per-item values
            local function MakeBuyHandler(itm, affordable)
                return function()
                    if not affordable then return end
                    net.Start("ZC_BuyMenu_Purchase")
                        net.WriteUInt(itm.index, 16)
                    net.SendToServer()
                    playerMoney = math.max(0, playerMoney - itm.price)
                    frame:UpdateMoney(playerMoney)
                    frame:RebuildItems()
                end
            end

            local buyBtn = vgui.Create("DButton", row)
            buyBtn:SetPos(rowW - 92, 4)
            buyBtn:SetSize(76, 26)
            buyBtn:SetText("BUY")
            buyBtn:SetFont("HomigradFontMedium")
            buyBtn:SetTextColor(canAfford and Color(20, 20, 20, 255) or COL_GREY)
            buyBtn:SetDisabled(not canAfford)
            buyBtn.DoClick = MakeBuyHandler(item, canAfford)

            local btnNormal  = canAfford and COL_ACCENT or Color(40, 40, 40, 200)
            local btnHovered = Color(220, 170, 70, 255)
            local btnAfford  = canAfford
            function buyBtn:Paint(w, h)
                draw.RoundedBox(4, 0, 0, w, h, (btnAfford and self:IsHovered()) and btnHovered or btnNormal)
            end

            if showAttachments then
                local hint = vgui.Create("DLabel", row)
                hint:SetPos(14, 34)
                hint:SetSize(attachmentAreaWidth, 14)
                hint:SetText("Equipped weapon attachments (click icon to apply)")
                hint:SetFont("HomigradFontVSmall")
                hint:SetTextColor(COL_GREY)
                hint:SetContentAlignment(4)

                local shown = 0

                for i = 1, #activeAttachments do
                    local att = activeAttachments[i]
                    shown = shown + 1

                    local idx = shown - 1
                    local iconRow = math.floor(idx / iconsPerRow)
                    local iconCol = idx % iconsPerRow

                    local btn = vgui.Create("DImageButton", row)
                    btn:SetPos(startX + iconCol * (iconSize + spacing), yIcons + iconRow * (iconSize + spacing))
                    btn:SetSize(iconSize, iconSize)
                    btn:SetImage(att.icon)
                    btn:SetTooltip(att.name .. " [" .. att.placement .. "]")
                    btn.DoClick = function()
                        net.Start("ZC_BuyMenu_ForceAttach")
                            net.WriteString(att.key)
                        net.SendToServer()
                    end
                end
            end

            yOff = yOff + rowH + 2
        end

        itemContainer:SetSize(fw - 12, math.max(yOff + 4, scrollH))
    end

    -- ── Category tabs (two rows, factory to avoid closure bugs) ───────────────

    local tabW = math.floor(fw / tabsPerRow)

    local function MakeTab(cat, posX, posY, w)
        local tab = vgui.Create("DButton", frame)
        tab:SetPos(posX, posY)
        tab:SetSize(w, tabH)
        tab:SetText(CategoryShortName(cat))
        tab:SetFont("HomigradFontVSmall")

        function tab:Paint(tw, th)
            local isActive = (currentCategory == cat)
            draw.RoundedBox(0, 0, 0, tw, th,
                isActive and COL_ACCENT or (self:IsHovered() and Color(50,50,50,255) or COL_PANEL))
            if isActive then
                surface.SetDrawColor(COL_ACCENT)
                surface.DrawRect(0, th - 2, tw, 2)
            end
        end

        function tab:Think()
            self:SetTextColor(currentCategory == cat and Color(20,20,20,255) or COL_WHITE)
        end

        function tab:DoClick()
            currentCategory = cat
            local vbar = scroll:GetVBar()
            if IsValid(vbar) then vbar:SetScroll(0) end
            frame:RebuildItems()
        end
    end

    for i, cat in ipairs(categories) do
        local tabRow = math.floor((i - 1) / tabsPerRow)
        local tabCol = (i - 1) % tabsPerRow
        -- Stretch last tab in a row to fill rounding gaps
        local w = (tabCol == tabsPerRow - 1) and (fw - tabCol * tabW) or tabW
        MakeTab(cat, tabCol * tabW, headerH + tabRow * tabH, w)
    end

    frame:RebuildItems()

    -- Slide in from below
    frame:SetPos(sw / 2 - fw / 2, sh + fh)
    frame:MoveTo(sw / 2 - fw / 2, sh / 2 - fh / 2, 0.25, 0, 0.3)
end

-- ── Close on death ────────────────────────────────────────────────────────────

hook.Add("HUDPaint", "ZCity_BuyMenu_CloseOnDeath", function()
    if IsValid(shopFrame) and not LocalPlayer():Alive() then
        shopFrame:Remove()
    end
end)
