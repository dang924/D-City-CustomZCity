-- sv_npc_manager.lua — Server side of the NPC Manager panel.
-- Provides staff with godmode, teleport, sequence browser, and scripted
-- sequence status for every active NPC on the map.
--
-- ULX: !npcmanager  (admin+)

if CLIENT then return end

-- ── AI state tracking ─────────────────────────────────────────────────────────
-- ai_disable is FCVAR_CHEAT and unusable in multiplayer without sv_cheats.
-- Per-NPC freezing doesn't work either: ZCity NPCs target homigrad npc_bullseye
-- proxies parented to players, so schedule overrides don't stop them attacking.
-- The AI toggle in the NPC Manager panel tracks state for the UI only.

ZC_NPCManager_AIEnabled = ZC_NPCManager_AIEnabled ~= false  -- default: true

local function GetAIEnabled()
    return ZC_NPCManager_AIEnabled
end

local function SetAIEnabled(enabled)
    ZC_NPCManager_AIEnabled = enabled
end

-- ── Godmode registry ──────────────────────────────────────────────────────────
-- Keyed by entity index. Cleared when the entity is removed.

ZC_NPC_Godmode = ZC_NPC_Godmode or {}

hook.Add("EntityTakeDamage", "ZC_NPCManager_Godmode", function(ent, dmgInfo)
    if not IsValid(ent) or not ent:IsNPC() then return end
    if ZC_NPC_Godmode[ent:EntIndex()] then return true end
end)

hook.Add("EntityRemoved", "ZC_NPCManager_GodmodeCleanup", function(ent)
    if not IsValid(ent) then return end
    ZC_NPC_Godmode[ent:EntIndex()] = nil
end)

-- ── Network strings ───────────────────────────────────────────────────────────

util.AddNetworkString("ZC_NPCManager_Open")
util.AddNetworkString("ZC_NPCManager_NPCList")
util.AddNetworkString("ZC_NPCManager_SequenceList")
util.AddNetworkString("ZC_NPCManager_Action")
util.AddNetworkString("ZC_NPCManager_Feedback")
util.AddNetworkString("ZC_NPCManager_SeqTargets")  -- all scripted_sequence target names on this map
util.AddNetworkString("ZC_NPCManager_AIState")     -- server → client: current AI enabled state

-- ── NPC state helpers ─────────────────────────────────────────────────────────

local NPC_STATE_NAMES = {
    [NPC_STATE_NONE]    = "None",
    [NPC_STATE_IDLE]    = "Idle",
    [NPC_STATE_ALERT]   = "Alert",
    [NPC_STATE_COMBAT]  = "Combat",
    [NPC_STATE_SCRIPT]  = "Scripted",
    [NPC_STATE_PLAYDEAD]= "PlayDead",
    [NPC_STATE_PRONE]   = "Prone",
    [NPC_STATE_DEAD]    = "Dead",
}

local function GetScriptedSeqName(npc)
    -- Find any scripted_sequence entity whose target matches this NPC's name
    if not IsValid(npc) then return "" end
    local npcName = npc:GetName()
    if not npcName or npcName == "" then return "" end
    for _, ss in ipairs(ents.FindByClass("scripted_sequence")) do
        if IsValid(ss) then
            local target = ss:GetInternalVariable("m_iszEntity") or ""
            if target == npcName then
                return ss:GetName() ~= "" and ss:GetName() or "(unnamed scripted_sequence)"
            end
        end
    end
    return ""
end

-- ── Send NPC list ─────────────────────────────────────────────────────────────

local function SendNPCList(admin)
    local npcs = {}
    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) or not ent:IsNPC() then continue end
        table.insert(npcs, ent)
    end

    net.Start("ZC_NPCManager_NPCList")
        net.WriteUInt(#npcs, 16)
        for _, npc in ipairs(npcs) do
            net.WriteUInt(npc:EntIndex(), 16)
            net.WriteString(npc:GetClass())
            net.WriteString(npc:GetName() or "")
            net.WriteInt(npc:Health(), 16)
            net.WriteInt(npc:GetMaxHealth(), 16)
            net.WriteUInt(npc:GetNPCState(), 4)
            net.WriteInt(npc:GetCurrentSchedule(), 16)
            net.WriteBool(ZC_NPC_Godmode[npc:EntIndex()] == true)
            net.WriteString(GetScriptedSeqName(npc))
            -- Position for distance display
            local pos = npc:GetPos()
            net.WriteFloat(pos.x)
            net.WriteFloat(pos.y)
            net.WriteFloat(pos.z)
        end
    net.Send(admin)
end

-- ── Send sequence list for a specific NPC ─────────────────────────────────────

local function SendSequenceList(admin, npc)
    if not IsValid(npc) then return end
    local seqs = npc:GetSequenceList() or {}
    -- Cap at 512 to avoid net overflow on models with huge sequence counts
    local count = math.min(#seqs, 512)
    net.Start("ZC_NPCManager_SequenceList")
        net.WriteUInt(npc:EntIndex(), 16)
        net.WriteUInt(count, 16)
        for i = 1, count do
            net.WriteString(seqs[i])
        end
    net.Send(admin)
end

-- ── Feedback ──────────────────────────────────────────────────────────────────

local function Feedback(admin, msg)
    net.Start("ZC_NPCManager_Feedback")
        net.WriteString(msg)
    net.Send(admin)
end

local function FindNPC(entIndex)
    local ent = ents.GetByIndex(entIndex)
    if IsValid(ent) and ent:IsNPC() then return ent end
end

-- Collects every unique targetname used by scripted_sequence entities on the map,
-- along with which scripted_sequence owns it. Staff can assign one of these names
-- to a newly spawned NPC so the sequence can find and use it.
local function SendSeqTargets(admin)
    local targets = {}
    local seen    = {}
    for _, ss in ipairs(ents.FindByClass("scripted_sequence")) do
        if not IsValid(ss) then continue end
        local target  = ss:GetInternalVariable("m_iszEntity") or ""
        local ssName  = ss:GetName() ~= "" and ss:GetName() or "(unnamed)"
        if target ~= "" and not seen[target] then
            seen[target] = true
            table.insert(targets, { target = target, seqEnt = ssName })
        end
    end
    net.Start("ZC_NPCManager_SeqTargets")
        net.WriteUInt(#targets, 8)
        for _, t in ipairs(targets) do
            net.WriteString(t.target)
            net.WriteString(t.seqEnt)
        end
    net.Send(admin)
end

-- ── Open request ──────────────────────────────────────────────────────────────

net.Receive("ZC_NPCManager_Open", function(len, admin)
    if not IsValid(admin) then return end
    if not admin:IsAdmin() then return end
    SendNPCList(admin)
    SendSeqTargets(admin)
    net.Start("ZC_NPCManager_AIState")
        net.WriteBool(GetAIEnabled())
    net.Send(admin)
    net.Start("ZC_NPCManager_Open")
    net.Send(admin)
end)

-- ── Action dispatcher ─────────────────────────────────────────────────────────

net.Receive("ZC_NPCManager_Action", function(len, admin)
    if not IsValid(admin) then return end
    if not admin:IsAdmin() then return end

    local action   = net.ReadString()
    local entIndex = net.ReadUInt(16)
    local arg      = net.ReadString()

    local npc = FindNPC(entIndex)

    if action == "refresh" then
        SendNPCList(admin)
        return
    end

    if action == "getseqs" then
        if not IsValid(npc) then Feedback(admin, "NPC no longer valid."); return end
        SendSequenceList(admin, npc)
        return
    end

    if action == "godmode" then
        if not IsValid(npc) then Feedback(admin, "NPC no longer valid."); return end
        local enabled = ZC_NPC_Godmode[entIndex]
        if enabled then
            ZC_NPC_Godmode[entIndex] = nil
            Feedback(admin, npc:GetClass() .. " godmode OFF")
            ULib.log(admin:Nick() .. " disabled godmode on " .. npc:GetClass() .. " [" .. entIndex .. "]")
        else
            ZC_NPC_Godmode[entIndex] = true
            Feedback(admin, npc:GetClass() .. " godmode ON")
            ULib.log(admin:Nick() .. " enabled godmode on " .. npc:GetClass() .. " [" .. entIndex .. "]")
        end
        SendNPCList(admin)
        return
    end

    if action == "teleport" then
        if not IsValid(npc) then Feedback(admin, "NPC no longer valid."); return end
        local pos    = admin:GetPos()
        local offset = Vector(math.Rand(-80, 80), math.Rand(-80, 80), 0)
        npc:SetPos(pos + offset)
        npc:SetLocalVelocity(Vector(0, 0, 0))
        Feedback(admin, npc:GetClass() .. " teleported to you")
        ULib.log(admin:Nick() .. " teleported " .. npc:GetClass() .. " [" .. entIndex .. "] to themselves")
        return
    end

    if action == "tphere" then
        -- Teleport admin to the NPC instead
        if not IsValid(npc) then Feedback(admin, "NPC no longer valid."); return end
        local pos    = npc:GetPos()
        local offset = Vector(math.Rand(-60, 60), math.Rand(-60, 60), 0)
        admin:SetPos(pos + offset)
        admin:SetLocalVelocity(Vector(0, 0, 0))
        Feedback(admin, "Teleported to " .. npc:GetClass())
        return
    end

    if action == "playseq" then
        if not IsValid(npc) then Feedback(admin, "NPC no longer valid."); return end
        local seqName = string.Trim(arg)
        if seqName == "" then Feedback(admin, "No sequence specified."); return end
        local seqIdx = npc:LookupSequence(seqName)
        if seqIdx < 0 then
            Feedback(admin, "Sequence '" .. seqName .. "' not found on this model.")
            return
        end
        npc:ResetSequence(seqIdx)
        Feedback(admin, npc:GetClass() .. " playing: " .. seqName)
        ULib.log(admin:Nick() .. " played sequence '" .. seqName .. "' on " .. npc:GetClass() .. " [" .. entIndex .. "]")
        return
    end

    if action == "setname" then
        if not IsValid(npc) then Feedback(admin, "NPC no longer valid."); return end
        local newName = string.Trim(arg)
        -- Check nothing else already has this name
        if newName ~= "" then
            for _, ent in ipairs(ents.GetAll()) do
                if IsValid(ent) and ent ~= npc and ent:GetName() == newName then
                    Feedback(admin, "Name '" .. newName .. "' already used by " .. ent:GetClass() .. " [" .. ent:EntIndex() .. "].")
                    return
                end
            end
        end
        npc:SetName(newName)
        local display = newName ~= "" and ("'" .. newName .. "'") or "(cleared)"
        Feedback(admin, npc:GetClass() .. " name set to " .. display)
        ULib.log(admin:Nick() .. " set name of " .. npc:GetClass() .. " [" .. npc:EntIndex() .. "] to " .. display)
        SendNPCList(admin)
        return
    end

    if action == "kill" then
        if not IsValid(npc) then Feedback(admin, "NPC no longer valid."); return end
        ZC_NPC_Godmode[entIndex] = nil
        if npc.Kill then
            npc:Kill()
        else
            npc:Remove()
        end
        Feedback(admin, npc:GetClass() .. " killed")
        ULib.log(admin:Nick() .. " killed NPC " .. npc:GetClass() .. " [" .. entIndex .. "]")
        SendNPCList(admin)
        return
    end

    if action == "remove" then
        if not IsValid(npc) then Feedback(admin, "NPC no longer valid."); return end
        local cls = npc:GetClass()
        ZC_NPC_Godmode[entIndex] = nil
        npc:Remove()
        Feedback(admin, cls .. " removed")
        ULib.log(admin:Nick() .. " removed NPC " .. cls .. " [" .. entIndex .. "]")
        SendNPCList(admin)
        return
    end

    if action == "ai_toggle" then
        local newState = not GetAIEnabled()
        SetAIEnabled(newState)
        local label = newState and "enabled" or "disabled"
        Feedback(admin, "AI " .. label)
        ULib.log(admin:Nick() .. " toggled AI: " .. label)
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:IsAdmin() then
                net.Start("ZC_NPCManager_AIState")
                    net.WriteBool(newState)
                net.Send(ply)
            end
        end
        return
    end
end)

-- ── ULX command ───────────────────────────────────────────────────────────────

if ulx then
    local function ulxNPCManager(calling_ply)
        if not IsValid(calling_ply) then return end
        net.Start("ZC_NPCManager_Open")
        net.Send(calling_ply)
        ulx.logString(calling_ply:Nick() .. " opened the NPC Manager")
    end
    local cmd = ulx.command("ZCity", "ulx npcmanager", ulxNPCManager, "!npcmanager")
    cmd:defaultAccess(ULib.ACCESS_ADMIN)
    cmd:help("Opens the NPC Manager panel.")
end
