MODE.name = "hidden"

local MODE = MODE
local HIDDEN_ROUND_THEME = "hidden/round_theme.mp3"
local HIDDEN_ROUND_THEME_VOLUME = 0.55
local hiddenRoundTheme = nil
local CreateEndMenu

local colGray = Color(85, 85, 85, 255)
local colRed = Color(130, 10, 10)
local colRedUp = Color(160, 30, 30)
local colBlue = Color(10, 10, 160)
local colBlueUp = Color(40, 40, 160)
local colWhite = Color(255, 255, 255, 255)
local colSpect1 = Color(75, 75, 75, 255)
local colSpect2 = Color(255, 255, 255, 255)

local hiddenReadyCount = 0
local hiddenReadyTotal = 0
local hiddenPrepState = false
local hiddenPrepFallbackEndsAt = 0
local hiddenExtractActive = false
local hiddenExtractEligible = true
local hiddenExtractPos = vector_origin
local hiddenExtractRequired = 0
local hiddenExtractCurrent = 0
local hiddenExtractVipMode = false
local hiddenExtractIntelRequired = false
local hiddenExtractVipAtZone = false
local hiddenExtractVipHasIntel = false
local hiddenExtractPingPos = vector_origin
local hiddenExtractPingUntil = 0

local function getHiddenPrepDuration()
    return math.max(tonumber(MODE and MODE.HiddenConfig and MODE.HiddenConfig.PrepDuration) or 60, 1)
end

local function getHiddenPrepRemaining()
    if not hiddenPrepState then
        return 0
    end

    local roundStart = zb.ROUND_START or CurTime()
    local roundBegin = tonumber(zb.ROUND_BEGIN) or 0
    if roundBegin > 0 and roundBegin <= CurTime() then
        return 0
    end

    local fallbackFromRoundStart = roundStart + getHiddenPrepDuration()
    local prepEndAt = roundBegin > CurTime() and roundBegin or math.max(hiddenPrepFallbackEndsAt, fallbackFromRoundStart)

    return math.max(prepEndAt - CurTime(), 0)
end

local function drawHiddenStatusBar(x, y, w, h, fraction, fillColor, label)
    local clamped = math.Clamp(tonumber(fraction) or 0, 0, 1)

    surface.SetDrawColor(10, 10, 10, 180)
    surface.DrawRect(x, y, w, h)

    local innerW = math.max(w - 2, 0)
    local innerH = math.max(h - 2, 0)
    local fillW = math.floor(innerW * clamped)

    if fillW > 0 then
        surface.SetDrawColor(fillColor.r, fillColor.g, fillColor.b, 220)
        surface.DrawRect(x + 1, y + 1, fillW, innerH)
    end

    surface.SetDrawColor(255, 255, 255, 35)
    surface.DrawOutlinedRect(x, y, w, h, 1)
end

local function isHiddenIrisPrepSpectator()
    return IsValid(lply)
        and lply:Team() == 1
        and not lply:Alive()
    and getHiddenPrepRemaining() > 0
end

BlurBackground = BlurBackground or hg.DrawBlur

local function stopHiddenRoundTheme()
    if IsValid(hiddenRoundTheme) then
        hiddenRoundTheme:Stop()
        hiddenRoundTheme = nil
    end
end

local function startHiddenRoundTheme()
    stopHiddenRoundTheme()

    sound.PlayFile("sound/" .. HIDDEN_ROUND_THEME, "noplay noblock", function(channel)
        if not IsValid(channel) then return end

        hiddenRoundTheme = channel
        hiddenRoundTheme:EnableLooping(true)
        hiddenRoundTheme:SetVolume(HIDDEN_ROUND_THEME_VOLUME * (GetConVar("snd_musicvolume"):GetFloat() or 1))
        hiddenRoundTheme:Play()
    end)
end

net.Receive("hidden_start", function()
    surface.PlaySound("ambient/levels/citadel/weapon_disintegrate2.wav")
    startHiddenRoundTheme()
    hiddenPrepState = true
    hiddenPrepFallbackEndsAt = CurTime() + getHiddenPrepDuration()
    zb.RemoveFade()
end)

net.Receive("hidden_roundend", function()
    local winner = net.ReadInt(4)
    surface.PlaySound("ambient/alarms/warningbell1.wav")
    stopHiddenRoundTheme()

    CreateEndMenu(winner)
end)

net.Receive("hidden_ready_sync", function()
    hiddenReadyCount = net.ReadUInt(8)
    hiddenReadyTotal = net.ReadUInt(8)
end)

net.Receive("hidden_prep_state", function()
    local isPreparation = net.ReadBool()
    local combatStart = net.ReadFloat()
    local combatDuration = net.ReadFloat()
    hiddenPrepState = isPreparation and true or false

    if hiddenPrepState then
        hiddenPrepFallbackEndsAt = math.max(CurTime() + getHiddenPrepDuration(), tonumber(zb.ROUND_BEGIN) or 0)
    else
        hiddenPrepFallbackEndsAt = 0
        -- Server has reset the round clock for the combat phase. Mirror those values
        -- locally so the HUD timer drops to the configured combat duration (e.g. 4:00)
        -- whether prep ended via the ready system or the timer expiring.
        if combatStart and combatStart > 0 then
            zb.ROUND_START = combatStart
            zb.ROUND_BEGIN = combatStart
        end
        if combatDuration and combatDuration > 0 then
            zb.ROUND_TIME = combatDuration
        end
    end

    hook.Run("HG_HiddenPrepStateChanged", hiddenPrepState, combatStart, combatDuration)
end)

net.Receive("hidden_extract_sync", function()
    hiddenExtractActive = net.ReadBool()
    hiddenExtractEligible = net.ReadBool()
    hiddenExtractPos = net.ReadVector()
    hiddenExtractRequired = net.ReadUInt(8)
    hiddenExtractCurrent = net.ReadUInt(8)
    hiddenExtractVipMode = net.ReadBool()
    hiddenExtractIntelRequired = net.ReadBool()
    hiddenExtractVipAtZone = net.ReadBool()
    hiddenExtractVipHasIntel = net.ReadBool()
end)

net.Receive("hidden_extract_ping", function()
    hiddenExtractPingPos = net.ReadVector()
    hiddenExtractPingUntil = CurTime() + 10
    surface.PlaySound("buttons/blip1.wav")
end)

local teams = {
    [0] = {
        objective = "Stalk and eliminate every IRIS operative.",
        name = "Subject 617",
        color1 = Color(170, 30, 30),
        color2 = Color(170, 30, 30),
    },
    [1] = {
        objective = "Track and kill Subject 617 or survive until extraction.",
        name = "an IRIS Operative",
        color1 = Color(25, 110, 210),
        color2 = Color(25, 110, 210),
    },
}

if IsValid(hmcdEndMenu) then
    hmcdEndMenu:Remove()
    hmcdEndMenu = nil
end

CreateEndMenu = function(winner)
    if IsValid(scoreBoardMenu) then
        scoreBoardMenu:Remove()
        scoreBoardMenu = nil
    end

    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end

    hmcdEndMenu = vgui.Create("ZFrame")
    if not IsValid(hmcdEndMenu) then return end

    local sizeX, sizeY = ScrW() / 2.5, ScrH() / 1.2
    local posX, posY = ScrW() / 1.3 - sizeX / 2, ScrH() / 2 - sizeY / 2
    local winnerInfo = teams[winner] or teams[1]
    local winnerName = winnerInfo.name
    local winnerColor = winnerInfo.color1

    hmcdEndMenu:SetPos(posX, posY)
    hmcdEndMenu:SetSize(sizeX, sizeY)
    hmcdEndMenu:MakePopup()
    hmcdEndMenu:SetKeyboardInputEnabled(false)
    hmcdEndMenu:ShowCloseButton(false)

    local closeButton = vgui.Create("DButton", hmcdEndMenu)
    closeButton:SetPos(5, 5)
    closeButton:SetSize(ScrW() / 20, ScrH() / 30)
    closeButton:SetText("")
    closeButton.DoClick = function()
        if IsValid(hmcdEndMenu) then
            hmcdEndMenu:Close()
            hmcdEndMenu = nil
        end
    end

    closeButton.Paint = function(self, w, h)
        surface.SetDrawColor(122, 122, 122, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
        surface.SetFont("ZB_InterfaceMedium")
        surface.SetTextColor(colWhite.r, colWhite.g, colWhite.b, colWhite.a)
        local lengthX = surface.GetTextSize("Close")
        surface.SetTextPos(lengthX - lengthX / 1.1, 4)
        surface.DrawText("Close")
    end

    hmcdEndMenu.Paint = function(self, w, h)
        BlurBackground(self)

        surface.SetFont("ZB_InterfaceMediumLarge")
        surface.SetTextColor(winnerColor.r, winnerColor.g, winnerColor.b, 255)
        local winnerText = winnerName .. " win"
        local titleX, titleY = surface.GetTextSize(winnerText)
        surface.SetTextPos(w / 2 - titleX / 2, 20)
        surface.DrawText(winnerText)

        surface.SetTextColor(colWhite.r, colWhite.g, colWhite.b, colWhite.a)
        local playersText = "Players:"
        local playersX = surface.GetTextSize(playersText)
        surface.SetTextPos(w / 2 - playersX / 2, 50)
        surface.DrawText(playersText)

        surface.SetDrawColor(255, 0, 0, 128)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
    end

    local scrollPanel = vgui.Create("DScrollPanel", hmcdEndMenu)
    scrollPanel:SetPos(10, 80)
    scrollPanel:SetSize(sizeX - 20, sizeY - 90)
    function scrollPanel:Paint(w, h)
        BlurBackground(self)
        surface.SetDrawColor(255, 0, 0, 128)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
    end

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end

        local button = vgui.Create("DButton", scrollPanel)
        button:SetSize(100, 50)
        button:Dock(TOP)
        button:DockMargin(8, 6, 8, -1)
        button:SetText("")

        button.Paint = function(self, w, h)
            if not IsValid(ply) then
                surface.SetDrawColor(colGray.r, colGray.g, colGray.b, colGray.a)
                surface.DrawRect(0, 0, w, h)
                surface.SetFont("ZB_InterfaceMediumLarge")
                surface.SetTextColor(colSpect2.r, colSpect2.g, colSpect2.b, colSpect2.a)
                surface.SetTextPos(15, h / 2 - 8)
                surface.DrawText("Disconnected")
                return
            end

            local isWinner = winner ~= nil and ply:Team() == winner
            local alive = ply:Alive()
            local topColor = colGray
            local bottomColor = colSpect1

            if isWinner then
                topColor = alive and Color(winnerColor.r, winnerColor.g, winnerColor.b, 255) or colGray
                bottomColor = alive and Color(math.min(winnerColor.r + 30, 255), math.min(winnerColor.g + 30, 255), math.min(winnerColor.b + 30, 255), 255) or colSpect1
            elseif alive then
                topColor = ply:Team() == 0 and colRed or colBlue
                bottomColor = ply:Team() == 0 and colRedUp or colBlueUp
            end

            surface.SetDrawColor(topColor.r, topColor.g, topColor.b, topColor.a)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(bottomColor.r, bottomColor.g, bottomColor.b, bottomColor.a)
            surface.DrawRect(0, h / 2, w, h / 2)

            local playerColor = ply:GetPlayerColor():ToColor()
            local playerName = ply:GetPlayerName() or "Disconnected"
            local statusText = ply:Name() .. (alive and "" or " - died")

            surface.SetFont("ZB_InterfaceMediumLarge")

            local centerX, centerY = surface.GetTextSize(playerName)
            surface.SetTextColor(0, 0, 0, 255)
            surface.SetTextPos(w / 2 + 1, h / 2 - centerY / 2 + 1)
            surface.DrawText(playerName)

            surface.SetTextColor(playerColor.r, playerColor.g, playerColor.b, playerColor.a)
            surface.SetTextPos(w / 2, h / 2 - centerY / 2)
            surface.DrawText(playerName)

            local statusX, statusY = surface.GetTextSize(statusText)
            surface.SetTextColor(colSpect2.r, colSpect2.g, colSpect2.b, colSpect2.a)
            surface.SetTextPos(15, h / 2 - statusY / 2)
            surface.DrawText(statusText)

            local fragText = tostring(ply:Frags() or 0)
            local fragX, fragY = surface.GetTextSize(fragText)
            surface.SetTextPos(w - fragX - 15, h / 2 - fragY / 2)
            surface.DrawText(fragText)
        end

        button.DoClick = function()
            if not IsValid(ply) then return end

            if ply:IsBot() then
                chat.AddText(Color(255, 0, 0), "no, you can't")
                return
            end

            gui.OpenURL("https://steamcommunity.com/profiles/" .. ply:SteamID64())
        end

        scrollPanel:AddItem(button)
    end
end

function MODE:RenderScreenspaceEffects()
    if isHiddenIrisPrepSpectator() then
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
        return
    end

    if zb.ROUND_START + 7.5 < CurTime() then return end

    local fade = math.Clamp(zb.ROUND_START + 7.5 - CurTime(), 0, 1)
    surface.SetDrawColor(0, 0, 0, 255 * fade)
    surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
end

function MODE:HUDPaint()
    local roundStart = zb.ROUND_START or CurTime()
    local roundTime = math.max(roundStart + (zb.ROUND_TIME or self.ROUND_TIME or 240) - CurTime(), 0)
    local prepTime = getHiddenPrepRemaining()
    local teamInfo = teams[lply:Team()] or teams[1]
    local timerText
    local timerColor

    timerText = "TIME " .. string.FormattedTime(roundTime, "%02i:%02i:%02i")
    timerColor = Color(255, 255, 255)

    draw.SimpleText(timerText, "ZB_HomicideMedium", sw * 0.5, sh * 0.15, timerColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Dedicated PREP timer rendered directly under the TIME line so every player
    -- (Subject 617 included) can see exactly when the prep phase will end.
    if prepTime > 0 then
        local prepText = "PREP " .. string.FormattedTime(prepTime, "%02i:%02i:%02i")
        draw.SimpleText(prepText, "ZB_HomicideMedium", sw * 0.5, sh * 0.19, Color(255, 220, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if prepTime > 0 then
        local prepDuration = getHiddenPrepDuration()
        local prepFraction = math.Clamp(prepTime / prepDuration, 0, 1)
        local prepLabel = "Prep " .. string.FormattedTime(prepTime, "%02i:%02i")
        drawHiddenStatusBar(sw * 0.35, sh * 0.175, sw * 0.30, 18, prepFraction, Color(245, 188, 72), prepLabel)
    end

    if prepTime <= 0 and lply:Team() == 1 then
        if hiddenExtractActive then
            local distText = ""
            if isvector(hiddenExtractPos) and hiddenExtractPos ~= vector_origin and IsValid(lply) and lply:Alive() then
                local distMeters = math.floor((lply:GetPos():Distance(hiddenExtractPos)) / 52.4934)
                distText = " | " .. distMeters .. "m"
            end

            if hiddenExtractVipMode then
                local vipStatus = hiddenExtractVipAtZone and "VIP IN EXTRACTION" or "VIP NOT IN EXTRACTION"
                draw.SimpleText(vipStatus .. distText, "ZB_HomicideMedium", sw * 0.5, sh * 0.23, Color(245, 188, 72), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                if hiddenExtractIntelRequired then
                    local intelStatus = hiddenExtractVipHasIntel and "Intel secured" or "VIP must carry intel briefcase"
                    draw.SimpleText(intelStatus, "ZB_HomicideMedium", sw * 0.5, sh * 0.26, Color(235, 235, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                else
                    draw.SimpleText("IRIS VIP must reach extraction zone.", "ZB_HomicideMedium", sw * 0.5, sh * 0.26, Color(235, 235, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            else
                local extractText = string.format("EXTRACT %d / %d%s", hiddenExtractCurrent, hiddenExtractRequired, distText)
                draw.SimpleText(extractText, "ZB_HomicideMedium", sw * 0.5, sh * 0.23, Color(245, 188, 72), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("Majority of living IRIS must be inside extraction zone.", "ZB_HomicideMedium", sw * 0.5, sh * 0.26, Color(235, 235, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        elseif not hiddenExtractEligible then
            draw.SimpleText("EXTRACTION UNAVAILABLE", "ZB_HomicideMedium", sw * 0.5, sh * 0.23, Color(220, 90, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Kill Subject 617 before timer runs out or IRIS loses.", "ZB_HomicideMedium", sw * 0.5, sh * 0.26, Color(220, 90, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    if hiddenExtractPingUntil > CurTime() and isvector(hiddenExtractPingPos) and hiddenExtractPingPos ~= vector_origin then
        draw.SimpleText("EXTRACTION ZONE PINGED", "ZB_HomicideMedium", sw * 0.5, sh * 0.30, Color(245, 188, 72), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local screenPos = hiddenExtractPingPos:ToScreen()
        if screenPos.visible then
            draw.SimpleText("EXTRACT", "ZB_HomicideMedium", screenPos.x, screenPos.y - 18, Color(245, 188, 72), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    if isHiddenIrisPrepSpectator() then
        draw.SimpleText("IRIS prep phase", "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.46, Color(235, 235, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("You are locked out until prep ends.", "ZB_HomicideMedium", sw * 0.5, sh * 0.52, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        local readyText = "Players ready: " .. hiddenReadyCount .. " / " .. hiddenReadyTotal
        local readyColor = hiddenReadyCount >= hiddenReadyTotal and hiddenReadyTotal > 0 and Color(120, 255, 120) or Color(75, 155, 235)
        draw.SimpleText(readyText, "ZB_HomicideMedium", sw * 0.5, sh * 0.58, readyColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        draw.SimpleText("If the loadout editor closes, open console and run: zb_hidden_loadout", "ZB_HomicideMedium", sw * 0.5, sh * 0.64, Color(255, 220, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return
    end

    if prepTime <= 0 and lply:Team() == 0 and lply:Alive() then
        local leapReadyAt = lply:GetNWFloat("HiddenNextLeap", 0)
        local cooldown = math.max(leapReadyAt - CurTime(), 0)
        local leapCooldownText = (cooldown <= 0 and "Leap cooldown: ready" or ("Leap cooldown: " .. string.format("%.1f", cooldown) .. "s"))
        local leapCooldown = math.max(tonumber(self.HiddenConfig and self.HiddenConfig.LeapCooldown) or 6, 0.1)
        local leapCooldownFraction = math.Clamp(1 - (cooldown / leapCooldown), 0, 1)

        drawHiddenStatusBar(sw * 0.35, sh * 0.915, sw * 0.30, 18, leapCooldownFraction, Color(120, 255, 120), leapCooldownText)
    end

    if zb.ROUND_START + 8.5 < CurTime() then return end
    if not lply:Alive() then return end

    zb.RemoveFade()

    local fade = math.Clamp(zb.ROUND_START + 8 - CurTime(), 0, 1)
    local colorRole = Color(teamInfo.color1.r, teamInfo.color1.g, teamInfo.color1.b, 255 * fade)
    local colorObj = Color(teamInfo.color2.r, teamInfo.color2.g, teamInfo.color2.b, 255 * fade)

    draw.SimpleText("ZBattle | Hidden", "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.1, Color(0, 162, 255, 255 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("You are " .. teamInfo.name, "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.5, colorRole, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if prepTime <= 0 then
        draw.SimpleText(teamInfo.objective, "ZB_HomicideMedium", sw * 0.5, sh * 0.9, colorObj, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

function MODE:RoundStart()
    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end
end

hook.Add("Think", "HiddenRoundThemeCleanup", function()
    local round = CurrentRound and CurrentRound()
    if round and round.name == MODE.name then
        if IsValid(hiddenRoundTheme) then
            hiddenRoundTheme:SetVolume(HIDDEN_ROUND_THEME_VOLUME * (GetConVar("snd_musicvolume"):GetFloat() or 1))
        end
        return
    end

    stopHiddenRoundTheme()
end)

hook.Add("PostDrawTranslucentRenderables", "HiddenExtractPingBeacon", function(_, isSkybox)
    if isSkybox then return end
    if hiddenExtractPingUntil <= CurTime() then return end
    if not isvector(hiddenExtractPingPos) or hiddenExtractPingPos == vector_origin then return end

    local frac = math.Clamp((hiddenExtractPingUntil - CurTime()) / 10, 0, 1)
    local alpha = math.floor(40 + 140 * frac)

    render.SetColorMaterial()
    render.DrawWireframeSphere(hiddenExtractPingPos + Vector(0, 0, 6), 95, 18, 18, Color(245, 188, 72, alpha), true)
    render.DrawLine(hiddenExtractPingPos, hiddenExtractPingPos + Vector(0, 0, 200), Color(245, 188, 72, alpha), true)
end)

