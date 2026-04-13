if SERVER then return end

net.Receive("DCityPatch_RPChatLine", function()
    local r = net.ReadUInt(8)
    local g = net.ReadUInt(8)
    local b = net.ReadUInt(8)
    local message = net.ReadString()

    chat.AddText(Color(r, g, b), message)
end)
