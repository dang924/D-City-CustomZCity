if CLIENT then return end

local exactHandlers = {}

local function NormalizeCommand(text)
    return string.lower(string.Trim(tostring(text or "")))
end

function ZC_RegisterExactChatCommand(cmd, handler)
    local key = NormalizeCommand(cmd)
    if key == "" or not isfunction(handler) then return false end
    exactHandlers[key] = handler
    return true
end

hook.Add("HG_PlayerSay", "ZC_ExactChatCommandRouter", function(ply, txtTbl, text)
    local key = NormalizeCommand(text)
    local handler = exactHandlers[key]
    if not handler then return end

    local ok, consumed = pcall(handler, ply, txtTbl, text)
    if not ok then
        print("[ZC chat-router] command handler error for '" .. key .. "': " .. tostring(consumed))
        return
    end

    if consumed then
        return ""
    end
end)
