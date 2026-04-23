local MODE = MODE

util.AddNetworkString("hidden_start")
util.AddNetworkString("hidden_roundend")

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
    return 1, true
end

local function getPlayingPlayers()
    local players = {}

    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        players[#players + 1] = ply
    end

    return players
end

local function getTeamAlive(teamId)
    local players = {}

    for _, ply in player.Iterator() do
        if ply:Team() ~= teamId then continue end
        if not ply:Alive() then continue end
        if ply.organism and ply.organism.incapacitated then continue end
        players[#players + 1] = ply
    end

    return players
end

local function setIrisPrepSpectator(ply)
    if not IsValid(ply) then return end
    if ply:Alive() then return end

    ply:Spectate(OBS_MODE_NONE)
    ply:SetMoveType(MOVETYPE_OBSERVER)
end

local function isHiddenRoundActive()
    local round = CurrentRound and CurrentRound()
    return round and round.name == MODE.name
end

local function setHiddenPrepState(active)
    if util.NetworkStringToID("hidden_prep_state") == 0 then return end

    net.Start("hidden_prep_state")
    net.WriteBool(active and true or false)
    net.Broadcast()
end

local function clearHiddenLeapImpactProtection(ply, force)
    if not IsValid(ply) then return end
    if not force and (ply.HiddenLeapImpactProtectUntil or 0) > CurTime() then return end
    ply.HiddenLeapImpactProtectUntil = 0
end

local function resetHiddenRoundPlayerState(ply)
    if not IsValid(ply) then return end

    ply.HiddenLeapEndsAt = 0
    ply.HiddenLeapHit = false
    clearHiddenLeapImpactProtection(ply, true)
    ply:SetNWFloat("HiddenNextLeap", 0)
end

local function killSubject617ForRoundEnd(ply)
    if not IsValid(ply) then return end
    if ply:Team() != 0 then return end
    if not ply:Alive() then return end

    if hg and hg.FakeUp and IsValid(ply.FakeRagdoll) then
        hg.FakeUp(ply, true, true)
    end

    if not ply:Alive() then return end

    resetHiddenRoundPlayerState(ply)
    ply:SetNoTarget(false)
    ply:SetRenderMode(RENDERMODE_NORMAL)
    ply:SetColor(color_white)
    ply:KillSilent()
end

local function applyHiddenLeapImpactProtection(mode, ply)
    if not IsValid(ply) then return end

    local untilTime = CurTime() + (mode.HiddenConfig.LeapDuration or 0) + (mode.HiddenConfig.LeapImpactGrace or 0)
    ply.HiddenLeapImpactProtectUntil = math.max(ply.HiddenLeapImpactProtectUntil or 0, untilTime)
end

local function queueHiddenCombatEquipment(mode, ply)
    if not mode or not mode.ApplyHiddenCombatEquipment then return end
    if not IsValid(ply) or ply.HiddenCombatEquipPending then return end

    ply.HiddenCombatEquipPending = true

    timer.Simple(0, function()
        if not IsValid(ply) then return end

        ply.HiddenCombatEquipPending = nil

        if not isHiddenRoundActive() then return end
        if not ply:Alive() then return end
        if ply:Team() != 0 then return end

        mode:ApplyHiddenCombatEquipment(ply)
    end)
end

local function startHiddenCombat(mode)
    if not mode or mode.HiddenCombatStarted then return end

    mode.HiddenCombatStarted = true

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        if ply:Team() != 1 then continue end
        if ply:Alive() then continue end

        ply:Spawn()
    end

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end

        resetHiddenRoundPlayerState(ply)

        if not ply:Alive() then continue end
        if ply:Team() == TEAM_SPECTATOR then continue end
        if not mode.ApplyHiddenCombatEquipment then continue end

        mode:ApplyHiddenCombatEquipment(ply)
    end

    setHiddenPrepState(false)
end

hook.Add("EntityTakeDamage", "HiddenLeapImpactProtection", function(ent, dmgInfo)
    if not IsValid(ent) or not ent:IsPlayer() then return end
    if ent:Team() != 0 then return end
    if (ent.HiddenLeapImpactProtectUntil or 0) <= CurTime() then return end
    if not isHiddenRoundActive() then return end
    if not dmgInfo:IsDamageType(DMG_FALL + DMG_CRUSH) then return end

    dmgInfo:SetDamage(0)
    dmgInfo:ScaleDamage(0)
end)

function MODE:CanLaunch()
    return true
end

function MODE:PickHiddenPlayer(players)
    if #players == 0 then return nil end
    if #players == 1 then return players[1] end

    local filtered = {}
    for _, ply in ipairs(players) do
        if ply:SteamID64() != self.LastHiddenSteamID64 then
            filtered[#filtered + 1] = ply
        end
    end

    local chosen = table.Random(#filtered > 0 and filtered or players)
    if IsValid(chosen) then
        self.LastHiddenSteamID64 = chosen:SteamID64()
    end

    return chosen
end

function MODE:Intermission()
    game.CleanUpMap()

    local players = getPlayingPlayers()
    local hidden = self:PickHiddenPlayer(players)

    self.HiddenSteamID64 = IsValid(hidden) and hidden:SteamID64() or nil
    self.RoundWinner = nil
    self.RoundWinnerText = nil

    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end

        local teamId = (IsValid(hidden) and ply == hidden) and 0 or 1
        ply:SetupTeam(teamId)
    end

    net.Start("hidden_start")
    net.Broadcast()
end

function MODE:CheckAlivePlayers()
    return {
        [0] = getTeamAlive(0),
        [1] = getTeamAlive(1),
    }
end

function MODE:ShouldRoundEnd()
    local hiddenAlive = getTeamAlive(0)
    local irisAlive = getTeamAlive(1)

    if #hiddenAlive <= 0 then
        self.RoundWinner = 1
        self.RoundWinnerText = "IRIS contained Subject 617."
        return true
    end

    if #irisAlive <= 0 then
        self.RoundWinner = 0
        self.RoundWinnerText = "Subject 617 wiped out IRIS."
        return true
    end

    return nil
end

function MODE:BoringRoundFunction()
    self.RoundWinner = 1
    self.RoundWinnerText = "Time expired. IRIS contained Subject 617."
end

function MODE:RoundStart()
    self.HiddenCombatStarted = false

    local prepActive = self.IsHiddenPreparationPhase and self:IsHiddenPreparationPhase()

    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end

        resetHiddenRoundPlayerState(ply)

        if prepActive and ply:Team() == 0 and ply:Alive() then
            queueHiddenCombatEquipment(self, ply)
        end
    end

    if prepActive then
        setHiddenPrepState(true)
        return
    end

    startHiddenCombat(self)
end

function MODE:GiveEquipment()
    timer.Simple(0, function()
        self.HiddenCombatStarted = false

        for _, ply in player.Iterator() do
            if not IsValid(ply) then continue end
            if not ply:Alive() then continue end
            if ply:Team() == TEAM_SPECTATOR then continue end

            ply:StripWeapons()
            ply:StripAmmo()
            ply:SetSuppressPickupNotices(true)
            ply.noSound = true

            local hands = ply:Give("weapon_hands_sh")

            if ply:Team() == 0 then
                ply:SetPlayerClass("subject617")
                zb.GiveRole(ply, "Subject 617", Color(170, 30, 30))
                ply:SetNetVar("CurPluv", "pluvboss")
                queueHiddenCombatEquipment(self, ply)
            else
                ply:SetPlayerClass("swat")
                zb.GiveRole(ply, "IRIS Operative", Color(25, 110, 210))
                ply:SetNetVar("CurPluv", "pluvberet")

                if self.EnsureHiddenSling then
                    self:EnsureHiddenSling(ply)
                end

                if self.ClearHiddenArmor then
                    self:ClearHiddenArmor(ply)
                end

                if self.SendHiddenLoadoutData then
                    self:SendHiddenLoadoutData(ply, true)
                end

                ply:KillSilent()
                timer.Simple(0, function()
                    if not IsValid(ply) then return end
                    setIrisPrepSpectator(ply)
                end)
            end

            if IsValid(hands) then
                ply:SelectWeapon(hands:GetClass())
            end

            resetHiddenRoundPlayerState(ply)

            timer.Simple(0.1, function()
                if not IsValid(ply) then return end
                ply.noSound = false
            end)

            ply:SetSuppressPickupNotices(false)
        end

        setHiddenPrepState(true)
    end)
end

function MODE:CanSpawn()
    return false
end

local function getPreferredSpawnVectors(...)
    for index = 1, select("#", ...) do
        local pointGroup = select(index, ...)
        if not isstring(pointGroup) or pointGroup == "" then continue end

        local points = zb.TranslatePointsToVectors(zb.GetMapPoints(pointGroup))
        if #points > 0 then
            return points
        end
    end

    return {}
end

function MODE:GetTeamSpawn()
    local hiddenSpawns = getPreferredSpawnVectors("HDN_SUBSPAWN", "HDN_HIDDEN", "HMCD_TDM_T")
    local irisSpawns = getPreferredSpawnVectors("HDN_IRISSPAWN", "HDN_IRIS", "HMCD_TDM_CT")

    return hiddenSpawns, irisSpawns
end

function MODE:PlayerSpawn(ply)
    if ply:Team() == TEAM_SPECTATOR then return end

    local cfg = self.HiddenConfig
    clearHiddenLeapImpactProtection(ply, true)
    local prepActive = self.IsHiddenPreparationPhase and self:IsHiddenPreparationPhase()

    if prepActive and ply:Team() == 1 then
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            if ply:Alive() then
                ply:KillSilent()
            end

            setIrisPrepSpectator(ply)
        end)

        return
    end

    if ply:Team() == 0 then
        ply:SetHealth(cfg.HiddenHealth)
        ply:SetMaxHealth(cfg.HiddenHealth)
        ply:SetRunSpeed(cfg.HiddenRunSpeed)
        ply:SetWalkSpeed(cfg.HiddenWalkSpeed)
        ply:SetJumpPower(cfg.HiddenJumpPower)
        ply:SetGravity(cfg.HiddenGravity)
        ply:SetNoTarget(true)
        queueHiddenCombatEquipment(self, ply)
    else
        ply:SetHealth(cfg.IrisHealth)
        ply:SetMaxHealth(cfg.IrisHealth)
        ply:SetRunSpeed(cfg.IrisRunSpeed)
        ply:SetWalkSpeed(cfg.IrisWalkSpeed)
        ply:SetJumpPower(cfg.IrisJumpPower)
        ply:SetGravity(cfg.IrisGravity)
        ply:SetNoTarget(false)
        ply:SetRenderMode(RENDERMODE_NORMAL)
        ply:SetColor(color_white)
    end
end

function MODE:KeyPress(ply, key)
    if key != IN_RELOAD then return end
    if ply:Team() != 0 then return end
    if not ply:Alive() then return end

    local now = CurTime()
    if ply:GetNWFloat("HiddenNextLeap", 0) > now then return end

    ply.HiddenLeapEndsAt = now + self.HiddenConfig.LeapDuration
    ply.HiddenLeapHit = false
    applyHiddenLeapImpactProtection(self, ply)
    ply:SetNWFloat("HiddenNextLeap", now + self.HiddenConfig.LeapCooldown)
    ply:SetVelocity(ply:GetAimVector() * self.HiddenConfig.LeapForce + Vector(0, 0, self.HiddenConfig.LeapUpForce))
end

function MODE:RoundThink()
    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        if (ply.HiddenLeapImpactProtectUntil or 0) <= 0 then continue end
        if (ply.HiddenLeapImpactProtectUntil or 0) > CurTime() then continue end

        clearHiddenLeapImpactProtection(ply, true)
    end

    if self.IsHiddenPreparationPhase and self:IsHiddenPreparationPhase() then
        for _, ply in player.Iterator() do
            if not IsValid(ply) then continue end
            if ply:Team() != 1 then continue end

            if ply:Alive() then
                ply:KillSilent()
            end

            setIrisPrepSpectator(ply)
        end
    elseif not self.HiddenCombatStarted then
        startHiddenCombat(self)
    end

    for _, hunter in ipairs(getTeamAlive(0)) do
        if (hunter.HiddenLeapEndsAt or 0) < CurTime() then continue end
        if hunter.HiddenLeapHit then continue end

        for _, target in ipairs(ents.FindInSphere(hunter:GetPos(), self.HiddenConfig.LeapRange)) do
            if not IsValid(target) or not target:IsPlayer() then continue end
            if target:Team() != 1 then continue end
            if not target:Alive() then continue end

            local dmg = DamageInfo()
            dmg:SetAttacker(hunter)
            dmg:SetInflictor(hunter)
            dmg:SetDamage(self.HiddenConfig.LeapDamage)
            dmg:SetDamageType(DMG_SLASH)
            dmg:SetDamageForce(hunter:GetAimVector() * 900)

            target:TakeDamageInfo(dmg)
            hunter.HiddenLeapHit = true
            break
        end
    end
end

function MODE:EndRound()
    local winner = self.RoundWinner
    local winnerText = tostring(self.RoundWinnerText or "")

    if winnerText == "" then
        winnerText = (winner == 0 and "Subject 617 wiped out IRIS.") or "IRIS contained Subject 617."
    end

    PrintMessage(HUD_PRINTTALK, winnerText)

    for _, ply in player.Iterator() do
        killSubject617ForRoundEnd(ply)
    end

    timer.Simple(2, function()
        net.Start("hidden_roundend")
        net.WriteInt(winner or 1, 4)
        net.Broadcast()
    end)

    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end

        if winner and ply:Team() == winner then
            ply:GiveExp(math.random(18, 32))
            ply:GiveSkill(math.Rand(0.1, 0.16))
        else
            ply:GiveSkill(-math.Rand(0.04, 0.08))
        end
    end
end

function MODE:PlayerDeath(ply)
    ply:SetNoTarget(false)
    ply.HiddenLeapEndsAt = 0
    ply.HiddenLeapHit = false
    clearHiddenLeapImpactProtection(ply, true)

    if self.IsHiddenPreparationPhase and self:IsHiddenPreparationPhase() and IsValid(ply) and ply:Team() == 1 then
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            setIrisPrepSpectator(ply)
        end)
    end
end