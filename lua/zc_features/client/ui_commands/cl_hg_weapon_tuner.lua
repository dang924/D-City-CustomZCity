local function GetActiveWeaponSafe()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return nil end

    return wep
end

local function VecOrDefault(v)
    if isvector(v) then return v end
    return Vector(0, 0, 0)
end

local function AngOrDefault(a)
    if isangle(a) then return a end
    return Angle(0, 0, 0)
end

local function BuildStateFromWeapon(wep)
    local zoom = VecOrDefault(wep.ZoomPos)
    local fakePos = VecOrDefault(wep.FakePos)
    local fakeAng = AngOrDefault(wep.FakeAng)
    local attPos = VecOrDefault(wep.AttachmentPos)
    local attAng = AngOrDefault(wep.AttachmentAng)
    local muPos = VecOrDefault(wep.LocalMuzzlePos)
    local muAng = AngOrDefault(wep.LocalMuzzleAng)
    local trAng = AngOrDefault(wep.TraceAngOffset)

    return {
        class = wep:GetClass(),

        hasZoomPos = wep.ZoomPos ~= nil,
        hasFakePos = wep.FakePos ~= nil,
        hasFakeAng = wep.FakeAng ~= nil,
        hasAttachmentPos = wep.AttachmentPos ~= nil,
        hasAttachmentAng = wep.AttachmentAng ~= nil,
        hasMuzzlePos = wep.LocalMuzzlePos ~= nil,
        hasMuzzleAng = wep.LocalMuzzleAng ~= nil,
        hasTraceOffset = wep.TraceAngOffset ~= nil,
        hasTraceMul = wep.GarandTraceMultiplier ~= nil,
        hasADSTraceToggle = wep.GarandUseADSTrace ~= nil,
        hasTraceOffsetToggle = wep.GarandEnableTraceOffset ~= nil,

        zoom_x = zoom[1],
        zoom_y = zoom[2],
        zoom_z = zoom[3],

        fakepos_x = fakePos[1],
        fakepos_y = fakePos[2],
        fakepos_z = fakePos[3],

        fakeang_p = fakeAng[1],
        fakeang_y = fakeAng[2],
        fakeang_r = fakeAng[3],

        attpos_x = attPos[1],
        attpos_y = attPos[2],
        attpos_z = attPos[3],

        attang_p = attAng[1],
        attang_y = attAng[2],
        attang_r = attAng[3],

        muzzlepos_x = muPos[1],
        muzzlepos_y = muPos[2],
        muzzlepos_z = muPos[3],

        muzzleang_p = muAng[1],
        muzzleang_y = muAng[2],
        muzzleang_r = muAng[3],

        trace_pitch = trAng[1],
        trace_yaw = trAng[2],

        trace_mul = math.Clamp(tonumber(wep.GarandTraceMultiplier) or 1, 0.1, 20),
        use_ads_trace = wep.GarandUseADSTrace ~= false,
        use_trace_offset = wep.GarandEnableTraceOffset ~= false,

        show_hit_debug = GetConVar("hg_show_hitposmuzzle") and GetConVar("hg_show_hitposmuzzle"):GetBool() or false,
        set_zoom_mode = GetConVar("hg_setzoompos") and GetConVar("hg_setzoompos"):GetBool() or false,
    }
end

local function ApplyStateLocal(wep, s)
    if s.hasZoomPos then wep.ZoomPos = Vector(s.zoom_x, s.zoom_y, s.zoom_z) end
    if s.hasFakePos then wep.FakePos = Vector(s.fakepos_x, s.fakepos_y, s.fakepos_z) end
    if s.hasFakeAng then wep.FakeAng = Angle(s.fakeang_p, s.fakeang_y, s.fakeang_r) end
    if s.hasAttachmentPos then wep.AttachmentPos = Vector(s.attpos_x, s.attpos_y, s.attpos_z) end
    if s.hasAttachmentAng then wep.AttachmentAng = Angle(s.attang_p, s.attang_y, s.attang_r) end
    if s.hasMuzzlePos then wep.LocalMuzzlePos = Vector(s.muzzlepos_x, s.muzzlepos_y, s.muzzlepos_z) end
    if s.hasMuzzleAng then wep.LocalMuzzleAng = Angle(s.muzzleang_p, s.muzzleang_y, s.muzzleang_r) end

    if s.hasTraceOffset then
        wep.TraceAngOffset = Angle(s.trace_pitch, s.trace_yaw, 0)
        if wep.GarandTracePitch ~= nil then wep.GarandTracePitch = s.trace_pitch end
        if wep.GarandTraceYaw ~= nil then wep.GarandTraceYaw = s.trace_yaw end
    end

    if s.hasTraceMul then wep.GarandTraceMultiplier = s.trace_mul end
    if s.hasADSTraceToggle then wep.GarandUseADSTrace = s.use_ads_trace ~= false end
    if s.hasTraceOffsetToggle then wep.GarandEnableTraceOffset = s.use_trace_offset ~= false end
end

local function BuildPayload(s)
    local out = {class = s.class}

    if s.hasZoomPos then out.ZoomPos = {x = s.zoom_x, y = s.zoom_y, z = s.zoom_z} end
    if s.hasFakePos then out.FakePos = {x = s.fakepos_x, y = s.fakepos_y, z = s.fakepos_z} end
    if s.hasFakeAng then out.FakeAng = {p = s.fakeang_p, y = s.fakeang_y, r = s.fakeang_r} end
    if s.hasAttachmentPos then out.AttachmentPos = {x = s.attpos_x, y = s.attpos_y, z = s.attpos_z} end
    if s.hasAttachmentAng then out.AttachmentAng = {p = s.attang_p, y = s.attang_y, r = s.attang_r} end
    if s.hasMuzzlePos then out.LocalMuzzlePos = {x = s.muzzlepos_x, y = s.muzzlepos_y, z = s.muzzlepos_z} end
    if s.hasMuzzleAng then out.LocalMuzzleAng = {p = s.muzzleang_p, y = s.muzzleang_y, r = s.muzzleang_r} end

    if s.hasTraceOffset then out.TraceAngOffset = {p = s.trace_pitch, y = s.trace_yaw} end
    if s.hasTraceMul then out.GarandTraceMultiplier = s.trace_mul end
    if s.hasADSTraceToggle then out.GarandUseADSTrace = s.use_ads_trace ~= false end
    if s.hasTraceOffsetToggle then out.GarandEnableTraceOffset = s.use_trace_offset ~= false end

    return out
end

local function SendPayload(tbl)
    net.Start("hg_wep_tuner_apply")
        net.WriteTable(tbl)
    net.SendToServer()
end

local function PrintState(s)
    local lines = {}

    if s.hasZoomPos then table.insert(lines, string.format("SWEP.ZoomPos = Vector(%.4f, %.4f, %.4f)", s.zoom_x, s.zoom_y, s.zoom_z)) end
    if s.hasFakePos then table.insert(lines, string.format("SWEP.FakePos = Vector(%.4f, %.4f, %.4f)", s.fakepos_x, s.fakepos_y, s.fakepos_z)) end
    if s.hasFakeAng then table.insert(lines, string.format("SWEP.FakeAng = Angle(%.4f, %.4f, %.4f)", s.fakeang_p, s.fakeang_y, s.fakeang_r)) end
    if s.hasAttachmentPos then table.insert(lines, string.format("SWEP.AttachmentPos = Vector(%.4f, %.4f, %.4f)", s.attpos_x, s.attpos_y, s.attpos_z)) end
    if s.hasAttachmentAng then table.insert(lines, string.format("SWEP.AttachmentAng = Angle(%.4f, %.4f, %.4f)", s.attang_p, s.attang_y, s.attang_r)) end
    if s.hasMuzzlePos then table.insert(lines, string.format("SWEP.LocalMuzzlePos = Vector(%.4f, %.4f, %.4f)", s.muzzlepos_x, s.muzzlepos_y, s.muzzlepos_z)) end
    if s.hasMuzzleAng then table.insert(lines, string.format("SWEP.LocalMuzzleAng = Angle(%.4f, %.4f, %.4f)", s.muzzleang_p, s.muzzleang_y, s.muzzleang_r)) end
    if s.hasTraceOffset then table.insert(lines, string.format("SWEP.TraceAngOffset = Angle(%.4f, %.4f, 0)", s.trace_pitch, s.trace_yaw)) end
    if s.hasTraceMul then table.insert(lines, string.format("SWEP.GarandTraceMultiplier = %.4f", s.trace_mul)) end
    if s.hasADSTraceToggle then table.insert(lines, string.format("SWEP.GarandUseADSTrace = %s", s.use_ads_trace and "true" or "false")) end
    if s.hasTraceOffsetToggle then table.insert(lines, string.format("SWEP.GarandEnableTraceOffset = %s", s.use_trace_offset and "true" or "false")) end

    local out = table.concat(lines, "\n")
    print(out)
    SetClipboardText(out .. "\n")
end

local function OpenTuner()
    local wep = GetActiveWeaponSafe()
    if not IsValid(wep) then
        print("hg_wep_tuner: hold a weapon first")
        return
    end

    local state = BuildStateFromWeapon(wep)
    local initial = table.Copy(state)
    local debounceId = "hg_wep_tuner_apply_" .. LocalPlayer():EntIndex()

    local function QueueApply()
        timer.Create(debounceId, 0.03, 1, function()
            local held = GetActiveWeaponSafe()
            if not IsValid(held) or held:GetClass() ~= state.class then return end
            ApplyStateLocal(held, state)
            SendPayload(BuildPayload(state))
        end)
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(520, 760)
    frame:Center()
    frame:SetTitle("Weapon Live Tuner - " .. state.class)
    frame:MakePopup()

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(6, 6, 6, 6)

    local function AddSlider(label, key, minV, maxV, decimals)
        local s = scroll:Add("DNumSlider")
        s:Dock(TOP)
        s:DockMargin(0, 0, 0, 6)
        s:SetText(label)
        s:SetMinMax(minV, maxV)
        s:SetDecimals(decimals)
        s:SetValue(state[key] or 0)
        function s:OnValueChanged(value)
            state[key] = tonumber(value) or 0

            if string.sub(key, 1, 5) == "zoom_" and state.set_zoom_mode then
                state.set_zoom_mode = false
                RunConsoleCommand("hg_setzoompos", "0")
            end

            QueueApply()
        end
    end

    local function AddCheck(label, key, onChanged)
        local c = scroll:Add("DCheckBoxLabel")
        c:Dock(TOP)
        c:DockMargin(0, 0, 0, 6)
        c:SetText(label)
        c:SetValue(state[key] and 1 or 0)
        c:SizeToContents()
        function c:OnChange(val)
            state[key] = val and true or false
            if onChanged then onChanged(state[key]) end
            QueueApply()
        end
    end

    AddCheck("Show hitpos/muzzle debug", "show_hit_debug", function(val)
        RunConsoleCommand("hg_show_hitposmuzzle", val and "1" or "0")
    end)
    AddCheck("Enable hg_setzoompos mode", "set_zoom_mode", function(val)
        RunConsoleCommand("hg_setzoompos", val and "1" or "0")
    end)

    if state.hasADSTraceToggle then AddCheck("Use ADS trace override", "use_ads_trace") end
    if state.hasTraceOffsetToggle then AddCheck("Apply TraceAngOffset", "use_trace_offset") end

    if state.hasTraceOffset then
        AddSlider("Trace Pitch", "trace_pitch", -30, 30, 3)
        AddSlider("Trace Yaw", "trace_yaw", -30, 30, 3)
    end

    if state.hasTraceMul then
        AddSlider("Trace Multiplier", "trace_mul", 0.1, 20, 3)
    end

    if state.hasZoomPos then
        AddSlider("ZoomPos X", "zoom_x", -64, 64, 4)
        AddSlider("ZoomPos Y", "zoom_y", -64, 64, 4)
        AddSlider("ZoomPos Z", "zoom_z", -64, 64, 4)
    end

    if state.hasFakePos then
        AddSlider("FakePos X", "fakepos_x", -64, 64, 4)
        AddSlider("FakePos Y", "fakepos_y", -64, 64, 4)
        AddSlider("FakePos Z", "fakepos_z", -64, 64, 4)
    end

    if state.hasFakeAng then
        AddSlider("FakeAng Pitch", "fakeang_p", -180, 180, 3)
        AddSlider("FakeAng Yaw", "fakeang_y", -180, 180, 3)
        AddSlider("FakeAng Roll", "fakeang_r", -180, 180, 3)
    end

    if state.hasAttachmentPos then
        AddSlider("AttachmentPos X", "attpos_x", -32, 32, 4)
        AddSlider("AttachmentPos Y", "attpos_y", -32, 32, 4)
        AddSlider("AttachmentPos Z", "attpos_z", -32, 32, 4)
    end

    if state.hasAttachmentAng then
        AddSlider("AttachmentAng Pitch", "attang_p", -180, 180, 3)
        AddSlider("AttachmentAng Yaw", "attang_y", -180, 180, 3)
        AddSlider("AttachmentAng Roll", "attang_r", -180, 180, 3)
    end

    if state.hasMuzzlePos then
        AddSlider("LocalMuzzlePos X", "muzzlepos_x", -64, 64, 4)
        AddSlider("LocalMuzzlePos Y", "muzzlepos_y", -64, 64, 4)
        AddSlider("LocalMuzzlePos Z", "muzzlepos_z", -64, 64, 4)
    end

    if state.hasMuzzleAng then
        AddSlider("LocalMuzzleAng Pitch", "muzzleang_p", -180, 180, 3)
        AddSlider("LocalMuzzleAng Yaw", "muzzleang_y", -180, 180, 3)
        AddSlider("LocalMuzzleAng Roll", "muzzleang_r", -180, 180, 3)
    end

    local btnRow = scroll:Add("DPanel")
    btnRow:Dock(TOP)
    btnRow:DockMargin(0, 4, 0, 0)
    btnRow:SetTall(30)

    local btnPrint = vgui.Create("DButton", btnRow)
    btnPrint:Dock(LEFT)
    btnPrint:SetWide(170)
    btnPrint:SetText("Print + Copy Config")
    btnPrint.DoClick = function()
        PrintState(state)
    end

    local btnReset = vgui.Create("DButton", btnRow)
    btnReset:Dock(LEFT)
    btnReset:DockMargin(6, 0, 0, 0)
    btnReset:SetWide(130)
    btnReset:SetText("Reset Open Values")
    btnReset.DoClick = function()
        for k, v in pairs(initial) do
            state[k] = v
        end

        local held = GetActiveWeaponSafe()
        if IsValid(held) and held:GetClass() == state.class then
            ApplyStateLocal(held, state)
            SendPayload(BuildPayload(state))
        end

        frame:Close()
        OpenTuner()
    end

    local btnApply = vgui.Create("DButton", btnRow)
    btnApply:Dock(FILL)
    btnApply:DockMargin(6, 0, 0, 0)
    btnApply:SetText("Apply Now")
    btnApply.DoClick = function()
        local held = GetActiveWeaponSafe()
        if IsValid(held) and held:GetClass() == state.class then
            ApplyStateLocal(held, state)
            SendPayload(BuildPayload(state))
        end
    end

    frame.OnClose = function()
        timer.Remove(debounceId)
    end
end

concommand.Remove("hg_wep_tuner")
concommand.Add("hg_wep_tuner", OpenTuner)
