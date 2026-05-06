ZSCAV = ZSCAV or {}

local VECTOR_ZERO = Vector(0, 0, 0)

local Raid = ZSCAV.Raid or {}
ZSCAV.Raid = Raid

Raid.Config = Raid.Config or {
    ArmDelay = 300,
    RearmDelay = 300,
    Countdown = 30,
    MinPlayers = 6,
    PadCapacity = 2,
    RaidDuration = 1800,
    ExtractRadius = 220,
    DefaultExtractDuration = 8,
    LateSpawnWindow = 300,
    LateSpawnCountdown = 30,
    LateSpawnSafeRadius = 600,
    SafeZoneExitPadding = 96,
    SafeZoneExitGrace = 0.6,
    SafeZoneExitBounceCooldown = 1.0,
}

Raid.RuntimePads = Raid.RuntimePads or {}
Raid.PadOccupants = Raid.PadOccupants or {}
Raid.PadsArmedAt = Raid.PadsArmedAt or 0
Raid.CountdownEndAt = Raid.CountdownEndAt or 0
Raid.Initialized = Raid.Initialized or false
Raid.NextThinkAt = Raid.NextThinkAt or 0
Raid.BattlefieldLockActive = Raid.BattlefieldLockActive or false
Raid.BattlefieldCooldownEndAt = Raid.BattlefieldCooldownEndAt or 0
Raid.BattlefieldPlayers = Raid.BattlefieldPlayers or 0
Raid.LateWindowEndAt = Raid.LateWindowEndAt or 0
Raid.LateCountdownEndAt = Raid.LateCountdownEndAt or 0
Raid.LateReadyPlayers = Raid.LateReadyPlayers or 0
Raid.UsedSpawnGroupIDs = Raid.UsedSpawnGroupIDs or {}
Raid.CycleLockedTokens = Raid.CycleLockedTokens or {}

local function noticePlayer(ply, text)
    local helper = ZSCAV.ServerHelpers and ZSCAV.ServerHelpers.Notice
    if IsValid(ply) and isfunction(helper) then
        helper(ply, text)
        return
    end

    if IsValid(ply) then
        ply:ChatPrint("[ZScav] " .. tostring(text or ""))
    end
end

local function sendLateJoinSpawnClientHint(ply)
    if not IsValid(ply) then return end

    net.Start("ZScavRaidJoinHint")
        net.WriteBool(ply:Team() == TEAM_SPECTATOR)
    net.Send(ply)
end

local function resolveLateJoinTarget(requester, value)
    local query = string.Trim(tostring(value or ""))
    if query == "" then return nil end

    local lowerQuery = string.lower(query)
    if lowerQuery == "me" then
        return IsValid(requester) and requester or nil
    end

    if lowerQuery == "all" then
        return "all"
    end

    if player.GetBySteamID64 then
        local sidTarget = player.GetBySteamID64(query)
        if IsValid(sidTarget) then
            return sidTarget
        end
    end

    local exactMatch = nil
    for _, candidate in player.Iterator() do
        if not IsValid(candidate) then continue end
        if tostring(candidate:SteamID64() or "") == query then
            return candidate
        end

        if string.lower(tostring(candidate:Nick() or "")) == lowerQuery then
            exactMatch = candidate
            break
        end
    end
    if IsValid(exactMatch) then
        return exactMatch
    end

    for _, candidate in player.Iterator() do
        if not IsValid(candidate) then continue end
        if string.find(string.lower(tostring(candidate:Nick() or "")), lowerQuery, 1, true) then
            return candidate
        end
    end

    return nil
end

local function isRaidRoundLive()
    return ZSCAV:IsActive() and zb and zb.ROUND_STATE == 1
end

local function clearRaidGlobals()
    SetGlobalBool("ZScavRaidPadsActive", false)
    SetGlobalFloat("ZScavRaidPadsArmedAt", 0)
    SetGlobalFloat("ZScavRaidPadCountdownEnd", 0)
    SetGlobalInt("ZScavRaidPadReadyPlayers", 0)
    SetGlobalInt("ZScavRaidPadMinPlayers", Raid.Config.MinPlayers)
    SetGlobalInt("ZScavRaidBattlefieldPlayers", 0)
    SetGlobalFloat("ZScavRaidLateSpawnWindowEnd", 0)
    SetGlobalFloat("ZScavRaidLateSpawnCountdownEnd", 0)
    SetGlobalInt("ZScavRaidLateSpawnReadyPlayers", 0)
end

local function isPlayerInSafeZone(ply)
    if not IsValid(ply) then return false end
    if ply:GetNWBool("ZCityInSafeZone", false) then return true end

    local lib = rawget(_G, "ZCitySafeZones")
    if istable(lib) and isfunction(lib.FindZoneAtPos) then
        return lib.FindZoneAtPos(ply:GetPos(), lib.ServerZones or {}, 0) ~= nil
    end

    return false
end

local function findPlayerSafeZone(ply, padding)
    if not IsValid(ply) then return nil end

    local lib = rawget(_G, "ZCitySafeZones")
    if istable(lib) and isfunction(lib.FindZoneAtPos) then
        return lib.FindZoneAtPos(ply:GetPos(), lib.ServerZones or {}, padding or 0)
    end

    return ply:GetNWBool("ZCityInSafeZone", false) and true or nil
end

local function teleportPlayerToSafeBack(ply)
    if not (IsValid(ply) and ply:Alive()) then return false, "invalid_player" end

    local point = ZSCAV.GetRandomSafeBackPoint and ZSCAV:GetRandomSafeBackPoint() or nil
    if not (istable(point) and isvector(point.pos)) then
        return false, "missing_safe_back"
    end

    local ang = point.ang or Angle(0, tonumber(point.yaw) or ply:EyeAngles().y, 0)
    ply:SetPos(point.pos)
    if isangle(ang) then
        ply:SetAngles(ang)
        ply:SetEyeAngles(Angle(0, ang.y, 0))
    end
    ply:SetVelocity(-ply:GetVelocity())
    return true
end

local function shouldBounceLobbyPlayerBack(ply)
    if not (IsValid(ply) and ply:IsPlayer() and ply:Alive()) then return false end
    if ply:Team() == TEAM_SPECTATOR then return false end
    if ply.zscav_raid_active then return false end

    return isRaidRoundLive()
end

local function isPlayerQueuedOnPad(ply)
    if not IsValid(ply) then return false end

    for _, members in pairs(Raid.PadOccupants or {}) do
        for _, member in ipairs(members or {}) do
            if member == ply then
                return true
            end
        end
    end

    return false
end

local function enforceSafeZoneLobbyBoundary(ply)
    if not shouldBounceLobbyPlayerBack(ply) then
        ply.zscav_safezone_exit_since = nil
        return
    end

    if isPlayerQueuedOnPad(ply) then
        ply.zscav_safezone_exit_since = nil
        return
    end

    local now = CurTime()
    local zone = findPlayerSafeZone(ply, Raid.Config.SafeZoneExitPadding)
    if zone then
        ply.zscav_safezone_exit_since = nil
        return
    end

    local outsideSince = tonumber(ply.zscav_safezone_exit_since) or 0
    if outsideSince <= 0 then
        ply.zscav_safezone_exit_since = now
        return
    end

    if now - outsideSince < math.max(tonumber(Raid.Config.SafeZoneExitGrace) or 0, 0) then
        return
    end

    if (tonumber(ply.zscav_safezone_exit_bounce_until) or 0) > now then
        return
    end

    local ok = teleportPlayerToSafeBack(ply)
    ply.zscav_safezone_exit_bounce_until = now + math.max(tonumber(Raid.Config.SafeZoneExitBounceCooldown) or 0, 0.25)
    ply.zscav_safezone_exit_since = nil

    if ok then
        noticePlayer(ply, "Leave the safe zone through a spawn pad.")
    end
end

local function getPadPoints()
    return zb and zb.GetMapPoints and (zb.GetMapPoints("ZSCAV_PAD") or {}) or {}
end

local function getExtractPoints()
    return zb and zb.GetMapPoints and (zb.GetMapPoints("ZSCAV_EXTRACT") or {}) or {}
end

local function getSpawnGroups()
    return ZScavSpawnPoints and ZScavSpawnPoints.GetGroups and (ZScavSpawnPoints.GetGroups() or {}) or {}
end

local function getNamedExtracts()
    return ZScavExtracts and ZScavExtracts.GetExtracts and (ZScavExtracts.GetExtracts() or {}) or {}
end

local function getPadLabel(pad)
    local index = math.max(tonumber(pad:GetNWInt("ZScavPadIndex", 0)) or 0, 0)
    if index <= 0 then
        index = math.max(tonumber(pad.zscav_pad_index) or 0, 0)
    end
    return index > 0 and ("Pad " .. tostring(index)) or "Pad"
end

local function getManagedPads()
    local pads = {}

    for _, pad in ipairs(Raid.RuntimePads or {}) do
        if IsValid(pad) then
            pads[#pads + 1] = pad
        end
    end

    if #pads > 0 then
        for _, pad in ipairs(ents.FindByClass("ent_zscav_spawnpad")) do
            if IsValid(pad) and not pad.zscav_runtime_pad then
                pads[#pads + 1] = pad
            end
        end
        return pads
    end

    return ents.FindByClass("ent_zscav_spawnpad")
end

local function pushPlayerOffPad(ply, pad)
    if not (IsValid(ply) and IsValid(pad)) then return end

    local delta = ply:GetPos() - pad:GetPos()
    delta.z = 0
    if delta:LengthSqr() <= 1 then
        delta = pad:GetForward()
        delta.z = 0
    end
    delta:Normalize()

    local radius = math.max(tonumber(pad.ZScavPadRadius) or 96, 32)
    local target = pad:GetPos() + delta * (radius + 18) + Vector(0, 0, 8)
    ply:SetPos(target)
    ply:SetVelocity(delta * 120)
end

local function isPlayerStandingOnPad(ply, pad)
    if not (IsValid(ply) and IsValid(pad)) then return false end

    if isfunction(pad.IsPlayerOnPad) then
        return pad:IsPlayerOnPad(ply)
    end

    local origin = pad:GetPos()
    local pos = ply:GetPos()
    local dx, dy = pos.x - origin.x, pos.y - origin.y
    local radius = math.max(tonumber(pad.ZScavPadRadius) or 96, 32)

    if (dx * dx + dy * dy) > (radius * radius) then
        return false
    end

    return math.abs(pos.z - origin.z) < 96
end

local function isPlayerEligibleForPad(ply, pad)
    if not (IsValid(ply) and ply:IsPlayer() and ply:Alive()) then return false end
    if not isRaidRoundLive() then return false end
    if ply:Team() == TEAM_SPECTATOR then return false end
    if ply.zscav_raid_active then return false end
    local token = tostring(ply:SteamID64() or "")
    if token ~= "" and Raid.CycleLockedTokens[token] then return false end
    if isPlayerInSafeZone(ply) then return true end
    return isPlayerStandingOnPad(ply, pad)
end

local function getPlayerToken(ply)
    return tostring(IsValid(ply) and ply:SteamID64() or "")
end

local function normalizeExtractDuration(duration)
    return math.Clamp(math.floor(tonumber(duration) or Raid.Config.DefaultExtractDuration or 8), 1, 255)
end

local function getExtractLabel(extract, index)
    local label = string.Trim(tostring(istable(extract) and (extract.label or extract.name) or ""))
    if label ~= "" then
        return label
    end

    return "Extract #" .. tostring(index or 1)
end

local function getExtractID(extract, index)
    local extractID = string.Trim(tostring(istable(extract) and extract.id or ""))
    if extractID ~= "" then
        return extractID
    end

    if istable(extract) and isvector(extract.pos) then
        return string.format("extract_%d_%.3f_%.3f_%.3f", index or 0, extract.pos.x, extract.pos.y, extract.pos.z)
    end

    return "extract_" .. tostring(index or 0)
end

local function buildExtractNameSummary(extracts)
    local labels = {}
    local total = math.max(#(extracts or {}), 0)

    for index, extract in ipairs(extracts or {}) do
        labels[#labels + 1] = getExtractLabel(extract, index)
        if #labels >= 4 then break end
    end

    if total > #labels then
        labels[#labels + 1] = "+" .. tostring(total - #labels) .. " more"
    end

    return table.concat(labels, ", ")
end

function Raid:SyncGlobals(readyCount)
    local lateActive = self:IsLateSpawnModeActive()
    local padsActive = (not lateActive) and self:ArePadsAvailable() or false
    SetGlobalBool("ZScavRaidPadsActive", padsActive)
    SetGlobalFloat("ZScavRaidPadsArmedAt", self.PadsArmedAt or 0)
    SetGlobalFloat("ZScavRaidPadCountdownEnd", lateActive and 0 or (self.CountdownEndAt or 0))
    SetGlobalInt("ZScavRaidPadReadyPlayers", lateActive and 0 or math.max(tonumber(readyCount) or 0, 0))
    SetGlobalInt("ZScavRaidPadMinPlayers", self.Config.MinPlayers)
    SetGlobalInt("ZScavRaidBattlefieldPlayers", math.max(tonumber(self.BattlefieldPlayers) or 0, 0))
    SetGlobalFloat("ZScavRaidLateSpawnWindowEnd", self.LateWindowEndAt or 0)
    SetGlobalFloat("ZScavRaidLateSpawnCountdownEnd", self.LateCountdownEndAt or 0)
    SetGlobalInt("ZScavRaidLateSpawnReadyPlayers", math.max(tonumber(self.LateReadyPlayers) or 0, 0))
end

function Raid:IsLateSpawnWindowOpen()
    return self.BattlefieldLockActive and (tonumber(self.LateWindowEndAt) or 0) > CurTime()
end

function Raid:IsLateSpawnCountdownActive()
    return (tonumber(self.LateCountdownEndAt) or 0) > CurTime()
end

function Raid:IsLateSpawnModeActive()
    return self:IsLateSpawnWindowOpen() or self:IsLateSpawnCountdownActive()
end

function Raid:OpenLateSpawnWindow()
    self.LateWindowEndAt = CurTime() + self.Config.LateSpawnWindow
    self.LateCountdownEndAt = 0
    self.LateReadyPlayers = 0
end

function Raid:CancelLateSpawnMode(notifyText)
    local hadLateState = self:IsLateSpawnModeActive()
        or (tonumber(self.LateWindowEndAt) or 0) > 0
        or (tonumber(self.LateCountdownEndAt) or 0) > 0
        or (tonumber(self.LateReadyPlayers) or 0) > 0

    self.LateWindowEndAt = 0
    self.LateCountdownEndAt = 0
    self.LateReadyPlayers = 0

    if hadLateState and notifyText and notifyText ~= "" then
        PrintMessage(HUD_PRINTTALK, notifyText)
    end
end

function Raid:MarkSpawnGroupUsed(groupID)
    groupID = string.Trim(tostring(groupID or ""))
    if groupID == "" then return end
    self.UsedSpawnGroupIDs[groupID] = true
end

function Raid:LockPlayerOutOfCurrentCycle(ply)
    local token = getPlayerToken(ply)
    if token == "" then return end
    self.CycleLockedTokens[token] = true
end

function Raid:ClearCycleLocks()
    self.CycleLockedTokens = {}
end

function Raid:ClearCyclePlayerStates()
    for _, ply in player.Iterator() do
        if IsValid(ply) and (ply.zscav_raid_active or ply:GetNWBool("ZScavRaidActive", false)) then
            self:ClearPlayerState(ply)
        end
    end
end

function Raid:NormalizeEmptyBattlefieldState()
    local battlefieldPlayers = self:GetBattlefieldPlayerCount()
    self.BattlefieldPlayers = battlefieldPlayers

    if battlefieldPlayers > 0 then
        return false
    end

    local hasBattlefieldState = self.BattlefieldLockActive
        or self:IsLateSpawnModeActive()
        or (tonumber(self.BattlefieldCooldownEndAt) or 0) > 0

    if not hasBattlefieldState then
        return false
    end

    self:CancelLateSpawnMode()
    self.BattlefieldLockActive = false
    self.BattlefieldCooldownEndAt = 0
    self.BattlefieldPlayers = 0
    self.CountdownEndAt = 0
    self.PadsArmedAt = CurTime()
    self.NextThinkAt = 0
    self:ClearCyclePlayerStates()
    self:ClearCycleLocks()

    return true
end

function Raid:SyncPlayerExtractList(ply)
    if not IsValid(ply) then return end

    local extracts = istable(ply.zscav_raid_extracts) and ply.zscav_raid_extracts or {}
    local count = math.min(#extracts, 63)

    net.Start("ZScavRaidExtractList")
        net.WriteUInt(count, 6)
        for index = 1, count do
            local extract = extracts[index]
            net.WriteString(getExtractLabel(extract, index))
            net.WriteUInt(normalizeExtractDuration(extract and extract.duration), 8)
        end
    net.Send(ply)
end

function Raid:ClearPlayerExtractHold(ply)
    if not IsValid(ply) then return end

    ply.zscav_raid_extract_hold_id = nil
    ply.zscav_raid_extract_hold_end_at = nil
    ply.zscav_raid_extract_hold_duration = nil
    ply.zscav_raid_extract_hold_label = nil

    ply:SetNWBool("ZScavRaidExtracting", false)
    ply:SetNWFloat("ZScavRaidExtractHoldEnd", 0)
    ply:SetNWFloat("ZScavRaidExtractHoldDuration", 0)
    ply:SetNWString("ZScavRaidExtractHoldLabel", "")
end

function Raid:SetPlayerExtractHold(ply, extract, extractIndex)
    if not IsValid(ply) then return end

    local duration = normalizeExtractDuration(extract and extract.duration)
    local holdEndAt = CurTime() + duration
    local label = getExtractLabel(extract, extractIndex)

    ply.zscav_raid_extract_hold_id = getExtractID(extract, extractIndex)
    ply.zscav_raid_extract_hold_end_at = holdEndAt
    ply.zscav_raid_extract_hold_duration = duration
    ply.zscav_raid_extract_hold_label = label

    ply:SetNWBool("ZScavRaidExtracting", true)
    ply:SetNWFloat("ZScavRaidExtractHoldEnd", holdEndAt)
    ply:SetNWFloat("ZScavRaidExtractHoldDuration", duration)
    ply:SetNWString("ZScavRaidExtractHoldLabel", label)
end

function Raid:ClearPlayerState(ply)
    if not IsValid(ply) then return end

    ply.zscav_raid_active = nil
    ply.zscav_raid_deploy_pending_until = nil
    ply.zscav_raid_safezone_reentry_armed = nil
    ply.zscav_raid_deadline = nil
    ply.zscav_raid_extracts = nil
    ply.zscav_raid_extract_pos = nil
    ply.zscav_raid_extract_label = nil
    ply.zscav_extract_processing = nil
    ply.zscav_safezone_exit_since = nil
    ply.zscav_safezone_exit_bounce_until = nil

    self:ClearPlayerExtractHold(ply)

    ply:SetNWBool("ZScavRaidActive", false)
    ply:SetNWFloat("ZScavRaidDeadline", 0)
    ply:SetNWVector("ZScavRaidExtractPos", VECTOR_ZERO)
    ply:SetNWString("ZScavRaidExtractLabel", "")

    self:SyncPlayerExtractList(ply)
end

function Raid:RemoveRuntimePads()
    for _, pad in ipairs(self.RuntimePads or {}) do
        if IsValid(pad) then
            pad:Remove()
        end
    end

    self.RuntimePads = {}
    self.PadOccupants = {}
end

function Raid:SpawnRuntimePads()
    self:RemoveRuntimePads()

    for index, point in ipairs(getPadPoints()) do
        if not istable(point) or not isvector(point.pos) then continue end

        local pad = ents.Create("ent_zscav_spawnpad")
        if not IsValid(pad) then continue end

        pad:SetPos(point.pos)
        pad:SetAngles(point.ang or Angle(0, tonumber(point.yaw) or 0, 0))
        pad:Spawn()
        pad:Activate()

        pad.zscav_runtime_pad = true
        pad.zscav_pad_index = index
        pad:SetNWInt("ZScavPadIndex", index)
        pad:SetNWInt("ZScavPadCapacity", self.Config.PadCapacity)

        self.RuntimePads[#self.RuntimePads + 1] = pad
    end
end

function Raid:HardReset()
    if ZSCAV and ZSCAV.PersistSafeZoneInventorySnapshot then
        for _, ply in player.Iterator() do
            ZSCAV:PersistSafeZoneInventorySnapshot(ply, {
                allow_inactive = true,
                use_pending_restore = true,
            })
        end
    end

    self.Initialized = false
    self.PadsArmedAt = 0
    self.CountdownEndAt = 0
    self.NextThinkAt = 0
    self.PadOccupants = {}
    self.BattlefieldLockActive = false
    self.BattlefieldCooldownEndAt = 0
    self.BattlefieldPlayers = 0
    self.LateWindowEndAt = 0
    self.LateCountdownEndAt = 0
    self.LateReadyPlayers = 0
    self.UsedSpawnGroupIDs = {}
    self.CycleLockedTokens = {}

    self:RemoveRuntimePads()

    for _, ply in player.Iterator() do
        self:ClearPlayerState(ply)
    end

    clearRaidGlobals()
end

function Raid:OnRoundStart()
    self.Initialized = true
    self.PadsArmedAt = CurTime() + self.Config.ArmDelay
    self.CountdownEndAt = 0
    self.PadOccupants = {}
    self.NextThinkAt = 0
    self.BattlefieldLockActive = false
    self.BattlefieldCooldownEndAt = 0
    self.BattlefieldPlayers = 0
    self.LateWindowEndAt = 0
    self.LateCountdownEndAt = 0
    self.LateReadyPlayers = 0
    self.UsedSpawnGroupIDs = {}
    self.CycleLockedTokens = {}

    self:SpawnRuntimePads()

    for _, ply in player.Iterator() do
        self:ClearPlayerState(ply)
    end

    self:SyncGlobals(0)
end

function Raid:ArePadsAvailable()
    if not (self.Initialized and isRaidRoundLive()) then return false end
    if self.BattlefieldLockActive then return false end
    return CurTime() >= (self.PadsArmedAt or 0)
end

function Raid:GetBattlefieldPlayerCount()
    local count = 0

    for _, ply in player.Iterator() do
        if not (IsValid(ply) and ply:Alive() and ply.zscav_raid_active) then continue end

        local pendingDeployUntil = tonumber(ply.zscav_raid_deploy_pending_until) or 0
        local inSafeZone = isPlayerInSafeZone(ply)
        if not inSafeZone then
            ply.zscav_raid_safezone_reentry_armed = true
        end

        if pendingDeployUntil > CurTime() or not ply.zscav_raid_safezone_reentry_armed or not inSafeZone then
            count = count + 1
        end
    end

    return count
end

function Raid:UpdateBattlefieldLock()
    if not self.BattlefieldLockActive then
        self.BattlefieldPlayers = 0
        return 0
    end

    local battlefieldPlayers = self:GetBattlefieldPlayerCount()
    self.BattlefieldPlayers = battlefieldPlayers

    if self:IsLateSpawnModeActive() then
        if battlefieldPlayers <= 0 then
            self:CancelLateSpawnMode("[ZScav] Late deployment cancelled. Battlefield clear detected; raid pads are re-arming.")
        else
            self.BattlefieldCooldownEndAt = 0
            self.PadsArmedAt = 0
            return battlefieldPlayers
        end
    end

    if battlefieldPlayers > 0 then
        self.BattlefieldCooldownEndAt = 0
        self.PadsArmedAt = 0
        return battlefieldPlayers
    end

    if next(self.UsedSpawnGroupIDs or {}) == nil then
        self.BattlefieldLockActive = false
        self.BattlefieldCooldownEndAt = 0
        self.PadsArmedAt = CurTime()
        self.BattlefieldPlayers = 0
        self:ClearCyclePlayerStates()
        self:ClearCycleLocks()
        return 0
    end

    if (self.BattlefieldCooldownEndAt or 0) <= 0 then
        self.BattlefieldCooldownEndAt = CurTime() + self.Config.RearmDelay
        self.PadsArmedAt = self.BattlefieldCooldownEndAt
        PrintMessage(HUD_PRINTTALK, string.format(
            "[ZScav] Battlefield clear. Raid pads re-arm in %d minutes.",
            math.max(math.floor(self.Config.RearmDelay / 60), 1)
        ))
        return 0
    end

    if CurTime() >= self.BattlefieldCooldownEndAt then
        self.BattlefieldLockActive = false
        self.BattlefieldCooldownEndAt = 0
        self.PadsArmedAt = CurTime()
        self:ClearCyclePlayerStates()
        self:ClearCycleLocks()
        PrintMessage(HUD_PRINTTALK, "[ZScav] Raid pads are available again.")
    else
        self.PadsArmedAt = self.BattlefieldCooldownEndAt
    end

    return 0
end

function Raid:IsDeploymentAreaClear(positions)
    local radiusSqr = math.max(tonumber(self.Config.LateSpawnSafeRadius) or 600, 1)
    radiusSqr = radiusSqr * radiusSqr

    for _, ply in player.Iterator() do
        if not (IsValid(ply) and ply:Alive()) then continue end
        if isPlayerInSafeZone(ply) then continue end

        local playerPos = ply:GetPos()
        for _, point in ipairs(positions or {}) do
            if istable(point) and isvector(point.pos) and playerPos:DistToSqr(point.pos) <= radiusSqr then
                return false
            end
        end
    end

    return true
end

function Raid:PickLateDeployment(teamSize, reservedGroupIDs)
    teamSize = math.max(1, math.floor(tonumber(teamSize) or 1))

    local groups = getSpawnGroups()
    local pool = {}
    reservedGroupIDs = istable(reservedGroupIDs) and reservedGroupIDs or {}

    for index, group in ipairs(groups) do
        if not istable(group) then continue end

        local groupID = string.Trim(tostring(group.id or ""))
        if groupID == "" then continue end
        if self.UsedSpawnGroupIDs[groupID] or reservedGroupIDs[groupID] then continue end

        local expanded = ZScavSpawnPoints and ZScavSpawnPoints.ExpandGroup and ZScavSpawnPoints.ExpandGroup(group) or {}
        if #expanded <= 0 then continue end
        if not self:IsDeploymentAreaClear(expanded) then continue end

        local positions = {}
        for memberIndex = 1, teamSize do
            positions[memberIndex] = expanded[((memberIndex - 1) % #expanded) + 1]
        end

        pool[#pool + 1] = {
            group = group,
            groupIndex = index,
            groupID = groupID,
            positions = positions,
        }
    end

    if #pool <= 0 then return nil end
    return pool[math.random(#pool)]
end

function Raid:DeployMembers(members, deployment, deployed)
    local spawnPositions = istable(deployment) and istable(deployment.positions) and deployment.positions or {}
    if #spawnPositions <= 0 then return false end

    local extracts = self:GetDeploymentExtracts(deployment)
    if #extracts <= 0 then
        for _, ply in ipairs(members or {}) do
            noticePlayer(ply, "No compatible ZScav extract is configured for this spawn group.")
        end
        return false
    end

    local deployedAny = false
    for index, ply in ipairs(members or {}) do
        if not (IsValid(ply) and ply:Alive()) then continue end

        local spawnPoint = spawnPositions[((index - 1) % #spawnPositions) + 1]
        if not (istable(spawnPoint) and isvector(spawnPoint.pos)) then continue end

        local deadline = CurTime() + self.Config.RaidDuration
        deployed[#deployed + 1] = ply
        deployedAny = true

        if ZSCAV and ZSCAV.ClearSafeZoneInventorySnapshots then
            ZSCAV:ClearSafeZoneInventorySnapshots(ply)
        end

        self:LockPlayerOutOfCurrentCycle(ply)
        self:ClearPlayerExtractHold(ply)
        ply.zscav_raid_active = true
        ply.zscav_raid_deploy_pending_until = CurTime() + 2
        ply.zscav_raid_safezone_reentry_armed = false
        ply.zscav_raid_deadline = deadline
        ply.zscav_raid_extracts = table.Copy(extracts)
        ply.zscav_raid_extract_pos = nil
        ply.zscav_raid_extract_label = nil
        ply:SetNWBool("ZScavRaidActive", true)
        ply:SetNWFloat("ZScavRaidDeadline", deadline)
        ply:SetNWVector("ZScavRaidExtractPos", VECTOR_ZERO)
        ply:SetNWString("ZScavRaidExtractLabel", "")
        self:SyncPlayerExtractList(ply)
        noticePlayer(ply, "Available extracts: " .. buildExtractNameSummary(extracts) .. ".")

        net.Start("ZScavRaidIntro")
        net.Send(ply)

        timer.Simple(0.5, function()
            if not (IsValid(ply) and ply:Alive() and ZSCAV:IsActive() and ply.zscav_raid_active) then return end
            ply.zscav_raid_deploy_pending_until = nil
            ply:SetPos(spawnPoint.pos + Vector(0, 0, 8))
            ply:SetEyeAngles(Angle(0, tonumber(spawnPoint.yaw) or 0, 0))
            ply:SetVelocity(-ply:GetVelocity())
        end)
    end

    if deployedAny then
        self:MarkSpawnGroupUsed(deployment.groupID)
    end

    return deployedAny
end

local function buildExtractCenter(positions)
    local center = VECTOR_ZERO
    local count = 0

    for _, entry in ipairs(positions or {}) do
        if istable(entry) and isvector(entry.pos) then
            center = center + entry.pos
            count = count + 1
        end
    end

    if count <= 0 then return nil end
    return center / count
end

local function buildRankedExtractPool(center, rawPoints)
    local ranked = {}

    for index, point in ipairs(rawPoints or {}) do
        if not (istable(point) and isvector(point.pos)) then continue end

        ranked[#ranked + 1] = {
            index = index,
            id = getExtractID(point, index),
            pos = point.pos,
            ang = point.ang or Angle(0, tonumber(point.yaw) or 0, 0),
            label = getExtractLabel(point, index),
            duration = normalizeExtractDuration(point.duration),
            dist = center:DistToSqr(point.pos),
        }
    end

    table.sort(ranked, function(left, right)
        return left.dist > right.dist
    end)

    return ranked
end

local function buildExtractListFromRankedPool(ranked)
    local extracts = {}
    local seen = {}

    for _, extract in ipairs(ranked or {}) do
        local extractID = tostring(extract.id or "")
        if extractID ~= "" and seen[extractID] then
            continue
        end

        if extractID ~= "" then
            seen[extractID] = true
        end

        extracts[#extracts + 1] = {
            id = extractID,
            pos = extract.pos,
            ang = extract.ang,
            label = extract.label,
            duration = extract.duration,
        }
    end

    return extracts
end

function Raid:GetDeploymentExtracts(deployment)
    local positions = istable(deployment) and deployment.positions or deployment
    local center = buildExtractCenter(positions)
    if not isvector(center) then return {} end

    local groupID = string.Trim(tostring(istable(deployment) and deployment.groupID or ""))
    local linkedNamed = {}
    local globalNamed = {}

    for _, extract in ipairs(getNamedExtracts()) do
        local refs = istable(extract.groups) and extract.groups or {}
        if #refs <= 0 then
            globalNamed[#globalNamed + 1] = extract
        elseif groupID ~= "" then
            for _, ref in ipairs(refs) do
                if tostring(ref) == groupID then
                    linkedNamed[#linkedNamed + 1] = extract
                    break
                end
            end
        end
    end

    local ranked = buildRankedExtractPool(center, #linkedNamed > 0 and linkedNamed or globalNamed)
    if #ranked > 0 then
        return buildExtractListFromRankedPool(ranked)
    end

    return buildExtractListFromRankedPool(buildRankedExtractPool(center, getExtractPoints()))
end

function Raid:UpdatePadOccupants()
    local pads = getManagedPads()
    local armed = self:ArePadsAvailable()
    local lateWindowOpen = self:IsLateSpawnWindowOpen()
    local lateCountdownActive = self:IsLateSpawnCountdownActive()
    local queueAcceptingNew = armed or lateWindowOpen
    local preserveExisting = queueAcceptingNew or lateCountdownActive
    local totalReady = 0
    local nextOccupants = {}

    for _, pad in ipairs(pads) do
        if not IsValid(pad) then continue end

        local existing = self.PadOccupants[pad] or {}
        local candidates = {}
        local candidateTokens = {}

        if isfunction(pad.GetOccupants) then
            for _, ply in ipairs(pad:GetOccupants() or {}) do
                local token = getPlayerToken(ply)
                if token ~= "" and not candidateTokens[token] and isPlayerEligibleForPad(ply, pad) then
                    candidateTokens[token] = true
                    candidates[#candidates + 1] = ply
                end
            end
        end

        local members = {}
        local memberTokens = {}

        if preserveExisting then
            for _, ply in ipairs(existing) do
                local token = getPlayerToken(ply)
                if token ~= "" and candidateTokens[token] and not memberTokens[token] then
                    memberTokens[token] = true
                    members[#members + 1] = ply
                end
            end
        end

        if queueAcceptingNew then
            for _, ply in ipairs(candidates) do
                if #members >= self.Config.PadCapacity then break end

                local token = getPlayerToken(ply)
                if token ~= "" and not memberTokens[token] then
                    memberTokens[token] = true
                    members[#members + 1] = ply
                end
            end

            if #members >= self.Config.PadCapacity then
                for _, ply in ipairs(candidates) do
                    local token = getPlayerToken(ply)
                    if token ~= "" and not memberTokens[token] then
                        pushPlayerOffPad(ply, pad)
                    end
                end
            end
        end

        nextOccupants[pad] = members
        totalReady = totalReady + #members

        pad:SetNWInt("ZScavPadOccupants", #members)
        pad:SetNWBool("ZScavPadArmed", queueAcceptingNew or lateCountdownActive)
        pad:SetNWBool("ZScavPadFull", #members >= self.Config.PadCapacity)
        pad:SetNWFloat("ZScavPadCountdownEnd", math.max(self.CountdownEndAt or 0, self.LateCountdownEndAt or 0))
    end

    self.PadOccupants = nextOccupants
    self.LateReadyPlayers = self:IsLateSpawnModeActive() and totalReady or 0
    return totalReady
end

function Raid:LaunchCurrentOccupants(forceStart)
    local deployed = {}

    for pad, members in pairs(self.PadOccupants or {}) do
        if not IsValid(pad) or #members <= 0 then continue end

        local deployment = ZScavSpawnPoints and ZScavSpawnPoints.RandomGroupDeployment
            and ZScavSpawnPoints.RandomGroupDeployment(#members) or nil
        local spawnPositions = istable(deployment) and istable(deployment.positions) and deployment.positions
            or (ZScavSpawnPoints and ZScavSpawnPoints.RandomGroupPositions and ZScavSpawnPoints.RandomGroupPositions(#members) or {})

        if not istable(deployment) then
            deployment = { positions = spawnPositions }
        end

        if #spawnPositions == 0 then
            for _, ply in ipairs(members) do
                noticePlayer(ply, "No ZScav spawn groups are placed on this map.")
            end
            continue
        end

        self:DeployMembers(members, deployment, deployed)

        pad:SetNWInt("ZScavPadOccupants", 0)
        pad:SetNWBool("ZScavPadFull", false)
        pad:SetNWFloat("ZScavPadCountdownEnd", 0)
    end

    self.PadOccupants = {}
    self.CountdownEndAt = 0
    self.LateCountdownEndAt = 0
    self.LateReadyPlayers = 0

    if #deployed > 0 or forceStart == true then
        self.BattlefieldLockActive = true
        self.BattlefieldCooldownEndAt = 0
        self.PadsArmedAt = 0
        self.BattlefieldPlayers = #deployed
        self:OpenLateSpawnWindow()
        if #deployed > 0 then
            hook.Run("ZScav_RaidStart", deployed)
        end
    end

    self:SyncGlobals(0)
end

function Raid:LaunchLateOccupants()
    local deployed = {}
    local reservedGroupIDs = {}

    for pad, members in pairs(self.PadOccupants or {}) do
        if not IsValid(pad) or #members <= 0 then continue end

        local deployment = self:PickLateDeployment(#members, reservedGroupIDs)
        if not deployment then
            for _, ply in ipairs(members) do
                noticePlayer(ply, "No unused late-spawn group is clear within the 600 unit safety radius.")
            end
            continue
        end

        reservedGroupIDs[deployment.groupID] = true
        self:DeployMembers(members, deployment, deployed)

        pad:SetNWInt("ZScavPadOccupants", 0)
        pad:SetNWBool("ZScavPadFull", false)
        pad:SetNWFloat("ZScavPadCountdownEnd", 0)
    end

    self.PadOccupants = {}
    self.LateCountdownEndAt = 0
    self.LateReadyPlayers = 0

    if CurTime() >= (self.LateWindowEndAt or 0) then
        self.LateWindowEndAt = 0
    end

    if #deployed > 0 then
        self.BattlefieldPlayers = self:GetBattlefieldPlayerCount()
    end

    self:SyncGlobals(0)
end

function Raid:UpdateCountdown(readyCount)
    local armed = self:ArePadsAvailable()

    if not armed then
        self.CountdownEndAt = 0
        return
    end

    if readyCount < self.Config.MinPlayers then
        if (self.CountdownEndAt or 0) > 0 then
            self.CountdownEndAt = 0
            PrintMessage(HUD_PRINTTALK, "[ZScav] Raid launch countdown cancelled.")
        end
        return
    end

    if (self.CountdownEndAt or 0) <= 0 then
        self.CountdownEndAt = CurTime() + self.Config.Countdown
        PrintMessage(HUD_PRINTTALK, string.format(
            "[ZScav] %d players are ready. Raid launch in %d seconds.",
            readyCount,
            self.Config.Countdown
        ))
        return
    end

    if CurTime() >= self.CountdownEndAt then
        self:LaunchCurrentOccupants()
    end
end

function Raid:UpdateLateCountdown(readyCount)
    local lateWindowOpen = self:IsLateSpawnWindowOpen()
    local lateCountdownActive = self:IsLateSpawnCountdownActive()

    if not (lateWindowOpen or lateCountdownActive) then
        self.LateReadyPlayers = 0
        self.LateCountdownEndAt = 0
        return
    end

    self.LateReadyPlayers = math.max(tonumber(readyCount) or 0, 0)

    if readyCount <= 0 then
        if lateCountdownActive then
            self.LateCountdownEndAt = 0
            PrintMessage(HUD_PRINTTALK, "[ZScav] Late deployment countdown cancelled.")
        end

        if not lateWindowOpen then
            self.LateWindowEndAt = 0
        end
        return
    end

    if (self.LateCountdownEndAt or 0) <= 0 then
        self.LateCountdownEndAt = CurTime() + self.Config.LateSpawnCountdown
        PrintMessage(HUD_PRINTTALK, string.format(
            "[ZScav] Late deployment in %d seconds for %d queued player%s.",
            self.Config.LateSpawnCountdown,
            readyCount,
            readyCount == 1 and "" or "s"
        ))
        return
    end

    if CurTime() >= self.LateCountdownEndAt then
        self:LaunchLateOccupants()
    end
end

function Raid:ForceStart(requester)
    if not isRaidRoundLive() then
        noticePlayer(requester, "ZScav raid force start only works during a live ZScav round.")
        return false
    end

    if not self.Initialized then
        self:OnRoundStart()
    end

    local recoveredIdleState = self:NormalizeEmptyBattlefieldState()
    local readyCount = self:UpdatePadOccupants()

    if readyCount <= 0 then
        self.PadsArmedAt = CurTime()
        self.CountdownEndAt = 0
        self:SyncGlobals(0)

        noticePlayer(requester, recoveredIdleState
            and "No players were queued on raid pads. Cleared the empty raid-cycle lock and armed the pads immediately."
            or "No players were queued on raid pads. Raid pads were armed immediately instead of starting an empty raid.")
        return true
    end

    self.CountdownEndAt = 0
    self:LaunchCurrentOccupants()

    noticePlayer(requester, string.format(
        "Forced raid start. %d queued player%s launched; late deployment remains open for %d minutes.",
        readyCount,
        readyCount == 1 and "" or "s",
        math.max(math.floor(self.Config.LateSpawnWindow / 60), 1)
    ))

    return true
end

function Raid:ForceReadyPads(requester)
    if not isRaidRoundLive() then
        noticePlayer(requester, "ZScav pad force ready only works during a live ZScav round.")
        return false
    end

    if not self.Initialized then
        self:OnRoundStart()
    end

    local recoveredIdleState = self:NormalizeEmptyBattlefieldState()
    local readyCount = self:UpdatePadOccupants()

    if self.BattlefieldLockActive or self:IsLateSpawnModeActive() then
        noticePlayer(requester, "Raid pads cannot be force-readied after the raid has started.")
        return false
    end

    if self:ArePadsAvailable() then
        noticePlayer(requester, recoveredIdleState
            and "Battlefield was empty. Cleared the stale raid-cycle lock; raid pads are already armed."
            or "Raid pads are already armed.")
        return true
    end

    self.PadsArmedAt = CurTime()
    self:SyncGlobals(readyCount)

    noticePlayer(requester, recoveredIdleState
        and "Battlefield was empty. Cleared the stale raid-cycle lock and armed the raid pads immediately."
        or string.format(
            "Raid pads armed immediately. Launch countdown stays at %d seconds once enough players are ready.",
            self.Config.Countdown
        ))

    PrintMessage(HUD_PRINTTALK, recoveredIdleState
        and "[ZScav] Staff cleared an empty raid-cycle lock. Raid pads are ready again."
        or "[ZScav] Staff bypassed the pad arm timer. Raid pads are now ready.")

    return true
end

function Raid:SendLateJoinerToSafeZone(target, requester)
    if not IsValid(target) then
        noticePlayer(requester, "Late-join safe-zone target is invalid.")
        return false
    end

    if not ZSCAV:IsActive() then
        noticePlayer(requester or target, "Late join to safe zone is only available while ZScav is active.")
        return false
    end

    if target.zscav_raid_active then
        noticePlayer(requester or target, string.format("%s is already deployed in a raid.", tostring(target:Nick() or "That player")))
        return false
    end

    self:ClearPlayerState(target)
    if isRaidRoundLive() then
        self:LockPlayerOutOfCurrentCycle(target)
    end

    local ok, reason = ZSCAV:SendPlayerToSafeZone(target)
    if not ok then
        if reason == "missing_safe_spawn" then
            noticePlayer(requester or target, "No ZSCAV_SAFESPAWN, SAFE_SPAWN, or Spawnpoint points are configured.")
        else
            noticePlayer(requester or target, "Could not move that player to the ZScav safe zone.")
        end
        return false
    end

    target.zscav_raid_join_hint_sent = true
    if requester ~= target then
        noticePlayer(requester, string.format("Sent %s to the ZScav safe zone.", tostring(target:Nick() or "player")))
    end
    noticePlayer(target, isRaidRoundLive()
        and "You were sent to the ZScav safe zone lobby and locked out of the current raid cycle."
        or "You were sent to the ZScav safe zone.")

    return true
end

function Raid:FindPlayerExtractZone(ply)
    if not (IsValid(ply) and ply:Alive()) then return nil end

    local extracts = istable(ply.zscav_raid_extracts) and ply.zscav_raid_extracts or {}
    local bestExtract
    local bestIndex
    local bestDist
    local maxDist = self.Config.ExtractRadius * self.Config.ExtractRadius

    for index, extract in ipairs(extracts) do
        if not (istable(extract) and isvector(extract.pos)) then continue end

        local dist = ply:GetPos():DistToSqr(extract.pos)
        if dist <= maxDist and (not bestDist or dist < bestDist) then
            bestDist = dist
            bestExtract = extract
            bestIndex = index
        end
    end

    return bestExtract, bestIndex
end

function Raid:HandleExtraction(ply, extract, extractIndex)
    if not (IsValid(ply) and ply:Alive() and ply.zscav_raid_active) then return false end
    if (ply.zscav_extract_processing or 0) > CurTime() then return false end

    ply.zscav_extract_processing = CurTime() + 1

    local inv = ZSCAV and ZSCAV.GetInventory and ZSCAV:GetInventory(ply) or ply.zscav_inv
    local snapshot = ZSCAV and ZSCAV.BuildSafeZoneInventorySnapshot and ZSCAV:BuildSafeZoneInventorySnapshot(inv) or nil
    if not snapshot then
        noticePlayer(ply, "Could not preserve raid inventory for safe-zone return.")
        return false
    end

    if not (ZSCAV and ZSCAV.QueueSafeZoneInventoryRestore and ZSCAV:QueueSafeZoneInventoryRestore(ply, snapshot, {
        source = "raid_extract",
    })) then
        noticePlayer(ply, "Could not queue raid inventory restore.")
        return false
    end

    if not ZSCAV:QueueSafeSpawn(ply) then
        ply.zscav_safezone_inventory_restore_pending = nil
        noticePlayer(ply, "Could not queue a safe-zone spawn after extraction.")
        return false
    end

    local label = getExtractLabel(extract, extractIndex)

    local flushSecure = ZSCAV.ServerHelpers and ZSCAV.ServerHelpers.FlushSecurePersistence
    if isfunction(flushSecure) then
        flushSecure(ply)
    end

    self:ClearPlayerState(ply)

    noticePlayer(ply, string.format("Extracted at %s. Returned to safe zone with your raid gear.", label))

    timer.Simple(0, function()
        if IsValid(ply) then
            ply:Spawn()
        end
    end)

    return true
end

function Raid:UpdateActiveRaids()
    for _, ply in player.Iterator() do
        if not (IsValid(ply) and ply.zscav_raid_active) then continue end

        local deadline = tonumber(ply.zscav_raid_deadline) or 0
        if deadline > 0 and CurTime() >= deadline then
            noticePlayer(ply, "Raid time expired.")
            self:LockPlayerOutOfCurrentCycle(ply)
            self:ClearPlayerState(ply)
            if ply:Alive() then
                ply:Kill()
            end
            continue
        end

        local pendingDeployUntil = tonumber(ply.zscav_raid_deploy_pending_until) or 0
        local inSafeZone = isPlayerInSafeZone(ply)
        if not inSafeZone then
            ply.zscav_raid_safezone_reentry_armed = true
        end

        if pendingDeployUntil > CurTime() then
            self:ClearPlayerExtractHold(ply)
            continue
        end

        if inSafeZone and not ply.zscav_raid_safezone_reentry_armed then
            self:ClearPlayerExtractHold(ply)
            continue
        end

        if inSafeZone then
            local inv = ZSCAV and ZSCAV.GetInventory and ZSCAV:GetInventory(ply) or ply.zscav_inv
            local snapshot = ZSCAV and ZSCAV.BuildSafeZoneInventorySnapshot and ZSCAV:BuildSafeZoneInventorySnapshot(inv) or nil
            if snapshot
                and ZSCAV
                and ZSCAV.QueueSafeZoneInventoryRestore
                and ZSCAV:QueueSafeZoneInventoryRestore(ply, snapshot, {
                    source = "raid_safezone_return",
                })
                and ZSCAV:QueueSafeSpawn(ply) then
                local flushSecure = ZSCAV.ServerHelpers and ZSCAV.ServerHelpers.FlushSecurePersistence
                if isfunction(flushSecure) then
                    flushSecure(ply)
                end

                self:ClearPlayerState(ply)
                noticePlayer(ply, "Raid ended when you re-entered the safe zone. Your raid gear stayed equipped.")

                timer.Simple(0, function()
                    if IsValid(ply) then
                        ply:Spawn()
                    end
                end)

                continue
            end
        end

        local extract, extractIndex = self:FindPlayerExtractZone(ply)
        if not extract then
            self:ClearPlayerExtractHold(ply)
            continue
        end

        local extractID = getExtractID(extract, extractIndex)
        local holdID = tostring(ply.zscav_raid_extract_hold_id or "")
        local holdEndAt = tonumber(ply.zscav_raid_extract_hold_end_at) or 0

        if holdID ~= extractID or holdEndAt <= 0 then
            self:SetPlayerExtractHold(ply, extract, extractIndex)
        elseif CurTime() >= holdEndAt then
            self:HandleExtraction(ply, extract, extractIndex)
        end
    end
end

function Raid:Think()
    if not isRaidRoundLive() then
        if self.Initialized or #self.RuntimePads > 0 then
            self:HardReset()
        end
        return
    end

    if not self.Initialized then
        self:OnRoundStart()
    end

    if self.NextThinkAt > CurTime() then return end
    self.NextThinkAt = CurTime() + 0.2

    self:UpdateActiveRaids()
    self:UpdateBattlefieldLock()
    local readyCount = self:UpdatePadOccupants()
    for _, ply in player.Iterator() do
        enforceSafeZoneLobbyBoundary(ply)
    end
    if self:IsLateSpawnModeActive() then
        self:UpdateLateCountdown(readyCount)
    else
        self:UpdateCountdown(readyCount)
    end
    self:SyncGlobals(readyCount)
end

hook.Add("ZB_StartRound", "ZSCAV_RaidRoundStart", function()
    if not ZSCAV:IsActive() then return end
    Raid:OnRoundStart()
end)

hook.Add("ZB_PreRoundStart", "ZSCAV_RaidPreRoundReset", function()
    Raid:HardReset()
end)

hook.Add("Think", "ZSCAV_RaidThink", function()
    Raid:Think()
end)

hook.Add("PlayerDeath", "ZSCAV_RaidClearOnDeath", function(ply)
    if IsValid(ply) and ply.zscav_raid_active then
        Raid:LockPlayerOutOfCurrentCycle(ply)
    end
    Raid:ClearPlayerState(ply)
end)

hook.Add("PlayerDisconnected", "ZSCAV_RaidClearOnLeave", function(ply)
    Raid:ClearPlayerState(ply)
end)

hook.Add("InitPostEntity", "ZSCAV_RaidBootPads", function()
    clearRaidGlobals()
end)

hook.Add("PlayerInitialSpawn", "ZSCAV_LateJoinSafeZoneHint", function(ply)
    timer.Simple(7, function()
        if not IsValid(ply) then return end
        if not isRaidRoundLive() then return end
        if ply.zscav_raid_join_hint_sent then return end
        if ply.zscav_raid_active then return end
        if ply:Alive() and ply:Team() ~= TEAM_SPECTATOR then return end

        ply.zscav_raid_join_hint_sent = true
        sendLateJoinSpawnClientHint(ply)
        ply:ChatPrint("[ZScav] A raid is already in progress. Type !join in chat to spawn at ZSCAV_SAFESPAWN and wait in the safe zone.")
        if ply:Team() == TEAM_SPECTATOR then
            ply:ChatPrint("[ZScav] You can stay spectating, then use !join when you want to enter the safe zone lobby.")
        end
    end)
end)

hook.Add("HG_PlayerSay", "ZSCAV_LateJoinChat", function(ply, txtTbl, text)
    local cmd = string.lower(string.Trim(text or ""))
    if cmd ~= "!join" and cmd ~= "/join" and cmd ~= "!latejoin" and cmd ~= "/latejoin"
        and cmd ~= "!zscavjoin" and cmd ~= "/zscavjoin" then
        return
    end

    txtTbl[1] = ""

    if not ZSCAV:IsActive() then
        noticePlayer(ply, "!join is only available while ZScav is active.")
        return ""
    end

    if ply.zscav_raid_active then
        noticePlayer(ply, "You are already deployed in a raid.")
        return ""
    end

    Raid:SendLateJoinerToSafeZone(ply, ply)
    return ""
end)

concommand.Add("zscav_raid_force_start", function(ply)
    if IsValid(ply) and not (ply:IsAdmin() or ply:IsSuperAdmin()) then return end
    Raid:ForceStart(ply)
end)

concommand.Add("zscav_raid_force_ready", function(ply)
    if IsValid(ply) and not (ply:IsAdmin() or ply:IsSuperAdmin()) then return end
    Raid:ForceReadyPads(ply)
end)

concommand.Add("zscav_late_join", function(ply, _cmd, args)
    if IsValid(ply) and not (ply:IsAdmin() or ply:IsSuperAdmin()) then
        Raid:SendLateJoinerToSafeZone(ply, ply)
        return
    end

    local targetArg = tostring(args[1] or "")
    if targetArg == "" then
        if IsValid(ply) then
            noticePlayer(ply, "Usage: zscav_late_join <player|me|all>")
        else
            print("[ZScav] Usage: zscav_late_join <player|me|all>")
        end
        return
    end

    local target = resolveLateJoinTarget(ply, targetArg)
    if target == "all" then
        local moved = 0
        for _, candidate in player.Iterator() do
            if Raid:SendLateJoinerToSafeZone(candidate, ply) then
                moved = moved + 1
            end
        end
        if IsValid(ply) then
            noticePlayer(ply, string.format("Late-join safe-zone command processed %d player%s.", moved, moved == 1 and "" or "s"))
        else
            print(string.format("[ZScav] Late-join safe-zone command processed %d player%s.", moved, moved == 1 and "" or "s"))
        end
        return
    end

    if not IsValid(target) then
        if IsValid(ply) then
            noticePlayer(ply, "Player not found for zscav_late_join.")
        else
            print("[ZScav] Player not found for zscav_late_join.")
        end
        return
    end

    Raid:SendLateJoinerToSafeZone(target, ply)
end)