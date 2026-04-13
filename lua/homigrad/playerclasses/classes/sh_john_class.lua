-- sh_john_class.lua — John Wick playerclass for ZCity.
-- Registers "John" as a selectable playerclass via !playerclass <player> John.
-- Mirrors the rebel class for NPC relationships, with martial arts organism stats.
-- Place in: lua/homigrad/playerclass/classes/

local CLASS = player.RegClass("John")

local JOHN_MODEL = "models/wick_chapter2/wick_chapter2.mdl"

-- NPC relationship tables — mirrors rebel class so NPCs treat John as rebel
local combines = {
    "npc_combine_s", "npc_strider", "npc_metropolice", "npc_hunter",
    "npc_rollermine", "npc_cscanner", "npc_combinegunship",
    "npc_combinedropship", "npc_clawscanner", "npc_manhack",
    "npc_combine_camera", "npc_turret_ceiling", "npc_turret_floor"
}
local rebels = {
    "npc_alyx", "npc_barney", "npc_citizen", "npc_eli", "npc_fisherman",
    "npc_kleiner", "npc_magnusson", "npc_mossman", "npc_odessa",
    "npc_rollermine_hacked", "npc_turret_floor_resistance", "npc_vortigaunt"
}

local function ApplyJohnStats(ply)
    local org = ply.organism
    if not org then return end

    -- ── Martial arts ──────────────────────────────────────────────────────────
    -- Melee animation speed — matches Gordon at full HEV power
    org.meleespeed   = 2.0

    -- Kick damage multiplier — judo/jiu-jitsu kicks hit significantly harder
    org.legstrength  = 2.5

    -- NOTE: superfighter is intentionally NOT set here.
    -- superfighter causes sv_input.lua to return 0 damage for every organ that
    -- isn't named "vest" or "helmet" — including skull and brain — making John
    -- completely bulletproof to headshots outside of the JWick event's own
    -- PreTraceOrganBulletDamage hook. The doubled melee knockback it provides
    -- is not worth that side effect; legstrength alone handles the kick power.

    -- ── Suit / conditioning ───────────────────────────────────────────────────
    -- Recoil control — trained shooter, precise fire
    org.recoilmul    = 0.3

    -- Reduced bleeding — suit and conditioning slow blood loss
    org.bleedingmul  = 0.4

    -- Fast stamina recovery — elite conditioning between engagements
    if org.stamina then
        org.stamina.regen = 2.0
    end

    -- Suppress pain feedback — focus and adrenaline suppress pain signals
    org.CantCheckPulse = true
end

local function RemoveJohnStats(ply)
    local org = ply.organism
    if not org then return end

    org.meleespeed   = 1
    org.legstrength  = 1
    org.recoilmul    = 0.6
    org.bleedingmul  = 1
    if org.stamina then
        org.stamina.regen = 1
    end
    org.CantCheckPulse = nil
end

function CLASS.Off(self)
    if CLIENT then return end

    RemoveJohnStats(self)
    self:SetNWString("PlayerRole", nil)

    -- Restore NPC relationships on class change
    for _, v in ipairs(ents.FindByClass("npc_*")) do
        if table.HasValue(combines, v:GetClass()) then
            v:AddEntityRelationship(self, D_HT, 99)
        elseif table.HasValue(rebels, v:GetClass()) then
            v:AddEntityRelationship(self, D_LI, 0)
        end
    end

    hook.Remove("OnEntityCreated", "john_relation_" .. self:EntIndex())
end

function CLASS.On(self)
    if CLIENT then return end

    ApplyAppearance(self, nil, nil, nil, true)
    local Appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    Appearance.AAttachments = ""
    Appearance.AColthes = ""
    self.CurAppearance = Appearance

    self:SetNWString("PlayerName", "John Wick")
    self:SetPlayerColor(Color(10, 10, 10):ToVector())
    self:SetModel(JOHN_MODEL)
    self:SetSubMaterial()
    self:SetSkin(0)

    -- Correct view offset to match ZCity standard (model $eyeposition is 70)
    self:SetViewOffset(Vector(0, 0, 64))
    self:SetViewOffsetDucked(Vector(0, 0, 38))

    -- Apply martial arts and suit stats
    timer.Simple(0.1, function()
        if not IsValid(self) then return end
        ApplyJohnStats(self)
    end)

    -- Recreate FakeRagdoll with the wick skeleton so ADS works correctly
    timer.Simple(0.2, function()
        if not IsValid(self) or not self:Alive() then return end
        if IsValid(self.FakeRagdoll) then
            self.FakeRagdoll:Remove()
            self.FakeRagdoll = nil
        end
        timer.Simple(0.1, function()
            if not IsValid(self) or not self:Alive() then return end
            hg.Fake(self)
        end)
    end)

    -- Make combine hostile, rebels friendly — same as rebel class
    for _, v in ipairs(ents.FindByClass("npc_*")) do
        if table.HasValue(combines, v:GetClass()) then
            v:AddEntityRelationship(self, D_HT, 99)
        elseif table.HasValue(rebels, v:GetClass()) then
            v:AddEntityRelationship(self, D_LI, 0)
        end
    end

    -- Keep relationships for newly spawned NPCs
    hook.Add("OnEntityCreated", "john_relation_" .. self:EntIndex(), function(ent)
        if not IsValid(self) or not self:Alive() then
            hook.Remove("OnEntityCreated", "john_relation_" .. self:EntIndex())
            return
        end
        timer.Simple(0, function()
            if not IsValid(ent) then return end
            if table.HasValue(combines, ent:GetClass()) then
                ent:AddEntityRelationship(self, D_HT, 99)
            elseif table.HasValue(rebels, ent:GetClass()) then
                ent:AddEntityRelationship(self, D_LI, 0)
            end
        end)
    end)
end

-- Re-apply stats on respawn in case organism resets them
hook.Add("Player Spawn", "JohnClass_StatRestore", function(ply)
    if ply.PlayerClassName ~= "John" then return end
    timer.Simple(0.2, function()
        if not IsValid(ply) or not ply:Alive() then return end
        ApplyJohnStats(ply)
    end)
end)

function CLASS.Guilt(self, Victim)
    if CLIENT then return end
    if Victim:GetPlayerClass() == self:GetPlayerClass() then return 1 end
    local ok, rnd = pcall(CurrentRound)
    if ok and istable(rnd) and rnd.name == "hmcd" then
        return zb.ForcesAttackedInnocent(self, Victim)
    end
    return 1
end
