-- cl_subcategories_entities.lua
-- Adapted from a weapons subcategory script to work for Entities (Spawnmenu -> Entities)
-- Groups entities by Category (list.Get("SpawnableEntities")[class].Category)
-- and then by a subcategory parsed from PrintName like "[HLM] ...".
-- If no subcategory is found, they go into "Other".

local function safeGet(t, k) return (t and t[k]) or nil end

-- Таблица соответствий коротких кодов и полных названий подкатегорий
local SubcatFullNames = {
    ["VT"]   = "Vests",
    ["VA"]   = "Vest Attachments",
    ["HLM"]  = "Combat Helmets",
    ["NVG"]  = "NVG",
    ["CHLM"] = "Civilian Helmets",
    ["EHLM"] = "Exotic Helmets",
    ["BP"]   = "Backpacks",
    ["BT"]   = "Belts",
    ["CD"]   = "Сommunication device",
    ["HW"]   = "Headwear",
    ["GM"]   = "Gas Masks",
    ["FE"]   = "Face Equipment",
    ["GH"]   = "Ghillie",
    ["MS"]   = "Misc"
}

-- Порядок сортировки по этим же кодам
local SubcatOrder = {
    "VT", "VA", "HLM", "NVG", "CHLM", "EHLM",
    "BP", "BT", "CD", "HW", "GM", "FE",
    "GH", "MS"
}

-- Utility: extract subcategory from PrintName
local function extractSubcatFromName(name)
    if not name then return "Other" end
    local code = string.match(name, "^%s*%[([^%]]+)%]") or string.match(name, "%[([^%]]+)%]")
    if not code then return "Other" end
    return SubcatFullNames[code] or "Other"
end

-- Provide a right-click generic menu for entity icons (copy/delete)
local function OpenGenericEntityRightClickMenu(self)
    local menu = DermaMenu()
    if ( self:GetSpawnName() and self:GetSpawnName() ~= "" ) then
        menu:AddOption( "#spawnmenu.menu.copy", function() SetClipboardText( self:GetSpawnName() ) end ):SetIcon( "icon16/page_copy.png" )
    end

    hook.Run( "SpawnmenuIconMenuOpen", menu, self, self:GetContentType() )

    if ( !IsValid( self:GetParent() ) || !self:GetParent().GetReadOnly || !self:GetParent():GetReadOnly() ) then
        menu:AddSpacer()
        menu:AddOption( "#spawnmenu.menu.delete", function()
            self:Remove()
            hook.Run( "SpawnlistContentChanged" )
        end ):SetIcon( "icon16/bin_closed.png" )
    end

    menu:Open()
    self.SubMenu = menu
end

-- Main hook: populate Entities tab with subcategories
hook.Add("PopulateEntities", "Subcat_PopulateEntities", function(pnlContent, tree)
    if not pnlContent or not tree then return end

    timer.Simple(0, function()
        local entries = list.Get("SpawnableEntities") or {}
        if table.IsEmpty(entries) then return end

        local Categorised = {}

        for class, data in pairs(entries) do
            if not data then continue end
            if data.Spawnable == false then continue end
            if data.Category ~= "JMod - EZ DayZ Armor" then continue end

            local Category = data.Category
            local nicename = data.PrintName or class
            local SubCategory = extractSubcatFromName(nicename)

            Categorised[Category] = Categorised[Category] or {}
            Categorised[Category][SubCategory] = Categorised[Category][SubCategory] or {}
            table.insert(Categorised[Category][SubCategory], { Class = class, Data = data })
        end

        local root = tree:Root()
        if not IsValid(root) then return end
        local childNodes = root:GetChildNodes() or {}

        for _, node in pairs(childNodes) do
            local ok, catName = pcall(function() return node:GetText() end)
            if not ok or not catName then continue end
            if not Categorised[catName] then continue end

            local catSubcats = Categorised[catName]

            node.DoPopulate = function(self)
                self.PropPanel = vgui.Create("ContentContainer", pnlContent)
                self.PropPanel:SetVisible(false)
                self.PropPanel:SetTriggerSpawnlistChange(false)

                local subNames = {}
                for subn, _ in pairs(catSubcats) do table.insert(subNames, subn) end

                -- Кастомная сортировка подкатегорий по таблице SubcatOrder
                table.sort(subNames, function(a, b)
                    local ia, ib
                    for i, code in ipairs(SubcatOrder) do
                        if SubcatFullNames[code] == a then ia = i end
                        if SubcatFullNames[code] == b then ib = i end
                    end
                    ia = ia or math.huge
                    ib = ib or math.huge
                    return ia < ib
                end)

                for _, subcatName in ipairs(subNames) do
                    local subList = catSubcats[subcatName]
                    if not subList or #subList == 0 then continue end

                    if table.Count(catSubcats) > 1 then
                        local header = vgui.Create("ContentHeader", self.PropPanel)
                        header:SetText(" " .. subcatName)
                        self.PropPanel:Add(header)
                    end

                    table.sort(subList, function(a,b)
                        local an = (a.Data and a.Data.PrintName) or a.Class
                        local bn = (b.Data and b.Data.PrintName) or b.Class
                        return an < bn
                    end)

                    for _, entEntry in ipairs(subList) do
                        local class = entEntry.Class
                        local data = entEntry.Data or {}
                        local nicename = data.PrintName or class
                        local material = data.IconOverride or ("entities/" .. class .. ".png")
                        local admin = data.AdminOnly

                        local icon = spawnmenu.CreateContentIcon("entity", self.PropPanel, {
                            nicename  = nicename,
                            spawnname = class,
                            material  = material,
                            admin     = admin
                        })
                        icon.OpenMenu = OpenGenericEntityRightClickMenu
                    end
                end
            end

            node.DoClick = function(self)
                self:DoPopulate()
                pnlContent:SwitchPanel(self.PropPanel)
            end
        end

        local FirstNode = root:GetChildNode(0)
        if IsValid(FirstNode) then FirstNode:InternalDoClick() end
    end)
end)
