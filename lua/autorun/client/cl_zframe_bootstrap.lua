if SERVER then return end

local function HasZFrame()
    return vgui and vgui.GetControlTable and vgui.GetControlTable("ZFrame") ~= nil
end

local function RegisterFallbackZFrame()
    if HasZFrame() then return true end

    local PANEL = {}

    function PANEL:Init()
        self:SetTitle("")
        self:SetSizable(false)
        self:ShowCloseButton(true)
    end

    vgui.Register("ZFrame", PANEL, "DFrame")
    print("[DCityPatch] Registered fallback ZFrame.")
    return true
end

local function EnsureZFrame()
    if HasZFrame() then return true end

    if file.Exists("initpost/menu-n-derma/derma/cl_frame.lua", "LUA") then
        include("initpost/menu-n-derma/derma/cl_frame.lua")
    end

    if HasZFrame() then
        print("[DCityPatch] Loaded base ZFrame definition.")
        return true
    end

    return RegisterFallbackZFrame()
end

hook.Add("InitPostEntity", "DCityPatch_EnsureZFrame", EnsureZFrame)
timer.Simple(0, EnsureZFrame)
timer.Simple(1, EnsureZFrame)
