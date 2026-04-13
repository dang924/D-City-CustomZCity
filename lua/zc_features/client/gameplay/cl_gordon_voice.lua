if SERVER then return end

local MUFFLE_VOLUME_MAX = 0.24
local MUFFLE_VOLUME_MIN = 0.07
local GATE_RATE = 13
local THINK_INTERVAL = 0.05
local OCCLUSION_CACHE_INTERVAL = 0.12

local talkState = {}
local nextThink = 0

local function GetUserVoiceVolume(ply)
    if hg and hg.playerInfo and hg.playerInfo[ply:SteamID()] then
        local info = hg.playerInfo[ply:SteamID()]
        if istable(info) and tonumber(info[2]) then
            return math.Clamp(tonumber(info[2]), 0, 1)
        end
    end

    return 1
end

local function GetOcclusionVolume(listener, talker)
    if talker:WaterLevel() == 3 then return 0.25 end

    local trace = util.TraceLine({
        start = listener:EyePos(),
        endpos = talker:EyePos(),
        mask = MASK_SOLID_BRUSHONLY,
    })

    return trace.Hit and 0.5 or 1
end

hook.Add("Think", "ZC_GordonVoice_MuffleFallback", function()
    local now = CurTime()
    if now < nextThink then return end
    nextThink = now + THINK_INTERVAL

    local listener = LocalPlayer()
    if not IsValid(listener) then return end

    if not GetGlobalBool("ZC_GordonTalkEnabled", true) then
        table.Empty(talkState)
        return
    end

    for _, talker in ipairs(player.GetHumans()) do
        if not IsValid(talker) or talker == listener then continue end
        local muffled = talker:GetNWBool("ZC_GordonHelmetMuffled", false)
        local speaking = talker:IsSpeaking()

        if not muffled or not speaking then
            talkState[talker] = nil
            continue
        end

        local state = talkState[talker]
        if not state then
            state = {}
            talkState[talker] = state
        end

        local base = GetUserVoiceVolume(talker)
        if (state.nextOccCheck or 0) <= now then
            state.occlusion = GetOcclusionVolume(listener, talker)
            state.nextOccCheck = now + OCCLUSION_CACHE_INTERVAL
        end
        local occlusion = state.occlusion or 1

        -- Aggressive gate to emulate helmet comms with weak mic pickup.
        local gate = 0.5 + 0.5 * math.sin(CurTime() * GATE_RATE + talker:EntIndex() * 0.37)
        gate = gate * gate
        local muffledCap = Lerp(gate, MUFFLE_VOLUME_MIN, MUFFLE_VOLUME_MAX)
        local volume = math.min(base, occlusion, muffledCap)

        if hg and hg.muteall then
            volume = 0
        elseif hg and hg.mutespect and not talker:Alive() then
            volume = 0
        end

        talker:SetVoiceVolumeScale(volume)
    end
end)

hook.Add("PlayerEndVoice", "ZC_GordonVoice_ClearTalkState", function(ply)
    if not IsValid(ply) then return end
    talkState[ply] = nil
end)
