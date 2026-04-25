local TOOL_WEAPON_CLASS = "weapon_alyx_standin_tool"
local NET_REQUEST_BROWSER = "ZC_AlyxStandin_RequestBrowser"
local NET_SEND_BROWSER = "ZC_AlyxStandin_SendBrowser"
local NET_REQUEST_START = "ZC_AlyxStandin_RequestStart"
local NET_REQUEST_STOP = "ZC_AlyxStandin_RequestStop"
local NET_STATUS = "ZC_AlyxStandin_Status"
local DEFAULT_DURATION = 5
local MAX_DURATION = 30

if SERVER then
    AddCSLuaFile()
    util.AddNetworkString(NET_REQUEST_BROWSER)
    util.AddNetworkString(NET_SEND_BROWSER)
    util.AddNetworkString(NET_REQUEST_START)
    util.AddNetworkString(NET_REQUEST_STOP)
    util.AddNetworkString(NET_STATUS)
end

ZC_AlyxStandin = ZC_AlyxStandin or {}

local BLOCKED_PLAYER_CLASSES = {
    gordon = true,
    combine = true,
    metrocop = true,
}

local MOVE_TO_LABELS = {
    [0] = "Stay",
    [1] = "Walk",
    [2] = "Run",
    [4] = "Teleport",
}

local function trimInternal(value)
    value = string.Trim(tostring(value or ""))
    if value == "NULL" then
        return ""
    end
    return value
end

local function normalizeBlockedClass(name)
    local key = string.lower(string.Trim(tostring(name or "")))

    if key == "freeman" then return "gordon" end
    if key == "overwatch" then return "combine" end
    if key == "metropolice" or key == "civilprotection" or key == "civil_protection" then
        return "metrocop"
    end

    return key
end

local function isEligiblePlayer(ply)
    if not IsValid(ply) or not ply:IsPlayer() then
        return false, "Player no longer valid."
    end

    if not ply:Alive() then
        return false, "You must be alive to stand in for Alyx."
    end

    local className = normalizeBlockedClass(ply.PlayerClassName)
    if BLOCKED_PLAYER_CLASSES[className] then
        return false, "This playerclass cannot replace Alyx."
    end

    return true
end

local function getMoveToLabel(moveTo)
    return MOVE_TO_LABELS[moveTo] or tostring(moveTo)
end

local function getSequenceEntry(seq)
    local moveTo = tonumber(seq:GetInternalVariable("m_fMoveTo") or 0) or 0

    return {
        entIndex = seq:EntIndex(),
        name = trimInternal(seq:GetName()),
        targetName = trimInternal(seq:GetInternalVariable("m_iszEntity")),
        playSequence = trimInternal(seq:GetInternalVariable("m_iszPlay")),
        idleSequence = trimInternal(seq:GetInternalVariable("m_iszIdle")),
        nextSequence = trimInternal(seq:GetInternalVariable("m_iszNextScript")),
        moveTo = moveTo,
        moveToLabel = getMoveToLabel(moveTo),
        radius = tonumber(seq:GetInternalVariable("m_flRadius") or 0) or 0,
        pos = seq:GetPos(),
    }
end

local function collectSequenceEntries()
    local out = {}

    for _, seq in ipairs(ents.FindByClass("scripted_sequence")) do
        if not IsValid(seq) then continue end
        out[#out + 1] = getSequenceEntry(seq)
    end

    table.sort(out, function(left, right)
        local leftKey = string.lower((left.name ~= "" and left.name or left.targetName ~= "" and left.targetName or tostring(left.entIndex)))
        local rightKey = string.lower((right.name ~= "" and right.name or right.targetName ~= "" and right.targetName or tostring(right.entIndex)))
        return leftKey < rightKey
    end)

    return out
end

ZC_AlyxStandin.CollectSequenceEntries = collectSequenceEntries
ZC_AlyxStandin.IsEligiblePlayer = isEligiblePlayer

if SERVER then
    local activeStandins = {}

    ZC_AlyxStandin.ActiveStandins = activeStandins

    local function sendStatus(ply, msg)
        if not IsValid(ply) then return end

        net.Start(NET_STATUS)
            net.WriteString(tostring(msg or ""))
        net.Send(ply)
    end

    local function canUseTool(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return false end

        local activeWeapon = ply:GetActiveWeapon()
        if IsValid(activeWeapon) and activeWeapon:GetClass() == TOOL_WEAPON_CLASS then
            return true
        end

        if ply.HasWeapon and ply:HasWeapon(TOOL_WEAPON_CLASS) then
            return true
        end

        return false
    end

    local function sendBrowser(ply)
        local entries = collectSequenceEntries()

        net.Start(NET_SEND_BROWSER)
            net.WriteUInt(#entries, 16)
            for _, entry in ipairs(entries) do
                net.WriteUInt(entry.entIndex, 16)
                net.WriteString(entry.name)
                net.WriteString(entry.targetName)
                net.WriteString(entry.playSequence)
                net.WriteString(entry.idleSequence)
                net.WriteString(entry.nextSequence)
                net.WriteInt(entry.moveTo, 8)
                net.WriteFloat(entry.radius)
                net.WriteVector(entry.pos)
            end
        net.Send(ply)
    end

    local function stopStandin(ply, reason, silent)
        local state = activeStandins[ply]
        if not state then
            if not silent and reason and reason ~= "" then
                sendStatus(ply, reason)
            end
            return
        end

        activeStandins[ply] = nil
        timer.Remove(state.timerName)

        if IsValid(state.proxy) then
            state.proxy:Remove()
        end

        if IsValid(ply) then
            ply:Freeze(false)
            if state.collisionGroup ~= nil then
                ply:SetCollisionGroup(state.collisionGroup)
            end
            if ply.PlayCustomAnims then
                ply:PlayCustomAnims("")
            end
            ply:SetNWBool("ZC_AlyxStandinActive", false)
            ply:SetNWString("ZC_AlyxStandinTarget", "")
            ply:SetNWInt("ZC_AlyxStandinSequence", 0)
            ply:SetLocalVelocity(vector_origin)
        end

        if not silent and reason and reason ~= "" then
            sendStatus(ply, reason)
        end
    end

    local function findConflictingTarget(targetName, owner)
        if targetName == "" then return end

        for _, ent in ipairs(ents.GetAll()) do
            if not IsValid(ent) or ent == owner then continue end
            if ent:GetName() == targetName then
                return ent
            end
        end
    end

    local function buildProxy(ply, targetName)
        if targetName == "" then return end

        local conflict = findConflictingTarget(targetName, ply)
        if IsValid(conflict) then
            return nil, conflict
        end

        local proxy = ents.Create("info_target")
        if not IsValid(proxy) then
            return nil
        end

        proxy:SetKeyValue("targetname", targetName)
        proxy:SetName(targetName)
        proxy:SetOwner(ply)
        proxy:SetPos(ply:GetPos())
        proxy:SetAngles(ply:EyeAngles())
        proxy:Spawn()
        proxy:SetSolid(SOLID_NONE)
        proxy:SetMoveType(MOVETYPE_NONE)
        proxy:SetNoDraw(true)
        proxy:DrawShadow(false)
        proxy:SetParent(ply)

        return proxy
    end

    local function resolveAnimation(ply, requestedName, entry)
        local candidates = {
            string.Trim(tostring(requestedName or "")),
            entry.playSequence,
            entry.idleSequence,
        }
        local seen = {}

        for _, name in ipairs(candidates) do
            local key = string.lower(name)
            if name ~= "" and not seen[key] then
                seen[key] = true
                local seqIndex, seqDuration = ply:LookupSequence(name)
                if seqIndex and seqIndex >= 0 then
                    return name, seqDuration or 0
                end
            end
        end

        return "", 0
    end

    local function startStandin(ply, seqEnt, requestedDuration, requestedAnim)
        local ok, reason = isEligiblePlayer(ply)
        if not ok then
            sendStatus(ply, reason)
            return
        end

        if not canUseTool(ply) then
            sendStatus(ply, "You need the Alyx stand-in tool to do that.")
            return
        end

        if not IsValid(seqEnt) or seqEnt:GetClass() ~= "scripted_sequence" then
            sendStatus(ply, "That scripted_sequence is no longer valid.")
            return
        end

        local entry = getSequenceEntry(seqEnt)
        local animName, animDuration = resolveAnimation(ply, requestedAnim, entry)
        local holdDuration = tonumber(requestedDuration)

        if not holdDuration or holdDuration <= 0 then
            holdDuration = animDuration > 0 and animDuration or DEFAULT_DURATION
        end

        holdDuration = math.Clamp(holdDuration, 0.25, MAX_DURATION)

        stopStandin(ply, nil, true)

        local proxy, conflict = buildProxy(ply, entry.targetName)
        local state = {
            timerName = "ZC_AlyxStandin_" .. ply:EntIndex(),
            collisionGroup = ply:GetCollisionGroup(),
            proxy = proxy,
        }

        activeStandins[ply] = state

        local ang = seqEnt:GetAngles()
        ang.p = 0
        ang.r = 0

        ply:SetPos(seqEnt:GetPos())
        ply:SetEyeAngles(ang)
        ply:SetLocalVelocity(vector_origin)
        ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
        ply:Freeze(true)
        ply:SetNWBool("ZC_AlyxStandinActive", true)
        ply:SetNWString("ZC_AlyxStandinTarget", entry.targetName)
        ply:SetNWInt("ZC_AlyxStandinSequence", seqEnt:EntIndex())

        if animName ~= "" and ply.PlayCustomAnims then
            ply:PlayCustomAnims(animName, true, animDuration > 0 and animDuration or nil, false, 0)
        end

        timer.Create(state.timerName, holdDuration, 1, function()
            if not IsValid(ply) then return end
            stopStandin(ply, "Stand-in complete.", false)
        end)

        local label = entry.name ~= "" and entry.name or ("scripted_sequence #" .. seqEnt:EntIndex())
        local targetLabel = entry.targetName ~= "" and entry.targetName or "none"
        local animLabel = animName ~= "" and animName or "no matching player animation"
        local suffix = ""

        if IsValid(conflict) then
            suffix = string.format(" | target already claimed by %s [%d]", conflict:GetClass(), conflict:EntIndex())
        end

        sendStatus(ply, string.format("Stand-in started: %s | target=%s | anim=%s | %.1fs%s", label, targetLabel, animLabel, holdDuration, suffix))
    end

    ZC_AlyxStandin.Start = startStandin
    ZC_AlyxStandin.Stop = stopStandin

    hook.Add("StartCommand", "ZC_AlyxStandin_BlockInput", function(ply, cmd)
        if not activeStandins[ply] then return end

        cmd:ClearButtons()
        cmd:ClearMovement()
        cmd:SetForwardMove(0)
        cmd:SetSideMove(0)
        cmd:SetUpMove(0)
        cmd:SetMouseX(0)
        cmd:SetMouseY(0)
    end)

    hook.Add("PlayerDeath", "ZC_AlyxStandin_StopOnDeath", function(ply)
        stopStandin(ply, "", true)
    end)

    hook.Add("PlayerDisconnected", "ZC_AlyxStandin_StopOnDisconnect", function(ply)
        stopStandin(ply, "", true)
    end)

    hook.Add("PlayerSpawn", "ZC_AlyxStandin_StopOnSpawn", function(ply)
        stopStandin(ply, "", true)
    end)

    net.Receive(NET_REQUEST_BROWSER, function(_, ply)
        if not canUseTool(ply) then
            sendStatus(ply, "Equip or carry the Alyx stand-in tool first.")
            return
        end

        sendBrowser(ply)
    end)

    net.Receive(NET_REQUEST_START, function(_, ply)
        local entIndex = net.ReadUInt(16)
        local requestedDuration = net.ReadFloat()
        local requestedAnim = net.ReadString()
        local seqEnt = ents.GetByIndex(entIndex)

        startStandin(ply, seqEnt, requestedDuration, requestedAnim)
    end)

    net.Receive(NET_REQUEST_STOP, function(_, ply)
        stopStandin(ply, "Stand-in cancelled.", false)
    end)

    return
end

local browserEntries = {}
local browserFrame
local selectedEntry
local pendingDuration = DEFAULT_DURATION
local pendingAnimOverride = ""

local function moveToLabel(moveTo)
    return MOVE_TO_LABELS[moveTo] or tostring(moveTo)
end

local function addClientStatus(msg)
    msg = tostring(msg or "")
    if msg == "" then return end

    if notification and notification.AddLegacy then
        notification.AddLegacy(msg, NOTIFY_HINT, 4)
    end

    if chat and chat.AddText then
        chat.AddText(Color(140, 210, 255), "[Alyx Stand-In] ", color_white, msg)
    end

    if IsValid(browserFrame) and IsValid(browserFrame.FeedbackLabel) then
        browserFrame.FeedbackLabel:SetText(msg)
    end
end

local function getConfiguredDuration()
    if IsValid(browserFrame) and IsValid(browserFrame.DurationEntry) then
        pendingDuration = tonumber(browserFrame.DurationEntry:GetValue()) or pendingDuration
    end

    pendingDuration = math.Clamp(tonumber(pendingDuration) or DEFAULT_DURATION, 0, MAX_DURATION)
    return pendingDuration
end

local function getConfiguredAnimOverride()
    if IsValid(browserFrame) and IsValid(browserFrame.AnimEntry) then
        pendingAnimOverride = string.Trim(browserFrame.AnimEntry:GetValue() or "")
    end

    return pendingAnimOverride
end

local function requestBrowser()
    net.Start(NET_REQUEST_BROWSER)
    net.SendToServer()
end

local function sendStartForEntry(entry)
    if not entry then
        addClientStatus("Pick a scripted_sequence first.")
        return
    end

    net.Start(NET_REQUEST_START)
        net.WriteUInt(entry.entIndex, 16)
        net.WriteFloat(getConfiguredDuration())
        net.WriteString(getConfiguredAnimOverride())
    net.SendToServer()
end

local function sendStop()
    net.Start(NET_REQUEST_STOP)
    net.SendToServer()
end

local function findLookSequence(maxDistance)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local eyePos = ply:EyePos()
    local forward = ply:EyeAngles():Forward()
    local bestEnt
    local bestScore

    for _, ent in ipairs(ents.FindByClass("scripted_sequence")) do
        if not IsValid(ent) then continue end

        local offset = ent:GetPos() - eyePos
        local distance = offset:Length()
        if distance <= 0 or distance > maxDistance then continue end

        local dot = forward:Dot(offset:GetNormalized())
        if dot < 0.96 then continue end

        local score = dot * 100000 - distance
        if not bestScore or score > bestScore then
            bestScore = score
            bestEnt = ent
        end
    end

    return bestEnt
end

local function updateBrowserList(frame)
    if not IsValid(frame) or not IsValid(frame.List) then return end

    frame.List:Clear()
    selectedEntry = nil

    local query = IsValid(frame.SearchEntry) and string.lower(string.Trim(frame.SearchEntry:GetValue() or "")) or ""

    for _, entry in ipairs(browserEntries) do
        local haystack = string.lower(table.concat({
            entry.name,
            entry.targetName,
            entry.playSequence,
            entry.idleSequence,
            entry.nextSequence,
            tostring(entry.entIndex),
        }, " "))

        if query ~= "" and not string.find(haystack, query, 1, true) then
            continue
        end

        local row = frame.List:AddLine(
            entry.name ~= "" and entry.name or ("#" .. entry.entIndex),
            entry.targetName ~= "" and entry.targetName or "-",
            entry.playSequence ~= "" and entry.playSequence or "-",
            entry.idleSequence ~= "" and entry.idleSequence or "-",
            entry.moveToLabel,
            entry.nextSequence ~= "" and entry.nextSequence or "-"
        )
        row.Entry = entry
    end

    if IsValid(frame.FeedbackLabel) then
        frame.FeedbackLabel:SetText(string.format("Loaded %d scripted_sequence refs.", #browserEntries))
    end
end

local function updateDetail(frame, entry)
    if not IsValid(frame) or not IsValid(frame.DetailLabel) then return end

    if not entry then
        frame.DetailLabel:SetText("Select a scripted_sequence to inspect its references.")
        return
    end

    frame.DetailLabel:SetText(string.format(
        "Ref: %s\nTarget: %s\nPlay: %s\nIdle: %s\nNext: %s\nMoveTo: %s\nRadius: %.1f\nPos: %.0f %.0f %.0f",
        entry.name ~= "" and entry.name or ("#" .. entry.entIndex),
        entry.targetName ~= "" and entry.targetName or "-",
        entry.playSequence ~= "" and entry.playSequence or "-",
        entry.idleSequence ~= "" and entry.idleSequence or "-",
        entry.nextSequence ~= "" and entry.nextSequence or "-",
        entry.moveToLabel,
        entry.radius,
        entry.pos.x,
        entry.pos.y,
        entry.pos.z
    ))
end

local function openBrowser()
    if IsValid(browserFrame) then
        browserFrame:MakePopup()
        browserFrame:SetVisible(true)
        browserFrame:MoveToFront()
        updateBrowserList(browserFrame)
        updateDetail(browserFrame, selectedEntry)
        return
    end

    local frame = vgui.Create("DFrame")
    frame:SetTitle("Alyx Stand-In Browser")
    frame:SetSize(1040, 620)
    frame:Center()
    frame:MakePopup()
    frame:SetSizable(true)
    frame:SetMinWidth(860)
    frame:SetMinHeight(520)

    local searchEntry = vgui.Create("DTextEntry", frame)
    searchEntry:SetPos(12, 34)
    searchEntry:SetSize(250, 24)
    searchEntry:SetPlaceholderText("Search refs, targets, or sequences...")
    searchEntry.OnValueChange = function()
        updateBrowserList(frame)
        updateDetail(frame, selectedEntry)
    end

    local durationLabel = vgui.Create("DLabel", frame)
    durationLabel:SetPos(274, 38)
    durationLabel:SetSize(70, 16)
    durationLabel:SetText("Duration")

    local durationEntry = vgui.Create("DTextEntry", frame)
    durationEntry:SetPos(336, 34)
    durationEntry:SetSize(60, 24)
    durationEntry:SetValue(tostring(pendingDuration))

    local animLabel = vgui.Create("DLabel", frame)
    animLabel:SetPos(410, 38)
    animLabel:SetSize(100, 16)
    animLabel:SetText("Anim Override")

    local animEntry = vgui.Create("DTextEntry", frame)
    animEntry:SetPos(500, 34)
    animEntry:SetSize(200, 24)
    animEntry:SetPlaceholderText("Optional player sequence name")
    animEntry:SetValue(pendingAnimOverride)

    local refreshButton = vgui.Create("DButton", frame)
    refreshButton:SetPos(712, 34)
    refreshButton:SetSize(74, 24)
    refreshButton:SetText("Refresh")
    refreshButton.DoClick = requestBrowser

    local useLookButton = vgui.Create("DButton", frame)
    useLookButton:SetPos(792, 34)
    useLookButton:SetSize(114, 24)
    useLookButton:SetText("Use Aimed Ref")
    useLookButton.DoClick = function()
        local ent = findLookSequence(4096)
        if not IsValid(ent) then
            addClientStatus("No scripted_sequence is inside the crosshair cone.")
            return
        end

        sendStartForEntry({ entIndex = ent:EntIndex() })
    end

    local stopButton = vgui.Create("DButton", frame)
    stopButton:SetPos(912, 34)
    stopButton:SetSize(114, 24)
    stopButton:SetText("Cancel Stand-In")
    stopButton.DoClick = sendStop

    local list = vgui.Create("DListView", frame)
    list:SetPos(12, 68)
    list:SetSize(1014, 360)
    list:SetMultiSelect(false)
    list:AddColumn("Reference")
    list:AddColumn("Target")
    list:AddColumn("Play")
    list:AddColumn("Idle")
    list:AddColumn("Move")
    list:AddColumn("Next")
    list.OnRowSelected = function(_, _, row)
        selectedEntry = row.Entry
        updateDetail(frame, selectedEntry)
    end
    list.DoDoubleClick = function(_, _, row)
        selectedEntry = row.Entry
        updateDetail(frame, selectedEntry)
        sendStartForEntry(selectedEntry)
    end

    local detailLabel = vgui.Create("DLabel", frame)
    detailLabel:SetPos(12, 438)
    detailLabel:SetSize(700, 112)
    detailLabel:SetWrap(true)
    detailLabel:SetAutoStretchVertical(true)
    detailLabel:SetText("Select a scripted_sequence to inspect its references.")

    local selectedButton = vgui.Create("DButton", frame)
    selectedButton:SetPos(12, 556)
    selectedButton:SetSize(180, 30)
    selectedButton:SetText("Start Selected Stand-In")
    selectedButton.DoClick = function()
        sendStartForEntry(selectedEntry)
    end

    local feedbackLabel = vgui.Create("DLabel", frame)
    feedbackLabel:SetPos(206, 563)
    feedbackLabel:SetSize(820, 18)
    feedbackLabel:SetText("")

    frame.SearchEntry = searchEntry
    frame.DurationEntry = durationEntry
    frame.AnimEntry = animEntry
    frame.List = list
    frame.DetailLabel = detailLabel
    frame.FeedbackLabel = feedbackLabel

    browserFrame = frame

    updateBrowserList(frame)
    updateDetail(frame, selectedEntry)
end

concommand.Add("zc_alyx_standin_browser", function()
    requestBrowser()
end)

concommand.Add("zc_alyx_standin_activate_look", function()
    local ent = findLookSequence(4096)
    if not IsValid(ent) then
        addClientStatus("No scripted_sequence is inside the crosshair cone.")
        return
    end

    sendStartForEntry({ entIndex = ent:EntIndex() })
end)

concommand.Add("zc_alyx_standin_stop", function()
    sendStop()
end)

net.Receive(NET_SEND_BROWSER, function()
    browserEntries = {}

    local count = net.ReadUInt(16)
    for index = 1, count do
        browserEntries[index] = {
            entIndex = net.ReadUInt(16),
            name = net.ReadString(),
            targetName = net.ReadString(),
            playSequence = net.ReadString(),
            idleSequence = net.ReadString(),
            nextSequence = net.ReadString(),
            moveTo = net.ReadInt(8),
            radius = net.ReadFloat(),
            pos = net.ReadVector(),
        }
        browserEntries[index].moveToLabel = moveToLabel(browserEntries[index].moveTo)
    end

    openBrowser()
end)

net.Receive(NET_STATUS, function()
    addClientStatus(net.ReadString())
end)

hook.Add("HUDPaint", "ZC_AlyxStandin_Help", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local weapon = ply:GetActiveWeapon()
    if not IsValid(weapon) or weapon:GetClass() ~= TOOL_WEAPON_CLASS then return end

    local x = ScrW() * 0.5
    local y = ScrH() - 106
    local aimed = findLookSequence(4096)
    local aimedText = "Aimed ref: none"

    if IsValid(aimed) then
        local entry = getSequenceEntry(aimed)
        local label = entry.name ~= "" and entry.name or ("#" .. aimed:EntIndex())
        aimedText = string.format("Aimed ref: %s -> %s", label, entry.targetName ~= "" and entry.targetName or "no target")
    end

    draw.SimpleTextOutlined("Primary: use aimed scripted_sequence | Reload: browser | Secondary: cancel", "Trebuchet18", x, y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
    draw.SimpleTextOutlined(aimedText, "Trebuchet18", x, y + 22, Color(140, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end)