if CLIENT then return end
if _G.ZC_SV_PlayerOrganismGuardLoaded then return end

local function EnsurePlayerOrganism(ply, initialize)
    if not IsValid(ply) or not ply:IsPlayer() then return nil end

    local org = ply.organism
    local created = false

    if istable(org) then
        org.owner = ply
        if hg and hg.organism then
            hg.organism.list = hg.organism.list or {}
            hg.organism.list[ply] = org
        end
    else
        created = true
        if hg and hg.organism and isfunction(hg.organism.Add) then
            org = hg.organism.Add(ply)
        else
            org = { owner = ply }
            ply.organism = org
            if hg and hg.organism then
                hg.organism.list = hg.organism.list or {}
                hg.organism.list[ply] = org
            end
        end
    end

    if istable(org) then
        org.owner = ply
    end

    if initialize and istable(org) then
        local needsInit = created
            or not istable(org.stamina)
            or not istable(org.o2)
            or org.recoilmul == nil
            or org.meleespeed == nil

        if needsInit and hg and hg.organism and isfunction(hg.organism.Clear) then
            hg.organism.Clear(org)
        end
    end

    return org
end

local function PatchOrganismLifecycle()
    if not hg or not hg.organism then return false end
    if hg.organism._DCPatched_PlayerOrganismGuard then return true end

    local originalAdd = hg.organism.Add
    local originalClear = hg.organism.Clear

    if isfunction(originalAdd) then
        hg.organism.Add = function(ent)
            if IsValid(ent) and ent:IsPlayer() and istable(ent.organism) then
                ent.organism.owner = ent
                hg.organism.list = hg.organism.list or {}
                hg.organism.list[ent] = ent.organism
                return ent.organism
            end

            local org = originalAdd(ent)
            if IsValid(ent) and ent:IsPlayer() and istable(org) then
                org.owner = ent
            end
            return org
        end
    end

    if isfunction(originalClear) then
        hg.organism.Clear = function(org)
            if not istable(org) then return false end
            return originalClear(org)
        end
    end

    hook.Remove("Player Spawn", "homigrad-organism")
    hook.Add("Player Spawn", "homigrad-organism", function(ply)
        local org = EnsurePlayerOrganism(ply, false)
        if not istable(org) then return end
        hg.organism.Clear(org)
    end)

    for _, ply in ipairs(player.GetAll()) do
        EnsurePlayerOrganism(ply, true)
    end

    hg.organism._DCPatched_PlayerOrganismGuard = true
    return true
end

local function PatchSetPlayerClass()
    local pmeta = FindMetaTable("Player")
    if not pmeta or not isfunction(pmeta.SetPlayerClass) then return false end
    if pmeta._DCPatched_EnsureOrganismBeforeClass then return true end

    local originalSetPlayerClass = pmeta.SetPlayerClass
    pmeta.SetPlayerClass = function(self, value, data)
        EnsurePlayerOrganism(self, true)
        return originalSetPlayerClass(self, value, data)
    end

    pmeta._DCPatched_EnsureOrganismBeforeClass = true
    return true
end

local function TryPatchPlayerOrganismGuards()
    local okLifecycle = PatchOrganismLifecycle()
    local okClass = PatchSetPlayerClass()
    if okLifecycle and okClass then
        timer.Remove("DCityPatch_PlayerOrganismGuardTimer")
    end
end

hook.Add("PlayerInitialSpawn", "ZC_EnsurePlayerOrganismOnInitialSpawn", function(ply)
    EnsurePlayerOrganism(ply, false)
end)

hook.Add("HomigradRun", "DCityPatch_PlayerOrganismGuardHG", function()
    TryPatchPlayerOrganismGuards()
    timer.Simple(0, TryPatchPlayerOrganismGuards)
    timer.Simple(0.5, TryPatchPlayerOrganismGuards)
end)

hook.Add("InitPostEntity", "DCityPatch_PlayerOrganismGuardInit", TryPatchPlayerOrganismGuards)
timer.Create("DCityPatch_PlayerOrganismGuardTimer", 1, 0, TryPatchPlayerOrganismGuards)

_G.ZC_SV_PlayerOrganismGuardLoaded = true
print("[DCityPatch] Player organism guard loaded.")