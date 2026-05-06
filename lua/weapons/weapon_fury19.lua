if SERVER then AddCSLuaFile() end

SWEP.Base = "weapon_bandage_sh"
SWEP.PrintName = "Fury-19 'Overdrive'"
SWEP.Instructions = [[Fury-19 "Overdrive" is a highly unstable compound synthesized by combining 
Fury-13's berserk-inducing agents with Fury-16's synthetic noradrenaline in a 
single delivery system. The result is a drug that simultaneously pushes the body 
beyond all physical limits while flooding the brain with uncontrollable aggression.

The subject becomes faster, stronger, and violently hostile to everything — but the 
compound burns through the body at an alarming rate. Cardiac arrest, organ failure, 
and spontaneous cranial detonation are not side effects — they are certainties.

The only question is how much damage you do before it kills you.

Do NOT administer to infected, mutated, or previously stimulated subjects.]]

SWEP.Category = "ZCity Medicine"
SWEP.Spawnable = true
SWEP.Primary.Wait = 1
SWEP.Primary.Next = 0
SWEP.HoldType = "normal"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/bloocobalt/l4d/items/w_eq_adrenaline.mdl"

if CLIENT then
	SWEP.WepSelectIcon = Material("entities/zcity/fury19.png")
	SWEP.IconOverride = "entities/zcity/fury19.png"
	SWEP.BounceWeaponIcon = false
end

SWEP.AdminOnly = true
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Slot = 5
SWEP.SlotPos = 1
SWEP.WorkWithFake = true
SWEP.offsetVec = Vector(3, -2.5, -1)
SWEP.offsetAng = Angle(-30, 20, -90)
SWEP.ModelScale = 0.7
SWEP.Color = Color(255, 50, 180) -- Volatile pink/magenta — mix of Fury-13 orange and Fury-16 blue
SWEP.modeNames = {
	[1] = "fury-19"
}

function SWEP:InitializeAdd()
	self:SetHold(self.HoldType)

	self.modeValues = {
		[1] = 1
	}
end

SWEP.modeValuesdef = {
	[1] = 1
}

SWEP.DeploySnd = ""
SWEP.HolsterSnd = ""
SWEP.showstats = false

local hg_healanims = ConVarExists("hg_healanims") and GetConVar("hg_healanims") or CreateConVar("hg_healanims", 0, FCVAR_REPLICATED + FCVAR_ARCHIVE, "Toggle heal/food animations", 0, 1)

-----------------------------------------------------------
-- NPC faction tables for universal hostility (from Fury-13)
-----------------------------------------------------------
local combines = {
	"npc_combine_s",
	"npc_metropolice",
	"npc_helicopter",
	"npc_combinegunship",
	"npc_combine",
	"npc_stalker",
	"npc_hunter",
	"npc_strider",
	"npc_turret_floor",
	"npc_combine_camera",
	"npc_manhack",
	"npc_cscanner",
	"npc_clawscanner"
}

local rebels = {
	"npc_barney",
	"npc_citizen",
	"npc_dog",
	"npc_eli",
	"npc_kleiner",
	"npc_magnusson",
	"npc_monk",
	"npc_mossman",
	"npc_odessa",
	"npc_rollermine_hacked",
	"npc_turret_floor_resistance",
	"npc_vortigaunt",
	"npc_alyx"
}

local zombies = {
	"npc_fastzombie",
	"npc_fastzombie_torso",
	"npc_headcrab",
	"npc_headcrab_black",
	"npc_headcrab_fast",
	"npc_poisonzombie",
	"npc_zombie",
	"npc_zombie_torso",
	"npc_zombine"
}

local allFactions = {}
table.Add(allFactions, combines)
table.Add(allFactions, rebels)
table.Add(allFactions, zombies)

-----------------------------------------------------------
-- Think & Animation
-----------------------------------------------------------
function SWEP:Think()
	self:SetBodyGroups("11")
	if not self:GetOwner():KeyDown(IN_ATTACK) and hg_healanims:GetBool() then
		self:SetHolding(math.max(self:GetHolding() - 4, 0))
	end
end

function SWEP:Animation()
	local hold = self:GetHolding()
	self:BoneSet("r_upperarm", vector_origin, Angle(0, -hold + (100 * (hold / 100)), 0))
	self:BoneSet("r_forearm", vector_origin, Angle(-hold / 6, -hold * 2, -15))
end

-----------------------------------------------------------
-- NPC Healing + Overdrive behavior
-----------------------------------------------------------
function SWEP:NPCHeal(npc, mul, snd)
	if not npc then npc = self:GetOwner() end
	if not npc:IsNPC() then return end

	self:SetHold("melee")
	if not mul then mul = 0.3 end

	-- Massive heal (Fury-13 potency + Fury-16 efficiency)
	local maxHp = npc:GetMaxHealth()
	npc:SetHealth(math.Clamp(npc:Health() + (maxHp * 1 * mul), 0, maxHp * math.Clamp(2 * mul, 2, 100)))
	npc:EmitSound(snd or "snd_jack_hmcd_needleprick.wav", 80, math.random(85, 95))

	-- Combined speed boost: Fury-13's x2 + Fury-16's x6 = x4 (averaged, unstable)
	npc:SetPlaybackRate(4)
	npc:SetKeyValue("m_flPlaybackSpeed", 4)

	if not SERVER then return end

	local index = npc:EntIndex()

	-------------------------------------------------------
	-- Fury-13 component: Universal hostility
	-------------------------------------------------------
	npc:SetSquad("fury19_" .. index)

	for _, v in ipairs(ents.FindByClass("npc_*")) do
		if table.HasValue(allFactions, v:GetClass()) then
			v:AddEntityRelationship(npc, D_HT, 99)
			npc:AddEntityRelationship(v, D_HT, 99)
		end
	end

	for _, v in player.Iterator() do
		npc:AddEntityRelationship(v, D_HT, 99)
	end

	-- Dynamic hostility for future NPCs
	hook.Add("OnEntityCreated", "fury19_relations_" .. index, function(ent)
		if not IsValid(npc) or not npc:Alive() then
			hook.Remove("OnEntityCreated", "fury19_relations_" .. index)
			return
		end

		if ent:IsNPC() and table.HasValue(allFactions, ent:GetClass()) then
			ent:AddEntityRelationship(npc, D_HT, 99)
			npc:AddEntityRelationship(ent, D_HT, 99)
		end
	end)

	-------------------------------------------------------
	-- Fury-19 exclusive: Overdrive burnout timer
	-- The NPC is incredibly powerful but begins taking
	-- escalating damage after a short period as the
	-- compound tears their body apart from the inside.
	-------------------------------------------------------
	local burnoutDelay = 15 -- seconds of full power before burnout
	local burnoutStart = CurTime() + burnoutDelay
	local timerName = "fury19_burnout_" .. index

	timer.Create(timerName, 1, 0, function()
		if not IsValid(npc) or not npc:Alive() then
			timer.Remove(timerName)
			return
		end

		if CurTime() >= burnoutStart then
			local elapsed = CurTime() - burnoutStart
			local burnDamage = math.floor(5 + (elapsed * 3)) -- escalating damage

			local dmg = DamageInfo()
			dmg:SetDamage(burnDamage)
			dmg:SetDamageType(DMG_POISON)
			dmg:SetAttacker(npc)
			dmg:SetInflictor(npc)
			npc:TakeDamageInfo(dmg)

			-- Visual feedback: occasional sparks/smoke as the body fails
			local effectData = EffectData()
			effectData:SetOrigin(npc:GetPos() + Vector(0, 0, 40))
			effectData:SetScale(1)
			util.Effect("BloodImpact", effectData)

			-- Speed gradually drops as the body gives out
			local decayRate = math.max(4 - (elapsed * 0.1), 1)
			npc:SetPlaybackRate(decayRate)
			npc:SetKeyValue("m_flPlaybackSpeed", decayRate)
		end
	end)

	self:Remove()
end

-----------------------------------------------------------
-- Owner changed (NPC pickup)
-----------------------------------------------------------
function SWEP:OwnerChanged()
	local owner = self:GetOwner()
	if IsValid(owner) and owner:IsNPC() then
		self:SpawnGarbage(nil, nil, nil, self.Color, "2211")
		self:NPCHeal(owner, 60, "snd_jack_hmcd_needleprick.wav")
	end
end

-----------------------------------------------------------
-- Player healing
-----------------------------------------------------------
if SERVER then
	function SWEP:Heal(ent, mode)
		-- NPC injection path
		if ent:IsNPC() then
			self:SpawnGarbage(nil, nil, nil, self.Color, "2211")
			self:NPCHeal(ent, 60, "snd_jack_hmcd_needleprick.wav")
			return
		end

		local org = ent.organism
		if not org then return end

		local owner = self:GetOwner()

		-- Animation gating
		if ent == hg.GetCurrentCharacter(owner) and hg_healanims:GetBool() then
			self:SetHolding(math.min(self:GetHolding() + 4, 100))
			if self:GetHolding() < 100 then return end
		end

		local entOwner = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
		entOwner:EmitSound("snd_jack_hmcd_needleprick.wav", 80, math.random(60, 75)) -- Deep, ominous pitch

		---------------------------------------------------
		-- Lethality checks — both original kill conditions
		-- Since this drug contains BOTH compounds,
		-- having ANY prior stimulant is fatal.
		---------------------------------------------------
		if org.noradrenaline >= 0.4 or org.berserk >= 0.4 then
			hg.ExplodeHead(ent)
			self:SpawnGarbage(nil, nil, nil, self.Color, "2211")
			self:Remove()
			return
		end

		---------------------------------------------------
		-- Furry class: both drugs reject the host violently
		---------------------------------------------------
		if ent.PlayerClassName and ent.PlayerClassName == "furry" then
			org.o2["curregen"] = 0
			org.o2["regen"] = 0
			org.poison4 = CurTime()
			org.internalBleed = org.internalBleed + 25 -- Amplified from Fury-13's 10
			self:SpawnGarbage(nil, nil, nil, self.Color, "2211")
			owner:SelectWeapon("weapon_hands_sh")
			self:Remove()
			return
		end

		---------------------------------------------------
		-- Apply BOTH effects simultaneously
		---------------------------------------------------
		org.berserk = org.berserk + 2        -- Fury-13 component
		org.noradrenaline = org.noradrenaline + 1.25 -- Fury-16 component

		---------------------------------------------------
		-- Fury-19 exclusive: Overdrive burnout for players
		-- After a grace period, the body starts failing.
		---------------------------------------------------
		local burnoutDelay = 30 -- Players get more time than NPCs
		local burnoutStart = CurTime() + burnoutDelay
		local steamId = owner:SteamID64() or tostring(owner:EntIndex())
		local timerName = "fury19_player_burnout_" .. steamId

		timer.Create(timerName, 2, 0, function()
			if not IsValid(ent) or not ent:Alive() then
				timer.Remove(timerName)
				return
			end

			if not ent.organism then
				timer.Remove(timerName)
				return
			end

			if CurTime() >= burnoutStart then
				local elapsed = CurTime() - burnoutStart
				local org2 = ent.organism

				-- Internal bleeding increases over time
				if org2.internalBleed then
					org2.internalBleed = org2.internalBleed + (1 + elapsed * 0.5)
				end

				-- Noradrenaline and berserk slowly decay
				if org2.noradrenaline then
					org2.noradrenaline = math.max(org2.noradrenaline - 0.02, 0)
				end
				if org2.berserk then
					org2.berserk = math.max(org2.berserk - 0.03, 0)
				end

				-- Once both compounds have fully metabolized, stop
				if (org2.noradrenaline or 0) <= 0 and (org2.berserk or 0) <= 0 then
					timer.Remove(timerName)
				end
			end
		end)

		---------------------------------------------------
		-- Poisoned syringe interaction
		---------------------------------------------------
		if self.poisoned2 then
			org.poison4 = CurTime()
			self.poisoned2 = nil
		end

		---------------------------------------------------
		-- Consume the drug
		---------------------------------------------------
		self.modeValues[1] = 0
		owner:SelectWeapon("weapon_hands_sh")
		self:SpawnGarbage(nil, nil, nil, self.Color, "2211")
		self:Remove()
	end
end