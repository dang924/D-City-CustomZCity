if SERVER then return end

local function isClientProtogen(ply)
    if not IsValid(ply) then return false end
    return ply:GetNWBool("ZC_IsEventProtogen", false)
end

-- Client-side fallback: never draw event protogens for non-protogen clients
-- when hide mode is enabled.
hook.Add("PrePlayerDraw", "DCityPatch_EventProtogenClientHide", function(target)
    local lp = LocalPlayer()
    if not IsValid(lp) or not IsValid(target) then return end

    if not GetGlobalBool("ZC_EventModeIsEvent", false) then return end
    if not GetGlobalBool("ZC_EventProtogenHideEnabled", true) then return end

    if not isClientProtogen(target) then return end
    if isClientProtogen(lp) then return end

    return true
end)
