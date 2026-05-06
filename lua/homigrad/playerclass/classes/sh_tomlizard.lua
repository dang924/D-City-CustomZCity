local CLASS = player.RegClass("TomLizard")

local TOM_MODEL = "models/a_thing/hoppers/tom_lizard.mdl"
local FALLBACK_MODEL = "models/player/group03/male_07.mdl"

local combines = {
    "npc_combine_s",
    "npc_metropolice",
    "npc_helicopter",
    "npc_combinegunship",
    "npc_combine",
    "npc_stalker",
    "npc_hunter",
    "npc_strider",
    "npc_turret_floor",
    "npc_combine_camera",
    "npc_manhack",
    "npc_cscanner",
    "npc_clawscanner"
}

local rebels = {
    "npc_barney",
    "npc_citizen",
    "npc_dog",
    "npc_eli",
    "npc_kleiner",
    "npc_magnusson",
    "npc_monk",
    "npc_mossman",
    "npc_odessa",
    "npc_rollermine_hacked",
    "npc_turret_floor_resistance",
    "npc_vortigaunt",
    "npc_alyx"
}

local function setRelations(ply, rebelDisposition, combineDisposition)
    for _, ent in ipairs(ents.FindByClass("npc_*")) do
        local npcClass = ent:GetClass()
        if table.HasValue(rebels, npcClass) then
            ent:AddEntityRelationship(ply, rebelDisposition, 0)
            ent:ClearEnemyMemory()
        elseif table.HasValue(combines, npcClass) then
            ent:AddEntityRelationship(ply, combineDisposition, 99)
            ent:ClearEnemyMemory()
        end
    end
end

function CLASS.Off(self)
    if CLIENT then return end

    setRelations(self, D_HT, D_LI)
end

CLASS.CanUseDefaultPhrase = true

function CLASS.On(self)
    if CLIENT then return end

    ApplyAppearance(self, nil, nil, nil, true)
    local appearance = self.CurAppearance or hg.Appearance.GetRandomAppearance()
    appearance.AAttachments = ""
    appearance.AColthes = ""

    self:SetPlayerColor(Color(23, 31, 100):ToVector())
    self:SetModel(util.IsValidModel(TOM_MODEL) and TOM_MODEL or FALLBACK_MODEL)
    self:SetSubMaterial()
    self:SetSkin(0)
    self:SetNetVar("Accessories", "")

    if self:GetModel() ~= TOM_MODEL then
        self:ChatPrint("[TomLizard] Model missing. Using fallback model; install Tom Lizard content.")
    end

    -- Keep view height stable with custom skeletons while preserving native anims.
    self:SetViewOffset(Vector(0, 0, 64))
    self:SetViewOffsetDucked(Vector(0, 0, 38))

    if zb and zb.GiveRole then
        zb.GiveRole(self, "Citizen", Color(255, 155, 0))
    end

    self.CurAppearance = appearance

    setRelations(self, D_LI, D_HT)

    local index = self:EntIndex()
    hook.Add("OnEntityCreated", "tomlizard_relation_ship" .. index, function(ent)
        if not IsValid(self) then
            hook.Remove("OnEntityCreated", "tomlizard_relation_ship" .. index)
            return
        end

        if not ent:IsNPC() then return end

        if table.HasValue(rebels, ent:GetClass()) then
            ent:AddEntityRelationship(self, D_LI, 0)
        elseif table.HasValue(combines, ent:GetClass()) then
            ent:AddEntityRelationship(self, D_HT, 99)
        end
    end)
end

function CLASS.Guilt(self, victim)
    if CLIENT then return end
    if victim:GetPlayerClass() == self:GetPlayerClass() then return 1 end

    local round = CurrentRound and CurrentRound()
    if round and round.name == "hmcd" and zb and zb.ForcesAttackedInnocent then
        return zb.ForcesAttackedInnocent(self, victim)
    end

    return 1
end
