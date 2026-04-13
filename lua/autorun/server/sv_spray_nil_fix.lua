-- Fix: sh_spray.lua line 46 crashes with "attempt to perform arithmetic on field 'SprayI' (a nil value)"
-- This happens when a weapon fires before Initialize_Spray() has run (e.g. during mass-kill events
-- like simultaneous strider detonations causing rapid weapon re-equip/transfer in the same tick).
-- Initialize_Spray sets SprayI = 0, but if it hasn't been called yet PrimarySpread crashes.

hook.Add("WeaponEquip", "DCityPatch_SprayI_SafeGuard", function(wep, ply)
    if wep.SprayI == nil then
        wep.SprayI = 0
        wep.dmgStack = wep.dmgStack or 0
        wep.dmgStack2 = wep.dmgStack2 or 0
        wep.EyeSpray = wep.EyeSpray or Angle(0, 0, 0)
        wep.EyeSprayVel = wep.EyeSprayVel or Angle(0, 0, 0)
    end
end)

-- Secondary guard: patch Step_Spray which also reads SprayI (line 186)
-- and EyeSpray/EyeSprayVel which are set in Initialize_Spray
hook.Add("OnEntityCreated", "DCityPatch_SprayI_EntityGuard", function(ent)
    if not IsValid(ent) or not ent.PrimarySpread then return end
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        if ent.SprayI == nil then
            ent.SprayI = 0
            ent.dmgStack = ent.dmgStack or 0
            ent.dmgStack2 = ent.dmgStack2 or 0
            ent.EyeSpray = ent.EyeSpray or Angle(0, 0, 0)
            ent.EyeSprayVel = ent.EyeSprayVel or Angle(0, 0, 0)
        end
    end)
end)
