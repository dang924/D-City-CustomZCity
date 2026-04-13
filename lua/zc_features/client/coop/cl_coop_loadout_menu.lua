-- cl_coop_loadout_menu.lua
-- Unified Coop Loadout Manager — Rebel / Combine / Gordon in one panel.
-- Commands: !manageclasses  (aliases: !managerebel, !managecombine, !managegordon)

if SERVER then return end

-- ── Module state ──────────────────────────────────────────────────────────────

local coopLoadouts    = {}
local activeMenu      = nil
local currentOpenMode = "rebel"
local loadoutSyncSeq = 0
local loadoutSyncStarted = false
local loadoutSyncCompleted = false

local function SeedFallbackCoopLoadouts(reason)
    if table.Count(coopLoadouts or {}) > 0 then return end

    coopLoadouts = {
        ["Rebel Default"] = {
            subclass = "default",
            baseClass = "Rebel",
            weapons = {
                {"$random", "weapon_akm", "weapon_asval", "weapon_mp7", "weapon_spas12", "weapon_xm1014", "weapon_svd", "weapon_osi_pr"},
                {"$random", "weapon_m9beretta", "weapon_browninghp", "weapon_revolver357", "weapon_revolver2", "weapon_hk_usp", "weapon_glock17"},
                "weapon_hg_hl2nade_tpik",
                "weapon_melee",
                "weapon_walkie_talkie",
            },
            armor = {
                torso = {"$random", "vest5", "vest4", "vest1"},
                head = {"$random", "helmet1", "helmet7"},
                face = {"$random", "mask1", "mask3", "nightvision1", ""},
                ears = "",
            }
        },
        ["Rebel Medic"] = {
            subclass = "medic",
            baseClass = "Rebel",
            weapons = {
                "weapon_bandage_sh",
                "weapon_bloodbag",
                "weapon_medkit_sh",
                "weapon_mannitol",
                "weapon_morphine",
                "weapon_naloxone",
                "weapon_painkillers",
                "weapon_tourniquet",
                "weapon_needle",
                "weapon_betablock",
                "weapon_adrenaline",
                {"$random", "weapon_akm", "weapon_asval", "weapon_mp7", "weapon_spas12", "weapon_xm1014", "weapon_svd", "weapon_osi_pr"},
                {"$random", "weapon_m9beretta", "weapon_browninghp", "weapon_revolver357", "weapon_revolver2", "weapon_hk_usp", "weapon_glock17"},
                "weapon_melee",
                "weapon_walkie_talkie",
            },
            armor = {
                torso = {"$random", "vest5", "vest4", "vest1"},
                head = {"$random", "helmet1", "helmet7"},
                face = {"$random", "mask1", "mask3", "nightvision1", ""},
                ears = "",
            }
        },
        ["Rebel Sniper"] = {
            subclass = "sniper",
            baseClass = "Rebel",
            weapons = {
                "weapon_hg_crossbow",
                "weapon_revolver357",
                "weapon_melee",
                "weapon_walkie_talkie",
            },
            armor = {
                torso = {"$random", "vest5", "vest4", "vest1"},
                head = {"$random", "helmet1", "helmet7"},
                face = {"$random", "mask1", "mask3", "nightvision1", ""},
                ears = "",
            }
        },
        ["Rebel Grenadier"] = {
            subclass = "grenadier",
            baseClass = "Rebel",
            weapons = {
                {"$random", "weapon_hg_rebelrpg", "weapon_hg_rpg"},
                "weapon_revolver357",
                "weapon_claymore",
                "weapon_traitor_ied",
                "weapon_hg_slam",
                "weapon_hg_pipebomb_tpik",
                "weapon_melee",
                "weapon_walkie_talkie",
            },
            armor = {
                torso = {"$random", "vest5", "vest4", "vest1"},
                head = {"$random", "helmet1", "helmet7"},
                face = {"$random", "mask1", "mask3", "nightvision1", ""},
                ears = "",
            }
        },
        ["Refugee Default"] = {
            subclass = "default",
            baseClass = "Refugee",
            weapons = {
                {"$random", "weapon_doublebarrel", "weapon_mp5", "weapon_mp7", "weapon_sks", "weapon_vpo136", "weapon_winchester"},
                {"$random", "weapon_m9beretta", "weapon_browninghp", "weapon_revolver357", "weapon_revolver2", "weapon_hk_usp", "weapon_glock17"},
                "weapon_melee",
                "weapon_walkie_talkie",
            },
            armor = {
                torso = {"$random", "vest2", ""},
                head = {"$random", "helmet1", ""},
                face = "",
                ears = "",
            }
        },
        ["Refugee Medic"] = {
            subclass = "medic",
            baseClass = "Refugee",
            weapons = {
                {"$random", "weapon_doublebarrel", "weapon_mp5", "weapon_mp7", "weapon_sks", "weapon_vpo136", "weapon_winchester"},
                {"$random", "weapon_m9beretta", "weapon_browninghp", "weapon_revolver357", "weapon_revolver2", "weapon_hk_usp", "weapon_glock17"},
                "weapon_bandage_sh",
                "weapon_medkit_sh",
                "weapon_painkillers",
                "weapon_tourniquet",
                "weapon_melee",
                "weapon_walkie_talkie",
            },
            armor = {
                torso = {"$random", "vest2", ""},
                head = {"$random", "helmet1", ""},
                face = "",
                ears = "",
            }
        },
        ["Combine Default"] = {
            subclass = "default",
            baseClass = "Combine",
            weapons = {
                "weapon_melee",
                "weapon_hg_hl2nade_tpik",
                "weapon_hk_usp",
                {"$random", "weapon_osipr", "weapon_mp7"},
            },
            armor = {
                torso = "",
                head = "",
                face = "",
                ears = "",
            }
        },
        ["Combine Sniper"] = {
            subclass = "sniper",
            baseClass = "Combine",
            weapons = {
                "weapon_melee",
                "weapon_hg_hl2nade_tpik",
                "weapon_hk_usp",
                "weapon_combinesniper",
            },
            armor = {
                torso = "",
                head = "",
                face = "",
                ears = "",
            }
        },
        ["Combine Shotgunner"] = {
            subclass = "shotgunner",
            baseClass = "Combine",
            weapons = {
                "weapon_melee",
                "weapon_hg_flashbang_tpik",
                "weapon_hk_usp",
                "weapon_breachcharge",
                "weapon_spas12",
            },
            armor = {
                torso = "",
                head = "",
                face = "",
                ears = "",
            }
        },
        ["Combine Elite"] = {
            subclass = "elite",
            baseClass = "Combine",
            weapons = {
                "weapon_melee",
                "weapon_hg_hl2nade_tpik",
                "weapon_hk_usp",
                "weapon_osipr",
            },
            armor = {
                torso = "",
                head = "",
                face = "",
                ears = "",
            }
        },
        ["Metrocop Default"] = {
            subclass = "metropolice",
            baseClass = "Metrocop",
            weapons = {
                "weapon_medkit_sh",
                "weapon_naloxone",
                "weapon_bigbandage_sh",
                "weapon_tourniquet",
                "weapon_hg_stunstick",
                "weapon_handcuffs",
                "weapon_handcuffs_key",
                "weapon_walkie_talkie",
                "weapon_hk_usp",
                "weapon_mp7",
            },
            armor = {
                torso = "",
                head = "",
                face = "",
                ears = "",
            }
        },
        ["Gordon Default"] = {
            subclass = "default",
            baseClass = "Gordon",
            weapons = {},
            armor = {
                torso = "",
                head = "",
                face = "",
                ears = "",
            }
        },
    }

    chat.AddText(Color(255, 100, 100), "[ZC] Server sync failed; using full built-in fallback loadouts!", reason and (" (" .. reason .. ")") or "")
    if IsValid(activeMenu) then
        activeMenu:RefreshLoadoutList()
    end
end

local slotModifiers = {
    rebel   = { medic = 1, grenadier = 1 },
    combine = { sniper = 1, shotgunner = 1, metropolice = 1 },
}

local resistanceConfig = {
    referencePlayers = 8,
    minScale         = 0.05,
    maxScale         = 1.0,
    combinePlayer    = { base = 0.2, perPlayer = 0 },
    metrocopPlayer   = { base = 0.2, perPlayer = 0 },
    combineNpc       = { base = 0.2, perPlayer = 0 },
    metrocopNpc      = { base = 0.2, perPlayer = 0 },
    rebelNpc         = { base = 1.0, perPlayer = 0 },
    gordon           = { base = 0.2, perPlayer = 0 },
}

local knockdownConfig = {
    refPlayers     = 4,
    harmBase       = 2.10,
    harmPerPlayer  = 0.10,
    bloodBase      = 1900,
    bloodPerPlayer = -100,
    legBase        = 0.85,
    legPerPlayer   = 0.04,
}

local noOrganismNPCs = false

-- ── Constants ─────────────────────────────────────────────────────────────────

local MODES = { "rebel", "combine", "gordon" }
local MODE_LABEL        = { rebel = "Rebel", combine = "Combine", gordon = "Gordon" }
local MODE_BASE_CLASSES = {
    rebel   = { "Rebel", "Refugee" },
    combine = { "Combine", "Metrocop" },
    gordon  = { "Gordon" },
}
local MODE_SUBCLASSES = {
    rebel   = { "default", "medic", "sniper", "grenadier" },
    combine = { "default", "sniper", "shotgunner", "metropolice", "elite" },
    gordon  = { "default" },
}
local ARMOR_SLOTS = { "torso", "head", "face", "ears" }

-- Populated from server via ZC_SendArmorList. Falls back to known defaults
-- if the server hasn't responded yet (e.g. editor opened very quickly).
local ARMOR_VALUES_BY_SLOT = {
    torso = { "", "vest1","vest2","vest3","vest4","vest5","vest6","vest7" },
    head  = { "", "helmet1","helmet2","helmet3","helmet4","helmet5","helmet6","helmet7" },
    face  = { "", "mask1","mask2","mask3","mask4","nightvision1" },
    ears  = { "" },
}

-- Faction armor that should never appear in the editor (applied by playerclass)
local ARMOR_BLACKLIST = {
    combine_armor=true,  combine_helmet=true,
    metrocop_armor=true, metrocop_helmet=true,
    gordon_armor=true,   gordon_helmet=true,
    gordon_arm_armor_left=true,  gordon_arm_armor_right=true,
    gordon_leg_armor_left=true,  gordon_leg_armor_right=true,
    gordon_calf_armor_left=true, gordon_calf_armor_right=true,
}

local function SanitiseArmorValue(val)
    if isstring(val) then
        return ARMOR_BLACKLIST[val] and "" or val
    end
    if istable(val) and val[1] == "$random" then
        local out = { "$random" }
        for i = 2, #val do
            if not ARMOR_BLACKLIST[tostring(val[i])] then
                out[#out+1] = val[i]
            end
        end
        return (#out <= 1) and "" or out
    end
    return val
end

-- ── Colours ───────────────────────────────────────────────────────────────────

local C = {
    bg         = Color(20,  22,  26 ),
    panelDark  = Color(26,  29,  34 ),
    panel      = Color(34,  38,  44 ),
    panelLight = Color(44,  49,  57 ),
    border     = Color(58,  63,  72 ),
    accent     = Color(255, 190, 50 ),
    green      = Color(52,  165, 75 ),
    greenHov   = Color(65,  190, 90 ),
    red        = Color(180, 55,  55 ),
    redHov     = Color(210, 70,  70 ),
    blue       = Color(55,  115, 210),
    blueHov    = Color(70,  135, 235),
    steel      = Color(65,  95,  160),
    steelHov   = Color(80,  115, 185),
    grey       = Color(80,  85,  95 ),
    greyHov    = Color(100, 106, 118),
    textPri    = Color(225, 228, 232),
    textSec    = Color(155, 162, 172),
    textDim    = Color(100, 107, 118),
    textGold   = Color(255, 195, 70 ),
    textLive   = Color(200, 230, 130),
    white      = Color(255, 255, 255),
    tabLine    = Color(255, 190, 50 ),
}

-- ── Pure helpers ──────────────────────────────────────────────────────────────

local function SanitiseWeapon(v)
    if v == "weapon_medkit" then return "weapon_medkit_sh" end
    return v
end

local function ValueToDisplay(v)
    if istable(v) and v[1] == "$random" then
        local t = {}
        for i = 2, #v do t[#t+1] = tostring(v[i]) end
        return "[$random: " .. table.concat(t, ", ") .. "]"
    end
    return tostring(v or "")
end

local function ParseValueFromInput(text)
    text = string.Trim(tostring(text or ""))
    if text == "" then return "" end
    local body = string.match(text, "^%$random%s*[:|]?%s*(.+)$")
    if not body then return text end
    local p = { "$random" }
    for _, tok in ipairs(string.Explode(",", body)) do
        local s = string.Trim(tok)
        if s ~= "" then p[#p+1] = s end
    end
    return (#p > 1) and p or ""
end

local function ExtractRandomItems(v)
    if istable(v) and v[1] == "$random" then
        local o = {}; for i = 2, #v do o[#o+1] = tostring(v[i]) end; return o
    end
    if isstring(v) then
        local p = ParseValueFromInput(v)
        if istable(p) and p[1] == "$random" then
            local o = {}; for i = 2, #p do o[#o+1] = tostring(p[i]) end; return o
        end
    end
    return {}
end

local function BuildWeaponChoices()
    local u = {}
    for _, sw in ipairs(weapons.GetList() or {}) do
        if isstring(sw.ClassName) and string.StartWith(sw.ClassName, "weapon_") then
            u[sw.ClassName] = true
        end
    end
    for cls in pairs(list.Get("Weapon") or {}) do
        if isstring(cls) and string.StartWith(cls, "weapon_") then u[cls] = true end
    end
    local t = table.GetKeys(u); table.sort(t); return t
end

local function BuildArmorChoices(slot)
    local base = ARMOR_VALUES_BY_SLOT[slot] or { "" }
    local out = {}
    -- Always include empty option first
    if not table.HasValue(base, "") then out[1] = "" end
    for _, v in ipairs(base) do
        if v == "" or not ARMOR_BLACKLIST[v] then
            out[#out+1] = v
        end
    end
    return out
end

-- ── VGUI helpers ──────────────────────────────────────────────────────────────

local function MakeBtn(parent, label, col, colHov, onClick)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn._lbl = label
    btn._col = col
    btn._hov = colHov or Color(math.min(col.r+20,255), math.min(col.g+20,255), math.min(col.b+20,255))
    btn.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and s._hov or s._col)
        draw.SimpleText(s._lbl, "DermaDefault", w/2, h/2, C.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.DoClick = onClick
    return btn
end

local function SyncNoOrganismButton(btn)
    if not IsValid(btn) then return end
    if noOrganismNPCs then
        btn._lbl = "NPC Organism: OFF"
        btn._col = C.red
        btn._hov = C.redHov
    else
        btn._lbl = "NPC Organism: ON"
        btn._col = C.green
        btn._hov = C.greenHov
    end
end

-- Section card using pure Dock — no GetWide() needed
local function MakeCard(parent, title)
    local card = vgui.Create("DPanel", parent)
    card:Dock(TOP)
    card:DockMargin(8, 0, 8, 8)
    card.Paint = function(_, w, h)
        draw.RoundedBox(5, 0, 0, w, h, C.panel)
        if title ~= "" then
            draw.RoundedBoxEx(5, 0, 0, w, 26, C.panelLight, true, true, false, false)
            draw.SimpleText(title, "DermaDefaultBold", 10, 13,
                C.textGold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(C.border)
            surface.DrawRect(0, 26, w, 1)
        end
    end
    card.PerformLayout = function(c, w, h)
        c:SizeToChildren(false, true)
    end
    return card
end

-- Spacer inside a card below its header
local function CardSpacer(parent, h)
    local sp = vgui.Create("DPanel", parent)
    sp:Dock(TOP)
    sp:SetHeight(h)
    sp.Paint = nil
    return sp
end

-- Row panel docked TOP
local function MakeRow(parent, h, margin)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:SetHeight(h)
    if margin then row:DockMargin(margin, 0, margin, 0) end
    row.Paint = nil
    return row
end

-- ── PANEL ─────────────────────────────────────────────────────────────────────

local PANEL = {}

function PANEL:GetMode()    return self.ManagerMode or "rebel" end
function PANEL:IsCombine()  return self:GetMode() == "combine" end
function PANEL:IsGordon()   return self:GetMode() == "gordon"  end
function PANEL:DefaultBase()
    if self:IsCombine() then return "Combine" end
    if self:IsGordon()  then return "Gordon"  end
    return "Rebel"
end
function PANEL:IsAllowedBase(bc)
    return table.HasValue(MODE_BASE_CLASSES[self:GetMode()] or {}, bc)
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function PANEL:Init()
    self.ManagerMode    = currentOpenMode
    self.SlotControls   = { rebel = {}, combine = {} }
    self.ResistControls = { rebel = {}, combine = {}, gordon = {} }
    self.KnockControls  = {}
    self.NoOrgButtons   = {}
    self.LiveUpdaters   = {}
    self.ModeLists      = {}
    self._liveTimers    = {}
    self.TabPanels      = {}
    self.TabBtns        = {}

    self:SetTitle("")
    self:ShowCloseButton(false)
    self:SetSize(1060, 700)
    self:Center()
    self:MakePopup()
    self:SetDeleteOnClose(true)
    self:SetDraggable(true)
    self:SetSizable(false)

    self.OnRemove = function()
        for _, tn in ipairs(self._liveTimers or {}) do timer.Remove(tn) end
        if activeMenu == self then activeMenu = nil end
    end

    self.Paint = function(_, w, h)
        draw.RoundedBox(5, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(5, 0, 0, w, 30, C.panelDark, true, true, false, false)
        surface.SetDrawColor(C.border)
        surface.DrawRect(0, 30, w, 1)
        draw.SimpleText("  Manage Coop Loadouts", "DermaDefaultBold", 10, 15,
            C.textGold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local closeX = vgui.Create("DButton", self)
    closeX:SetText("✕")
    closeX:SetTextColor(C.textSec)
    closeX:SetFont("DermaDefault")
    closeX:SetSize(28, 22)
    closeX:SetPos(self:GetWide() - 32, 4)
    closeX.Paint = function(b, w, h)
        if b:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, C.red) end
    end
    closeX.DoClick = function() self:Close() end

    -- Tab bar
    local tabBar = vgui.Create("DPanel", self)
    tabBar:Dock(TOP)
    tabBar:SetHeight(32)
    tabBar:DockMargin(0, 30, 0, 0)
    tabBar.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, C.panelDark)
        surface.SetDrawColor(C.border)
        surface.DrawRect(0, h-1, w, 1)
    end

    -- Body
    local body = vgui.Create("DPanel", self)
    body:Dock(FILL)
    body.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, C.bg)
    end

    local frame = self

    for _, mode in ipairs(MODES) do
        local btn = vgui.Create("DButton", tabBar)
        btn:Dock(LEFT)
        btn:SetWide(120)
        btn:SetText("")
        btn._active = false
        btn.Paint = function(b, w, h)
            local bg = b._active and C.panel or (b:IsHovered() and C.panelLight or C.panelDark)
            draw.RoundedBoxEx(4, 1, 1, w-2, h, bg, true, true, false, false)
            local col = b._active and C.textGold or C.textSec
            draw.SimpleText(MODE_LABEL[mode], b._active and "DermaDefaultBold" or "DermaDefault",
                w/2, h/2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            if b._active then
                surface.SetDrawColor(C.tabLine)
                surface.DrawRect(2, 0, w-4, 3)
            end
        end
        btn.DoClick = function() frame:SwitchTab(mode) end
        self.TabBtns[mode] = btn

        -- Tab panel: NOT docked — sized by body.PerformLayout
        local tabPnl = vgui.Create("DPanel", body)
        tabPnl:SetVisible(false)
        tabPnl.Paint = function(_, w, h)
            draw.RoundedBox(0, 0, 0, w, h, C.bg)
        end
        self.TabPanels[mode] = tabPnl

        self:BuildTabContent(tabPnl, mode)
    end

    body.PerformLayout = function(b, w, h)
        for _, tp in pairs(frame.TabPanels) do
            tp:SetSize(w, h)
        end
    end

    self:SwitchTab(self.ManagerMode)
    activeMenu = self
    self:RefreshLoadoutList()
end

-- ── SwitchTab ─────────────────────────────────────────────────────────────────

function PANEL:SwitchTab(mode)
    self.ManagerMode = mode
    for m, pnl in pairs(self.TabPanels) do pnl:SetVisible(m == mode) end
    for m, btn in pairs(self.TabBtns)   do btn._active = (m == mode)  end
    self:RefreshLoadoutList()
end

-- ── BuildTabContent ───────────────────────────────────────────────────────────

function PANEL:BuildTabContent(root, mode)
    local frame = self
    local k = "_" .. mode

    -- Left sidebar
    local sidebar = vgui.Create("DPanel", root)
    sidebar:Dock(LEFT)
    sidebar:SetWide(220)
    sidebar.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, C.panelDark)
        surface.SetDrawColor(C.border)
        surface.DrawRect(w-1, 0, 1, h)
    end

    local sideHdr = vgui.Create("DPanel", sidebar)
    sideHdr:Dock(TOP)
    sideHdr:SetHeight(30)
    sideHdr.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, C.panel)
        draw.SimpleText("LOADOUTS", "DermaDefaultBold", 10, h/2,
            C.textGold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local newBtn = MakeBtn(sidebar, "+ New Loadout", C.green, C.greenHov, function()
        frame:CreateNewLoadout()
    end)
    newBtn:Dock(BOTTOM)
    newBtn:SetHeight(32)
    newBtn:DockMargin(8, 0, 8, 8)

    local lv = vgui.Create("DListView", sidebar)
    lv:Dock(FILL)
    lv:DockMargin(4, 4, 4, 4)
    lv:AddColumn("Name"):SetWidth(-1)
    lv:SetMultiSelect(false)
    lv.OnRowSelected = function(_, _, row)
        frame:LoadPreset(row:GetColumnText(1))
    end
    self.ModeLists[mode] = lv

    -- Right: scroll panel
    local scroll = vgui.Create("DScrollPanel", root)
    scroll:Dock(FILL)
    scroll.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, C.bg)
    end

    -- Inner container — all sections dock TOP inside it
    -- We use a DPanel parented to scroll; AddItem keeps it in sync
    local inner = vgui.Create("DPanel", scroll)
    inner.Paint = nil

    -- Keep inner width matching scroll width; height auto-sizes from children
    scroll.PerformLayout = function(s, w, h)
        inner:SetWide(math.max(w - 12, 100))
        inner:SizeToChildren(false, true)
    end

    self:BuildEditorSections(inner, mode, k)

    scroll:AddItem(inner)
end

-- ── BuildEditorSections ───────────────────────────────────────────────────────
-- All layout is pure Dock — no GetWide() at construction time.

function PANEL:BuildEditorSections(inner, mode, k)
    local frame = self

    local PAD = 8  -- DockMargin left/right for cards

    -- ── Card: Loadout Identity ─────────────────────────────────────────────────

    local icard = MakeCard(inner, "Loadout Identity")
    CardSpacer(icard, 26)  -- header height

    local irow1 = MakeRow(icard, 20, PAD)
    local iNameLbl = vgui.Create("DLabel", irow1)
    iNameLbl:Dock(LEFT); iNameLbl:SetWide(50)
    iNameLbl:SetText("Name:"); iNameLbl:SetTextColor(C.textSec)

    local irow2 = MakeRow(icard, 28, PAD)
    local nameInput = vgui.Create("DTextEntry", irow2)
    nameInput:Dock(LEFT); nameInput:SetWide(280)
    nameInput:SetPlaceholderText("Enter loadout name…")
    frame["NameInput"..k] = nameInput

    local iScLbl = vgui.Create("DLabel", irow2)
    iScLbl:Dock(LEFT); iScLbl:SetWide(70); iScLbl:DockMargin(14, 0, 0, 0)
    iScLbl:SetText("Subclass:"); iScLbl:SetTextColor(C.textSec)

    local scCombo = vgui.Create("DComboBox", irow2)
    scCombo:Dock(LEFT); scCombo:SetWide(140)
    for _, sub in ipairs(MODE_SUBCLASSES[mode] or {}) do scCombo:AddChoice(sub) end
    scCombo:SetValue("default")
    frame["SubclassCombo"..k] = scCombo

    local iBcLbl = vgui.Create("DLabel", irow2)
    iBcLbl:Dock(LEFT); iBcLbl:SetWide(76); iBcLbl:DockMargin(14, 0, 0, 0)
    iBcLbl:SetText("Base Class:"); iBcLbl:SetTextColor(C.textSec)

    local bcCombo = vgui.Create("DComboBox", irow2)
    bcCombo:Dock(LEFT); bcCombo:SetWide(130)
    for _, bc in ipairs(MODE_BASE_CLASSES[mode] or {}) do bcCombo:AddChoice(bc) end
    bcCombo:SetValue(MODE_BASE_CLASSES[mode] and MODE_BASE_CLASSES[mode][1] or "")
    frame["BaseClassCombo"..k] = bcCombo

    CardSpacer(icard, 6)

    -- ── Card: Actions ──────────────────────────────────────────────────────────

    local acard = MakeCard(inner, "")
    acard.Paint = function(_, w, h) draw.RoundedBox(5, 0, 0, w, h, C.panel) end

    local arow = MakeRow(acard, 36, 0)
    arow:DockMargin(0, 0, 0, 0)

    local saveBtn = MakeBtn(arow, "💾 Save Loadout", C.blue, C.blueHov, function()
        frame:SaveLoadout(k)
    end)
    saveBtn:Dock(LEFT); saveBtn:SetWide(140); saveBtn:DockMargin(8, 4, 4, 4)

    local saveCtrl = MakeBtn(arow, "💾 Save Controls", C.steel, C.steelHov, function()
        frame:SaveModeControls(mode)
    end)
    saveCtrl:Dock(LEFT); saveCtrl:SetWide(140); saveCtrl:DockMargin(0, 4, 4, 4)

    local noOrgBtn = MakeBtn(arow, "NPC Organism: ON", C.green, C.greenHov, function()
        frame:SaveNoOrganismNPCs(not noOrganismNPCs, false)
    end)
    noOrgBtn:Dock(LEFT); noOrgBtn:SetWide(150); noOrgBtn:DockMargin(0, 4, 4, 4)
    SyncNoOrganismButton(noOrgBtn)
    self.NoOrgButtons[#self.NoOrgButtons + 1] = noOrgBtn

    local delBtn = MakeBtn(arow, "🗑 Delete", C.red, C.redHov, function()
        frame:DeleteLoadout(k)
    end)
    delBtn:Dock(LEFT); delBtn:SetWide(100); delBtn:DockMargin(0, 4, 4, 4)

    local resetOne = MakeBtn(arow, "↺ Reset This", Color(160,120,40), Color(190,145,50), function()
        frame:ResetLoadoutToDefault(k)
    end)
    resetOne:Dock(LEFT); resetOne:SetWide(110); resetOne:DockMargin(0, 4, 4, 4)

    local resetAll = MakeBtn(arow, "↺ Reset All", Color(140,60,20), Color(170,80,30), function()
        frame:ResetAllLoadouts(mode)
    end)
    resetAll:Dock(LEFT); resetAll:SetWide(100); resetAll:DockMargin(0, 4, 4, 4)

    local closeBtn = MakeBtn(arow, "✕ Close", C.grey, C.greyHov, function()
        frame:Close()
    end)
    closeBtn:Dock(RIGHT); closeBtn:SetWide(100); closeBtn:DockMargin(0, 4, 8, 4)

    -- ── Card: Slot Multipliers ─────────────────────────────────────────────────

    if mode ~= "gordon" then
        local slotDefs = (mode == "combine")
            and { {"sniper","Sniper"}, {"shotgunner","Shotgunner"}, {"metropolice","Metropolice"} }
            or  { {"medic","Medic"}, {"grenadier","Grenadier"} }

        local scard = MakeCard(inner, "Subclass Slot Multipliers")
        CardSpacer(scard, 28)

        for _, def in ipairs(slotDefs) do
            local key, lbl = def[1], def[2]
            local srow = MakeRow(scard, 30, PAD)
            local slider = vgui.Create("DNumSlider", srow)
            slider:Dock(FILL)
            slider:SetText(lbl .. " slot multiplier")
            slider:SetMin(0); slider:SetMax(4); slider:SetDecimals(2)
            slider:SetValue(1)
            self.SlotControls[mode][key] = slider
        end
        CardSpacer(scard, 4)
    end

    -- ── Card: Damage Scaling ──────────────────────────────────────────────────

    local resistDefs
    if mode == "combine" then
        resistDefs = {
            {"combinePlayerBase",       "P-Combine scale @ ref",       0,    2,    2},
            {"combinePlayerPerPlayer",  "P-Combine Δ/player",         -0.25, 0.25, 3},
            {"metrocopPlayerBase",      "P-Metrocop scale @ ref",      0,    2,    2},
            {"metrocopPlayerPerPlayer", "P-Metrocop Δ/player",        -0.25, 0.25, 3},
            {"combineNpcBase",          "NPC-Combine scale @ ref",     0,    2,    2},
            {"combineNpcPerPlayer",     "NPC-Combine Δ/player",       -0.25, 0.25, 3},
            {"metrocopNpcBase",         "NPC-Metrocop scale @ ref",    0,    2,    2},
            {"metrocopNpcPerPlayer",    "NPC-Metrocop Δ/player",      -0.25, 0.25, 3},
        }
    elseif mode == "gordon" then
        resistDefs = {
            {"gordonBase",      "Gordon scale @ ref",  0,    2,    2},
            {"gordonPerPlayer", "Gordon Δ/player",    -0.25, 0.25, 3},
        }
    else
        resistDefs = {
            {"rebelNpcBase",      "NPC-Rebel scale @ ref",  0,    2,    2},
            {"rebelNpcPerPlayer", "NPC-Rebel Δ/player",    -0.25, 0.25, 3},
        }
    end

    local allResist = {
        {"referencePlayers", "Reference player count", 0, 64, 0},
        {"minScale",         "Min damage scale",       0, 2,  2},
        {"maxScale",         "Max damage scale",       0, 2,  2},
    }
    for _, v in ipairs(resistDefs) do allResist[#allResist+1] = v end

    local rcard = MakeCard(inner, "Damage Scaling")
    CardSpacer(rcard, 28)

    local hintRow = MakeRow(rcard, 18, PAD)
    local hintLbl = vgui.Create("DLabel", hintRow)
    hintLbl:Dock(FILL)
    hintLbl:SetText("scale = base + (players − ref) × Δ, clamped. Lower = tankier.")
    hintLbl:SetTextColor(C.textDim)

    local liveRow = MakeRow(rcard, 18, PAD)
    local liveLbl = vgui.Create("DLabel", liveRow)
    liveLbl:Dock(FILL)
    liveLbl:SetText("Live: —")
    liveLbl:SetTextColor(C.textLive)
    frame["ResistLive"..k] = liveLbl

    local rCtrl = self.ResistControls[mode]

    for _, def in ipairs(allResist) do
        local key, lbl, mn, mx, dec = def[1], def[2], def[3], def[4], def[5]
        local srow = MakeRow(rcard, 30, PAD)
        local slider = vgui.Create("DNumSlider", srow)
        slider:Dock(FILL)
        slider:SetText(lbl)
        slider:SetMin(mn); slider:SetMax(mx); slider:SetDecimals(dec)
        rCtrl[key] = slider
    end
    CardSpacer(rcard, 4)

    -- Live updater
    local function GetN()
        local n = 0
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and not (TEAM_SPECTATOR and p:Team() == TEAM_SPECTATOR) then n=n+1 end
        end
        return n
    end
    local function R(key, fb)
        local s = rCtrl[key]
        return (IsValid(s) and tonumber(s:GetValue())) or fb
    end
    local function Cl(v, a, b) return math.Clamp(v, math.min(a,b), math.max(a,b)) end
    local function LS(base, delta, ref, n, mn2, mx2) return Cl(base+(n-ref)*delta, mn2, mx2) end

    local function UpdateLive()
        if not IsValid(liveLbl) then return end
        local n   = GetN()
        local ref = R("referencePlayers", resistanceConfig.referencePlayers)
        local mn2 = R("minScale", resistanceConfig.minScale)
        local mx2 = R("maxScale", resistanceConfig.maxScale)
        if mode == "combine" then
            local cp  = LS(R("combinePlayerBase",  (resistanceConfig.combinePlayer  or{}).base or 0.2), R("combinePlayerPerPlayer",  (resistanceConfig.combinePlayer  or{}).perPlayer or 0), ref, n, mn2, mx2)
            local mp  = LS(R("metrocopPlayerBase", (resistanceConfig.metrocopPlayer or{}).base or 0.2), R("metrocopPlayerPerPlayer", (resistanceConfig.metrocopPlayer or{}).perPlayer or 0), ref, n, mn2, mx2)
            local cn  = LS(R("combineNpcBase",     (resistanceConfig.combineNpc     or{}).base or 0.2), R("combineNpcPerPlayer",     (resistanceConfig.combineNpc     or{}).perPlayer or 0), ref, n, mn2, mx2)
            local mn3 = LS(R("metrocopNpcBase",    (resistanceConfig.metrocopNpc    or{}).base or 0.2), R("metrocopNpcPerPlayer",    (resistanceConfig.metrocopNpc    or{}).perPlayer or 0), ref, n, mn2, mx2)
            liveLbl:SetText(string.format("Live @%d:  P-Combine=%.3f  P-Metro=%.3f  NPC-Combine=%.3f  NPC-Metro=%.3f", n,cp,mp,cn,mn3))
        elseif mode == "gordon" then
            local g = LS(R("gordonBase",(resistanceConfig.gordon or{}).base or 0.2), R("gordonPerPlayer",(resistanceConfig.gordon or{}).perPlayer or 0), ref, n, mn2, mx2)
            liveLbl:SetText(string.format("Live @%d:  Gordon=%.3f", n, g))
        else
            local r = LS(R("rebelNpcBase",(resistanceConfig.rebelNpc or{}).base or 1), R("rebelNpcPerPlayer",(resistanceConfig.rebelNpc or{}).perPlayer or 0), ref, n, mn2, mx2)
            liveLbl:SetText(string.format("Live @%d:  NPC-Rebels=%.3f", n, r))
        end
    end
    self.LiveUpdaters[mode] = UpdateLive

    for _, slider in pairs(rCtrl) do
        if IsValid(slider) then
            local ot = slider.Think
            slider.Think = function(s)
                if ot then ot(s) end
                if s._lv ~= s:GetValue() then s._lv = s:GetValue(); UpdateLive() end
            end
        end
    end

    if not _G.ZC_LRC then _G.ZC_LRC = 0 end
    _G.ZC_LRC = _G.ZC_LRC + 1
    local tn = "ZC_LR_" .. mode .. "_" .. _G.ZC_LRC
    timer.Create(tn, 3, 0, function()
        if not IsValid(self) then timer.Remove(tn); return end
        if self.ManagerMode == mode then UpdateLive() end
    end)
    self._liveTimers[#self._liveTimers+1] = tn

    -- ── Card: Weapons ──────────────────────────────────────────────────────────

    -- ── Card: NPC Knockdown Difficulty (rebel tab only) ───────────────────────
    if mode == "rebel" then
        local kDefs = {
            {"refPlayers",     "Reference player count",  0,    64,   0},
            {"harmBase",       "Harm threshold @ ref",    0.5,  5.0,  2},
            {"harmPerPlayer",  "Harm Δ/player",           0,    0.5,  3},
            {"bloodBase",      "Blood threshold @ ref",   100, 5000,  0},
            {"bloodPerPlayer", "Blood Δ/player",         -300,    0,  0},
            {"legBase",        "Leg threshold @ ref",     0.3,  2.0,  2},
            {"legPerPlayer",   "Leg Δ/player",            0,    0.2,  3},
        }

        local kcard = MakeCard(inner, "NPC Knockdown Difficulty")
        CardSpacer(kcard, 28)

        local khintRow = MakeRow(kcard, 18, PAD)
        local khintLbl = vgui.Create("DLabel", khintRow)
        khintLbl:Dock(FILL)
        khintLbl:SetText("threshold = base + (players − ref) × Δ. Higher harm/leg = harder; lower blood = harder.")
        khintLbl:SetTextColor(C.textDim)

        local kliveRow = MakeRow(kcard, 18, PAD)
        local kliveLbl = vgui.Create("DLabel", kliveRow)
        kliveLbl:Dock(FILL)
        kliveLbl:SetText("Live: —")
        kliveLbl:SetTextColor(C.textLive)
        frame["KnockLive"] = kliveLbl

        self.KnockControls = {}
        local kCtrl = self.KnockControls

        for _, def in ipairs(kDefs) do
            local key, lbl, mn, mx, dec = def[1], def[2], def[3], def[4], def[5]
            local srow = MakeRow(kcard, 30, PAD)
            local slider = vgui.Create("DNumSlider", srow)
            slider:Dock(FILL)
            slider:SetText(lbl)
            slider:SetMin(mn); slider:SetMax(mx); slider:SetDecimals(dec)
            slider:SetValue(knockdownConfig[key] or 0)
            kCtrl[key] = slider
        end
        CardSpacer(kcard, 4)

        -- Live updater for knockdown card
        local function KnockGetN()
            local n = 0
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and not (TEAM_SPECTATOR and p:Team() == TEAM_SPECTATOR) then n = n + 1 end
            end
            return n
        end
        local function KR(key, fb)
            local s = kCtrl[key]
            return (IsValid(s) and tonumber(s:GetValue())) or fb
        end
        local function UpdateKnockLive()
            if not IsValid(kliveLbl) then return end
            local n    = KnockGetN()
            local ref  = KR("refPlayers",    knockdownConfig.refPlayers    or 4)
            local hB   = KR("harmBase",      knockdownConfig.harmBase      or 1.55)
            local hD   = KR("harmPerPlayer", knockdownConfig.harmPerPlayer or 0.05)
            local bB   = KR("bloodBase",     knockdownConfig.bloodBase     or 2600)
            local bD   = KR("bloodPerPlayer",knockdownConfig.bloodPerPlayer or -50)
            local lB   = KR("legBase",       knockdownConfig.legBase       or 0.60)
            local lD   = KR("legPerPlayer",  knockdownConfig.legPerPlayer  or 0.02)
            local delta = n - ref
            local harm  = math.Clamp(hB + delta * hD,  0.5,  5.0)
            local blood = math.Clamp(bB + delta * bD, 100, 5000)
            local leg   = math.Clamp(lB + delta * lD,  0.3,  2.0)
            kliveLbl:SetText(string.format("Live @%d:  harm=%.2f  blood=%.0f  leg=%.2f", n, harm, blood, leg))
        end

        for _, slider in pairs(kCtrl) do
            if IsValid(slider) then
                local ot = slider.Think
                slider.Think = function(s)
                    if ot then ot(s) end
                    if s._lv ~= s:GetValue() then s._lv = s:GetValue(); UpdateKnockLive() end
                end
            end
        end

        if not _G.ZC_KLRC then _G.ZC_KLRC = 0 end
        _G.ZC_KLRC = _G.ZC_KLRC + 1
        local ktn = "ZC_KR_rebel_" .. _G.ZC_KLRC
        timer.Create(ktn, 3, 0, function()
            if not IsValid(self) then timer.Remove(ktn); return end
            if self.ManagerMode == "rebel" then UpdateKnockLive() end
        end)
        self._liveTimers[#self._liveTimers+1] = ktn
    end

    local wcard = MakeCard(inner, "Weapons")
    CardSpacer(wcard, 28)

    local wList = vgui.Create("DListView", wcard)
    wList:Dock(TOP)
    wList:SetHeight(110)
    wList:DockMargin(PAD, 0, PAD, 0)
    wList:AddColumn("Weapon classname"):SetWidth(-1)
    wList:SetMultiSelect(false)
    wList.DoDoubleClick = function(_, _, line) frame:EditWeaponLine(line, k) end
    frame["WeaponsList"..k] = wList

    local wBtnRow = MakeRow(wcard, 32, PAD)
    wBtnRow:DockMargin(PAD, 4, PAD, 4)

    local addW = MakeBtn(wBtnRow, "+ Add", C.green, C.greenHov, function()
        frame:OpenWeaponEditor(nil, k)
    end)
    addW:Dock(LEFT); addW:SetWide(90)

    local remW = MakeBtn(wBtnRow, "✕ Remove", C.red, C.redHov, function()
        local list = frame["WeaponsList"..k]
        local row = IsValid(list) and list:GetSelectedLine()
        if row then list:RemoveLine(row) end
    end)
    remW:Dock(LEFT); remW:SetWide(90); remW:DockMargin(6, 0, 0, 0)

    local editW = MakeBtn(wBtnRow, "✎ Edit", C.steel, C.steelHov, function()
        local list = frame["WeaponsList"..k]
        local idx = IsValid(list) and list:GetSelectedLine()
        if not idx then return end
        frame:EditWeaponLine(list:GetLine(idx), k)
    end)
    editW:Dock(LEFT); editW:SetWide(90); editW:DockMargin(6, 0, 0, 0)

    -- ── Card: Armor ────────────────────────────────────────────────────────────

    local arcard = MakeCard(inner, "Armor")
    CardSpacer(arcard, 28)

    local aList = vgui.Create("DListView", arcard)
    aList:Dock(TOP)
    aList:SetHeight(88)
    aList:DockMargin(PAD, 0, PAD, 0)
    aList:AddColumn("Slot"):SetWidth(90)
    aList:AddColumn("Value"):SetWidth(-1)
    aList:SetMultiSelect(false)
    aList.DoDoubleClick = function(_, _, line) frame:EditArmorLine(line, k) end
    frame["ArmorList"..k] = aList

    local aBtnRow = MakeRow(arcard, 32, PAD)
    aBtnRow:DockMargin(PAD, 4, PAD, 4)

    local addA = MakeBtn(aBtnRow, "+ Add", C.green, C.greenHov, function()
        frame:OpenArmorEditor(nil, k)
    end)
    addA:Dock(LEFT); addA:SetWide(90)

    local remA = MakeBtn(aBtnRow, "✕ Remove", C.red, C.redHov, function()
        local list = frame["ArmorList"..k]
        local row = IsValid(list) and list:GetSelectedLine()
        if row then list:RemoveLine(row) end
    end)
    remA:Dock(LEFT); remA:SetWide(90); remA:DockMargin(6, 0, 0, 0)

    local editA = MakeBtn(aBtnRow, "✎ Edit", C.steel, C.steelHov, function()
        local list = frame["ArmorList"..k]
        local idx = IsValid(list) and list:GetSelectedLine()
        if not idx then return end
        frame:EditArmorLine(list:GetLine(idx), k)
    end)
    editA:Dock(LEFT); editA:SetWide(90); editA:DockMargin(6, 0, 0, 0)

    CardSpacer(arcard, 4)
end

-- ── RefreshLoadoutList ────────────────────────────────────────────────────────

function PANEL:RefreshLoadoutList()
    local mode = self:GetMode()
    local lv   = self.ModeLists and self.ModeLists[mode]
    if not IsValid(lv) then return end
    lv:Clear()
    local names = {}
    for name, data in pairs(coopLoadouts) do
        if self:IsAllowedBase(data.baseClass or "") then
            names[#names+1] = name
        end
    end
    table.sort(names)
    for _, n in ipairs(names) do lv:AddLine(n) end
end

-- ── LoadPreset ────────────────────────────────────────────────────────────────

function PANEL:LoadPreset(presetName)
    local data = coopLoadouts[presetName]
    if not data then return end
    self.CurrentPresetName = presetName
    local k = "_" .. self:GetMode()

    local ni = self["NameInput"..k]
    if IsValid(ni) then ni:SetValue(presetName) end

    local sc = self["SubclassCombo"..k]
    if IsValid(sc) then sc:SetValue(data.subclass or "default") end

    local bc = self["BaseClassCombo"..k]
    if IsValid(bc) then bc:SetValue(data.baseClass or self:DefaultBase()) end

    local wl = self["WeaponsList"..k]
    if IsValid(wl) then
        wl:Clear()
        for _, w in ipairs(data.weapons or {}) do
            local ln = wl:AddLine(ValueToDisplay(w))
            ln.RawValue = w
        end
    end

    local al = self["ArmorList"..k]
    if IsValid(al) then
        al:Clear()
        for slot, val in pairs(data.armor or {}) do
            local sanitised = SanitiseArmorValue(val)
            local ln = al:AddLine(slot, ValueToDisplay(sanitised))
            ln.RawValue = sanitised
        end
    end
end

-- ── CreateNewLoadout ──────────────────────────────────────────────────────────

function PANEL:CreateNewLoadout()
    self.CurrentPresetName = nil
    local k = "_" .. self:GetMode()
    local ni = self["NameInput"..k];     if IsValid(ni) then ni:SetValue("") end
    local sc = self["SubclassCombo"..k]; if IsValid(sc) then sc:SetValue("default") end
    local bc = self["BaseClassCombo"..k];if IsValid(bc) then bc:SetValue(self:DefaultBase()) end
    local wl = self["WeaponsList"..k];   if IsValid(wl) then wl:Clear() end
    local al = self["ArmorList"..k];     if IsValid(al) then al:Clear() end
    chat.AddText(C.blue, "[ZC] Fill in the name and equipment, then press Save Loadout.")
end

-- ── SaveLoadout ───────────────────────────────────────────────────────────────

function PANEL:SaveLoadout(k)
    k = k or ("_" .. self:GetMode())
    local ni = self["NameInput"..k]
    local name = ni and string.Trim(ni:GetValue() or "") or ""
    if name == "" then chat.AddText(Color(255,0,0), "[ZC] Loadout needs a name."); return end

    local wl = self["WeaponsList"..k]
    local weapons = {}
    for _, row in ipairs(IsValid(wl) and wl:GetLines() or {}) do
        local raw = row.RawValue or row:GetColumnText(1)
        if isstring(raw) then raw = SanitiseWeapon(raw)
        elseif istable(raw) then
            for i = 2, #raw do raw[i] = SanitiseWeapon(raw[i]) end
        end
        weapons[#weapons+1] = raw
    end

    local al = self["ArmorList"..k]
    local armor = {}
    for _, row in ipairs(IsValid(al) and al:GetLines() or {}) do
        armor[row:GetColumnText(1)] = row.RawValue or row:GetColumnText(2)
    end

    local sc = self["SubclassCombo"..k]
    local bc = self["BaseClassCombo"..k]
    local data = {
        subclass  = (IsValid(sc) and sc:GetValue()) or "default",
        baseClass = (IsValid(bc) and bc:GetValue()) or self:DefaultBase(),
        weapons   = weapons,
        armor     = armor,
    }

    -- Use JSON string instead of WriteTable to avoid numeric-key mangling.
    -- net.WriteTable turns {1="$random",2="weapon_ak"} (array) into
    -- string-keyed tables on the receiver, breaking $random resolution.
    local json = util.TableToJSON(data)
    if util.NetworkStringToID("ZC_SaveCoopLoadoutJSON") == 0 then
        chat.AddText(Color(255,120,120), "[ZC] Save unavailable: net message not pooled yet.")
        return
    end
    net.Start("ZC_SaveCoopLoadoutJSON")
    net.WriteString(name)
    net.WriteString(json)
    net.SendToServer()

    coopLoadouts[name] = table.Copy(data)
    if self.CurrentPresetName and self.CurrentPresetName ~= name then
        coopLoadouts[self.CurrentPresetName] = nil
    end
    self.CurrentPresetName = name
    self:RefreshLoadoutList()
    chat.AddText(C.green, "[ZC] Saved: " .. name)
end

-- ── DeleteLoadout ─────────────────────────────────────────────────────────────

function PANEL:DeleteLoadout(k)
    if not self.CurrentPresetName then
        chat.AddText(Color(255,0,0), "[ZC] No loadout selected.")
        return
    end
    if util.NetworkStringToID("ZC_DeleteCoopLoadout") == 0 then
        chat.AddText(Color(255,120,120), "[ZC] Delete unavailable: net message not pooled yet.")
        return
    end
    net.Start("ZC_DeleteCoopLoadout")
    net.WriteString(self.CurrentPresetName)
    net.SendToServer()
    coopLoadouts[self.CurrentPresetName] = nil
    self.CurrentPresetName = nil
    self:RefreshLoadoutList()
    chat.AddText(C.green, "[ZC] Loadout deleted.")
end

-- ── SaveSlotModifiers ─────────────────────────────────────────────────────────

function PANEL:SaveSlotModifiers(mode, silent)
    if mode == "gordon" then return end
    local payload = {
        rebel   = table.Copy(slotModifiers.rebel   or {}),
        combine = table.Copy(slotModifiers.combine or {}),
    }
    local ctrlSrc = self.SlotControls and self.SlotControls[mode] or {}
    local tgt     = (mode == "combine") and payload.combine or payload.rebel
    for key, slider in pairs(ctrlSrc) do
        if IsValid(slider) then tgt[key] = tonumber(slider:GetValue()) or 1 end
    end
    if util.NetworkStringToID("ZC_SaveSubclassSlotModifiers") == 0 then
        if not silent then chat.AddText(Color(255,120,120), "[ZC] Slot save unavailable: net message not pooled yet.") end
        return
    end
    net.Start("ZC_SaveSubclassSlotModifiers")
    net.WriteTable(payload)
    net.SendToServer()
    if not silent then chat.AddText(C.green, "[ZC] Slot modifiers saved.") end
end

-- ── SaveResistanceConfig ──────────────────────────────────────────────────────

function PANEL:SaveResistanceConfig(silent)
    local function rd(m, key, fb)
        local c = self.ResistControls and self.ResistControls[m]
        local s = c and c[key]
        return (IsValid(s) and tonumber(s:GetValue())) or fb
    end
    local payload = {
        referencePlayers = rd("rebel","referencePlayers", resistanceConfig.referencePlayers),
        minScale         = rd("rebel","minScale",         resistanceConfig.minScale),
        maxScale         = rd("rebel","maxScale",         resistanceConfig.maxScale),
        combinePlayer    = {base=rd("combine","combinePlayerBase",      (resistanceConfig.combinePlayer  or{}).base  or 0.2),perPlayer=rd("combine","combinePlayerPerPlayer",(resistanceConfig.combinePlayer  or{}).perPlayer or 0)},
        metrocopPlayer   = {base=rd("combine","metrocopPlayerBase",     (resistanceConfig.metrocopPlayer or{}).base  or 0.2),perPlayer=rd("combine","metrocopPlayerPerPlayer",(resistanceConfig.metrocopPlayer or{}).perPlayer or 0)},
        combineNpc       = {base=rd("combine","combineNpcBase",         (resistanceConfig.combineNpc     or{}).base  or 0.2),perPlayer=rd("combine","combineNpcPerPlayer",   (resistanceConfig.combineNpc     or{}).perPlayer or 0)},
        metrocopNpc      = {base=rd("combine","metrocopNpcBase",        (resistanceConfig.metrocopNpc    or{}).base  or 0.2),perPlayer=rd("combine","metrocopNpcPerPlayer",  (resistanceConfig.metrocopNpc    or{}).perPlayer or 0)},
        rebelNpc         = {base=rd("rebel",  "rebelNpcBase",           (resistanceConfig.rebelNpc       or{}).base  or 1),  perPlayer=rd("rebel",  "rebelNpcPerPlayer",    (resistanceConfig.rebelNpc       or{}).perPlayer or 0)},
        gordon           = {base=rd("gordon", "gordonBase",             (resistanceConfig.gordon         or{}).base  or 0.2),perPlayer=rd("gordon", "gordonPerPlayer",      (resistanceConfig.gordon         or{}).perPlayer or 0)},
    }
    if util.NetworkStringToID("ZC_SaveCombineResistanceConfig") == 0 then
        if not silent then chat.AddText(Color(255,120,120), "[ZC] Resistance save unavailable: net message not pooled yet.") end
        return
    end
    net.Start("ZC_SaveCombineResistanceConfig")
    net.WriteTable(payload)
    net.SendToServer()
    if not silent then chat.AddText(C.green, "[ZC] Resistance config saved.") end
end

-- ── SaveKnockdownConfig ───────────────────────────────────────────────────────

function PANEL:SaveKnockdownConfig(silent)
    local function krd(key, fb)
        local s = self.KnockControls and self.KnockControls[key]
        return (IsValid(s) and tonumber(s:GetValue())) or fb
    end
    local payload = {
        refPlayers     = krd("refPlayers",     knockdownConfig.refPlayers     or 4),
        harmBase       = krd("harmBase",       knockdownConfig.harmBase       or 1.55),
        harmPerPlayer  = krd("harmPerPlayer",  knockdownConfig.harmPerPlayer  or 0.05),
        bloodBase      = krd("bloodBase",      knockdownConfig.bloodBase      or 2600),
        bloodPerPlayer = krd("bloodPerPlayer", knockdownConfig.bloodPerPlayer or -50),
        legBase        = krd("legBase",        knockdownConfig.legBase        or 0.60),
        legPerPlayer   = krd("legPerPlayer",   knockdownConfig.legPerPlayer   or 0.02),
    }
    if util.NetworkStringToID("ZC_SaveKnockdownConfig") == 0 then
        if not silent then chat.AddText(Color(255,120,120), "[ZC] Knockdown save unavailable: net message not pooled yet.") end
        return
    end
    net.Start("ZC_SaveKnockdownConfig")
    net.WriteTable(payload)
    net.SendToServer()
    if not silent then chat.AddText(C.green, "[ZC] Knockdown config saved.") end
end

-- ── SaveNoOrganismNPCs ───────────────────────────────────────────────────────

function PANEL:SaveNoOrganismNPCs(desiredValue, silent)
    if util.NetworkStringToID("ZC_SaveNoOrganismNPCs") == 0 then
        if not silent then chat.AddText(Color(255,120,120), "[ZC] NPC organism toggle unavailable: net message not pooled yet.") end
        return
    end
    net.Start("ZC_SaveNoOrganismNPCs")
    net.WriteBool(desiredValue and true or false)
    net.SendToServer()
    if not silent then chat.AddText(C.green, "[ZC] NPC organism toggle saved.") end
end

-- ── SaveModeControls ──────────────────────────────────────────────────────────

function PANEL:SaveModeControls(mode)
    mode = mode or self:GetMode()
    self:SaveSlotModifiers(mode, true)
    self:SaveResistanceConfig(true)
    self:SaveKnockdownConfig(true)
    self:SaveNoOrganismNPCs(noOrganismNPCs, true)
    chat.AddText(C.green, "[ZC] Controls saved.")
end

-- ── Weapon editor ─────────────────────────────────────────────────────────────

function PANEL:EditWeaponLine(line, k)
    if not IsValid(line) then return end
    self:OpenWeaponEditor(line, k or ("_"..self:GetMode()))
end

function PANEL:OpenWeaponEditor(existingLine, k)
    k = k or ("_"..self:GetMode())
    local frame    = self
    local allCls   = BuildWeaponChoices()
    local initRand = ExtractRandomItems(existingLine and existingLine.RawValue or "")

    local ed = vgui.Create("DFrame")
    ed:SetTitle(existingLine and "Edit Weapon" or "Add Weapon")
    ed:SetSize(560, 560)
    ed:Center()
    ed:MakePopup()
    ed:SetDeleteOnClose(true)
    ed.Paint = function(_, w, h)
        draw.RoundedBox(5,0,0,w,h,C.bg)
        draw.RoundedBoxEx(5,0,0,w,28,C.panelDark,true,true,false,false)
        surface.SetDrawColor(C.border); surface.DrawRect(0,28,w,1)
    end

    -- ── Search / filter row (docked TOP) ──────────────────────────────────────

    local searchRow = vgui.Create("DPanel", ed)
    searchRow:Dock(TOP); searchRow:SetHeight(30); searchRow:DockMargin(10,8,10,0)
    searchRow.Paint = nil

    local searchLbl = vgui.Create("DLabel", searchRow)
    searchLbl:Dock(LEFT); searchLbl:SetWide(58)
    searchLbl:SetText("Filter:"); searchLbl:SetTextColor(C.textSec)

    local searchBox = vgui.Create("DTextEntry", searchRow)
    searchBox:Dock(FILL)
    searchBox:SetPlaceholderText("Type to filter weapon names…")

    -- Hint row
    local hintRow = vgui.Create("DPanel", ed)
    hintRow:Dock(TOP); hintRow:SetHeight(16); hintRow:DockMargin(10,3,10,0)
    hintRow.Paint = nil
    local hintLbl = vgui.Create("DLabel", hintRow)
    hintLbl:Dock(FILL)
    hintLbl:SetText("Check one item to add it directly. Check 2+ for a $random pool.")
    hintLbl:SetTextColor(C.textDim)

    -- Pool header
    local poolHdr = vgui.Create("DPanel", ed)
    poolHdr:Dock(TOP); poolHdr:SetHeight(22); poolHdr:DockMargin(10,4,10,0)
    poolHdr.Paint = function(_, w, h)
        draw.RoundedBoxEx(4,0,0,w,h,C.panelLight,true,true,false,false)
        draw.SimpleText("  Weapon List  (check to select / build $random pool)",
            "DermaDefaultBold", 6, h/2, C.textGold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- Bottom buttons (dock BOTTOM before FILL so they stay anchored)
    local botRow = vgui.Create("DPanel", ed)
    botRow:Dock(BOTTOM); botRow:SetHeight(38); botRow:DockMargin(10,0,10,8)
    botRow.Paint = nil

    -- Custom entry row (dock BOTTOM above buttons)
    local custRow = vgui.Create("DPanel", ed)
    custRow:Dock(BOTTOM); custRow:SetHeight(30); custRow:DockMargin(10,0,10,2)
    custRow.Paint = nil

    local custEntry = vgui.Create("DTextEntry", custRow)
    custEntry:Dock(LEFT); custEntry:SetWide(260)
    custEntry:SetPlaceholderText("Custom classname not in list…")

    local custAddBtn = MakeBtn(custRow, "+ Add Custom", C.steel, C.steelHov, nil)
    custAddBtn:Dock(LEFT); custAddBtn:SetWide(110); custAddBtn:DockMargin(4,2,0,2)

    -- Scroll panel (FILL — all remaining space)
    local poolScroll = vgui.Create("DScrollPanel", ed)
    poolScroll:Dock(FILL); poolScroll:DockMargin(10,2,10,2)
    poolScroll.Paint = function(_, w, h) draw.RoundedBox(3,0,0,w,h,C.panel) end

    local poolInner = vgui.Create("DPanel", poolScroll)
    poolInner.Paint = nil

    local ROW_H     = 22
    local checkboxes = {}   -- { cb, lbl, cls }
    local filterText = ""

    -- Build one row per weapon — single column, full width labels
    local function BuildRows(list)
        -- Remove old children
        for _, row in ipairs(checkboxes) do
            if IsValid(row.cb)  then row.cb:Remove()  end
            if IsValid(row.lbl) then row.lbl:Remove() end
        end
        checkboxes = {}
        -- Compute width from scroll panel (valid once laid out)
        local innerW = math.max(poolScroll:GetWide() - 12, 200)
        poolInner:SetSize(innerW, #list * ROW_H + 4)
        for i, cls in ipairs(list) do
            local y = (i-1) * ROW_H + 2
            local cb = vgui.Create("DCheckBox", poolInner)
            cb:SetPos(4, y + 3); cb:SetSize(16, 16)
            cb:SetValue(table.HasValue(initRand, cls))
            cb._cls = cls
            local lbl2 = vgui.Create("DLabel", poolInner)
            lbl2:SetPos(24, y); lbl2:SetSize(innerW - 30, ROW_H)
            lbl2:SetText(cls); lbl2:SetTextColor(C.textSec)
            checkboxes[#checkboxes+1] = { cb = cb, lbl = lbl2, cls = cls }
        end
    end

    local function GetFiltered()
        if filterText == "" then return allCls end
        local out = {}
        for _, cls in ipairs(allCls) do
            if string.find(cls, filterText, 1, true) then out[#out+1] = cls end
        end
        return out
    end

    -- Defer first build until scroll has been sized
    local built = false
    poolScroll.PerformLayout = function(s, w, h)
        -- Resize poolInner width whenever scroll resizes
        if #checkboxes > 0 then
            local innerW = math.max(w - 12, 200)
            poolInner:SetWide(innerW)
            for _, row in ipairs(checkboxes) do
                if IsValid(row.lbl) then row.lbl:SetWide(innerW - 30) end
            end
        end
        if not built then
            built = true
            BuildRows(GetFiltered())
        end
    end
    poolScroll:AddItem(poolInner)

    -- Filter on typing
    searchBox.OnChange = function(s)
        filterText = string.lower(string.Trim(s:GetValue() or ""))
        -- Preserve checked state across rebuild
        local checked = {}
        for _, row in ipairs(checkboxes) do
            if IsValid(row.cb) and row.cb:GetChecked() then
                checked[row.cls] = true
            end
        end
        -- Merge checked items into initRand so they survive filter changes
        for cls in pairs(checked) do
            if not table.HasValue(initRand, cls) then initRand[#initRand+1] = cls end
        end
        BuildRows(GetFiltered())
        -- Restore checked state
        for _, row in ipairs(checkboxes) do
            if IsValid(row.cb) and checked[row.cls] then
                row.cb:SetValue(true)
            end
        end
    end

    -- Add custom
    custAddBtn.DoClick = function()
        local val = string.Trim(custEntry:GetValue() or "")
        if val == "" then return end
        -- Mark as checked; add to list if missing
        local found = false
        for _, row in ipairs(checkboxes) do
            if row.cls == val then row.cb:SetValue(true); found = true; break end
        end
        if not found then
            allCls[#allCls+1] = val
            initRand[#initRand+1] = val
            BuildRows(GetFiltered())
            -- check the new row
            for _, row in ipairs(checkboxes) do
                if row.cls == val then row.cb:SetValue(true); break end
            end
        end
        custEntry:SetValue("")
    end

    -- Confirm
    local confirmBtn = MakeBtn(botRow, existingLine and "✔ Save" or "✔ Add",
        C.green, C.greenHov, function()
        local pool = {}
        for _, row in ipairs(checkboxes) do
            if IsValid(row.cb) and row.cb:GetChecked() then pool[#pool+1] = row.cls end
        end
        -- Also include any initRand items that survived filter but aren't visible
        -- (filter may have hidden some checked items; we track them in initRand)
        local allChecked = {}
        local seen = {}
        for _, row in ipairs(checkboxes) do
            if IsValid(row.cb) and row.cb:GetChecked() then
                if not seen[row.cls] then seen[row.cls] = true; allChecked[#allChecked+1] = row.cls end
            end
        end

        local parsed
        if #allChecked >= 2 then
            parsed = { "$random" }
            for _, v in ipairs(allChecked) do parsed[#parsed+1] = v end
        elseif #allChecked == 1 then
            parsed = SanitiseWeapon(allChecked[1])
        else
            -- Nothing checked — try custom entry as fallback
            local raw = string.Trim(custEntry:GetValue() or "")
            if raw == "" then
                chat.AddText(Color(255,0,0), "[ZC] Check at least one weapon in the list."); return
            end
            parsed = SanitiseWeapon(raw)
        end

        local wl = frame["WeaponsList"..k]
        if existingLine then
            existingLine.RawValue = parsed
            existingLine:SetColumnText(1, ValueToDisplay(parsed))
        elseif IsValid(wl) then
            local ln = wl:AddLine(ValueToDisplay(parsed)); ln.RawValue = parsed
        end
        ed:Close()
    end)
    confirmBtn:Dock(LEFT); confirmBtn:SetWide(110); confirmBtn:DockMargin(0,4,6,4)

    local cancelBtn = MakeBtn(botRow, "Cancel", C.grey, C.greyHov, function() ed:Close() end)
    cancelBtn:Dock(LEFT); cancelBtn:SetWide(90); cancelBtn:DockMargin(0,4,0,4)
end


-- ── Armor editor ──────────────────────────────────────────────────────────────

function PANEL:EditArmorLine(line, k)
    if not IsValid(line) then return end
    self:OpenArmorEditor(line, k or ("_"..self:GetMode()))
end

function PANEL:UpsertArmorLine(slot, value, k)
    k = k or ("_"..self:GetMode())
    local al = self["ArmorList"..k]
    if not IsValid(al) then return end
    for _, line in ipairs(al:GetLines() or {}) do
        if line:GetColumnText(1) == slot then
            line.RawValue = value
            line:SetColumnText(2, ValueToDisplay(value))
            return
        end
    end
    local ln = al:AddLine(slot, ValueToDisplay(value)); ln.RawValue = value
end

function PANEL:OpenArmorEditor(existingLine, k)
    k = k or ("_"..self:GetMode())
    local frame  = self
    local initA  = ExtractRandomItems(existingLine and existingLine.RawValue or "")

    local ed = vgui.Create("DFrame")
    ed:SetTitle(existingLine and "Edit Armor" or "Add Armor")
    ed:SetSize(500, 380)
    ed:Center()
    ed:MakePopup()
    ed:SetDeleteOnClose(true)
    ed.Paint = function(_, w, h)
        draw.RoundedBox(5,0,0,w,h,C.bg)
        draw.RoundedBoxEx(5,0,0,w,28,C.panelDark,true,true,false,false)
        surface.SetDrawColor(C.border); surface.DrawRect(0,28,w,1)
    end

    local topRow = vgui.Create("DPanel", ed)
    topRow:Dock(TOP); topRow:SetHeight(32); topRow:DockMargin(10,8,10,0)
    topRow.Paint = nil

    local slotLbl = vgui.Create("DLabel", topRow)
    slotLbl:Dock(LEFT); slotLbl:SetWide(34)
    slotLbl:SetText("Slot:"); slotLbl:SetTextColor(C.textSec)

    local slotCombo = vgui.Create("DComboBox", topRow)
    slotCombo:Dock(LEFT); slotCombo:SetWide(120); slotCombo:SetSortItems(false)
    for _, s in ipairs(ARMOR_SLOTS) do slotCombo:AddChoice(s) end

    local valLbl = vgui.Create("DLabel", topRow)
    valLbl:Dock(LEFT); valLbl:SetWide(46); valLbl:DockMargin(10,0,0,0)
    valLbl:SetText("Value:"); valLbl:SetTextColor(C.textSec)

    local valCombo = vgui.Create("DComboBox", topRow)
    valCombo:Dock(LEFT); valCombo:SetWide(160); valCombo:SetSortItems(false)

    local function RefreshValues()
        valCombo:Clear()
        for _, opt in ipairs(BuildArmorChoices(slotCombo:GetValue())) do
            valCombo:AddChoice(opt == "" and "<empty>" or opt)
        end
    end
    slotCombo.OnSelect = function() RefreshValues() end

    if existingLine then
        slotCombo:SetValue(existingLine:GetColumnText(1))
        valCombo:SetValue(ValueToDisplay(existingLine.RawValue or existingLine:GetColumnText(2)))
    else
        slotCombo:SetValue("torso")
    end
    RefreshValues()

    local hintRow2 = vgui.Create("DPanel", ed)
    hintRow2:Dock(TOP); hintRow2:SetHeight(18); hintRow2:DockMargin(10,4,10,0)
    hintRow2.Paint = nil
    local hintLbl2 = vgui.Create("DLabel", hintRow2)
    hintLbl2:Dock(FILL)
    hintLbl2:SetText("Or check 2+ items in the pool for a $random armor value.")
    hintLbl2:SetTextColor(C.textDim)

    local poolHdr = vgui.Create("DPanel", ed)
    poolHdr:Dock(TOP); poolHdr:SetHeight(24); poolHdr:DockMargin(10,6,10,0)
    poolHdr.Paint = function(_, w, h)
        draw.RoundedBoxEx(4,0,0,w,h,C.panelLight,true,true,false,false)
        draw.SimpleText("  Random Pool — check items to include","DermaDefaultBold",
            6, h/2, C.textGold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local botRow2 = vgui.Create("DPanel", ed)
    botRow2:Dock(BOTTOM); botRow2:SetHeight(38); botRow2:DockMargin(10,0,10,8)
    botRow2.Paint = nil

    local aScroll = vgui.Create("DScrollPanel", ed)
    aScroll:Dock(FILL); aScroll:DockMargin(10,2,10,2)
    aScroll.Paint = function(_, w, h) draw.RoundedBox(3,0,0,w,h,C.panel) end

    local aInner = vgui.Create("DPanel", aScroll)
    aInner.Paint = nil
    local aCBs = {}

    local currentArmorSlot = slotCombo:GetValue()

    local function RebuildArmorPool(slot)
        currentArmorSlot = slot
        for _, cb in ipairs(aCBs) do if IsValid(cb) then cb:Remove() end end
        aCBs = {}
        for _, ch in ipairs(aInner:GetChildren()) do if IsValid(ch) then ch:Remove() end end
        local opts = BuildArmorChoices(slot)
        -- Single column layout so labels are never truncated
        local innerW = math.max(aScroll:GetWide() - 12, 100)
        local ARH = 22
        aInner:SetSize(innerW, #opts * ARH + 4)
        for i, opt in ipairs(opts) do
            local y = (i-1) * ARH + 2
            local cb = vgui.Create("DCheckBox", aInner)
            cb:SetPos(4, y+3); cb:SetSize(16,16)
            cb:SetValue(table.HasValue(initA, opt))
            cb._val = opt
            local lbl3 = vgui.Create("DLabel", aInner)
            lbl3:SetPos(24, y); lbl3:SetSize(innerW-30, ARH)
            lbl3:SetText(opt=="" and "<empty>" or opt); lbl3:SetTextColor(C.textSec)
            aCBs[#aCBs+1] = cb
        end
    end

    local armorBuilt = false
    aScroll.PerformLayout = function(s, w, h)
        if #aCBs > 0 then
            local innerW = math.max(w-12, 100)
            aInner:SetWide(innerW)
            for _, cb in ipairs(aCBs) do
                -- find matching label sibling — just resize all DLabel children
            end
        end
        if not armorBuilt then
            armorBuilt = true
            RebuildArmorPool(currentArmorSlot)
        end
    end
    aScroll:AddItem(aInner)

    local origOnSel = slotCombo.OnSelect
    slotCombo.OnSelect = function(...)
        if origOnSel then origOnSel(...) end
        RebuildArmorPool(slotCombo:GetValue())
    end

    local confA = MakeBtn(botRow2, existingLine and "✔ Save" or "✔ Add", C.green, C.greenHov, function()
        local slot = string.Trim(slotCombo:GetValue() or "")
        if slot == "" then chat.AddText(Color(255,0,0),"[ZC] Slot required."); return end
        local pool = {}
        for _, cb in ipairs(aCBs) do
            if IsValid(cb) and cb:GetChecked() then pool[#pool+1] = cb._val end
        end
        local parsed
        if #pool >= 2 then
            parsed = { "$random" }
            for _, v in ipairs(pool) do parsed[#parsed+1] = v end
        elseif #pool == 1 then
            parsed = pool[1]
        else
            local rv = string.Trim(valCombo:GetValue() or "")
            if rv == "<empty>" then rv = "" end
            parsed = ParseValueFromInput(rv)
        end
        if parsed == "" then
            local al = frame["ArmorList"..k]
            if IsValid(al) then
                for idx, line in ipairs(al:GetLines() or {}) do
                    if line:GetColumnText(1) == slot then al:RemoveLine(idx); break end
                end
            end
        else
            frame:UpsertArmorLine(slot, parsed, k)
        end
        ed:Close()
    end)
    confA:Dock(LEFT); confA:SetWide(110); confA:DockMargin(0,4,6,4)

    local cancelA = MakeBtn(botRow2, "Cancel", C.grey, C.greyHov, function() ed:Close() end)
    cancelA:Dock(LEFT); cancelA:SetWide(90); cancelA:DockMargin(0,4,0,4)
end

-- ── vgui.Register ─────────────────────────────────────────────────────────────

-- ── ResetLoadoutToDefault ────────────────────────────────────────────────────

function PANEL:ResetLoadoutToDefault(k)
    k = k or ("_"..self:GetMode())
    local ni = self["NameInput"..k]
    local name = ni and string.Trim(ni:GetValue() or "") or ""
    if name == "" then
        chat.AddText(Color(255,0,0), "[ZC] Select a loadout first.")
        return
    end
    if util.NetworkStringToID("ZC_ResetCoopLoadoutToDefault") == 0 then
        chat.AddText(Color(255,120,120), "[ZC] Reset unavailable: net message not pooled yet.")
        return
    end
    net.Start("ZC_ResetCoopLoadoutToDefault")
    net.WriteString(name)
    net.SendToServer()
    chat.AddText(Color(255,180,50), "[ZC] Resetting '" .. name .. "' to default…")
end

function PANEL:ResetAllLoadouts(mode)
    if util.NetworkStringToID("ZC_ResetAllCoopLoadoutsToDefault") == 0 then
        chat.AddText(Color(255,120,120), "[ZC] Reset-all unavailable: net message not pooled yet.")
        return
    end
    net.Start("ZC_ResetAllCoopLoadoutsToDefault")
    net.SendToServer()
    chat.AddText(Color(255,100,30), "[ZC] Resetting ALL loadouts to built-in defaults…")
end

vgui.Register("ZC_CoopLoadoutMenu", PANEL, "DFrame")

-- ── Net receives ──────────────────────────────────────────────────────────────

net.Receive("ZC_SendArmorList", function()
    local jsonStr = net.ReadString()
    local list    = util.JSONToTable(jsonStr)
    if not istable(list) then return end
    -- Merge server list into ARMOR_VALUES_BY_SLOT.
    -- Server already filtered blacklisted keys; we prepend "" for the "no armor" option.
    for slot, keys in pairs(list) do
        if istable(keys) then
            local merged = { "" }  -- always first
            for _, key in ipairs(keys) do
                if key ~= "" and not ARMOR_BLACKLIST[key] then
                    merged[#merged+1] = key
                end
            end
            ARMOR_VALUES_BY_SLOT[slot] = merged
        end
    end
end)

net.Receive("ZC_OpenCoopLoadoutMenu", function()
    local mode = string.lower(net.ReadString() or "rebel")
    if mode ~= "combine" and mode ~= "gordon" then mode = "rebel" end
    currentOpenMode = mode

    if IsValid(activeMenu) then activeMenu:Remove(); activeMenu = nil end
    activeMenu = vgui.Create("ZC_CoopLoadoutMenu")
    loadoutSyncSeq = loadoutSyncSeq + 1
    local syncSeq = loadoutSyncSeq
    loadoutSyncStarted = false
    loadoutSyncCompleted = false

    local function StartLoadoutRequestTimeout(retryCount)
        retryCount = tonumber(retryCount) or 0
        timer.Simple(3.5, function()
            if syncSeq ~= loadoutSyncSeq then return end
            if not IsValid(activeMenu) then return end
            if loadoutSyncStarted or loadoutSyncCompleted then return end
            if table.Count(coopLoadouts or {}) > 0 then return end

            if retryCount < 2 then
                if util.NetworkStringToID("ZC_RequestCoopLoadouts") ~= 0 then
                    net.Start("ZC_RequestCoopLoadouts")
                    net.SendToServer()
                    chat.AddText(Color(255, 200, 120), "[ZC] No sync reply yet, retrying request (" .. tostring(retryCount + 1) .. "/2)...")
                    StartLoadoutRequestTimeout(retryCount + 1)
                    return
                end
            end

            SeedFallbackCoopLoadouts("request-timeout")
        end)
    end

    local function sendWhenPooled(msgName, attempt)
        if util.NetworkStringToID(msgName) ~= 0 then
            net.Start(msgName)
            net.SendToServer()
            if msgName == "ZC_RequestCoopLoadouts" then
                chat.AddText(Color(120, 200, 255), "[ZC] Requested coop loadouts from server...")
                StartLoadoutRequestTimeout()
            end
            return
        end

        attempt = (attempt or 0) + 1
        if attempt <= 8 then
            timer.Simple(0.15, function()
                sendWhenPooled(msgName, attempt)
            end)
        else
            chat.AddText(Color(255, 120, 120), "[ZC] Failed to request menu data (", msgName, " not pooled yet).")
        end
    end

    sendWhenPooled("ZC_RequestCoopLoadouts")
    sendWhenPooled("ZC_RequestSubclassSlotModifiers")
    sendWhenPooled("ZC_RequestCombineResistanceConfig")
    sendWhenPooled("ZC_RequestKnockdownConfig")
    sendWhenPooled("ZC_RequestNoOrganismNPCs")
end)

-- ── Chunked loadout receive (Begin / Entry / End) ────────────────────────────

local _pendingLoadouts = {}
local _pendingExpected = 0

net.Receive("ZC_SendCoopLoadoutsBegin", function()
    loadoutSyncStarted = true
    _pendingExpected = net.ReadUInt(16)
    _pendingLoadouts = {}
    print("[ZC CoopLoadouts] CLIENT: Begin, expecting " .. _pendingExpected .. " entries")
    chat.AddText(Color(120, 200, 255), "[ZC] Sync start: expecting ", Color(255,255,255), tostring(_pendingExpected), Color(120, 200, 255), " loadouts")
end)

net.Receive("ZC_SendCoopLoadoutEntry", function()
    local name = net.ReadString()
    local json = net.ReadString()
    local data = util.JSONToTable(json)
    if data then
        _pendingLoadouts[name] = data
        print("[ZC CoopLoadouts] CLIENT: received entry '" .. name .. "'")
    else
        print("[ZC CoopLoadouts] CLIENT: FAILED to parse entry '" .. name .. "'")
    end
end)

net.Receive("ZC_SendCoopLoadoutsEnd", function()
    loadoutSyncCompleted = true
    local got = table.Count(_pendingLoadouts)
    print("[ZC CoopLoadouts] CLIENT: End - got " .. got .. " / " .. _pendingExpected .. " entries")
    coopLoadouts = _pendingLoadouts
    _pendingLoadouts = {}
    if got <= 0 then
        chat.AddText(Color(255, 120, 120), "[ZC] Sync ended but received 0 loadouts.")
        SeedFallbackCoopLoadouts("chunk-end-empty")
    else
        chat.AddText(Color(120, 255, 140), "[ZC] Sync complete: ", Color(255,255,255), tostring(got), Color(120, 255, 140), " loadouts received")
    end
    if not IsValid(activeMenu) then
        print("[ZC CoopLoadouts] CLIENT: no active menu, data stored for next open")
        return
    end
    activeMenu:RefreshLoadoutList()
    if activeMenu.CurrentPresetName and coopLoadouts[activeMenu.CurrentPresetName] then
        activeMenu:LoadPreset(activeMenu.CurrentPresetName)
    end
end)

-- Legacy single-message handler (kept in case of old server code)
net.Receive("ZC_SendCoopLoadouts", function()
    loadoutSyncCompleted = true
    local json = net.ReadString()
    print("[ZC CoopLoadouts] CLIENT: legacy ZC_SendCoopLoadouts, JSON length = " .. (isstring(json) and #json or "nil"))
    coopLoadouts = (isstring(json) and util.JSONToTable(json)) or {}
    print("[ZC CoopLoadouts] CLIENT: parsed " .. table.Count(coopLoadouts) .. " loadouts")
    if table.Count(coopLoadouts or {}) <= 0 then
        SeedFallbackCoopLoadouts("legacy-empty")
    end
    if not IsValid(activeMenu) then return end
    activeMenu:RefreshLoadoutList()
    if activeMenu.CurrentPresetName and coopLoadouts[activeMenu.CurrentPresetName] then
        activeMenu:LoadPreset(activeMenu.CurrentPresetName)
    end
end)

net.Receive("ZC_SendSubclassSlotModifiers", function()
    slotModifiers = net.ReadTable() or slotModifiers
    if not IsValid(activeMenu) then return end
    for faction, ctrlMap in pairs(activeMenu.SlotControls or {}) do
        local src = slotModifiers[faction] or {}
        for key, slider in pairs(ctrlMap) do
            if IsValid(slider) then slider:SetValue(tonumber(src[key]) or 1) end
        end
    end
end)

net.Receive("ZC_SendCombineResistanceConfig", function()
    resistanceConfig = net.ReadTable() or resistanceConfig
    if not IsValid(activeMenu) then return end

    local rc = activeMenu.ResistControls or {}
    local function set(m, key, val)
        local c = rc[m] and rc[m][key]
        if IsValid(c) then c:SetValue(tonumber(val) or 0) end
    end

    local cp = resistanceConfig.combinePlayer  or {}
    local mp = resistanceConfig.metrocopPlayer or {}
    local cn = resistanceConfig.combineNpc     or {}
    local mn = resistanceConfig.metrocopNpc    or {}
    local rn = resistanceConfig.rebelNpc       or {}
    local gd = resistanceConfig.gordon         or {}

    for _, m in ipairs(MODES) do
        set(m, "referencePlayers", resistanceConfig.referencePlayers)
        set(m, "minScale",         resistanceConfig.minScale)
        set(m, "maxScale",         resistanceConfig.maxScale)
    end
    set("combine","combinePlayerBase",      cp.base);  set("combine","combinePlayerPerPlayer",  cp.perPlayer)
    set("combine","metrocopPlayerBase",     mp.base);  set("combine","metrocopPlayerPerPlayer", mp.perPlayer)
    set("combine","combineNpcBase",         cn.base);  set("combine","combineNpcPerPlayer",     cn.perPlayer)
    set("combine","metrocopNpcBase",        mn.base);  set("combine","metrocopNpcPerPlayer",    mn.perPlayer)
    set("rebel",  "rebelNpcBase",           rn.base);  set("rebel",  "rebelNpcPerPlayer",       rn.perPlayer)
    set("gordon", "gordonBase",             gd.base);  set("gordon", "gordonPerPlayer",         gd.perPlayer)

    for _, fn in pairs(activeMenu.LiveUpdaters or {}) do if fn then fn() end end
end)

net.Receive("ZC_SendKnockdownConfig", function()
    knockdownConfig = net.ReadTable() or knockdownConfig
    if not IsValid(activeMenu) then return end
    local kc = activeMenu.KnockControls or {}
    local function kset(key, val)
        local s = kc[key]
        if IsValid(s) then s:SetValue(tonumber(val) or 0) end
    end
    kset("refPlayers",     knockdownConfig.refPlayers)
    kset("harmBase",       knockdownConfig.harmBase)
    kset("harmPerPlayer",  knockdownConfig.harmPerPlayer)
    kset("bloodBase",      knockdownConfig.bloodBase)
    kset("bloodPerPlayer", knockdownConfig.bloodPerPlayer)
    kset("legBase",        knockdownConfig.legBase)
    kset("legPerPlayer",   knockdownConfig.legPerPlayer)
end)

net.Receive("ZC_SendNoOrganismNPCs", function()
    noOrganismNPCs = net.ReadBool() and true or false
    if not IsValid(activeMenu) then return end
    for _, btn in ipairs(activeMenu.NoOrgButtons or {}) do
        SyncNoOrganismButton(btn)
    end
end)
