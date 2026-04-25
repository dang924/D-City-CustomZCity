-- ─────────────────────────────────────────────────────────────────────────────
-- Solitron Heartbeat Sensor
--
-- Tablet-style life sensor inspired by the FPV tablet (model + open/close anim).
-- Reload toggles the radar HUD: a circular Solitron-style display with blinking
-- dots representing nearby living entities. Each dot's blink rate is tied to
-- that entity's organism heartbeat (BPM); 617 is highlighted, NPCs use a default
-- pulse, fresh ragdolls show as faint cooling dots.
-- ─────────────────────────────────────────────────────────────────────────────

if SERVER then AddCSLuaFile() end

-- Inherit the homigrad TPIK tablet base (same family as the FPV tablet /
-- motion tracker), so the radar registers through the hg weapon pipeline,
-- shows up in the spawnmenu's hg lists, and gets the standard tablet
-- world-model/holding behaviour for free.
SWEP.Base                   = "weapon_tpik_base"

SWEP.PrintName              = "Solitron Heartbeat Sensor"
SWEP.Author                 = "ZCity"
SWEP.Purpose                = "Reload to open the radar. Detects organism heart activity through walls."
SWEP.Instructions           = "Reload to toggle the radar HUD. Dots blink with each detected heartbeat. Subject 617 reads red; warm bodies linger as faint blue."
SWEP.Category               = "ZCity Other"

SWEP.Spawnable              = true
SWEP.AdminOnly              = false
SWEP.UseHands               = true

SWEP.ViewModel              = "models/v_item_pda.mdl"
SWEP.WorldModel             = "models/v_item_pda.mdl"
SWEP.WorldModelReal         = "models/v_item_pda.mdl"
SWEP.WorldModelExchange     = false
SWEP.ViewModelFOV           = 80
SWEP.SwayScale              = 0.1
SWEP.BobScale               = 0.1
SWEP.HoldType               = "slam"
SWEP.HoldPos                = Vector(-6, 0, -2)
SWEP.HoldAng                = Angle(-5, 0, 0)
SWEP.setlh                  = true
SWEP.setrh                  = true
SWEP.supportTPIK            = true

-- Tablet holding offset (positions the PDA screen in front of player's view).
-- Adjusted to push tablet forward and away from body for better visibility.
SWEP.offsetVec              = Vector(8, -8, 2)
SWEP.offsetAng              = Angle(-85, 180, 185)

-- Dummy primary/secondary so the homigrad base + hidden-loadout filter
-- accept the SWEP. Combat-irrelevant numbers; behaviour is fully overridden
-- by PrimaryAttack/Reload below.
SWEP.Primary.ClipSize       = 1
SWEP.Primary.DefaultClip    = 1
SWEP.Primary.Automatic      = false
SWEP.Primary.Ammo           = "none"
SWEP.Primary.Damage         = 1
SWEP.Primary.Wait           = 0.5

SWEP.Secondary.ClipSize     = -1
SWEP.Secondary.DefaultClip  = -1
SWEP.Secondary.Automatic    = false
SWEP.Secondary.Ammo         = "none"

SWEP.AutoSwitchTo           = false
SWEP.AutoSwitchFrom         = false
SWEP.Slot                   = 4
SWEP.SlotPos                = 5
SWEP.DrawCrosshair          = false
SWEP.DrawAmmo               = false

-- ── Hidden-mode loadout integration ──────────────────────────────────────
-- HiddenLoadoutAllow opts the radar into the hidden-mode IRIS loadout pool
-- without needing to satisfy the strict damage/clip/Base="homigrad_base"
-- filter normal weapons go through. HiddenLoadoutSlot pins it to the
-- secondary slot. Score is just the seed value; admins can override per
-- key from the loadout admin tab.
SWEP.HiddenLoadoutAllow     = true
SWEP.HiddenLoadoutSlot      = "secondary"
SWEP.HiddenLoadoutScore     = 30
SWEP.weaponInvCategory      = 2 -- secondary, mirrors hg pistol-class slotting

if CLIENT then
    SWEP.WepSelectIcon = Material("vgui/hud/offpv_tablet")
    SWEP.IconOverride  = "vgui/hud/offpv_tablet"
    SWEP.DrawWeaponInfoBox = false
    SWEP.BounceWeaponIcon  = false
end

-- ─── shared helpers ──────────────────────────────────────────────────────────

local SOLITRON_RANGE_INF = true -- whole map
local SOLITRON_NPC_DEFAULT_BPM = 70

local function getEntityOrganism(ent)
    if not IsValid(ent) then return nil end
    if ent.organism then return ent.organism end
    -- Players sometimes route their organism through the FakeRagdoll bone source.
    if ent:IsPlayer() and IsValid(ent.FakeRagdoll) and ent.FakeRagdoll.organism then
        return ent.FakeRagdoll.organism
    end
    return nil
end

local function getEntityBPM(ent)
    local org = getEntityOrganism(ent)
    if org and tonumber(org.heartbeat) then
        return math.Clamp(tonumber(org.heartbeat), 25, 220)
    end
    if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
        return SOLITRON_NPC_DEFAULT_BPM
    end
    return SOLITRON_NPC_DEFAULT_BPM
end

local function getDisplayPos(ent)
    -- Players riding a fake ragdoll keep the player ent at the ragdoll position
    -- already, but the ragdoll itself is the visible body — use it when valid.
    if IsValid(ent) and ent:IsPlayer() and IsValid(ent.FakeRagdoll) then
        return ent.FakeRagdoll:GetPos()
    end
    return ent:GetPos()
end

-- ─── SWEP behaviour ──────────────────────────────────────────────────────────

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self:SetWeaponHoldType(self.HoldType)
end

function SWEP:SetupDataTables()
    -- No longer using network vars; radar shows while R is held
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
    return true
end

function SWEP:Holster()
    return true
end

function SWEP:OnRemove()
end

function SWEP:PrimaryAttack()
    if self:GetNextPrimaryFire() > CurTime() then return end
    self:SetNextPrimaryFire(CurTime() + 0.5)
    -- Tap to ping (audible only to the wielder, no game effect).
    if CLIENT and IsValid(self:GetOwner()) and self:GetOwner() == LocalPlayer() then
        surface.PlaySound("buttons/button9.wav")
    end
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
    -- Do nothing on Reload press - we'll check the key during DrawHUD instead
    return false
end

-- ─── worldmodel positioning (hand-attached offset) ────────────────────────────

if CLIENT then
    function SWEP:DrawWorldModel2()
        local owner = self:GetOwner()
        
        -- Create or reuse the clientside model.
        if not IsValid(self.worldModel) then
            self.worldModel = ClientsideModel(self.WorldModel)
            self.worldModel:SetSkin(self.WMSkin or 0)
            self:CallOnRemove("remove_worldmodel", function()
                if IsValid(self.worldModel) then
                    self.worldModel:Remove()
                end
            end)
        end
        
        local model = self.worldModel
        if not IsValid(model) then return end
        
        model:SetNoDraw(true)
        model:SetModelScale(self.ModelScale or 1)
        
        -- If we have an owner holding it, check if R is being held
        if IsValid(owner) then
            local lply = LocalPlayer()
            local isReloading = lply:KeyDown(IN_RELOAD)
            
            if isReloading and owner == lply then
                -- R is held: raise tablet to face/head level and center it
                local headPos = owner:GetPos() + Vector(0, 0, 60)  -- Head height
                local eyeAng = owner:EyeAngles()
                
                -- Position tablet facing player's view direction
                local pos = headPos + eyeAng:Forward() * 15
                model:SetRenderOrigin(pos)
                model:SetRenderAngles(eyeAng)
            else
                -- Not held: position on hand with offset
                local boneid = owner:LookupBone("ValveBiped.Bip01_R_Hand")
                if boneid then
                    local matrix = owner:GetBoneMatrix(boneid)
                    if matrix then
                        local newPos, newAng = LocalToWorld(
                            self.offsetVec or Vector(0, 0, 0),
                            self.offsetAng or Angle(0, 0, 0),
                            matrix:GetTranslation(),
                            matrix:GetAngles()
                        )
                        model:SetRenderOrigin(newPos)
                        model:SetRenderAngles(newAng)
                    else
                        model:SetRenderOrigin(owner:GetPos())
                        model:SetRenderAngles(owner:GetAngles())
                    end
                else
                    model:SetRenderOrigin(owner:GetPos())
                    model:SetRenderAngles(owner:GetAngles())
                end
            end
        else
            -- Not held by anyone, position at weapon location.
            model:SetRenderOrigin(self:GetPos())
            model:SetRenderAngles(self:GetAngles())
        end
        
        model:DrawModel()
    end
end

-- ─── client HUD: Solitron radar ─────────────────────────────────────────────

if CLIENT then

    surface.CreateFont("SolitronRadar_Lg", { font = "Roboto", size = 22, weight = 600, antialias = true })
    surface.CreateFont("SolitronRadar_Sm", { font = "Roboto", size = 14, weight = 500, antialias = true })

    local COL_FRAME       = Color(8, 18, 12, 235)
    local COL_RING        = Color(60, 220, 120, 230)
    local COL_RING_DIM    = Color(40, 140, 80, 90)
    local COL_GRID        = Color(40, 160, 90, 60)
    local COL_TEXT        = Color(180, 255, 200, 240)
    local COL_TEXT_DIM    = Color(120, 200, 150, 180)
    local COL_SELF        = Color(120, 255, 200, 255)
    local COL_DOT_PLAYER  = Color(120, 255, 200)
    local COL_DOT_617     = Color(255, 80, 60)
    local COL_DOT_NPC     = Color(255, 180, 80)
    local COL_DOT_DEAD    = Color(160, 200, 220)
    local COL_SWEEP       = Color(120, 255, 180, 90)

    -- Soft world->radar projection. The whole map fits but close targets sit
    -- near the centre while distant ones approach (but never reach) the rim.
    local SOLITRON_PROJ_FALLOFF = 900 -- units per "screen" of distance
    local SOLITRON_DOT_BASE_SIZE = 7
    local SOLITRON_TICK = 0.25

    local function classifyTarget(ent, lply)
        if not IsValid(ent) then return nil end
        if ent == lply then return nil end

        if ent:IsPlayer() then
            if ent:Team() == TEAM_SPECTATOR then return nil end
            if not ent:Alive() then return nil end

            local pclass = ent.PlayerClassName or nil
            if pclass == "subject617" then
                return { kind = "617", color = COL_DOT_617, alive = true }
            end
            return { kind = "player", color = COL_DOT_PLAYER, alive = true }
        end

        if ent:IsNPC() or ent:IsNextBot() then
            if ent:Health() <= 0 then return nil end
            return { kind = "npc", color = COL_DOT_NPC, alive = true }
        end

        if ent:GetClass() == "prop_ragdoll" then
            local org = ent.organism
            if not org or not org.last_heartbeat then return nil end
            -- Mirrors the existing "still warm" window in weapon_hands_sh /
            -- weapon_hg_coolhands: bodies stay on the radar for ~2 minutes
            -- after the last heartbeat, fading to dim.
            local since = CurTime() - (org.last_heartbeat or 0)
            if since > 120 then return nil end
            return { kind = "dead", color = COL_DOT_DEAD, alive = false, coolFrac = since / 120 }
        end

        return nil
    end

    local function projectRelative(targetPos, eyePos, eyeYaw, radius)
        local rel = targetPos - eyePos
        rel:Rotate(Angle(0, -eyeYaw, 0))
        -- Source: +X forward, +Y left. Radar: +Y up (forward), +X right.
        local fx = -rel.y
        local fy = -rel.x
        local dist = math.sqrt(fx * fx + fy * fy)
        if dist < 0.5 then return 0, 0, 0 end

        -- Smooth diminishing-returns mapping: r/R = 1 - exp(-dist / falloff).
        -- Far targets approach but never touch the rim; close targets stay
        -- proportionally distinct rather than collapsing to centre.
        local frac = 1 - math.exp(-dist / SOLITRON_PROJ_FALLOFF)
        local r = radius * frac
        local nx = (fx / dist) * r
        local ny = (fy / dist) * r
        return nx, ny, dist
    end

    local function gatherTargets(lply)
        local out = {}
        for _, ent in ipairs(ents.GetAll()) do
            local cls = classifyTarget(ent, lply)
            if cls then
                cls.ent = ent
                cls.pos = getDisplayPos(ent)
                cls.bpm = getEntityBPM(ent)
                out[#out + 1] = cls
            end
        end
        return out
    end

    local function drawRadarFrame(cx, cy, radius)
        draw.NoTexture()

        -- Frame disc.
        surface.SetDrawColor(COL_FRAME)
        local segs = 64
        local poly = {}
        for i = 0, segs do
            local a = (i / segs) * math.pi * 2
            poly[#poly + 1] = { x = cx + math.cos(a) * radius, y = cy + math.sin(a) * radius }
        end
        surface.DrawPoly(poly)

        -- Concentric rings.
        for i = 1, 4 do
            local rr = radius * (i / 4)
            surface.SetDrawColor(i == 4 and COL_RING or COL_RING_DIM)
            local ring = {}
            for j = 0, 96 do
                local a = (j / 96) * math.pi * 2
                local nx = cx + math.cos(a) * rr
                local ny = cy + math.sin(a) * rr
                ring[#ring + 1] = nx
                ring[#ring + 1] = ny
            end
            for j = 1, #ring - 2, 2 do
                surface.DrawLine(ring[j], ring[j + 1], ring[j + 2], ring[j + 3])
            end
            surface.DrawLine(ring[#ring - 1], ring[#ring], ring[1], ring[2])
        end

        -- Cross-hair grid (N/S/E/W).
        surface.SetDrawColor(COL_GRID)
        surface.DrawLine(cx - radius, cy, cx + radius, cy)
        surface.DrawLine(cx, cy - radius, cx, cy + radius)
    end

    local function drawSweep(cx, cy, radius)
        local sweepAngle = (CurTime() * math.pi * 0.5) % (math.pi * 2) -- one revolution / 4s
        local segs = 28
        local arc = math.rad(38)
        local poly = { { x = cx, y = cy } }
        for i = 0, segs do
            local a = sweepAngle - (i / segs) * arc
            poly[#poly + 1] = {
                x = cx + math.cos(a) * radius,
                y = cy + math.sin(a) * radius,
            }
        end
        draw.NoTexture()
        surface.SetDrawColor(COL_SWEEP)
        surface.DrawPoly(poly)
    end

    local function drawDot(x, y, color, scale, alpha)
        local size = SOLITRON_DOT_BASE_SIZE * scale
        local c = Color(color.r, color.g, color.b, math.Clamp(alpha, 0, 255))
        draw.NoTexture()
        surface.SetDrawColor(c)
        local segs = 16
        local poly = {}
        for i = 0, segs do
            local a = (i / segs) * math.pi * 2
            poly[#poly + 1] = { x = x + math.cos(a) * size, y = y + math.sin(a) * size }
        end
        surface.DrawPoly(poly)

        -- Soft halo.
        c.a = math.Clamp(alpha * 0.35, 0, 255)
        surface.SetDrawColor(c)
        local poly2 = {}
        for i = 0, segs do
            local a = (i / segs) * math.pi * 2
            poly2[#poly2 + 1] = { x = x + math.cos(a) * size * 1.9, y = y + math.sin(a) * size * 1.9 }
        end
        surface.DrawPoly(poly2)
    end

    function SWEP:DrawHUD()
        local lply = LocalPlayer()
        if not IsValid(lply) then return end
        
        -- Only show radar when R is actively held down
        local isReloading = lply:KeyDown(IN_RELOAD)
        if not isReloading then return end
        
        -- Make sure this is the active weapon
        if lply:GetActiveWeapon() ~= self then return end

        local sw, sh = ScrW(), ScrH()
        
        -- Fullscreen radar: radius covers entire screen
        local cx = sw * 0.5
        local cy = sh * 0.5
        local radius = math.max(sw, sh) * 0.6

        drawRadarFrame(cx, cy, radius)
        drawSweep(cx, cy, radius)

        local eyePos = lply:EyePos()
        local eyeYaw = lply:EyeAngles().y
        local now = CurTime()

        -- Self marker (centred green dot, breathing with own BPM).
        do
            local bpm = getEntityBPM(lply)
            local period = 60 / math.max(bpm, 1)
            local phase  = (now % period) / period
            -- 25% of period as a sharp pulse, then resting.
            local pulse  = phase < 0.25 and (1 - phase / 0.25) or 0
            local scale  = 1 + pulse * 0.6
            drawDot(cx, cy, COL_SELF, scale, 230)
        end

        local targets = gatherTargets(lply)

        for _, t in ipairs(targets) do
            local nx, ny, dist = projectRelative(t.pos, eyePos, eyeYaw, radius)
            if dist > 0 then
                local x = cx + nx
                local y = cy + ny

                if t.alive then
                    -- 617: force extremely rapid threat heartbeat (~160 BPM) to stand out.
                    local bpm = (t.kind == "617") and 160 or math.max(t.bpm or SOLITRON_NPC_DEFAULT_BPM, 25)
                    local period = 60 / bpm
                    local phase = (now % period) / period
                    
                    local pulse
                    if t.kind == "617" then
                        -- 617 threat pattern: aggressive double-spike (two rapid pulses per period).
                        if phase < 0.1 then
                            pulse = 1 - phase / 0.1 * 0.4
                        elseif phase < 0.15 then
                            pulse = 0.6 + (0.15 - phase) / 0.05 * 0.4
                        elseif phase < 0.25 then
                            pulse = 0.6 - (phase - 0.15) / 0.1 * 0.5
                        else
                            pulse = 0.1
                        end
                    else
                        -- Standard pulse: full bright for first 18% of the period, then exponential decay.
                        if phase < 0.18 then
                            pulse = 1 - phase / 0.18 * 0.55
                        else
                            pulse = math.max(0.45 - (phase - 0.18) * 0.4, 0.18)
                        end
                    end

                    local alpha = 90 + pulse * 165
                    local scale = 0.85 + pulse * 0.7
                    
                    -- 617: draw as primary RED threat dot with aggressive jitter overlay.
                    if t.kind == "617" then
                        -- Main threat dot: RED with high opacity.
                        drawDot(x, y, COL_DOT_617, scale * 1.15, 200 + pulse * 55)
                        
                        -- Hostile jitter overlay: intense, rapid flicker.
                        local jitter = (math.sin(now * 35) + 1) * 0.5
                        drawDot(x, y, COL_DOT_617, scale * (1.2 + jitter * 0.25), 120 + pulse * 80)
                    else
                        drawDot(x, y, t.color, scale, alpha)
                    end
                else
                    -- Cooling body: very slow blink, fading with time-since-death.
                    local cool = 1 - (t.coolFrac or 0)
                    local period = 4
                    local phase = (now % period) / period
                    local pulse = phase < 0.4 and (1 - phase / 0.4) or 0
                    drawDot(x, y, t.color, 0.7 + pulse * 0.3, (40 + pulse * 70) * cool)
                end
            end
        end

        -- Header text (fullscreen size).
        draw.SimpleText("SOLITRON RADAR", "SolitronRadar_Lg", cx, cy - radius - 18,
            COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Footer: BPM and contact count.
        local ownBpm = getEntityBPM(lply)
        local statusText = string.format("BPM %d | Contacts: %d", math.floor(ownBpm + 0.5), #targets)
        draw.SimpleText(statusText, "SolitronRadar_Sm", cx, cy + radius + 10,
            COL_TEXT_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Compass markers (at screen edges for fullscreen display).
        draw.SimpleText("N", "SolitronRadar_Sm", cx, cy - radius - 4, COL_TEXT_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        draw.SimpleText("S", "SolitronRadar_Sm", cx, cy + radius + 4, COL_TEXT_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText("W", "SolitronRadar_Sm", cx - radius - 4, cy, COL_TEXT_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText("E", "SolitronRadar_Sm", cx + radius + 4, cy, COL_TEXT_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- Hide the player's own viewmodel only when the radar is closed (open looks
    -- nicer with the PDA on screen). Suppress the crosshair regardless.
    function SWEP:PreDrawViewModel()
    end

    function SWEP:DoDrawCrosshair()
        return true
    end
end

-- Range query exposed for any future net-driven extension. Currently unused.
SWEP.SOLITRON_RANGE_INF = SOLITRON_RANGE_INF
