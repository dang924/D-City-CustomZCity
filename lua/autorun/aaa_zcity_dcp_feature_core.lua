-- DCityPatchPack: per-module feature toggles (loads before aa_dcity_mode_gate.lua).
-- ConVars: zc_dcp_feat_<key> (0/1), default 1. ULX: sh_ulx_dcity_pack_features.lua

local function ZC_DCP_LoadStaticKeys()
    local candidates = {
        "dcitypack/dcp_feat_keys.lua",
        "dcitypack\\dcp_feat_keys.lua",
    }

    for _, path in ipairs(candidates) do
        if file.Exists(path, "LUA") then
            local loaded = include(path)
            if istable(loaded) then return loaded end
        end
    end

    print("[DCityPatch] WARNING: dcp_feat_keys.lua missing/unreadable; feature list fallback is empty.")
    return {}
end

ZC_DCP_STATIC_KEYS = ZC_DCP_STATIC_KEYS or ZC_DCP_LoadStaticKeys()

function ZC_DCP_FeatureKeyFromSource(src)
    if not isstring(src) or src == "" then return nil end
    src = string.lower(string.gsub(src, "\\", "/"))
    if string.sub(src, 1, 1) == "@" then
        src = string.sub(src, 2)
    end
    local p = string.find(src, "/lua/", 1, true)
    if not p then return nil end
    local rel = string.sub(src, p + 5)

    -- Keep old zc_dcp_feat_* convar names stable after feature file reorganization.
    if string.sub(rel, 1, 12) == "zc_features/" then
        local fname = string.match(rel, "([^/]+)%.lua$")
        if fname then
            if string.find(rel, "^zc_features/server/", 1, false) then
                rel = "autorun/server/" .. fname .. ".lua"
            elseif string.find(rel, "^zc_features/client/", 1, false) then
                rel = "autorun/client/" .. fname .. ".lua"
            elseif string.find(rel, "^zc_features/shared/", 1, false) then
                rel = "autorun/" .. fname .. ".lua"
            end
        end
    end

    rel = string.gsub(rel, "%.lua$", "")
    rel = string.gsub(rel, "/", "_")
    rel = string.gsub(rel, "[^%w_]", "_")
    if rel == "" then return nil end
    return rel
end

function ZC_DCP_FeatureEnabledForKey(key)
    if not key then return true end
    local cv = GetConVar("zc_dcp_feat_" .. key)
    if not cv then return true end
    return cv:GetBool()
end

if SERVER then
    function ZC_DCP_EnsureFeatureConvar(key)
        if not key then return end
        local name = "zc_dcp_feat_" .. key
        if ConVarExists(name) then return end
        CreateConVar(
            name,
            "1",
            { FCVAR_ARCHIVE, FCVAR_REPLICATED },
            "DCityPatchPack module toggle",
            0,
            1
        )
    end

    hook.Add("InitPostEntity", "ZC_DCP_PreregisterFeatureConvars", function()
        if not istable(ZC_DCP_STATIC_KEYS) then return end
        for _, k in ipairs(ZC_DCP_STATIC_KEYS) do
            ZC_DCP_EnsureFeatureConvar(k)
        end
    end)
end
