-- ZScav backpack on-body attach.
--
-- For each player whose ZScav inventory has a worn backpack, we spawn a
-- ClientsideModel parented to the spine bone with per-class offset/angle
-- /scale taken from ZSCAV.GearItems[class].display.
--
-- The display table is server-tunable (see sv_zscav_config.lua); when an
-- admin updates it, the server broadcasts ZScavDisplaySync and we
-- re-attach so changes are visible without restarting the round.

if SERVER then return end
-- Backpack draw is now handled entirely by the homigrad armor pipeline
-- (sh_equiprender.lua MergeZScavBackpackArmor), which works identically on
-- alive and ragdolled players. This file still registers the tuner command
-- and ZScavDisplaySync handler, but the per-player bonemerge attach loop
-- is disabled.
local ATTACH_DISABLED = true

ZSCAV = ZSCAV or {}

local ATTACH = {}  -- ply -> { mdl = ent, class = "..." }

local function GetWornBackpackClass(ply)
    if not IsValid(ply) then return nil end
    local inv = ply:GetNetVar("ZScavInv", nil)
    if not inv or not inv.gear or not inv.gear.backpack then return nil end
    return inv.gear.backpack.class
end

local function ResolveDisplay(class)
    local def = class and ZSCAV:GetGearDef(class) or nil
    if not def or not def.display then return nil end
    local d = def.display
    return {
        bone  = d.bone or "ValveBiped.Bip01_Spine2",
        pos   = Vector(d.pos and d.pos.x or 0, d.pos and d.pos.y or 0, d.pos and d.pos.z or 0),
        ang   = Angle(d.ang and d.ang.p or 0, d.ang and d.ang.y or 0, d.ang and d.ang.r or 0),
        scale = tonumber(d.scale or 1) or 1,
    }
end

local function ResolveModelPath(class)
    -- The pack ENT's ENT.Model. Fallback walks scripted_ents.
    local stored = scripted_ents.GetStored(class)
    if stored and stored.t and stored.t.Model then return stored.t.Model end
    return nil
end

local function ClearAttach(ply)
    local rec = ATTACH[ply]
    if rec and IsValid(rec.mdl) then rec.mdl:Remove() end
    ATTACH[ply] = nil
end

local function ApplyAttach(ply, class, parentOverride)
    ClearAttach(ply)
    if not IsValid(ply) or not class then return end

    local model = ResolveModelPath(class)
    if not model then return end
    local disp = ResolveDisplay(class)
    if not disp then return end

    local mdl = ClientsideModel(model, RENDERGROUP_OPAQUE)
    if not IsValid(mdl) then return end

    local parent = IsValid(parentOverride) and parentOverride or ply

    -- Pack worn-models are player-format ragdolls (`bp_*_body_lod0.mdl`)
    -- with a full ValveBiped skeleton. They MUST bonemerge to the
    -- wearer or they render in their own A-pose centered on the parent
    -- bone -- which puts the visible backpack mesh ~50u above the
    -- player's head. With EF_BONEMERGE the player's skeleton drives the
    -- bag, and the display pos/ang/scale become small fine-tune nudges.
    mdl:SetParent(parent)
    mdl:AddEffects(EF_BONEMERGE)
    mdl:AddEffects(EF_BONEMERGE_FASTCULL)
    mdl:SetLocalPos(disp.pos)
    mdl:SetLocalAngles(disp.ang)
    mdl:SetModelScale(disp.scale, 0)

    ATTACH[ply] = { mdl = mdl, class = class, parent = parent }
end

-- Resolve which entity should currently carry the bonemerged pack.
-- When a player dies the player ent goes invisible/frozen and a separate
-- prop_ragdoll (`ply:GetRagdollEntity()`) holds the visible body. Some
-- frameworks also stuff a custom ragdoll into ply.ragdoll / ply.Ragdoll.
local function GetVisibleBody(ply)
    if not IsValid(ply) then return nil end
    if ply:Alive() and not ply:IsDormant() then return ply end

    local rag = ply:GetRagdollEntity()
    if IsValid(rag) then return rag end

    rag = ply.ragdoll or ply.Ragdoll or ply.serverRagdoll
    if IsValid(rag) then return rag end

    return ply -- fall back; will still float, but no worse than before
end

local function SyncOne(ply)
    local class = GetWornBackpackClass(ply)
    local rec = ATTACH[ply]

    if not class then
        if rec then ClearAttach(ply) end
        return
    end

    local desiredParent = GetVisibleBody(ply)

    -- Recreate if class changed, the cached ent is gone, OR the visible
    -- body switched (player → ragdoll on death, ragdoll → player on
    -- respawn). Re-parenting alone isn't enough because EF_BONEMERGE
    -- caches its source skeleton at SetParent time.
    if not rec
        or rec.class ~= class
        or not IsValid(rec.mdl)
        or rec.parent ~= desiredParent
        or not IsValid(rec.parent)
    then
        ApplyAttach(ply, class, desiredParent)
        return
    end

    -- Live re-apply transform every tick so admin tuning shows up.
    local disp = ResolveDisplay(class)
    if disp and IsValid(rec.mdl) then
        rec.mdl:SetLocalPos(disp.pos)
        rec.mdl:SetLocalAngles(disp.ang)
        rec.mdl:SetModelScale(disp.scale, 0)
    end
end

-- Hide our own pack each frame if we're in first person. Vehicles,
-- thirdperson cams, and death cam all set ShouldDrawLocalPlayer() to
-- true, so this only suppresses the case where the camera is inside the
-- player's head and the spine-parented mesh would clip through it.
hook.Add("PrePlayerDraw", "ZSCAV_AttachFirstPersonHide", function(ply)
    if ATTACH_DISABLED then return end
    if ply ~= LocalPlayer() then return end
    local rec = ATTACH[ply]
    if rec and IsValid(rec.mdl) then
        rec.mdl:SetNoDraw(not ply:ShouldDrawLocalPlayer())
    end
end)

hook.Add("PostPlayerDraw", "ZSCAV_AttachFirstPersonShow", function(ply)
    if ATTACH_DISABLED then return end
    if ply ~= LocalPlayer() then return end
    local rec = ATTACH[ply]
    if rec and IsValid(rec.mdl) then
        rec.mdl:SetNoDraw(false)
    end
end)

-- Belt-and-suspenders: PrePlayerDraw is only fired when the engine
-- actually intends to draw the player; in pure first person it may be
-- skipped, leaving SetNoDraw(false) and our pack visible at the camera.
-- A per-frame check forces the right state regardless.
hook.Add("PreDrawOpaqueRenderables", "ZSCAV_AttachFirstPersonGuard", function(_, _, isSky3D)
    if ATTACH_DISABLED then return end
    if isSky3D then return end
    local me = LocalPlayer()
    if not IsValid(me) then return end
    local rec = ATTACH[me]
    if rec and IsValid(rec.mdl) then
        rec.mdl:SetNoDraw(not me:ShouldDrawLocalPlayer())
    end
end)

local nextSync = 0
hook.Add("Think", "ZSCAV_AttachThink", function()
    if ATTACH_DISABLED then return end
    if CurTime() < nextSync then return end
    nextSync = CurTime() + 0.25
    for _, ply in player.Iterator() do
        SyncOne(ply)
    end
end)

hook.Add("EntityRemoved", "ZSCAV_AttachCleanup", function(ent)
    if ATTACH_DISABLED then return end
    if ent:IsPlayer() then ClearAttach(ent) end
end)

-- ---------------------------------------------------------------------
-- Display tuning sync from server.
-- ---------------------------------------------------------------------
net.Receive("ZScavDisplaySync", function()
    local sz = net.ReadUInt(32)
    if sz <= 0 or sz > 64000 then return end
    local raw = net.ReadData(sz)
    local data = util.JSONToTable(raw or "")
    if not istable(data) then return end

    for class, d in pairs(data) do
        local def = ZSCAV.GearItems and ZSCAV.GearItems[class]
        if def and istable(d) then
            def.display = def.display or {}
            if d.bone  then def.display.bone  = tostring(d.bone) end
            if d.pos   then def.display.pos   = { x = tonumber(d.pos.x) or 0, y = tonumber(d.pos.y) or 0, z = tonumber(d.pos.z) or 0 } end
            if d.ang   then def.display.ang   = { p = tonumber(d.ang.p) or 0, y = tonumber(d.ang.y) or 0, r = tonumber(d.ang.r) or 0 } end
            if d.scale then def.display.scale = tonumber(d.scale) or 1 end
        end
    end
end)

-- ---------------------------------------------------------------------
-- Tuner GUI: zscav_pack_tune
--
-- Opens a sliders panel for the currently worn pack's display offsets.
-- All edits apply locally in real-time (you'll see them on your model in
-- thirdperson / on other players if mirrored). The Save to Server
-- button sends the current values via ZScavCfgApply (server checks
-- IsAuthorized) so they persist and broadcast to all clients.
--
-- A class dropdown lets you switch between known pack classes without
-- equipping each one -- useful for tuning the whole roster in a session.
-- ---------------------------------------------------------------------

local TunerFrame  -- single-instance

local function CollectPackClasses()
    local out = {}
    for class, def in pairs(ZSCAV.GearItems or {}) do
        if def.slot == "backpack" then out[#out + 1] = class end
    end
    table.sort(out)
    return out
end

local function EnsureDisplay(class)
    local def = ZSCAV.GearItems and ZSCAV.GearItems[class]
    if not def then return nil end
    def.display = def.display or {}
    local d = def.display
    d.bone  = d.bone  or "ValveBiped.Bip01_Spine2"
    d.pos   = d.pos   or { x = 0, y = 0, z = 0 }
    d.ang   = d.ang   or { p = 0, y = 0, r = 0 }
    d.scale = d.scale or 1
    return d
end

-- Force the local attach to refresh now (so slider drags feel instant
-- instead of waiting on the 0.25s sync tick).
local function PokeAttach()
    local me = LocalPlayer()
    if not IsValid(me) then return end
    local rec = ATTACH[me]
    local cls = GetWornBackpackClass(me)
    if cls and rec and rec.class == cls then
        local disp = ResolveDisplay(cls)
        if disp and IsValid(rec.mdl) then
            rec.mdl:SetLocalPos(disp.pos)
            rec.mdl:SetLocalAngles(disp.ang)
            rec.mdl:SetModelScale(disp.scale, 0)
        end
    end
end

local function SendDisplayToServer(class)
    local def = ZSCAV.GearItems and ZSCAV.GearItems[class]
    if not (def and def.display) then return end
    local payload = {
        GearItems = {
            [class] = {
                display = {
                    bone  = def.display.bone,
                    pos   = def.display.pos,
                    ang   = def.display.ang,
                    scale = def.display.scale,
                },
            },
        },
    }
    local raw = util.TableToJSON(payload) or "{}"
    net.Start("ZScavCfgApply")
        net.WriteUInt(#raw, 32)
        net.WriteData(raw, #raw)
    net.SendToServer()
end

local function BuildTuner()
    if IsValid(TunerFrame) then TunerFrame:Remove() end

    local frame = vgui.Create("DFrame")
    TunerFrame = frame
    frame:SetTitle("ZScav Pack Tuner")
    frame:SetSize(360, 460)
    frame:Center()
    frame:MakePopup()
    frame:SetDeleteOnClose(true)

    local classes = CollectPackClasses()
    if #classes == 0 then
        local lbl = frame:Add("DLabel")
        lbl:Dock(FILL)
        lbl:SetText("No backpack-class gear is registered.")
        lbl:SetContentAlignment(5)
        return
    end

    -- Default: currently worn class, else first known.
    local startClass = GetWornBackpackClass(LocalPlayer()) or classes[1]
    if not table.HasValue(classes, startClass) then startClass = classes[1] end
    local currentClass = startClass

    local row = frame:Add("DPanel")
    row:Dock(TOP)
    row:DockMargin(8, 8, 8, 4)
    row:SetTall(28)
    row.Paint = nil

    local lbl = row:Add("DLabel")
    lbl:Dock(LEFT)
    lbl:SetWide(50)
    lbl:SetText("Pack:")
    lbl:SetContentAlignment(4)

    local combo = row:Add("DComboBox")
    combo:Dock(FILL)
    for _, c in ipairs(classes) do combo:AddChoice(c, c, c == startClass) end

    -- Bone selector.
    local boneRow = frame:Add("DPanel")
    boneRow:Dock(TOP)
    boneRow:DockMargin(8, 4, 8, 4)
    boneRow:SetTall(28)
    boneRow.Paint = nil

    local boneLbl = boneRow:Add("DLabel")
    boneLbl:Dock(LEFT)
    boneLbl:SetWide(50)
    boneLbl:SetText("Bone:")
    boneLbl:SetContentAlignment(4)

    local boneEntry = boneRow:Add("DTextEntry")
    boneEntry:Dock(FILL)

    -- Sliders. Each tuple = { label, min, max, decimals, getter, setter }.
    local sliders = {}
    local function addSlider(name, mn, mx, dec, getter, setter)
        local s = frame:Add("DNumSlider")
        s:Dock(TOP)
        s:DockMargin(8, 2, 8, 2)
        s:SetText(name)
        s:SetMin(mn)
        s:SetMax(mx)
        s:SetDecimals(dec)
        s.OnValueChanged = function(_, v)
            setter(v)
            PokeAttach()
        end
        sliders[#sliders + 1] = { panel = s, getter = getter }
        return s
    end

    -- Bound to current class via closures that re-read on each call.
    local function d() return EnsureDisplay(currentClass) end

    -- Position sliders need wide range: ragdoll pack models can have
    -- their origin far from the visible mesh, so ±32 is not enough.
    addSlider("Pos X",  -128,128, 2, function() return d().pos.x end, function(v) d().pos.x = v end)
    addSlider("Pos Y",  -128,128, 2, function() return d().pos.y end, function(v) d().pos.y = v end)
    addSlider("Pos Z",  -128,128, 2, function() return d().pos.z end, function(v) d().pos.z = v end)
    addSlider("Pitch", -180,180, 1, function() return d().ang.p end, function(v) d().ang.p = v end)
    addSlider("Yaw",   -180,180, 1, function() return d().ang.y end, function(v) d().ang.y = v end)
    addSlider("Roll",  -180,180, 1, function() return d().ang.r end, function(v) d().ang.r = v end)
    addSlider("Scale", 0.05, 3,  3, function() return d().scale  end, function(v) d().scale  = v end)

    local function refreshFromClass()
        local disp = EnsureDisplay(currentClass)
        if not disp then return end
        boneEntry:SetText(disp.bone or "")
        for _, rec in ipairs(sliders) do
            rec.panel:SetValue(rec.getter())
        end
    end

    boneEntry.OnEnter = function(self)
        local v = self:GetValue() or ""
        if v ~= "" then
            EnsureDisplay(currentClass).bone = v
            PokeAttach()
        end
    end

    combo.OnSelect = function(_, _, _, data)
        currentClass = data
        refreshFromClass()
    end

    -- Buttons row.
    local btns = frame:Add("DPanel")
    btns:Dock(BOTTOM)
    btns:DockMargin(8, 4, 8, 8)
    btns:SetTall(30)
    btns.Paint = nil

    local saveBtn = btns:Add("DButton")
    saveBtn:Dock(LEFT)
    saveBtn:SetWide(140)
    saveBtn:SetText("Save to Server")
    saveBtn.DoClick = function()
        SendDisplayToServer(currentClass)
        chat.AddText(Color(180, 220, 180),
            "[ZScav] Sent display for " .. currentClass .. " to server.")
    end

    local printBtn = btns:Add("DButton")
    printBtn:Dock(LEFT)
    printBtn:SetWide(110)
    printBtn:DockMargin(4, 0, 0, 0)
    printBtn:SetText("Print to Lua")
    printBtn.DoClick = function()
        local disp = EnsureDisplay(currentClass)
        if not disp then return end
        local line = string.format(
            'ZSCAV.GearItems["%s"].display = { bone = "%s", pos = { x = %.2f, y = %.2f, z = %.2f }, ang = { p = %.2f, y = %.2f, r = %.2f }, scale = %.3f }',
            currentClass,
            tostring(disp.bone or "ValveBiped.Bip01_Spine2"),
            tonumber(disp.pos and disp.pos.x) or 0,
            tonumber(disp.pos and disp.pos.y) or 0,
            tonumber(disp.pos and disp.pos.z) or 0,
            tonumber(disp.ang and disp.ang.p) or 0,
            tonumber(disp.ang and disp.ang.y) or 0,
            tonumber(disp.ang and disp.ang.r) or 0,
            tonumber(disp.scale) or 1
        )
        print("[ZScav Display] " .. line)
        chat.AddText(Color(200, 230, 200), "[ZScav] Printed display for " .. currentClass .. " to console.")
    end

    local closeBtn = btns:Add("DButton")
    closeBtn:Dock(RIGHT)
    closeBtn:SetWide(80)
    closeBtn:SetText("Close")
    closeBtn.DoClick = function() frame:Close() end

    refreshFromClass()
end

concommand.Add("zscav_pack_tune", function(_, _, args)
    -- Backwards-compat CLI form: zscav_pack_tune <field> <value>
    if args[1] and tonumber(args[2]) then
        local class = GetWornBackpackClass(LocalPlayer())
        if not class then
            chat.AddText(Color(220, 120, 120), "[ZScav] No backpack worn.")
            return
        end
        local d = EnsureDisplay(class)
        if not d then return end
        local field = tostring(args[1]):lower()
        local val = tonumber(args[2])
        if     field == "posx"  then d.pos.x = val
        elseif field == "posy"  then d.pos.y = val
        elseif field == "posz"  then d.pos.z = val
        elseif field == "pitch" then d.ang.p = val
        elseif field == "yaw"   then d.ang.y = val
        elseif field == "roll"  then d.ang.r = val
        elseif field == "scale" then d.scale = val
        else chat.AddText("Unknown field: " .. field) return end
        PokeAttach()
        chat.AddText(Color(200, 220, 200),
            string.format("[ZScav] %s = %.2f (local-only; save via GUI)", field, val))
        return
    end
    BuildTuner()
end)
