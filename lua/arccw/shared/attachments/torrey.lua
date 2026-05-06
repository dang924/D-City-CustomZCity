att.PrintName = "Torrey Pines Logic T12W Thermal Reflex Sight"
att.AbbrevName = "Torrey Thermal Reflex"
att.Icon = Material("entities/torreylogo.png")
att.Description = "A compact thermal reflex sight with a low frequency. Manufactured by Torrey Pines Logic."

att.SortOrder = 3

att.Desc_Pros = {
    "autostat.holosight",
    "autostat.thermal"
}
att.Desc_Cons = {
    "Small screen",
    "Low resolution",
    "10 Hz low refresh rate",
}

att.AutoStats = true
att.Slot = {"optic", "optic_lp", "eft_optic_medium", "eft_optic_small"} -- Escape From Tarkov Tactial Realism Lewd SCP MODS Garry's Mod Workshop EFT ARCCW guns Online High octane gameplay 

att.Model = "models/weapons/arccw_ushanka/torrey.mdl"

att.ModelOffset = Vector(0, 0, 0.18)
att.AdditionalSights = {
    {
        Pos = Vector(0, 15, -0.8),
        Ang = Angle(0, 0, 0),
        Magnification = 1,
        ScopeMagnification = 1.1,
        Thermal = true,
        ThermalScopeColor = {r=255, g=255+1.4, b=255+5.1}, --color() is limiting to 255 and artcic code is stupid but we ar e smarter
        ThermalHighlightColor = {r=255+1.2, g=255-0.4, b=255-0.4},
        ThermalFullColor = true,
        ThermalScopeSimple = false,
        ThermalNoCC = false,
        ThermalBHOT = false,
        IgnoreExtra = true,
        Contrast = 0.2,
        Brightness = -1.32,
        Colormult = 0.4,
        ForceLowRes = true,
        FPSLock = 10,
        -- DrawAlways = true, -- expensive
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
att.HolosightReticle = Material("materials/hud/scopes/torreyreticle.png", "mips smooth")
att.HolosightNoFlare = true
att.HolosightSize = 4.7
att.HolosightBone = "holosight"
att.HolosightPiece = "models/weapons/arccw_ushanka/torrey_hsp.mdl"
att.Colorable = false

-- att.HolosightMagnificationMin = 2,
-- att.HolosightMagnificationMax = 9,

att.HolosightBlackbox = false

att.HolosightMagnification = 1.1

att.Mult_SightTime = 1.15
att.Mult_SightedSpeedMult = 0.9


-- att.DrawFunc = function(wep, element, wm) 
--     if !wm then
--         if element and IsValid(element.Model) then
--             if GetConVar("arccw_cheapscopes"):GetBool() then
--                 element.Model:SetSubMaterial(1, nil)
--             else
--                 element.Model:SetSubMaterial(1, "!arccw_rtsubmat")
--             end
--         end
--     end
-- end