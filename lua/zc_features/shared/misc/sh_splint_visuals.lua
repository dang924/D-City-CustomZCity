if SERVER then
    AddCSLuaFile()

    hook.Add("Player Spawn", "dcity_clear_splints", function(ply)
        if OverrideSpawn then return end
        ply.splints = {}
        ply:SetNetVar("Splints", ply.splints)
    end)

    hook.Add("Player_Death", "dcity_copy_clear_splints", function(ply)
        if IsValid(ply.FakeRagdoll) then
            ply.FakeRagdoll.splints = table.Copy(ply.splints or {})
            ply.FakeRagdoll:SetNetVar("Splints", ply.FakeRagdoll.splints)
        end

        ply.splints = {}
        ply:SetNetVar("Splints", ply.splints)
    end)

    hook.Add("Fake", "dcity_sync_splints_to_ragdoll", function(ply, ragdoll)
        if not IsValid(ragdoll) then return end
        ragdoll.splints = table.Copy(ply.splints or {})
        ragdoll:SetNetVar("Splints", ragdoll.splints)
    end)

    return
end

local SPLINT_MODEL = "models/tourniquet/tourniquet_put.mdl"
local SPLINT_OFFSETS = {
    ["ValveBiped.Bip01_L_Forearm"] = { Vector(0, 0, 0), Angle(0, 0, 90), 1 },
    ["ValveBiped.Bip01_R_Forearm"] = { Vector(0, 0, 0), Angle(0, 0, 90), 1 },
    ["ValveBiped.Bip01_L_Calf"] = { Vector(0, 0, 0), Angle(0, 0, 90), 1 },
    ["ValveBiped.Bip01_R_Calf"] = { Vector(0, 0, 0), Angle(0, 0, 90), 1 },
}

local function RemoveSplintModels(ent)
    if not ent.splintsM then return end

    for i, model in pairs(ent.splintsM) do
        if IsValid(model) then
            model:Remove()
        end
        ent.splintsM[i] = nil
    end
end

local function RenderSplints(ent, splints)
    if not istable(splints) or not next(splints) then return end

    ent.splintsM = ent.splintsM or {}

    for i, info in ipairs(splints) do
        local boneName = istable(info) and info[1]
        local params = boneName and SPLINT_OFFSETS[boneName]
        if not params then continue end

        local boneIndex = ent:LookupBone(boneName)
        if not boneIndex then continue end

        local matrix = ent:GetBoneMatrix(boneIndex)
        if not matrix then continue end

        ent.splintsM[i] = IsValid(ent.splintsM[i]) and ent.splintsM[i] or ClientsideModel(SPLINT_MODEL)
        local model = ent.splintsM[i]
        if not IsValid(model) then continue end

        model:SetNoDraw(true)

        local pos, ang = LocalToWorld(params[1], params[2], matrix:GetTranslation(), matrix:GetAngles())
        model:SetRenderOrigin(pos)
        model:SetRenderAngles(ang)
        model:SetModelScale(params[3], 0)
        model:SetupBones()
        model:DrawModel()
    end
end

hook.Add("OnNetVarSet", "dcity_splints_netvar", function(index, key, var)
    if key ~= "Splints" then return end

    local ent = Entity(index)
    if not IsValid(ent) then return end

    ent.splints = var
    RemoveSplintModels(ent)

    ent:CallOnRemove("dcity_remove_splint_models", function()
        RemoveSplintModels(ent)
    end)
end)

hook.Add("Player_Death", "dcity_remove_splints_on_death", function(ply)
    if IsValid(ply) then
        RemoveSplintModels(ply)
    end
end)

hook.Add("PostPlayerDraw", "dcity_render_splints", function(ply)
    if not IsValid(ply) then return end
    local splints = ply.splints or ply:GetNetVar("Splints", nil)
    RenderSplints(ply, splints)
end)
