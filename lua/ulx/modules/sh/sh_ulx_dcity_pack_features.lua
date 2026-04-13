-- ULX: per-module toggles for DCityPatchPack (zc_dcp_feat_<key>).
-- Keys match lua/dcitypack/dcp_feat_keys.lua and ZC_DCP_FeatureKeyFromSource().

if not SERVER then return end

local registerAttempts = 0

local function register()
    if not ulx or not ULib then return end
    if ulx.dcitypackfeat and ulx.dcitypackfeat._registered then return end
    if not istable(ZC_DCP_STATIC_KEYS) then
        registerAttempts = registerAttempts + 1
        if registerAttempts < 60 then
            timer.Simple(0.5, register)
        end
        return
    end

    ulx.dcitypackfeat = ulx.dcitypackfeat or {}
    ulx.dcitypackfeat._registered = true

    local function setFeat(calling_ply, key, state)
        key = tostring(key or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if key == "" then
            ULib.tsayError(calling_ply, "Usage: ulx dcitypackfeat <feature_key> <0|1>", true)
            return
        end
        local v = tonumber(state)
        if v ~= 0 and v ~= 1 then
            ULib.tsayError(calling_ply, "State must be 0 or 1.", true)
            return
        end
        local cv = GetConVar("zc_dcp_feat_" .. key)
        if not cv then
            ULib.tsayError(calling_ply, "Unknown feature key (no convar zc_dcp_feat_" .. key .. "). Use ulx dcitypackfeatlist", true)
            return
        end
        cv:SetInt(v)
        local who = IsValid(calling_ply) and calling_ply:Nick() or "Console"
        local msg = "[DCityPatchPack] " .. who .. " set " .. key .. " = " .. v
        print(msg)
        if ulx and ulx.fancyLogAdmin and IsValid(calling_ply) then
            ulx.fancyLogAdmin(calling_ply, "#A set DCityPack feature #s to #s", key, tostring(v))
        end
    end

    local function listFeats(calling_ply)
        if not istable(ZC_DCP_STATIC_KEYS) then
            ULib.tsayError(calling_ply, "ZC_DCP_STATIC_KEYS not loaded.", true)
            return
        end
        local lines = {}
        for i, k in ipairs(ZC_DCP_STATIC_KEYS) do
            local cv = GetConVar("zc_dcp_feat_" .. k)
            local on = not cv and "?" or (cv:GetBool() and "1" or "0")
            lines[#lines + 1] = string.format("%4d  ulx dcpf%d <0|1>  %s = %s", i, i, k, on)
        end
        local chunk = table.concat(lines, "\n")
        if IsValid(calling_ply) then
            calling_ply:PrintMessage(HUD_PRINTCONSOLE, "=== DCityPatchPack features (zc_dcp_feat_<key>) ===\n" .. chunk .. "\n=== end ===\n")
            calling_ply:ChatPrint("[DCityPatchPack] Full list printed to console.")
        else
            print("=== DCityPatchPack features ===\n" .. chunk)
        end
    end

    local function setAllFeats(calling_ply, state)
        local v = tonumber(state)
        if v ~= 0 and v ~= 1 then
            ULib.tsayError(calling_ply, "State must be 0 or 1.", true)
            return
        end
        if not istable(ZC_DCP_STATIC_KEYS) then return end
        for _, k in ipairs(ZC_DCP_STATIC_KEYS) do
            local name = "zc_dcp_feat_" .. k
            local cv = GetConVar(name)
            if cv then cv:SetInt(v) end
        end
        local who = IsValid(calling_ply) and calling_ply:Nick() or "Console"
        print("[DCityPatchPack] " .. who .. " set ALL pack features to " .. v)
    end

    function ulx.dcitypackfeat.set(calling_ply, key, state)
        setFeat(calling_ply, key, state)
    end

    local c1 = ulx.command("ZCity", "ulx dcitypackfeat", ulx.dcitypackfeat.set, "!dcitypackfeat")
    c1:addParam{ type = ULib.cmds.StringArg, hint = "feature_key" }
    c1:addParam{ type = ULib.cmds.NumArg, min = 0, max = 1, hint = "0=off 1=on" }
    c1:defaultAccess(ULib.ACCESS_SUPERADMIN)
    c1:help("Toggle one DCityPatchPack module (see lua/dcitypack/dcp_feat_keys.lua).")

    function ulx.dcitypackfeat.list(calling_ply)
        listFeats(calling_ply)
    end

    local c2 = ulx.command("ZCity", "ulx dcitypackfeatlist", ulx.dcitypackfeat.list, "!dcitypackfeatlist")
    c2:defaultAccess(ULib.ACCESS_SUPERADMIN)
    c2:help("Print all DCityPatchPack feature keys and zc_dcp_feat_* state to console.")

    function ulx.dcitypackfeat.setall(calling_ply, state)
        setAllFeats(calling_ply, state)
    end

    local c3 = ulx.command("ZCity", "ulx dcitypackfeatalle", ulx.dcitypackfeat.setall, "!dcitypackfeatalle")
    c3:addParam{ type = ULib.cmds.NumArg, min = 0, max = 1, hint = "0=off 1=on" }
    c3:defaultAccess(ULib.ACCESS_SUPERADMIN)
    c3:help("Set every DCityPatchPack module toggle on or off (dangerous).")

    -- One ULX command per module: ulx dcpf<N> <0|1> matches line N from dcitypackfeatlist order.
    if not ulx.dcitypackfeat._indexed then
        ulx.dcitypackfeat._indexed = true
        for idx, kid in ipairs(ZC_DCP_STATIC_KEYS) do
            local key = kid
            local fname = "dcpf" .. idx

            ulx.dcitypackfeat["_idx_" .. idx] = function(calling_ply, state)
                setFeat(calling_ply, key, state)
            end

            local cx = ulx.command("ZCity", "ulx " .. fname, ulx.dcitypackfeat["_idx_" .. idx], "!" .. fname)
            cx:addParam{ type = ULib.cmds.NumArg, min = 0, max = 1, hint = "0=off 1=on" }
            cx:defaultAccess(ULib.ACCESS_SUPERADMIN)
            cx:help("DCityPatchPack module #" .. idx .. ": " .. key)
        end
    end
end

hook.Add("Initialize", "ZC_ULX_DCityPackFeatures", register)
hook.Add("ULibLoaded", "ZC_ULX_DCityPackFeatures", register)
