-- Client-side damage log viewer panel.
-- Opened via: zc_damagelog_open (console) or !damagelog (chat, admin+)
-- Displays a scrollable table of damage events with copy-SteamID buttons.

if SERVER then return end

-- ── Fonts ──────────────────────────────────────────────────────────────────────
surface.CreateFont("ZCLog_Title", {
    font = "Courier New", size = 20, weight = 800
})
surface.CreateFont("ZCLog_Header", {
    font = "Courier New", size = 13, weight = 700
})
surface.CreateFont("ZCLog_Row", {
    font = "Courier New", size = 12, weight = 400
})
surface.CreateFont("ZCLog_Small", {
    font = "Courier New", size = 11, weight = 400
})
surface.CreateFont("ZCLog_Btn", {
    font = "Courier New", size = 11, weight = 700
})

-- ── Colours ───────────────────────────────────────────────────────────────────
local C = {
    bg       = Color(10,  12,  16),
    panel    = Color(16,  20,  26),
    border   = Color(40,  48,  60),
    header   = Color(22,  28,  36),
    rowA     = Color(18,  23,  30),
    rowB     = Color(14,  18,  24),
    rowHover = Color(30,  40,  55),
    accent   = Color(255, 80,  80),
    accentB  = Color(80, 160, 255),
    text     = Color(220, 225, 235),
    dim      = Color(130, 140, 155),
    green    = Color(80,  210, 120),
    yellow   = Color(255, 200, 60),
    red      = Color(255, 80,  80),
    copyBtn  = Color(30,  90,  160),
    copyHov  = Color(50, 130, 220),
}

local CLASS_COLORS = {
    Gordon   = Color(255, 200, 60),
    Rebel    = Color(100, 210, 120),
    Refugee  = Color(160, 210, 140),
    Combine  = Color(80,  160, 255),
    Metrocop = Color(120, 180, 255),
}

local function ClassColor(cls)
    return CLASS_COLORS[cls] or C.dim
end

-- ── State ─────────────────────────────────────────────────────────────────────
local logEntries  = {}
local totalOnFile = 0

local function RequestLogs(keyword, date)
    net.Start("ZC_DamageLog_Request")
        net.WriteString(keyword or "")
        net.WriteString(date    or "")
    net.SendToServer()
end

net.Receive("ZC_DamageLog_Data", function()
    totalOnFile = net.ReadUInt(16)
    local count = net.ReadUInt(16)
    logEntries  = {}
    for i = 1, count do
        table.insert(logEntries, {
            time     = net.ReadString(),
            atkName  = net.ReadString(),
            atkSteam = net.ReadString(),
            atkClass = net.ReadString(),
            vicName  = net.ReadString(),
            vicSteam = net.ReadString(),
            vicClass = net.ReadString(),
            damage   = net.ReadString(),
            hitgroup = net.ReadString(),
            weapon   = net.ReadString(),
        })
    end
    -- Refresh panel if open
    if IsValid(ZC_DamageLogPanel) then
        ZC_DamageLogPanel:Refresh()
    end
end)

-- ── Panel ─────────────────────────────────────────────────────────────────────
local function OpenDamageLog()
    if IsValid(ZC_DamageLogPanel) then
        ZC_DamageLogPanel:Remove()
        return
    end

    local sw, sh = ScrW(), ScrH()
    local pw, ph = math.min(1200, sw - 80), math.min(700, sh - 80)
    local px, py = (sw - pw) / 2, (sh - ph) / 2

    local frame = vgui.Create("DFrame")
    frame:SetSize(pw, ph)
    frame:SetPos(px, py)
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    ZC_DamageLogPanel = frame

    -- Custom paint
    frame.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, C.bg)
        draw.RoundedBox(6, 0, 0, w, 44, C.header)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.DrawLine(0, 44, w, 44)

        draw.SimpleText("◈ DAMAGE LOG VIEWER", "ZCLog_Title", 14, 22, C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local countStr = "Showing " .. #logEntries .. " of " .. totalOnFile .. " entries"
        if totalOnFile > #logEntries then
            countStr = countStr .. " (most recent 50)"
        end
        draw.SimpleText(countStr, "ZCLog_Small", w - 14, 22, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- Close button
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(pw - 38, 8)
    closeBtn:SetSize(28, 28)
    closeBtn:SetText("✕")
    closeBtn:SetFont("ZCLog_Header")
    closeBtn:SetTextColor(C.dim)
    closeBtn.Paint = function(self, w, h)
        if self:IsHovered() then
            draw.RoundedBox(4, 0, 0, w, h, C.rowHover)
            self:SetTextColor(C.text)
        else
            self:SetTextColor(C.dim)
        end
    end
    closeBtn.DoClick = function() frame:Remove() end

    -- ── Search bar ────────────────────────────────────────────────────────────
    local barY = 54
    local searchBox = vgui.Create("DTextEntry", frame)
    searchBox:SetPos(14, barY)
    searchBox:SetSize(pw * 0.35, 28)
    searchBox:SetFont("ZCLog_Row")
    searchBox:SetPlaceholderText("Search name or SteamID...")
    searchBox:SetTextColor(C.text)
    searchBox:SetCursorColor(C.text)
    searchBox.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, C.panel)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(C.text, C.accentB, C.text)
    end

    local dateBox = vgui.Create("DTextEntry", frame)
    dateBox:SetPos(14 + pw * 0.35 + 8, barY)
    dateBox:SetSize(120, 28)
    dateBox:SetFont("ZCLog_Row")
    dateBox:SetPlaceholderText(os.date("%Y-%m-%d"))
    dateBox:SetTextColor(C.text)
    dateBox:SetCursorColor(C.text)
    dateBox.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, C.panel)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(C.text, C.accentB, C.text)
    end

    local searchBtn = vgui.Create("DButton", frame)
    searchBtn:SetPos(14 + pw * 0.35 + 8 + 128, barY)
    searchBtn:SetSize(80, 28)
    searchBtn:SetText("SEARCH")
    searchBtn:SetFont("ZCLog_Btn")
    searchBtn:SetTextColor(C.text)
    searchBtn.Paint = function(self, w, h)
        local bg = self:IsHovered() and C.accentB or C.copyBtn
        draw.RoundedBox(4, 0, 0, w, h, bg)
    end
    searchBtn.DoClick = function()
        RequestLogs(searchBox:GetValue(), dateBox:GetValue())
    end

    local todayBtn = vgui.Create("DButton", frame)
    todayBtn:SetPos(14 + pw * 0.35 + 8 + 128 + 88, barY)
    todayBtn:SetSize(60, 28)
    todayBtn:SetText("TODAY")
    todayBtn:SetFont("ZCLog_Btn")
    todayBtn:SetTextColor(C.dim)
    todayBtn.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and C.rowHover or C.panel)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    todayBtn.DoClick = function()
        dateBox:SetValue("")
        searchBox:SetValue("")
        RequestLogs("", "")
    end

    -- ── Column headers ────────────────────────────────────────────────────────
    local headerY  = barY + 36
    local colY     = headerY + 24
    local rowH     = 32
    local scrollH  = ph - colY - 8

    local COLS = {
        { label = "TIME",      w = 60  },
        { label = "ATTACKER",  w = 130 },
        { label = "ATK CLASS", w = 80  },
        { label = "",          w = 28  },  -- copy button
        { label = "VICTIM",    w = 130 },
        { label = "VIC CLASS", w = 80  },
        { label = "",          w = 28  },  -- copy button
        { label = "DMG",       w = 52  },
        { label = "HITGROUP",  w = 72  },
        { label = "WEAPON",    w = 0   },  -- fill remaining
    }

    -- Calculate fill width
    local totalFixed = 0
    for _, c in ipairs(COLS) do totalFixed = totalFixed + c.w end
    COLS[#COLS].w = pw - 28 - totalFixed

    -- Header paint
    local headerPanel = vgui.Create("DPanel", frame)
    headerPanel:SetPos(14, headerY)
    headerPanel:SetSize(pw - 28, 22)
    headerPanel.Paint = function(self, w, h)
        draw.RoundedBox(3, 0, 0, w, h, C.header)
        local x = 8
        for _, col in ipairs(COLS) do
            if col.label ~= "" then
                draw.SimpleText(col.label, "ZCLog_Header", x, h/2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            x = x + col.w
        end
    end

    -- ── Scroll panel ─────────────────────────────────────────────────────────
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(14, colY)
    scroll:SetSize(pw - 28, scrollH)
    scroll.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, C.panel)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local sbar = scroll:GetVBar()
    sbar:SetWide(6)
    sbar.Paint = function(self, w, h) draw.RoundedBox(3, 0, 0, w, h, C.bg) end
    sbar.btnUp.Paint   = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(self, w, h) draw.RoundedBox(3, 0, 0, w, h, C.border) end

    local listPanel = vgui.Create("DPanel", scroll)
    listPanel:SetSize(pw - 34, 1)
    listPanel.Paint = function() end

    local function MakeCopyBtn(parent, steamid, x, y)
        local btn = vgui.Create("DButton", parent)
        btn:SetPos(x, y + (rowH - 18) / 2)
        btn:SetSize(24, 18)
        btn:SetText("⎘")
        btn:SetFont("ZCLog_Btn")
        btn:SetTextColor(C.dim)
        btn.Paint = function(self, w, h)
            local bg = self:IsHovered() and C.copyHov or C.copyBtn
            draw.RoundedBox(3, 0, 0, w, h, bg)
            if self:IsHovered() then self:SetTextColor(C.text) else self:SetTextColor(C.dim) end
        end
        btn.DoClick = function()
            SetClipboardText(steamid)
            btn:SetText("✓")
            btn:SetTextColor(C.green)
            timer.Simple(1.5, function()
                if IsValid(btn) then
                    btn:SetText("⎘")
                    btn:SetTextColor(C.dim)
                end
            end)
        end
        btn:SetTooltip(steamid)
        return btn
    end

    local function BuildRows()
        -- Clear existing children
        for _, child in ipairs(listPanel:GetChildren()) do
            child:Remove()
        end

        local totalH = math.max(#logEntries * rowH, scrollH - 2)
        listPanel:SetTall(totalH)

        for i, entry in ipairs(logEntries) do
            local y   = (i - 1) * rowH
            local row = vgui.Create("DPanel", listPanel)
            row:SetPos(0, y)
            row:SetSize(pw - 34, rowH)

            local isHovered = false
            row.Think = function(self)
                isHovered = self:IsHovered() or self:IsChildHovered()
            end
            row.Paint = function(self, w, h)
                local bg = isHovered and C.rowHover or (i % 2 == 0 and C.rowA or C.rowB)
                draw.RoundedBox(0, 0, 0, w, h, bg)
                surface.SetDrawColor(C.border)
                surface.DrawLine(0, h - 1, w, h - 1)

                local x = 8
                local cols_data = {
                    { text = entry.time,    color = C.dim },
                    { text = entry.atkName, color = C.red },
                    { text = entry.atkClass,color = ClassColor(entry.atkClass) },
                    { text = "",            color = C.text },  -- copy btn placeholder
                    { text = entry.vicName, color = C.accentB },
                    { text = entry.vicClass,color = ClassColor(entry.vicClass) },
                    { text = "",            color = C.text },  -- copy btn placeholder
                    { text = entry.damage,  color = C.yellow },
                    { text = entry.hitgroup,color = entry.hitgroup == "head" and C.red or C.dim },
                    { text = entry.weapon,  color = C.dim },
                }
                for j, col in ipairs(COLS) do
                    local d = cols_data[j]
                    if d and d.text ~= "" then
                        local maxW = col.w - 6
                        draw.SimpleTextOutlined(d.text, "ZCLog_Row", x + 2, h/2, d.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color(0,0,0,80))
                    end
                    x = x + col.w
                end
            end

            -- Copy buttons (positioned over their column slots)
            local xOff = 8
            for j, col in ipairs(COLS) do
                if j == 4 then MakeCopyBtn(row, entry.atkSteam, xOff, 0) end
                if j == 7 then MakeCopyBtn(row, entry.vicSteam, xOff, 0) end
                xOff = xOff + col.w
            end
        end
    end

    -- Expose refresh
    frame.Refresh = function() BuildRows() end

    BuildRows()

    -- Initial load
    RequestLogs("", "")
end

-- ── Hooks ─────────────────────────────────────────────────────────────────────

net.Receive("ZC_DamageLog_Open", function()
    OpenDamageLog()
end)

hook.Add("HG_PlayerSay", "ZCity_DamageLogCmd", function(ply, txtTbl, text)
    if not IsPlayer or not LocalPlayer then return end
    local cmd = string.lower(string.Trim(text))
    if cmd ~= "!damagelog" and cmd ~= "/damagelog" then return end
    if not LocalPlayer():IsAdmin() then return end
    txtTbl[1] = ""
    OpenDamageLog()
end)

-- Also bindable
concommand.Add("zc_damagelog_panel", function()
    OpenDamageLog()
end)
