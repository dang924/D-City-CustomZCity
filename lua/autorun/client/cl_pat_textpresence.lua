PATTextPresence = PATTextPresence or {}
PATTextPresence.Active = PATTextPresence.Active or {}
PATTextPresence.SuppressTypingUntil = PATTextPresence.SuppressTypingUntil or {}

local fallbackSpeechColor = Color(245, 245, 245, 255)
local outlineColor = Color(255, 255, 255, 235)
local typingColor = Color(255, 220, 160, 255)
local dotPulseBase = 145
local pixelvis = util.GetPixelVisibleHandle()
local lineHeightCache = {}

surface.CreateFont("PAT_TextPresence_Main", {
    font = "Bahnschrift",
    size = 28,
    weight = 800,
    antialias = true,
    extended = true
})

surface.CreateFont("PAT_TextPresence_Whisper", {
    font = "Bahnschrift",
    size = 22,
    weight = 650,
    italic = true,
    antialias = true,
    extended = true
})

surface.CreateFont("PAT_TextPresence_Typing", {
    font = "Bahnschrift",
    size = 24,
    weight = 900,
    antialias = true,
    extended = true
})

surface.CreateFont("PAT_TextPresence_Main_Mid", {
    font = "Bahnschrift",
    size = 24,
    weight = 800,
    antialias = true,
    extended = true
})

surface.CreateFont("PAT_TextPresence_Main_Far", {
    font = "Bahnschrift",
    size = 20,
    weight = 800,
    antialias = true,
    extended = true
})

surface.CreateFont("PAT_TextPresence_Whisper_Mid", {
    font = "Bahnschrift",
    size = 19,
    weight = 650,
    italic = true,
    antialias = true,
    extended = true
})

surface.CreateFont("PAT_TextPresence_Whisper_Far", {
    font = "Bahnschrift",
    size = 16,
    weight = 650,
    italic = true,
    antialias = true,
    extended = true
})

surface.CreateFont("PAT_TextPresence_Typing_Mid", {
    font = "Bahnschrift",
    size = 20,
    weight = 900,
    antialias = true,
    extended = true
})

surface.CreateFont("PAT_TextPresence_Typing_Far", {
    font = "Bahnschrift",
    size = 17,
    weight = 900,
    antialias = true,
    extended = true
})

local function utf8SubSafe(text, limit)
    limit = math.max(limit or 0, 0)
    if utf8.len(text) == nil then return string.sub(text, 1, limit) end
    return utf8.sub(text, 1, limit)
end

local function clearSpeakerState(ply)
    PATTextPresence.Active[ply] = nil
    PATTextPresence.SuppressTypingUntil[ply] = nil
end

local function isDeadState(ply)
    if not IsValid(ply) then return true end
    if ply:Alive() == false then return true end
    if ply.Health and ply:Health() <= 0 then return true end

    local ragDeath = ply:GetNWEntity("RagdollDeath")
    if IsValid(ragDeath) then
        return true
    end

    return false
end

local function isUnconsciousState(ply)
    if not IsValid(ply) or not ply.GetNWBool then return false end

    if ply:GetNWBool("Unconscious", false) then return true end
    if ply:GetNWBool("unconscious", false) then return true end
    if ply:GetNWBool("KnockedOut", false) then return true end
    if ply:GetNWBool("knockedout", false) then return true end
    if ply:GetNWBool("Otrub", false) then return true end
    if ply:GetNWBool("otrub", false) then return true end
    if ply:GetNWBool("IsUnconscious", false) then return true end
    if ply:GetNWBool("is_unconscious", false) then return true end

    return false
end

local function shouldSuppressPresence(ply)
    return isDeadState(ply) or isUnconsciousState(ply)
end

-- Keep the original anchor behavior exactly.
local function getSpeakEnt(ply)
    if not IsValid(ply) then return nil end
    if IsValid(ply.FakeRagdoll) then return ply.FakeRagdoll end
    local ragDeath = ply:GetNWEntity("RagdollDeath")
    if IsValid(ragDeath) then return ragDeath end
    return ply
end

-- Keep the original head position logic exactly.
local function getHeadPos(ent)
    if not IsValid(ent) then return nil end

    local bone = ent:LookupBone("ValveBiped.Bip01_Head1")
    if bone then
        local matrix = ent:GetBoneMatrix(bone)
        if matrix then
            return matrix:GetTranslation() + Vector(0, 0, 9)
        end
    end

    return ent:WorldSpaceCenter() + Vector(0, 0, 38)
end

-- Keep the original visibility logic exactly.
local function canSeeSpeaker(ply, targetPos)
    local localPly = LocalPlayer()
    if not IsValid(localPly) then return false end
    if not targetPos then return false end

    local listenerEnt = getSpeakEnt(localPly)
    local viewEnt = GetViewEntity()
    local listenerPos = EyePos()

    local speakerEnt = getSpeakEnt(ply)
    local filter = {localPly, listenerEnt, ply, speakerEnt}
    if IsValid(viewEnt) then
        filter[#filter + 1] = viewEnt
    end
    local samples = {
        targetPos,
        targetPos - Vector(0, 0, 8),
        targetPos - Vector(0, 0, 16)
    }

    for _, sample in ipairs(samples) do
        local px = util.PixelVisible(sample, 3, pixelvis)
        if px and px > 0 then
            local tr = util.TraceLine({
                start = listenerPos,
                endpos = sample,
                mask = MASK_SHOT,
                filter = filter
            })

            if not tr.Hit then
                return true
            end
        end
    end

    return false
end

local function getSpeechColor(ply, alpha)
    if not IsValid(ply) or not ply.GetPlayerColor then
        return Color(fallbackSpeechColor.r, fallbackSpeechColor.g, fallbackSpeechColor.b, alpha)
    end

    local vec = ply:GetPlayerColor()
    local color = vec and vec.ToColor and vec:ToColor() or fallbackSpeechColor
    return Color(color.r, color.g, color.b, alpha)
end

local function getDistanceData(distance, isWhisper)
    local scale = isWhisper and PATTextPresence.WhisperDistanceScale:GetFloat() or 1
    local maxDist = PATTextPresence.MaxDistance:GetFloat() * scale
    local fadeDist = math.min(PATTextPresence.FadeDistance:GetFloat() * scale, maxDist)
    return fadeDist, maxDist
end

local function distanceAlpha(distance, isWhisper)
    local fadeDist, maxDist = getDistanceData(distance, isWhisper)

    if distance >= maxDist then return 0 end
    if distance <= fadeDist then return 255 end

    return math.Clamp(255 * (1 - (distance - fadeDist) / math.max(maxDist - fadeDist, 1)), 0, 255)
end

local function getDistanceFraction(distance, isWhisper)
    local fadeDist, maxDist = getDistanceData(distance, isWhisper)
    local startDist = fadeDist * 0.35

    if distance <= startDist then return 0 end
    if distance >= maxDist then return 1 end

    return math.Clamp((distance - startDist) / math.max(maxDist - startDist, 1), 0, 1)
end

local function getSpeechFontForDistance(distance, isWhisper)
    local frac = getDistanceFraction(distance, isWhisper)

    if isWhisper then
        if frac >= 0.72 then return "PAT_TextPresence_Whisper_Far" end
        if frac >= 0.36 then return "PAT_TextPresence_Whisper_Mid" end
        return "PAT_TextPresence_Whisper"
    end

    if frac >= 0.72 then return "PAT_TextPresence_Main_Far" end
    if frac >= 0.36 then return "PAT_TextPresence_Main_Mid" end
    return "PAT_TextPresence_Main"
end

local function getTypingFontForDistance(distance, isWhisper)
    local frac = getDistanceFraction(distance, isWhisper)

    if frac >= 0.72 then return "PAT_TextPresence_Typing_Far" end
    if frac >= 0.36 then return "PAT_TextPresence_Typing_Mid" end
    return "PAT_TextPresence_Typing"
end

local function wrapText(text, font, maxWidth)
    surface.SetFont(font)

    local words = string.Explode(" ", text, false)
    local lines = {}
    local current = ""

    if #words == 0 then
        return {text}
    end

    for _, word in ipairs(words) do
        local candidate = current == "" and word or (current .. " " .. word)
        local width = surface.GetTextSize(candidate)

        if width <= maxWidth or current == "" then
            current = candidate
        else
            lines[#lines + 1] = current
            current = word
        end
    end

    if current ~= "" then
        lines[#lines + 1] = current
    end

    if #lines == 0 then
        lines[1] = text
    end

    return lines
end

local function getLineHeight(font)
    local cached = lineHeightCache[font]
    if cached then return cached end

    surface.SetFont(font)
    local _, h = surface.GetTextSize("Ag")
    lineHeightCache[font] = h
    return h
end

local function shiftCurrentToPrevious(slot, now)
    if not slot.current or not slot.current.text or slot.current.text == "" then return end

    slot.previous = {
        text = slot.current.text,
        whisper = slot.current.whisper,
        expiresAt = now + PATTextPresence.PreviousLifeTime:GetFloat()
    }
end

local function addSpeech(ply, text, isWhisper)
    if not IsValid(ply) or not isstring(text) or text == "" then return end
    if shouldSuppressPresence(ply) then
        clearSpeakerState(ply)
        return
    end

    local now = CurTime()
    local charCount = math.max(utf8.len(text) or #text, 1)
    local revealDuration = math.Clamp(charCount / PATTextPresence.RevealSpeed:GetFloat(), 0.22, 3.8)
    local slot = PATTextPresence.Active[ply] or {}

    shiftCurrentToPrevious(slot, now)

    slot.current = {
        text = text,
        whisper = isWhisper,
        startedAt = now,
        revealAt = now + revealDuration,
        expiresAt = now + revealDuration + PATTextPresence.LifeTime:GetFloat(),
        chars = charCount
    }

    PATTextPresence.Active[ply] = slot
    PATTextPresence.SuppressTypingUntil[ply] = now + 0.35
end

-- Keep the original permissive capture path that worked.
hook.Add("OnPlayerChat", "PAT_TextPresence_Capture", function(ply, text, bTeam, bDead, bWhisper)
    if not IsValid(ply) or bTeam then return end
    addSpeech(ply, text, bWhisper)
end)

local function getRevealText(state, now)
    if now >= state.revealAt then
        return state.text, true
    end

    local frac = math.TimeFraction(state.startedAt, state.revealAt, now)
    local shown = math.max(math.floor(state.chars * frac), 1)
    return utf8SubSafe(state.text, shown), false
end

local function getCurrentLineFade(lineAge, totalLines, fadeProgress)
    if lineAge <= 0 then return 1 end

    local vanishAt = math.Clamp(1 - (lineAge / totalLines), 0.15, 0.9)
    local softness = 0.16
    return math.Clamp((vanishAt - fadeProgress) / softness, 0, 1)
end

local function getTextHash(text)
    local hash = 0
    local sampleLen = math.min(#text, 32)

    for i = 1, sampleLen do
        hash = (hash + (string.byte(text, i) or 0) * i) % 997
    end

    return hash
end

local function getObfuscationStrength(distance, isWhisper)
    local fadeDist, maxDist = getDistanceData(distance, isWhisper)
    local startDist = fadeDist * 0.72

    if distance <= startDist then return 0 end
    if distance >= maxDist then return 1 end

    return math.Clamp((distance - startDist) / math.max(maxDist - startDist, 1), 0, 1)
end

local function obfuscateTextAtDistance(text, distance, isWhisper)
    local strength = getObfuscationStrength(distance, isWhisper)
    if strength <= 0 then return text end

    local len = utf8.len(text)
    if not len or len <= 0 then return text end

    local threshold = math.floor(strength * 100)
    local textHash = getTextHash(text)
    local out = {}

    for i = 1, len do
        local ch = utf8.sub(text, i, i)

        if ch == " " or ch == "\t" then
            out[#out + 1] = ch
        else
            local hash = ((i * 17) + textHash) % 100
            if hash < threshold then
                out[#out + 1] = "•"
            else
                out[#out + 1] = ch
            end
        end
    end

    return table.concat(out)
end

local function drawSpeechStack(ply, screenPos, text, alpha, isWhisper, yOffset, historyScale, fadeProgress, progressiveFade, viewDistance)
    local font = getSpeechFontForDistance(viewDistance or 0, isWhisper)
    local maxWidth = PATTextPresence.WrapWidth:GetFloat() * (isWhisper and 0.85 or 1)
    local lines = wrapText(text, font, maxWidth)
    local lineHeight = getLineHeight(font)
    local gap = 2
    local totalHeight = #lines * lineHeight + (#lines - 1) * gap
    local currentY = screenPos.y + yOffset

    for index = #lines, 1, -1 do
        local lineAge = (#lines - index)
        local lineFade = progressiveFade and getCurrentLineFade(lineAge, #lines, fadeProgress or 0) or 1
        local lineScale = lineAge == 0 and 1 or math.max(0.16, 0.58 - lineAge * 0.18)
        local finalAlpha = math.floor(alpha * historyScale * lineScale * lineFade)

        if finalAlpha > 0 then
            local fillAlpha = math.Clamp(math.floor(finalAlpha * 1.55), 0, 255)
            local outlineAlpha = math.Clamp(math.floor(finalAlpha * 0.14), 0, 255)
            local color = getSpeechColor(ply, math.floor(fillAlpha * (isWhisper and 0.9 or 1)))
            local outline = Color(outlineColor.r, outlineColor.g, outlineColor.b, outlineAlpha)
            draw.SimpleTextOutlined(lines[index], font, screenPos.x, currentY, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, outline)
        end

        currentY = currentY - lineHeight - gap
    end

    return totalHeight
end

local function drawTyping(screenPos, alpha, viewDistance, isWhisper)
    local phase = CurTime() * 5
    local dots = "."
    if phase % 3 > 1 then dots = ".." end
    if phase % 3 > 2 then dots = "..." end

    local font = getTypingFontForDistance(viewDistance or 0, isWhisper)

    draw.SimpleTextOutlined(
        dots,
        font,
        screenPos.x,
        screenPos.y - PATTextPresence.TypingOffset:GetFloat(),
        Color(typingColor.r, typingColor.g, typingColor.b, math.floor(alpha * (dotPulseBase + math.abs(math.sin(phase)) * 110) / 255)),
        TEXT_ALIGN_CENTER,
        TEXT_ALIGN_CENTER,
        1,
        Color(255, 255, 255, math.floor(alpha * 0.8))
    )
end

hook.Add("HUDPaint", "PAT_TextPresence_Draw", function()
    local localPly = LocalPlayer()
    if not IsValid(localPly) then return end

    local now = CurTime()

    for ply, slot in pairs(PATTextPresence.Active) do
        if not IsValid(ply) or shouldSuppressPresence(ply) then
            clearSpeakerState(ply)
            continue
        end

        local current = slot.current
        local previous = slot.previous

        if current and now >= current.expiresAt then
            slot.current = nil
            current = nil
        end

        if previous and now >= previous.expiresAt then
            slot.previous = nil
            previous = nil
        end

        if not current and not previous then
            clearSpeakerState(ply)
            continue
        end

        local ent = getSpeakEnt(ply)
        local pos = getHeadPos(ent)
        if not pos then continue end
        if not canSeeSpeaker(ply, pos) then continue end

        local screenPos = pos:ToScreen()
        if not screenPos.visible then continue end

        local stackedHeight = 0
        local viewDistance = EyePos():Distance(pos)

        if current then
            local currentText = getRevealText(current, now)
            currentText = obfuscateTextAtDistance(currentText, viewDistance, current.whisper)

            local alpha = distanceAlpha(viewDistance, current.whisper)
            local fade = math.Clamp((current.expiresAt - now) / 0.45, 0, 1)
            alpha = math.floor(alpha * math.min(fade, 1))

            if alpha > 0 then
                local lineFadeProgress = math.TimeFraction(current.revealAt, current.expiresAt, now)
                stackedHeight = drawSpeechStack(ply, screenPos, currentText, alpha, current.whisper, current.whisper and 6 or 0, 1, lineFadeProgress, true, viewDistance)
            end
        end

        if previous then
            local previousText = obfuscateTextAtDistance(previous.text, viewDistance, previous.whisper)

            local alpha = distanceAlpha(viewDistance, previous.whisper)
            local fade = math.Clamp((previous.expiresAt - now) / 0.5, 0, 1)
            alpha = math.floor(alpha * 0.55 * fade)

            if alpha > 0 then
                drawSpeechStack(ply, screenPos, previousText, alpha, previous.whisper, -(stackedHeight + 8), 0.65, 0, false, viewDistance)
            end
        end
    end

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or shouldSuppressPresence(ply) then
            clearSpeakerState(ply)
            continue
        end
        if (PATTextPresence.SuppressTypingUntil[ply] or 0) > now then continue end
        if PATTextPresence.Active[ply] and PATTextPresence.Active[ply].current then continue end
        if not ply:IsTyping() then continue end

        local ent = getSpeakEnt(ply)
        local pos = getHeadPos(ent)
        if not pos then continue end
        if not canSeeSpeaker(ply, pos) then continue end

        local viewDistance = EyePos():Distance(pos)
        local alpha = distanceAlpha(viewDistance, ply.ChatWhisper)
        if alpha <= 0 then continue end

        local screenPos = pos:ToScreen()
        if not screenPos.visible then continue end

        drawTyping(Vector(screenPos.x, screenPos.y - 18, 0), math.floor(alpha * 0.9), viewDistance, ply.ChatWhisper)
    end
end)
