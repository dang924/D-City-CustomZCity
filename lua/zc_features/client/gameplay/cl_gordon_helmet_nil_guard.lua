if SERVER then return end

-- Patch-side guard for Gordon HEV RenderScreenspaceEffects hook.
-- Base code indexes LocalPlayer().armors["head"] without a nil check.

local BASE_HOOK_ID = "HEV_helmet"
local WRAPPED_HOOK_ID = "DCityPatch_HEV_helmet"

local nextWarnAt = 0

local function Warn(msg)
    if CurTime() < nextWarnAt then return end
    nextWarnAt = CurTime() + 5
    print("[DCityPatch] " .. msg)
end

local function TryWrapHevHook()
    local renderHooks = hook.GetTable() and hook.GetTable().RenderScreenspaceEffects
    if not istable(renderHooks) then return false end

    local original = renderHooks[BASE_HOOK_ID]
    if not isfunction(original) then return false end

    -- Avoid double-wrap.
    if renderHooks[WRAPPED_HOOK_ID] then
        return true
    end

    hook.Remove("RenderScreenspaceEffects", BASE_HOOK_ID)

    hook.Add("RenderScreenspaceEffects", WRAPPED_HOOK_ID, function(...)
        local lply = LocalPlayer()
        if IsValid(lply) then
            local armors = lply.armors
            if not istable(armors) then
                return
            end
        end

        local ok, err = pcall(original, ...)
        if ok then return end

        err = tostring(err or "")
        if string.find(err, "sh_gordon.lua:523", 1, true) then
            Warn("Suppressed Gordon HEV nil-armors crash in RenderScreenspaceEffects")
            return
        end

        ErrorNoHalt("[DCityPatch] HEV wrapper error: " .. err .. "\n")
    end)

    print("[DCityPatch] Wrapped HEV_helmet with nil-armors guard")
    return true
end

-- Base hook may register after autorun load; keep retrying briefly.
timer.Simple(0, TryWrapHevHook)
timer.Create("DCityPatch_WrapHEVHelmet", 1, 30, function()
    if TryWrapHevHook() then
        timer.Remove("DCityPatch_WrapHEVHelmet")
    end
end)
