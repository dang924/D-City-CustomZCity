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
    zb.RemoveFade()
end)

net.Receive("hidden_roundend", function()
    local winner = net.ReadInt(4)
    surface.PlaySound("ambient/alarms/warningbell1.wav")
    stopHiddenRoundTheme()

    CreateEndMenu(winner)
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
        if ply:Team() == TEAM_SPECTATOR then continue end

        local button = vgui.Create("DButton", scrollPanel)
        button:SetSize(100, 50)
        button:Dock(TOP)
        button:DockMargin(8, 6, 8, -1)
        button:SetText("")

        button.Paint = function(self, w, h)
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
    if zb.ROUND_START + 7.5 < CurTime() then return end

    local fade = math.Clamp(zb.ROUND_START + 7.5 - CurTime(), 0, 1)
    surface.SetDrawColor(0, 0, 0, 255 * fade)
    surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
end

function MODE:HUDPaint()
    local roundStart = zb.ROUND_START or CurTime()
    local roundTime = math.max(roundStart + (zb.ROUND_TIME or self.ROUND_TIME or 240) - CurTime(), 0)
    local prepTime = math.max((zb.ROUND_BEGIN or roundStart) - CurTime(), 0)
    local teamInfo = teams[lply:Team()] or teams[1]
    local timerText
    local timerColor

    if prepTime > 0 then
        timerText = "PREP " .. string.FormattedTime(prepTime, "%02i:%02i:%02i")
        timerColor = Color(255, 220, 120)
    else
        timerText = "TIME " .. string.FormattedTime(roundTime, "%02i:%02i:%02i")
        timerColor = Color(255, 255, 255)
    end

    draw.SimpleText(timerText, "ZB_HomicideMedium", sw * 0.5, sh * 0.15, timerColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if prepTime <= 0 and lply:Team() == 0 and lply:Alive() then
        local leapReadyAt = lply:GetNWFloat("HiddenNextLeap", 0)
        local cooldown = math.max(leapReadyAt - CurTime(), 0)
        local leapText = (cooldown <= 0 and "Leap ready" or ("Leap in " .. string.format("%.1f", cooldown) .. "s"))
        local leapColor = (cooldown <= 0 and Color(120, 255, 120) or Color(255, 150, 150))

        draw.SimpleText(leapText, "ZB_HomicideMedium", sw * 0.5, sh * 0.9, leapColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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

