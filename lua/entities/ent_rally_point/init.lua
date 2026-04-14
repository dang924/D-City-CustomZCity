AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ── Configuration ────────────────────────────────────────────────────────────
local RALLY_COOLDOWN  = 3      -- seconds between rally triggers
local DETECT_RADIUS   = 80     -- units around the entity that counts as a touch
local THINK_ACTIVE    = 0.05   -- Think interval when active (player scan rate)
local THINK_IDLE      = 0.5    -- Think interval when inactive

-- ── Persistence ──────────────────────────────────────────────────────────────
local PERSIST_DIR  = "zcity_rally_points"

local function GetPersistPath()
    return PERSIST_DIR .. "/" .. game.GetMap() .. ".json"
end

local function SaveAll(except)
    local points = {}
    for _, ent in ipairs(ents.FindByClass("ent_rally_point")) do
        if not IsValid(ent) or ent == except then continue end
        local p = ent:GetPos()
        local a = ent:GetAngles()
        table.insert(points, {
            px = p.x, py = p.y, pz = p.z,
            ap = a.p, ay = a.y, ar = a.r,
            active = ent:GetActive(),
        })
    end
    if not file.IsDir(PERSIST_DIR, "DATA") then
        file.CreateDir(PERSIST_DIR)
    end
    file.Write(GetPersistPath(), util.TableToJSON(points))
end

-- ── Entity lifecycle ─────────────────────────────────────────────────────────
function ENT:Initialize()
    self:SetModel("models/props_combine/combine_interface001.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(100)
    end
    self:SetActive(false)
    self._lastTrigger     = 0
    self._usedRebelRound   = false
    self._usedCombineRound = false
    self:NextThink(CurTime() + THINK_IDLE)
end

-- SetActiveState: transitions between visible-prop and invisible-trigger.
-- Pass noSave = true during load to suppress a redundant file write.
function ENT:SetActiveState(active, noSave)
    self:SetActive(active)
    if active then
        -- Freeze physics before switching movetype
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
        self:SetNoDraw(true)
        self:SetMoveType(MOVETYPE_NONE)
        -- SOLID_NONE: completely non-solid so bullets and NPC fire pass
        -- straight through. PermaProps/physgun targeting is done while the
        -- entity is still INACTIVE (SOLID_VPHYSICS); toggle back to inactive
        -- if you need to grab it again. E-key Use still works regardless.
        self:SetSolid(SOLID_NONE)
        self:SetCollisionGroup(COLLISION_GROUP_NONE)
    else
        self:SetNoDraw(false)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(true)
            phys:Wake()
        end
    end
    if not noSave then SaveAll() end
    self:NextThink(CurTime() + (active and THINK_ACTIVE or THINK_IDLE))
end

-- Use is intentionally disabled; toggle via right-click context menu.

-- ── Per-instance, per-faction round-use flags ───────────────────────────────
-- Each rally point has a separate use for rebels and combine per round.
local function ResetRallyFlags(ent)
    ent._usedRebelRound   = false
    ent._usedCombineRound = false
end

hook.Add("ZB_StartRound", "ZC_RallyPoint_RoundReset", function()
    for _, ent in ipairs(ents.FindByClass("ent_rally_point")) do
        if IsValid(ent) then ResetRallyFlags(ent) end
    end
    for _, ent in ipairs(ents.FindByClass("ent_rally_point_activated")) do
        if IsValid(ent) then ResetRallyFlags(ent) end
    end
end)

-- ── Teleport logic ────────────────────────────────────────────────────────────

-- Explicit combine class set used as the sole faction discriminator.
-- Everyone NOT in this set is treated as rebel, including nil/unknown classes
-- (default playerclass, furry, staff-custom classes, etc.)
local COMBINE_CLASSES = {
    ["Combine"]        = true,
    ["Metrocop"]       = true,
    ["headcrabzombie"] = true,
}

local function IsCombinePlayer(ply)
    -- Prefer the authoritative ZCity function if available (may be richer).
    if ZC_IsPatchCombinePlayer then return ZC_IsPatchCombinePlayer(ply) end
    -- Fallback: direct table lookup so nil/empty class always returns false → rebel.
    return IsValid(ply) and COMBINE_CLASSES[ply.PlayerClassName] == true
end

-- Moves every physics bone of a prop_ragdoll by the given offset vector.
local function TeleportRagdoll(ragdoll, offset)
    if not IsValid(ragdoll) then return end
    local physCount = ragdoll:GetPhysicsObjectCount()
    for i = 0, physCount - 1 do
        local phys = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(phys) then
            phys:SetPos(phys:GetPos() + offset)
            phys:SetVelocity(vector_origin)
            phys:Wake()
        end
    end
end

-- Teleports all players of a given faction ("rebel" or "combine") to dest.
-- Uses ZC_IsPatchCombinePlayer / ZC_IsPatchRebelPlayer from sv_patch_player_factions.
local function TeleportFaction(dest, faction)
    local landPos = dest + Vector(0, 0, 5)
    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        -- Faction gate: only explicit combine classes are "combine";
        -- everything else (nil class, default, furry, custom staff classes) is "rebel".
        local isCombine = IsCombinePlayer(ply)
        if faction == "combine" and not isCombine then continue end
        if faction == "rebel"   and isCombine     then continue end

        -- ZCity ragdoll: stored as ply.FakeRagdoll or NW "FakeRagdoll"
        local ragdoll = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll
                     or IsValid(ply:GetNWEntity("FakeRagdoll")) and ply:GetNWEntity("FakeRagdoll")
        if IsValid(ragdoll) then
            local delta = landPos - ragdoll:GetPos()
            TeleportRagdoll(ragdoll, delta)
        end

        ply:SetPos(landPos)
        ply:SetVelocity(-ply:GetVelocity())
    end
end

-- ── Think: player proximity scan when active ───────────────────────────────
function ENT:Think()
    if not self:GetActive() then
        self:NextThink(CurTime() + THINK_IDLE)
        return true
    end

    local now = CurTime()
    if (self._lastTrigger or 0) + RALLY_COOLDOWN <= now then
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), DETECT_RADIUS)) do
            if not (IsValid(ent) and ent:IsPlayer()) then continue end

            local isCombine = IsCombinePlayer(ent)
            local faction   = isCombine and "combine" or "rebel"

            if faction == "combine" and self._usedCombineRound then continue end
            if faction == "rebel"   and self._usedRebelRound   then continue end

            self._lastTrigger = now
            if faction == "combine" then
                self._usedCombineRound = true
            else
                self._usedRebelRound = true
            end
            TeleportFaction(self:GetPos(), faction)
            break
        end
    end

    self:NextThink(CurTime() + THINK_ACTIVE)
    return true
end

function ENT:OnRemove()
    SaveAll(self)
end

-- ── Persistence loader ────────────────────────────────────────────────────────
-- Delay 3 s so PermaProps (if used) can spawn its copies first; we then only
-- spawn entities for positions that aren't already covered, and restore the
-- active state for ones that are.
hook.Add("InitPostEntity", "ZC_RallyPointLoad", function()
    timer.Simple(3, function()
        local path = GetPersistPath()
        if not file.Exists(path, "DATA") then return end
        local data = util.JSONToTable(file.Read(path, "DATA"))
        if not data then return end

        local existing = ents.FindByClass("ent_rally_point")

        for _, saved in ipairs(data) do
            local savedPos = Vector(saved.px, saved.py, saved.pz)

            -- Find a close-enough existing entity (PermaProps may have spawned it)
            local found = nil
            for _, ex in ipairs(existing) do
                if IsValid(ex) and ex:GetPos():DistToSqr(savedPos) < 100 * 100 then
                    found = ex
                    break
                end
            end

            if found then
                -- Entity already exists; just restore active state if needed
                if saved.active and not found:GetActive() then
                    found:SetActiveState(true, true)
                end
            else
                -- Spawn a new one
                local ent = ents.Create("ent_rally_point")
                if IsValid(ent) then
                    ent:SetPos(savedPos)
                    ent:SetAngles(Angle(saved.ap, saved.ay, saved.ar))
                    ent:Spawn()
                    ent:Activate()
                    if saved.active then
                        timer.Simple(0.1, function()
                            if IsValid(ent) then ent:SetActiveState(true, true) end
                        end)
                    end
                end
            end
        end
    end)
end)
