-- МОИ ДОПОЛНИТЕЛЬНЫЕ ОБВЕСЫ ДЛЯ ZCITY
-- Файл: addons/my_attachments/lua/autorun/sh_my_attachments.lua

-- Проверяем, существует ли основная таблица
if not hg then hg = {} end
if not hg.attachments then hg.attachments = {} end

-- #####################################################################
-- ####################   ТВОИ НОВЫЕ ОБВЕСЫ   #########################
-- #####################################################################

-- Добавляем в существующие категории (или создаем, если их нет)
hg.attachments.sight = hg.attachments.sight or {}
hg.attachments.barrel = hg.attachments.barrel or {}
hg.attachments.underbarrel = hg.attachments.underbarrel or {}
hg.attachments.grip = hg.attachments.grip or {}
hg.attachments.mount = hg.attachments.mount or {}

-- ===================== НОВЫЙ ПРИЦЕЛ =====================

hg.attachments.sight["sightmgl"] = {
		"sight",
		"models/weapons/arc9/darsu_eft/mods/sight_m2a1.mdl",
		Angle(0, 0, -90),
		offset = Vector(-0.5, -0.0, 0),
		offsetView = Vector(-2.0, 0, 0),
		{},
		mountType = "picatinny",
		holotex = "models/weapons/arc9_eft_shared/atts/optic/transparent_glass",

		holo = Material("entities/m2a1/scope_all_milkor_m2a1_reflex_sight_mark.png"),
		holo_size = CLIENT and ScreenScale(0.5) or 1, --size of the holo
		holo_lum = 5,
		PhysModel = "models/hunter/plates/plate025.mdl",
		PhysPos = Vector(0, 0, 0),
		PhysAng = Angle(0, 90, 0),
		valid = true,
	}

	hg.attachments.underbarrel["flashlightshot0"] = {
		"underbarrel", -- integrated
		(CLIENT and "models/hunter/plates/plate.mdl") or "",
		Angle(0, -8, 0),
		{
			[0] = "null"
		},
		offset = Vector(-2, 1.9, 0.2),
		offsetPos = Vector(0, -0, 0),
		color = Color(255, 0, 0, 250),
		supportFlashlight = true,
		mat = nil,
		farZ = 300,
		size = 40,
		brightness = 20,
		brightness2 = 0,
		shouldalwaysdraw = true,
	}



hg.attachmentslaunguage = hg.attachmentslaunguage or {}
hg.attachmentsIcons = hg.attachmentsIcons or {}

-- Добавляем названия (то, что будет отображаться в инвентаре)
hg.attachmentslaunguage["sightmgl"] = "M2A1 Reflex Sight"

-- Добавляем иконки (если есть файлы иконок)
-- hg.attachmentsIcons["ironsight5"] = "vgui/my_attachments/scar_iron"
hg.attachmentsIcons["sightmgl"] = "entities/m2a1/m2a.png"

-- #####################################################################
-- ###############   ДОБАВЛЯЕМ В VALIDATTACHMENTS   ####################
-- #####################################################################

-- Это нужно, чтобы обвес точно появился в инвентаре
hg.validattachments = hg.validattachments or {}
hg.validattachments.sight = hg.validattachments.sight or {}
hg.validattachments.underbarrel = hg.validattachments.underbarrel or {}
hg.validattachments.sight["sightmgl"] = hg.attachments.sight["sightmgl"]
hg.validattachments.underbarrel["flashlightshot0"] = hg.attachments.underbarrel["flashlightshot0"]

