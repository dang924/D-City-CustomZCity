-- cl_zrp_class_builder.lua — ZRP Custom PlayerClass Builder.
-- Opened via "zrp_open_class_builder" (admin only) or chat aliases !classes / !zrpclasses.
--
-- The user has indicated this builder will eventually grow a model browser with
-- bone-data validation. Until then the model field is a path entry; structure
-- the form so the picker can be slotted in later without rewriting save logic.

if SERVER then return end

local ZRP_CB = {
    classes = {},   -- last received class list snapshot
    panel   = nil,  -- active VGUI panel
}

local function IsAdmin()
    return IsValid(LocalPlayer()) and LocalPlayer():IsAdmin()
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Reuse the loot editor's category guesser for the weapons multiselect. If it
-- isn't loaded for some reason we fall back to a flat list.
local function GetWeaponList()
    local out = {}
    local seen = {}
    for _, w in ipairs(weapons.GetList() or {}) do
        local cls = w.ClassName or w.Classname or w.class
        if isstring(cls) and string.StartWith(string.lower(cls), "weapon_") then
            cls = string.lower(cls)
            if not seen[cls] then
                seen[cls] = true
                out[#out + 1] = cls
            end
        end
    end
    table.sort(out)
    return out
end

local function GetArmorList()
    -- The codebase uses string keys like "vest1", "helmet1". Anything goes via
    -- hg.AddArmor; we offer a sensible default list and let admins type custom.
    return { "vest1", "vest2", "vest3", "vest4", "helmet1", "helmet2" }
end

local function FindClassByName(name)
    for _, c in ipairs(ZRP_CB.classes) do
        if c.name == name then return c end
    end
end

-- ── Net receivers ─────────────────────────────────────────────────────────────

net.Receive("ZRP_ClassListSync", function()
    ZRP_CB.classes = net.ReadTable() or {}
    if IsValid(ZRP_CB.panel) and ZRP_CB.panel.RefreshList then
        ZRP_CB.panel:RefreshList()
    end
end)

net.Receive("ZRP_OpenClassBuilder", function()
    if not IsAdmin() then return end
    ZRP_CB.OpenBuilder()
end)

-- ── The form (right-hand pane) ───────────────────────────────────────────────
-- Returns the form panel and a function to load a class definition into it.

local function BuildForm(parent)
    local form = vgui.Create("DPanel", parent)
    form:Dock(FILL)
    form:DockMargin(4, 0, 0, 0)
    form:SetPaintBackground(false)

    local function row(tall)
        local r = vgui.Create("DPanel", form)
        r:Dock(TOP)
        r:SetTall(tall or 24)
        r:DockMargin(0, 2, 0, 2)
        r:SetPaintBackground(false)
        return r
    end

    local function label(parent, text, w)
        local l = vgui.Create("DLabel", parent)
        l:Dock(LEFT)
        l:SetWide(w or 95)
        l:SetText(text)
        return l
    end

    -- Header: name
    local nameRow = row(24)
    label(nameRow, "Class Name:")
    local nameEntry = vgui.Create("DTextEntry", nameRow)
    nameEntry:Dock(FILL)
    nameEntry:SetPlaceholderText("e.g. Mechanic")

    -- Model path
    local modelRow = row(24)
    label(modelRow, "Model Path:")
    local modelEntry = vgui.Create("DTextEntry", modelRow)
    modelEntry:Dock(FILL)
    modelEntry:SetPlaceholderText("models/player/group03/male_07.mdl")

    -- Reserve space for a future model-picker button — wire is in place.
    local modelPickRow = row(20)
    local modelHint = vgui.Create("DLabel", modelPickRow)
    modelHint:Dock(FILL)
    modelHint:SetText("  (Model browser w/ bone-data validation: planned)")
    modelHint:SetTextColor(Color(140, 140, 150))

    -- Color
    local colorRow = row(120)
    label(colorRow, "Player Color:")
    local colorMixer = vgui.Create("DColorMixer", colorRow)
    colorMixer:Dock(FILL)
    colorMixer:SetPalette(false)
    colorMixer:SetAlphaBar(false)
    colorMixer:SetWangs(true)
    colorMixer:SetColor(Color(180, 180, 180))

    -- Speeds + health
    local statsRow = row(24)
    label(statsRow, "Walk / Run / HP:")
    local walkEntry = vgui.Create("DTextEntry", statsRow)
    walkEntry:Dock(LEFT) walkEntry:SetWide(60) walkEntry:DockMargin(0, 0, 4, 0)
    walkEntry:SetNumeric(true) walkEntry:SetValue("200")
    local runEntry = vgui.Create("DTextEntry", statsRow)
    runEntry:Dock(LEFT) runEntry:SetWide(60) runEntry:DockMargin(0, 0, 4, 0)
    runEntry:SetNumeric(true) runEntry:SetValue("360")
    local hpEntry = vgui.Create("DTextEntry", statsRow)
    hpEntry:Dock(LEFT) hpEntry:SetWide(60) hpEntry:DockMargin(0, 0, 4, 0)
    hpEntry:SetNumeric(true) hpEntry:SetValue("100")
    local statsHint = vgui.Create("DLabel", statsRow)
    statsHint:Dock(FILL)
    statsHint:SetText("  walk speed / run speed / max HP")
    statsHint:SetTextColor(Color(140, 140, 150))

    -- Weapons
    local wepHdr = row(20)
    local wepLbl = vgui.Create("DLabel", wepHdr)
    wepLbl:Dock(FILL)
    wepLbl:SetFont("DermaDefaultBold") wepLbl:SetTextColor(Color(160, 200, 230))
    wepLbl:SetText("  Weapons (double-click to add/remove)")

    local wepRow = row(150)
    -- Available list
    local wepAvail = vgui.Create("DListView", wepRow)
    wepAvail:Dock(LEFT) wepAvail:SetWide(220) wepAvail:DockMargin(0, 0, 4, 0)
    wepAvail:SetMultiSelect(false)
    wepAvail:AddColumn("Available")
    -- Selected list
    local wepSel = vgui.Create("DListView", wepRow)
    wepSel:Dock(FILL)
    wepSel:SetMultiSelect(false)
    wepSel:AddColumn("Selected")

    local wepAvailItems = GetWeaponList()
    for _, cls in ipairs(wepAvailItems) do
        wepAvail:AddLine(cls)
    end
    wepAvail.OnRowSelected = function(_, _, row)
        local cls = row:GetValue(1)
        wepSel:AddLine(cls)
    end

    wepSel.OnRowSelected = function(self, idx)
        self:RemoveLine(idx)
    end

    -- Manual weapon add (for SWEPs not in the global list)
    local wepAddRow = row(24)
    local wepAddEntry = vgui.Create("DTextEntry", wepAddRow)
    wepAddEntry:Dock(FILL)
    wepAddEntry:DockMargin(0, 0, 4, 0)
    wepAddEntry:SetPlaceholderText("manual weapon class (e.g. weapon_custom_xyz)")
    local wepAddBtn = vgui.Create("DButton", wepAddRow)
    wepAddBtn:Dock(RIGHT) wepAddBtn:SetWide(80)
    wepAddBtn:SetText("Add to Selected")
    wepAddBtn.DoClick = function()
        local cls = string.lower(string.Trim(wepAddEntry:GetValue() or ""))
        if cls == "" then return end
        wepSel:AddLine(cls)
        wepAddEntry:SetValue("")
    end

    -- Armor
    local armorHdr = row(20)
    local armorLbl = vgui.Create("DLabel", armorHdr)
    armorLbl:Dock(FILL)
    armorLbl:SetFont("DermaDefaultBold") armorLbl:SetTextColor(Color(160, 200, 230))
    armorLbl:SetText("  Armor (double-click to add/remove)")

    local armorRow = row(100)
    local armorAvail = vgui.Create("DListView", armorRow)
    armorAvail:Dock(LEFT) armorAvail:SetWide(220) armorAvail:DockMargin(0, 0, 4, 0)
    armorAvail:SetMultiSelect(false)
    armorAvail:AddColumn("Available")
    local armorSel = vgui.Create("DListView", armorRow)
    armorSel:Dock(FILL)
    armorSel:SetMultiSelect(false)
    armorSel:AddColumn("Selected")

    for _, ar in ipairs(GetArmorList()) do armorAvail:AddLine(ar) end
    armorAvail.OnRowSelected = function(_, _, row) armorSel:AddLine(row:GetValue(1)) end
    armorSel.OnRowSelected = function(self, idx) self:RemoveLine(idx) end

    -- Buttons
    local btnRow = row(28)
    local saveBtn = vgui.Create("DButton", btnRow)
    saveBtn:Dock(LEFT) saveBtn:SetWide(120) saveBtn:DockMargin(0, 0, 6, 0)
    saveBtn:SetText("Save Class")

    local testBtn = vgui.Create("DButton", btnRow)
    testBtn:Dock(LEFT) testBtn:SetWide(120) testBtn:DockMargin(0, 0, 6, 0)
    testBtn:SetText("Test on Self")

    local clearBtn = vgui.Create("DButton", btnRow)
    clearBtn:Dock(LEFT) clearBtn:SetWide(80)
    clearBtn:SetText("Clear")

    -- ── Build / collect / load helpers ────────────────────────────────────────
    local function collect()
        local weapons_ = {}
        for _, ln in ipairs(wepSel:GetLines()) do weapons_[#weapons_ + 1] = ln:GetValue(1) end
        local armor_ = {}
        for _, ln in ipairs(armorSel:GetLines()) do armor_[#armor_ + 1] = ln:GetValue(1) end

        local c = colorMixer:GetColor()

        return {
            name      = string.Trim(nameEntry:GetValue() or ""),
            model     = string.Trim(modelEntry:GetValue() or ""),
            color     = {c.r, c.g, c.b},
            walkSpeed = tonumber(walkEntry:GetValue()) or 200,
            runSpeed  = tonumber(runEntry:GetValue())  or 360,
            maxHealth = tonumber(hpEntry:GetValue())   or 100,
            weapons   = weapons_,
            ammo      = {},  -- ammo grid is intentionally minimal in v1
            armor     = armor_,
        }
    end

    local function loadDef(def, opts)
        opts = opts or {}
        nameEntry:SetValue(opts.asClone and ("Copy of " .. (def.name or "")) or (def.name or ""))
        modelEntry:SetValue(def.model or "")
        if def.color then colorMixer:SetColor(Color(def.color[1] or 200, def.color[2] or 200, def.color[3] or 200)) end
        walkEntry:SetValue(tostring(def.walkSpeed or 200))
        runEntry:SetValue(tostring(def.runSpeed or 360))
        hpEntry:SetValue(tostring(def.maxHealth or 100))

        wepSel:Clear()
        for _, cls in ipairs(def.weapons or {}) do wepSel:AddLine(cls) end

        armorSel:Clear()
        for _, ar in ipairs(def.armor or {}) do armorSel:AddLine(ar) end
    end

    local function clearForm()
        nameEntry:SetValue("")
        modelEntry:SetValue("")
        colorMixer:SetColor(Color(180, 180, 180))
        walkEntry:SetValue("200")
        runEntry:SetValue("360")
        hpEntry:SetValue("100")
        wepSel:Clear()
        armorSel:Clear()
    end

    saveBtn.DoClick = function()
        local def = collect()
        if def.name == "" then
            Derma_Message("Class name is required.", "Save", "OK")
            return
        end
        if def.model == "" then
            Derma_Message("Model path is required.", "Save", "OK")
            return
        end

        net.Start("ZRP_ClassSave")
        net.WriteTable(def)
        net.SendToServer()
    end

    testBtn.DoClick = function()
        local name = string.Trim(nameEntry:GetValue() or "")
        if name == "" then
            Derma_Message("Save the class first, then Test on Self.", "Test", "OK")
            return
        end
        Derma_Query(
            "Apply class '" .. name .. "' to yourself now?\n(Use only on yourself; this will reset your equipment.)",
            "Test on Self",
            "Yes", function()
                net.Start("ZRP_ClassTestOnSelf")
                net.WriteString(name)
                net.SendToServer()
            end,
            "No", function() end
        )
    end

    clearBtn.DoClick = clearForm

    return form, loadDef, clearForm
end

-- ── Panel builder ─────────────────────────────────────────────────────────────

function ZRP_CB.OpenBuilder()
    if IsValid(ZRP_CB.panel) then ZRP_CB.panel:Remove() end

    local PANEL_W, PANEL_H = 900, 640
    local sw, sh = ScrW(), ScrH()

    local frame = vgui.Create("DFrame")
    frame:SetTitle("ZRP Custom PlayerClass Builder")
    frame:SetSize(PANEL_W, PANEL_H)
    frame:SetPos(sw * 0.5 - PANEL_W * 0.5, sh * 0.5 - PANEL_H * 0.5)
    frame:SetDraggable(true)
    frame:MakePopup()
    ZRP_CB.panel = frame

    -- Left: class list. Right: form.
    local left = vgui.Create("DPanel", frame)
    left:Dock(LEFT)
    left:SetWide(280)
    left:DockMargin(4, 0, 0, 4)
    left:SetPaintBackground(false)

    local listHdr = vgui.Create("DLabel", left)
    listHdr:Dock(TOP)
    listHdr:SetTall(20)
    listHdr:SetFont("DermaDefaultBold")
    listHdr:SetTextColor(Color(160, 200, 230))
    listHdr:SetText("  Existing Classes")

    local list = vgui.Create("DListView", left)
    list:Dock(FILL)
    list:SetMultiSelect(false)
    list:AddColumn("Type"):SetWidth(60)
    list:AddColumn("Name"):SetWidth(180)

    local form, loadDef, clearForm = BuildForm(frame)

    function frame:RefreshList()
        list:Clear()
        for _, c in ipairs(ZRP_CB.classes) do
            local ln = list:AddLine(c.isBuiltIn and "Built-in" or "Custom", c.name)
            ln.ZRP_ClassName = c.name
            ln.ZRP_IsBuiltIn = c.isBuiltIn
            if c.isBuiltIn then
                ln:SetTooltip("Built-in class — read-only. Right-click to Clone.")
            end
        end
    end

    list.OnRowRightClick = function(_, _, row)
        if not row.ZRP_ClassName then return end
        local def = FindClassByName(row.ZRP_ClassName)
        if not def then return end

        local menu = DermaMenu()

        if def.isBuiltIn then
            menu:AddOption("Clone into editor", function()
                loadDef({
                    name       = def.name,
                    model      = "",  -- built-ins don't expose model in snapshot
                    color      = {180, 180, 180},
                    walkSpeed  = 200, runSpeed = 360, maxHealth = 100,
                    weapons    = {}, ammo = {}, armor = {},
                    clonedFrom = def.name,
                }, { asClone = true })
            end)
        else
            menu:AddOption("Edit", function()
                loadDef(def)
            end)
            menu:AddOption("Clone", function()
                loadDef(def, { asClone = true })
            end)
            menu:AddSpacer()
            menu:AddOption("Delete", function()
                Derma_Query(
                    "Delete custom class '" .. def.name .. "'?",
                    "Delete",
                    "Yes", function()
                        net.Start("ZRP_ClassDelete")
                        net.WriteString(def.name)
                        net.SendToServer()
                    end,
                    "No", function() end
                )
            end)
        end

        menu:Open()
    end

    list.DoDoubleClick = function(_, _, row)
        if not row.ZRP_ClassName then return end
        local def = FindClassByName(row.ZRP_ClassName)
        if not def then return end
        if def.isBuiltIn then
            Derma_Message("Built-in classes are read-only. Right-click and use Clone.", "Read-only", "OK")
        else
            loadDef(def)
        end
    end

    frame:RefreshList()
end

-- ── Console command alias ────────────────────────────────────────────────────

concommand.Add("zrp_open_class_builder_cl", function()
    if not IsAdmin() then return end
    RunConsoleCommand("zrp_open_class_builder")
end)
