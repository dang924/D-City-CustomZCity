-- cl_ragdoll_animator_hud.lua
-- Guided client UI for ragdoll animator workflows.

if SERVER then return end

local COOKIE_PREFIX = "zc_raganim_"

local isRecording = false
local currentRecordingName = nil
local recordingFrameCount = 0
local recordingStartTime = 0

local panelRef = nil
local ui = {}
local statusState = {
    recordings = {},
    activeRecording = "",
    mirrorRecording = "",
    mirrorRecordingFront = "",
    mirrorRecordingBack = "",
    hasAimTarget = false,
    isAimCapturing = false,
    aimSamples = 0,
    aimYawBias = 0,
    aimPitchBias = 0,
}

local function GetSavedString(key, fallback)
    local value = cookie.GetString(COOKIE_PREFIX .. key, fallback or "")
    if value == nil or value == "" then
        return fallback or ""
    end
    return value
end

local function SetSavedString(key, value)
    cookie.Set(COOKIE_PREFIX .. key, tostring(value or ""))
end

local function RequestStatus()
    net.Start("RagdollAnimator_RequestStatus")
    net.SendToServer()
end

local function QueueStatusRefresh()
    timer.Simple(0.12, function()
        RequestStatus()
    end)
    timer.Simple(0.45, function()
        RequestStatus()
    end)
end

local function RunAnimatorCommand(cmd, ...)
    RunConsoleCommand(cmd, ...)
    QueueStatusRefresh()
end

local function BuildSection(parent, title, height)
    local section = vgui.Create("DPanel", parent)
    section:Dock(TOP)
    section:DockMargin(0, 0, 0, 10)
    section:SetTall(height or 120)
    section.Paint = function(self, w, h)
        surface.SetDrawColor(22, 24, 30, 240)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(75, 82, 94, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(title, "DermaDefaultBold", 10, 8, Color(236, 236, 236), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    return section
end

local function AddButton(parent, x, y, w, h, label, onClick)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText(label)
    btn.DoClick = onClick
    return btn
end

local function AddEntry(parent, x, y, w, h, key, placeholder, fallback)
    local entry = vgui.Create("DTextEntry", parent)
    entry:SetPos(x, y)
    entry:SetSize(w, h)
    entry:SetPlaceholderText(placeholder)
    entry:SetValue(GetSavedString(key, fallback))
    entry.OnValueChange = function(self, value)
        SetSavedString(key, value)
    end
    return entry
end

local function UpdateRecordingList()
    if not IsValid(ui.recordingList) then return end
    ui.recordingList:Clear()
    for _, name in ipairs(statusState.recordings or {}) do
        ui.recordingList:AddLine(name)
    end
end

local function UpdateStatusText()
    if IsValid(ui.summaryLabel) then
        ui.summaryLabel:SetText(string.format(
            "Live state: recording=%s | front=%s | back=%s | fallback=%s | aim target=%s | aim capture=%s | samples=%d",
            statusState.activeRecording ~= "" and statusState.activeRecording or "none",
            statusState.mirrorRecordingFront ~= "" and statusState.mirrorRecordingFront or "none",
            statusState.mirrorRecordingBack ~= "" and statusState.mirrorRecordingBack or "none",
            statusState.mirrorRecording ~= "" and statusState.mirrorRecording or "none",
            statusState.hasAimTarget and "yes" or "no",
            statusState.isAimCapturing and "yes" or "no",
            tonumber(statusState.aimSamples) or 0
        ))
        ui.summaryLabel:SizeToContentsY()
    end

    if IsValid(ui.aimBiasLabel) then
        ui.aimBiasLabel:SetText(string.format(
            "Aim bias: yaw %.2f | pitch %.2f",
            tonumber(statusState.aimYawBias) or 0,
            tonumber(statusState.aimPitchBias) or 0
        ))
    end

    if IsValid(ui.step1Label) then
        ui.step1Label:SetText("1. Record movement: use the fake-ragdoll button (or selected mode), move, then stop.")
    end
    if IsValid(ui.step2Label) then
        ui.step2Label:SetText("2. Calibrate aim: spawn target, start capture, aim naturally, stop capture.")
    end
    if IsValid(ui.step3Label) then
        ui.step3Label:SetText("3. Mirror to knockdown: set the chosen recording as the active mirror.")
    end
    if IsValid(ui.step4Label) then
        ui.step4Label:SetText("4. Test: look at a ragdoll and play/stop a recording manually if needed.")
    end

    UpdateRecordingList()
end

local function ApplyRecordingNameToFields(name)
    if not isstring(name) or name == "" then return end
    if IsValid(ui.recordNameEntry) then ui.recordNameEntry:SetValue(name) end
    if IsValid(ui.mirrorNameEntry) then ui.mirrorNameEntry:SetValue(name) end
    if IsValid(ui.mirrorFrontNameEntry) then ui.mirrorFrontNameEntry:SetValue(name) end
    if IsValid(ui.mirrorBackNameEntry) then ui.mirrorBackNameEntry:SetValue(name) end
    if IsValid(ui.playNameEntry) then ui.playNameEntry:SetValue(name) end
end

local function EnsureMenu()
    if IsValid(panelRef) then
        panelRef:MakePopup()
        panelRef:Center()
        RequestStatus()
        return panelRef
    end

    local frame = vgui.Create("DFrame")
    panelRef = frame
    frame:SetSize(620, 700)
    frame:Center()
    frame:SetTitle("Ragdoll Animator Workflow")
    frame:SetSizable(false)
    frame:MakePopup()
    frame.OnClose = function()
        panelRef = nil
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 8, 8, 8)

    local summary = BuildSection(scroll, "Session Overview", 88)
    ui.summaryLabel = vgui.Create("DLabel", summary)
    ui.summaryLabel:SetPos(10, 30)
    ui.summaryLabel:SetSize(590, 18)
    ui.summaryLabel:SetWrap(true)
    ui.summaryLabel:SetAutoStretchVertical(true)
    ui.aimBiasLabel = vgui.Create("DLabel", summary)
    ui.aimBiasLabel:SetPos(10, 54)
    ui.aimBiasLabel:SetSize(590, 18)
    AddButton(summary, 475, 26, 120, 26, "Refresh Status", function()
        RequestStatus()
    end)

    local workflow = BuildSection(scroll, "Guided Workflow", 118)
    ui.step1Label = vgui.Create("DLabel", workflow)
    ui.step1Label:SetPos(10, 32)
    ui.step1Label:SetSize(590, 16)
    ui.step2Label = vgui.Create("DLabel", workflow)
    ui.step2Label:SetPos(10, 50)
    ui.step2Label:SetSize(590, 16)
    ui.step3Label = vgui.Create("DLabel", workflow)
    ui.step3Label:SetPos(10, 68)
    ui.step3Label:SetSize(590, 16)
    ui.step4Label = vgui.Create("DLabel", workflow)
    ui.step4Label:SetPos(10, 86)
    ui.step4Label:SetSize(590, 16)

    local record = BuildSection(scroll, "Step 1: Record Movement", 164)
    ui.recordNameEntry = AddEntry(record, 10, 30, 240, 26, "record_name", "Recording name", "player_pose")
    ui.recordIntervalEntry = AddEntry(record, 260, 30, 90, 26, "record_interval", "Interval", "0.05")
    ui.recordModeCombo = vgui.Create("DComboBox", record)
    ui.recordModeCombo:SetPos(360, 30)
    ui.recordModeCombo:SetSize(140, 26)
    ui.recordModeCombo:AddChoice("Player", "player")
    ui.recordModeCombo:AddChoice("Target Ragdoll", "ragdoll")
    ui.recordModeCombo:SetValue(GetSavedString("record_mode", "Player"))
    ui.recordModeCombo.OnSelect = function(_, _, value)
        SetSavedString("record_mode", value)
    end
    AddButton(record, 10, 68, 150, 28, "Start", function()
        local name = string.Trim(ui.recordNameEntry:GetValue())
        local interval = string.Trim(ui.recordIntervalEntry:GetValue())
        local _, mode = ui.recordModeCombo:GetSelected()
        if name == "" then name = "player_pose" end
        if mode == "ragdoll" then
            RunAnimatorCommand("ragdoll_record_start", name, interval)
        else
            RunAnimatorCommand("ragdoll_record_player_start", name, interval)
        end
    end)
    AddButton(record, 170, 68, 150, 28, "Stop", function()
        local name = string.Trim(ui.recordNameEntry:GetValue())
        if name == "" then name = "player_pose" end
        RunAnimatorCommand("ragdoll_record_stop", name)
    end)
    AddButton(record, 330, 68, 170, 28, "Save Recording", function()
        local name = string.Trim(ui.recordNameEntry:GetValue())
        if name == "" then name = "player_pose" end
        RunAnimatorCommand("ragdoll_save", name)
    end)
    AddButton(record, 10, 102, 290, 28, "Record From My Current Fake Ragdoll", function()
        local name = string.Trim(ui.recordNameEntry:GetValue())
        local interval = string.Trim(ui.recordIntervalEntry:GetValue())
        if name == "" then name = "player_pose" end
        RunAnimatorCommand("ragdoll_record_player_start", name, interval)
    end)
    AddButton(record, 310, 102, 290, 28, "Capture Current Upper-Body Pose as Idle Aim Pose", function()
        local name = string.Trim(ui.recordNameEntry:GetValue())
        if name == "" then name = "player_pose" end
        RunAnimatorCommand("ragdoll_capture_idle_aim_pose", name)
    end)

    local aim = BuildSection(scroll, "Step 2: Aim Calibration", 126)
    local aimInfo = vgui.Create("DLabel", aim)
    aimInfo:SetPos(10, 30)
    aimInfo:SetSize(590, 28)
    aimInfo:SetWrap(true)
    aimInfo:SetText("Spawn a target at your crosshair, start capture, aim naturally for a few seconds, then stop. The resulting bias is reused even after closing and reopening this menu during the session.")
    AddButton(aim, 10, 72, 140, 28, "Spawn Target", function()
        RunAnimatorCommand("ragdoll_aim_target_spawn")
    end)
    AddButton(aim, 160, 72, 140, 28, "Remove Target", function()
        RunAnimatorCommand("ragdoll_aim_target_remove")
    end)
    AddButton(aim, 310, 72, 140, 28, "Start Capture", function()
        RunAnimatorCommand("ragdoll_aim_capture_start")
    end)
    AddButton(aim, 460, 72, 140, 28, "Stop Capture", function()
        RunAnimatorCommand("ragdoll_aim_capture_stop")
    end)

    local mirror = BuildSection(scroll, "Step 3: Knockdown Mirror", 164)
    ui.mirrorNameEntry = AddEntry(mirror, 10, 30, 280, 26, "mirror_name", "Fallback recording", "player_pose")
    ui.mirrorFrontNameEntry = AddEntry(mirror, 10, 64, 280, 26, "mirror_front_name", "Front-fall recording", "player_pose_front")
    ui.mirrorBackNameEntry = AddEntry(mirror, 10, 98, 280, 26, "mirror_back_name", "Back-fall recording", "player_pose_back")
    AddButton(mirror, 300, 30, 140, 26, "Set Fallback", function()
        local name = string.Trim(ui.mirrorNameEntry:GetValue())
        if name == "" then return end
        RunAnimatorCommand("ragdoll_knockdown_mirror_set", name)
    end)
    AddButton(mirror, 450, 30, 150, 26, "Set Front-Fall", function()
        local name = string.Trim(ui.mirrorFrontNameEntry:GetValue())
        if name == "" then return end
        RunAnimatorCommand("ragdoll_knockdown_mirror_front_set", name)
    end)
    AddButton(mirror, 300, 64, 140, 26, "Set Back-Fall", function()
        local name = string.Trim(ui.mirrorBackNameEntry:GetValue())
        if name == "" then return end
        RunAnimatorCommand("ragdoll_knockdown_mirror_back_set", name)
    end)
    AddButton(mirror, 450, 64, 150, 26, "Mirror Status", function()
        RequestStatus()
    end)
    AddButton(mirror, 300, 98, 140, 26, "Disable Mirrors", function()
        RunAnimatorCommand("ragdoll_knockdown_mirror_clear")
    end)

    local playback = BuildSection(scroll, "Step 4: Playback Test", 126)
    ui.playNameEntry = AddEntry(playback, 10, 30, 220, 26, "play_name", "Recording to play", "player_pose")
    ui.playSpeedEntry = AddEntry(playback, 240, 30, 80, 26, "play_speed", "Speed", "1")
    ui.loopCheck = vgui.Create("DCheckBoxLabel", playback)
    ui.loopCheck:SetPos(330, 34)
    ui.loopCheck:SetText("Loop")
    ui.loopCheck:SetValue(GetSavedString("play_loop", "1") == "1" and 1 or 0)
    ui.loopCheck:SizeToContents()
    ui.loopCheck.OnChange = function(_, value)
        SetSavedString("play_loop", value and "1" or "0")
    end
    AddButton(playback, 10, 68, 150, 28, "Play On Looked-at Ragdoll", function()
        local name = string.Trim(ui.playNameEntry:GetValue())
        local speed = string.Trim(ui.playSpeedEntry:GetValue())
        if name == "" then return end
        RunAnimatorCommand("ragdoll_play", name, speed, ui.loopCheck:GetChecked() and "1" or "0")
    end)
    AddButton(playback, 170, 68, 150, 28, "Stop On Looked-at Ragdoll", function()
        local name = string.Trim(ui.playNameEntry:GetValue())
        if name == "" then return end
        RunAnimatorCommand("ragdoll_stop", name)
    end)

    local recordingsSection = BuildSection(scroll, "Session Memory", 190)
    local recInfo = vgui.Create("DLabel", recordingsSection)
    recInfo:SetPos(10, 30)
    recInfo:SetSize(590, 18)
    recInfo:SetText("This list comes from live server session state. Double-click a recording to fill the current fields.")
    ui.recordingList = vgui.Create("DListView", recordingsSection)
    ui.recordingList:SetPos(10, 54)
    ui.recordingList:SetSize(590, 92)
    ui.recordingList:AddColumn("Available Recordings")
    ui.recordingList.OnRowSelected = function(_, _, row)
        ApplyRecordingNameToFields(row:GetColumnText(1))
    end
    AddButton(recordingsSection, 10, 152, 120, 26, "Refresh", function()
        RequestStatus()
    end)
    AddButton(recordingsSection, 140, 152, 180, 26, "Use Selected Recording", function()
        local line = ui.recordingList:GetSelectedLine()
        if not line then return end
        local row = ui.recordingList:GetLine(line)
        if not IsValid(row) then return end
        ApplyRecordingNameToFields(row:GetColumnText(1))
    end)
    AddButton(recordingsSection, 330, 152, 120, 26, "Close", function()
        if IsValid(frame) then
            frame:Close()
        end
    end)

    UpdateStatusText()
    RequestStatus()
    return frame
end

hook.Add("HUDPaint", "RagdollAnimator_HUD", function()
    if not isRecording then return end

    local elapsed = CurTime() - recordingStartTime
    draw.SimpleText("[RECORDING] " .. tostring(currentRecordingName or ""), "DermaLarge", 10, 10, Color(255, 80, 80, 255))
    draw.SimpleText(
        string.format("Frames: %d | Time: %.1fs", tonumber(recordingFrameCount) or 0, elapsed),
        "Default",
        10,
        34,
        Color(255, 255, 255, 255)
    )
end)

concommand.Add("ragdoll_animator_menu", function()
    EnsureMenu()
end)

hook.Add("OnPlayerChat", "RagdollAnimator_MenuChatShortcut", function(ply, text)
    if ply ~= LocalPlayer() then return end
    local lowered = string.Trim(string.lower(text or ""))
    if lowered == "!raganim" or lowered == "/raganim" then
        EnsureMenu()
        return true
    end
end)

net.Receive("RagdollAnimator_Status", function()
    local received = net.ReadTable() or {}
    statusState.recordings = istable(received.recordings) and received.recordings or {}
    statusState.activeRecording = tostring(received.activeRecording or "")
    statusState.mirrorRecording = tostring(received.mirrorRecording or "")
    statusState.mirrorRecordingFront = tostring(received.mirrorRecordingFront or "")
    statusState.mirrorRecordingBack = tostring(received.mirrorRecordingBack or "")
    statusState.hasAimTarget = received.hasAimTarget == true
    statusState.isAimCapturing = received.isAimCapturing == true
    statusState.aimSamples = tonumber(received.aimSamples) or 0
    statusState.aimYawBias = tonumber(received.aimYawBias) or 0
    statusState.aimPitchBias = tonumber(received.aimPitchBias) or 0
    UpdateStatusText()
end)

net.Receive("RagdollAnimator_RecordingStarted", function()
    isRecording = true
    currentRecordingName = net.ReadString()
    recordingFrameCount = 0
    recordingStartTime = CurTime()
    QueueStatusRefresh()
end)

net.Receive("RagdollAnimator_RecordingStopped", function()
    currentRecordingName = net.ReadString()
    recordingFrameCount = net.ReadUInt(16)
    isRecording = false
    QueueStatusRefresh()
end)

net.Receive("RagdollAnimator_FrameRecorded", function()
    recordingFrameCount = net.ReadUInt(16)
end)