-- Free Attachment Menu — Client

if SERVER then return end

local attList   = {}
local attFrame  = nil

local COL_BG       = Color(15, 15, 15, 245)
local COL_HEADER   = Color(25, 25, 25, 255)
local COL_PANEL    = Color(22, 22, 22, 255)
local COL_ITEM     = Color(30, 30, 30, 255)
local COL_ITEM_HVR = Color(45, 45, 45, 255)
local COL_ACCENT   = Color(200, 150, 50, 255)
local COL_WHITE    = Color(255, 255, 255, 255)
local COL_GREY     = Color(160, 160, 160, 255)
local COL_DIVIDER  = Color(50, 50, 50, 255)
local COL_OWNED    = Color(60, 180, 80, 255)

local FRIENDLY_PLACEMENT = {
    sight = "Sights",
    mount = "Mounts",
    barrel = "Barrels",
    grip = "Grips",
    underbarrel = "Underbarrel",
    magwell = "Magwell",
}

local function FormatPlacementName(key)
    key = tostring(key or "")
    if FRIENDLY_PLACEMENT[key] then
        return FRIENDLY_PLACEMENT[key]
    end

    local s = string.Replace(key, "_", " ")
    s = string.gsub(s, "(%a)([%w_']*)", function(a, b)
        return string.upper(a) .. string.lower(b)
    end)
    if s == "" then return "Other" end
    return s
end

local function BuildCategories()
    local order, seen = {}, {}
    for _, att in ipairs(attList or {}) do
        local placement = tostring(att.placement or "other")
        if seen[placement] then continue end
        seen[placement] = true
        order[#order + 1] = {
            key = placement,
            label = FormatPlacementName(placement),
        }
    end

    table.sort(order, function(a, b)
        return a.label < b.label
    end)

    if #order == 0 then
        order[1] = { key = "other", label = "Other" }
    end

    return order
end

local function GetOwnedAttachments()
    local owned = {}
    if not LocalPlayer or not IsValid(LocalPlayer()) then return owned end
    local inv = LocalPlayer():GetNetVar("Inventory", {})
    local atts = inv["Attachments"] or {}
    for _, k in ipairs(atts) do owned[k] = true end
    return owned
end

local function OpenAttachmentMenu()
    if IsValid(attFrame) then attFrame:Remove() end

    local sw, sh   = ScrW(), ScrH()
    local fw, fh   = math.min(sw * 0.5, 640), math.min(sh * 0.72, 520)
    local tabH     = 28
    local headerH  = 36
    local tabAreaH = tabH
    local scrollY  = headerH + tabAreaH + 4
    local scrollH  = fh - scrollY - 8

    local frame = vgui.Create("DFrame")
    frame:SetSize(fw, fh)
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    attFrame = frame

    frame.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, COL_BG)
        draw.RoundedBoxEx(6, 0, 0, w, headerH, COL_HEADER, true, true, false, false)
        draw.SimpleText("ATTACHMENTS", "DermaDefaultBold", 12, headerH / 2,
            COL_ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Free for all — equip to active weapon on next draw",
            "DermaDefault", fw - 10, headerH / 2,
            COL_GREY, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(COL_DIVIDER)
        surface.DrawRect(0, headerH, w, 1)
    end

    -- Close button
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(fw - 28, 6)
    closeBtn:SetSize(22, 22)
    closeBtn:SetText("✕")
    closeBtn:SetFont("DermaDefaultBold")
    closeBtn:SetTextColor(COL_GREY)
    closeBtn.Paint = function(self, w, h)
        if self:IsHovered() then
            draw.RoundedBox(4, 0, 0, w, h, Color(80, 30, 30, 200))
        end
    end
    closeBtn.DoClick = function() frame:Remove() end

    -- Category tabs
    local categories = BuildCategories()
    local activeTab = categories[1].key
    local tabs = {}
    local tabW = fw / math.max(1, #categories)

    local tabBar = vgui.Create("DPanel", frame)
    tabBar:SetPos(0, headerH + 1)
    tabBar:SetSize(fw, tabH)
    tabBar.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL_PANEL)
    end

    -- Scroll panel for items
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(0, scrollY)
    scroll:SetSize(fw, scrollH)

    local itemList = vgui.Create("DPanel", scroll)
    itemList:SetWide(fw)
    itemList.Paint = function() end

    local function RebuildList(catKey)
        itemList:Clear()
        local owned = GetOwnedAttachments()
        local itemH = 36
        local pad   = 4
        local y     = pad

        for _, att in ipairs(attList) do
            if tostring(att.placement or "other") ~= tostring(catKey) then continue end

            local isOwned = owned[att.attKey]
            local row = vgui.Create("DPanel", itemList)
            row:SetPos(pad, y)
            row:SetSize(fw - pad * 2, itemH)
            row.attKey = att.attKey

            row.Paint = function(self, w, h)
                local bg = self:IsHovered() and not isOwned and COL_ITEM_HVR or COL_ITEM
                draw.RoundedBox(4, 0, 0, w, h, bg)
                -- Label
                draw.SimpleText(att.label, "DermaDefaultBold", 10, h / 2,
                    isOwned and COL_OWNED or COL_WHITE,
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                -- Owned badge
                if isOwned then
                    draw.SimpleText("✔ Unlocked", "DermaDefault", w - 10, h / 2,
                        COL_OWNED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                else
                    draw.SimpleText("Click to unlock", "DermaDefault", w - 10, h / 2,
                        COL_GREY, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
                surface.SetDrawColor(COL_DIVIDER)
                surface.DrawRect(0, h - 1, w, 1)
            end

            if not isOwned then
                row:SetCursor("hand")
                row.OnMousePressed = function(self, mc)
                    if mc ~= MOUSE_LEFT then return end
                    net.Start("ZC_FreeAtt_Apply")
                        net.WriteString(self.attKey)
                    net.SendToServer()
                    -- Optimistic local update
                    isOwned = true
                    surface.PlaySound("buttons/button14.wav")
                    -- Rebuild after a tick so inventory netvar has time to update
                    timer.Simple(0.3, function()
                        if IsValid(frame) then RebuildList(catKey) end
                    end)
                end
            end

            y = y + itemH + 2
        end

        itemList:SetTall(y + pad)
    end

    -- Build tabs
    for i, cat in ipairs(categories) do
        local tab = vgui.Create("DButton", tabBar)
        tab:SetPos((i - 1) * tabW, 0)
        tab:SetSize(tabW, tabH)
        tab:SetText(cat.label)
        tab:SetFont("DermaDefaultBold")
        tab:SetTextColor(COL_WHITE)
        tabs[cat.key] = tab

        tab.Paint = function(self, w, h)
            local isActive = activeTab == cat.key
            draw.RoundedBox(0, 0, 0, w, h,
                isActive and COL_ACCENT or (self:IsHovered() and COL_ITEM_HVR or COL_PANEL))
            if isActive then
                draw.SimpleText(cat.label, "DermaDefaultBold", w / 2, h / 2,
                    Color(15, 15, 15), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        tab.DoClick = function()
            activeTab = cat.key
            RebuildList(cat.key)
        end
    end

    RebuildList(activeTab)
end

net.Receive("ZC_FreeAtt_Open", function()
    attList = {}
    local count = net.ReadUInt(12)
    for i = 1, count do
        attList[i] = {
            label     = net.ReadString(),
            attKey    = net.ReadString(),
            placement = net.ReadString(),
        }
    end
    OpenAttachmentMenu()
end)
