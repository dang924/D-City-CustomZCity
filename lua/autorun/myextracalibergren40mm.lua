--taken(stolen) from asirius addon LOL - https://steamcommunity.com/sharedfiles/filedetails/?id=3659353345&searchtext=zcity+additional
--[[
    .408 Cheytac Ammo Type for HG Ammo System
    Исправленная версия
]]

-- Проверяем, существует ли основная таблица аммо
if not hg or not hg.ammotypes then
    ErrorNoHalt("[Grenade 40mm] Ошибка: основная система аммо не найдена!\n")
    return
end

--=\\Explosive Projectile
local function draw_explosive(self)
	if(IsValid(self.Draw_Model))then
		--
	else
		local model_ent = ClientsideModel(self.FunctionInfo.Model)
		self.Draw_Model = model_ent
	end
	
	local model_ent = self.Draw_Model
	local vel_ang = self.Vel:Angle()
	
	model_ent:SetPos(self.Pos)
	model_ent:SetAngles(vel_ang)
end

local function preremove_explosive(self)
	if(IsValid(self.Draw_Model))then
		self.Draw_Model:Remove()
	end
end

local function onstopped_explosive(self, last_unsure_penetration_pos, reason, trace)
	if(SERVER)then
		if(!trace or !trace.HitSky)then
			local attacker = self.Shooter
			local pos = self.Pos - self.Vel:GetNormalized() * 2
			local vec_cone = Vector(0, 0, 0)
			local shrapnel_coroutine_id = #APScheduledExplosions + 1
			
			util.ScreenShake(self.Pos, 35, 1, 1, 3000)

			timer.Simple(.01,function()
				ParticleEffect("pcf_jack_airsplode_small3",pos + vector_up * 1,-vector_up:Angle())
			end)

			net.Start("projectileFarSound")
				net.WriteString("m67/m67_detonate_01.wav")
				net.WriteString("m67/m67_detonate_far_dist_03.wav")
				net.WriteVector(pos)
				net.WriteEntity(Entity(0))
				net.WriteBool(false)
				net.WriteString("")
			net.Broadcast()
			
			util.BlastDamage(Entity(0), IsValid(attacker) and attacker or Entity(0), self.Pos, 100, 50)
			hg.ExplosionEffect(self.Pos, 1500 / 0.01905, 250)

			--local effectdata = EffectData()
			--effectdata:SetOrigin(selfPos)
			--effectdata:SetScale(0.9)
			--util.Effect("eff_jack_fragsplosion", effectdata)
	
			timer.Simple(.15,function()
				local coroutine_antilag = coroutine.create(function()
					local last_shrapnel = SysTime()

					for i = 1, 600 do
						last_shrapnel = SysTime()
						local dir = VectorRand(-1, 1)
						
						dir:Normalize()
						
						dir[3] = dir[3] > 0 and math.abs(dir[3] - 0.5) or -math.abs(dir[3] + 0.5)
						
						dir:Normalize()
						
						local bullet = {}
						bullet.Src = pos
						bullet.Spread = vec_cone
						bullet.Force = 4
						bullet.Damage = 40
						bullet.AmmoType = "Metal Debris"
						bullet.Attacker = game.GetWorld()
						bullet.Inflictor = attacker
						bullet.Distance = 567
						bullet.DisableLagComp = true
						bullet.Dir = dir
						
						game.GetWorld():FireLuaBullets(bullet, true)

						last_shrapnel = SysTime() - last_shrapnel

						if(last_shrapnel > 0.001)then
							coroutine.yield()
						end
					end
					
					APScheduledExplosions[shrapnel_coroutine_id] = nil
				end)

				APScheduledExplosions[shrapnel_coroutine_id] = coroutine_antilag
				
				coroutine.resume(coroutine_antilag)
			end)
			util.ScreenShake( self.Pos, 35, 1, 1, 1000, true )
		end
	end
end

-- Материал для иконки (используем существующий или создаем новый)
local matRfileAmmo = Material("vgui/hud/bullets/high_caliber.png")

-- Добавляем .408 Cheytac в таблицу ammotypes
hg.ammotypes["grenade40mm"] = {
		name = "Grenade 40mm",
		dmgtype = DMG_CLUB,
		tracer = TRACER_LINE,
		plydmg = 0,
		npcdmg = 0,
		force = 150,
		maxcarry = 120,
		minsplash = 10,
		maxsplash = 5,
		TracerSetings = {
			MaxPathPoints = 5,
		},
		BulletSettings = {
			Mass = 220,
			PhysPenetrationMul = 0.0,
			-- Speed = 185,
			Speed = 60,	--; Comically slow
			LifeTime = 15,
			Shell = "12guage",
			Icon = matRfileAmmo,
            noricochet = true,
		},
		FunctionInfo = {
			Model = "models/Items/AR2_Grenade.mdl",
			-- Ent = "crossbow_projectile",
		},
		BulletFunctions = {
			Draw = draw_explosive,
			OnStopped = onstopped_explosive,
			PreRemove = preremove_explosive,
		},
	}

-- Добавляем энтити для патронов
if not hg.ammoents then
    hg.ammoents = hg.ammoents or {}
end

hg.ammoents["grenade40mm"] = {
		Icon = "vgui/hud/ahuetzcity",
		Count = 3
	}

-- Регистрируем тип аммо если игра уже загружена
local function register40mm()
    -- Добавляем в game.GetAmmoTypes
    game.AddAmmoType(hg.ammotypes["grenade40mm"])
    
    -- Регистрируем энтити
    if CLIENT then
        -- ВАЖНО: имя для language.Add должно совпадать с name из таблицы + "_ammo"
        language.Add("Grenade 40mm_ammo", "Grenade 40mm")
    end
    
    local ammoent = {}
    ammoent.Base = "ammo_base"
    ammoent.PrintName = "Grenade 40mm"
    ammoent.Category = "ZCity Ammo"
    ammoent.Spawnable = true
    ammoent.AmmoCount = hg.ammoents["grenade40mm"].Count or 3
    -- ВАЖНО: AmmoType должно быть точно таким же, как name в таблице ammotypes
    ammoent.AmmoType = "Grenade 40mm"
    ammoent.Model = "models/Items/BoxMRounds.mdl"
    ammoent.ModelMaterial = hg.ammoents["grenade40mm"].Material or ""
    ammoent.ModelScale = hg.ammoents["grenade40mm"].Scale or 1.0
    ammoent.Color = hg.ammoents["grenade40mm"].Color or Color(218, 165, 32)
    
    scripted_ents.Register(ammoent, "ent_ammo_grenade40mm")
    
    -- Перестраиваем типы аммо
    game.BuildAmmoTypes()
    
    print("[Grenade 40mm] Успешно загружен!")
end

if game.IsDedicated() or game.GetMap() ~= "" then
    register40mm()
else
    hook.Add("Initialize", "init-ammo-40mm", register40mm)
end

-- Добавляем в таблицу allowed если она существует
if hg.ammotypesallowed then
    -- В этой таблице ключи - это отображаемые имена (name)
    hg.ammotypesallowed["Grenade 40mm"] = hg.ammotypes["grenade40mm"]
end

-- Добавляем в таблицу обратного соответствия если она существует
if hg.ammotypeshuy then
    -- В этой таблице ключи - отображаемые имена, значения - таблицы с добавленным полем name (ключ)
    hg.ammotypeshuy["Grenade 40mm"] = table.Copy(hg.ammotypes["grenade40mm"])
    hg.ammotypeshuy["Grenade 40mm"].name = "grenade40mm"
end

-- Создаем обратную связь для системы дропа
if SERVER then
    -- Добавляем хук для обработки создания энтити при дропе
    hook.Add("PlayerAmmoDrop", "40mm_drop_fix", function(ply, ammotype, count)
        -- Если это наш калибр, убеждаемся что создается правильная энтити
        if ammotype == "grenade40mm" then
            -- Эта функция будет вызвана из основного кода дропа
            -- Мы ничего не делаем, просто даем основному коду работать
        end
    end)
end

print("[Grenade 40mm] Файл загружен, используйте ключ 'Grenade 40mm' в коде винтовки")

--[[Проверяем существование системы
if not hg or not hg.ammotypes then return end

-- 1. ОСНОВНАЯ ТАБЛИЦА КАЛИБРА (в hg.ammotypes)
hg.ammotypes["НАЗВАНИЕ_КЛЮЧ"] = {  -- Ключ маленькими буквами, без пробелов
    name = "Отображаемое Имя",      -- То что видит игрок
    allowed = true,                  -- Разрешен ли в игре
    dmgtype = DMG_BULLET,            -- Тип урона (обычно DMG_BULLET)
    tracer = TRACER_LINE,            -- Тип трассера
    
    -- Стандартные параметры (для game.AddAmmoType)
    plydmg = 0,                       -- Урон по игрокам (обычно 0)
    npcdmg = 0,                        -- Урон по NPC (обычно 0)
    force = ЧИСЛО,                     -- Базовая сила (для стандартной системы)
    maxcarry = ЧИСЛО,                   -- Максимум в инвентаре
    minsplash = ЧИСЛО,                   -- Мин. радиус разбрызга
    maxsplash = ЧИСЛО,                    -- Макс. радиус разбрызга
    
    -- Настройки трассера (визуал)
    TracerSetings = {
        TracerBody = Material("particle/fire"),
        TracerTail = Material("effects/laser_tracer"),
        TracerHeadSize = ЧИСЛО,        -- Размер головы трассера
        TracerLength = ЧИСЛО,           -- Длина хвоста
        TracerWidth = ЧИСЛО,             -- Толщина
        TracerColor = Color(R,G,B),       -- Цвет
        TracerTPoint1 = 0.25,               -- Точка начала (обычно 0.25)
        TracerTPoint2 = 1,                    -- Точка конца (обычно 1)
        TracerSpeed = ЧИСЛО,                    -- Скорость отрисовки
        -- NoSpin = true,                    -- Если нужно отключить вращение
    },
    
    -- Настройки баллистики (для hg.PhysBullet)
    BulletSettings = {
        Damage = ЧИСЛО,                    -- Урон
        Force = ЧИСЛО,                      -- Сила толчка (кастомная)
        Penetration = ЧИСЛО,                  -- Пробиваемость
        Shell = "НАЗВАНИЕ",                     -- Тип гильзы (для эффектов)
        Speed = ЧИСЛО,                           -- Скорость пули (м/с)
        Diameter = ЧИСЛО,                          -- Калибр в мм
        Mass = ЧИСЛО,                               -- Масса пули в граммах
        AirResistMul = 0.000Х,                        -- Сопротивление воздуха
        Icon = Material("путь/к/иконке"),               -- Иконка в инвентаре
        -- Доп. параметры по желанию:
        -- NumBullet = ЧИСЛО,                           -- Для дробовых (кол-во pellets)
        -- PhysPenetrationMul = ЧИСЛО,                   -- Множитель пробития физики
        -- Distance = ЧИСЛО,                             -- Макс. дистанция
    }
}

-- 2. ТАБЛИЦА ЭНТИТИ (модель патронов в hg.ammoents)
hg.ammoents["НАЗВАНИЕ_КЛЮЧ"] = {  -- Тот же ключ что и выше
    Material = "путь/к/материалу",     -- Материал для модели
    -- ИЛИ
    -- Model = "путь/к/модели.mdl",    -- Если используется кастомная модель
    
    Scale = ЧИСЛО,                      -- Масштаб модели
    Color = Color(R,G,B),                -- Цвет модели
    Count = ЧИСЛО,                        -- Сколько патронов в коробке
}

-- 3. РЕГИСТРАЦИЯ ЭНТИТИ
local function registerNewAmmo()
    -- Регистрируем тип в game.AddAmmoType
    game.AddAmmoType(hg.ammotypes["НАЗВАНИЕ_КЛЮЧ"])
    
    -- Для клиента добавляем языковую строку
    if CLIENT then
        language.Add("Отображаемое Имя_ammo", "Отображаемое Имя")
    end
    
    -- Создаем таблицу энтити
    local ammoent = {}
    ammoent.Base = "ammo_base"
    ammoent.PrintName = "Отображаемое Имя"
    ammoent.Category = "ZCity Ammo"
    ammoent.Spawnable = true
    ammoent.AmmoCount = hg.ammoents["НАЗВАНИЕ_КЛЮЧ"].Count or 30
    ammoent.AmmoType = "Отображаемое Имя"
    ammoent.Model = "models/props_lab/box01a.mdl"  -- или кастомная
    ammoent.ModelMaterial = hg.ammoents["НАЗВАНИЕ_КЛЮЧ"].Material or ""
    ammoent.ModelScale = hg.ammoents["НАЗВАНИЕ_КЛЮЧ"].Scale or 1
    ammoent.Color = hg.ammoents["НАЗВАНИЕ_КЛЮЧ"].Color or Color(255,255,255)
    
    -- Регистрируем энтити
    scripted_ents.Register(ammoent, "ent_ammo_НАЗВАНИЕ_КЛЮЧ")
    
    -- Перестраиваем типы аммо
    game.BuildAmmoTypes()
end

-- Вызываем регистрацию
if game.IsDedicated() or game.GetMap() ~= "" then
    registerNewAmmo()
else
    hook.Add("Initialize", "init-ammo-НАЗВАНИЕ_КЛЮЧ", registerNewAmmo)
end

-- 4. ДОБАВЛЯЕМ В ДОП. ТАБЛИЦЫ (если нужны)
if hg.ammotypesallowed then
    hg.ammotypesallowed["Отображаемое Имя"] = hg.ammotypes["НАЗВАНИЕ_КЛЮЧ"]
end

if hg.ammotypeshuy then
    hg.ammotypeshuy["Отображаемое Имя"] = table.Copy(hg.ammotypes["НАЗВАНИЕ_КЛЮЧ"])
    hg.ammotypeshuy["Отображаемое Имя"].name = "НАЗВАНИЕ_КЛЮЧ"
end

print("[Отображаемое Имя] Загружен! Ключ: 'НАЗВАНИЕ_КЛЮЧ'")
]]