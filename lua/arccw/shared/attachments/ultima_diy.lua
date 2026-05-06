att.PrintName = "DIY Ultima Thermal camera (1x)"
att.AbbrevName = "DIY Ultima Thermal"
att.Icon = Material("entities/kalashnikovlogo.png")
att.Description = "A special thermal imaging camera for the `Ultima` modification for the MP-155 shotgun with slapped screen from mentioned screen on back of it. Original manufactured by Kalashnikov Group."

att.SortOrder = 3

att.Desc_Pros = {
    "autostat.holosight",
    "autostat.thermal"
}
att.Desc_Cons = {
    "- May reduce visual awareness",
    "Looks stupid",
    "15 Hz low refresh rate",
}

att.AutoStats = true
att.Slot = {"optic", "eft_optic_medium"} -- Escape From Tarkov Tactial Realism Lewd SCP MODS Garry's Mod Workshop EFT ARCCW guns Online High octane gameplay 

att.Model = "models/weapons/arccw_ushanka/ultima.mdl"

att.ModelOffset = Vector(-1, 0, 0.18)
att.AdditionalSights = {
    {
        Pos = Vector(0, 10, -1.08),
        Ang = Angle(0, 0, 0),
        Magnification = 1.1,
        ScopeMagnification = 1.2,
        Thermal = true,
        ThermalScopeColor = {r=255+0, g=255+1, b=255+16/255}, --color() is limiting to 255 and artcic code is stupid but we ar e smarter
        ThermalHighlightColor = {r=-255, g=-255, b=-255},
        ThermalFullColor = true,
        ThermalScopeSimple = false,
        ThermalNoCC = false,
        ThermalBHOT = false,
        IgnoreExtra = true,
        Contrast = 0.5,
        Brightness = 0.1,
        Colormult = 0.12,
        ForceLowRes = true,
        FPSLock = 15,
        --SpecialScopeFunction = function(screen)
            --render.PushRenderTarget(screen)
            
            --DrawBloom(0,0.3,5,5,3,0.5,1,1,1)
            --DrawSharpen(1,1.65)
            --DrawMotionBlur(0.45,1,1/45)

            --render.PopRenderTarget()
        --end,
    },
}

att.ScopeGlint = true 

att.Holosight = true
att.HolosightReticle = Material("materials/hud/scopes/ultimareticle3.png", "mips smooth")
att.HolosightNoFlare = true
att.HolosightSize = 14
att.HolosightBone = "holosight"
att.HolosightPiece = "models/weapons/arccw_ushanka/ultima_hsp.mdl"
att.Colorable = false

-- att.HolosightMagnificationMin = 2,
-- att.HolosightMagnificationMax = 9,

att.HolosightBlackbox = true

att.HolosightMagnification = 1.1

att.Mult_SightTime = 1.4
att.Mult_SightedSpeedMult = 0.8