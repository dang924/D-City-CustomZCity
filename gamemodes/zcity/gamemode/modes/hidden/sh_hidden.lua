local MODE = MODE

zb = zb or {}
zb.Points = zb.Points or {}

zb.Points.HDN_SUBSPAWN = zb.Points.HDN_SUBSPAWN or {}
zb.Points.HDN_SUBSPAWN.Color = Color(170, 30, 30)
zb.Points.HDN_SUBSPAWN.Name = "HDN_SUBSPAWN"

zb.Points.HDN_IRISSPAWN = zb.Points.HDN_IRISSPAWN or {}
zb.Points.HDN_IRISSPAWN.Color = Color(25, 110, 210)
zb.Points.HDN_IRISSPAWN.Name = "HDN_IRISSPAWN"

zb.Points.HDN_HIDDEN = zb.Points.HDN_HIDDEN or {}
zb.Points.HDN_HIDDEN.Color = Color(170, 30, 30)
zb.Points.HDN_HIDDEN.Name = "HDN_HIDDEN"

zb.Points.HDN_IRIS = zb.Points.HDN_IRIS or {}
zb.Points.HDN_IRIS.Color = Color(25, 110, 210)
zb.Points.HDN_IRIS.Name = "HDN_IRIS"

zb.Points.HDN_EXTRACT = zb.Points.HDN_EXTRACT or {}
zb.Points.HDN_EXTRACT.Color = Color(245, 188, 72)
zb.Points.HDN_EXTRACT.Name = "HDN_EXTRACT"

zb.Points.HDN_INTEL = zb.Points.HDN_INTEL or {}
zb.Points.HDN_INTEL.Color = Color(190, 150, 60)
zb.Points.HDN_INTEL.Name = "HDN_INTEL"

MODE.name = "hidden"
MODE.PrintName = "Hidden"

MODE.ROUND_TIME = 300
MODE.start_time = 60
MODE.end_time = 7

MODE.ForBigMaps = false
MODE.Chance = 0
MODE.LootSpawn = false
MODE.OverrideSpawn = true

MODE.HiddenConfig = {
    PrepDuration = 60,
    CombatDuration = 240,
    LoadoutBudget = 170,
    PrimaryAmmoMultiplier = 3,
    SecondaryAmmoMultiplier = 2,
    HiddenHealth = 325,
    IrisHealth = 100,
    HiddenRunSpeed = 360,
    HiddenWalkSpeed = 250,
    IrisRunSpeed = 235,
    IrisWalkSpeed = 170,
    HiddenJumpPower = 240,
    IrisJumpPower = 200,
    HiddenGravity = 0.75,
    IrisGravity = 1,
    ExtractRadius = 220,
    IntelSpawnDelay = 60,
    LeapCooldown = 6,
    LeapForce = 925,
    LeapUpForce = 260,
    LeapDuration = 0.7,
    LeapImpactGrace = 0.9,
    LeapImpactBerserk = 0.35,
    LeapRange = 80,
    LeapDamage = 95,
}

MODE.ROUND_TIME = MODE.HiddenConfig.PrepDuration + MODE.HiddenConfig.CombatDuration
MODE.start_time = 1

function MODE:HG_MovementCalc_2(mul, ply, cmd, mv)
    local prepActive = self.IsHiddenPreparationPhase and self:IsHiddenPreparationPhase()
    if prepActive and cmd then
        cmd:RemoveKey(IN_ATTACK)
        cmd:RemoveKey(IN_ATTACK2)

        if mv then
            mv:RemoveKey(IN_ATTACK)
            mv:RemoveKey(IN_ATTACK2)
        end

        if IsValid(ply) and IsValid(ply:GetWeapon("weapon_hands_sh")) then
            cmd:SelectWeapon(ply:GetWeapon("weapon_hands_sh"))
            if SERVER then
                ply:SelectWeapon("weapon_hands_sh")
            end
        end
    end
end

function MODE:PlayerCanLegAttack()
    local prepActive = self.IsHiddenPreparationPhase and self:IsHiddenPreparationPhase()
    if prepActive then
        return false
    end
end