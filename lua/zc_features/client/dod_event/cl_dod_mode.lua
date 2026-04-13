-- cl_dod_mode.lua — DoD mode client HUD (loads on demand)

if SERVER then return end

-- ── Fonts ─────────────────────────────────────────────────────────────────────

surface.CreateFont("DOD_HUD_Flag",    { font = "Roboto", size = 13, weight = 600 })
surface.CreateFont("DOD_HUD_FlagSm",  { font = "Roboto", size = 11, weight = 400 })
surface.CreateFont("DOD_HUD_Wave",    { font = "Roboto", size = 36, weight = 700 })
surface.CreateFont("DOD_HUD_WaveSub", { font = "Roboto", size = 16, weight = 400 })
surface.CreateFont("DOD_HUD_Score",   { font = "Roboto", size = 15, weight = 600 })
surface.CreateFont("DOD_HUD_ScoreSm", { font = "Roboto", size = 12, weight = 400 })
surface.CreateFont("DOD_HUD_Info",    { font = "Roboto", size = 12, weight = 500 })

-- ── Colors ────────────────────────────────────────────────────────────────────

local CLR_NEUTRAL  = Color(120, 120, 130, 255)
local CLR_AXIS     = Color(190, 60,  60,  255)
local CLR_ALLIES   = Color(60,  110, 200, 255)
local CLR_BG       = Color(15,  15,  20,  180)
local CLR_BORDER   = Color(60,  65,  80,  200)
local CLR_TEXT     = Color(230, 230, 230, 255)
local CLR_MUTED    = Color(160, 160, 170, 200)
local CLR_WAVE_BG  = Color(10,  10,  15,  200)

local function OwnerColor(owner)
    if owner == 0 then return CLR_AXIS
    elseif owner == 1 then return CLR_ALLIES
    else return CLR_NEUTRAL end
end

local function OwnerName(owner)
    if owner == 0 then return (DOD_TEAM and DOD_TEAM[0] and DOD_TEAM[0].name) or "Axis"
    elseif owner == 1 then return (DOD_TEAM and DOD_TEAM[1] and DOD_TEAM[1].name) or "Allies"
    else return "Neutral" end
end

-- ── Client state ──────────────────────────────────────────────────────────────

local flagList   = {}
local matchScore = { [0] = 0, [1] = 0 }
local waveInterval  = 0
local waveEndTime   = 0
local roundResult   = nil
local resultExpiry  = 0

-- ── Net receivers ──────────────────────────────────────────────────────────────

net.Receive("DOD_FlagInit", function()
    local n = net.ReadUInt(6)
    flagList = {}
    for i = 1, n do
        flagList[i] = {
            name     = net.ReadString(),
            pos      = net.ReadVector(),
            radius   = net.ReadFloat(),
            owner    = net.ReadInt(4),
            progress = net.ReadFloat(),
        }
        if flagList[i].owner == -1 then flagList[i].owner = nil end
    end
end)

net.Receive("DOD_FlagSync", function()
    local n = net.ReadUInt(6)
    for i = 1, n do
        local owner    = net.ReadInt(4)
        local progress = net.ReadFloat()
        if flagList[i] then
            flagList[i].owner    = (owner == -1) and nil or owner
            flagList[i].progress = progress
        end
    end
end)

net.Receive("DOD_WaveCountdown", function()
    waveInterval = net.ReadFloat()
    waveEndTime  = net.ReadFloat()
end)

net.Receive("DOD_MatchScore", function()
    matchScore[0] = net.ReadUInt(8)
    matchScore[1] = net.ReadUInt(8)
end)

net.Receive("DOD_RoundResult", function()
    local winner    = net.ReadInt(4)
    local wname     = net.ReadString()
    local f0        = net.ReadUInt(6)
    local f1        = net.ReadUInt(6)
    roundResult  = { winner = winner, winnerName = wname, f0 = f0, f1 = f1 }
    resultExpiry = CurTime() + 6
end)

-- ── HUD drawing ───────────────────────────────────────────────────────────────

local function DrawFlagBar()
    if not flagList or #flagList == 0 then return end
    if not (zb and zb.CROUND == "dod") then return end

    local sw     = ScrW()
    local n      = #flagList
    local PAD    = 8
    local FPAD   = 6
    local FW     = math.min(110, (sw - PAD * 2 - FPAD * (n - 1)) / n)
    local FH     = 48
    local totalW = n * FW + (n - 1) * FPAD
    local startX = (sw - totalW) / 2
    local Y      = 8

    for i, f in ipairs(flagList) do
        local x    = startX + (i - 1) * (FW + FPAD)
        local owner = f.owner
        local prog  = f.progress
        local ownerClr = OwnerColor(owner)

        draw.RoundedBox(4, x, Y, FW, FH, CLR_BG)
        surface.SetDrawColor(ownerClr.r, ownerClr.g, ownerClr.b, 80)
        surface.DrawRect(x, Y, FW, FH)
        surface.SetDrawColor(CLR_BORDER)
        surface.DrawOutlinedRect(x, Y, FW, FH, 1)

        surface.SetDrawColor(ownerClr)
        surface.DrawRect(x, Y, FW, 3)

        draw.SimpleText(f.name, "DOD_HUD_Flag", x + FW / 2, Y + 8, CLR_TEXT,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        draw.SimpleText(OwnerName(owner), "DOD_HUD_FlagSm", x + FW / 2, Y + 22, ownerClr,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

        local barY  = Y + FH - 10
        local barH  = 6
        local barW  = FW - 8
        local barX  = x + 4

        surface.SetDrawColor(40, 40, 50, 200)
        surface.DrawRect(barX, barY, barW, barH)

        local norm = (prog + 1) / 2
        if norm < 0.5 then
            local w0 = math.Round((0.5 - norm) * 2 * barW)
            surface.SetDrawColor(CLR_AXIS)
            surface.DrawRect(barX, barY, w0, barH)
        end
        if norm > 0.5 then
            local w1 = math.Round((norm - 0.5) * 2 * barW)
            surface.SetDrawColor(CLR_ALLIES)
            surface.DrawRect(barX + barW - w1, barY, w1, barH)
        end
        surface.SetDrawColor(80, 80, 90, 255)
        surface.DrawRect(barX + barW / 2 - 1, barY, 2, barH)
    end
end

local function DrawWaveCountdown()
    if not (zb and zb.CROUND == "dod") then return end
    if not IsValid(LocalPlayer()) then return end
    if LocalPlayer():Alive() then return end
    if waveEndTime <= 0 then return end

    local remaining = math.max(0, waveEndTime - CurTime())
    local sw, sh    = ScrW(), ScrH()
    local cx        = sw / 2
    local cy        = sh / 2

    local W, H = 220, 70
    draw.RoundedBox(8, cx - W / 2, cy - H / 2, W, H, CLR_WAVE_BG)
    surface.SetDrawColor(CLR_BORDER)
    surface.DrawOutlinedRect(cx - W / 2, cy - H / 2, W, H, 1)

    draw.SimpleText("WAVE RESPAWN", "DOD_HUD_WaveSub", cx, cy - 16, CLR_MUTED,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(string.format("%.1f", remaining), "DOD_HUD_Wave", cx, cy + 10, CLR_TEXT,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function DrawMatchScore()
    if not (zb and zb.CROUND == "dod") then return end

    local sw    = ScrW()
    local W, H  = 160, 52
    local x     = sw - W - 8
    local y     = 8

    draw.RoundedBox(4, x, y, W, H, CLR_BG)
    surface.SetDrawColor(CLR_BORDER)
    surface.DrawOutlinedRect(x, y, W, H, 1)

    draw.SimpleText("MATCH SCORE", "DOD_HUD_ScoreSm", x + W / 2, y + 6, CLR_MUTED,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    draw.SimpleText(tostring(matchScore[0]), "DOD_HUD_Score", x + W / 4, y + 28, CLR_AXIS,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText((DOD_TEAM and DOD_TEAM[0] and DOD_TEAM[0].name) or "Axis",
        "DOD_HUD_ScoreSm", x + W / 4, y + 42, CLR_AXIS, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    surface.SetDrawColor(CLR_BORDER)
    surface.DrawRect(x + W / 2 - 1, y + 20, 1, 26)

    draw.SimpleText(tostring(matchScore[1]), "DOD_HUD_Score", x + 3 * W / 4, y + 28, CLR_ALLIES,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText((DOD_TEAM and DOD_TEAM[1] and DOD_TEAM[1].name) or "Allies",
        "DOD_HUD_ScoreSm", x + 3 * W / 4, y + 42, CLR_ALLIES, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function DrawRoundResult()
    if not roundResult then return end
    if CurTime() > resultExpiry then roundResult = nil return end

    local sw, sh = ScrW(), ScrH()
    local W, H   = 320, 80
    local cx     = sw / 2
    local ry     = sh * 0.35

    local alpha  = 255
    local fade   = resultExpiry - CurTime()
    if fade < 1.5 then alpha = math.Round(fade / 1.5 * 255) end

    local winClr = roundResult.winner == 0 and CLR_AXIS
        or roundResult.winner == 1 and CLR_ALLIES
        or CLR_MUTED

    draw.RoundedBox(6, cx - W / 2, ry, W, H,
        Color(CLR_BG.r, CLR_BG.g, CLR_BG.b, math.Round(alpha * 0.85)))
    surface.SetDrawColor(winClr.r, winClr.g, winClr.b, alpha)
    surface.DrawOutlinedRect(cx - W / 2, ry, W, H, 2)

    draw.SimpleText(roundResult.winnerName .. " wins!", "DOD_ClassTitle", cx, ry + 18,
        Color(winClr.r, winClr.g, winClr.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(
        string.format("Flags — %s: %d   %s: %d",
            (DOD_TEAM and DOD_TEAM[0] and DOD_TEAM[0].name) or "Axis",   roundResult.f0,
            (DOD_TEAM and DOD_TEAM[1] and DOD_TEAM[1].name) or "Allies", roundResult.f1),
        "DOD_ClassBody", cx, ry + 50,
        Color(CLR_MUTED.r, CLR_MUTED.g, CLR_MUTED.b, alpha),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function DrawCommandOverlay()
    if not (zb and zb.CROUND == "dod") then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if not lp:GetNWBool("DOD_ShowInfo", true) then return end

    local lines = {
        "DoD Commands: !dodclass  !dodscore  !dodteam  !dodinfo",
        "Admin: !dodconfig show|req|single|neutral|enemy|wave|round|presets|export|import [map]|preload <map> <preset>|save",
        "Admin: !dodcfgmenu  !dodresetscore  !dodbalance on|off|toggle|status  !dodloadout",
        "Admin Flags: !dodflag_place [name] [radius] [neutral|axis|allies]  !dodflag_save  !dodflag_reload  !dodflag_clear",
    }

    surface.SetFont("DOD_HUD_Info")
    local maxW = 0
    for _, line in ipairs(lines) do
        local w = surface.GetTextSize(line)
        if w > maxW then maxW = w end
    end

    local pad = 8
    local lineH = 14
    local boxW = maxW + pad * 2
    local boxH = lineH * #lines + pad * 2
    local x = (ScrW() - boxW) / 2
    local y = 60

    draw.RoundedBox(4, x, y, boxW, boxH, Color(10, 10, 15, 160))
    surface.SetDrawColor(CLR_BORDER)
    surface.DrawOutlinedRect(x, y, boxW, boxH, 1)

    for i, line in ipairs(lines) do
        draw.SimpleText(line, "DOD_HUD_Info", x + pad, y + pad + (i - 1) * lineH,
            Color(230, 230, 230, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end

hook.Add("HUDPaint", "DOD_HUD", function()
    DrawFlagBar()
    DrawMatchScore()
    DrawWaveCountdown()
    DrawRoundResult()
    DrawCommandOverlay()
end)

hook.Add("ZB_PreRoundStart", "DOD_HUD_Reset", function()
    flagList    = {}
    waveEndTime = 0
    roundResult = nil
end)

-- ── Team picker panel ─────────────────────────────────────────────────────────

local teamCounts  = { [0] = 0, [1] = 0 }
local teamPicker  = nil

local function CloseTeamPicker()
    if IsValid(teamPicker) then teamPicker:Remove() end
    teamPicker = nil
end

local function BuildTeamPicker(c0, c1)
    if IsValid(teamPicker) then teamPicker:Remove() end

    teamCounts[0] = c0
    teamCounts[1] = c1

    local W, H  = 420, 240
    local sx    = (ScrW() - W) / 2
    local sy    = (ScrH() - H) / 2

    teamPicker = vgui.Create("DPanel")
    teamPicker:SetPos(sx, sy)
    teamPicker:SetSize(W, H)
    teamPicker:SetZPos(600)
    teamPicker:MakePopup()
    teamPicker:SetKeyboardInputEnabled(false)

    teamPicker.Paint = function(self, w, h)
        draw.RoundedBox(6, 0, 0, w, h, CLR_BG)
        draw.RoundedBoxEx(6, 0, 0, w, 36, CLR_BORDER, true, true, false, false)
        surface.SetDrawColor(CLR_BORDER)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("Choose Your Team", "DOD_ClassTitle", w / 2, 18, CLR_TEXT,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Teams lock when the round starts.", "DOD_ClassSmall",
            w / 2, H - 14, CLR_MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local BPAD = 16
    local BW   = (W - BPAD * 3) / 2
    local BH   = 120
    local BY   = 48

    for i, teamIdx in ipairs({ 0, 1 }) do
        local td     = DOD_TEAM and DOD_TEAM[teamIdx]
        local tname  = td and td.name or ("Team " .. teamIdx)
        local tclr   = teamIdx == 0 and CLR_AXIS or CLR_ALLIES
        local bx     = BPAD + (i - 1) * (BW + BPAD)

        local count      = teamCounts[teamIdx] or 0
        local total      = teamCounts[0] + teamCounts[1]
        local maxAllowed = total > 0 and math.ceil((total + 1) / 2) or 999
        local isFull     = (count + 1) > maxAllowed and total > 1

        local btn = vgui.Create("DButton", teamPicker)
        btn:SetPos(bx, BY)
        btn:SetSize(BW, BH)
        btn:SetText("")
        btn:SetEnabled(not isFull)

        btn.Paint = function(self, w, h)
            local count = teamCounts[teamIdx] or 0
            local base = Color(tclr.r * 0.3, tclr.g * 0.3, tclr.b * 0.3, 220)
            local hov  = Color(tclr.r * 0.45, tclr.g * 0.45, tclr.b * 0.45, 240)
            draw.RoundedBox(6, 0, 0, w, h, (self:IsHovered() and not isFull) and hov or base)
            surface.SetDrawColor(isFull and Color(80, 80, 90) or tclr)
            surface.DrawOutlinedRect(0, 0, w, h, 2)

            local nameClr = isFull and CLR_MUTED or CLR_TEXT
            draw.SimpleText(tname, "DOD_ClassTitle", w / 2, h / 2 - 22,
                nameClr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            draw.SimpleText(count .. " players", "DOD_ClassBody", w / 2, h / 2 + 4,
                isFull and CLR_MUTED or tclr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            if isFull then
                draw.SimpleText("Team Full", "DOD_ClassSmall", w / 2, h / 2 + 24,
                    Color(200, 130, 130), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        if not isFull then
            btn.DoClick = function()
                net.Start("DOD_JoinTeam")
                    net.WriteUInt(teamIdx, 2)
                net.SendToServer()
                CloseTeamPicker()
            end
            btn:SetCursor("hand")
        end
    end
end

net.Receive("DOD_OpenTeamPicker", function()
    local c0 = net.ReadUInt(8)
    local c1 = net.ReadUInt(8)
    BuildTeamPicker(c0, c1)
end)

net.Receive("DOD_TeamCounts", function()
    local c0 = net.ReadUInt(8)
    local c1 = net.ReadUInt(8)
    teamCounts[0] = c0
    teamCounts[1] = c1
end)

hook.Add("ZB_StartRound", "DOD_TeamPicker_Close", function()
    if zb and zb.CROUND == "dod" then
        CloseTeamPicker()
    end
end)

print("[DoD] Client HUD loaded")
