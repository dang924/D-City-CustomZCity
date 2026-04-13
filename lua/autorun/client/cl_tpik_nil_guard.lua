if SERVER then return end

local function isCarriedBackcarry(owner)
    return IsValid(owner) and IsValid(owner:GetNWEntity("ZCBackCarrier"))
end

local function shouldSkipTPIK(owner, ent)
    if not IsValid(owner) or not IsValid(ent) then return true end
    if not ent:IsRagdoll() then return false end
    if isCarriedBackcarry(owner) then return true end

    local forearmIndex = ent:LookupBone("ValveBiped.Bip01_L_Forearm")
    if forearmIndex == nil then return true end

    local boneLength = owner.BoneLength and owner:BoneLength(forearmIndex) or nil
    if boneLength == nil then return true end

    return false
end

hook.Add("InitPostEntity", "DCityPatch_TPIKNilGuard", function()
    timer.Simple(0, function()
        if not hg or not hg.DoTPIK or not hg.MainTPIKFunction then return end
        if hg.DCityPatch_OriginalDoTPIK then return end

        hg.DCityPatch_OriginalDoTPIK = hg.DoTPIK

        function hg.DoTPIK(ply, ent)
            if shouldSkipTPIK(ply, ent) then return end

            local ok, err = pcall(hg.DCityPatch_OriginalDoTPIK, ply, ent)
            if ok then return end

            local msg = tostring(err or "")
            if string.find(msg, "cl_tpik.lua", 1, true) or string.find(msg, "BoneLength", 1, true) then
                return
            end

            ErrorNoHalt("[DCityPatch] TPIK guard caught unexpected error: " .. msg .. "\n")
        end
    end)
end)

print("[DCityPatch] Client TPIK nil-guard hotfix loaded.")