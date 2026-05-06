-- ZScav: inject worn-backpack rows into the Homigrad drop-equipment
-- radial menu (hg.armorMenuPanel).
--
-- Backpacks live in our own ZScav inventory (`inv.gear.backpack`), not
-- in `ply.armors`, so they don't appear in the standard menu. This file
-- watches for the menu to open and appends a button per worn pack which
-- fires `ZScavBackpackDrop` -- the server then routes through
-- BackpackUnequip so the SQL bag is repacked and a fresh ragdoll is
-- spawned in front of the player.

if SERVER then return end

ZSCAV = ZSCAV or {}

local function GetWornPackClass()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end
    local inv = ply:GetNetVar("ZScavInv", nil)
    if not (inv and inv.gear and inv.gear.backpack) then return nil end
    return inv.gear.backpack.class
end

local function PackName(class)
    local def = ZSCAV.GearItems and ZSCAV.GearItems[class]
    return (def and def.name) or string.NiceName(string.Replace(class, "sent_zscav_pack_", ""))
end

local function RequestDrop()
    net.Start("ZScavBackpackDrop")
    net.SendToServer()
end

-- Append a button for the currently worn pack to a frame's scroll panel.
-- Idempotent: bails if a button is already present.
local function InjectBackpackButton(frame)
    if not IsValid(frame) then return end
    local class = GetWornPackClass()
    if not class then return end
    local scroll = frame.scroll
    if not IsValid(scroll) then return end

    local canvas = scroll:GetCanvas()
    if IsValid(canvas) then
        for _, child in ipairs(canvas:GetChildren()) do
            if child.zscav_pack_btn then return end
        end
    end

    local mat = Material("homigrad/vgui/gradient_left.png")
    local but = vgui.Create("DButton")
    but.zscav_pack_btn = true
    but:SetText(PackName(class))
    but:SetFont("ZCity_Tiny")
    but:Dock(TOP)
    but:DockMargin(0, 0, 0, 5)
    but:SetSize(0, ScreenScaleH and ScreenScaleH(20) or 24)

    but.Paint = function(self, w, h)
        surface.SetMaterial(mat)
        surface.SetDrawColor(60, 30, 80, 255) -- distinct purple-ish for ZScav packs
        surface.DrawTexturedRect(0, 0, w, h)
        if self:IsHovered() then
            surface.SetDrawColor(120, 60, 160, 100)
            surface.DrawRect(0, 0, w, h)
        end
    end

    but.DoClick = function()
        RequestDrop()
        if IsValid(frame) then frame:Close() end
    end

    scroll:AddItem(but)
end

-- Watch for hg.armorMenuPanel coming alive. We can't predict exactly
-- when it opens (multiple key/cmd paths) so a cheap Think check is the
-- most robust hook.
local lastFrame
hook.Add("Think", "ZSCAV_DropMenu_Inject", function()
    local frame = hg and hg.armorMenuPanel
    if not IsValid(frame) then
        lastFrame = nil
        return
    end
    if frame == lastFrame then return end
    lastFrame = frame

    InjectBackpackButton(frame)

    -- The menu's RefreshTbl wipes and rebuilds the scroll on inventory
    -- changes; wrap it so our row reappears after each refresh.
    if not frame.zscav_wrapped and isfunction(frame.RefreshTbl) then
        local orig = frame.RefreshTbl
        frame.RefreshTbl = function(self, ...)
            local r = orig(self, ...)
            InjectBackpackButton(self)
            return r
        end
        frame.zscav_wrapped = true
    end
end)

-- Homigrad's "Drop Equipment" radial entry is gated by
-- `table.Count(armors+flashlight+sling+brassknuckles) > 0` (see
-- sh_equiprender.lua's `radialOptions "equipment"`). A player whose
-- only equipped gear is a ZScav backpack would never see the entry --
-- so the menu we're injecting into never opens. Add a parallel entry
-- whenever a worn pack exists; we de-dup against the base hook by
-- name.
hook.Add("radialOptions", "ZSCAV_equipment", function()
    if not GetWornPackClass() then return end
    local lply = LocalPlayer()
    if not IsValid(lply) then return end
    if not lply:KeyDown(IN_WALK) then return end
    local organism = lply.organism or {}
    if organism.otrub then return end

    hg.radialOptions = hg.radialOptions or {}
    -- Bail if the base "equipment" hook already added "Drop Equipment".
    for _, entry in ipairs(hg.radialOptions) do
        if entry and entry[2] == "Drop Equipment" then return end
    end
    hg.radialOptions[#hg.radialOptions + 1] = {
        function()
            RunConsoleCommand("hg_get_equipment")
            return 0
        end,
        "Drop Equipment",
    }
end)

-- Re-trigger a refresh when our ZScav inventory netvar changes so the
-- button reflects equip/unequip while the menu is open.
hook.Add("OnNetVarSet", "ZSCAV_DropMenu_NVRefresh", function(idx, key, _var)
    if key ~= "ZScavInv" then return end
    if Entity(idx) ~= LocalPlayer() then return end
    local frame = hg and hg.armorMenuPanel
    if IsValid(frame) and isfunction(frame.RefreshTbl) then
        frame:RefreshTbl()
    end
end)
