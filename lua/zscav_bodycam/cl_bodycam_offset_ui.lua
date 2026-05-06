local BC = ZSCAV.Bodycam

local function canUseTuner()
    local ply = LocalPlayer()
    return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

local function copyState(state)
    return {
        mountBone = tostring(state.mountBone or ""),
        baseOffset = Vector(state.baseOffset.x, state.baseOffset.y, state.baseOffset.z),
        crouchOffset = Vector(state.crouchOffset.x, state.crouchOffset.y, state.crouchOffset.z),
    }
end

local function buildDefaultState()
    return {
        mountBone = tostring(BC.CAMERA_BONE or "ValveBiped.Bip01_Spine4"),
        baseOffset = Vector(
            tonumber(BC.CAMERA_OFFSET and BC.CAMERA_OFFSET.x) or 8,
            tonumber(BC.CAMERA_OFFSET and BC.CAMERA_OFFSET.y) or 0,
            tonumber(BC.CAMERA_OFFSET and BC.CAMERA_OFFSET.z) or -4
        ),
        crouchOffset = Vector(
            tonumber(BC.CAMERA_CROUCH_OFFSET and BC.CAMERA_CROUCH_OFFSET.x) or 0,
            tonumber(BC.CAMERA_CROUCH_OFFSET and BC.CAMERA_CROUCH_OFFSET.y) or 0,
            tonumber(BC.CAMERA_CROUCH_OFFSET and BC.CAMERA_CROUCH_OFFSET.z) or 0
        ),
    }
end

local function buildCommand(state)
    return string.format(
        "zscav_bodycam_offset_set %.2f %.2f %.2f %.2f %.2f %.2f %s",
        tonumber(state.baseOffset.x) or 0,
        tonumber(state.baseOffset.y) or 0,
        tonumber(state.baseOffset.z) or 0,
        tonumber(state.crouchOffset.x) or 0,
        tonumber(state.crouchOffset.y) or 0,
        tonumber(state.crouchOffset.z) or 0,
        tostring(state.mountBone or "ValveBiped.Bip01_Spine4")
    )
end

local function requestStateSync()
    net.Start("ZScav_Bodycam_OffsetStateRequest")
    net.SendToServer()
end

function BC:OpenOffsetTuner()
    if not canUseTuner() then
        chat.AddText(Color(220, 38, 38), "[Bodycam] Admin only.")
        return
    end

    if IsValid(self._offsetTuner) then
        self._offsetTuner:MakePopup()
        self._offsetTuner:Center()
        requestStateSync()
        return
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(560, 610)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(true)
    frame:MakePopup()
    frame:SetSizable(false)

    frame.Paint = function(_, w, h)
        surface.SetDrawColor(24, 28, 38, 248)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(70, 78, 94)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText("BODYCAM OFFSET TUNER", "DermaDefaultBold", 18, 14, color_white)
        draw.SimpleText("Adjust mount offsets, apply live, then print or copy the resulting command.", "DermaDefault", 18, 34, Color(180, 188, 200))
    end

    local status = vgui.Create("DLabel", frame)
    status:SetPos(18, 56)
    status:SetSize(520, 18)
    status:SetTextColor(Color(148, 163, 184))
    status:SetText("Waiting for current server offset state...")

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(14, 80)
    scroll:SetSize(532, 518)

    local list = vgui.Create("DIconLayout", scroll)
    list:Dock(FILL)
    list:SetSpaceY(8)

    local content = vgui.Create("DPanel", list)
    content:SetSize(510, 520)
    content.Paint = function() end

    local y = 0
    local function addLabel(text)
        local label = vgui.Create("DLabel", content)
        label:SetPos(0, y)
        label:SetSize(500, 20)
        label:SetTextColor(Color(226, 232, 240))
        label:SetFont("DermaDefaultBold")
        label:SetText(text)
        y = y + 22
        return label
    end

    local function addTextEntry(labelText, defaultText)
        addLabel(labelText)
        local entry = vgui.Create("DTextEntry", content)
        entry:SetPos(0, y)
        entry:SetSize(500, 24)
        entry:SetText(defaultText or "")
        y = y + 32
        return entry
    end

    local function addSlider(labelText, minValue, maxValue)
        local slider = vgui.Create("DNumSlider", content)
        slider:SetPos(0, y)
        slider:SetSize(500, 34)
        slider:SetText(labelText)
        slider:SetMinMax(minValue, maxValue)
        slider:SetDecimals(2)
        slider:SetDark(true)
        y = y + 36
        return slider
    end

    local boneEntry = addTextEntry("Mount Bone", tostring(BC.CAMERA_BONE or "ValveBiped.Bip01_Spine4"))

    addLabel("Base Offset")
    local sliderForward = addSlider("Forward", -32, 32)
    local sliderRight = addSlider("Right", -32, 32)
    local sliderUp = addSlider("Up", -32, 32)

    addLabel("Crouch Extra Offset")
    local sliderCrouchForward = addSlider("Crouch Forward", -32, 32)
    local sliderCrouchRight = addSlider("Crouch Right", -32, 32)
    local sliderCrouchUp = addSlider("Crouch Up", -32, 32)

    addLabel("Command Preview")
    local commandPreview = vgui.Create("DTextEntry", content)
    commandPreview:SetPos(0, y)
    commandPreview:SetSize(500, 52)
    commandPreview:SetMultiline(true)
    commandPreview:SetEditable(false)
    y = y + 60

    local buttonPanel = vgui.Create("DPanel", content)
    buttonPanel:SetPos(0, y)
    buttonPanel:SetSize(500, 120)
    buttonPanel.Paint = function() end

    local function makeButton(parent, x, yPos, width, text)
        local btn = vgui.Create("DButton", parent)
        btn:SetPos(x, yPos)
        btn:SetSize(width, 30)
        btn:SetText(text)
        return btn
    end

    local refreshBtn = makeButton(buttonPanel, 0, 0, 120, "Refresh")
    local applyBtn = makeButton(buttonPanel, 128, 0, 120, "Apply")
    local applyPrintBtn = makeButton(buttonPanel, 256, 0, 120, "Apply + Print")
    local printBtn = makeButton(buttonPanel, 384, 0, 116, "Print Live")
    local copyBtn = makeButton(buttonPanel, 0, 40, 160, "Copy Command")
    local resetBtn = makeButton(buttonPanel, 168, 40, 160, "Reset Defaults")
    local closeBtn = makeButton(buttonPanel, 336, 40, 164, "Close")

    local help = vgui.Create("DLabel", buttonPanel)
    help:SetPos(0, 82)
    help:SetSize(500, 28)
    help:SetWrap(true)
    help:SetTextColor(Color(148, 163, 184))
    help:SetText("Apply sends the current slider values to the server. Print Live echoes the resolved mount/offset in chat for the current live player state.")

    local function collectState()
        return {
            mountBone = string.Trim(boneEntry:GetValue() or ""),
            baseOffset = Vector(sliderForward:GetValue(), sliderRight:GetValue(), sliderUp:GetValue()),
            crouchOffset = Vector(sliderCrouchForward:GetValue(), sliderCrouchRight:GetValue(), sliderCrouchUp:GetValue()),
        }
    end

    local function updatePreview()
        commandPreview:SetText(buildCommand(collectState()))
    end

    function frame:ApplyState(state)
        if not state then return end
        state = copyState(state)
        boneEntry:SetText(state.mountBone)
        sliderForward:SetValue(state.baseOffset.x)
        sliderRight:SetValue(state.baseOffset.y)
        sliderUp:SetValue(state.baseOffset.z)
        sliderCrouchForward:SetValue(state.crouchOffset.x)
        sliderCrouchRight:SetValue(state.crouchOffset.y)
        sliderCrouchUp:SetValue(state.crouchOffset.z)
        updatePreview()
        status:SetText("Loaded current server offset state.")
        BC._offsetTunerState = state
    end

    local function sendApply(shouldPrint)
        local state = collectState()
        net.Start("ZScav_Bodycam_OffsetStateApply")
            net.WriteString(state.mountBone)
            net.WriteVector(state.baseOffset)
            net.WriteVector(state.crouchOffset)
            net.WriteBool(shouldPrint == true)
        net.SendToServer()
        status:SetText(shouldPrint and "Applied values and requested a live printout." or "Applied values to server. Refreshing...")
    end

    for _, panel in ipairs({ sliderForward, sliderRight, sliderUp, sliderCrouchForward, sliderCrouchRight, sliderCrouchUp }) do
        panel.OnValueChanged = updatePreview
    end
    boneEntry.OnChange = updatePreview

    refreshBtn.DoClick = function()
        status:SetText("Refreshing from server...")
        requestStateSync()
    end

    applyBtn.DoClick = function()
        sendApply(false)
    end

    applyPrintBtn.DoClick = function()
        sendApply(true)
    end

    printBtn.DoClick = function()
        RunConsoleCommand("zscav_bodycam_offset_print", "me")
        status:SetText("Requested live printout in chat.")
    end

    copyBtn.DoClick = function()
        SetClipboardText(commandPreview:GetValue())
        status:SetText("Copied command preview to clipboard.")
    end

    resetBtn.DoClick = function()
        frame:ApplyState(buildDefaultState())
        sendApply(false)
        status:SetText("Reset to defaults and applied to server.")
    end

    closeBtn.DoClick = function()
        frame:Close()
    end

    frame.OnClose = function()
        if BC._offsetTuner == frame then
            BC._offsetTuner = nil
        end
    end

    BC._offsetTuner = frame
    frame:ApplyState(BC._offsetTunerState or buildDefaultState())
    requestStateSync()
end

net.Receive("ZScav_Bodycam_OffsetStateSync", function()
    local state = {
        mountBone = net.ReadString(),
        baseOffset = net.ReadVector(),
        crouchOffset = net.ReadVector(),
    }

    BC._offsetTunerState = copyState(state)

    if IsValid(BC._offsetTuner) and BC._offsetTuner.ApplyState then
        BC._offsetTuner:ApplyState(state)
    end
end)

concommand.Add("zscav_bodycam_offset_gui", function()
    BC:OpenOffsetTuner()
end)