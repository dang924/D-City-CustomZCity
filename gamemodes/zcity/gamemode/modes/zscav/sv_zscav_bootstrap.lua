-- ZScav server bootstrap: net channels, resource preloads, and
-- pack-ragdoll integration helpers used by sv_zscav.lua.

ZSCAV = ZSCAV or {}

util.AddNetworkString("ZScavInvOpen")
util.AddNetworkString("ZScavInvClose")
util.AddNetworkString("ZScavInvAction")
util.AddNetworkString("ZScavInvNotice")
util.AddNetworkString("ZScavWorldPickupPrompt")
-- Container (bag-on-ground or nested-bag) net surface.
util.AddNetworkString("ZScavContainerOpen")   -- sv -> cl: snapshot+grid
util.AddNetworkString("ZScavContainerClose")  -- cl -> sv: stop sync / sv -> cl: force close
util.AddNetworkString("ZScavContainerAction") -- cl -> sv: take/put/move/open_nested
util.AddNetworkString("ZScavBackpackDrop")    -- cl -> sv: drop worn pack via radial
util.AddNetworkString("ZScavBagOpenProgress") -- sv -> cl: hold-to-open progress bar
util.AddNetworkString("ZScavSurgeryProgress") -- sv -> cl: timed surgery progress bar
util.AddNetworkString("ZScavRaidIntro")       -- sv -> cl: round-start splash for deployed raiders
util.AddNetworkString("ZScavRaidExtractList") -- sv -> cl: assigned extract names for the active raid
util.AddNetworkString("ZScavRaidJoinHint")    -- sv -> cl: late-join lobby hint for newly connected players
util.AddNetworkString("ZScavDeathOpen")       -- sv -> cl: death overlay + summary
util.AddNetworkString("ZScavDeathFade")       -- sv -> cl: fade-only death overlay used for protected instant respawns
util.AddNetworkString("ZScavDeathClose")      -- sv -> cl: close death overlay
util.AddNetworkString("ZScavDeathReturnLobby") -- cl -> sv: respawn at safe lobby

SetGlobalBool("ZScavRaidPadsActive", false)
SetGlobalFloat("ZScavRaidPadsArmedAt", 0)
SetGlobalFloat("ZScavRaidPadCountdownEnd", 0)
SetGlobalInt("ZScavRaidPadReadyPlayers", 0)
SetGlobalInt("ZScavRaidPadMinPlayers", 6)
SetGlobalInt("ZScavRaidBattlefieldPlayers", 0)
SetGlobalFloat("ZScavRaidLateSpawnWindowEnd", 0)
SetGlobalFloat("ZScavRaidLateSpawnCountdownEnd", 0)
SetGlobalInt("ZScavRaidLateSpawnReadyPlayers", 0)

-- Ensure custom backpack model files are in the client download list even
-- before the pack entity Lua is touched/spawned.
if SERVER then
    local paratusBase = "models/player/backpack_paratus_3_day/bp_paratus_3_day_body_lod0"
    for _, ext in ipairs({ ".mdl", ".vvd", ".phy", ".dx90.vtx", ".dx80.vtx", ".sw.vtx" }) do
        local path = paratusBase .. ext
        if file.Exists(path, "GAME") then
            resource.AddSingleFile(path)
        end
    end

    -- Also include custom Paratus materials so clients render the model.
    for _, path in ipairs({
        "materials/models/player/backpack_paratus_3_day/backpack paratus 3 day_diff.vmt",
        "materials/models/player/backpack_paratus_3_day/backpack paratus 3 day_diff.vtf",
    }) do
        if file.Exists(path, "GAME") then
            resource.AddSingleFile(path)
        end
    end
end

-- Admin diagnostic: checks Paratus model availability server-side and
-- asks the caller's client to print its own availability report.
concommand.Add("zscav_model_diag", function(ply)
    if IsValid(ply) and not ply:IsAdmin() and not ply:IsSuperAdmin() then
        ply:ChatPrint("[ZScavDiag] Admin only.")
        return
    end

    local model = "models/player/backpack_paratus_3_day/bp_paratus_3_day_body_lod0.mdl"
    local base = "models/player/backpack_paratus_3_day/bp_paratus_3_day_body_lod0"
    local svMsg = string.format("[ZScavDiag] SV util.IsValidModel=%s file.Exists=%s model=%s",
        tostring(util.IsValidModel(model)), tostring(file.Exists(model, "GAME")), model)

    print(svMsg)
    if IsValid(ply) then
        ply:ChatPrint(svMsg)
        ply:SendLua(([=[
            local model = %q
            local base = %q
            print("[ZScavDiag] CL util.IsValidModel:", util.IsValidModel(model), model)
            print("[ZScavDiag] CL file.Exists .mdl:", file.Exists(model, "GAME"), model)
            for _, ext in ipairs({ ".vvd", ".phy", ".dx90.vtx", ".dx80.vtx", ".sw.vtx" }) do
                local p = base .. ext
                print("[ZScavDiag] CL file.Exists " .. ext .. ":", file.Exists(p, "GAME"), p)
            end
        ]=]):format(model, base))
        ply:ChatPrint("[ZScavDiag] Client diagnostics printed to your client console.")
    end
end)

-- ---------------------------------------------------------------
-- Pack-as-ragdoll integration.
--
-- Pack ENTs (ent_zscav_pack_*) replace themselves with a real
-- prop_ragdoll on spawn so the player-format meshes drop with proper
-- bone-hull physics instead of floating off a single OBB box. The
-- ragdoll carries the original SENT class + bag UID in dynamic fields.
--
-- These helpers paper over the difference: any code that needs the
-- pack class or bag UID off a world entity should go through
-- ZSCAV:GetEntPackClass / ZSCAV:GetEntPackUID.
-- ---------------------------------------------------------------
function ZSCAV:GetEntPackClass(ent)
    if not IsValid(ent) then return nil end
    if ent.zscav_pack_class and ent.zscav_pack_class ~= "" then
        return ent.zscav_pack_class
    end
    return ent:GetClass()
end

function ZSCAV:GetEntPackUID(ent)
    if not IsValid(ent) then return nil end
    if ent.zscav_pack_uid and ent.zscav_pack_uid ~= "" then
        return ent.zscav_pack_uid
    end
    if ent.GetBagUID then
        local u = ent:GetBagUID()
        if u and u ~= "" then return u end
    end
    return nil
end

-- Spawn the ground/floor representation of a pack as a prop_ragdoll.
-- Tagged with class + uid so pickup intercepts and the bag GC can
-- recognize it. Returns the ragdoll entity (or NULL on failure).
function ZSCAV:SpawnPackRagdoll(class, pos, ang, uid, modelOverride)
    local model = modelOverride
    if not model then
        local stored = scripted_ents.GetStored(class)
        model = stored and stored.t and stored.t.Model or nil
    end
    if not model then return NULL end

    local rag = ents.Create("prop_ragdoll")
    if not IsValid(rag) then return NULL end
    rag:SetModel(model)
    rag:SetPos(pos or vector_origin)
    rag:SetAngles(ang or angle_zero)
    rag:Spawn()
    rag:Activate()

    rag.IsZScavPack      = true
    rag.zscav_pack_class = class
    rag.IsSpawned        = true
    if uid and uid ~= "" then
        rag.zscav_pack_uid = uid
    elseif ZSCAV.CreateBag then
        rag.zscav_pack_uid = ZSCAV:CreateBag(class)
    end

    -- Wake every bone so the ragdoll actually settles instead of staying
    -- in T-pose at the spawn point.
    for i = 0, rag:GetPhysicsObjectCount() - 1 do
        local p = rag:GetPhysicsObjectNum(i)
        if IsValid(p) then
            p:EnableMotion(true)
            p:Wake()
        end
    end

    -- Use intercept needs SIMPLE_USE so a single tap fires the hook.
    rag:SetUseType(SIMPLE_USE)

    -- Track for map cleanup / GC walking.
    ZSCAV.PackRagdolls = ZSCAV.PackRagdolls or {}
    ZSCAV.PackRagdolls[rag] = true

    return rag
end

-- Iterator: every active pack ragdoll OR pack SENT in the world.
function ZSCAV:IterPackEnts()
    local out = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and (ent.IsZScavPack or ent.GetBagUID) then
            local class = self:GetEntPackClass(ent)
            local def = class and self:GetGearDef(class) or nil
            if def and def.slot == "backpack" then
                out[#out + 1] = ent
            end
        end
    end
    return out
end
