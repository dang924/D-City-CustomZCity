-- ZCity Buy Menu — Server
-- Grants money for NPC kills, handles item purchases.
-- Everyone starts with $2500 each round. No persistence.
-- Blocked for Combine, Metrocop and headcrabzombie.

if CLIENT then return end

local initialized = false

local shopEnabled = true

-- Exposed globally so sh_ulx_shoptoggle.lua can flip the state directly.
-- Returns the new state as a string ("ENABLED" / "DISABLED").
_G.ZC_ToggleShop = function(ply)
    shopEnabled = not shopEnabled
    local state = shopEnabled and "ENABLED" or "DISABLED"
    local actor = IsValid(ply) and ply:Nick() or "Console"
    PrintMessage(HUD_PRINTTALK, "[Shop] Shop " .. state .. " by " .. actor .. ".")
    return state
end

local function Initialize()
    if initialized then return end
    initialized = true
    local BLOCKED_CLASSES = {
        ["Combine"]        = true,
        ["Metrocop"]       = true,
        ["headcrabzombie"] = true,
    }


    -- ── Money store (in-memory only, resets each round) ──────────────────────────

    local STARTING_MONEY = 2500

    local moneyStore = {}
    local lastResetTime = 0
    local lastPlayerCount = 0

    local function PerformMoneyReset(reason)
        if not isfunction(SetMoney) then
            -- SetMoney not available yet, defer
            timer.Simple(0.1, function()
                PerformMoneyReset(reason)
            end)
            return
        end
        
        moneyStore = {}
        lastResetTime = CurTime()
        print("[ZCity BuyMenu] Money reset: " .. reason)
        for _, ply in ipairs(player.GetAll()) do
            if ply:Team() == TEAM_SPECTATOR then continue end
            if BLOCKED_CLASSES[ply.PlayerClassName] then continue end
            SetMoney(ply, STARTING_MONEY)
        end
    end

    -- ── NPC kill rewards ──────────────────────────────────────────────────────────

    local NPC_REWARDS = {
        -- Combine military
        ["npc_metropolice"]    = 100,
        ["npc_combine_s"]      = 250,
        ["npc_stalker"]        = 35,
        ["npc_hunter"]         = 120,
        ["npc_strider"]        = 300,
        ["npc_combinegunship"] = 200,
        ["npc_helicopter"]     = 150,
        ["npc_manhack"]        = 15,
        ["npc_cscanner"]       = 10,
        ["npc_clawscanner"]    = 10,
        ["npc_combine_camera"] = 20,
        -- Zombies
        ["npc_zombie"]             = 20,
        ["npc_zombie_torso"]       = 15,
        ["npc_fastzombie"]         = 30,
        ["npc_fastzombie_torso"]   = 25,
        ["npc_poisonzombie"]       = 45,
        -- Other hostiles
        ["npc_antlion"]       = 20,
        ["npc_antlionguard"]  = 100,
        ["npc_headcrab"]      = 10,
        ["npc_headcrab_fast"] = 15,
        ["npc_headcrab_black"]= 20,
    }

    -- ── VJ Base SNPC kill rewards ─────────────────────────────────────────────────
    -- Keyed by VJ_NPC_Class tag (lowercase). Only hostile classes are listed;
    -- friendly classes (class_player_ally, class_citizen_*, class_vortigaunt) are
    -- intentionally absent so they return nil and are never tracked or rewarded.
    -- Amounts mirror the native equivalents above.
    local VJ_CLASS_TIER_REWARDS = {
        ["class_combine"]         = 200,
        ["class_metropolice"]     = 100,
        ["class_hunter"]          = 120,
        ["class_stalker"]         = 35,
        ["class_clawscanner"]     = 10,
        ["class_scanner"]         = 10,
        ["class_manhack"]         = 15,
        ["class_combine_gunship"] = 200,
    }

    -- Returns the reward for a VJ Base SNPC based on its VJ_NPC_Class table,
    -- or nil if the NPC has no hostile VJ class tag (and should not be rewarded).
    local function GetVJClassReward(npc)
        if not IsValid(npc) then return nil end
        local vjClass = npc.VJ_NPC_Class
        if not istable(vjClass) then return nil end
        for _, cls in ipairs(vjClass) do
            if isstring(cls) then
                local r = VJ_CLASS_TIER_REWARDS[string.lower(cls)]
                if r then return r end
            end
        end
        return nil
    end

    -- ── Shop item list ─────────────────────────────────────────────────────────────
    -- Prices are balanced against NPC rewards:
    --   Common soldier kill ($50)  ≈ 1 bandage or half a pistol
    --   Strider kill ($300)        ≈ most of a mid-tier rifle
    --   Full sortie                ≈ $500–$800 for a loadout upgrade
    --
    -- NOTE: WFA and Z-Fun class names are marked TODO — run the console dump
    -- described in sv_buy_menu_README below to get the exact class strings,
    -- then replace each "TODO_classname" with the real value.

    ZC_ShopItems = {

        -- ── PISTOLS ───────────────────────────────────────────────────────────────
        -- ZCity native
        { label = "Glock 17",        class = "weapon_glock17",        price = 120,  category = "Pistols" },
        { label = "Glock 18C",       class = "weapon_glock18c",       price = 160,  category = "Pistols" },
        { label = "Glock 26",        class = "weapon_glock26",        price = 100,  category = "Pistols" },
        { label = "HK USP",          class = "weapon_hk_usp",         price = 150,  category = "Pistols" },
        { label = "Beretta M9",      class = "weapon_m9beretta",      price = 130,  category = "Pistols" },
        { label = "Beretta PX4",     class = "weapon_px4beretta",     price = 140,  category = "Pistols" },
        { label = "Browning HP",     class = "weapon_browninghp",     price = 130,  category = "Pistols" },
        { label = "Colt M1911",      class = "weapon_m1911",          price = 140,  category = "Pistols" },
        { label = "Colt M45A1",      class = "weapon_m45",            price = 150,  category = "Pistols" },
        { label = "Desert Eagle",    class = "weapon_deagle",         price = 250,  category = "Pistols" },
        { label = "FNX-45",          class = "weapon_fn45",           price = 160,  category = "Pistols" },
        { label = "Makarov",         class = "weapon_makarov",        price = 80,   category = "Pistols" },
        { label = "TT-33 Tokarev",   class = "weapon_tokarev",        price = 90,   category = "Pistols" },
        { label = "Colt King Cobra", class = "weapon_revolver357",    price = 200,  category = "Pistols" },
        { label = "Manurhin MR-96",  class = "weapon_revolver2",      price = 180,  category = "Pistols" },
        { label = "CZ 75",           class = "weapon_cz75",           price = 140,  category = "Pistols" },
        { label = "CZ 75-A",         class = "weapon_cz75a",          price = 150,  category = "Pistols" },
        { label = "PL-15",           class = "weapon_pl15",           price = 160,  category = "Pistols" },
        { label = "Walther P22",     class = "weapon_p22",            price = 80,   category = "Pistols" },
        { label = "TEC-9",           class = "weapon_tec9",           price = 110,  category = "Pistols" },
        { label = "AB-10",           class = "weapon_ab10",           price = 130,  category = "Pistols" },
        { label = "PM-9",            class = "weapon_pm9",            price = 120,  category = "Pistols" },
        { label = "Draco",           class = "weapon_draco",          price = 200,  category = "Pistols" },
        { label = "VSKA Draco",      class = "weapon_dracovska",      price = 210,  category = "Pistols" },
        { label = "AR-15 Pistol",    class = "weapon_ar_pistol",      price = 220,  category = "Pistols" },
        { label = "Zoraki M906",     class = "weapon_zoraki",         price = 70,   category = "Pistols" },
        { label = "PB-4 Osa",        class = "weapon_osapb",          price = 100,  category = "Pistols" },
        -- WFA
        { label = "Walther P99",     class = "weapon_p99",            price = 140,  category = "Pistols" },
        { label = "Glock 22",        class = "weapon_glock22",        price = 130,  category = "Pistols" },
        { label = "MP-443 Grach",    class = "weapon_mp443",          price = 140,  category = "Pistols" },
        { label = "Colt Python",     class = "weapon_python",         price = 200,  category = "Pistols" },
        { label = "P250",            class = "weapon_p250",           price = 130,  category = "Pistols" },

        -- ── MACHINE PISTOLS ───────────────────────────────────────────────────────
        -- ZCity native
        { label = "HK MP7",          class = "weapon_mp7",            price = 350,  category = "SMGs" },
        { label = "HK MP5",          class = "weapon_mp5",            price = 320,  category = "SMGs" },
        { label = "MAC-11",          class = "weapon_mac11",          price = 200,  category = "SMGs" },
        { label = "FN P90",          class = "weapon_p90",            price = 420,  category = "SMGs" },
        { label = "Uzi",             class = "weapon_uzi",            price = 250,  category = "SMGs" },
        { label = "Scorpion vz. 61", class = "weapon_skorpion",       price = 220,  category = "SMGs" },
        { label = "KRISS Vector",    class = "weapon_vector",         price = 400,  category = "SMGs" },
        { label = "Steyr TMP",       class = "weapon_tmp",            price = 280,  category = "SMGs" },
        { label = "Colt 9mm SMG",    class = "weapon_colt9mm",        price = 280,  category = "SMGs" },
        -- WFA
        { label = "MP5 SD",          class = "weapon_mp5sd",          price = 370,  category = "SMGs" },
        { label = "Walther MPL",     class = "weapon_mpl",            price = 260,  category = "SMGs" },
        { label = "MPi 81",          class = "weapon_mpi81",          price = 240,  category = "SMGs" },
        { label = "MP40",            class = "weapon_mp40",           price = 220,  category = "SMGs" },

        -- ── ASSAULT RIFLES ────────────────────────────────────────────────────────
        -- ZCity native
        { label = "AKM",             class = "weapon_akm",            price = 500,  category = "Rifles" },
        { label = "AK-74",           class = "weapon_ak74",           price = 480,  category = "Rifles" },
        { label = "AKS-74U",         class = "weapon_ak74u",          price = 450,  category = "Rifles" },
        { label = "AK-200",          class = "weapon_ak200",          price = 520,  category = "Rifles" },
        { label = "AK-203",          class = "weapon_ak203",          price = 520,  category = "Rifles" },
        { label = "AS Val",          class = "weapon_asval",          price = 550,  category = "Rifles" },
        { label = "ASH-12",          class = "weapon_ash12",          price = 600,  category = "Rifles" },
        { label = "M4A1",            class = "weapon_m4a1",           price = 530,  category = "Rifles" },
        { label = "M16A2",           class = "weapon_m16a2",          price = 500,  category = "Rifles" },
        { label = "HK416",           class = "weapon_hk416",          price = 560,  category = "Rifles" },
        { label = "SG 552 Commando", class = "weapon_sg552",          price = 540,  category = "Rifles" },
        { label = "O.S.I.P.R.",      class = "weapon_osipr",          price = 600,  category = "Rifles" },
        { label = "Ruger AC-556",    class = "weapon_ac556",          price = 480,  category = "Rifles" },
        -- WFA
        { label = "AK-12",           class = "weapon_ak12",           price = 540,  category = "Rifles" },
        { label = "LR-300",          class = "weapon_lr300",          price = 520,  category = "Rifles" },
        { label = "MK 18",           class = "weapon_mk18",           price = 540,  category = "Rifles" },
        { label = "CQB-11",          class = "weapon_cqb11",          price = 500,  category = "Rifles" },
        { label = "AK Alpha",        class = "weapon_akalpha",        price = 560,  category = "Rifles" },
        { label = "QBZ-97-1",        class = "weapon_qbz97",          price = 520,  category = "Rifles" },
        { label = "M16A3",           class = "weapon_m16a3",          price = 510,  category = "Rifles" },
        { label = "FN 2000",         class = "weapon_fn2000",         price = 560,  category = "Rifles" },
        { label = "OTs-14-1A",       class = "weapon_ots141a",        price = 560,  category = "Rifles" },
        { label = "OTs-14-4",        class = "weapon_ots144",         price = 560,  category = "Rifles" },
        { label = "G3A3",            class = "weapon_g3a3",           price = 520,  category = "Rifles" },
        { label = "FN FAL",          class = "weapon_fnfal",          price = 540,  category = "Rifles" },
        { label = "FN FAL Para",     class = "weapon_fnfalpara",      price = 520,  category = "Rifles" },
        { label = "Zastava M70",     class = "weapon_zastavam70",     price = 490,  category = "Rifles" },
        { label = "American-180",    class = "weapon_american180",    price = 480,  category = "Rifles" },

        -- ── CARBINES ─────────────────────────────────────────────────────────────
        -- ZCity native
        { label = "AR-15",           class = "weapon_ar15",           price = 450,  category = "Carbines" },
        { label = "Mini-14",         class = "weapon_mini14",         price = 420,  category = "Carbines" },
        { label = "Ruger 10/22",     class = "weapon_ruger",          price = 320,  category = "Carbines" },
        { label = "VPO-136",         class = "weapon_vpo136",         price = 400,  category = "Carbines" },
        { label = "VPO-209",         class = "weapon_vpo209",         price = 380,  category = "Carbines" },
        { label = "Vepr SOK-94",     class = "weapon_sok94",          price = 440,  category = "Carbines" },
        -- WFA
        { label = "M14",             class = "weapon_m14",            price = 480,  category = "Carbines" },
        { label = "M14 DMR",         class = "weapon_m14dmr",         price = 550,  category = "Carbines" },
        { label = "SCAR-H",          class = "weapon_scarh",          price = 580,  category = "Carbines" },
        { label = "SCAR-L",          class = "weapon_scarl",          price = 560,  category = "Carbines" },
        { label = "SCAR SSR",        class = "weapon_scarssr",        price = 600,  category = "Carbines" },

        -- ── SHOTGUNS ─────────────────────────────────────────────────────────────
        -- ZCity native
        { label = "SPAS-12",         class = "weapon_spas12",         price = 400,  category = "Shotguns" },
        { label = "XM-1014",         class = "weapon_xm1014",         price = 360,  category = "Shotguns" },
        { label = "Remington 870",   class = "weapon_remington870",   price = 320,  category = "Shotguns" },
        { label = "Benelli M4",      class = "weapon_m4super",        price = 420,  category = "Shotguns" },
        { label = "Mossberg 590A1",  class = "weapon_m590a1",         price = 380,  category = "Shotguns" },
        { label = "Saiga-12",        class = "weapon_saiga12",        price = 400,  category = "Shotguns" },
        { label = "IZh-43",          class = "weapon_doublebarrel",   price = 200,  category = "Shotguns" },
        { label = "Sawed-off IZh-43",class = "weapon_doublebarrel_short", price = 180, category = "Shotguns" },
        { label = "KS-23",           class = "weapon_ks23",           price = 350,  category = "Shotguns" },
        { label = "TOZ-106",         class = "weapon_toz106",         price = 200,  category = "Shotguns" },

        -- ── SNIPER RIFLES ────────────────────────────────────────────────────────
        -- ZCity native
        { label = "SVD",             class = "weapon_svd",            price = 700,  category = "Snipers" },
        { label = "Mosin-Nagant",    class = "weapon_mosin",          price = 400,  category = "Snipers" },
        { label = "Karabiner 98k",   class = "weapon_kar98",          price = 420,  category = "Snipers" },
        { label = "Barrett M98B",    class = "weapon_m98b",           price = 900,  category = "Snipers" },
        { label = "SR25",            class = "weapon_sr25",           price = 680,  category = "Snipers" },
        { label = "SKS",             class = "weapon_sks",            price = 450,  category = "Snipers" },
        { label = "PTRD-41",         class = "weapon_ptrd",           price = 950,  category = "Snipers" },
        { label = "Combine Sniper",  class = "weapon_combinesniper",  price = 750,  category = "Snipers" },
        -- WFA
        { label = "T-5000",          class = "weapon_t5000",          price = 800,  category = "Snipers" },
        { label = "CS5",             class = "weapon_cs5",            price = 750,  category = "Snipers" },
        { label = "AMP DSR-1",       class = "weapon_dsr1",           price = 780,  category = "Snipers" },
        { label = "PSG1",            class = "weapon_psg1",           price = 700,  category = "Snipers" },
        { label = "Enfield Enforcer",class = "weapon_enfield_enforcer", price = 620, category = "Snipers" },

        -- ── MACHINEGUNS ───────────────────────────────────────────────────────────
        -- ZCity native
        { label = "PKM",             class = "weapon_pkm",            price = 750,  category = "MGs" },
        { label = "RPK-74",          class = "weapon_rpk",            price = 600,  category = "MGs" },
        { label = "M249",            class = "weapon_m249",           price = 700,  category = "MGs" },
        { label = "M60",             class = "weapon_m60",            price = 680,  category = "MGs" },
        { label = "HK21",            class = "weapon_hk21",           price = 720,  category = "MGs" },
        { label = "Kord 6P50",       class = "weapon_kord",           price = 900,  category = "MGs" },
        -- WFA
        { label = "DP-27",           class = "weapon_dp27",           price = 600,  category = "MGs" },
        { label = "RPD",             class = "weapon_rpd",            price = 620,  category = "MGs" },

        -- ── GRENADES & EXPLOSIVES ─────────────────────────────────────────────────
        -- ZCity native
        { label = "Combine Grenade", class = "weapon_hg_hl2nade_tpik",  price = 200, category = "Grenades" },
        { label = "M67 Grenade",     class = "weapon_hg_grenade_tpik",  price = 220, category = "Grenades" },
        { label = "F1 Grenade",      class = "weapon_hg_f1_tpik",       price = 200, category = "Grenades" },
        { label = "RGD-5",           class = "weapon_hg_rgd_tpik",      price = 190, category = "Grenades" },
        { label = "Type-59",         class = "weapon_hg_type59_tpik",   price = 190, category = "Grenades" },
        { label = "Flashbang",       class = "weapon_hg_flashbang_tpik",price = 150, category = "Grenades" },
        { label = "Smoke Bomb",      class = "weapon_hg_smokenade_tpik",price = 120, category = "Grenades" },
        { label = "Molotov",         class = "weapon_hg_molotov_tpik",  price = 140, category = "Grenades" },
        { label = "Pipe Bomb",       class = "weapon_hg_pipebomb_tpik", price = 250, category = "Grenades" },
        { label = "Claymore",        class = "weapon_claymore",         price = 400, category = "Grenades" },
        { label = "Breach Charge",   class = "weapon_breachcharge",     price = 300, category = "Grenades" },
        { label = "SLAM",            class = "weapon_hg_slam",          price = 350, category = "Grenades" },
        { label = "IED",             class = "weapon_traitor_ied",      price = 350, category = "Grenades" },
        { label = "RPG-7",           class = "weapon_hg_rpg",           price = 800,  category = "Launchers" },
        { label = "Rebel RPG",       class = "weapon_hg_rebelrpg",      price = 700,  category = "Launchers" },
        { label = "AGS-30",          class = "weapon_ags_30_handheld",   price = 5000, category = "Launchers" },
        { label = "EOTech XPS", attKey = "holo1", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Kobra EKP", attKey = "holo2", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "SIG Romeo 8T", attKey = "holo3", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Walther MRS", attKey = "holo4", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "OKP-7", attKey = "holo5", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "OKP-7 (Alt)", attKey = "holo5fur", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "OKP-7 Dovetail", attKey = "holo6", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "OKP-7 Dovetail (Alt)", attKey = "holo6fur", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Belomo PK-06", attKey = "holo7", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Holosun HS401", attKey = "holo8", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Leapers UTG 1x30", attKey = "holo9", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Trijicon SRS-02", attKey = "holo11", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Valday 1P87", attKey = "holo12", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Valday Krechet", attKey = "holo13", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "EOTech XPS3", attKey = "holo14", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "SIG Romeo 4", attKey = "holo15", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Trijicon RMR", attKey = "holo16", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Compact Prism", attKey = "holo17", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Fullfield Tac30", attKey = "optic2", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Valday PS-320", attKey = "optic3", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "PSO-1M2", attKey = "optic4", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Razor HD", attKey = "optic5", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Leupold Mark 4", attKey = "optic6", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "SIG Bravo4", attKey = "optic7", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "Leupold HAMR", attKey = "optic8", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "ACOG TA01", attKey = "optic9", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "PSO-1M2 (Alt)", attKey = "optic11", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "EOTech Vudu", attKey = "optic12", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "NPZ PAG-17", attKey = "optic13", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "MBUS Rear", attKey = "ironsight1", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "A2 Rear", attKey = "ironsight2", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "A2 Front", attKey = "ironsight3", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "MBUS Front", attKey = "ironsight4", attPlacement = "sight", price = 0, category = "Attachments" },
        { label = "AK Rail Mount", attKey = "mount1", attPlacement = "mount", price = 0, category = "Attachments" },
        { label = "LaRue QD Riser", attKey = "mount2", attPlacement = "mount", price = 0, category = "Attachments" },
        { label = "Dovetail Pilad", attKey = "mount3", attPlacement = "mount", price = 0, category = "Attachments" },
        { label = "Pistol UM3 Mount", attKey = "mount4", attPlacement = "mount", price = 0, category = "Attachments" },
        { label = "AK Suppressor", attKey = "supressor1", attPlacement = "barrel", price = 0, category = "Attachments" },
        { label = "5.56 Suppressor", attKey = "supressor2", attPlacement = "barrel", price = 0, category = "Attachments" },
        { label = "Pistol Suppressor", attKey = "supressor3", attPlacement = "barrel", price = 0, category = "Attachments" },
        { label = "9mm Suppressor", attKey = "supressor4", attPlacement = "barrel", price = 0, category = "Attachments" },
        { label = "12ga Suppressor", attKey = "supressor5", attPlacement = "barrel", price = 0, category = "Attachments" },
        { label = "Makeshift Suppressor", attKey = "supressor6", attPlacement = "barrel", price = 0, category = "Attachments" },
        { label = "SRD 762 QD Suppressor", attKey = "supressor7", attPlacement = "barrel", price = 0, category = "Attachments" },
        { label = "Hybrid 46 Suppressor", attKey = "supressor8", attPlacement = "barrel", price = 0, category = "Attachments" },
        { label = "RK-2 Foregrip", attKey = "grip1", attPlacement = "grip", price = 0, category = "Attachments" },
        { label = "ASh-12 Foregrip", attKey = "grip2", attPlacement = "grip", price = 0, category = "Attachments" },
        { label = "AFG Foregrip", attKey = "grip3", attPlacement = "grip", price = 0, category = "Attachments" },
        { label = "AKS-74U Woodgrip", attKey = "grip_akdong", attPlacement = "grip", price = 0, category = "Attachments" },
        { label = "NCSTAR Laser", attKey = "laser1", attPlacement = "underbarrel", price = 0, category = "Attachments" },
        { label = "Kleh2 Laser", attKey = "laser2", attPlacement = "underbarrel", price = 0, category = "Attachments" },
        { label = "Baldr Pro Laser", attKey = "laser3", attPlacement = "underbarrel", price = 0, category = "Attachments" },
        { label = "AN/PEQ-2 Laser", attKey = "laser4", attPlacement = "underbarrel", price = 0, category = "Attachments" },
        { label = "Rail Laser", attKey = "laser5", attPlacement = "underbarrel", price = 0, category = "Attachments" },
        { label = "Glock Drum Mag (50)", attKey = "mag1", attPlacement = "magwell", price = 0, category = "Attachments" },

        -- ── MEDICAL ───────────────────────────────────────────────────────────────
        -- ZCity native
        { label = "Bandage",         class = "weapon_bandage_sh",     price = 60,   category = "Medical" },
        { label = "Big Bandage",     class = "weapon_bigbandage_sh",  price = 100,  category = "Medical" },
        { label = "Medkit",          class = "weapon_medkit_sh",      price = 200,  category = "Medical" },
        { label = "Morphine",        class = "weapon_morphine",       price = 100,  category = "Medical" },
        { label = "Tourniquet",      class = "weapon_tourniquet",     price = 60,   category = "Medical" },
        { label = "Splint",          class = "weapon_splint",         price = 85,   category = "Medical" },
        { label = "Adrenaline",      class = "weapon_adrenaline",     price = 120,  category = "Medical" },
        { label = "Naloxone",        class = "weapon_naloxone",       price = 80,   category = "Medical" },
        { label = "Beta-Blocker",    class = "weapon_betablock",      price = 90,   category = "Medical" },
        { label = "Painkillers",     class = "weapon_painkillers",    price = 50,   category = "Medical" },
        { label = "Bloodbag",        class = "weapon_bloodbag",       price = 180,  category = "Medical" },
        { label = "Needle",          class = "weapon_needle",         price = 70,   category = "Medical" },
        { label = "Mannitol",        class = "weapon_mannitol",       price = 110,  category = "Medical" },

        --[[ ─────────────────────────────────────────────────────────────────────────
        Z-FUN WEAPON PACK ENTRIES
        Class names below are GUESSES based on ZCity naming conventions.
        To confirm exact names, run in server console while Z-Fun is loaded:
          lua_run for k,v in pairs(weapons.GetList()) do if v.Category and v.Category:find("Z%-Fun") then print(v.ClassName.."|"..v.PrintName) end end
        Replace each class string below with the confirmed value.
        ──────────────────────────────────────────────────────────────────────────── ]]
        -- Z-Fun entries are omitted pending class name confirmation.
        -- Add them here in the same format once confirmed:
        -- { label = "weapon name", class = "weapon_classname", price = 000, category = "Rifles" },
    }

    local RuntimeShopItems = {}
    local SHOP_PRICE_FILE = "zbattle/shop_prices.json"
    local SHOP_CUSTOM_FILE = "zbattle/shop_custom_entries.json"
    local PriceOverrides = {}
    local ShopCustomData = {
        removed = {},
        manual = {},
        overrides = {},
        autoSeedDone = false,
    }

    local MEDICAL_CLASSES = {
        weapon_bandage_sh = true,
        weapon_bigbandage_sh = true,
        weapon_medkit_sh = true,
        weapon_morphine = true,
        weapon_tourniquet = true,
        weapon_splint = true,
        weapon_adrenaline = true,
        weapon_naloxone = true,
        weapon_betablock = true,
        weapon_painkillers = true,
        weapon_bloodbag = true,
        weapon_needle = true,
        weapon_mannitol = true,
        weapon_fentanyl = true,
    }

    local function ClassHasAny(className, terms)
        for _, term in ipairs(terms) do
            if string.find(className, term, 1, true) then return true end
        end
        return false
    end

    local FIXED_PRICE_BY_CLASS = {
        weapon_ags_30_handheld = 5000,
    }

    local LEGACY_TO_MENU_CATEGORY = {
        Pistols = "Weapons - Pistols",
        SMGs = "Weapons - Machine-Pistols",
        Rifles = "Weapons - Assault Rifles",
        Carbines = "Weapons - Carbines",
        Shotguns = "Weapons - Shotguns",
        Snipers = "Weapons - Sniper Rifles",
        MGs = "Weapons - Machineguns",
        Launchers = "Weapons - Grenade Launchers",
        Grenades = "Weapons - Explosive",
        Melee = "Weapons - Melee",
        Medical = "Medical",
        Armor = "Armor",
        Attachments = "Attachments",
    }

    local ALLOWED_WEAPON_TABS = {
        ["Weapons - Assault Rifles"] = true,
        ["Weapons - Carbines"] = true,
        ["Weapons - Explosive"] = true,
        ["Weapons - Grenade Launchers"] = true,
        ["Weapons - Machine-Pistols"] = true,
        ["Weapons - Machineguns"] = true,
        ["Weapons - Melee"] = true,
        ["Weapons - Pistols"] = true,
        ["Weapons - Shotguns"] = true,
        ["Weapons - Sniper Rifles"] = true,
        Medical = true,
        Armor = true,
        Attachments = true,
    }

    local function CanUseShopEditor(ply)
        return IsValid(ply) and ply:IsAdmin()
    end

    local function LoadPriceOverrides()
        local raw = file.Exists(SHOP_PRICE_FILE, "DATA") and file.Read(SHOP_PRICE_FILE, "DATA") or nil
        local parsed = isstring(raw) and util.JSONToTable(raw) or nil
        PriceOverrides = istable(parsed) and parsed or {}
    end

    local function SavePriceOverrides()
        file.CreateDir("zbattle")
        file.Write(SHOP_PRICE_FILE, util.TableToJSON(PriceOverrides, true))
    end

    local function LoadShopCustomData()
        local raw = file.Exists(SHOP_CUSTOM_FILE, "DATA") and file.Read(SHOP_CUSTOM_FILE, "DATA") or nil
        local parsed = isstring(raw) and util.JSONToTable(raw) or nil

        if istable(parsed) then
            ShopCustomData.removed = istable(parsed.removed) and parsed.removed or {}
            ShopCustomData.manual = istable(parsed.manual) and parsed.manual or {}
            ShopCustomData.overrides = istable(parsed.overrides) and parsed.overrides or {}
            ShopCustomData.autoSeedDone = parsed.autoSeedDone == true
        else
            ShopCustomData.removed = {}
            ShopCustomData.manual = {}
            ShopCustomData.overrides = {}
            ShopCustomData.autoSeedDone = false
        end
    end

    local function SaveShopCustomData()
        file.CreateDir("zbattle")
        file.Write(SHOP_CUSTOM_FILE, util.TableToJSON(ShopCustomData, true))
    end

    local BuildItemPriceKey

    local function GetItemOverride(key)
        if not isstring(key) or key == "" then return nil end
        local override = ShopCustomData.overrides[key]
        return istable(override) and override or nil
    end

    local function SetItemOverrideValue(key, field, value)
        if not isstring(key) or key == "" then return end
        if not isstring(field) or field == "" then return end

        local override = GetItemOverride(key) or {}
        if value == nil or value == "" then
            override[field] = nil
        else
            override[field] = value
        end

        if override.category == nil and override.label == nil then
            ShopCustomData.overrides[key] = nil
            return
        end

        ShopCustomData.overrides[key] = override
    end

    local function ApplyItemOverride(item)
        if not istable(item) then return item end

        local key = BuildItemPriceKey(item)
        local override = GetItemOverride(key)
        if not override then return item end

        if isstring(override.label) and override.label ~= "" then
            item.label = override.label
        end

        if isstring(override.category) and override.category ~= "" then
            item.category = override.category
        end

        return item
    end

    local IsAdminOnlyWeapon
    local IsRemovedKey
    local ResolveWeaponCategory

    local function EnsureShopAutoSeededOnce()
        if ShopCustomData.autoSeedDone == true then return end

        local baseSeen = {}
        for _, item in ipairs(ZC_ShopItems or {}) do
            local cls = string.lower(tostring(item.class or ""))
            if cls ~= "" then
                baseSeen[cls] = true
            end
        end

        local manualSeen = {}
        for _, manual in ipairs(ShopCustomData.manual or {}) do
            if not istable(manual) then continue end
            local cls = string.lower(tostring(manual.class or ""))
            if cls ~= "" then
                manualSeen[cls] = true
            end
        end

        local added = 0
        for _, wep in ipairs(weapons.GetList() or {}) do
            local className = wep.ClassName or wep.Classname or wep.class
            if not isstring(className) or className == "" then continue end
            if string.sub(className, 1, 7) ~= "weapon_" then continue end
            if className == "weapon_base" or className == "weapon_crowbar" then continue end
            if ClassHasAny(string.lower(className), {"debug", "test", "base", "tool"}) then continue end
            if IsAdminOnlyWeapon(wep, className) then continue end

            local clsLower = string.lower(className)
            if baseSeen[clsLower] then continue end
            if manualSeen[clsLower] then continue end

            local runtimeKey = "class:" .. clsLower
            if IsRemovedKey(runtimeKey) then continue end

            local category = ResolveWeaponCategory(className, wep)
            if not category then continue end

            local label = (isstring(wep.PrintName) and wep.PrintName ~= "") and wep.PrintName or className
            ShopCustomData.manual[#ShopCustomData.manual + 1] = {
                class = className,
                label = label,
                category = category,
                source = "auto-seed",
            }
            manualSeen[clsLower] = true
            added = added + 1
        end

        ShopCustomData.autoSeedDone = true
        SaveShopCustomData()

        print("[ZCity BuyMenu] Auto-seeded shop entries once: added " .. tostring(added) .. " entries")
    end

    BuildItemPriceKey = function(item)
        if not istable(item) then return nil end
        if isstring(item.attKey) and item.attKey ~= "" then
            return "att:" .. string.lower(item.attKey)
        end
        if item.itemType == "armor" then
            return "armor:" .. string.lower(tostring(item.armorKey or item.class or ""))
        end
        if isstring(item.class) and item.class ~= "" then
            return "class:" .. string.lower(item.class)
        end
        return nil
    end

    local function NormalizeMenuCategory(categoryName)
        if not isstring(categoryName) or categoryName == "" then
            return nil
        end

        if LEGACY_TO_MENU_CATEGORY[categoryName] then
            return LEGACY_TO_MENU_CATEGORY[categoryName]
        end

        local lower = string.lower(categoryName)
        if string.sub(lower, 1, 10) == "weapons - " then
            return ALLOWED_WEAPON_TABS[categoryName] and categoryName or nil
        end

        return ALLOWED_WEAPON_TABS[categoryName] and categoryName or nil
    end

    IsRemovedKey = function(key)
        return isstring(key) and key ~= "" and ShopCustomData.removed[key] == true
    end

    local function IsFreeItem(item)
        if not istable(item) then return false end
        if isstring(item.attKey) and item.attKey ~= "" then return true end
        if string.lower(tostring(item.category or "")) == "attachments" then return true end
        if string.lower(tostring(item.category or "")) == "medical" then return true end

        local cls = string.lower(tostring(item.class or ""))
        if MEDICAL_CLASSES[cls] then return true end

        return false
    end

    local function ResolveFinalPrice(item, basePrice)
        local key = BuildItemPriceKey(item)
        local price = tonumber(basePrice) or tonumber(item and item.price) or 0

        if key and tonumber(PriceOverrides[key]) then
            price = tonumber(PriceOverrides[key])
        end

        if IsFreeItem(item) then
            price = 0
        end

        return math.Clamp(math.floor(tonumber(price) or 0), 0, 20000)
    end

    IsAdminOnlyWeapon = function(wep, className)
        if not istable(wep) then return false end

        if wep.AdminOnly == true then return true end

        -- Classic GMod pattern: not spawnable for players, but spawnable for admins.
        if wep.Spawnable == false and wep.AdminSpawnable == true then return true end

        local cls = string.lower(tostring(className or ""))
        if ClassHasAny(cls, {"admin", "ulx", "debug", "devonly"}) then return true end

        return false
    end

    local function InferCategoryFromClass(className, wep)
        local cls = string.lower(className or "")
        local base = string.lower(tostring((wep and wep.Base) or ""))

        if MEDICAL_CLASSES[cls] or base == "weapon_bandage_sh" or ClassHasAny(cls, {
            "bandage", "medkit", "morphine", "tourniquet", "adrenaline", "naloxone",
            "painkiller", "bloodbag", "needle", "mannitol", "fentanyl", "splint", "betablock"
        }) then
            return "Medical"
        end

        if ClassHasAny(cls, {"nade", "grenade", "molotov", "flash", "smoke", "slam", "ied", "claymore", "pipebomb"}) then
            return "Weapons - Explosive"
        end

        if ClassHasAny(cls, {"rpg", "launcher", "rocket", "m72", "at4", "panzer", "bazooka"}) then
            return "Weapons - Grenade Launchers"
        end

        if base == "weapon_melee" or ClassHasAny(cls, {"knife", "crowbar", "bat", "machete", "melee"}) then
            return "Weapons - Melee"
        end

        if ClassHasAny(cls, {"shotgun", "spas", "xm1014", "m870", "toz", "saiga", "ks23", "doublebarrel"}) then
            return "Weapons - Shotguns"
        end

        if ClassHasAny(cls, {"sniper", "svd", "mosin", "kar98", "m98", "sr25", "psg", "t5000", "dsr", "awp", "ptrd"}) then
            return "Weapons - Sniper Rifles"
        end

        if ClassHasAny(cls, {"pkm", "m249", "m60", "rpk", "hk21", "kord", "lmg", "mg"}) then
            return "Weapons - Machineguns"
        end

        if ClassHasAny(cls, {"mp5", "mp7", "uzi", "p90", "mac", "vector", "scorpion", "tmp", "smg"}) then
            return "Weapons - Machine-Pistols"
        end

        if ClassHasAny(cls, {"glock", "usp", "deagle", "revolver", "m1911", "pistol", "p99", "tokarev", "makarov", "cz", "p250"}) then
            return "Weapons - Pistols"
        end

        if ClassHasAny(cls, {"carbine", "mini14", "sks", "m14", "scar"}) then
            return "Weapons - Carbines"
        end

        return nil
    end

    ResolveWeaponCategory = function(className, wep)
        local rawCategory = tostring((wep and wep.Category) or "")
        if rawCategory ~= "" then
            local lower = string.lower(rawCategory)
            if string.sub(lower, 1, 10) == "weapons - " then
                return rawCategory
            end
        end

        local inferred = InferCategoryFromClass(className, wep)
        return inferred and NormalizeMenuCategory(inferred) or nil
    end

    local function InferPrice(itemType, category, wep)
        if itemType == "armor" then
            local prot = tonumber(wep and wep.protection) or 0
            if prot > 0 then
                return math.Clamp(math.floor(prot * 45), 150, 2000)
            end
            return 350
        end

        local base = {
            ["Weapons - Pistols"] = 150,
            ["Weapons - Machine-Pistols"] = 300,
            ["Weapons - Assault Rifles"] = 500,
            ["Weapons - Carbines"] = 460,
            ["Weapons - Shotguns"] = 360,
            ["Weapons - Sniper Rifles"] = 700,
            ["Weapons - Machineguns"] = 720,
            ["Weapons - Grenade Launchers"] = 900,
            ["Weapons - Explosive"] = 180,
            ["Weapons - Melee"] = 120,
            ["Weapons - Other"] = 400,
            Medical = 100,
            Attachments = 0,
        }
        return base[category] or 300
    end

    local function BuildRuntimeShopItems()
        LoadPriceOverrides()
        LoadShopCustomData()
        EnsureShopAutoSeededOnce()

        local result = {}
        local weaponSeen = {}
        local armorSeen = {}

        for _, item in ipairs(ZC_ShopItems or {}) do
            local entry = table.Copy(item)
            ApplyItemOverride(entry)
            entry.category = NormalizeMenuCategory(entry.category)
            if not entry.category then continue end

            local key = BuildItemPriceKey(entry)
            if IsRemovedKey(key) then continue end

            local cls = string.lower(tostring(entry.class or ""))
            if FIXED_PRICE_BY_CLASS[cls] then
                entry.price = FIXED_PRICE_BY_CLASS[cls]
            end
            entry.price = ResolveFinalPrice(entry, entry.price)
            result[#result + 1] = entry
            if entry.class and entry.class ~= "" then
                weaponSeen[entry.class] = true
                weaponSeen[string.lower(entry.class)] = true
            end
            if entry.itemType == "armor" and entry.armorKey then armorSeen[entry.armorKey] = true end
        end

        for _, manual in ipairs(ShopCustomData.manual or {}) do
            if not istable(manual) then continue end
            local className = tostring(manual.class or "")
            if className == "" then continue end

            local category = NormalizeMenuCategory(manual.category)
            if not category then continue end

            local runtimeKey = "class:" .. string.lower(className)
            if IsRemovedKey(runtimeKey) then continue end
            if weaponSeen[className] or weaponSeen[string.lower(className)] then continue end

            local item = {
                label = tostring(manual.label or className),
                class = className,
                category = category,
                itemType = "weapon",
                price = tonumber(manual.price) or InferPrice("weapon", category, nil),
            }
            ApplyItemOverride(item)
            item.category = NormalizeMenuCategory(item.category)
            if not item.category then continue end
            item.price = ResolveFinalPrice(item, item.price)
            result[#result + 1] = item
            weaponSeen[className] = true
            weaponSeen[string.lower(className)] = true
        end

        local armorRoot = hg and hg.armor
        if istable(armorRoot) then
            local armorNames = hg.armorNames or {}
            for slot, slotTbl in pairs(armorRoot) do
                if not istable(slotTbl) then continue end
                for armorKey, armorData in pairs(slotTbl) do
                    if not isstring(armorKey) or armorKey == "" then continue end
                    if armorSeen[armorKey] then continue end
                    local label = armorNames[armorKey] or armorKey
                    local armorItem = {
                        label = label,
                        class = armorKey,
                        price = InferPrice("armor", "Armor", armorData),
                        category = "Armor",
                        itemType = "armor",
                        armorSlot = slot,
                        armorKey = armorKey,
                    }
                    local armorRuntimeKey = BuildItemPriceKey(armorItem)
                    if IsRemovedKey(armorRuntimeKey) then
                        armorSeen[armorKey] = true
                        continue
                    end
                    ApplyItemOverride(armorItem)
                    armorItem.category = NormalizeMenuCategory(armorItem.category)
                    if not armorItem.category then
                        armorSeen[armorKey] = true
                        continue
                    end
                    armorItem.price = ResolveFinalPrice(armorItem, armorItem.price)
                    result[#result + 1] = armorItem
                    armorSeen[armorKey] = true
                end
            end
        end

        table.sort(result, function(a, b)
            local ca = tostring(a.category or "")
            local cb = tostring(b.category or "")
            if ca ~= cb then return ca < cb end
            return tostring(a.label or "") < tostring(b.label or "")
        end)

        RuntimeShopItems = result
        return RuntimeShopItems
    end

    -- ── Network strings ───────────────────────────────────────────────────────────

    util.AddNetworkString("ZC_BuyMenu_Open")
    util.AddNetworkString("ZC_BuyMenu_Purchase")
    util.AddNetworkString("ZC_BuyMenu_MoneyUpdate")
    util.AddNetworkString("ZC_BuyMenu_ItemList")
    util.AddNetworkString("ZC_BuyMenu_AdminSetPrice")
    util.AddNetworkString("ZC_BuyMenu_AdminSetCategory")
    util.AddNetworkString("ZC_BuyMenu_AdminRemoveEntry")
    util.AddNetworkString("ZC_BuyMenu_AdminAddEntry")
    util.AddNetworkString("ZC_BuyMenu_ForceAttach")
    util.AddNetworkString("ZC_BuyMenu_PostPurchaseRefresh")

    -- ── Money helpers ─────────────────────────────────────────────────────────────

    -- ── Money helpers ─────────────────────────────────────────────────────────────
    -- moneyStore is the source of truth. The netvar is only used for live display.
    -- All reads come from moneyStore; netvars are synced from it, not the other way.

    local function GetMoney(ply)
        return moneyStore[ply:SteamID64()] or 0
    end

    local function SetMoney(ply, amount)
        amount = math.max(0, math.floor(amount))
        moneyStore[ply:SteamID64()] = amount
        -- Sync live display netvar
        if IsValid(ply) then
            ply:SetNetVar("ZC_Money", amount)
        end
    end

    local function AddMoney(ply, amount)
        SetMoney(ply, GetMoney(ply) + amount)
        net.Start("ZC_BuyMenu_MoneyUpdate")
            net.WriteInt(GetMoney(ply), 32)
        net.Send(ply)
    end

    local function SendPostPurchaseRefresh(ply)
        if not IsValid(ply) then return end
        net.Start("ZC_BuyMenu_PostPurchaseRefresh")
        net.Send(ply)
    end

    local function SendShopSnapshot(ply)
        if not IsValid(ply) then return end

        local items = BuildRuntimeShopItems()

        net.Start("ZC_BuyMenu_ItemList")
            net.WriteUInt(#items, 16)
            for _, item in ipairs(items) do
                net.WriteString(item.label or "")
                net.WriteString(item.class or "")
                net.WriteUInt(item.price, 16)
                net.WriteString(item.category or "")
                net.WriteString(item.attKey or "")
                net.WriteString(item.itemType or ((item.attKey and item.attKey ~= "") and "attachment" or "weapon"))
                net.WriteString(item.armorSlot or "")
            end
            net.WriteInt(GetMoney(ply), 32)
            net.WriteBool(CanUseShopEditor(ply))
        net.Send(ply)
    end

    -- Give every eligible player starting money at round start
    hook.Add("ZB_StartRound", "ZCity_BuyMenu_RoundStart", function()
        PerformMoneyReset("ZB_StartRound hook")
    end)

    -- Fallback: detect map load (all players spawning fresh)
    hook.Add("InitPostEntity", "ZCity_BuyMenu_MapLoad", function()
        -- Defer slightly to ensure player list stabilizes after map load
        timer.Simple(0.5, function()
            PerformMoneyReset("map load (InitPostEntity)")
        end)
    end)

    -- Fallback: detect when player count suddenly drops to 0 and grows again (likely new round on broken round systems)
    hook.Add("Think", "ZCity_BuyMenu_PlayerCountReset", function()
        if CurTime() - lastResetTime < 5 then return end  -- Skip if we reset very recently
        
        local curCount = #player.GetAll()
        if lastPlayerCount > 2 and curCount == 0 then
            lastPlayerCount = 0  -- Mark that we hit empty
        elseif lastPlayerCount == 0 and curCount >= 2 then
            -- Transitioned from empty to populated; likely new round
            PerformMoneyReset("player count reset (0→" .. curCount .. ")")
        end
        lastPlayerCount = curCount
    end)

    -- Players who join mid-round get starting money when they first spawn
    -- If they already have money (from a previous spawn/purchase), don't overwrite it
    hook.Add("Player Spawn", "ZCity_BuyMenu_MidRoundJoin", function(ply)
        if ply:Team() == TEAM_SPECTATOR then return end
        if BLOCKED_CLASSES[ply.PlayerClassName] then return end
        
        local steam64 = ply:SteamID64()
        if moneyStore[steam64] == nil then
            SetMoney(ply, STARTING_MONEY)
        end
    end)

    -- ── NPC kill reward ───────────────────────────────────────────────────────────
    -- NPC organisms die via ply:Kill() triggered by bleed-out, same as players.
    -- By the time OnNPCKilled fires the physics attacker is stale (world entity).
    -- We track the last player who dealt damage to each NPC via EntityTakeDamage
    -- and use that as a fallback, mirroring sv_kill_tracker.lua's approach.

    -- { [NPC EntIndex] = player } — fallback if no damage ledger winner
    local lastNPCAttacker = {}
    -- { [NPC EntIndex] = { [SteamID64] = { damage = number, ply = player } } }
    local npcDamageLedger = {}
    -- { [NPC EntIndex] = true } — prevents duplicate payouts across multiple hooks
    local npcRewardPaid = {}

    local function ResolveRewardAttacker(dmgInfo)
        if not dmgInfo then return nil end

        local attacker = dmgInfo:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() then return attacker end

        local inflictor = dmgInfo:GetInflictor()
        if IsValid(inflictor) and isfunction(inflictor.GetOwner) then
            local owner = inflictor:GetOwner()
            if IsValid(owner) and owner:IsPlayer() then return owner end
        end

        if IsValid(attacker) and isfunction(attacker.GetOwner) then
            local owner = attacker:GetOwner()
            if IsValid(owner) and owner:IsPlayer() then return owner end
        end

        return nil
    end

    local function TrackNPCDamage(npc, attacker, damage)
        if not IsValid(npc) or not IsValid(attacker) then return end
        if not attacker:IsPlayer() then return end
        if BLOCKED_CLASSES[attacker.PlayerClassName] then return end
        if damage <= 0 then return end

        local npcIdx = npc:EntIndex()
        local sid64 = attacker:SteamID64()

        npcDamageLedger[npcIdx] = npcDamageLedger[npcIdx] or {}
        local bucket = npcDamageLedger[npcIdx]
        bucket[sid64] = bucket[sid64] or { damage = 0, ply = attacker }
        bucket[sid64].damage = bucket[sid64].damage + damage
        bucket[sid64].ply = attacker

        lastNPCAttacker[npcIdx] = attacker
    end

    local function GetTopDamageContributorsByIndex(npcIdx, limit)
        local bucket = npcDamageLedger[npcIdx]
        if not istable(bucket) then return nil end

        local rows = {}
        for _, entry in pairs(bucket) do
            local ply = entry and entry.ply
            local dmg = tonumber(entry and entry.damage) or 0
            if IsValid(ply) and ply:IsPlayer() and not BLOCKED_CLASSES[ply.PlayerClassName] and dmg > 0 then
                rows[#rows + 1] = {
                    ply = ply,
                    damage = dmg,
                }
            end
        end

        if #rows <= 0 then return nil end

        table.sort(rows, function(a, b)
            return a.damage > b.damage
        end)

        local top = {}
        local maxCount = math.min(limit or 3, #rows)
        for i = 1, maxCount do
            top[#top + 1] = rows[i]
        end

        return top
    end

    local function AwardNPCRewardByIndex(npcIdx, npcClass, fallbackAttacker, npcRef)
        if npcRewardPaid[npcIdx] then return end

        local reward = NPC_REWARDS[npcClass] or (IsValid(npcRef) and GetVJClassReward(npcRef)) or nil
        if not reward or reward <= 0 then
            lastNPCAttacker[npcIdx] = nil
            npcDamageLedger[npcIdx] = nil
            npcRewardPaid[npcIdx] = true
            return
        end

        local contributors = GetTopDamageContributorsByIndex(npcIdx, 3)
        if not contributors or #contributors == 0 then
            local attacker = IsValid(fallbackAttacker) and fallbackAttacker or lastNPCAttacker[npcIdx]

            lastNPCAttacker[npcIdx] = nil
            npcDamageLedger[npcIdx] = nil
            npcRewardPaid[npcIdx] = true

            if not IsValid(attacker) or not attacker:IsPlayer() then return end
            if BLOCKED_CLASSES[attacker.PlayerClassName] then return end

            AddMoney(attacker, reward)
            attacker:ChatPrint("[Shop] +" .. reward .. "$ — Balance: $" .. GetMoney(attacker))
            return
        end

        local totalDamage = 0
        for _, row in ipairs(contributors) do
            totalDamage = totalDamage + (row.damage or 0)
        end
        if totalDamage <= 0 then totalDamage = 1 end

        local distributed = 0
        for i, row in ipairs(contributors) do
            local ply = row.ply
            if not IsValid(ply) or not ply:IsPlayer() then continue end

            local amount
            if i == #contributors then
                amount = reward - distributed
            else
                amount = math.floor(reward * (row.damage / totalDamage))
            end

            if amount > 0 then
                AddMoney(ply, amount)
                ply:ChatPrint("[Shop] +" .. amount .. "$ (" .. math.floor(row.damage) .. " dmg share) — Balance: $" .. GetMoney(ply))
                distributed = distributed + amount
            end
        end

        lastNPCAttacker[npcIdx] = nil
        npcDamageLedger[npcIdx] = nil
        npcRewardPaid[npcIdx] = true
    end

    hook.Add("EntityTakeDamage", "ZCity_BuyMenu_TrackNPCAttacker", function(ent, dmgInfo)
        if not IsValid(ent) or ent:IsPlayer() then return end

        -- Track normal NPC hits and downed knockdown ragdoll proxy hits.
        local npc = nil
        if ent:IsNPC() then
            npc = ent
        elseif IsValid(ent.zc_npc_ref) and ent.zc_npc_ref:IsNPC() then
            npc = ent.zc_npc_ref
        end
        if not IsValid(npc) then return end

        -- Only care about NPCs that have a reward defined (native or VJ Base).
        if not NPC_REWARDS[npc:GetClass()] and not GetVJClassReward(npc) then return end

        local attacker = ResolveRewardAttacker(dmgInfo)
        if not IsValid(attacker) then return end

        local damage = tonumber(dmgInfo:GetDamage()) or 0
        TrackNPCDamage(npc, attacker, damage)
    end)

    -- Organism damage paths can bypass useful damage values in EntityTakeDamage;
    -- mirror tracking here so prolonged/downed fights still credit contributors.
    hook.Add("HomigradDamage", "ZCity_BuyMenu_TrackNPCAttacker_HG", function(victim, dmgInfo, hitgroup, ent, harm)
        if not IsValid(victim) or victim:IsPlayer() then return end

        local npc = nil
        if victim:IsNPC() then
            npc = victim
        elseif IsValid(victim.zc_npc_ref) and victim.zc_npc_ref:IsNPC() then
            npc = victim.zc_npc_ref
        end
        if not IsValid(npc) then return end
        if not NPC_REWARDS[npc:GetClass()] and not GetVJClassReward(npc) then return end

        local attacker = ResolveRewardAttacker(dmgInfo)
        if not IsValid(attacker) then return end

        local dmg = math.max(tonumber(harm) or 0, tonumber(dmgInfo:GetDamage()) or 0)
        TrackNPCDamage(npc, attacker, dmg)
    end)

    hook.Add("OnNPCKilled", "ZCity_BuyMenu_NPCReward", function(npc, attacker, inflictor)
        if not IsValid(npc) then return end
        AwardNPCRewardByIndex(npc:EntIndex(), npc:GetClass(), attacker, npc)
    end)

    -- Clean up tracking table when an NPC is removed without dying
    -- (e.g. map cleanup, round end) so the table doesn't grow unbounded
    hook.Add("EntityRemoved", "ZCity_BuyMenu_ClearNPCAttacker", function(ent)
        if not ent then return end
        if not ent:IsNPC() then return end

        local idx = ent:EntIndex()
        local class = ent:GetClass()

        -- Fallback payout path for cases where scripted/forced NPC death skips OnNPCKilled.
        if (NPC_REWARDS[class] or GetVJClassReward(ent)) and not npcRewardPaid[idx] then
            AwardNPCRewardByIndex(idx, class, lastNPCAttacker[idx], ent)
        end

        lastNPCAttacker[idx] = nil
        npcDamageLedger[idx] = nil
        npcRewardPaid[idx] = nil
    end)

    -- ── Attachment grant helper ──────────────────────────────────────────────────

    local function GrantAttachment(ply, attKey)
        if not IsValid(ply) then return end
        if not ply.inventory then return end
        ply.inventory.Attachments = ply.inventory.Attachments or {}
        if not table.HasValue(ply.inventory.Attachments, attKey) then
            ply.inventory.Attachments[#ply.inventory.Attachments + 1] = attKey
        end
        ply:SetNetVar("Inventory", ply.inventory)
    end

    local function WeaponHasAttachment(wep, attKey)
        if not IsValid(wep) or not istable(wep.availableAttachments) then return false end
        attKey = string.lower(tostring(attKey or ""))
        if attKey == "" then return false end

        local function MountTypeCompatible(availableMountType, attachmentMountType)
            if not availableMountType or not attachmentMountType then return false end
            if istable(availableMountType) then
                return table.HasValue(availableMountType, attachmentMountType)
            end
            return tostring(availableMountType) == tostring(attachmentMountType)
        end

        local hgAttachments = (hg and istable(hg.attachments) and hg.attachments) or {}

        for placement, options in pairs(wep.availableAttachments) do
            if not istable(options) then continue end
            for _, option in pairs(options) do
                if istable(option) and isstring(option[1]) then
                    if string.lower(option[1]) == attKey then
                        return true
                    end
                end
            end

            -- Allow mountType-based compatibility (used heavily by optic hot-swaps in ZCity).
            local placementTbl = hgAttachments[placement]
            local attData = istable(placementTbl) and placementTbl[attKey] or nil
            if istable(attData) and MountTypeCompatible(options.mountType, attData.mountType) then
                return true
            end
        end

        return false
    end

    -- ── Purchase handler ──────────────────────────────────────────────────────────

    net.Receive("ZC_BuyMenu_Purchase", function(len, ply)
        if not IsValid(ply) then return end
        if BLOCKED_CLASSES[ply.PlayerClassName] then
            ply:ChatPrint("[Shop] Your faction cannot use the shop.")
            return
        end
        if not ply:Alive() then
            ply:ChatPrint("[Shop] You must be alive to buy items.")
            return
        end

        local itemIndex = net.ReadUInt(16)
        if not RuntimeShopItems[itemIndex] then
            BuildRuntimeShopItems()
        end
        local item = RuntimeShopItems[itemIndex]
        if not item then return end

        local money = GetMoney(ply)
        if money < item.price then
            ply:ChatPrint("[Shop] Not enough money. Need $" .. item.price .. ", have $" .. money)
            return
        end

        SetMoney(ply, money - item.price)
        local purchaseApplied = false

        -- Grant attachment, armor or weapon
        if item.attKey and item.attKey ~= "" then
            GrantAttachment(ply, item.attKey)
            ply:ChatPrint("[Shop] Attachment '" .. item.label .. "' unlocked — Balance: $" .. GetMoney(ply))
            purchaseApplied = true
        elseif item.itemType == "armor" then
            local slot = item.armorSlot or "torso"
            local key = item.armorKey or item.class
            if hg and hg.AddArmor then
                local ok = pcall(function()
                    hg.AddArmor(ply, key)
                    if ply.SyncArmor then ply:SyncArmor() end
                end)
                if ok then
                    ply:ChatPrint("[Shop] Equipped armor " .. item.label .. " (" .. slot .. ") — Balance: $" .. GetMoney(ply))
                    purchaseApplied = true
                else
                    ply:ChatPrint("[Shop] Armor system unavailable right now.")
                    SetMoney(ply, money)
                end
            else
                ply:ChatPrint("[Shop] Armor system unavailable right now.")
                SetMoney(ply, money)
            end
        else
            ply:Give(item.class)
            ply:ChatPrint("[Shop] Bought " .. item.label .. " for $" .. item.price .. " — Balance: $" .. GetMoney(ply))
            purchaseApplied = true
        end

        net.Start("ZC_BuyMenu_MoneyUpdate")
            net.WriteInt(GetMoney(ply), 32)
        net.Send(ply)

        if purchaseApplied then
            timer.Simple(0, function()
                if not IsValid(ply) then return end
                SendPostPurchaseRefresh(ply)
            end)
        end
    end)

    net.Receive("ZC_BuyMenu_ForceAttach", function(_, ply)
        if not IsValid(ply) or not ply:Alive() then return end
        if BLOCKED_CLASSES[ply.PlayerClassName] then return end
        if not hg or not hg.AddAttachmentForce then return end

        local attKey = string.lower(tostring(net.ReadString() or ""))
        if attKey == "" then return end

        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) then return end
        if not istable(wep.attachments) or not istable(wep.availableAttachments) then return end
        if not WeaponHasAttachment(wep, attKey) then return end

        hg.AddAttachmentForce(ply, wep, { attKey })

        timer.Simple(0, function()
            if not IsValid(ply) then return end
            SendPostPurchaseRefresh(ply)
        end)
    end)

    net.Receive("ZC_BuyMenu_AdminSetPrice", function(_, ply)
        if not CanUseShopEditor(ply) then return end

        local itemIndex = net.ReadUInt(16)
        local newPrice = math.Clamp(net.ReadUInt(16), 0, 20000)

        if not RuntimeShopItems[itemIndex] then
            BuildRuntimeShopItems()
        end

        local item = RuntimeShopItems[itemIndex]
        if not item then return end

        local key = BuildItemPriceKey(item)
        if not key then return end

        if IsFreeItem(item) then
            newPrice = 0
            PriceOverrides[key] = nil
        else
            PriceOverrides[key] = newPrice
        end

        item.price = ResolveFinalPrice(item, newPrice)
        SavePriceOverrides()

        ply:ChatPrint("[Shop] Updated price: " .. tostring(item.label or item.class or key) .. " = $" .. tostring(item.price))
        SendShopSnapshot(ply)
    end)

    net.Receive("ZC_BuyMenu_AdminSetCategory", function(_, ply)
        if not CanUseShopEditor(ply) then return end

        local itemIndex = net.ReadUInt(16)
        local newCategory = NormalizeMenuCategory(net.ReadString())

        if not RuntimeShopItems[itemIndex] then
            BuildRuntimeShopItems()
        end

        local item = RuntimeShopItems[itemIndex]
        if not item or not newCategory then return end

        local key = BuildItemPriceKey(item)
        if not key then
            ply:ChatPrint("[Shop] Failed to change section: missing runtime key.")
            return
        end

        SetItemOverrideValue(key, "category", newCategory)

        if isstring(item.class) and item.class ~= "" then
            for i = 1, #ShopCustomData.manual do
                local manual = ShopCustomData.manual[i]
                if tostring(manual.class or "") ~= tostring(item.class) then continue end
                manual.category = newCategory
            end
        end

        SaveShopCustomData()
        BuildRuntimeShopItems()
        ply:ChatPrint("[Shop] Updated section: " .. tostring(item.label or item.class or key) .. " -> " .. newCategory)
        SendShopSnapshot(ply)
    end)

    net.Receive("ZC_BuyMenu_AdminRemoveEntry", function(_, ply)
        if not CanUseShopEditor(ply) then return end

        local itemIndex = net.ReadUInt(16)
        if not RuntimeShopItems[itemIndex] then
            BuildRuntimeShopItems()
        end

        local item = RuntimeShopItems[itemIndex]
        if not item then return end

        local key = BuildItemPriceKey(item)
        if not key then
            ply:ChatPrint("[Shop] Failed to remove entry: missing runtime key.")
            return
        end

        ShopCustomData.removed[key] = true
        ShopCustomData.overrides[key] = nil

        for i = #ShopCustomData.manual, 1, -1 do
            local manual = ShopCustomData.manual[i]
            if tostring(manual.class or "") == tostring(item.class or "") then
                table.remove(ShopCustomData.manual, i)
            end
        end

        PriceOverrides[key] = nil
        SavePriceOverrides()
        SaveShopCustomData()
        BuildRuntimeShopItems()
        ply:ChatPrint("[Shop] Removed from menu: " .. tostring(item.label or item.class or key))
        SendShopSnapshot(ply)
    end)

    net.Receive("ZC_BuyMenu_AdminAddEntry", function(_, ply)
        if not CanUseShopEditor(ply) then return end

        local className = tostring(net.ReadString() or "")
        local label = tostring(net.ReadString() or "")
        local category = NormalizeMenuCategory(net.ReadString())

        if className == "" or not category then return end

        if not weapons.GetStored(className) then
            ply:ChatPrint("[Shop] Cannot add unknown weapon class: " .. className)
            return
        end

        local key = "class:" .. string.lower(className)
        ShopCustomData.removed[key] = nil
        SetItemOverrideValue(key, "label", label ~= "" and label or nil)
        SetItemOverrideValue(key, "category", category)

        local updated = false
        for i = 1, #ShopCustomData.manual do
            local manual = ShopCustomData.manual[i]
            if tostring(manual.class or "") == className then
                manual.label = label ~= "" and label or className
                manual.category = category
                updated = true
                break
            end
        end

        if not updated then
            ShopCustomData.manual[#ShopCustomData.manual + 1] = {
                class = className,
                label = label ~= "" and label or className,
                category = category,
            }
        end

        SaveShopCustomData()
        BuildRuntimeShopItems()
        ply:ChatPrint("[Shop] Added to menu: " .. (label ~= "" and label or className) .. " -> " .. category)
        SendShopSnapshot(ply)
    end)

    hook.Add("HG_PlayerSay", "ZCity_BuyMenu_ShopEntryReset", function(ply, txtTbl, text)
        local args = string.Explode(" ", string.lower(string.Trim(text or "")))
        local cmd = args[1]
        if cmd ~= "!shopresetentries" and cmd ~= "/shopresetentries" then return end

        txtTbl[1] = ""

        if not IsValid(ply) or not ply:IsSuperAdmin() then
            if IsValid(ply) then
                ply:ChatPrint("[Shop] Only superadmins can reset shop entries.")
            end
            return ""
        end

        ShopCustomData.removed = {}
        ShopCustomData.manual = {}
        ShopCustomData.overrides = {}
        ShopCustomData.autoSeedDone = false
        SaveShopCustomData()
        BuildRuntimeShopItems()

        ply:ChatPrint("[Shop] Shop entries reset. Auto-seed will rebuild defaults once.")
        return ""
    end)

    -- ── Open shop command ─────────────────────────────────────────────────────────

    hook.Add("HG_PlayerSay", "ZCity_BuyMenu", function(ply, txtTbl, text)
        local cmd = string.lower(string.Trim(text))

        if cmd ~= "!buy" and cmd ~= "/buy" and cmd ~= "!shop" and cmd ~= "/shop" then return end
        txtTbl[1] = ""

        if not shopEnabled then
            ply:ChatPrint("[Shop] The shop is currently disabled.")
            return ""
        end
        if BLOCKED_CLASSES[ply.PlayerClassName] then
            ply:ChatPrint("[Shop] Your faction cannot access the shop.")
            return ""
        end
        if not ply:Alive() then
            ply:ChatPrint("[Shop] You must be alive to open the shop.")
            return ""
        end

        -- Defer out of ZCity's chat hook to avoid colliding with its in-flight netvar send
        timer.Simple(0, function()
            if not IsValid(ply) then return end

            SendShopSnapshot(ply)

            net.Start("ZC_BuyMenu_Open")
            net.Send(ply)
        end)

        return ""
    end)

    -- ── Shop access toggle ────────────────────────────────────────────────────────
    -- !shoptoggle is handled entirely by sh_ulx_shoptoggle.lua via ULX.
    -- No HG_PlayerSay hook here — ULX intercepts the chat trigger itself.



    -- ── Starting money for brand-new players only ────────────────────────────────
    -- Given once in PlayerInitialSpawn, not on every respawn, to avoid overwriting
    -- legitimate balances during class changes and round resets.
    -- Only a superadmin can reset balances via !moneyreset.

    -- ── Superadmin reset command ──────────────────────────────────────────────────
    -- !moneyreset          — wipes all players (online + saved) to $0
    -- !moneyreset <name>   — resets a specific online player to $0
    hook.Add("HG_PlayerSay", "ZCity_BuyMenu_MoneyReset", function(ply, txtTbl, text)
        local args = string.Split(string.lower(string.Trim(text)), " ")
        if args[1] ~= "!moneyreset" and args[1] ~= "/moneyreset" then return end
        txtTbl[1] = ""

        if not ply:IsSuperAdmin() then
            ply:ChatPrint("[Shop] Only superadmins can reset money.")
            return
        end

        -- Reset a specific player by partial name match
        if args[2] then
            local name = table.concat(args, " ", 2)
            local found = false
            for _, target in ipairs(player.GetAll()) do
                if string.find(string.lower(target:Nick()), name, 1, true) then
                    moneyStore[target:SteamID64()] = 0
                    SetMoney(target, 0)
                    target:ChatPrint("[Shop] Your money has been reset to $0 by an admin.")
                    ply:ChatPrint("[Shop] Reset money for " .. target:Nick() .. ".")
                    found = true
                end
            end
            if not found then
                ply:ChatPrint("[Shop] No player found matching '" .. name .. "'.")
            end
            return
        end

        -- Reset all online players and wipe the entire save file
        for _, target in ipairs(player.GetAll()) do
            if target:Team() == TEAM_SPECTATOR then continue end
            if IsValid(target) then
                SetMoney(target, 0)
                target:ChatPrint("[Shop] Your money has been reset to $0 by an admin.")
            end
        end
        moneyStore = {}
        ply:ChatPrint("[Shop] All player money has been reset.")
    end)
end

local function IsShopModeActive()
    if isfunction(CurrentRound) then
        local ok, round = pcall(CurrentRound)
        if ok and istable(round) then
            local name = string.lower(tostring(round.name or ""))
            if name == "coop" or name == "event" then
                return true
            end
        end
    end

    local mode = string.lower(tostring(istable(zb) and zb.CROUND or ""))
    return mode == "coop" or mode == "event"
end

hook.Add("InitPostEntity", "ZC_CoopInit_svbuymenu", function()
    if not IsShopModeActive() then return end
    Initialize()
end)

hook.Add("Think", "ZC_CoopInit_svbuymenu_Late", function()
    if initialized then
        hook.Remove("Think", "ZC_CoopInit_svbuymenu_Late")
        return
    end
    if not IsShopModeActive() then return end
    Initialize()
end)

-- Force Initialize() to run on coop mode even if called before gamemode is set
if SERVER then
    -- Try immediately
    if isfunction(CurrentRound) then
        local ok, round = pcall(CurrentRound)
        if ok and istable(round) and (round.name == "coop" or round.name == "event") then
            if not initialized then Initialize() end
        end
    end
    
    -- Fallback timers for late initialization
    timer.Simple(0.1, function()
        if not initialized and isfunction(CurrentRound) then
            local ok, round = pcall(CurrentRound)
            if ok and istable(round) and (round.name == "coop" or round.name == "event") then
                Initialize()
            end
        end
    end)
    
    timer.Simple(1, function()
        if not initialized and isfunction(CurrentRound) then
            local ok, round = pcall(CurrentRound)
            if ok and istable(round) and (round.name == "coop" or round.name == "event") then
                Initialize()
            end
        end
    end)
end
