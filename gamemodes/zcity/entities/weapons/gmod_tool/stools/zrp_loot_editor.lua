-- zrp_loot_editor.lua — LootEditor stool for placing & managing ZRP containers.
-- Category: ZBattle  |  Admin-only

TOOL.Category = "ZBattle"
TOOL.Name     = "ZRP LootEditor"

TOOL.ClientConVar["model"]        = "models/props_junk/wood_crate001a.mdl"
TOOL.ClientConVar["respawn_delay"] = "900"

-- Available container models for the panel dropdown.
local CONTAINER_MODELS = {
    { label = "Wood Crate (small)",     model = "models/props_junk/wood_crate001a.mdl" },
    { label = "Wood Crate (large)",     model = "models/props_junk/wood_crate002a.mdl" },
    { label = "Cardboard Box",          model = "models/props_junk/cardboard_box001a.mdl" },
    { label = "Metal Box",              model = "models/props_c17/metalbox01a.mdl" },
    { label = "Dresser (weapons)",      model = "models/props_c17/FurnitureDresser001a.mdl" },
    { label = "Storage Closet (large)", model = "models/props_wasteland/controlroom_storagecloset001a.mdl" },
    { label = "Lockers",                model = "models/props_c17/Lockers001a.mdl" },
    { label = "Fridge (food)",          model = "models/props_wasteland/kitchen_fridge001a.mdl" },
    { label = "Suitcase",               model = "models/props_c17/SuitCase001a.mdl" },
    { label = "Oil Drum",               model = "models/props_c17/oildrum001.mdl" },
    { label = "Footlocker",             model = "models/props/CS_militia/footlocker01_closed.mdl" },
    { label = "Military Crate (large)", model = "models/props/CS_militia/crate_extralargemill.mdl" },
}

-- ── Left click: place a new ZRP container ────────────────────────────────────

function TOOL:LeftClick(trace)
    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsAdmin() then return false end

    if SERVER then
        if not ZRP or not ZRP.Containers then
            ply:ChatPrint("[ZRP] ZRP mode not loaded. Start/force ZRP first.")
            return false
        end

        local pos   = trace.HitPos + trace.HitNormal * 4  -- push slightly off surface
        local ang   = Angle(0, ply:EyeAngles().y, 0)      -- face forward, flat on ground
        local model = ply:GetInfo(self:GetMode() .. "_model")
        if not model or model == "" then model = "models/props_junk/wood_crate001a.mdl" end
        -- Sanitise model path.
        model = string.lower(string.Trim(model))
        if string.find(model, "%.%.") then return false end

        local delay = tonumber(ply:GetInfo(self:GetMode() .. "_respawn_delay")) or 900
        delay = math.Clamp(delay, 1, 86400)

        ZRP.Containers[#ZRP.Containers + 1] = {
            model        = model,
            pos          = pos,
            ang          = ang,
            respawnDelay = delay,
            lootOverride = {},
        }
        local id = #ZRP.Containers
        ZRP.SaveContainers()
        ZRP.SpawnContainer(id)
        if ZRP.SyncContainersToPlayer then ZRP.SyncContainersToPlayer(ply) end
        ply:ChatPrint("[ZRP] Container #" .. id .. " added.")
    end

    return true
end

-- ── Right click: remove nearest ZRP container OR adopt world prop ───────────

function TOOL:RightClick(trace)
    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsAdmin() then return false end

    if SERVER then
        local trEnt = trace.Entity

        -- If right-clicking a lootable world prop, adopt it as a world container.
        if IsValid(trEnt) and trEnt:GetClass() ~= "zrp_container" then
            local mdl = trEnt:GetModel()
            if mdl and hg and hg.loot_boxes and hg.loot_boxes[string.lower(mdl)] then
                if ZRP.AdoptWorldProp then
                    local ok, msg = ZRP.AdoptWorldProp(trEnt, ply)
                    ply:ChatPrint("[ZRP] " .. (msg or (ok and "Adopted." or "Adoption failed.")))
                    if ok and ZRP.SyncWorldContainersToPlayer then
                        ZRP.SyncWorldContainersToPlayer(ply)
                    end
                    if ok then return true end
                    -- fall through if adoption couldn't be performed (returned false)
                end
            end
        end

        local hitPos = trace.HitPos
        local closest_id   = nil
        local closest_dist = 150   -- max detection radius (units)

        for _, ent in ipairs(ents.FindByClass("zrp_container")) do
            if not IsValid(ent) then continue end
            local d = hitPos:Distance(ent:GetPos())
            if d < closest_dist then
                closest_dist = d
                -- Find its registry ID.
                if ent.ZRP_ContainerID then
                    closest_id = ent.ZRP_ContainerID
                end
            end
        end

        if closest_id then
            if IsValid(ZRP.ActiveContainers[closest_id]) then
                ZRP.ActiveContainers[closest_id].ZRP_SilentRemove = true
                ZRP.ActiveContainers[closest_id]:Remove()
                ZRP.ActiveContainers[closest_id] = nil
            end

            timer.Remove("ZRP_CReset_"   .. closest_id)
            timer.Remove("ZRP_CRespawn_" .. closest_id)

            table.remove(ZRP.Containers, closest_id)
            local newActive = {}
            for k, v in pairs(ZRP.ActiveContainers) do
                if k > closest_id then newActive[k - 1] = v
                elseif k ~= closest_id then newActive[k] = v end
            end
            ZRP.ActiveContainers = newActive
            ZRP.SaveContainers()
            if ZRP.SyncContainersToPlayer then ZRP.SyncContainersToPlayer(ply) end
            ply:ChatPrint("[ZRP] Container #" .. closest_id .. " removed.")
        else
            ply:ChatPrint("[ZRP] No ZRP container nearby; RMB a lootable map prop to adopt it.")
        end
    end

    return true
end

-- ── Allowed check ─────────────────────────────────────────────────────────────

function TOOL:Allowed()
    return IsValid(self:GetOwner()) and self:GetOwner():IsAdmin()
end

-- ── Deploy: announce the tool ────────────────────────────────────────────────

function TOOL:Deploy()
    if SERVER then
        local ply = self:GetOwner()
        if IsValid(ply) then
            ply:ChatPrint(
                "[ZRP LootEditor] LMB = place ZRP container  |  " ..
                "RMB on prop = adopt world container  |  " ..
                "RMB on ZRP container = remove it"
            )
        end
    end
end

-- ── HUD: draw existing containers in the world ────────────────────────────────

function TOOL:DrawHUD()
    if not CLIENT then return end
    local lply = LocalPlayer()
    if not lply:IsAdmin() then return end

    for _, ent in ipairs(ents.FindByClass("zrp_container")) do
        if not IsValid(ent) then continue end
        if EyePos():DistToSqr(ent:GetPos()) > (1500 * 1500) then continue end

        local pos    = ent:GetPos() + Vector(0, 0, ent:BoundingRadius() + 4)
        local data   = pos:ToScreen()
        if not data.visible then continue end

        local id     = ent.ZRP_ContainerID or "?"
        local looted = ent:GetLooted()
        local clr    = looted and Color(200, 80, 80) or Color(60, 200, 120)
        local label  = "ZRP #" .. tostring(id) .. (looted and "  [looted]" or "  [ready]")

        surface.SetFont("ChatFont")
        local tw, _ = surface.GetTextSize(label)
        surface.SetDrawColor(0, 0, 0, 140)
        surface.DrawRect(data.x - tw / 2 - 4, data.y - 10, tw + 8, 18)
        draw.SimpleText(label, "ChatFont", data.x, data.y, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- ── Tool panel ────────────────────────────────────────────────────────────────

function TOOL.BuildCPanel(CPanel)
    CPanel:AddControl("Header", {
        Description = "ZRP LootEditor\nLMB  — place container at crosshair\nRMB  — remove nearest container or adopt lootable map prop"
    })

    -- Model picker.
    CPanel:AddControl("Label", { Text = "Container Model:" })
    local combo = vgui.Create("DComboBox")
    combo:SetWide(260)
    combo:SetValue(CONTAINER_MODELS[1].label)
    for _, entry in ipairs(CONTAINER_MODELS) do
        combo:AddChoice(entry.label, entry.model)
    end
    combo.OnSelect = function(_, _, _, model)
        RunConsoleCommand("zrp_loot_editor_model", model)
    end
    CPanel:AddItem(combo)

    -- Respawn delay slider.
    CPanel:AddControl("Slider", {
        Label   = "Respawn / Reset Delay (seconds)",
        Command = "zrp_loot_editor_respawn_delay",
        Type    = "Integer",
        Min     = 60,
        Max     = 3600,
    })

    CPanel:AddControl("Label", { Text = " " })

    -- Open the full loot editor.
    local editBtn = vgui.Create("DButton")
    editBtn:SetText("Open Loot & Container Editor")
    editBtn:SetWide(260)
    editBtn.DoClick = function()
        RunConsoleCommand("zrp_open_editor_cl")
    end
    CPanel:AddItem(editBtn)
end
