-- cl_dod_config_menu.lua -- Admin UI for live DoD map flag behavior tuning.

if SERVER then return end

local uiState = nil
local frame = nil

local function IsStaff()
    local lp = LocalPlayer()
    return IsValid(lp) and lp:IsAdmin()
end

local function RequestState()
    net.Start("DOD_ConfigMenu_Request")
    net.SendToServer()
end

local function SendApply(saveNow)
    if not uiState then return end
    local payload = {
        neutral_capture_time = tonumber(uiState.neutral_capture_time) or 6,
        enemy_capture_time = tonumber(uiState.enemy_capture_time) or 10,
        wave_interval = tonumber(uiState.wave_interval) or 15,
        round_time = tonumber(uiState.round_time) or 600,
        flags = {},
        save = saveNow and true or false,
    }

    for i, row in ipairs(uiState.flags or {}) do
        payload.flags[i] = {
            idx = tonumber(row.idx) or i,
            name = tostring(row.name or ("CP" .. i)),
            requiredPlayers = math.max(1, math.floor(tonumber(row.requiredPlayers) or 1)),
            originalOwner = tonumber(row.originalOwner) or -1,
            singleCap = row.singleCap and true or false,
        }
    end

    net.Start("DOD_ConfigMenu_Apply")
        net.WriteTable(payload)
    net.SendToServer()
end

local function MakeNumEntry(parent, x, y, w, label, key)
    local lbl = vgui.Create("DLabel", parent)
    lbl:SetPos(x, y)
    lbl:SetText(label)
    lbl:SetTextColor(Color(220, 220, 220))
    lbl:SizeToContents()

    local e = vgui.Create("DTextEntry", parent)
    e:SetPos(x, y + 18)
    e:SetSize(w, 24)
    e:SetNumeric(true)
    e:SetValue(tostring(uiState[key] or ""))
    e.OnValueChange = function(_, val)
        uiState[key] = tonumber(val) or uiState[key]
    end

    return e
end

local function BuildMenu()
    if not IsStaff() then
        chat.AddText(Color(200, 80, 80), "[DoD] Staff only.")
        return
    end

    if IsValid(frame) then frame:Remove() end

    frame = vgui.Create("DFrame")
    frame:SetSize(760, 700)
    frame:Center()
    frame:SetTitle("DoD Live Config Menu")
    frame:MakePopup()

    local mapLbl = vgui.Create("DLabel", frame)
    mapLbl:SetPos(12, 34)
    mapLbl:SetTextColor(Color(170, 190, 230))
    mapLbl:SetText("Map: " .. tostring(uiState.map or game.GetMap()))
    mapLbl:SizeToContents()

    MakeNumEntry(frame, 12, 56, 170, "Neutral capture (sec)", "neutral_capture_time")
    MakeNumEntry(frame, 198, 56, 170, "Enemy capture (sec)", "enemy_capture_time")
    MakeNumEntry(frame, 384, 56, 170, "Wave interval (sec)", "wave_interval")
    MakeNumEntry(frame, 570, 56, 170, "Round time (sec)", "round_time")

    local list = vgui.Create("DScrollPanel", frame)
    list:SetPos(12, 128)
    list:SetSize(736, 500)

    local y = 0
    for i, row in ipairs(uiState.flags or {}) do
        local p = vgui.Create("DPanel", list)
        p:SetPos(0, y)
        p:SetSize(716, 56)
        p.Paint = function(_, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(28, 32, 44, 240))
            surface.SetDrawColor(58, 65, 88, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local name = vgui.Create("DLabel", p)
        name:SetPos(10, 9)
        name:SetText(string.format("%s (CP%d)", tostring(row.name or ("Flag " .. i)), tonumber(row.idx) or i))
        name:SetTextColor(Color(225, 225, 225))
        name:SizeToContents()

        local req = vgui.Create("DNumSlider", p)
        req:SetPos(190, 6)
        req:SetSize(235, 44)
        req:SetText("Required players")
        req:SetMinMax(1, 8)
        req:SetDecimals(0)
        req:SetValue(tonumber(row.requiredPlayers) or 1)
        req.OnValueChanged = function(_, val)
            row.requiredPlayers = math.max(1, math.floor(tonumber(val) or 1))
            if row.singleCap then
                row.requiredPlayers = 1
            end
        end

        local owner = vgui.Create("DComboBox", p)
        owner:SetPos(430, 16)
        owner:SetSize(110, 24)
        owner:AddChoice("Neutral", -1)
        owner:AddChoice("Axis", 0)
        owner:AddChoice("Allies", 1)
        owner.OnSelect = function(_, _, _, data)
            row.originalOwner = tonumber(data) or -1
        end

        local curOwner = tonumber(row.originalOwner)
        if curOwner == nil then curOwner = -1 end
        owner:ChooseOptionID(curOwner == -1 and 1 or (curOwner == 0 and 2 or 3))

        local single = vgui.Create("DCheckBoxLabel", p)
        single:SetPos(550, 18)
        single:SetText("Single cap")
        single:SetValue(row.singleCap and 1 or 0)
        single:SizeToContents()
        single.OnChange = function(_, val)
            row.singleCap = val and true or false
            if row.singleCap then
                row.requiredPlayers = 1
                req:SetValue(1)
            end
        end

        y = y + 62
    end

    local btnApply = vgui.Create("DButton", frame)
    btnApply:SetPos(12, 636)
    btnApply:SetSize(220, 28)
    btnApply:SetText("Apply Live")
    btnApply.DoClick = function()
        SendApply(false)
    end

    local btnSave = vgui.Create("DButton", frame)
    btnSave:SetPos(242, 636)
    btnSave:SetSize(220, 28)
    btnSave:SetText("Apply + Save")
    btnSave.DoClick = function()
        SendApply(true)
    end

    local btnRefresh = vgui.Create("DButton", frame)
    btnRefresh:SetPos(472, 636)
    btnRefresh:SetSize(130, 28)
    btnRefresh:SetText("Refresh")
    btnRefresh.DoClick = function()
        RequestState()
    end

    local btnClose = vgui.Create("DButton", frame)
    btnClose:SetPos(612, 636)
    btnClose:SetSize(136, 28)
    btnClose:SetText("Close")
    btnClose.DoClick = function()
        if IsValid(frame) then frame:Close() end
    end
end

net.Receive("DOD_ConfigMenu_Open", function()
    if not IsStaff() then return end
    if not uiState then
        uiState = {
            map = game.GetMap(),
            neutral_capture_time = 6,
            enemy_capture_time = 10,
            wave_interval = 15,
            round_time = 600,
            flags = {},
        }
    end
    BuildMenu()
    RequestState()
end)

net.Receive("DOD_ConfigMenu_State", function()
    local state = net.ReadTable()
    if not istable(state) then return end

    uiState = {
        map = tostring(state.map or game.GetMap()),
        neutral_capture_time = tonumber(state.neutral_capture_time) or 6,
        enemy_capture_time = tonumber(state.enemy_capture_time) or 10,
        wave_interval = tonumber(state.wave_interval) or 15,
        round_time = tonumber(state.round_time) or 600,
        flags = {},
    }

    for i, row in ipairs(state.flags or {}) do
        uiState.flags[i] = {
            idx = tonumber(row.idx) or i,
            name = tostring(row.name or ("Flag " .. i)),
            requiredPlayers = math.max(1, math.floor(tonumber(row.requiredPlayers) or 1)),
            originalOwner = tonumber(row.originalOwner) or -1,
            singleCap = row.singleCap and true or false,
        }
    end

    if IsValid(frame) then
        BuildMenu()
    end
end)

concommand.Add("dod_cfg_menu", function()
    if not IsStaff() then
        chat.AddText(Color(200, 80, 80), "[DoD] Staff only.")
        return
    end

    net.Start("DOD_ConfigMenu_Open")
    net.SendToServer()
    RequestState()
end)
