local function getWorldLootLib()
    return ZSCAV and ZSCAV.WorldLoot or nil
end

local function isAdminLike(ply)
    return IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

local function getModelFromSpawnmenuPanel(pnl)
    if not IsValid(pnl) or not pnl.GetModelName then return "" end
    local lib = getWorldLootLib()
    local model = lib and lib.NormalizeModel and lib.NormalizeModel(pnl:GetModelName()) or string.lower(string.Trim(tostring(pnl:GetModelName() or "")))
    if model == "" or not string.EndsWith(model, ".mdl") then return "" end
    return model
end

local function sendRegisterValuable(model, existing)
    local lib = getWorldLootLib()
    if not lib then return end

    local payload = {
        model = model,
        item_class = tostring(istable(existing) and existing.item_class or (lib.GetSuggestedValuableClassForModel and lib.GetSuggestedValuableClassForModel(model)) or ""),
        name = tostring(istable(existing) and existing.name or (lib.GetSuggestedValuableNameForModel and lib.GetSuggestedValuableNameForModel(model)) or "Prop Item"),
        w = tonumber(istable(existing) and existing.w) or 1,
        h = tonumber(istable(existing) and existing.h) or 1,
        weight = tonumber(istable(existing) and existing.weight) or 0.5,
        category = tostring(istable(existing) and existing.category or "valuable"),
        open_config = true,
    }

    net.Start(lib.Net.Action)
        net.WriteUInt(lib.ACTION_REGISTER_VALUABLE, 4)
        net.WriteString(util.TableToJSON(payload, false) or "{}")
    net.SendToServer()
end

local function openLootAuthoring(page, model)
    model = string.Trim(tostring(model or ""))
    if model == "" then return end
    RunConsoleCommand("zscav_loot_gui", tostring(page or "valuable"), model)
end

hook.Add("SpawnmenuIconMenuOpen", "ZScavSpawnmenuCatalogItem", function(menu, pnl, iconType)
    if iconType ~= "model" then return end
    if not IsValid(menu) then return end

    local ply = LocalPlayer()
    if not isAdminLike(ply) then return end

    local lib = getWorldLootLib()
    if not lib then return end

    local model = getModelFromSpawnmenuPanel(pnl)
    if model == "" then return end

    local state = lib.GetState and lib.GetState() or {}
    local containerDef = istable(state.model_containers) and state.model_containers[model] or nil
    local existing = lib.GetWorldItemDefByModel and lib.GetWorldItemDefByModel(model) or nil

    menu:AddSpacer()

    local authoringPage = containerDef and "model" or "valuable"
    local openOption = menu:AddOption("ZScav: Open loot authoring", function()
        openLootAuthoring(authoringPage, model)
    end)
    if IsValid(openOption) and openOption.SetIcon then
        openOption:SetIcon("icon16/application_view_tile.png")
    end

    if containerDef then
        local blocked = menu:AddOption("ZScav: Model already used by loot container", function() end)
        if IsValid(blocked) and blocked.SetIcon then
            blocked:SetIcon("icon16/lock.png")
        end
        if IsValid(blocked) and blocked.SetEnabled then
            blocked:SetEnabled(false)
        end
        return
    end

    local label = existing and "ZScav: Edit catalog item + open config" or "ZScav: Add item to catalog + open config"
    local option = menu:AddOption(label, function()
        sendRegisterValuable(model, existing)
    end)

    if IsValid(option) and option.SetIcon then
        option:SetIcon(existing and "icon16/pencil.png" or "icon16/package_add.png")
    end
end)