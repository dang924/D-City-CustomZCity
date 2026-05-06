if SERVER then return end

local introEndsAt = 0
local introDuration = 7
local assignedExtracts = {}
local raidInfoMode = nil
local raidInfoVisibleUntil = 0
local raidInfoLastPressAt = 0
local joinHintVisibleUntil = 0
local joinHintIsSpectator = false

local RAID_INFO_TOGGLE_KEY = KEY_O
local RAID_INFO_DOUBLE_PRESS_WINDOW = 2
local RAID_INFO_COMPACT_DURATION = 4
local RAID_INFO_EXPANDED_DURATION = 6
local RAID_INFO_FADE_DURATION = 0.4
local RAID_JOIN_HINT_DURATION = 12
local RAID_JOIN_HINT_FADE_DURATION = 0.4

local function hudScale(value)
    local scale = math.Clamp(math.min(ScrW() / 1920, ScrH() / 1080), 0.85, 1.35)
    return math.max(12, math.floor(value * scale + 0.5))
end

local function rebuildFonts()
    surface.CreateFont("ZScavRaidIntroTitle", {
        font = "Roboto",
        size = hudScale(42),
        weight = 900,
    })

    surface.CreateFont("ZScavRaidIntroSub", {
        font = "Roboto",
        size = hudScale(20),
        weight = 500,
    })

    surface.CreateFont("ZScavRaidInfoTitle", {
        font = "Roboto",
        size = hudScale(24),
        weight = 800,
    })

    surface.CreateFont("ZScavRaidInfoBody", {
        font = "Roboto",
        size = hudScale(17),
        weight = 500,
    })
end

rebuildFonts()

hook.Add("OnScreenSizeChanged", "ZScavRaid_Fonts", function()
    rebuildFonts()
end)

local function formatSeconds(seconds)
    seconds = math.max(math.floor(tonumber(seconds) or 0), 0)
    local minutes = math.floor(seconds / 60)
    local remain = seconds % 60
    return string.format("%02d:%02d", minutes, remain)
end

local function wrapHudText(text, font, maxWidth)
    text = tostring(text or "")
    maxWidth = math.max(math.floor(tonumber(maxWidth) or 0), 1)

    surface.SetFont(font)

    local lines = {}
    local current = ""
    for word in string.gmatch(text, "%S+") do
        local candidate = current == "" and word or (current .. " " .. word)
        local candidateWidth = select(1, surface.GetTextSize(candidate))

        if current ~= "" and candidateWidth > maxWidth then
            lines[#lines + 1] = current
            current = word
        else
            current = candidate
        end
    end

    if current ~= "" then
        lines[#lines + 1] = current
    end

    if #lines <= 0 then
        lines[1] = ""
    end

    return table.concat(lines, "\n"), #lines
end

local function drawRaidInfoPanel(sw, sh, title, lineData, alpha, overrideX, overrideY)
    alpha = math.Clamp(math.floor(tonumber(alpha) or 255), 0, 255)

    local outerPad = hudScale(16)
    local titleTop = hudScale(18)
    local titleGap = hudScale(34)
    local lineGap = hudScale(8)
    local bodyLineH = hudScale(22)
    local panelW = math.min(math.floor(sw * 0.46), hudScale(430))
    local textW = panelW - outerPad * 2
    local wrappedLines = {}
    local bodyHeight = 0

    for _, entry in ipairs(lineData or {}) do
        local wrappedText, lineCount = wrapHudText(entry.text, entry.font or "ZScavRaidInfoBody", textW)
        wrappedLines[#wrappedLines + 1] = {
            text = wrappedText,
            color = entry.color,
            font = entry.font or "ZScavRaidInfoBody",
            lineCount = lineCount,
        }
        bodyHeight = bodyHeight + lineCount * bodyLineH
    end

    if #wrappedLines > 1 then
        bodyHeight = bodyHeight + (#wrappedLines - 1) * lineGap
    end

    local panelH = titleTop + titleGap + bodyHeight + outerPad
    local panelX = overrideX ~= nil and math.floor(overrideX) or (sw - panelW - hudScale(38))
    local panelY = overrideY ~= nil and math.floor(overrideY) or hudScale(38)

    draw.RoundedBox(10, panelX, panelY, panelW, panelH, Color(14, 18, 24, math.floor(210 * (alpha / 255))))
    draw.SimpleText(title, "ZScavRaidInfoTitle", panelX + outerPad, panelY + titleTop, Color(232, 211, 152, alpha))

    local cursorY = panelY + titleGap + titleTop
    for _, entry in ipairs(wrappedLines) do
        draw.DrawText(entry.text, entry.font, panelX + outerPad, cursorY, ColorAlpha(entry.color, alpha), TEXT_ALIGN_LEFT)
        cursorY = cursorY + entry.lineCount * bodyLineH + lineGap
    end

    return panelX, panelY, panelW, panelH
end

local function drawRaidCountdownBar(panelX, panelY, panelW, panelH, fraction, fillColor, alpha)
    alpha = math.Clamp(math.floor(tonumber(alpha) or 255), 0, 255)

    local pad = hudScale(16)
    local barH = hudScale(10)
    local barY = panelY + panelH + hudScale(8)
    local barW = math.max(panelW - pad * 2, 1)
    local fillW = math.max(math.floor(barW * math.Clamp(fraction, 0, 1)), 0)

    draw.RoundedBox(6, panelX + pad, barY, barW, barH, Color(36, 40, 48, math.floor(230 * (alpha / 255))))
    if fillW > 0 then
        draw.RoundedBox(6, panelX + pad, barY, fillW, barH, ColorAlpha(fillColor, alpha))
    end
end

local function getUIScale(value)
    if Nexus and isfunction(Nexus.Scale) then
        return Nexus:Scale(value)
    end

    return hudScale(value)
end

local function getHotbarTopY(sw, sh)
    local totalSlots = math.max(math.floor(tonumber(ZSCAV and ZSCAV.CustomHotbarMax) or 10), 3)
    local gap = getUIScale(6)
    local maxSlotW = math.floor((sw - getUIScale(40) - gap * (totalSlots - 1)) / totalSlots)
    local slotW = math.max(getUIScale(48), math.min(getUIScale(72), maxSlotW))
    local slotH = math.max(getUIScale(56), math.floor(slotW * 0.92))
    return sh - slotH - getUIScale(22)
end

local function drawExtractionProgress(sw, sh, secondsText, fraction, alpha)
    alpha = math.Clamp(math.floor(tonumber(alpha) or 255), 0, 255)

    local barW = math.min(math.floor(sw * 0.42), hudScale(420))
    local barH = hudScale(12)
    local barX = math.floor((sw - barW) * 0.5)
    local hotbarTopY = getHotbarTopY(sw, sh)
    local barY = hotbarTopY - hudScale(28)
    local textY = barY - hudScale(8)

    draw.SimpleText(
        string.format("Extracting in (%s)", secondsText),
        "ZScavRaidInfoBody",
        sw * 0.5,
        textY,
        ColorAlpha(Color(232, 211, 152, 255), alpha),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_BOTTOM
    )

    draw.RoundedBox(6, barX, barY, barW, barH, Color(24, 28, 34, math.floor(230 * (alpha / 255))))

    local fillW = math.max(math.floor(barW * math.Clamp(fraction, 0, 1)), 0)
    if fillW > 0 then
        draw.RoundedBox(6, barX, barY, fillW, barH, ColorAlpha(Color(120, 208, 132, 255), alpha))
    end
end

local function isZScavRoundClient()
    if ZSCAV and ZSCAV.IsActive then
        return ZSCAV:IsActive()
    end

    local modeName = ZSCAV and ZSCAV.MODE_NAME or "zscav"
    if zb and (zb.CROUND == modeName or zb.CROUND_MAIN == modeName) then
        return true
    end

    if isfunction(CurrentRound) then
        local round = CurrentRound()
        return istable(round) and tostring(round.name or "") == modeName
    end

    return false
end

local function clearRaidInfoDisplay()
    raidInfoMode = nil
    raidInfoVisibleUntil = 0
end

local function showRaidInfoDisplay(mode, duration)
    raidInfoMode = mode
    raidInfoVisibleUntil = CurTime() + math.max(tonumber(duration) or 0, 0)
end

local function getRaidInfoAlpha(now)
    local timeLeft = math.max((raidInfoVisibleUntil or 0) - now, 0)
    if timeLeft <= 0 then return 0 end
    if timeLeft >= RAID_INFO_FADE_DURATION then return 255 end
    return math.floor(255 * (timeLeft / RAID_INFO_FADE_DURATION))
end

local function getJoinHintAlpha(now)
    local timeLeft = math.max((joinHintVisibleUntil or 0) - now, 0)
    if timeLeft <= 0 then return 0 end
    if timeLeft >= RAID_JOIN_HINT_FADE_DURATION then return 255 end
    return math.floor(255 * (timeLeft / RAID_JOIN_HINT_FADE_DURATION))
end

local function isKeyboardCaptured()
    if gui.IsGameUIVisible() then return true end

    local focus = vgui.GetKeyboardFocus()
    return focus ~= nil
end

net.Receive("ZScavRaidIntro", function()
    introEndsAt = CurTime() + introDuration
end)

net.Receive("ZScavRaidExtractList", function()
    local count = net.ReadUInt(6)
    local extracts = {}

    for index = 1, count do
        extracts[index] = {
            label = net.ReadString(),
            duration = net.ReadUInt(8),
        }
    end

    assignedExtracts = extracts
end)

net.Receive("ZScavRaidJoinHint", function()
    joinHintIsSpectator = net.ReadBool()
    joinHintVisibleUntil = CurTime() + RAID_JOIN_HINT_DURATION

    local message = "[ZScav] Type !join in chat to spawn into the safe-zone lobby."
    if joinHintIsSpectator then
        message = "[ZScav] Type !join in chat when you want to leave spectate and enter the safe-zone lobby."
    end

    notification.AddLegacy(message, NOTIFY_HINT, 6)
end)

hook.Add("RoundInfoCalled", "ZScavRaid_ClearIntroOnModeSwap", function(roundName)
    if roundName ~= (ZSCAV and ZSCAV.MODE_NAME or "zscav") then
        introEndsAt = 0
        assignedExtracts = {}
        clearRaidInfoDisplay()
        joinHintVisibleUntil = 0
        joinHintIsSpectator = false
    end
end)

hook.Add("PlayerButtonDown", "ZScavRaid_InfoKey", function(ply, button)
    if ply ~= LocalPlayer() then return end
    if button ~= RAID_INFO_TOGGLE_KEY then return end
    if not isZScavRoundClient() then return end
    if isKeyboardCaptured() then return end
    if not ply:GetNWBool("ZScavRaidActive", false) then return end

    local now = CurTime()
    if (now - (raidInfoLastPressAt or 0)) <= RAID_INFO_DOUBLE_PRESS_WINDOW then
        showRaidInfoDisplay("expanded", RAID_INFO_EXPANDED_DURATION)
    else
        showRaidInfoDisplay("compact", RAID_INFO_COMPACT_DURATION)
    end

    raidInfoLastPressAt = now
end)

hook.Add("HUDPaint", "ZScavRaid_HUD", function()
    if not isZScavRoundClient() then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local sw, sh = ScrW(), ScrH()
    local titleColor = Color(232, 211, 152, 255)
    local bodyColor = Color(228, 228, 228, 255)
    local subColor = Color(168, 176, 186, 255)

    local now = CurTime()
    if introEndsAt > now then
        local fade = math.Clamp((introEndsAt - now) / introDuration, 0, 1)
        draw.SimpleText(
            "ZScav",
            "ZScavRaidIntroTitle",
            sw * 0.5,
            sh * 0.14,
            ColorAlpha(titleColor, 255 * fade),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
        draw.SimpleText(
            "Survive, Loot, Extract.",
            "ZScavRaidIntroSub",
            sw * 0.5,
            sh * 0.20,
            ColorAlpha(bodyColor, 255 * fade),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end

    local joinHintAlpha = getJoinHintAlpha(now)
    if joinHintAlpha > 0 then
        local joinLines = {
            { text = "Type !join in chat to spawn at ZSCAV_SAFESPAWN and wait in the safe zone.", color = bodyColor },
        }

        if joinHintIsSpectator then
            joinLines[#joinLines + 1] = { text = "You can keep spectating for now, then use !join when you want to enter the safe-zone lobby.", color = subColor }
        else
            joinLines[#joinLines + 1] = { text = "This joins the lobby safe zone only; the current live raid stays locked.", color = subColor }
        end

        drawRaidInfoPanel(sw, sh, "JOIN SAFE LOBBY", joinLines, joinHintAlpha, hudScale(38), hudScale(38))
    end

    local raidActive = lp:GetNWBool("ZScavRaidActive", false)
    local lateWindowEnd = GetGlobalFloat("ZScavRaidLateSpawnWindowEnd", 0)
    local lateCountdownEnd = GetGlobalFloat("ZScavRaidLateSpawnCountdownEnd", 0)
    local lateReadyPlayers = GetGlobalInt("ZScavRaidLateSpawnReadyPlayers", 0)
    local lateWindowOpen = lateWindowEnd > now
    local lateCountdownActive = lateCountdownEnd > now

    if raidActive then
        local deadline = lp:GetNWFloat("ZScavRaidDeadline", 0)
        local secondsLeft = math.max(deadline - now, 0)
        local extracting = lp:GetNWBool("ZScavRaidExtracting", false)
        local extractHoldEnd = lp:GetNWFloat("ZScavRaidExtractHoldEnd", 0)
        local extractHoldDuration = math.max(lp:GetNWFloat("ZScavRaidExtractHoldDuration", 0), 0)
        local extractingActive = extracting and extractHoldEnd > now and extractHoldDuration > 0
        local visibleMode = raidInfoMode
        local alpha = getRaidInfoAlpha(now)

        if not extractingActive and alpha <= 0 then
            return
        end

        if extractingActive and visibleMode == nil then
            visibleMode = "compact"
            alpha = 255
        end

        local lineData = {
            { text = "Time left: " .. formatSeconds(secondsLeft), color = bodyColor },
        }

        if visibleMode == "expanded" then
            if #assignedExtracts > 0 then
                lineData[#lineData + 1] = { text = "Available extractions:", color = bodyColor }
                for _, extract in ipairs(assignedExtracts) do
                    lineData[#lineData + 1] = { text = "- " .. tostring(extract.label or "Extract"), color = subColor }
                end
            else
                lineData[#lineData + 1] = { text = "No extracts configured.", color = subColor }
            end
        end

        local panelX, panelY, panelW, panelH = drawRaidInfoPanel(sw, sh, "RAID ACTIVE", lineData, alpha)

        if extractingActive then
            drawExtractionProgress(
                sw,
                sh,
                formatSeconds(extractHoldEnd - now),
                1 - math.Clamp((extractHoldEnd - now) / extractHoldDuration, 0, 1),
                alpha
            )
        end

        return
    end

    clearRaidInfoDisplay()

    if lateWindowOpen or lateCountdownActive then
        local panelX, panelY, panelW, panelH = drawRaidInfoPanel(sw, sh, "LATE DEPLOYMENT", {
            { text = lateCountdownActive and ("Late spawn in: " .. formatSeconds(lateCountdownEnd - now)) or ("Window closes in: " .. formatSeconds(lateWindowEnd - now)), color = bodyColor },
            { text = string.format("Queued players on pads: %d", lateReadyPlayers), color = bodyColor },
            { text = lateWindowOpen and "Stand on a raid pad to join the next late deployment." or "Late deployment queue is locked to current pad occupants.", color = subColor },
        })

        if lateCountdownActive then
            drawRaidCountdownBar(
                panelX,
                panelY,
                panelW,
                panelH,
                math.max(lateCountdownEnd - now, 0) / 30,
                Color(245, 188, 72, 255)
            )
        end
        return
    end

    local padsArmedAt = GetGlobalFloat("ZScavRaidPadsArmedAt", 0)
    local countdownEnd = GetGlobalFloat("ZScavRaidPadCountdownEnd", 0)
    local readyPlayers = GetGlobalInt("ZScavRaidPadReadyPlayers", 0)
    local minPlayers = GetGlobalInt("ZScavRaidPadMinPlayers", 6)
    local padsActive = GetGlobalBool("ZScavRaidPadsActive", false)
    local battlefieldPlayers = GetGlobalInt("ZScavRaidBattlefieldPlayers", 0)

    if battlefieldPlayers > 0 then
        drawRaidInfoPanel(sw, sh, "SAFE LOBBY", {
            { text = "Raid in progress. Pads are locked.", color = bodyColor },
            { text = string.format("Players still on battlefield: %d", battlefieldPlayers), color = subColor },
        })
        return
    end

    if padsArmedAt > now then
        drawRaidInfoPanel(sw, sh, "SAFE LOBBY", {
            { text = "Pads arm in: " .. formatSeconds(padsArmedAt - now), color = bodyColor },
            { text = "Use the time to manage bodycam consent and mailbox.", color = subColor },
        })
        return
    end

    if countdownEnd > now then
        drawRaidInfoPanel(sw, sh, "SAFE LOBBY", {
            { text = "Raid launch in: " .. formatSeconds(countdownEnd - now), color = bodyColor },
            { text = string.format("Ready players on pads: %d/%d", readyPlayers, minPlayers), color = subColor },
        })
        return
    end

    if padsActive then
        drawRaidInfoPanel(sw, sh, "SAFE LOBBY", {
            { text = "Stand on a raid pad to queue.", color = bodyColor },
            { text = string.format("Need %d players total. Current ready: %d", minPlayers, readyPlayers), color = subColor },
        })
        return
    end

    drawRaidInfoPanel(sw, sh, "SAFE LOBBY", {
        { text = "Waiting for raid pads.", color = bodyColor },
    })
end)