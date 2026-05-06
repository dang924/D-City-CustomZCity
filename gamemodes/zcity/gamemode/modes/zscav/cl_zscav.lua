-- ZScav full-screen inventory UI.
-- Rebuilt to match mockup: left gear/health, middle personal storage,
-- right loot target panel, with full-screen blur and robust drag targets.

if not Nexus then
    if not _G.ZSCAV_PendingClientNexusBootstrap then
        _G.ZSCAV_PendingClientNexusBootstrap = true

        local function bootstrapWhenNexusLoads()
            if not Nexus then return end

            hook.Remove("InitPostEntity", "ZSCAV_BootstrapClientAfterNexus")
            timer.Remove("ZSCAV_BootstrapClientAfterNexus")
            _G.ZSCAV_PendingClientNexusBootstrap = nil
            include("cl_zscav.lua")
        end

        hook.Add("InitPostEntity", "ZSCAV_BootstrapClientAfterNexus", bootstrapWhenNexusLoads)
        timer.Create("ZSCAV_BootstrapClientAfterNexus", 1, 0, bootstrapWhenNexusLoads)
        print("[ZScav] Nexus library missing at client bootstrap - deferring main client load.")
    end

    return
end

ZSCAV = ZSCAV or {}

local PANEL_REF = nil
local CELL_BASE = 52  -- slightly larger slots for better readability/dragging

-- Multi-window container state. Each open bag gets its own entry.
-- CONT_WINDOWS[uid] = { chain, uid, class, gw, gh, contents, panel (DPanel ref or nil for root) }
local CONT_WINDOWS = {}
local ROOT_CONT_UID = nil  -- uid of the chain-root container embedded in the right panel
local SECONDARY_ROOT_CONT_UID = nil
local BAG_OPEN_PROGRESS = nil
local SURGERY_PROGRESS = nil
local MAX_CONT_WINDOWS = 6  -- max FLOATING windows (root in right panel is not counted)
local ATTACH_EQUIP_PICKER = nil
local WORLD_PICKUP_PROMPT = nil
local CORPSE_CONTAINER_CLASS = "Corpse"
local LIVE_LOOT_CONTAINER_CLASS = "LiveLoot"
local MAILBOX_CONTAINER_CLASS = "zscav_mailbox_container"
local STASH_CONTAINER_CLASS = "ent_zscav_player_stash"
local TRADER_TRADE_STATE = nil
local WORLD_PICKUP_PROMPT_RANGE_SQR = 120 * 120
local WORLD_PICKUP_PROMPT_CLOSE_YAW = 28
local WORLD_PICKUP_PROMPT_CLOSE_PITCH = 18
local WORLD_PICKUP_PROMPT_EQUIP_ENTER_YAW = 10
local WORLD_PICKUP_PROMPT_EQUIP_EXIT_YAW = 5
local ZSCAV_HOLD_BREATH_O2_RELEASE = 10
local UpdateTraderTradeUI = function() end
local IsTraderTradeActive = function() return false end

function ZSCAV.GetOpenContainerState(uid)
    uid = tostring(uid or "")
    if uid == "" then return nil end
    return CONT_WINDOWS[uid]
end

function ZSCAV.GetOpenContainerStates()
    return CONT_WINDOWS
end

local function CELL() return Nexus:Scale(CELL_BASE) end
local function PAD() return Nexus:Scale(5) end
local function R4() return Nexus:Scale(4) end
local function R8() return Nexus:Scale(8) end
local function R10() return Nexus:Scale(10) end
local function R12() return Nexus:Scale(12) end
local function R16() return Nexus:Scale(16) end

local function COL_SCRIM()      return Color(0, 0, 0, 90) end
local function COL_SHELL()      return Color(16, 18, 20, 175) end
local function COL_BLOCK()      return Color(22, 26, 30, 165) end
local function COL_PANEL()      return Color(28, 32, 37, 170) end
local function COL_SLOT()       return Color(44, 49, 56, 170) end
local function COL_SLOT_HOVER() return Color(60, 68, 80, 180) end
local function COL_SLOT_LOCK()  return Color(32, 35, 40, 140) end
local function COL_ITEM()       return Color(110, 92, 60, 210) end
local function COL_GEAR()       return Color(75, 84, 112, 210) end
local function COL_OK()         return Color(96, 196, 110, 110) end
local function COL_BAD()        return Color(220, 86, 86, 110) end
local function COL_TXT()        return Nexus.Colors.Text end
local function COL_DIM()        return Color(165, 170, 175, 200) end
local function COL_LINE()       return Color(8, 10, 12, 150) end

local function IsCtrlDown()
    return input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)
end

local function IsAltDown()
    return input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)
end

local function IsShiftDown()
    return input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)
end

local function GetEmbeddedRightPanelRootUIDByClass(className, excludeUID)
    className = tostring(className or "")
    excludeUID = tostring(excludeUID or "")
    if className == "" then return "" end

    local primaryUID = tostring(ROOT_CONT_UID or "")
    if primaryUID ~= "" and primaryUID ~= excludeUID then
        local primaryState = CONT_WINDOWS[primaryUID]
        if istable(primaryState) and tostring(primaryState.class or "") == className then
            return primaryUID
        end
    end

    local secondaryUID = tostring(SECONDARY_ROOT_CONT_UID or "")
    if secondaryUID ~= "" and secondaryUID ~= excludeUID then
        local secondaryState = CONT_WINDOWS[secondaryUID]
        if istable(secondaryState) and tostring(secondaryState.class or "") == className then
            return secondaryUID
        end
    end

    return ""
end

local function GetOpenPlayerStashRootUID(excludeUID)
    return GetEmbeddedRightPanelRootUIDByClass(STASH_CONTAINER_CLASS, excludeUID)
end

local function GetOpenOwnedSlotContainerUID(slotID, excludeUID)
    slotID = tostring(slotID or "")
    excludeUID = tostring(excludeUID or "")
    if slotID == "" then return "" end

    local ply = LocalPlayer()
    local inv = IsValid(ply) and ply:GetNetVar("ZScavInv", nil) or nil
    local entry = inv and inv.gear and inv.gear[slotID] or nil
    local uid = entry and tostring(entry.uid or "") or ""
    if uid == "" or uid == excludeUID then return "" end

    local state = CONT_WINDOWS[uid]
    if not istable(state) then return "" end
    if state.owned == true or (state.panel and IsValid(state.panel)) then
        return uid
    end

    return ""
end

local function GetInv()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end
    return ply:GetNetVar("ZScavInv", nil)
end

local function ZSCAV_GetMovementWeightCL()
    local inv = GetInv()
    if not inv then return 0 end

    if ZSCAV.GetTotalWeight then
        return tonumber(ZSCAV:GetTotalWeight(inv)) or 0
    end

    return tonumber(inv._totalWeight) or tonumber(inv._gridCarryWeight) or 0
end

local function ZSCAV_GetVisibleWeightCL()
    local inv = GetInv()
    if not inv then return 0 end

    if ZSCAV.GetTotalWeight then
        return tonumber(ZSCAV:GetTotalWeight(inv)) or 0
    end

    return tonumber(inv._totalWeight) or tonumber(inv._gridCarryWeight) or 0
end

local function ZSCAV_GetStaminaStateCL()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end

    local org = ply.organism
    local stamina = org and org.stamina or nil
    if not istable(stamina) then return nil end

    local maxValue = math.max(tonumber(stamina.max or stamina.range) or 180, 1)
    local curValue = math.Clamp(tonumber(stamina[1]) or maxValue, 0, maxValue)
    return curValue, maxValue
end

local function ZSCAV_GetLungStateCL()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end

    local org = ply.organism
    if not istable(org) then return nil end

    local maxValue = math.max(tonumber(org.zscav_lung_hold_max) or 0, 0)
    if maxValue <= 0 then return nil end

    local curValue = math.Clamp(tonumber(org.zscav_lung_hold_current) or maxValue, 0, maxValue)
    return curValue, maxValue, org.holdingbreath and true or false
end

local function ZSCAV_GetO2StateCL()
    local ply = LocalPlayer()
    if not IsValid(ply) then return nil end

    local org = ply.organism
    local o2 = org and org.o2 or nil
    if not istable(o2) then return nil end

    local maxValue = math.max(tonumber(o2.range) or 30, 1)
    local curValue = math.Clamp(tonumber(o2[1]) or maxValue, 0, maxValue)
    return curValue, maxValue
end

local function ZSCAV_GetBreathStateCL()
    local curLungs, maxLungs, holdingBreath = ZSCAV_GetLungStateCL()
    if not curLungs then return nil end

    local curO2, maxO2 = ZSCAV_GetO2StateCL()
    local curO2Time = 0
    local maxO2Time = 0

    if curO2 and curO2 > ZSCAV_HOLD_BREATH_O2_RELEASE then
        curO2Time = 30 * math.log(curO2 / ZSCAV_HOLD_BREATH_O2_RELEASE)
    end

    if maxO2 and maxO2 > ZSCAV_HOLD_BREATH_O2_RELEASE then
        maxO2Time = 30 * math.log(maxO2 / ZSCAV_HOLD_BREATH_O2_RELEASE)
    end

    local maxValue = math.max(maxLungs + maxO2Time, 0.01)
    local curValue = math.Clamp(curLungs + curO2Time, 0, maxValue)
    return curValue, maxValue, holdingBreath
end

local function ZSCAV_GetStaminaFracCL()
    local curValue, maxValue = ZSCAV_GetStaminaStateCL()
    if not curValue then return 1 end
    return math.Clamp(curValue / math.max(maxValue, 1), 0, 1)
end

local function ZScav_IsActiveCL()
    if ZSCAV and ZSCAV.IsActive then
        return ZSCAV:IsActive()
    end

    if not zb then return false end
    if zb.CROUND == "zscav" or zb.CROUND_MAIN == "zscav" then
        return true
    end

    if isfunction(CurrentRound) then
        local round = CurrentRound()
        return istable(round) and tostring(round.name or "") == "zscav"
    end

    return false
end

local function ZSCAV_CanManipulateInventoryCL()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end

    if ZSCAV.CanPlayerUseInventory then
        return ZSCAV:CanPlayerUseInventory(ply)
    end

    return ply:Alive()
end

local function ZSCAV_GetInventoryBindKeyCL()
    local binding = input.LookupBinding("zscav_inv", true)
        or input.LookupBinding("+zscav_inv", true)
        or input.LookupBinding("zscav_inv")
        or input.LookupBinding("+zscav_inv")
    binding = string.Trim(tostring(binding or ""))
    if binding == "" then return nil end
    return string.upper(binding)
end

local function ZSCAV_IsInventoryBoundCL()
    return ZSCAV_GetInventoryBindKeyCL() ~= nil
end

local function ZScav_CanOpenInventoryCL()
    if not ZSCAV_CanManipulateInventoryCL() then return false end
    if ZScav_IsActiveCL() then return true end

    local inv = GetInv()
    return istable(inv)
end

local function ZSCAV_IsSprintAttemptCL(cmd)
    if not (cmd and cmd.KeyDown and cmd.GetForwardMove) then return false end
    return cmd:KeyDown(IN_SPEED)
        and not cmd:KeyDown(IN_DUCK)
        and (cmd:KeyDown(IN_FORWARD) or (tonumber(cmd:GetForwardMove()) or 0) > 0)
end

local function ZSCAV_GetBlockedSprintMulCL(ply, walkMul)
    local runSpeed = math.max(tonumber(IsValid(ply) and ply:GetRunSpeed()) or 1, 1)
    local walkSpeed = math.max(tonumber(IsValid(ply) and ply:GetWalkSpeed()) or 1, 1)
    return math.max((walkSpeed * math.max(walkMul or 1, 0.01)) / runSpeed, 0.01)
end

local function ZSCAV_ResetWeightPredictionCL(ply)
    if not IsValid(ply) then return end

    ply.zscav_disable_stamina_move_debuff = false
    ply.zscav_weight_walk_mul = 1
    ply.zscav_weight_sprint_mul = 1
    ply.zscav_weight_speed_gain_mul = 1
    ply.zscav_weight_inertia_mul = 1
    ply.zscav_weight_block_sprint = false
    ply.zscav_weight_stamina_sprint_blocked = false
end

local function ZSCAV_ApplyWeightPredictionCL(ply)
    if not IsValid(ply) then return nil end

    local inv = ply:GetNetVar("ZScavInv", nil)
    if not inv then
        ZSCAV_ResetWeightPredictionCL(ply)
        return nil
    end

    local movementWeightKg = ZSCAV_GetMovementWeightCL()
    local profile = ZSCAV.GetWeightMovementProfile and ZSCAV:GetWeightMovementProfile(movementWeightKg) or nil
    if not istable(profile) then
        ZSCAV_ResetWeightPredictionCL(ply)
        return nil
    end

    ply.zscav_disable_stamina_move_debuff = true
    ply.zscav_weight_walk_mul = tonumber(profile.walkMul) or 1
    ply.zscav_weight_sprint_mul = tonumber(profile.sprintMul) or 1
    ply.zscav_weight_speed_gain_mul = tonumber(profile.speedGainMul) or 1
    ply.zscav_weight_inertia_mul = tonumber(profile.inertiaMul) or 1
    ply.zscav_weight_block_sprint = profile.blockSprint and true or false
    return profile
end

local function ZSCAV_GetSprintStaminaMulCL(ply, walkMul, sprintMul)
    local softStart = math.Clamp(tonumber(ZSCAV.WeightSprintStaminaSoftStartFrac) or 0.20, 0.05, 0.95)
    local hardBlock = math.Clamp(tonumber(ZSCAV.WeightSprintStaminaHardBlockFrac) or 0.07, 0.01, softStart - 0.01)
    local recover = math.Clamp(tonumber(ZSCAV.WeightSprintStaminaRecoverFrac) or 0.18, hardBlock + 0.01, 0.95)
    local staminaFrac = ZSCAV_GetStaminaFracCL()
    local blockedMul = ZSCAV_GetBlockedSprintMulCL(ply, walkMul)
    local blocked = ply.zscav_weight_stamina_sprint_blocked and true or false

    if blocked then
        if staminaFrac >= recover then
            blocked = false
        end
    elseif staminaFrac <= hardBlock then
        blocked = true
    end

    ply.zscav_weight_stamina_sprint_blocked = blocked

    if blocked then
        return blockedMul, true
    end

    local baseSprintMul = math.max(tonumber(sprintMul) or walkMul or 1, 0.01)
    if staminaFrac >= softStart then
        return baseSprintMul, false
    end

    local t = math.Clamp((staminaFrac - hardBlock) / (softStart - hardBlock), 0, 1)
    return Lerp(t, blockedMul, baseSprintMul), false
end

hook.Add("HG_MovementCalc", "ZSCAV_WeightAccelerationClient", function(_vel, _velLen, _weightmul, ply, _cmd, _mv)
    if ply ~= LocalPlayer() then return end

    if not (ZScav_IsActiveCL() and IsValid(ply) and ply:Alive()) then
        ZSCAV_ResetWeightPredictionCL(ply)
        return
    end

    local profile = ZSCAV_ApplyWeightPredictionCL(ply)
    if not profile then return end

    local walkMul = math.max(tonumber(ply.zscav_weight_walk_mul) or 1, 0.01)
    if walkMul >= 1.0 then return end

    local speedGainMul = math.max(tonumber(ply.zscav_weight_speed_gain_mul) or walkMul, 0.05)
    local inertiaMul = math.max(tonumber(ply.zscav_weight_inertia_mul) or walkMul, 0.05)

    ply.SpeedGainMul = math.max((tonumber(ply.SpeedGainMul) or 240) * speedGainMul, 1)
    ply.InertiaBlend = math.max((tonumber(ply.InertiaBlend) or 2000) * inertiaMul, 1)
end)

hook.Add("HG_MovementCalc_2", "ZSCAV_WeightMobilityClient", function(mul, ply, cmd, _mv)
    if ply ~= LocalPlayer() then return end
    if not istable(mul) then return end

    if not (ZScav_IsActiveCL() and IsValid(ply) and ply:Alive()) then
        ZSCAV_ResetWeightPredictionCL(ply)
        return
    end

    local profile = ZSCAV_ApplyWeightPredictionCL(ply)
    if not profile then return end

    local walkMul = math.max(tonumber(ply.zscav_weight_walk_mul) or 1, 0.01)
    local effectiveMul = walkMul
    local sprintAttempt = ZSCAV_IsSprintAttemptCL(cmd)

    if sprintAttempt then
        if ply.zscav_weight_block_sprint then
            effectiveMul = ZSCAV_GetBlockedSprintMulCL(ply, walkMul)
        else
            local staminaMul = nil
            staminaMul, _ = ZSCAV_GetSprintStaminaMulCL(
                ply,
                walkMul,
                tonumber(ply.zscav_weight_sprint_mul) or walkMul
            )
            effectiveMul = math.max(staminaMul or walkMul, 0.01)
        end
    else
        ply.zscav_weight_stamina_sprint_blocked = false
    end

    mul[1] = math.max((tonumber(mul[1]) or 1.0) * effectiveMul, 0.01)
end)

local function PrettyName(class)
    local c = tostring(class or "")
    local w = weapons.Get(c)
    if w and w.PrintName and w.PrintName ~= "" then return w.PrintName end
    local g = ZSCAV:GetGearDef(c)
    if g and g.name then return g.name end
    local m = ZSCAV.GetItemMeta and ZSCAV:GetItemMeta(c) or nil
    if m and m.name then return m.name end
    return c
end

local VENDOR_TICKET_CLASS = "zscav_vendor_ticket"

local function GetVendorTicketData(entry)
    if not (istable(entry) and tostring(entry.class or "") == VENDOR_TICKET_CLASS and istable(entry.ticket_data)) then
        return nil
    end

    return entry.ticket_data
end

local function GetEntryDisplayName(entry)
    if not (istable(entry) and entry.class) then
        return PrettyName(entry)
    end

    local ticket = GetVendorTicketData(entry)
    local number = math.max(0, math.floor(tonumber(ticket and ticket.number) or 0))
    if number > 0 then
        return string.format("%s #%d", PrettyName(entry.class), number)
    end

    return PrettyName(entry.class)
end

local function SummarizeVendorTicketEntries(entries, emptyText)
    local parts = {}

    for index, item in ipairs(entries or {}) do
        local class = tostring(item.class or "")
        if class ~= "" then
            local count = math.max(1, math.floor(tonumber(item.count) or 1))
            parts[#parts + 1] = string.format("%dx %s", count, PrettyName(class))
            if index >= 4 then
                break
            end
        end
    end

    if #parts <= 0 then
        return tostring(emptyText or "None")
    end

    local remainder = math.max(0, #(entries or {}) - #parts)
    local out = table.concat(parts, ", ")
    if remainder > 0 then
        out = out .. string.format(", +%d more", remainder)
    end

    return out
end

local function FormatVendorTicketCooldown(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if seconds <= 0 then return "None" end
    if string.NiceTime then
        return string.NiceTime(seconds)
    end
    return tostring(seconds) .. "s"
end

local function FormatVendorTicketIssuedAt(timestamp)
    timestamp = math.floor(tonumber(timestamp) or 0)
    if timestamp <= 0 then return "Unknown" end
    return os.date("%Y-%m-%d %H:%M", timestamp)
end

local function DrawVendorTicketBadgeCL(entry, x, y, w, h)
    local ticket = GetVendorTicketData(entry)
    local number = math.max(0, math.floor(tonumber(ticket and ticket.number) or 0))
    if number <= 0 then return end

    draw.SimpleText("#" .. number, Nexus:GetFont(w >= Nexus:Scale(92) and 12 or 10, nil, true), x + w - Nexus:Scale(6), y + Nexus:Scale(6), Color(236, 214, 123), TEXT_ALIGN_RIGHT)
end

local function StyleVendorTicketScroll(scroll)
    local bar = IsValid(scroll) and scroll.GetVBar and scroll:GetVBar() or nil
    if not IsValid(bar) or bar._zsVendorTicketStyled then return end

    bar._zsVendorTicketStyled = true
    bar:SetWide(Nexus:Scale(8))
    bar.Paint = function(_, w, h)
        draw.RoundedBox(R8(), 0, 0, w, h, Color(10, 12, 15, 180))
    end

    if IsValid(bar.btnUp) then
        bar.btnUp.Paint = function() end
    end

    if IsValid(bar.btnDown) then
        bar.btnDown.Paint = function() end
    end

    if IsValid(bar.btnGrip) then
        bar.btnGrip.Paint = function(_, w, h)
            draw.RoundedBox(R8(), 0, 0, w, h, Color(112, 118, 126, 220))
        end
    end
end

local function AddVendorTicketCard(parent, title, body, accent)
    local card = parent:Add("DPanel")
    card:Dock(TOP)
    card:DockMargin(0, 0, 0, Nexus:Scale(8))

    local titleLabel = card:Add("DLabel")
    titleLabel:Dock(TOP)
    titleLabel:DockMargin(Nexus:Scale(12), Nexus:Scale(10), Nexus:Scale(12), Nexus:Scale(4))
    titleLabel:SetFont(Nexus:GetFont(14, nil, true))
    titleLabel:SetTextColor(COL_TXT())
    titleLabel:SetText(tostring(title or ""))

    local bodyLabel = card:Add("DLabel")
    bodyLabel:Dock(TOP)
    bodyLabel:DockMargin(Nexus:Scale(12), 0, Nexus:Scale(12), Nexus:Scale(12))
    bodyLabel:SetFont(Nexus:GetFont(12))
    bodyLabel:SetTextColor(COL_DIM())
    bodyLabel:SetWrap(true)
    bodyLabel:SetAutoStretchVertical(true)
    bodyLabel:SetText(tostring(body or ""))

    card.PerformLayout = function(self, w)
        local bodyWide = math.max(0, w - Nexus:Scale(24))
        bodyLabel:SetWide(bodyWide)
        bodyLabel:SizeToContentsY()
        self:SetTall(bodyLabel:GetTall() + Nexus:Scale(44))
    end

    card.Paint = function(_, w, h)
        draw.RoundedBox(R10(), 0, 0, w, h, accent or Color(40, 44, 50, 220))
        surface.SetDrawColor(Color(10, 12, 14, 180))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    return card
end

local function OpenVendorTicketMenu(entry)
    local ticket = GetVendorTicketData(entry)
    if not ticket then return end

    local presets = istable(ticket.presets) and ticket.presets or {}
    local availableVendors = istable(ticket.available_vendors) and ticket.available_vendors or {}
    local number = math.max(0, math.floor(tonumber(ticket.number) or 0))
    local frame = vgui.Create("DFrame")
    frame:SetSize(math.min(760, math.floor(ScrW() * 0.9)), math.min(620, math.floor(ScrH() * 0.86)))
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:SetDeleteOnClose(true)
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        draw.RoundedBox(R12(), 0, 0, w, h, Color(18, 21, 24, 245))
        draw.RoundedBox(R12(), 0, 0, w, Nexus:Scale(42), Color(28, 32, 37, 245))
        draw.SimpleText(GetEntryDisplayName(entry), Nexus:GetFont(17, nil, true), Nexus:Scale(14), Nexus:Scale(12), COL_TXT())
        draw.SimpleText(string.format("Ticket #%s", number > 0 and tostring(number) or "?"), Nexus:GetFont(13), Nexus:Scale(14), Nexus:Scale(28), COL_DIM())
    end

    frame.btnClose:SetText("")
    frame.btnClose.Paint = function(self, w, h)
        draw.SimpleText("x", Nexus:GetFont(18, nil, true), w * 0.5, h * 0.5, self:IsHovered() and Color(255, 235, 235) or Color(214, 210, 198), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local scroll = frame:Add("DScrollPanel")
    scroll:SetPos(Nexus:Scale(10), Nexus:Scale(50))
    scroll:SetSize(frame:GetWide() - Nexus:Scale(20), frame:GetTall() - Nexus:Scale(60))
    StyleVendorTicketScroll(scroll)

    local summaryLines = {
        string.format("Ticket #%s", number > 0 and tostring(number) or "?"),
        "Vendor: " .. tostring(ticket.vendor_name or "Vendor"),
        "Issued: " .. FormatVendorTicketIssuedAt(ticket.issued_at),
    }

    if ticket.shopping_list_only == true then
        local names = {}
        for _, row in ipairs(availableVendors) do
            names[#names + 1] = tostring((istable(row) and row.name) or row or "Vendor")
        end

        summaryLines[#summaryLines + 1] = tostring(ticket.zone_name or "") ~= "" and ("This is a shopping list for the active vendors in " .. tostring(ticket.zone_name) .. ".") or "This is a shopping list for active player vendors."
        if #names > 0 then
            summaryLines[#summaryLines + 1] = "Show it to: " .. table.concat(names, ", ")
        end
    elseif #presets > 0 then
        summaryLines[#summaryLines + 1] = "Snapshot of listed preset sales:"
    else
        summaryLines[#summaryLines + 1] = "No preset sales were listed on this ticket."
    end

    AddVendorTicketCard(scroll, "Ticket Summary", table.concat(summaryLines, "\n"), Color(48, 52, 58, 225))

    if ticket.shopping_list_only == true and #availableVendors > 0 then
        for _, row in ipairs(availableVendors) do
            local vendorName = tostring((istable(row) and row.name) or row or "Vendor")
            local vendorLine = tostring(ticket.zone_name or "") ~= "" and (vendorName .. " is serving in " .. tostring(ticket.zone_name) .. ".") or (vendorName .. " is currently available for this queue.")
            AddVendorTicketCard(scroll, vendorName, vendorLine, Color(72, 66, 46, 225))
        end
    end

    for _, preset in ipairs(presets) do
        AddVendorTicketCard(
            scroll,
            tostring(preset.name or "Unnamed Preset"),
            string.format(
                "Pays: %s\nGives: %s\nCooldown: %s",
                SummarizeVendorTicketEntries(preset.player_items, "Nothing"),
                SummarizeVendorTicketEntries(preset.trader_items, "Nothing"),
                FormatVendorTicketCooldown(preset.cooldown_seconds)
            ),
            Color(40, 44, 50, 220)
        )
    end
end

local function ConfirmVendorTicketDiscard(entry, onConfirm)
    Derma_Query(
        string.format("Discard %s? It will be deleted instead of dropped to the floor.", GetEntryDisplayName(entry)),
        "Discard Vendor Ticket",
        "OK",
        function()
            if isfunction(onConfirm) then
                onConfirm()
            end
        end,
        "Cancel"
    )
end

local SendAction
local SendContainerAction

local HOTBAR_BIND_TO_SLOT = {
    slot1 = 1,
    slot2 = 2,
    slot3 = 3,
    slot4 = 4,
    slot5 = 5,
    slot6 = 6,
    slot7 = 7,
    slot8 = 8,
    slot9 = 9,
    slot10 = 10,
}

local HOTBAR_PHYSICAL_KEY_TO_SLOT = {
    [KEY_1] = 1,
    [KEY_2] = 2,
    [KEY_3] = 3,
    [KEY_4] = 4,
    [KEY_5] = 5,
    [KEY_6] = 6,
    [KEY_7] = 7,
    [KEY_8] = 8,
    [KEY_9] = 9,
    [KEY_0] = 10,
}

local HOTBAR_ROLE_LABELS = {
    [1] = "BACK",
    [2] = "SLING",
    [3] = "SIDEARMS",
}

local ZSCAV_ResolveQuickslotBoundEntryCL

local function ZSCAV_GetQuickslotIndexForHotbarSlotCL(slotNumber)
    slotNumber = math.floor(tonumber(slotNumber) or 0)
    local base = math.floor(tonumber(ZSCAV.CustomHotbarBase) or 4)
    local count = math.max(math.floor(tonumber(ZSCAV.CustomHotbarCount) or 7), 1)
    local index = slotNumber - base + 1
    if index < 1 or index > count then return nil end
    return index
end

local function ZSCAV_GetHotbarSlotNumberForQuickslotIndexCL(index)
    index = math.floor(tonumber(index) or 0)
    if index <= 0 then return nil end
    return math.floor(tonumber(ZSCAV.CustomHotbarBase) or 4) + index - 1
end

local function ZSCAV_GetQuickslotRefCL(index)
    local inv = GetInv()
    if not inv then return nil end

    local quickslots = inv.quickslots
    local entry = istable(quickslots) and quickslots[index] or nil
    if not (istable(entry) and entry.class) then return nil end
    return entry
end

local function ZSCAV_GetQuickslotEntryCL(index)
    local ref = ZSCAV_GetQuickslotRefCL(index)
    if not ref then return nil end

    if ZSCAV_ResolveQuickslotBoundEntryCL then
        return ZSCAV_ResolveQuickslotBoundEntryCL(ref) or ref
    end

    return ref
end

local function ZSCAV_GetHotbarEntryCL(slotNumber)
    local inv = GetInv()
    if not inv then return nil end

    inv.weapons = inv.weapons or {}
    if slotNumber == 1 then return inv.weapons.primary end
    if slotNumber == 2 then return inv.weapons.secondary end
    if slotNumber == 3 then return inv.weapons.sidearm or inv.weapons.sidearm2 end

    local quickslotIndex = ZSCAV_GetQuickslotIndexForHotbarSlotCL(slotNumber)
    if not quickslotIndex then return nil end
    return ZSCAV_GetQuickslotEntryCL(quickslotIndex)
end

local function ZSCAV_CollectHotbarTokensCL(source)
    local out = {}
    local seen = {}

    local function push(class)
        class = tostring(class or ""):lower()
        if class == "" or seen[class] then return end
        seen[class] = true
        out[#out + 1] = class
    end

    if istable(source) then
        push(source.class)
        push(source.actual_class)

        if ZSCAV.GetCanonicalItemClass then
            push(ZSCAV:GetCanonicalItemClass(source))
            push(ZSCAV:GetCanonicalItemClass(source.class))
            push(ZSCAV:GetCanonicalItemClass(source.actual_class))
        end
    else
        push(source)

        if ZSCAV.GetCanonicalItemClass then
            push(ZSCAV:GetCanonicalItemClass(source))
        end
    end

    return out
end

local function ZSCAV_ResolveGrenadeInventoryClassCL(entry)
    if ZSCAV.ResolveGrenadeInventoryClass then
        return ZSCAV:ResolveGrenadeInventoryClass(entry)
    end

    if not istable(entry) then return nil end

    local candidates = {}
    local seen = {}

    local function push(class)
        class = tostring(class or "")
        if class == "" then return end

        local lowerClass = string.lower(class)
        if seen[lowerClass] then return end
        seen[lowerClass] = true
        candidates[#candidates + 1] = class
    end

    push(entry.class)
    push(entry.actual_class)

    if ZSCAV.GetCanonicalItemClass then
        push(ZSCAV:GetCanonicalItemClass(entry))
        push(ZSCAV:GetCanonicalItemClass(entry.class))
        push(ZSCAV:GetCanonicalItemClass(entry.actual_class))
    end

    if ZSCAV.GetWeaponBaseClass then
        push(ZSCAV:GetWeaponBaseClass(entry.class))
        push(ZSCAV:GetWeaponBaseClass(entry.actual_class))
    end

    for _, class in ipairs(candidates) do
        if ZSCAV.GetEquipWeaponSlot and ZSCAV:GetEquipWeaponSlot(class) == "grenade" and weapons.GetStored(class) then
            return class
        end

        local lookupClass = string.lower(tostring(class or ""))
        if lookupClass ~= "" and scripted_ents.GetStored(lookupClass) then
            for candidateClass in pairs(ZSCAV.ItemSizes or {}) do
                candidateClass = tostring(candidateClass or "")
                if candidateClass ~= "" and ZSCAV.GetEquipWeaponSlot and ZSCAV:GetEquipWeaponSlot(candidateClass) == "grenade" then
                    local stored = weapons.GetStored(candidateClass)
                    if string.lower(tostring(stored and stored.ENT or "")) == lookupClass then
                        return candidateClass
                    end
                end
            end
        end
    end

    return nil
end

local function ZSCAV_QuickslotEntryMatchesCL(ref, entry)
    if not (istable(ref) and istable(entry) and entry.class) then return false end

    local refUID = tostring(ref.uid or "")
    if refUID ~= "" and tostring(entry.uid or "") == refUID then
        return true
    end

    local refWeaponUID = tostring(ref.weapon_uid or "")
    if refWeaponUID ~= "" and tostring(entry.weapon_uid or "") == refWeaponUID then
        return true
    end

    local wanted = {}
    for _, token in ipairs(ZSCAV_CollectHotbarTokensCL(ref)) do
        wanted[token] = true
    end

    if next(wanted) == nil then return false end

    for _, token in ipairs(ZSCAV_CollectHotbarTokensCL(entry)) do
        if wanted[token] then
            return true
        end
    end

    return false
end

local function ZSCAV_BuildQuickslotDisplayEntryCL(ref, entry)
    if not (istable(ref) and ref.class) then return nil end
    if not (istable(entry) and entry.class) then return ref end

    local out = table.Copy(entry) or {}

    local preferredGrid = tostring(ref.preferred_grid or "")
    if preferredGrid ~= "" then
        out.preferred_grid = preferredGrid
    end

    local preferredSlot = tostring(ref.preferred_slot or "")
    if preferredSlot ~= "" then
        out.preferred_slot = preferredSlot
    end

    local kind = tostring(ref.kind or "")
    if kind ~= "" then
        out.kind = kind
    end

    return out
end

ZSCAV_ResolveQuickslotBoundEntryCL = function(ref)
    local inv = GetInv()
    if not (istable(inv) and istable(ref) and ref.class) then return nil end

    inv.weapons = inv.weapons or {}

    local preferredSlot = tostring(ref.preferred_slot or "")
    if preferredSlot ~= "" then
        local entry = inv.weapons[preferredSlot]
        if entry and ZSCAV_QuickslotEntryMatchesCL(ref, entry) then
            return ZSCAV_BuildQuickslotDisplayEntryCL(ref, entry)
        end
    end

    for _, entry in pairs(inv.weapons) do
        if entry and ZSCAV_QuickslotEntryMatchesCL(ref, entry) then
            return ZSCAV_BuildQuickslotDisplayEntryCL(ref, entry)
        end
    end

    local hasStableIdentity = tostring(ref.uid or "") ~= "" or tostring(ref.weapon_uid or "") ~= ""
    local preferredGrid = tostring(ref.preferred_grid or "")

    local function scanGrid(gridName)
        local list = inv[gridName]
        if not istable(list) then return nil end

        for _, entry in ipairs(list) do
            if entry and ZSCAV_QuickslotEntryMatchesCL(ref, entry) then
                return ZSCAV_BuildQuickslotDisplayEntryCL(ref, entry)
            end
        end

        return nil
    end

    if hasStableIdentity and preferredGrid ~= "" then
        local found = scanGrid(preferredGrid)
        if found then return found end
    end

    for _, gridName in ipairs({ "pocket", "vest", "backpack", "secure" }) do
        if not (hasStableIdentity and gridName == preferredGrid) then
            local found = scanGrid(gridName)
            if found then return found end
        end
    end

    return ref
end

local function ZSCAV_HotbarEntryMatchesWeaponCL(entry, weapon)
    if not (istable(entry) and entry.class and IsValid(weapon)) then return false end

    local entryWeaponUID = tostring(entry.weapon_uid or "")
    local activeWeaponUID = tostring(weapon.zscav_weapon_uid or "")
    if entryWeaponUID ~= "" and entryWeaponUID == activeWeaponUID then
        return true
    end

    local entryActualClass = tostring(entry.actual_class or "")
    local activeClass = tostring(weapon:GetClass() or "")
    if entryActualClass ~= "" and entryActualClass == activeClass then
        return true
    end

    local wanted = {}
    for _, token in ipairs(ZSCAV_CollectHotbarTokensCL(entry)) do
        wanted[token] = true
    end

    if next(wanted) == nil then return false end

    for _, token in ipairs(ZSCAV_CollectHotbarTokensCL(weapon:GetClass())) do
        if wanted[token] then
            return true
        end
    end

    return false
end

local function ZSCAV_IsHotbarSlotSelectedCL(slotNumber)
    local ply = LocalPlayer()
    local activeWeapon = IsValid(ply) and ply:GetActiveWeapon() or NULL
    if not IsValid(activeWeapon) then return false end

    local inv = GetInv()
    if not inv then return false end

    inv.weapons = inv.weapons or {}
    if slotNumber == 3 then
        return ZSCAV_HotbarEntryMatchesWeaponCL(inv.weapons.sidearm, activeWeapon)
            or ZSCAV_HotbarEntryMatchesWeaponCL(inv.weapons.sidearm2, activeWeapon)
    end

    return ZSCAV_HotbarEntryMatchesWeaponCL(ZSCAV_GetHotbarEntryCL(slotNumber), activeWeapon)
end

local function ZSCAV_GetHotbarBindSlotCL(bind)
    local normalized = string.Trim(string.lower(tostring(bind or "")))
    return HOTBAR_BIND_TO_SLOT[normalized]
end

local zscavHotbarLastTriggerSlot = 0
local zscavHotbarLastTriggerAt = 0

local function ZSCAV_CanTriggerHotbarKeyboardCL()
    local ply = LocalPlayer()
    if not (ZScav_IsActiveCL() and IsValid(ply) and ZSCAV_CanManipulateInventoryCL()) then return false end
    if gui.IsGameUIVisible() then return false end
    if IsValid(vgui.GetKeyboardFocus()) then return false end
    return true
end

local function ZSCAV_TriggerHotbarSlotCL(slotNumber)
    slotNumber = math.floor(tonumber(slotNumber) or 0)
    if slotNumber <= 0 then return false end
    if not ZSCAV_CanTriggerHotbarKeyboardCL() then return false end

    local now = RealTime()
    if zscavHotbarLastTriggerSlot == slotNumber and (now - zscavHotbarLastTriggerAt) <= 0.08 then
        return true
    end

    zscavHotbarLastTriggerSlot = slotNumber
    zscavHotbarLastTriggerAt = now
    SendAction("activate_hotbar_slot", { slot = slotNumber })
    return true
end

local function ZSCAV_GetHotbarRoleLabelCL(slotNumber, entry)
    local fixedLabel = HOTBAR_ROLE_LABELS[slotNumber]
    if fixedLabel then return fixedLabel end

    local kind = entry and tostring(ZSCAV:GetEquipWeaponSlot(entry.class) or "") or ""
    if kind == "grenade" then return "GRENADE" end
    if kind == "medical" then return "MEDICAL" end
    if kind == "sidearm" then return "SIDEARM" end
    if kind == "scabbard" then return "SCABBARD" end
    return "QUICK"
end

local function ZSCAV_SplitHotbarTextCL(text, maxChars)
    text = string.Trim(tostring(text or ""))
    maxChars = math.max(math.floor(tonumber(maxChars) or 12), 4)
    if text == "" then return "", "" end
    if #text <= maxChars then return text, "" end

    local first = text:sub(1, maxChars)
    local lastSpace = first:match("^.*() ")
    if lastSpace and lastSpace > math.floor(maxChars * 0.45) then
        return string.Trim(first:sub(1, lastSpace - 1)), string.Trim(text:sub(lastSpace + 1, lastSpace + maxChars))
    end

    return first, string.Trim(text:sub(maxChars + 1, maxChars * 2))
end

local function ZSCAV_GetMedicalCounterValueCL(entry)
    if not (istable(entry) and entry.class and ZSCAV.GetMedicalEFTData) then return nil end

    local row = ZSCAV:GetMedicalEFTData(entry.class)
    if not istable(row) then return nil end

    if row.pool_hp ~= nil then
        local maxValue = math.max(0, math.floor(tonumber(row.pool_hp) or 0))
        local remaining = tonumber(entry.med_hp)
        if remaining == nil then remaining = maxValue end
        return math.Clamp(math.floor(remaining + 0.5), 0, maxValue)
    end

    if row.uses ~= nil then
        local maxValue = math.max(0, math.floor(tonumber(row.uses) or 0))
        local remaining = tonumber(entry.med_uses)
        if remaining == nil then remaining = maxValue end
        return math.Clamp(math.floor(remaining + 0.5), 0, maxValue)
    end

    if row.single_use then
        return 1
    end

    return nil
end

local function ZSCAV_DrawMedicalCounterBadgeCL(entry, x, y, w, h, opts)
    local remaining = ZSCAV_GetMedicalCounterValueCL(entry)
    if remaining == nil then return end

    opts = opts or {}

    local font = opts.font or Nexus:GetFont(11, nil, true)
    local marginX = opts.marginX or Nexus:Scale(6)
    local marginY = opts.marginY or Nexus:Scale(4)
    local alignBottom = opts.alignBottom == true
    local text = tostring(remaining)

    surface.SetFont(font)
    local tw, th = surface.GetTextSize(text)
    local badgeW = math.max(Nexus:Scale(18), tw + Nexus:Scale(8))
    local badgeH = math.max(Nexus:Scale(14), th + Nexus:Scale(4))
    local bx = x + w - badgeW - marginX
    local by = alignBottom and (y + h - badgeH - marginY) or (y + marginY)

    draw.RoundedBox(R4(), bx, by, badgeW, badgeH, Color(17, 20, 24, 220))
    surface.SetDrawColor(205, 214, 222, 100)
    surface.DrawOutlinedRect(bx, by, badgeW, badgeH, 1)
    draw.SimpleText(text, font, bx + badgeW * 0.5, by + badgeH * 0.5, Color(238, 242, 246, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local ATTACHMENT_GRID_LABELS = {
    backpack = "Backpack",
    pocket = "Pockets",
    secure = "Secure Container",
    vest = "Tactical Rig",
}

local ATTACHMENT_SLOT_LABELS = {
    primary = "Primary Slot",
    secondary = "Primary Slot 2",
    sidearm = "Sidearm Slot",
    sidearm2 = "Sidearm Slot 2",
    melee = "Scabbard Slot",
    scabbard = "Scabbard Slot",
}

local function CanEquipWeaponClass(class)
    local slot = ZSCAV:GetEquipWeaponSlot(class)
    local candidates = ZSCAV.GetCompatibleWeaponSlots and ZSCAV:GetCompatibleWeaponSlots(slot) or nil
    return istable(candidates) and #candidates > 0
end

local function OpenInspect(ref, entry)
    if ZSCAV.OpenWeaponInspect and (entry.weapon_uid or entry.weapon_state or CanEquipWeaponClass(entry.class)) then
        ZSCAV.OpenWeaponInspect(ref)
        return
    end

    SendAction("inspect", ref)
end

local function CollectInstalledAttachmentNames(entry)
    if not (istable(entry) and entry.class and ZSCAV.GetWeaponAttachmentSlots and ZSCAV.NormalizeWeaponAttachments) then
        return nil
    end

    local normalized = ZSCAV:NormalizeWeaponAttachments(entry.class, entry.weapon_state and entry.weapon_state.attachments or nil)
    local names = {}

    for _, placement in ipairs(ZSCAV:GetWeaponAttachmentSlots()) do
        local attKey = ZSCAV:NormalizeAttachmentKey(normalized and normalized[placement])
        if attKey ~= "" then
            names[#names + 1] = ZSCAV:GetAttachmentName(attKey)
        end
    end

    return (#names > 0) and names or nil
end

local function TrimOverlayText(text, maxChars)
    text = tostring(text or "")
    maxChars = math.max(4, math.floor(tonumber(maxChars) or 0))
    if #text <= maxChars then return text end
    return string.sub(text, 1, math.max(1, maxChars - 3)) .. "..."
end

local function BuildAttachmentOverlayLines(entry, maxLines, maxChars)
    local names = CollectInstalledAttachmentNames(entry)
    if not names then return nil end

    maxLines = math.max(1, math.floor(tonumber(maxLines) or 0))
    maxChars = math.max(8, math.floor(tonumber(maxChars) or 0))

    local lines = { "ATT x" .. tostring(#names) }
    if maxLines == 1 then return lines end

    local nameLineBudget = maxLines - 1
    if #names > nameLineBudget then
        nameLineBudget = math.max(0, nameLineBudget - 1)
    end

    for index = 1, math.min(#names, nameLineBudget) do
        lines[#lines + 1] = TrimOverlayText(names[index], maxChars)
    end

    local hiddenCount = #names - nameLineBudget
    if hiddenCount > 0 then
        local suffix = (nameLineBudget == 0) and " attached" or " more"
        lines[#lines + 1] = "+" .. tostring(hiddenCount) .. suffix
    end

    return lines
end

local function DrawWeaponAttachmentOverlay(entry, x, y, w, h)
    local boxX = x + Nexus:Scale(5)
    local boxY = y + Nexus:Scale(22)
    local boxW = math.max(0, w - Nexus:Scale(10))
    local availableH = h - Nexus:Scale(28)
    if boxW <= 0 or availableH <= Nexus:Scale(16) then return end

    local lineH = Nexus:Scale(11)
    local boxPadding = Nexus:Scale(6)
    local maxLines = math.min(4, math.floor((availableH - boxPadding) / lineH))
    if maxLines <= 0 then return end

    local maxChars = math.max(8, math.floor(boxW / Nexus:Scale(5.4)))
    local lines = BuildAttachmentOverlayLines(entry, maxLines, maxChars)
    if not lines then return end

    local boxH = (#lines * lineH) + boxPadding
    draw.RoundedBox(R8(), boxX, boxY, boxW, boxH, Color(16, 18, 22, 205))

    for lineIndex, lineText in ipairs(lines) do
        draw.SimpleText(lineText, Nexus:GetFont(11),
            boxX + Nexus:Scale(4), boxY + Nexus:Scale(3) + ((lineIndex - 1) * lineH),
            Color(222, 226, 230))
    end
end

SendAction = function(action, args)
    if not ZSCAV_CanManipulateInventoryCL() then return false end
    net.Start("ZScavInvAction")
        net.WriteString(action)
        net.WriteTable(args or {})
    net.SendToServer()
    return true
end

SendContainerAction = function(action, args)
    local isCloseAction = action == "close_all" or action == "close_window"
    if not isCloseAction and not ZSCAV_CanManipulateInventoryCL() then return false end
    local payload = util.TableToJSON(args or {}) or "{}"
    net.Start("ZScavContainerAction")
        net.WriteString(action)
        net.WriteUInt(#payload, 16)
        net.WriteData(payload, #payload)
    net.SendToServer()
    return true
end

local function SendTraderTradeAction(action, args)
    net.Start("ZScavTraderTradeAction")
        net.WriteString(tostring(action or ""))
        net.WriteTable(args or {})
    net.SendToServer()
    return true
end

local function FindRoot(p)
    while IsValid(p) and not p.zsDragRoot do
        p = p:GetParent()
    end
    return IsValid(p) and p or nil
end

local function StartDrag(srcPanel, gridName, index, entry, fromContainer, fromContainerUID, extra)
    local root = FindRoot(srcPanel)
    if not root then return end
    extra = extra or {}
    root.zsDrag = {
        fromGrid = gridName,
        fromIndex = index,
        entry = entry,
        fromContainer = fromContainer == true,
        fromContainerUID = fromContainerUID or "",
        fromSlot = extra.fromSlot == true,
        slotKind = extra.slotKind,
        slotID = extra.slotID,
        grabOffX = tonumber(extra.grabOffX) or nil,
        grabOffY = tonumber(extra.grabOffY) or nil,
    }
    root:MouseCapture(true)
end

local function EndDrag(root)
    if not IsValid(root) then return end
    root.zsDrag = nil
    root:MouseCapture(false)
end

local function ResolveDropTarget(root)
    local hovered = vgui.GetHoveredPanel()
    while IsValid(hovered) do
        if hovered.HandleZScavDrop then
            local mx, my = input.GetCursorPos()
            if hovered:HandleZScavDrop(root.zsDrag, mx, my) then
                return true
            end
        end
        if hovered == root then break end
        hovered = hovered:GetParent()
    end
    return false
end

local function GetAttachmentInstallPlacement(targetEntry, attachmentEntry, requireEmpty)
    if not (istable(targetEntry) and targetEntry.class and istable(attachmentEntry) and attachmentEntry.class) then
        return nil
    end

    if not ZSCAV:IsAttachmentItemClass(attachmentEntry) then
        return nil
    end

    local attKey = ZSCAV:NormalizeAttachmentKey(attachmentEntry)
    if attKey == "" then
        return nil
    end

    local placement = ZSCAV:GetAttachmentPlacement(attKey)
    if not placement or placement == "" then
        return nil
    end

    local compatible = false
    local optionsByPlacement = ZSCAV:BuildWeaponAttachmentOptions(targetEntry.class)
    for _, option in ipairs(optionsByPlacement[placement] or {}) do
        if ZSCAV:NormalizeAttachmentKey(option.key) == attKey then
            compatible = true
            break
        end
    end

    if not compatible then
        return nil
    end

    local installed = ZSCAV:NormalizeWeaponAttachments(
        targetEntry.class,
        targetEntry.weapon_state and targetEntry.weapon_state.attachments or nil
    )

    local currentKey = ZSCAV:NormalizeAttachmentKey(installed[placement])
    if requireEmpty and currentKey ~= "" then
        return nil
    end

    return placement, currentKey
end

local function FindDirectAttachmentPlacement(targetEntry, attachmentEntry)
    local placement = GetAttachmentInstallPlacement(targetEntry, attachmentEntry, true)
    return placement
end

local function ShowAttachmentInventoryOnlyNotice()
    notification.AddLegacy("[ZScav] Move the weapon and attachment into your inventory to modify attachments.", NOTIFY_HINT, 3)
    surface.PlaySound("buttons/button15.wav")
end

local function SendDirectAttachmentInstall(drag, weaponArgs, placement)
    if not (drag and istable(weaponArgs) and isstring(placement) and placement ~= "") then
        return false
    end

    if drag.fromContainer then
        ShowAttachmentInventoryOnlyNotice()
        return false
    end

    local payload = {
        placement = placement,
        weapon_uid = weaponArgs.weapon_uid,
        slot = weaponArgs.slot,
        grid = weaponArgs.grid,
        index = weaponArgs.index,
        attachment_key = ZSCAV:NormalizeAttachmentKey(drag.entry),
    }

    payload.attachment_grid = drag.fromGrid
    payload.attachment_index = drag.fromIndex
    SendAction("inspect_attach_install", payload)
    return true
end

local function GetAttachmentLocationLabel(target)
    if target.slot and target.slot ~= "" then
        return ATTACHMENT_SLOT_LABELS[target.slot] or target.slot
    end

    if target.inContainer then
        return target.containerLabel or "Open Container"
    end

    return ATTACHMENT_GRID_LABELS[target.grid] or tostring(target.grid or "Inventory")
end

local function SendAttachmentInstallFromContext(source, target)
    if not (istable(source) and istable(target)) then return false end

    if source.fromContainer or target.inContainer then
        ShowAttachmentInventoryOnlyNotice()
        return false
    end

    local payload = {
        placement = target.placement,
        weapon_uid = target.weapon_uid,
        slot = target.slot,
        grid = target.grid,
        index = target.index,
        target_uid = target.targetUID,
        target_index = target.targetIndex,
        attachment_key = ZSCAV:NormalizeAttachmentKey(source.entry),
    }

    payload.attachment_grid = source.grid
    payload.attachment_index = source.index

    SendAction("inspect_attach_install", payload)
    return true
end

local function CollectCompatibleWeaponTargets(attachmentSource)
    if not (istable(attachmentSource) and istable(attachmentSource.entry) and attachmentSource.entry.class) then
        return {}
    end

    local targets = {}
    local seen = {}
    local inv = GetInv()

    local function addTarget(entry, target)
        if not (istable(entry) and entry.class and istable(target)) then return end

        local placement, currentKey = GetAttachmentInstallPlacement(entry, attachmentSource.entry, false)
        if not placement then return end

        local dedupeKey = tostring(entry.weapon_uid or "")
        if dedupeKey == "" then
            dedupeKey = table.concat({
                tostring(target.targetUID or "inv"),
                tostring(target.slot or target.grid or "?"),
                tostring(target.targetIndex or target.index or "?"),
                tostring(entry.class or ""),
            }, ":")
        end

        if seen[dedupeKey] then return end
        seen[dedupeKey] = true

        local installedLabel = currentKey ~= "" and ZSCAV:GetAttachmentName(currentKey) or "Empty"
        target.label = PrettyName(entry.class)
        target.location = GetAttachmentLocationLabel(target)
        target.detail = "Slot: " .. ZSCAV:GetWeaponAttachmentSlotLabel(placement) .. " | Installed: " .. installedLabel
        target.placement = placement
        target.weapon_uid = tostring(entry.weapon_uid or target.weapon_uid or "")
        target.class = entry.class
        targets[#targets + 1] = target
    end

    if istable(inv) then
        for slotName, entry in pairs(inv.weapons or {}) do
            addTarget(entry, {
                slot = tostring(slotName or ""),
                inContainer = false,
            })
        end

        for _, gridName in ipairs({ "vest", "backpack", "pocket", "secure" }) do
            for index, entry in ipairs(inv[gridName] or {}) do
                addTarget(entry, {
                    grid = gridName,
                    index = index,
                    inContainer = false,
                })
            end
        end
    end

    table.sort(targets, function(left, right)
        if left.inContainer ~= right.inContainer then
            return left.inContainer == false
        end
        if left.location ~= right.location then
            return tostring(left.location or "") < tostring(right.location or "")
        end
        return tostring(left.label or "") < tostring(right.label or "")
    end)

    return targets
end

local function ShowAttachmentInspectPlaceholder(entry)
    local label = PrettyName(entry and entry.class or "attachment")
    notification.AddLegacy("[ZScav] Inspect placeholder for " .. label .. ".", NOTIFY_HINT, 2)
    surface.PlaySound("buttons/button15.wav")
end

local function OpenAttachmentEquipPicker(source)
    if not (istable(source) and istable(source.entry) and source.entry.class) then return end

    local targets = CollectCompatibleWeaponTargets(source)
    if #targets == 0 then
        notification.AddLegacy("[ZScav] No compatible weapons found in inventory or open storage.", NOTIFY_HINT, 2)
        surface.PlaySound("buttons/button15.wav")
        return
    end

    if IsValid(ATTACH_EQUIP_PICKER) then
        ATTACH_EQUIP_PICKER:Remove()
    end

    local frame = vgui.Create("DFrame")
    frame:SetSize(Nexus:Scale(420), Nexus:Scale(340))
    frame:Center()
    frame:SetTitle("")
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    frame:SetDeleteOnClose(true)
    frame.Paint = function(self, w, h)
        draw.RoundedBox(R12(), 0, 0, w, h, Color(18, 21, 24, 245))
        draw.RoundedBox(R12(), 0, 0, w, Nexus:Scale(42), Color(28, 32, 37, 245))
        draw.SimpleText("Equip Attachment", Nexus:GetFont(17, nil, true), Nexus:Scale(14), Nexus:Scale(12), COL_TXT())
        draw.SimpleText(PrettyName(source.entry.class), Nexus:GetFont(13), Nexus:Scale(14), Nexus:Scale(28), COL_DIM())
    end
    frame.OnClose = function()
        if ATTACH_EQUIP_PICKER == frame then
            ATTACH_EQUIP_PICKER = nil
        end
    end

    local scroll = frame:Add("DScrollPanel")
    scroll:SetPos(Nexus:Scale(10), Nexus:Scale(50))
    scroll:SetSize(frame:GetWide() - Nexus:Scale(20), frame:GetTall() - Nexus:Scale(60))
    do
        local bar = scroll:GetVBar()
        if bar then bar:SetWide(Nexus:Scale(8)) end
    end

    for _, target in ipairs(targets) do
        local button = scroll:Add("DButton")
        button:Dock(TOP)
        button:SetTall(Nexus:Scale(54))
        button:DockMargin(0, 0, 0, Nexus:Scale(6))
        button:SetText("")
        button.Paint = function(self, w, h)
            local bg = self:IsHovered() and Color(76, 68, 46, 225) or Color(40, 44, 50, 220)
            draw.RoundedBox(R8(), 0, 0, w, h, bg)
            draw.SimpleText(target.label, Nexus:GetFont(14, nil, true), Nexus:Scale(10), Nexus:Scale(10), Color(242, 238, 228))
            draw.SimpleText(target.location, Nexus:GetFont(12), w - Nexus:Scale(10), Nexus:Scale(11), Color(196, 180, 136), TEXT_ALIGN_RIGHT)
            draw.SimpleText(target.detail, Nexus:GetFont(12), Nexus:Scale(10), h - Nexus:Scale(12), Color(176, 180, 186), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
        end
        button.DoClick = function()
            if SendAttachmentInstallFromContext(source, target) then
                frame:Close()
            end
        end
    end

    ATTACH_EQUIP_PICKER = frame
end

local function CloseWorldPickupPrompt()
    WORLD_PICKUP_PROMPT = nil
end

local function OpenWorldPickupPrompt(entIndex, className, canEquip)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    entIndex = tonumber(entIndex) or -1
    if istable(WORLD_PICKUP_PROMPT) and WORLD_PICKUP_PROMPT.entIndex == entIndex then
        return
    end

    local ang = ply:EyeAngles()
    WORLD_PICKUP_PROMPT = {
        entIndex = entIndex,
        className = tostring(className or ""),
        canEquip = canEquip == true,
        baseYaw = tonumber(ang.y) or 0,
        basePitch = tonumber(ang.p) or 0,
        selectedMode = "take",
    }
end

local function GetWorldPickupPromptViewDelta(state)
    local ply = LocalPlayer()
    if not (IsValid(ply) and istable(state)) then
        return 0, 0, false
    end

    local ang = ply:EyeAngles()
    local yawDiff = math.AngleDifference(tonumber(state.baseYaw) or 0, tonumber(ang.y) or 0)
    local pitchDiff = math.AngleDifference(tonumber(ang.p) or 0, tonumber(state.basePitch) or 0)
    local within = math.abs(yawDiff) <= WORLD_PICKUP_PROMPT_CLOSE_YAW and math.abs(pitchDiff) <= WORLD_PICKUP_PROMPT_CLOSE_PITCH
    return yawDiff, pitchDiff, within
end

local function GetWorldPickupPromptSelection(state)
    local yawDiff, pitchDiff, within = GetWorldPickupPromptViewDelta(state)
    if not within then
        return nil, yawDiff, pitchDiff, false
    end

    if not istable(state) then
        return "take", yawDiff, pitchDiff, true
    end

    if state.canEquip ~= true then
        state.selectedMode = "take"
        return "take", yawDiff, pitchDiff, true
    end

    local selectedMode = state.selectedMode == "equip" and "equip" or "take"
    if selectedMode == "equip" then
        if yawDiff <= WORLD_PICKUP_PROMPT_EQUIP_EXIT_YAW then
            selectedMode = "take"
        end
    elseif yawDiff >= WORLD_PICKUP_PROMPT_EQUIP_ENTER_YAW then
        selectedMode = "equip"
    end

    state.selectedMode = selectedMode
    return selectedMode, yawDiff, pitchDiff, true
end

hook.Add("Think", "ZSCAV_WorldPickupPromptState", function()
    local state = WORLD_PICKUP_PROMPT
    if not istable(state) then return end

    if IsValid(PANEL_REF) then
        CloseWorldPickupPrompt()
        return
    end

    local ply = LocalPlayer()
    local ent = Entity(tonumber(state.entIndex) or -1)
    if not (IsValid(ply) and IsValid(ent)) then
        CloseWorldPickupPrompt()
        return
    end

    if ent:GetPos():DistToSqr(ply:GetPos()) > WORLD_PICKUP_PROMPT_RANGE_SQR then
        CloseWorldPickupPrompt()
        return
    end

    local _, _, within = GetWorldPickupPromptSelection(state)
    if not within then
        CloseWorldPickupPrompt()
    end
end)

hook.Add("HUDPaint", "ZSCAV_WorldPickupPromptHUD", function()
    local state = WORLD_PICKUP_PROMPT
    if not istable(state) then return end

    local selectedMode = select(1, GetWorldPickupPromptSelection(state))
    if not selectedMode then return end

    local sw, sh = ScrW(), ScrH()
    local centerX = sw * 0.5
    local centerY = sh * 0.6
    local optionW = Nexus:Scale(206)
    local optionH = Nexus:Scale(54)
    local gap = Nexus:Scale(14)
    local titleW = state.canEquip and (optionW * 2 + gap) or optionW

    draw.RoundedBox(R12(), centerX - (titleW * 0.5), centerY - Nexus:Scale(68), titleW, Nexus:Scale(40), Color(18, 21, 24, 220))
    draw.SimpleText("World Loot", Nexus:GetFont(16, nil, true), centerX, centerY - Nexus:Scale(57), COL_TXT(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(PrettyName(state.className), Nexus:GetFont(13), centerX, centerY - Nexus:Scale(35), COL_DIM(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local function drawOption(x, mode, title, detail, activeColor, idleColor)
        local isActive = selectedMode == mode
        draw.RoundedBox(R8(), x, centerY, optionW, optionH, isActive and activeColor or idleColor)
        surface.SetDrawColor(isActive and Color(255, 244, 210, 120) or Color(0, 0, 0, 70))
        surface.DrawOutlinedRect(x, centerY, optionW, optionH, 1)
        draw.SimpleText(title, Nexus:GetFont(14, nil, true), x + Nexus:Scale(12), centerY + optionH * 0.5, Color(242, 238, 228), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(detail, Nexus:GetFont(12), x + optionW - Nexus:Scale(14), centerY + optionH * 0.5, isActive and Color(250, 236, 196) or Color(190, 196, 202), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    if state.canEquip then
        local leftX = centerX - optionW - (gap * 0.5)
        local rightX = centerX + (gap * 0.5)
        drawOption(leftX, "take", "Take", "Keep centered / left", Color(84, 98, 76, 235), Color(54, 64, 58, 210))
        drawOption(rightX, "equip", "Equip", "Look right", Color(96, 84, 58, 235), Color(68, 58, 40, 210))
    else
        drawOption(centerX - (optionW * 0.5), "take", "Take", "Press E again", Color(84, 98, 76, 235), Color(54, 64, 58, 210))
    end

    draw.SimpleText("Press E on the highlighted option", Nexus:GetFont(12), centerX, centerY + optionH + Nexus:Scale(14), Color(208, 214, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

hook.Add("PlayerBindPress", "ZSCAV_WorldPickupPromptInput", function(ply, bind, pressed)
    if ply ~= LocalPlayer() or not pressed then return end

    local state = WORLD_PICKUP_PROMPT
    if not istable(state) then return end

    local lowered = string.lower(tostring(bind or ""))
    if not lowered:find("+use", 1, true) then return end

    local selectedMode = select(1, GetWorldPickupPromptSelection(state))
    if selectedMode then
        SendAction("world_pickup", {
            ent_index = state.entIndex,
            mode = selectedMode,
        })
    end

    CloseWorldPickupPrompt()
    return true
end)

local function OpenAttachmentContextMenu(source)
    if not (istable(source) and istable(source.entry) and source.entry.class) then return end

    local m = DermaMenu()
    if source.fromContainer then
        m:AddOption("Take", function()
            SendContainerAction("take", {
                index = source.fromIndex,
                target_uid = source.fromUID,
            })
        end)
        m:AddOption("Drop to floor", function()
            SendContainerAction("drop_to_floor", {
                index = source.fromIndex,
                target_uid = source.fromUID,
            })
        end)
    else
        m:AddOption("Drop", function()
            SendAction("drop", {
                grid = source.grid,
                index = source.index,
            })
        end)
        m:AddOption("Equip", function()
            OpenAttachmentEquipPicker(source)
        end)
    end
    m:AddOption("Inspect", function()
        ShowAttachmentInspectPlaceholder(source.entry)
    end)
    m:Open()
end

local function OpenContextMenu(gridName, index, entry)
    if entry and entry.class and ZSCAV:IsAttachmentItemClass(entry) then
        OpenAttachmentContextMenu({
            entry = entry,
            fromContainer = false,
            grid = gridName,
            index = index,
        })
        return
    end

    local m = DermaMenu()
    local ticketData = GetVendorTicketData(entry)

    if ticketData then
        m:AddOption("View Menu", function()
            OpenVendorTicketMenu(entry)
        end)
    end

    m:AddOption("Inspect", function()
        OpenInspect({
            grid = gridName,
            index = index,
            weapon_uid = entry and entry.weapon_uid,
        }, entry)
    end)

    local def = ZSCAV:GetGearDef(entry.class)
    local canOpenContainer = (entry.uid and entry.uid ~= "")
        or (def and (def.slot == "backpack" or def.compartment or def.secure))
    if canOpenContainer then
        m:AddOption("Open bag", function()
            SendContainerAction("open_owned", {
                uid = entry.uid,
                from_grid = gridName,
                from_index = index,
            })
        end)
    end

    if ZSCAV:IsGearItem(entry.class) then
        m:AddOption("Equip gear", function()
            SendAction("equip_gear", { grid = gridName, index = index })
        end)
    end

    if CanEquipWeaponClass(entry.class) then
        local equipLabel = ZSCAV_ResolveGrenadeInventoryClassCL(entry) and "Ready grenade" or "Equip weapon"
        m:AddOption(equipLabel, function()
            SendAction("equip_weapon", { grid = gridName, index = index })
        end)
    end

    m:AddOption("Reload (active)", function() SendAction("reload", {}) end)
    m:AddOption("Unload", function() SendAction("unload", {}) end)
    m:AddSpacer()
    if ticketData then
        m:AddOption("Discard ticket", function()
            ConfirmVendorTicketDiscard(entry, function()
                SendAction("drop", {
                    grid = gridName,
                    index = index,
                    confirm_ticket_destroy = true,
                })
            end)
        end)
    else
        m:AddOption("Drop", function()
            SendAction("drop", { grid = gridName, index = index })
        end)
    end
    m:Open()
end

local function EntryHasOwnContainer(entry)
    if not entry or not entry.class then return false end
    local def = ZSCAV:GetGearDef(entry.class)
    if entry.uid and entry.uid ~= "" then return true end
    return def and (def.slot == "backpack" or def.compartment or def.secure) or false
end

-- ---------------------------------------------------------------------
-- Grid panel
-- ---------------------------------------------------------------------
local GRID = {}

-- Client-side cache for layout blocks (Option C: cache fallback).
local _layoutBlocksCache = {}

function GRID:Init()
    self.gridName = "backpack"
    self.title = ""
    self._lastW = -1
    self._lastH = -1
end

function GRID:SetGrid(name, title)
    self.gridName = name
    self.title = title or name
    self:ResizeToGrid()
end

function GRID:GetRawEffSize()
    local grids = ZSCAV:GetEffectiveGrids(GetInv())
    local g = grids[self.gridName] or { w = 0, h = 0 }
    if self.gridName == "pocket" then
        return math.max(tonumber(g.w) or 0, 4), math.max(tonumber(g.h) or 0, 1)
    end
    -- Fallback: for the vest grid, use the server-pre-computed value
    -- (_vestGrid is attached by SyncInventory so clients without admin
    -- GearItems overrides still see the correct rig storage size).
    if self.gridName == "vest" and g.w == 0 and g.h == 0 then
        local inv = GetInv()
        local vg = inv and inv._vestGrid
        if istable(vg) then return tonumber(vg.w) or 0, tonumber(vg.h) or 0 end
    end

    return g.w, g.h
end

function GRID:GetEffSize()
    local gw, gh = self:GetRawEffSize()

    if self.gridName == "vest" and gw > 0 and gh > 0 then
        local blocks = self:GetLayoutBlocks(gw, gh)
        if blocks and #blocks > 0 then
            local minX, minY = gw, gh
            local maxX, maxY = 0, 0
            for _, b in ipairs(blocks) do
                minX = math.min(minX, b.x)
                minY = math.min(minY, b.y)
                maxX = math.max(maxX, b.x + b.w)
                maxY = math.max(maxY, b.y + b.h)
            end
            
            -- Calculate bounding box size
            local blockW = maxX - minX
            local blockH = maxY - minY
            
            -- Auto-center compartments when there's extra grid space
            local padX = math.max(0, gw - blockW)
            local padY = math.max(0, gh - blockH)
            local centerOffX = math.floor(padX / 2)
            local centerOffY = math.floor(padY / 2)
            
            self._vestOffX = math.max(0, minX - centerOffX)
            self._vestOffY = math.max(0, minY - centerOffY)
            self._vestDispW = math.max(1, blockW)
            self._vestDispH = math.max(1, blockH)
            return self._vestDispW, self._vestDispH
        end
    end

    self._vestOffX, self._vestOffY = 0, 0
    self._vestDispW, self._vestDispH = nil, nil
    return gw, gh
end

function GRID:GetLayoutBlocks(gw, gh)
    if self.gridName == "pocket" then
        return {
            { x = 0, y = 0, w = 1, h = 1 },
            { x = 1, y = 0, w = 1, h = 1 },
            { x = 2, y = 0, w = 1, h = 1 },
            { x = 3, y = 0, w = 1, h = 1 },
        }
    end

    if self.gridName ~= "vest" and self.gridName ~= "backpack" and self.gridName ~= "secure" then
        return nil
    end

    local inv = GetInv()
    local class = nil
    if self.gridName == "vest" then
        local rig = inv and inv.gear and (inv.gear.tactical_rig or inv.gear.vest)
        class = rig and rig.class
    elseif self.gridName == "backpack" then
        local pack = inv and inv.gear and inv.gear.backpack
        class = pack and pack.class
    else
        local secure = inv and inv.gear and inv.gear.secure_container
        class = secure and secure.class
    end
    if not class then return nil end

    -- Option A: Check if layout blocks came with the inventory sync.
    local syncBlocks = nil
    if self.gridName == "vest" then
        syncBlocks = inv._vestLayoutBlocks
    elseif self.gridName == "backpack" then
        syncBlocks = inv._backpackLayoutBlocks
    elseif self.gridName == "secure" then
        syncBlocks = inv._secureLayoutBlocks
    end

    if istable(syncBlocks) and #syncBlocks > 0 then
        local src = syncBlocks
        -- Process and return.
        local out = {}
        for _, b in ipairs(src) do
            local bx = math.max(0, math.floor(tonumber(b.x) or 0))
            local by = math.max(0, math.floor(tonumber(b.y) or 0))
            local bw = math.max(1, math.floor(tonumber(b.w) or 1))
            local bh = math.max(1, math.floor(tonumber(b.h) or 1))
            if bx < gw and by < gh then
                if bx + bw > gw then bw = gw - bx end
                if by + bh > gh then bh = gh - by end
                if bw > 0 and bh > 0 then
                    out[#out + 1] = { x = bx, y = by, w = bw, h = bh }
                end
            end
        end
        if #out > 0 then
            _layoutBlocksCache[class] = out
            return out
        end
    end

    -- Option C: Check the client cache.
    if _layoutBlocksCache[class] and istable(_layoutBlocksCache[class]) and #_layoutBlocksCache[class] > 0 then
        return _layoutBlocksCache[class]
    end

    -- Option B: Try to get from ZSCAV.GearItems (fallback).
    local def = ZSCAV:GetGearDef(class)
    local src = def and def.layoutBlocks
    if not istable(src) or #src == 0 then return nil end

    local out = {}
    for _, b in ipairs(src) do
        local bx = math.max(0, math.floor(tonumber(b.x) or 0))
        local by = math.max(0, math.floor(tonumber(b.y) or 0))
        local bw = math.max(1, math.floor(tonumber(b.w) or 1))
        local bh = math.max(1, math.floor(tonumber(b.h) or 1))
        if bx < gw and by < gh then
            if bx + bw > gw then bw = gw - bx end
            if by + bh > gh then bh = gh - by end
            if bw > 0 and bh > 0 then
                out[#out + 1] = { x = bx, y = by, w = bw, h = bh }
            end
        end
    end

    if #out > 0 then
        _layoutBlocksCache[class] = out
        return out
    end
    return nil
end

function GRID:IsCellInAnyBlock(cx, cy, blocks)
    if not blocks then return true end
    for _, b in ipairs(blocks) do
        if cx >= b.x and cx < b.x + b.w and cy >= b.y and cy < b.y + b.h then
            return true
        end
    end
    return false
end

function GRID:RectInsideAnyBlock(x, y, w, h, blocks)
    if not blocks then return true end
    for _, b in ipairs(blocks) do
        if x >= b.x and y >= b.y and (x + w) <= (b.x + b.w) and (y + h) <= (b.y + b.h) then
            return true
        end
    end
    return false
end

function GRID:ResizeToGrid()
    local w, h = self:GetEffSize()
    local vw, vh = math.max(w, 1), math.max(h, 1)
    local panelW = vw * (CELL() + PAD()) + PAD() * 2
    local panelH = vh * (CELL() + PAD()) + PAD() * 2 + Nexus:Scale(30)
    self:SetSize(panelW, panelH)
end

function GRID:GetDisplayOffset()
    if self.gridName ~= "vest" then return 0, 0 end
    local _w, _h = self:GetEffSize()
    return tonumber(self._vestOffX) or 0, tonumber(self._vestOffY) or 0
end

function GRID:Think()
    local w, h = self:GetEffSize()
    if w ~= self._lastW or h ~= self._lastH then
        self._lastW, self._lastH = w, h
        self:ResizeToGrid()
        local root = FindRoot(self)
        if root and root.DoLayout then root:DoLayout() end
    end
end

local function FindItemUnderCursor(self, mx, my)
    local top = Nexus:Scale(30)
    local list = (GetInv() or {})[self.gridName]
    if not list then return nil end
    local offX, offY = self:GetDisplayOffset()

    for i, it in ipairs(list) do
        local ix = PAD() + (it.x - offX) * (CELL() + PAD())
        local iy = top + PAD() + (it.y - offY) * (CELL() + PAD())
        local iw = it.w * (CELL() + PAD()) - PAD()
        local ih = it.h * (CELL() + PAD()) - PAD()
        if mx >= ix and mx <= ix + iw and my >= iy and my <= iy + ih then
            return i, it
        end
    end

    return nil
end

function GRID:Paint(w, h)
    draw.RoundedBox(R12(), 0, 0, w, h, COL_PANEL())
    surface.SetDrawColor(COL_LINE())
    surface.DrawOutlinedRect(0, 0, w, h, 1)

    local gw, gh = self:GetEffSize()
    local rawW, rawH = self:GetRawEffSize()
    local offX, offY = self:GetDisplayOffset()
    local title = self.title
    if gw == 0 or gh == 0 then
        title = title .. " (locked)"
    end

    draw.SimpleText(title, Nexus:GetFont(18, nil, true), PAD() * 2, Nexus:Scale(6), COL_TXT())

    local top = Nexus:Scale(30)
    local blocks = self:GetLayoutBlocks(rawW, rawH)

    -- For any compartmented grid: only draw cells inside blocks.
    if blocks and #blocks > 0 then
        -- Draw all cells and compartment backgrounds first.
        for _, b in ipairs(blocks) do
            local bx = PAD() + (b.x - offX) * (CELL() + PAD())
            local by = top + PAD() + (b.y - offY) * (CELL() + PAD())

            -- Draw individual cells inside this block.
            for cy = b.y, b.y + b.h - 1 do
                for cx = b.x, b.x + b.w - 1 do
                    local cellX = PAD() + (cx - offX) * (CELL() + PAD())
                    local cellY = top + PAD() + (cy - offY) * (CELL() + PAD())
                    draw.RoundedBox(R8(), cellX, cellY, CELL(), CELL(), COL_SLOT())
                end
            end
        end

        -- Draw strong compartment boundaries on top.
        for _, b in ipairs(blocks) do
            local bx = PAD() + (b.x - offX) * (CELL() + PAD())
            local by = top + PAD() + (b.y - offY) * (CELL() + PAD())
            local bw = b.w * (CELL() + PAD()) - PAD()
            local bh = b.h * (CELL() + PAD()) - PAD()

            -- Compartment background color (subtle).
            draw.RoundedBox(R8(), bx - 1, by - 1,
                bw + 2, bh + 2, Color(50, 65, 90, 80))

            -- Strong outer border for compartment separation.
            surface.SetDrawColor(200, 220, 240, 255)
            surface.DrawOutlinedRect(bx - 2, by - 2, bw + 4, bh + 4, 2)
        end
    else
        -- Non-vest grids: render normally with full grid.
        for y = 0, math.max(gh, 1) - 1 do
            for x = 0, math.max(gw, 1) - 1 do
                draw.RoundedBox(R8(),
                    PAD() + x * (CELL() + PAD()),
                    top + PAD() + y * (CELL() + PAD()),
                    CELL(), CELL(), COL_SLOT())
            end
        end
    end

    local root = FindRoot(self)
    local drag = root and root.zsDrag or nil
    local list = (GetInv() or {})[self.gridName]
    if not list then return end

    for i, it in ipairs(list) do
        if not (drag and drag.fromGrid == self.gridName and drag.fromIndex == i) then
            local ix = PAD() + (it.x - offX) * (CELL() + PAD())
            local iy = top + PAD() + (it.y - offY) * (CELL() + PAD())
            local iw = it.w * (CELL() + PAD()) - PAD()
            local ih = it.h * (CELL() + PAD()) - PAD()
            local col = ZSCAV:IsGearItem(it.class) and COL_GEAR() or COL_ITEM()

            draw.RoundedBox(R8(), ix, iy, iw, ih, col)
            surface.SetDrawColor(COL_LINE())
            surface.DrawOutlinedRect(ix, iy, iw, ih, 1)

            draw.SimpleText(PrettyName(it.class), Nexus:GetFont(14),
                ix + Nexus:Scale(6), iy + Nexus:Scale(4), COL_TXT())
            DrawWeaponAttachmentOverlay(it, ix, iy, iw, ih)
            ZSCAV_DrawMedicalCounterBadgeCL(it, ix, iy, iw, ih)
            DrawVendorTicketBadgeCL(it, ix, iy, iw, ih)
            draw.SimpleText(it.w .. "x" .. it.h, Nexus:GetFont(12),
                ix + iw - Nexus:Scale(6), iy + ih - Nexus:Scale(14),
                COL_DIM(), TEXT_ALIGN_RIGHT)
        end
    end

    if drag and self:IsHovered() then
        local mx, my = self:CursorPos()
        local e = drag.entry
        local step = CELL() + PAD()
        local ghostW = e.w * step - PAD()
        local ghostH = e.h * step - PAD()
        local grabX = tonumber(drag.grabOffX) or (ghostW * 0.5)
        local grabY = tonumber(drag.grabOffY) or (ghostH * 0.5)
        local itemLeft = mx - grabX
        local itemTop = my - grabY
        local gx = math.floor((itemLeft - PAD()) / step)
        local gy = math.floor((itemTop - top - PAD()) / step)
        local rx, ry = gx + offX, gy + offY

        local ix = PAD() + gx * (CELL() + PAD())
        local iy = top + PAD() + gy * (CELL() + PAD())
        local iw = e.w * (CELL() + PAD()) - PAD()
        local ih = e.h * (CELL() + PAD()) - PAD()

        local fits = (gx >= 0 and gy >= 0 and rx + e.w <= rawW and ry + e.h <= rawH)
            and self:RectInsideAnyBlock(rx, ry, e.w, e.h, blocks)
        draw.RoundedBox(R8(), ix, iy, iw, ih, fits and COL_OK() or COL_BAD())
    end
end

function GRID:OnMousePressed(code)
    local mx, my = self:CursorPos()
    local idx, it = FindItemUnderCursor(self, mx, my)

    if code == MOUSE_RIGHT then
        if it then OpenContextMenu(self.gridName, idx, it) end
        return
    end

    if code == MOUSE_LEFT and it then
        if IsShiftDown() then
            local stashUID = GetOpenPlayerStashRootUID()
            if stashUID ~= "" then
                SendContainerAction("quick_put_from_grid", {
                    from_grid = self.gridName,
                    from_index = idx,
                    target_uid = stashUID,
                })
            else
                SendAction("quick_move_inventory", {
                    from_grid = self.gridName,
                    from_index = idx,
                })
            end
            return
        end

        if IsCtrlDown() then
            SendContainerAction("quick_put_from_grid", {
                from_grid = self.gridName,
                from_index = idx,
            })
            return
        end

        local top = Nexus:Scale(30)
        local offX, offY = self:GetDisplayOffset()
        local itemX = PAD() + (it.x - offX) * (CELL() + PAD())
        local itemY = top + PAD() + (it.y - offY) * (CELL() + PAD())
        StartDrag(self, self.gridName, idx, it, false, "", {
            grabOffX = mx - itemX,
            grabOffY = my - itemY,
        })
    end
end

function GRID:HandleZScavDrop(drag, screenX, screenY)
    if not drag then return false end

    local lx, ly = self:ScreenToLocal(screenX, screenY)
    if lx < 0 or ly < 0 or lx > self:GetWide() or ly > self:GetTall() then
        return false
    end

    local top = Nexus:Scale(30)
    local step = CELL() + PAD()
    local ghostW = (drag.entry and drag.entry.w or 1) * step - PAD()
    local ghostH = (drag.entry and drag.entry.h or 1) * step - PAD()
    local grabX = tonumber(drag.grabOffX) or (ghostW * 0.5)
    local grabY = tonumber(drag.grabOffY) or (ghostH * 0.5)
    local itemLeft = lx - grabX
    local itemTop = ly - grabY
    local gx = math.floor((itemLeft - PAD()) / step)
    local gy = math.floor((itemTop - top - PAD()) / step)
    local offX, offY = self:GetDisplayOffset()
    local tx, ty = gx + offX, gy + offY

    local list = (GetInv() or {})[self.gridName] or {}
    local targetIdx, targetEntry = nil, nil
    for i, it in ipairs(list) do
        if tx >= it.x and tx < (it.x + it.w) and ty >= it.y and ty < (it.y + it.h) then
            targetIdx, targetEntry = i, it
            break
        end
    end

    local directAttachPlacement = FindDirectAttachmentPlacement(targetEntry, drag.entry)
    if directAttachPlacement then
        return SendDirectAttachmentInstall(drag, {
            grid = self.gridName,
            index = targetIdx,
            weapon_uid = targetEntry and targetEntry.weapon_uid,
        }, directAttachPlacement)
    end

    local droppingOnContainerItem = targetIdx
        and EntryHasOwnContainer(targetEntry)
        and not (drag.fromContainer == false and drag.fromGrid == self.gridName and drag.fromIndex == targetIdx)

    -- Drag came from an open container -> strict place into this player grid.
    if drag.fromContainer then
        if droppingOnContainerItem then
            SendContainerAction("put_into_owned_item", {
                from_uid = drag.fromContainerUID,
                from_index = drag.fromIndex,
                target_grid = self.gridName,
                target_index = targetIdx,
                rotated = drag.rotated and true or false,
            })
            return true
        end

        SendContainerAction("take", {
            index = drag.fromIndex,
            target_uid = drag.fromContainerUID,
            to_grid = self.gridName,
            x = tx,
            y = ty,
            rotated = drag.rotated and true or false,
        })
        return true
    end

    if drag.fromSlot then
        SendAction("unequip_slot_to_grid", {
            kind = drag.slotKind,
            slot = drag.slotID,
            to_grid = self.gridName,
            x = tx,
            y = ty,
            rotated = drag.rotated and true or false,
        })
        return true
    end

    if droppingOnContainerItem then
        SendContainerAction("put_into_owned_item", {
            from_grid = drag.fromGrid,
            from_index = drag.fromIndex,
            target_grid = self.gridName,
            target_index = targetIdx,
            rotated = drag.rotated and true or false,
        })
        return true
    end

    SendAction("move", {
        from_grid = drag.fromGrid,
        from_index = drag.fromIndex,
        to_grid = self.gridName,
        x = tx,
        y = ty,
        rotated = drag.rotated and true or false,
    })

    return true
end

function GRID:HandleZScavRotate()
    local mx, my = self:CursorPos()
    if mx < 0 or my < 0 or mx > self:GetWide() or my > self:GetTall() then
        return false
    end
    local idx, _it = FindItemUnderCursor(self, mx, my)
    if not idx then return false end
    SendAction("rotate", { grid = self.gridName, index = idx })
    return true
end

vgui.Register("ZScavGrid", GRID, "Panel")

local function OpenContainerEntryContextMenu(containerUID, idx, it)
    containerUID = tostring(containerUID or "")
    if containerUID == "" or not (it and it.class) then return end

    if it.class and ZSCAV:IsAttachmentItemClass(it) then
        OpenAttachmentContextMenu({
            entry = it,
            fromContainer = true,
            fromUID = containerUID,
            fromIndex = idx,
        })
        return
    end

    local m = DermaMenu()
    local def = ZSCAV:GetGearDef(it.class)
    local canOpenNested = (it.uid and it.uid ~= "")
        or (def and (def.slot == "backpack" or def.compartment or def.secure))
    local ticketData = GetVendorTicketData(it)

    if ticketData then
        m:AddOption("View Menu", function()
            OpenVendorTicketMenu(it)
        end)
    end

    m:AddOption("Inspect", function()
        OpenInspect({
            target_uid = containerUID,
            target_index = idx,
            weapon_uid = it.weapon_uid,
        }, it)
    end)

    if canOpenNested then
        m:AddSpacer()
        m:AddOption("Open nested bag", function()
            SendContainerAction("open_nested", {
                uid = it.uid,
                index = idx,
                target_uid = containerUID,
            })
        end)
    end

    m:AddOption("Take", function()
        SendContainerAction("take", { index = idx, target_uid = containerUID })
    end)
    m:AddSpacer()
    if ticketData then
        m:AddOption("Discard ticket", function()
            ConfirmVendorTicketDiscard(it, function()
                SendContainerAction("drop_to_floor", {
                    index = idx,
                    target_uid = containerUID,
                    confirm_ticket_destroy = true,
                })
            end)
        end)
    else
        m:AddOption("Drop to floor", function()
            SendContainerAction("drop_to_floor", { index = idx, target_uid = containerUID })
        end)
    end
    m:Open()
end

local function StartContainerEntryDrag(panel, containerUID, idx, entry, mx, my, itemX, itemY)
    if not (entry and entry.class) then return end

    local step = CELL() + PAD()
    local ghostW = math.max(1, (math.max(1, tonumber(entry.w) or 1) * step) - PAD())
    local ghostH = math.max(1, (math.max(1, tonumber(entry.h) or 1) * step) - PAD())

    StartDrag(panel, "__container__", idx, entry, true, containerUID, {
        grabOffX = math.Clamp(mx - itemX, 0, math.max(ghostW - 1, 0)),
        grabOffY = math.Clamp(my - itemY, 0, math.max(ghostH - 1, 0)),
    })
end

local function HandleContainerEntryPrimaryClick(panel, containerUID, idx, it, mx, my, itemX, itemY)
    if not (it and it.class) then return false end

    local stashUID = GetOpenPlayerStashRootUID(containerUID)

    if IsAltDown() then
        SendContainerAction("quick_equip", {
            index = idx,
            target_uid = containerUID,
        })
        return true
    end

    if IsShiftDown() then
        if stashUID ~= "" then
            SendContainerAction("quick_transfer_to_container", {
                from_uid = containerUID,
                from_index = idx,
                target_uid = stashUID,
            })
        else
            SendContainerAction("quick_take_to_inventory", {
                index = idx,
                target_uid = containerUID,
            })
        end
        return true
    end

    if IsCtrlDown() then
        local secureUID = GetOpenOwnedSlotContainerUID("secure_container", containerUID)
        if secureUID ~= "" then
            SendContainerAction("put_to_owned_slot", {
                from_uid = containerUID,
                from_index = idx,
                slot = "secure_container",
            })
        else
            SendContainerAction("quick_take_to_inventory", {
                index = idx,
                target_uid = containerUID,
            })
        end
        return true
    end

    StartContainerEntryDrag(panel, containerUID, idx, it, mx, my, itemX, itemY)
    return true
end

-- ---------------------------------------------------------------------
-- Container grid panel – used inside floating bag windows.
-- Each instance is bound to a specific container UID via self.containerUID.
-- ---------------------------------------------------------------------
local CGRID = {}

function CGRID:Init()
    self._lastW = -1
    self._lastH = -1
    self.containerUID = ""
end

function CGRID:GetState()
    return CONT_WINDOWS[self.containerUID]
end

function CGRID:GetLayoutBlocks()
    local st = self:GetState()
    if not st then return nil end
    local src = st.layoutBlocks
    if not (istable(src) and #src > 0) then return nil end

    local gw = math.max(0, tonumber(st.gw) or 0)
    local gh = math.max(0, tonumber(st.gh) or 0)
    local out = {}

    for _, b in ipairs(src) do
        local bx = math.max(0, math.floor(tonumber(b.x) or 0))
        local by = math.max(0, math.floor(tonumber(b.y) or 0))
        local bw = math.max(1, math.floor(tonumber(b.w) or 1))
        local bh = math.max(1, math.floor(tonumber(b.h) or 1))
        if bx < gw and by < gh then
            if bx + bw > gw then bw = gw - bx end
            if by + bh > gh then bh = gh - by end
            if bw > 0 and bh > 0 then
                out[#out + 1] = { x = bx, y = by, w = bw, h = bh }
            end
        end
    end

    return (#out > 0) and out or nil
end

function CGRID:RectInsideAnyBlock(x, y, w, h, blocks)
    if not blocks then return true end
    for _, b in ipairs(blocks) do
        if x >= b.x and y >= b.y and (x + w) <= (b.x + b.w) and (y + h) <= (b.y + b.h) then
            return true
        end
    end
    return false
end

function CGRID:ResizeToContainer()
    local st = self:GetState()
    local gw = st and tonumber(st.gw) or 1
    local gh = st and tonumber(st.gh) or 1
    gw = math.max(gw, 1)
    gh = math.max(gh, 1)
    local panelW = gw * (CELL() + PAD()) + PAD() * 2
    local panelH = gh * (CELL() + PAD()) + PAD() * 2
    self:SetSize(panelW, panelH)
end

function CGRID:Think()
    local st = self:GetState()
    local gw = st and (tonumber(st.gw) or 0) or 0
    local gh = st and (tonumber(st.gh) or 0) or 0
    if gw ~= self._lastW or gh ~= self._lastH then
        self._lastW = gw
        self._lastH = gh
        self:ResizeToContainer()
        -- Notify parent window to resize around new grid.
        local p = self:GetParent()
        if IsValid(p) and p.OnGridResize then p:OnGridResize() end
    end
end

function CGRID:Paint(w, h)
    local st = self:GetState()
    if not st then
        draw.SimpleText("(loading...)", Nexus:GetFont(14), Nexus:Scale(8), Nexus:Scale(8), COL_DIM())
        return
    end

    surface.SetDrawColor(COL_LINE())
    surface.DrawOutlinedRect(0, 0, w, h, 1)

    local root = FindRoot(self)
    local drag = root and root.zsDrag or nil
    local blocks = self:GetLayoutBlocks()

    if blocks and #blocks > 0 then
        for _, b in ipairs(blocks) do
            for cy = b.y, b.y + b.h - 1 do
                for cx = b.x, b.x + b.w - 1 do
                    draw.RoundedBox(R8(),
                        PAD() + cx * (CELL() + PAD()),
                        PAD() + cy * (CELL() + PAD()),
                        CELL(), CELL(), COL_SLOT())
                end
            end
        end

        for _, b in ipairs(blocks) do
            local bx = PAD() + b.x * (CELL() + PAD())
            local by = PAD() + b.y * (CELL() + PAD())
            local bw = b.w * (CELL() + PAD()) - PAD()
            local bh = b.h * (CELL() + PAD()) - PAD()

            draw.RoundedBox(R8(), bx - 1, by - 1, bw + 2, bh + 2, Color(50, 65, 90, 80))
            surface.SetDrawColor(200, 220, 240, 255)
            surface.DrawOutlinedRect(bx - 2, by - 2, bw + 4, bh + 4, 2)
        end
    else
        for y = 0, math.max(st.gh, 1) - 1 do
            for x = 0, math.max(st.gw, 1) - 1 do
                draw.RoundedBox(R8(),
                    PAD() + x * (CELL() + PAD()),
                    PAD() + y * (CELL() + PAD()),
                    CELL(), CELL(), COL_SLOT())
            end
        end
    end

    for i, it in ipairs(st.contents or {}) do
        if not (drag and drag.fromContainer and drag.fromContainerUID == self.containerUID and drag.fromIndex == i) then
            local ix = PAD() + it.x * (CELL() + PAD())
            local iy = PAD() + it.y * (CELL() + PAD())
            local iw = it.w * (CELL() + PAD()) - PAD()
            local ih = it.h * (CELL() + PAD()) - PAD()
            local col = ZSCAV:IsGearItem(it.class) and COL_GEAR() or COL_ITEM()

            draw.RoundedBox(R8(), ix, iy, iw, ih, col)
            surface.SetDrawColor(COL_LINE())
            surface.DrawOutlinedRect(ix, iy, iw, ih, 1)
            draw.SimpleText(PrettyName(it.class), Nexus:GetFont(14),
                ix + Nexus:Scale(6), iy + Nexus:Scale(4), COL_TXT())
            DrawWeaponAttachmentOverlay(it, ix, iy, iw, ih)
            ZSCAV_DrawMedicalCounterBadgeCL(it, ix, iy, iw, ih)
            DrawVendorTicketBadgeCL(it, ix, iy, iw, ih)
            if it.uid and it.uid ~= "" then
                draw.SimpleText("BAG", Nexus:GetFont(11),
                    ix + iw - Nexus:Scale(6), iy + Nexus:Scale(4),
                    Color(220, 200, 110), TEXT_ALIGN_RIGHT)
            end
        end
    end

    if drag and self:IsHovered() then
        local mx, my = self:CursorPos()
        local step = CELL() + PAD()
        local e = drag.entry
        local ghostW = e.w * step - PAD()
        local ghostH = e.h * step - PAD()
        local grabX = tonumber(drag.grabOffX) or (ghostW * 0.5)
        local grabY = tonumber(drag.grabOffY) or (ghostH * 0.5)
        local itemLeft = mx - grabX
        local itemTop = my - grabY
        local gx = math.floor((itemLeft - PAD()) / step)
        local gy = math.floor((itemTop - PAD()) / step)
        local ix = PAD() + gx * (CELL() + PAD())
        local iy = PAD() + gy * (CELL() + PAD())
        local iw = e.w * (CELL() + PAD()) - PAD()
        local ih = e.h * (CELL() + PAD()) - PAD()
        local fits = (gx >= 0 and gy >= 0 and gx + e.w <= st.gw and gy + e.h <= st.gh)
            and self:RectInsideAnyBlock(gx, gy, e.w, e.h, blocks)
        draw.RoundedBox(R8(), ix, iy, iw, ih, fits and COL_OK() or COL_BAD())
    end
end

local function CGRID_FindItemUnderCursor(self, mx, my)
    local st = self:GetState()
    if not st then return nil end
    for i, it in ipairs(st.contents or {}) do
        local ix = PAD() + it.x * (CELL() + PAD())
        local iy = PAD() + it.y * (CELL() + PAD())
        local iw = it.w * (CELL() + PAD()) - PAD()
        local ih = it.h * (CELL() + PAD()) - PAD()
        if mx >= ix and mx <= ix + iw and my >= iy and my <= iy + ih then
            return i, it
        end
    end
    return nil
end

function CGRID:OnMousePressed(code)
    local st = self:GetState()
    if not st then return end
    local mx, my = self:CursorPos()
    local idx, it = CGRID_FindItemUnderCursor(self, mx, my)

    if code == MOUSE_RIGHT then
        if not it then return end
        OpenContainerEntryContextMenu(self.containerUID, idx, it)
        return
    end

    if code == MOUSE_LEFT and it then
        local itemX = PAD() + it.x * (CELL() + PAD())
        local itemY = PAD() + it.y * (CELL() + PAD())
        HandleContainerEntryPrimaryClick(self, self.containerUID, idx, it, mx, my, itemX, itemY)
    end
end

function CGRID:HandleZScavDrop(drag, screenX, screenY)
    if not drag then return false end
    local st = self:GetState()
    if not st then return false end

    local lx, ly = self:ScreenToLocal(screenX, screenY)
    if lx < 0 or ly < 0 or lx > self:GetWide() or ly > self:GetTall() then
        return false
    end

    local step = CELL() + PAD()
    local ghostW = (drag.entry and drag.entry.w or 1) * step - PAD()
    local ghostH = (drag.entry and drag.entry.h or 1) * step - PAD()
    local grabX = tonumber(drag.grabOffX) or (ghostW * 0.5)
    local grabY = tonumber(drag.grabOffY) or (ghostH * 0.5)
    local itemLeft = lx - grabX
    local itemTop = ly - grabY
    local gx = math.floor((itemLeft - PAD()) / step)
    local gy = math.floor((itemTop - PAD()) / step)

    if drag.fromSlot then
        SendAction("unequip_slot_to_container", {
            kind = drag.slotKind,
            slot = drag.slotID,
            target_uid = self.containerUID,
            x = gx,
            y = gy,
            rotated = drag.rotated and true or false,
        })
        return true
    end

    if drag.fromContainer then
        if drag.fromContainerUID == self.containerUID then
            -- Move within the same container.
            SendContainerAction("move", { index = drag.fromIndex, x = gx, y = gy, target_uid = self.containerUID, rotated = drag.rotated and true or false })
        else
            -- Transfer from another open container window.
            SendContainerAction("transfer", {
                from_uid    = drag.fromContainerUID,
                from_index  = drag.fromIndex,
                to_uid      = self.containerUID,
                x           = gx,
                y           = gy,
                rotated     = drag.rotated and true or false,
            })
        end
    else
        -- Push from player inv into this container.
        SendContainerAction("put", {
            from_grid  = drag.fromGrid,
            from_index = drag.fromIndex,
            target_uid = self.containerUID,
            x          = gx,
            y          = gy,
            rotated    = drag.rotated and true or false,
        })
    end
    return true
end

-- R-key in-place rotation for items inside a container window.
function CGRID:HandleZScavRotate()
    local st = self:GetState()
    if not st then return false end
    local mx, my = self:CursorPos()
    local gx = math.floor((mx - PAD()) / (CELL() + PAD()))
    local gy = math.floor((my - PAD()) / (CELL() + PAD()))
    for i, it in ipairs(st.contents or {}) do
        if gx >= it.x and gx < it.x + it.w and gy >= it.y and gy < it.y + it.h then
            if it.w ~= it.h then
                SendContainerAction("rotate", { index = i, target_uid = self.containerUID })
                return true
            end
        end
    end
    return false
end

vgui.Register("ZScavContainer", CGRID, "Panel")

local CORPSE_VISIBLE_GEAR_SLOTS = {
    ears = true,
    helmet = true,
    face_cover = true,
    body_armor = true,
    tactical_rig = true,
    backpack = true,
}

local CORPSE_VISIBLE_WEAPON_SLOTS = {
    primary = true,
    secondary = true,
    sidearm = true,
    sidearm2 = true,
}

local CORPSE_SLOT_TITLES = {
    ears = "Earpiece",
    helmet = "Headwear",
    face_cover = "Face Cover",
    body_armor = "Body Armor",
    tactical_rig = "Tactical Rig",
    backpack = "Backpack",
    primary = "On Back",
    secondary = "On Sling",
    sidearm = "Holster 1",
    sidearm2 = "Holster 2",
}

local function IsCorpseContainerState(state)
    return istable(state) and tostring(state.class or "") == CORPSE_CONTAINER_CLASS
end

local function IsMailboxContainerState(state)
    return istable(state) and tostring(state.class or "") == MAILBOX_CONTAINER_CLASS
end

local function IsPlayerStashContainerState(state)
    return istable(state) and tostring(state.class or "") == STASH_CONTAINER_CLASS
end

local function HasEmbeddedRightPanelContainers()
    return tostring(ROOT_CONT_UID or "") ~= "" or tostring(SECONDARY_ROOT_CONT_UID or "") ~= ""
end

local function CanShareRightPanelStates(leftState, rightState)
    return (IsMailboxContainerState(leftState) and IsPlayerStashContainerState(rightState))
        or (IsPlayerStashContainerState(leftState) and IsMailboxContainerState(rightState))
end

local function ShouldEmbedSharedRightPanelState(uid, state)
    uid = tostring(uid or "")
    if uid == "" or not istable(state) then return false end

    local primaryUID = tostring(ROOT_CONT_UID or "")
    if primaryUID == "" or primaryUID == uid then return false end

    local primaryState = CONT_WINDOWS[primaryUID]
    return CanShareRightPanelStates(primaryState, state)
end

local function InvalidateRightPanelRootLayout()
    if not IsValid(PANEL_REF) then return end
    local host = PANEL_REF.zs_rightRootHost
    if IsValid(host) then
        host:InvalidateLayout(true)
    end
end

local function GetCorpseRightPanelMaxWidth()
    return math.max(1, math.floor(ScrW() * 0.5))
end

local function PrepareEmbeddedRightPanelPanel(panel, state, availableW)
    if not IsValid(panel) then return 0, 0 end

    availableW = math.max(1, math.floor(tonumber(availableW) or 1))

    if IsCorpseContainerState(state) then
        availableW = math.min(availableW, GetCorpseRightPanelMaxWidth())
        local layout = panel.BuildLayout and panel:BuildLayout(availableW) or nil
        panel:SetWide(availableW)
        if layout and tonumber(layout.totalH) then
            panel._layout = layout
            panel._lastTall = layout.totalH
            panel:SetTall(layout.totalH)
        end
    elseif panel.ResizeToContainer then
        panel:ResizeToContainer()
        if panel:GetWide() > availableW then
            panel:SetWide(availableW)
        end
    elseif panel:GetWide() > availableW then
        panel:SetWide(availableW)
    end

    return panel:GetSize()
end

local function GetEmbeddedRightPanelPanelNaturalWidth(panel, state)
    if IsCorpseContainerState(state) then
        return math.min(
            GetCorpseRightPanelMaxWidth(),
            math.max(1, math.floor(IsValid(panel) and panel:GetWide() or 0))
        )
    end

    local gw = math.max(1, math.floor(tonumber(state and state.gw) or 0))
    return gw * (CELL() + PAD()) + PAD() * 2
end

local function BuildRightPanelRootPanel(host, uid, data)
    if not IsValid(host) then return nil end

    local rootPanel
    if IsCorpseContainerState(data) then
        rootPanel = host:Add("ZScavCorpseLoot")
        rootPanel:SetContainerUID(uid)
    else
        rootPanel = host:Add("ZScavContainer")
        rootPanel.containerUID = uid
        rootPanel:ResizeToContainer()
    end

    if IsValid(rootPanel) then
        rootPanel.OnGridResize = function()
            if IsValid(host) then
                host:InvalidateLayout(true)
            end
        end
    end

    return rootPanel
end

local function SetEmbeddedRightPanelSlot(slotIndex, uid, data)
    if not IsValid(PANEL_REF) then return nil end

    local host = PANEL_REF.zs_rightRootHost
    if not IsValid(host) then return nil end

    local key = slotIndex == 1 and "zs_rootCont" or "zs_rootContSecondary"
    local existingPanel = PANEL_REF[key]
    if IsValid(existingPanel) then
        existingPanel:Remove()
    end

    local rootPanel = BuildRightPanelRootPanel(host, uid, data)
    PANEL_REF[key] = rootPanel
    if slotIndex == 1 then
        ROOT_CONT_UID = uid
    else
        SECONDARY_ROOT_CONT_UID = uid
    end

    return rootPanel
end

local function PromoteSecondaryRightPanelRoot()
    if not IsValid(PANEL_REF) then
        ROOT_CONT_UID = nil
        SECONDARY_ROOT_CONT_UID = nil
        return
    end

    if tostring(SECONDARY_ROOT_CONT_UID or "") == "" then return end

    ROOT_CONT_UID = SECONDARY_ROOT_CONT_UID
    SECONDARY_ROOT_CONT_UID = nil
    PANEL_REF.zs_rootCont = PANEL_REF.zs_rootContSecondary
    PANEL_REF.zs_rootContSecondary = nil
    InvalidateRightPanelRootLayout()
end

local function DropEmbeddedRightPanelSlot(slotIndex)
    if not IsValid(PANEL_REF) then return end

    local key = slotIndex == 1 and "zs_rootCont" or "zs_rootContSecondary"
    local uid = tostring((slotIndex == 1 and ROOT_CONT_UID or SECONDARY_ROOT_CONT_UID) or "")
    local panel = PANEL_REF[key]
    if IsValid(panel) then
        panel:Remove()
    end

    PANEL_REF[key] = nil
    if uid ~= "" then
        CONT_WINDOWS[uid] = nil
    end

    if slotIndex == 1 then
        ROOT_CONT_UID = nil
        if tostring(SECONDARY_ROOT_CONT_UID or "") ~= "" then
            PromoteSecondaryRightPanelRoot()
        end
    else
        SECONDARY_ROOT_CONT_UID = nil
        InvalidateRightPanelRootLayout()
    end
end

local function UpdateEmbeddedRightPanelState(uid, data)
    local entry = CONT_WINDOWS[uid]
    if not entry then return end

    entry.contents = data.contents
    entry.gw = data.gw
    entry.gh = data.gh
    entry.chain = data.chain
    entry.class = data.class
    entry.health_target_entindex = data.health_target_entindex
    entry.health_target_name = data.health_target_name

    local panel = nil
    if uid == ROOT_CONT_UID then
        panel = PANEL_REF and PANEL_REF.zs_rootCont or nil
    elseif uid == SECONDARY_ROOT_CONT_UID then
        panel = PANEL_REF and PANEL_REF.zs_rootContSecondary or nil
    end

    if IsValid(panel) and panel.ResizeToContainer then
        panel:ResizeToContainer()
    end
    InvalidateRightPanelRootLayout()
end

local function BuildCorpseEntryGroups(state)
    local groups = {
        gear = {},
        weapon = {},
        pockets = {},
        extra = {},
    }

    for index, entry in ipairs(state and state.contents or {}) do
        local wrapped = {
            index = index,
            entry = entry,
        }
        local kind = tostring(entry.corpse_slot_kind or "")
        local slotID = tostring(entry.corpse_slot_id or "")
        local section = tostring(entry.corpse_section or "")
        local addedExtra = false

        if (kind == "gear" or kind == "weapon") and slotID ~= "" then
            groups[kind][slotID] = wrapped

            local isKnown = (kind == "gear" and CORPSE_VISIBLE_GEAR_SLOTS[slotID])
                or (kind == "weapon" and CORPSE_VISIBLE_WEAPON_SLOTS[slotID])
            if section == "extra" or not isKnown then
                groups.extra[#groups.extra + 1] = wrapped
                addedExtra = true
            end
        end

        if section == "pocket" then
            groups.pockets[#groups.pockets + 1] = wrapped
        elseif not addedExtra and not ((kind == "gear" or kind == "weapon") and slotID ~= "") then
            groups.extra[#groups.extra + 1] = wrapped
        end
    end

    table.sort(groups.pockets, function(left, right)
        local leftY = tonumber(left.entry.corpse_grid_y) or 0
        local rightY = tonumber(right.entry.corpse_grid_y) or 0
        if leftY ~= rightY then
            return leftY < rightY
        end

        local leftX = tonumber(left.entry.corpse_grid_x) or 0
        local rightX = tonumber(right.entry.corpse_grid_x) or 0
        if leftX ~= rightX then
            return leftX < rightX
        end

        return tostring(left.entry.class or "") < tostring(right.entry.class or "")
    end)

    table.sort(groups.extra, function(left, right)
        return tostring(left.entry.class or "") < tostring(right.entry.class or "")
    end)

    return groups
end

local function DrawCorpseSilhouette(x, y, w, h)
    local col = Color(210, 220, 230, 14)
    local cx = x + w * 0.5
    local headW = Nexus:Scale(44)
    local headH = Nexus:Scale(44)
    local torsoW = Nexus:Scale(86)
    local torsoH = Nexus:Scale(122)
    local limbW = Nexus:Scale(18)
    local armH = Nexus:Scale(94)
    local legH = Nexus:Scale(108)

    draw.RoundedBox(R16(), cx - headW * 0.5, y + Nexus:Scale(26), headW, headH, col)
    draw.RoundedBox(R16(), cx - torsoW * 0.5, y + Nexus:Scale(74), torsoW, torsoH, col)
    draw.RoundedBox(R16(), cx - torsoW * 0.5 - Nexus:Scale(28), y + Nexus:Scale(92), limbW, armH, col)
    draw.RoundedBox(R16(), cx + torsoW * 0.5 + Nexus:Scale(10), y + Nexus:Scale(92), limbW, armH, col)
    draw.RoundedBox(R16(), cx - Nexus:Scale(28), y + Nexus:Scale(196), limbW, legH, col)
    draw.RoundedBox(R16(), cx + Nexus:Scale(10), y + Nexus:Scale(196), limbW, legH, col)
end

local function DrawCorpseEntryCard(x, y, w, h, wrapped, hovered, emptyText, detailText, compact)
    local bg = COL_SLOT()
    local border = COL_LINE()

    if wrapped and wrapped.entry and wrapped.entry.class then
        local entry = wrapped.entry
        bg = ZSCAV:IsGearItem(entry.class) and COL_GEAR() or COL_ITEM()
    end

    if hovered then
        bg = Color(
            math.min(bg.r + 14, 255),
            math.min(bg.g + 14, 255),
            math.min(bg.b + 14, 255),
            math.min(bg.a + 12, 255)
        )
    end

    draw.RoundedBox(R12(), x, y, w, h, bg)
    surface.SetDrawColor(border)
    surface.DrawOutlinedRect(x, y, w, h, 1)

    if not (wrapped and wrapped.entry and wrapped.entry.class) then
        draw.SimpleText(emptyText or "EMPTY", Nexus:GetFont(compact and 12 or 13), x + Nexus:Scale(8), y + h * 0.5, COL_DIM(), 0, 1)
        if detailText and detailText ~= "" then
            draw.SimpleText(detailText, Nexus:GetFont(11), x + Nexus:Scale(8), y + h - Nexus:Scale(8), COL_DIM(), 0, TEXT_ALIGN_BOTTOM)
        end
        return
    end

    local entry = wrapped.entry
    local nameFont = compact and Nexus:GetFont(12, nil, true) or Nexus:GetFont(13, nil, true)
    local nameChars = compact and math.max(7, math.floor(w / Nexus:Scale(10))) or math.max(10, math.floor(w / Nexus:Scale(10)))
    local displayName = TrimOverlayText(PrettyName(entry.class), nameChars)

    draw.SimpleText(displayName, nameFont, x + Nexus:Scale(8), y + Nexus:Scale(8), COL_TXT())
    ZSCAV_DrawMedicalCounterBadgeCL(entry, x, y, w, h)
    DrawVendorTicketBadgeCL(entry, x, y, w, h)

    if entry.uid and entry.uid ~= "" then
        draw.SimpleText("BAG", Nexus:GetFont(11, nil, true), x + w - Nexus:Scale(8), y + Nexus:Scale(8), Color(220, 200, 110), TEXT_ALIGN_RIGHT)
    end

    if detailText and detailText ~= "" then
        draw.SimpleText(detailText, Nexus:GetFont(11), x + Nexus:Scale(8), y + h - Nexus:Scale(8), COL_DIM(), 0, TEXT_ALIGN_BOTTOM)
    elseif compact then
        draw.SimpleText(string.format("%dx%d", tonumber(entry.w) or 1, tonumber(entry.h) or 1), Nexus:GetFont(10), x + w - Nexus:Scale(6), y + h - Nexus:Scale(6), COL_DIM(), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    end

    if not compact and w >= Nexus:Scale(92) and h >= Nexus:Scale(52) then
        DrawWeaponAttachmentOverlay(entry, x + Nexus:Scale(6), y + Nexus:Scale(6), w - Nexus:Scale(12), h - Nexus:Scale(12))
    end
end

local CORPSEVIEW = {}

function CORPSEVIEW:Init()
    self.containerUID = ""
    self._layout = nil
    self._lastTall = 0
    self:SetMouseInputEnabled(true)
end

function CORPSEVIEW:GetState()
    return CONT_WINDOWS[self.containerUID]
end

function CORPSEVIEW:SetContainerUID(uid)
    self.containerUID = tostring(uid or "")
    self._layout = nil
end

function CORPSEVIEW:BuildLayout(w)
    local state = self:GetState()
    local groups = BuildCorpseEntryGroups(state)
    local layout = {
        slots = {},
        sections = {},
        pocketCells = {},
        pocketItems = {},
        extraCards = {},
        hitEntries = {},
    }

    local pad = Nexus:Scale(12)
    local gap = Nexus:Scale(10)
    local labelH = Nexus:Scale(18)
    local bodyX = pad
    local bodyY = pad
    local bodyW = math.max(0, w - pad * 2)
    local smallH = Nexus:Scale(58)
    local weaponH = Nexus:Scale(72)
    local rowY = bodyY + Nexus:Scale(26)
    local thirdW = math.max(Nexus:Scale(86), math.floor((bodyW - gap * 2) / 3))
    local bodyArmorW = math.max(Nexus:Scale(132), math.floor(bodyW * 0.48))
    local weaponLeftW = math.max(Nexus:Scale(162), math.floor((bodyW - gap) * 0.66))
    local weaponRightW = math.max(Nexus:Scale(92), bodyW - gap - weaponLeftW)

    local function addHitbox(x, y, cardW, cardH, wrapped)
        if not wrapped then return end
        layout.hitEntries[#layout.hitEntries + 1] = {
            x = x,
            y = y,
            w = cardW,
            h = cardH,
            index = wrapped.index,
            entry = wrapped.entry,
        }
    end

    local function addSlot(kind, slotID, x, y, cardW, cardH)
        local wrapped = groups[kind][slotID]
        local slot = {
            title = CORPSE_SLOT_TITLES[slotID] or PrettyName(slotID),
            x = x,
            y = y,
            w = cardW,
            h = cardH,
            wrapped = wrapped,
        }
        layout.slots[#layout.slots + 1] = slot
        addHitbox(x, y + labelH, cardW, cardH, wrapped)
    end

    addSlot("gear", "ears", bodyX, rowY, thirdW, smallH)
    addSlot("gear", "helmet", bodyX + thirdW + gap, rowY, thirdW, smallH)
    addSlot("gear", "face_cover", bodyX + (thirdW + gap) * 2, rowY, thirdW, smallH)

    local armorY = rowY + labelH + smallH + gap
    addSlot("gear", "body_armor", bodyX + math.floor((bodyW - bodyArmorW) * 0.5), armorY, bodyArmorW, smallH)

    local weaponRow1Y = armorY + labelH + smallH + gap
    addSlot("weapon", "secondary", bodyX, weaponRow1Y, weaponLeftW, weaponH)
    addSlot("weapon", "sidearm", bodyX + weaponLeftW + gap, weaponRow1Y, weaponRightW, weaponH)

    local weaponRow2Y = weaponRow1Y + labelH + weaponH + gap
    addSlot("weapon", "primary", bodyX, weaponRow2Y, weaponLeftW, weaponH)
    addSlot("weapon", "sidearm2", bodyX + weaponLeftW + gap, weaponRow2Y, weaponRightW, weaponH)

    layout.bodyBox = {
        x = bodyX,
        y = bodyY,
        w = bodyW,
        h = weaponRow2Y + labelH + weaponH + pad - bodyY,
    }

    local sectionY = layout.bodyBox.y + layout.bodyBox.h + Nexus:Scale(16)

    local function addSectionCard(title, slotID, emptyText)
        local wrapped = groups.gear[slotID]
        local detail = nil
        if wrapped and wrapped.entry and wrapped.entry.uid and wrapped.entry.uid ~= "" then
            local openState = ZSCAV.GetOpenContainerState and ZSCAV.GetOpenContainerState(wrapped.entry.uid) or nil
            if openState then
                detail = "Storage open in floating window"
            else
                detail = "Right-click to open storage"
            end
        end

        layout.sections[#layout.sections + 1] = {
            title = title,
            x = bodyX,
            y = sectionY,
            w = bodyW,
            h = Nexus:Scale(74),
            wrapped = wrapped,
            emptyText = emptyText,
            detail = detail,
        }
        addHitbox(bodyX, sectionY + labelH, bodyW, Nexus:Scale(74), wrapped)
        sectionY = sectionY + labelH + Nexus:Scale(74) + Nexus:Scale(14)
    end

    addSectionCard("TACTICAL RIG", "tactical_rig", "EMPTY")

    local pocketCols = 4
    local pocketGap = Nexus:Scale(6)
    local pocketCell = math.max(Nexus:Scale(44), math.floor((bodyW - pocketGap * (pocketCols - 1)) / pocketCols))
    local pocketGridY = sectionY + labelH
    local pocketRows = 1

    for row = 0, pocketRows - 1 do
        for col = 0, pocketCols - 1 do
            layout.pocketCells[#layout.pocketCells + 1] = {
                x = bodyX + col * (pocketCell + pocketGap),
                y = pocketGridY + row * (pocketCell + pocketGap),
                w = pocketCell,
                h = pocketCell,
            }
        end
    end

    for _, wrapped in ipairs(groups.pockets) do
        local entry = wrapped.entry
        local gx = math.max(0, tonumber(entry.corpse_grid_x) or 0)
        local gy = math.max(0, tonumber(entry.corpse_grid_y) or 0)
        local gw = math.max(1, tonumber(entry.w) or 1)
        local gh = math.max(1, tonumber(entry.h) or 1)
        local itemX = bodyX + gx * (pocketCell + pocketGap)
        local itemY = pocketGridY + gy * (pocketCell + pocketGap)
        local itemW = gw * (pocketCell + pocketGap) - pocketGap
        local itemH = gh * (pocketCell + pocketGap) - pocketGap

        pocketRows = math.max(pocketRows, gy + gh)
        layout.pocketItems[#layout.pocketItems + 1] = {
            x = itemX,
            y = itemY,
            w = itemW,
            h = itemH,
            wrapped = wrapped,
        }
        addHitbox(itemX, itemY, itemW, itemH, wrapped)
    end

    layout.pocketBox = {
        title = "POCKETS",
        x = bodyX,
        y = sectionY,
        w = bodyW,
        rows = pocketRows,
        cell = pocketCell,
        gap = pocketGap,
        gridY = pocketGridY,
    }

    sectionY = pocketGridY + pocketRows * (pocketCell + pocketGap) - pocketGap + Nexus:Scale(14)

    addSectionCard("BACKPACK", "backpack", "EMPTY")

    if #groups.extra > 0 then
        local cardGap = Nexus:Scale(8)
        local cardW = math.max(Nexus:Scale(120), math.floor((bodyW - cardGap) / 2))
        local cardH = Nexus:Scale(66)

        layout.extraTitle = {
            title = "ADDITIONAL LOOT",
            x = bodyX,
            y = sectionY,
        }

        for extraIndex, wrapped in ipairs(groups.extra) do
            local col = (extraIndex - 1) % 2
            local row = math.floor((extraIndex - 1) / 2)
            local cardX = bodyX + col * (cardW + cardGap)
            local cardY = sectionY + labelH + row * (cardH + cardGap)
            layout.extraCards[#layout.extraCards + 1] = {
                x = cardX,
                y = cardY,
                w = cardW,
                h = cardH,
                wrapped = wrapped,
            }
            addHitbox(cardX, cardY, cardW, cardH, wrapped)
        end

        local extraRows = math.ceil(#groups.extra / 2)
        sectionY = sectionY + labelH + extraRows * (cardH + cardGap) - cardGap + Nexus:Scale(12)
    end

    layout.totalH = sectionY + pad
    return layout
end

function CORPSEVIEW:Think()
    if self:GetWide() <= 0 then return end
    self._layout = self:BuildLayout(self:GetWide())
    if self._layout and self._layout.totalH ~= self._lastTall then
        self._lastTall = self._layout.totalH
        self:SetTall(self._layout.totalH)
        local parent = self:GetParent()
        if IsValid(parent) and parent.InvalidateLayout then
            parent:InvalidateLayout(true)
        end
    end
end

function CORPSEVIEW:Paint(w, h)
    local st = self:GetState()
    if not st then
        draw.SimpleText("(loading corpse loot...)", Nexus:GetFont(14), Nexus:Scale(8), Nexus:Scale(8), COL_DIM())
        return
    end

    local layout = self._layout or self:BuildLayout(w)
    self._layout = layout

    local mx, my = self:CursorPos()
    local hoveredIndex = nil
    if self:IsHovered() then
        for hitIndex = #layout.hitEntries, 1, -1 do
            local hit = layout.hitEntries[hitIndex]
            if mx >= hit.x and mx <= hit.x + hit.w and my >= hit.y and my <= hit.y + hit.h then
                hoveredIndex = hit.index
                break
            end
        end
    end

    draw.RoundedBox(R12(), 0, 0, w, h, Color(20, 24, 28, 70))

    if layout.bodyBox then
        draw.RoundedBox(R12(), layout.bodyBox.x, layout.bodyBox.y, layout.bodyBox.w, layout.bodyBox.h, Color(18, 21, 25, 160))
        draw.SimpleText("BODY", Nexus:GetFont(16, nil, true), layout.bodyBox.x, layout.bodyBox.y + Nexus:Scale(6), COL_TXT())
        DrawCorpseSilhouette(layout.bodyBox.x, layout.bodyBox.y + Nexus:Scale(8), layout.bodyBox.w, layout.bodyBox.h - Nexus:Scale(16))
    end

    for _, slot in ipairs(layout.slots or {}) do
        local cardY = slot.y + Nexus:Scale(18)
        draw.SimpleText(string.upper(slot.title), Nexus:GetFont(12, nil, true), slot.x, slot.y, COL_TXT())
        DrawCorpseEntryCard(slot.x, cardY, slot.w, slot.h, slot.wrapped, hoveredIndex == (slot.wrapped and slot.wrapped.index or nil), "EMPTY", nil, false)
    end

    for _, section in ipairs(layout.sections or {}) do
        local cardY = section.y + Nexus:Scale(18)
        draw.SimpleText(section.title, Nexus:GetFont(13, nil, true), section.x, section.y, COL_TXT())
        DrawCorpseEntryCard(section.x, cardY, section.w, section.h, section.wrapped, hoveredIndex == (section.wrapped and section.wrapped.index or nil), section.emptyText or "EMPTY", section.detail, false)
    end

    if layout.pocketBox then
        draw.SimpleText(layout.pocketBox.title, Nexus:GetFont(13, nil, true), layout.pocketBox.x, layout.pocketBox.y, COL_TXT())
        for cellIndex = 1, math.max(4, (layout.pocketBox.rows or 1) * 4) do
            local row = math.floor((cellIndex - 1) / 4)
            local col = (cellIndex - 1) % 4
            local cellX = layout.pocketBox.x + col * (layout.pocketBox.cell + layout.pocketBox.gap)
            local cellY = layout.pocketBox.gridY + row * (layout.pocketBox.cell + layout.pocketBox.gap)
            draw.RoundedBox(R8(), cellX, cellY, layout.pocketBox.cell, layout.pocketBox.cell, COL_SLOT())
            surface.SetDrawColor(COL_LINE())
            surface.DrawOutlinedRect(cellX, cellY, layout.pocketBox.cell, layout.pocketBox.cell, 1)
        end

        for _, item in ipairs(layout.pocketItems or {}) do
            DrawCorpseEntryCard(item.x, item.y, item.w, item.h, item.wrapped, hoveredIndex == (item.wrapped and item.wrapped.index or nil), "EMPTY", nil, true)
        end
    end

    if layout.extraTitle then
        draw.SimpleText(layout.extraTitle.title, Nexus:GetFont(13, nil, true), layout.extraTitle.x, layout.extraTitle.y, COL_TXT())
    end
    for _, extraCard in ipairs(layout.extraCards or {}) do
        DrawCorpseEntryCard(extraCard.x, extraCard.y, extraCard.w, extraCard.h, extraCard.wrapped, hoveredIndex == (extraCard.wrapped and extraCard.wrapped.index or nil), "EMPTY", nil, false)
    end
end

function CORPSEVIEW:OnMousePressed(code)
    if code ~= MOUSE_LEFT and code ~= MOUSE_RIGHT then return end

    local layout = self._layout or self:BuildLayout(self:GetWide())
    self._layout = layout

    local mx, my = self:CursorPos()
    local hit = nil
    for hitIndex = #layout.hitEntries, 1, -1 do
        local candidate = layout.hitEntries[hitIndex]
        if mx >= candidate.x and mx <= candidate.x + candidate.w and my >= candidate.y and my <= candidate.y + candidate.h then
            hit = candidate
            break
        end
    end
    if not hit then return end

    if code == MOUSE_RIGHT then
        OpenContainerEntryContextMenu(self.containerUID, hit.index, hit.entry)
        return
    end

    HandleContainerEntryPrimaryClick(self, self.containerUID, hit.index, hit.entry, mx, my, hit.x, hit.y)
end

function CORPSEVIEW:HandleZScavDrop(drag, screenX, screenY)
    if not drag then return false end

    local lx, ly = self:ScreenToLocal(screenX, screenY)
    if lx < 0 or ly < 0 or lx > self:GetWide() or ly > self:GetTall() then
        return false
    end

    if drag.fromSlot then
        SendContainerAction("quick_move_slot_to_container", {
            kind = drag.slotKind,
            slot = drag.slotID,
            target_uid = self.containerUID,
        })
        return true
    end

    if drag.fromContainer then
        if drag.fromContainerUID == self.containerUID then
            return false
        end

        SendContainerAction("quick_transfer_to_container", {
            from_uid = drag.fromContainerUID,
            from_index = drag.fromIndex,
            target_uid = self.containerUID,
        })
        return true
    end

    SendContainerAction("quick_put_from_grid", {
        from_grid = drag.fromGrid,
        from_index = drag.fromIndex,
        target_uid = self.containerUID,
        rotated = drag.rotated and true or false,
    })
    return true
end

vgui.Register("ZScavCorpseLoot", CORPSEVIEW, "Panel")

-- ---------------------------------------------------------------------
-- Floating bag window builder.
-- Creates a draggable window (child of root) for a specific container uid.
-- ---------------------------------------------------------------------
local WINDOW_CASCADE_STEP = 28  -- px offset per window for cascading
local WINDOW_TITLE_H = 32

local function CreateContainerWindow(root, uid, data)
    if not IsValid(root) then return end

    -- Close any existing window for this uid first.
    local existing = CONT_WINDOWS[uid] and CONT_WINDOWS[uid].panel
    if IsValid(existing) then existing:Remove() end

    CONT_WINDOWS[uid] = data

    local gw = math.max(tonumber(data.gw) or 1, 1)
    local gh = math.max(tonumber(data.gh) or 1, 1)
    local gridW = gw * (CELL() + PAD()) + PAD() * 2
    local gridH = gh * (CELL() + PAD()) + PAD() * 2

    local winW = gridW + Nexus:Scale(4)
    local winH = gridH + WINDOW_TITLE_H + Nexus:Scale(4)

    -- Cascade position based on number of open windows.
    local openCount = 0
    for _ in pairs(CONT_WINDOWS) do openCount = openCount + 1 end
    local startX = ScrW() - winW - Nexus:Scale(20)
    local startY = Nexus:Scale(80)
    local ox = (openCount - 1) * WINDOW_CASCADE_STEP
    local oy = (openCount - 1) * WINDOW_CASCADE_STEP
    local winX = math.max(0, math.min(startX - ox, ScrW() - winW))
    local winY = math.max(0, math.min(startY + oy, ScrH() - winH))

    if IsTraderTradeActive() and tostring(TRADER_TRADE_STATE.player_offer_uid or "") == uid then
        local shell = IsValid(PANEL_REF) and PANEL_REF.zs_shell or nil
        if IsValid(shell) then
            local sx, sy = shell:LocalToScreen(0, 0)
            winX = math.Clamp(sx + math.floor((shell:GetWide() - winW) * 0.5), 0, ScrW() - winW)
            winY = math.Clamp(sy + math.floor((shell:GetTall() - winH) * 0.20), 0, ScrH() - winH)
        end
    end

    local win = root:Add("DPanel")
    win:SetPos(winX, winY)
    win:SetSize(winW, winH)
    win:SetMouseInputEnabled(true)
    win._dragOffX = nil
    win._dragOffY = nil
    win._draggingWin = false

    win.Paint = function(_, w, h)
        draw.RoundedBox(R12(), 0, 0, w, h, Color(18, 22, 28, 220))
        surface.SetDrawColor(Color(80, 100, 130, 200))
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        -- Title bar background
        draw.RoundedBoxEx(R8(), 0, 0, w, WINDOW_TITLE_H, Color(28, 36, 50, 220), true, true, false, false)
        local title = PrettyName(data.class) .. "  " .. gw .. "×" .. gh
        draw.SimpleText(title, Nexus:GetFont(15, nil, true), Nexus:Scale(10), WINDOW_TITLE_H / 2, COL_TXT(), 0, 1)
    end

    -- Title bar drag logic.
    win.OnMousePressed = function(self2, code)
        self2:MoveToFront()  -- bring to front on any click
        if code == MOUSE_LEFT then
            local mx, my = self2:CursorPos()
            if my <= WINDOW_TITLE_H then
                self2._draggingWin = true
                self2._dragOffX, self2._dragOffY = mx, my
            end
        end
    end
    win.OnMouseReleased = function(self2, code)
        if code == MOUSE_LEFT then self2._draggingWin = false end
    end
    win.Think = function(self2)
        if self2._draggingWin then
            local mx, my = input.GetCursorPos()
            local nx = math.Clamp(mx - self2._dragOffX, 0, ScrW() - self2:GetWide())
            local ny = math.Clamp(my - self2._dragOffY, 0, ScrH() - self2:GetTall())
            self2:SetPos(nx, ny)
        end
    end
    win.OnGridResize = function(self2)
        local st = CONT_WINDOWS[uid]
        if not st then return end
        local newGW = math.max(tonumber(st.gw) or 1, 1)
        local newGH = math.max(tonumber(st.gh) or 1, 1)
        local newGridW = newGW * (CELL() + PAD()) + PAD() * 2
        local newGridH = newGH * (CELL() + PAD()) + PAD() * 2
        local newWinW = newGridW + Nexus:Scale(4)
        local newWinH = newGridH + WINDOW_TITLE_H + Nexus:Scale(4)
        self2:SetSize(newWinW, newWinH)
        gw, gh = newGW, newGH
        gridW, gridH = newGridW, newGridH
        winW, winH = newWinW, newWinH
    end

    -- Close [X] button.
    local btnClose = win:Add("Nexus:Button")
    btnClose:SetText("✕")
    btnClose:SetSize(Nexus:Scale(26), Nexus:Scale(22))
    btnClose:SetPos(winW - Nexus:Scale(30), (WINDOW_TITLE_H - Nexus:Scale(22)) / 2)
    btnClose.DoClick = function()
        if IsTraderTradeActive() and tostring(TRADER_TRADE_STATE.player_offer_uid or "") == uid then
            SendTraderTradeAction("cancel", {})
            return
        end

        SendContainerAction("close_window", { uid = uid })
    end

    -- The CGRID inside.
    local cg = win:Add("ZScavContainer")
    cg.containerUID = uid
    cg:SetPos(Nexus:Scale(2), WINDOW_TITLE_H)
    cg:ResizeToContainer()

    CONT_WINDOWS[uid].panel = win
end

local function ClearRightPanelContainer()
    if not IsValid(PANEL_REF) then return end

    local primaryUID = tostring(ROOT_CONT_UID or "")
    local secondaryUID = tostring(SECONDARY_ROOT_CONT_UID or "")

    local cg = PANEL_REF.zs_rootCont
    if IsValid(cg) then cg:Remove() end
    local secondary = PANEL_REF.zs_rootContSecondary
    if IsValid(secondary) then secondary:Remove() end

    PANEL_REF.zs_rootCont = nil
    PANEL_REF.zs_rootContSecondary = nil
    ROOT_CONT_UID = nil
    SECONDARY_ROOT_CONT_UID = nil

    if primaryUID ~= "" then
        CONT_WINDOWS[primaryUID] = nil
    end
    if secondaryUID ~= "" then
        CONT_WINDOWS[secondaryUID] = nil
    end

    if IsValid(PANEL_REF.zs_rightScroll) then PANEL_REF.zs_rightScroll:SetVisible(false) end
    if IsValid(PANEL_REF.zs_rightHint)  then PANEL_REF.zs_rightHint:SetVisible(true)   end
    UpdateTraderTradeUI()
end

local function CloseContainerWindow(uid)
    if uid and uid ~= "" then
        local entry = CONT_WINDOWS[uid]
        if entry then
            if IsValid(entry.panel) then
                entry.panel:Remove()  -- floating window
                CONT_WINDOWS[uid] = nil
            elseif uid == ROOT_CONT_UID then
                DropEmbeddedRightPanelSlot(1)
            elseif uid == SECONDARY_ROOT_CONT_UID then
                DropEmbeddedRightPanelSlot(2)
            else
                CONT_WINDOWS[uid] = nil
            end

            if not HasEmbeddedRightPanelContainers() and IsValid(PANEL_REF) then
                if IsValid(PANEL_REF.zs_rightScroll) then PANEL_REF.zs_rightScroll:SetVisible(false) end
                if IsValid(PANEL_REF.zs_rightHint) then PANEL_REF.zs_rightHint:SetVisible(true) end
            end
            UpdateTraderTradeUI()
        end
    else
        -- Close all: floating windows + right panel root.
        for id, entry in pairs(CONT_WINDOWS) do
            if IsValid(entry.panel) then entry.panel:Remove() end
            CONT_WINDOWS[id] = nil
        end
        ClearRightPanelContainer()
    end
end

-- Show a container as the scrollable root in the right panel.
local function SetRightPanelContainer(uid, data)
    if not IsValid(PANEL_REF) then return end
    local scroll = PANEL_REF.zs_rightScroll
    local hint   = PANEL_REF.zs_rightHint
    if not (IsValid(scroll) and IsValid(hint)) then return end

    if (ROOT_CONT_UID == uid or SECONDARY_ROOT_CONT_UID == uid) and CONT_WINDOWS[uid] then
        UpdateEmbeddedRightPanelState(uid, data)
        return
    end

    local primaryUID = tostring(ROOT_CONT_UID or "")
    local secondaryUID = tostring(SECONDARY_ROOT_CONT_UID or "")
    local primaryState = primaryUID ~= "" and CONT_WINDOWS[primaryUID] or nil
    local secondaryState = secondaryUID ~= "" and CONT_WINDOWS[secondaryUID] or nil

    local shouldShareWithPrimary = primaryUID ~= ""
        and secondaryUID == ""
        and CanShareRightPanelStates(primaryState, data)

    if shouldShareWithPrimary then
        CONT_WINDOWS[uid] = data

        if IsPlayerStashContainerState(data) and IsMailboxContainerState(primaryState) then
            local mailboxUID = primaryUID
            local mailboxState = primaryState
            local oldPrimary = PANEL_REF.zs_rootCont
            if IsValid(oldPrimary) then oldPrimary:Remove() end
            PANEL_REF.zs_rootCont = nil
            ROOT_CONT_UID = nil

            SetEmbeddedRightPanelSlot(1, uid, data)
            SetEmbeddedRightPanelSlot(2, mailboxUID, mailboxState)
        else
            SetEmbeddedRightPanelSlot(2, uid, data)
        end

        scroll:SetVisible(true)
        hint:SetVisible(false)
        InvalidateRightPanelRootLayout()
        UpdateTraderTradeUI()
        return
    end

    if secondaryState and not (secondaryUID == uid) then
        ClearRightPanelContainer()
    elseif primaryUID ~= "" and not CanShareRightPanelStates(primaryState, data) then
        ClearRightPanelContainer()
    end

    CONT_WINDOWS[uid] = data
    SetEmbeddedRightPanelSlot(1, uid, data)

    scroll:SetVisible(true)
    hint:SetVisible(false)
    InvalidateRightPanelRootLayout()
    UpdateTraderTradeUI()
end

IsTraderTradeActive = function()
    return istable(TRADER_TRADE_STATE)
        and TRADER_TRADE_STATE.closed ~= true
        and tostring(TRADER_TRADE_STATE.player_offer_uid or "") ~= ""
end

local function RebuildTraderTradeOfferPanel(scroll)
    if not IsValid(scroll) then return end

    local canvas = scroll:GetCanvas()
    if not IsValid(canvas) then return end
    canvas:Clear()

    if not IsTraderTradeActive() then return end

    local state = TRADER_TRADE_STATE
    local requiredItems = istable(state.required_player_items) and state.required_player_items or {}
    local hasRequiredItems = #requiredItems > 0
    local cooldownAfterUse = math.max(0, math.floor(tonumber(state.preset_cooldown_seconds) or 0))

    local function formatTradeCooldown(seconds)
        seconds = math.max(0, math.floor(tonumber(seconds) or 0))
        if seconds <= 0 then return nil end
        if string.NiceTime then
            return string.NiceTime(seconds)
        end
        return tostring(seconds) .. "s"
    end

    local function summarizeRequiredItems(entries)
        local parts = {}

        for index, entry in ipairs(entries or {}) do
            local count = math.max(1, math.floor(tonumber(entry.count) or 1))
            parts[#parts + 1] = string.format("%dx %s", count, PrettyName(entry.class))
            if index >= 3 then
                break
            end
        end

        if #parts <= 0 then
            return "No required payment"
        end

        local extra = math.max(0, #(entries or {}) - #parts)
        local summary = table.concat(parts, ", ")
        if extra > 0 then
            summary = summary .. string.format(", +%d more", extra)
        end
        return summary
    end

    local function addTradeCard(entry, options)
        options = options or {}

        local card = canvas:Add("DPanel")
        card:Dock(TOP)
        card:SetTall(Nexus:Scale(64))
        card:DockMargin(Nexus:Scale(6), 0, Nexus:Scale(6), Nexus:Scale(6))
        card.Paint = function(_, w, h)
            local accent = options.accent or (ZSCAV.GetGearDef and ZSCAV:GetGearDef(entry.class) and COL_GEAR() or COL_ITEM())
            local badgeText = tostring(options.badgeText or string.format("%dx%d", tonumber(entry.w) or 1, tonumber(entry.h) or 1))
            draw.RoundedBox(R10(), 0, 0, w, h, COL_PANEL())
            draw.RoundedBox(R8(), Nexus:Scale(8), Nexus:Scale(8), Nexus:Scale(48), h - Nexus:Scale(16), accent)
            draw.SimpleText(tostring(options.title or PrettyName(entry.class)), Nexus:GetFont(15, nil, true), Nexus:Scale(66), Nexus:Scale(14), COL_TXT())
            draw.SimpleText(tostring(options.subtitle or string.upper(tostring(entry.class or ""))), Nexus:GetFont(11), Nexus:Scale(66), h - Nexus:Scale(14), COL_DIM(), 0, TEXT_ALIGN_BOTTOM)
            draw.SimpleText(badgeText, Nexus:GetFont(12, nil, true), w - Nexus:Scale(10), Nexus:Scale(14), COL_DIM(), TEXT_ALIGN_RIGHT)
            ZSCAV_DrawMedicalCounterBadgeCL(entry, Nexus:Scale(8), Nexus:Scale(8), Nexus:Scale(48), h - Nexus:Scale(16), {
                font = Nexus:GetFont(10, nil, true),
                marginX = Nexus:Scale(4),
                marginY = Nexus:Scale(20),
            })
        end
    end

    local intro = canvas:Add("DPanel")
    intro:Dock(TOP)
    intro:SetTall(hasRequiredItems and Nexus:Scale(108) or Nexus:Scale(82))
    intro:DockMargin(Nexus:Scale(6), Nexus:Scale(6), Nexus:Scale(6), Nexus:Scale(8))
    intro.Paint = function(_, w, h)
        local title = tostring(state.active_preset_name or "") ~= "" and tostring(state.active_preset_name) or tostring(state.trader_name or "Trader Offer")
        local statusText = tostring(state.required_offer_message or "")
        if statusText == "" then
            statusText = state.player_ready and "Trade marked ready. Any basket change will unset it."
                or "Place your payment in the centered trade basket, then mark ready."
        end

        local footer = string.format("Listed items: %d", #(state.trader_items or {}))
        local cooldownText = formatTradeCooldown(cooldownAfterUse)
        if cooldownText then
            footer = footer .. " | Cooldown after trade: " .. cooldownText
        end

        draw.RoundedBox(R10(), 0, 0, w, h, COL_PANEL())
        draw.SimpleText(title, Nexus:GetFont(16, nil, true), Nexus:Scale(10), Nexus:Scale(10), COL_TXT())
        draw.SimpleText(statusText, Nexus:GetFont(12), Nexus:Scale(10), Nexus:Scale(34), COL_DIM())
        if hasRequiredItems then
            local summaryColor = state.required_offer_ok and COL_TXT() or Color(220, 190, 130)
            draw.SimpleText("Required payment: " .. summarizeRequiredItems(requiredItems), Nexus:GetFont(11), Nexus:Scale(10), Nexus:Scale(56), summaryColor)
        end
        draw.SimpleText(footer, Nexus:GetFont(12, nil, true), Nexus:Scale(10), h - Nexus:Scale(12), COL_DIM(), 0, TEXT_ALIGN_BOTTOM)
    end

    if hasRequiredItems then
        local requiredLabel = canvas:Add("DPanel")
        requiredLabel:Dock(TOP)
        requiredLabel:SetTall(Nexus:Scale(22))
        requiredLabel:DockMargin(Nexus:Scale(6), 0, Nexus:Scale(6), Nexus:Scale(4))
        requiredLabel.Paint = function(_, w, h)
            draw.SimpleText("REQUIRED PAYMENT", Nexus:GetFont(12, nil, true), 0, h * 0.5, COL_TXT(), 0, 1)
        end

        for _, entry in ipairs(requiredItems) do
            local count = math.max(1, math.floor(tonumber(entry.count) or 1))
            addTradeCard(entry, {
                title = PrettyName(entry.class),
                subtitle = "PLAYER PAYS",
                badgeText = "x" .. tostring(count),
                accent = Color(116, 90, 58, 220),
            })
        end
    end

    if #(state.trader_items or {}) <= 0 then
        local empty = canvas:Add("DPanel")
        empty:Dock(TOP)
        empty:SetTall(Nexus:Scale(64))
        empty:DockMargin(Nexus:Scale(6), 0, Nexus:Scale(6), Nexus:Scale(6))
        empty.Paint = function(_, w, h)
            draw.RoundedBox(R10(), 0, 0, w, h, COL_PANEL())
            draw.SimpleText("Trader has not listed any items yet.", Nexus:GetFont(14, nil, true), w * 0.5, h * 0.5, COL_DIM(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        return
    end

    if hasRequiredItems then
        local rewardLabel = canvas:Add("DPanel")
        rewardLabel:Dock(TOP)
        rewardLabel:SetTall(Nexus:Scale(22))
        rewardLabel:DockMargin(Nexus:Scale(6), 0, Nexus:Scale(6), Nexus:Scale(4))
        rewardLabel.Paint = function(_, w, h)
            draw.SimpleText("TRADER REWARD", Nexus:GetFont(12, nil, true), 0, h * 0.5, COL_TXT(), 0, 1)
        end
    end

    for _, entry in ipairs(state.trader_items or {}) do
        addTradeCard(entry)
    end
end

UpdateTraderTradeUI = function()
    if not IsValid(PANEL_REF) then return end

    local rightHint = PANEL_REF.zs_rightHint
    local rightScroll = PANEL_REF.zs_rightScroll
    local tradeScroll = PANEL_REF.zs_tradeOfferScroll
    local readyButton = PANEL_REF.zs_tradeReadyButton
    local cancelButton = PANEL_REF.zs_tradeCancelButton
    local tradeActive = IsTraderTradeActive()

    if IsValid(readyButton) then
        readyButton:SetVisible(tradeActive)
        readyButton:SetText(tradeActive and (TRADER_TRADE_STATE.player_ready and "UNREADY" or "READY TRADE") or "READY TRADE")
        readyButton:SetColor(tradeActive and (TRADER_TRADE_STATE.player_ready and Nexus.Colors.Primary or Nexus.Colors.Secondary) or Nexus.Colors.Secondary)
    end

    if IsValid(cancelButton) then
        cancelButton:SetVisible(tradeActive)
        cancelButton:SetColor(Nexus.Colors.Secondary)
    end

    if not IsValid(tradeScroll) then return end

    if tradeActive then
        if IsValid(rightScroll) then rightScroll:SetVisible(false) end
        if IsValid(rightHint) then rightHint:SetVisible(false) end
        tradeScroll:SetVisible(true)
        RebuildTraderTradeOfferPanel(tradeScroll)
        return
    end

    tradeScroll:SetVisible(false)
    if HasEmbeddedRightPanelContainers() and IsValid(rightScroll) then
        rightScroll:SetVisible(true)
        if IsValid(rightHint) then rightHint:SetVisible(false) end
    else
        if IsValid(rightScroll) then rightScroll:SetVisible(false) end
        if IsValid(rightHint) then rightHint:SetVisible(true) end
    end
end

-- ---------------------------------------------------------------------
-- Equip slot tile
-- ---------------------------------------------------------------------
local SLOT = {}

local function _slotRectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    if ax + aw <= bx or bx + bw <= ax then return false end
    if ay + ah <= by or by + bh <= ay then return false end
    return true
end

local function _slotRectInsideAnyBlock(x, y, w, h, blocks)
    if not blocks then return true end
    for _, b in ipairs(blocks) do
        if x >= b.x and y >= b.y and (x + w) <= (b.x + b.w) and (y + h) <= (b.y + b.h) then
            return true
        end
    end
    return false
end

local function _slotFitsAt(list, x, y, iw, ih, gw, gh, ignoreIdx, layoutBlocks)
    if x < 0 or y < 0 then return false end
    if x + iw > gw or y + ih > gh then return false end
    if layoutBlocks and #layoutBlocks > 0 and not _slotRectInsideAnyBlock(x, y, iw, ih, layoutBlocks) then
        return false
    end
    for i, it in ipairs(list or {}) do
        if i ~= ignoreIdx and _slotRectsOverlap(x, y, iw, ih, it.x, it.y, it.w, it.h) then
            return false
        end
    end
    return true
end

local function _slotCanFindRoom(list, gw, gh, iw, ih, ignoreIdx, layoutBlocks)
    if iw > gw or ih > gh or gw <= 0 or gh <= 0 then return false end
    for y = 0, gh - ih do
        for x = 0, gw - iw do
            if _slotFitsAt(list, x, y, iw, ih, gw, gh, ignoreIdx, layoutBlocks) then
                return true
            end
        end
    end
    return false
end

local function _slotCanFindRoomAR(list, gw, gh, iw, ih, ignoreIdx, layoutBlocks)
    if _slotCanFindRoom(list, gw, gh, iw, ih, ignoreIdx, layoutBlocks) then return true end
    if iw ~= ih and _slotCanFindRoom(list, gw, gh, ih, iw, ignoreIdx, layoutBlocks) then return true end
    return false
end

local function _slotGetVestLayoutBlocks(inv, gw, gh)
    local out = {}
    local src = inv and inv._vestLayoutBlocks
    if not (istable(src) and #src > 0) then
        local rig = inv and inv.gear and (inv.gear.tactical_rig or inv.gear.vest)
        local def = rig and rig.class and ZSCAV:GetGearDef(rig.class)
        src = def and def.layoutBlocks or nil
    end
    if not (istable(src) and #src > 0) then return nil end

    for _, b in ipairs(src) do
        local bx = math.max(0, math.floor(tonumber(b.x) or 0))
        local by = math.max(0, math.floor(tonumber(b.y) or 0))
        local bw = math.max(1, math.floor(tonumber(b.w) or 1))
        local bh = math.max(1, math.floor(tonumber(b.h) or 1))
        if bx < gw and by < gh then
            if bx + bw > gw then bw = gw - bx end
            if by + bh > gh then bh = gh - by end
            if bw > 0 and bh > 0 then
                out[#out + 1] = { x = bx, y = by, w = bw, h = bh }
            end
        end
    end
    return (#out > 0) and out or nil
end

function SLOT:Init()
    self.kind = "gear"
    self.slotID = ""
    self.title = ""
    self.emptyText = "EMPTY"
    self.slotTall = Nexus:Scale(62)
    self:SetTall(self.slotTall + Nexus:Scale(24))
end

function SLOT:Setup(kind, slotID, title, emptyText, slotTall)
    self.kind = kind
    self.slotID = slotID
    self.title = title or slotID
    self.emptyText = emptyText or "EMPTY"
    self.slotTall = slotTall or Nexus:Scale(62)
    self:SetTall(self.slotTall + Nexus:Scale(24))
end

function SLOT:GetEquipped()
    local inv = GetInv()
    if not inv then return nil end
    if self.kind == "gear" then
        return inv.gear and inv.gear[self.slotID]
    end
    if self.kind == "quickslot" then
        local index = math.floor(tonumber(self.slotID) or 0)
        return ZSCAV_GetQuickslotEntryCL(index)
    end
    return inv.weapons and inv.weapons[self.slotID]
end

local function ZSCAV_IsQuickslotBindableEntryCL(entry)
    if not (istable(entry) and entry.class) then return false end
    if ZSCAV_ResolveGrenadeInventoryClassCL(entry) then
        return true
    end
    return tostring(ZSCAV:GetEquipWeaponSlot(entry.class) or "") ~= ""
end

local function ZSCAV_IsMedicalQuickslotGridCL(gridName)
    gridName = tostring(gridName or "")
    return gridName == "pocket" or gridName == "vest"
end

local function ZSCAV_IsHealthTargetMedicalEntryCL(entry)
    if not (istable(entry) and entry.class) then return false end
    return tostring(ZSCAV:GetEquipWeaponSlot(entry.class) or "") == "medical"
end

local function ZSCAV_GetHealthNumericValueCL(value)
    if istable(value) then
        value = value[1]
    end

    value = tonumber(value) or 0
    if value ~= value then return 0 end
    return value
end

local function ZSCAV_ClampHealthUnitCL(value)
    return math.Clamp(ZSCAV_GetHealthNumericValueCL(value), 0, 1)
end

local function ZSCAV_GetHealthFillColorCL(ratio)
    ratio = math.Clamp(tonumber(ratio) or 0, 0, 1)
    if ratio <= 0.15 then return Color(186, 78, 78, 225) end
    if ratio <= 0.4 then return Color(216, 154, 72, 225) end
    if ratio <= 0.75 then return Color(194, 180, 92, 225) end
    return Color(108, 198, 124, 225)
end

local function ZSCAV_GetHealthWoundLoadCL(ply)
    local woundLoadByPart = {}
    local arterialByPart = {}

    local function AddWounds(list, isArterial)
        if not istable(list) then return end

        for _, wound in ipairs(list) do
            if not istable(wound) then
                continue
            end

            local partID = ZSCAV.GetHealthPartIDForBoneName and ZSCAV:GetHealthPartIDForBoneName(wound[4]) or nil
            if not partID then
                continue
            end

            woundLoadByPart[partID] = (woundLoadByPart[partID] or 0) + math.max(0, tonumber(wound[1]) or 0)
            if isArterial then
                arterialByPart[partID] = true
            end
        end
    end

    AddWounds(IsValid(ply) and ply.wounds or nil, false)
    AddWounds(IsValid(ply) and ply.arterialwounds or nil, true)

    return woundLoadByPart, arterialByPart
end

local function ZSCAV_GetHealthPartStructuralDamageCL(org, partID)
    org = istable(org) and org or {}

    if partID == "head" then
        return math.max(
            ZSCAV_ClampHealthUnitCL(org.skull),
            ZSCAV_ClampHealthUnitCL(org.brain)
        )
    end

    if partID == "thorax" then
        local lungLeft = ZSCAV_ClampHealthUnitCL(org.lungsL)
        local lungRight = ZSCAV_ClampHealthUnitCL(org.lungsR)
        return math.max(
            ZSCAV_ClampHealthUnitCL(org.chest),
            ZSCAV_ClampHealthUnitCL(org.heart),
            ZSCAV_ClampHealthUnitCL(org.trachea),
            math.min(1, (lungLeft + lungRight) * 0.5),
            math.min(1, ZSCAV_GetHealthNumericValueCL(org.pneumothorax) * 0.35)
        )
    end

    if partID == "stomach" then
        return math.max(
            ZSCAV_ClampHealthUnitCL(org.stomach),
            ZSCAV_ClampHealthUnitCL(org.liver),
            ZSCAV_ClampHealthUnitCL(org.intestines),
            math.min(1, ZSCAV_GetHealthNumericValueCL(org.internalBleed) / 6),
            ZSCAV_ClampHealthUnitCL(org.pelvis) * 0.75
        )
    end

    if partID == "left_arm" then
        return ZSCAV_ClampHealthUnitCL(org.larm)
    end

    if partID == "right_arm" then
        return ZSCAV_ClampHealthUnitCL(org.rarm)
    end

    if partID == "left_leg" then
        return math.max(
            ZSCAV_ClampHealthUnitCL(org.lleg),
            ZSCAV_ClampHealthUnitCL(org.pelvis) * 0.45
        )
    end

    if partID == "right_leg" then
        return math.max(
            ZSCAV_ClampHealthUnitCL(org.rleg),
            ZSCAV_ClampHealthUnitCL(org.pelvis) * 0.45
        )
    end

    return 0
end

local function ZSCAV_BuildHealthPartStatusCL(partState)
    local status = {}

    if (tonumber(partState.current_hp) or 0) <= 0 then
        status[#status + 1] = partState.def and partState.def.lethal and "DESTROYED" or "BLACKED"
    elseif (tonumber(partState.damage_frac) or 0) >= 0.8 then
        status[#status + 1] = "CRITICAL"
    elseif (tonumber(partState.damage_frac) or 0) >= 0.35 then
        status[#status + 1] = "DAMAGED"
    else
        status[#status + 1] = "STABLE"
    end

    if partState.arterial then
        status[#status + 1] = "ARTERIAL"
    elseif (tonumber(partState.wound_load) or 0) >= 12 then
        status[#status + 1] = "BLEEDING"
    end

    return table.concat(status, " | ")
end

local function ZSCAV_BuildHealthSnapshotCL(ply)
    local partDefs = ZSCAV.GetHealthPartDefinitions and ZSCAV:GetHealthPartDefinitions() or {}
    local totalMax = tonumber(ZSCAV.GetHealthTotalMaxHP and ZSCAV:GetHealthTotalMaxHP() or 0) or 0
    local org = IsValid(ply) and ((istable(ply.organism) and ply.organism) or (istable(ply.new_organism) and ply.new_organism) or {}) or {}
    local woundLoadByPart, arterialByPart = ZSCAV_GetHealthWoundLoadCL(ply)

    local snapshot = {
        order = partDefs,
        parts = {},
        current_hp = 0,
        max_hp = totalMax,
    }

    for _, partDef in ipairs(partDefs) do
        local maxHP = math.max(0, math.floor(tonumber(partDef.max_hp) or 0))
        local structuralDamage = ZSCAV_GetHealthPartStructuralDamageCL(org, partDef.id)
        local woundLoad = math.max(0, tonumber(woundLoadByPart[partDef.id]) or 0)
        local woundDamage = math.Clamp(woundLoad / 40, 0, 1)
        local arterialDamage = arterialByPart[partDef.id] and 0.72 or 0
        local damageFrac = math.Clamp(math.max(structuralDamage, woundDamage, arterialDamage), 0, 1)
        local currentHP = math.Clamp(math.Round(maxHP * (1 - damageFrac)), 0, maxHP)

        local state = {
            def = partDef,
            current_hp = currentHP,
            max_hp = maxHP,
            ratio = maxHP > 0 and (currentHP / maxHP) or 0,
            damage_frac = damageFrac,
            wound_load = woundLoad,
            arterial = arterialByPart[partDef.id] == true,
        }
        state.status = ZSCAV_BuildHealthPartStatusCL(state)

        snapshot.parts[partDef.id] = state
        snapshot.current_hp = snapshot.current_hp + currentHP
    end

    if snapshot.max_hp <= 0 then
        snapshot.max_hp = snapshot.current_hp
    end

    return snapshot
end

local function ZSCAV_GetHealthTotalStatusTextCL(snapshot)
    snapshot = snapshot or {}
    local currentHP = tonumber(snapshot.current_hp) or 0
    local maxHP = tonumber(snapshot.max_hp) or 0

    if maxHP <= 0 then
        return "NO HEALTH DATA"
    end

    if currentHP <= 30 then return "LETHAL RANGE" end
    if currentHP <= 120 then return "CRITICAL" end
    if currentHP < maxHP then return "WOUNDED" end
    return "STABLE"
end

local function ZSCAV_GetHealthTabSubjectCL()
    local localPly = LocalPlayer()
    if not IsValid(localPly) then return nil, false, "" end

    local rootUID = tostring(ROOT_CONT_UID or "")
    if rootUID == "" then
        return localPly, false, tostring(localPly:Nick() or "")
    end

    local state = CONT_WINDOWS[rootUID]
    if not (istable(state) and tostring(state.class or "") == LIVE_LOOT_CONTAINER_CLASS) then
        return localPly, false, tostring(localPly:Nick() or "")
    end

    local entIndex = math.floor(tonumber(state.health_target_entindex) or 0)
    local target = entIndex > 0 and Entity(entIndex) or nil
    if IsValid(target) and target:IsPlayer() then
        return target, target ~= localPly, tostring(state.health_target_name or target:Nick() or "")
    end

    return localPly, false, tostring(localPly:Nick() or "")
end

function SLOT:Accepts(entry)
    if not entry then return false end
    if self.kind == "quickslot" then
        return ZSCAV_IsQuickslotBindableEntryCL(entry)
    end
    if self.kind == "gear" then
        local def = ZSCAV:GetGearDef(entry.class)
        if not def then return false end

        if self.slotID == "body_armor" or self.slotID == "tactical_rig" or self.slotID == "vest" then
            local targetSlot = ZSCAV.GetTorsoArmorSlotForClass and ZSCAV:GetTorsoArmorSlotForClass(entry.class) or tostring(def.slot or "")
            if targetSlot == "vest" then
                targetSlot = "body_armor"
            end
            return targetSlot == self.slotID
        end

        return def.slot == self.slotID
    end
    return ZSCAV.IsWeaponSlotCompatible and ZSCAV:IsWeaponSlotCompatible(ZSCAV:GetEquipWeaponSlot(entry.class), self.slotID) or false
end

function SLOT:GetQuickslotDragValidation(drag)
    if self.kind ~= "quickslot" then
        return false, nil, nil
    end

    if not (drag and drag.entry) then
        return false, nil, nil
    end

    if drag.fromContainer then
        return false, nil, "MOVE TO INVENTORY FIRST"
    end

    if not ZSCAV_IsQuickslotBindableEntryCL(drag.entry) then
        return false, nil, "NOT HOTBAR ELIGIBLE"
    end

    local quickslotType = tostring(ZSCAV:GetEquipWeaponSlot(drag.entry.class) or "")
    local preferredGrid = tostring(drag.entry.preferred_grid or drag.fromGrid or "")
    if quickslotType == "medical" and not ZSCAV_IsMedicalQuickslotGridCL(preferredGrid) then
        return false, nil, "MEDS: POCKET/RIG ONLY"
    end

    if drag.fromSlot and drag.slotKind == "quickslot" then
        local fromQuickslot = math.floor(tonumber(drag.slotID) or 0)
        if fromQuickslot <= 0 then
            return false, nil, nil
        end
        return true, "MOVE HOTKEY", nil
    end

    return true, "BIND HOTKEY", nil
end

function SLOT:CanDropIntoEquippedContainer(drag)
    if not drag or not drag.entry or self.kind ~= "gear" then return false end
    local eq = self:GetEquipped()
    if not (eq and eq.class and eq.uid and eq.uid ~= "") then return false end

    local inv = GetInv()
    if not inv then return false end
    local grids = ZSCAV:GetEffectiveGrids(inv)

    local list, g, layout, sourceGrid = nil, nil, nil, nil
    if self.slotID == "backpack" then
        list = inv.backpack or {}
        g = grids.backpack
        local eq = inv.gear and inv.gear.backpack
        local def = eq and eq.class and ZSCAV:GetGearDef(eq.class)
        layout = def and def.layoutBlocks or nil
        sourceGrid = "backpack"
    elseif self.slotID == "tactical_rig" or self.slotID == "vest" then
        list = inv.vest or {}
        g = grids.vest
        layout = _slotGetVestLayoutBlocks(inv, tonumber(g and g.w) or 0, tonumber(g and g.h) or 0)
        sourceGrid = "vest"
    elseif self.slotID == "secure_container" then
        list = inv.secure or {}
        g = grids.secure
        local eq = inv.gear and inv.gear.secure_container
        local def = eq and eq.class and ZSCAV:GetGearDef(eq.class)
        layout = def and def.layoutBlocks or nil
        sourceGrid = "secure"
    else
        return false
    end

    if not g or (tonumber(g.w) or 0) <= 0 or (tonumber(g.h) or 0) <= 0 then return false end

    local ignoreIdx = nil
    if not drag.fromContainer and not drag.fromSlot and drag.fromGrid == sourceGrid then
        ignoreIdx = tonumber(drag.fromIndex)
    end

    local e = drag.entry
    return _slotCanFindRoomAR(list, tonumber(g.w) or 0, tonumber(g.h) or 0,
        tonumber(e.w) or 1, tonumber(e.h) or 1, ignoreIdx, layout)
end

function SLOT:GetDirectAttachmentPlacement(drag)
    if self.kind == "gear" then return nil end
    return FindDirectAttachmentPlacement(self:GetEquipped(), drag and drag.entry)
end

function SLOT:Paint(w, h)
    draw.SimpleText(string.upper(self.title), Nexus:GetFont(15, nil, true), 0, 0, COL_TXT())

    local slotY = Nexus:Scale(20)
    local slotH = h - slotY

    local root = FindRoot(self)
    local drag = root and root.zsDrag or nil
    local hovered = self:IsHovered()
    local accepts = false
    local acceptsContainer = false
    local acceptsDirectAttachment = false
    local acceptsEquip = false
    local acceptHint = nil
    local equipHint = nil
    local rejectHint = nil
    if drag then
        local eq = self:GetEquipped()
        if eq and eq.class then
            acceptsDirectAttachment = self:GetDirectAttachmentPlacement(drag) ~= nil
            acceptsContainer = self:CanDropIntoEquippedContainer(drag)
            accepts = acceptsDirectAttachment or acceptsContainer
        else
            if self.kind == "quickslot" then
                acceptsEquip, acceptHint, rejectHint = self:GetQuickslotDragValidation(drag)
            else
                acceptsEquip = self:Accepts(drag.entry)
            end
            accepts = acceptsEquip

            if acceptsEquip and self.kind == "gear" and drag.entry and drag.entry.class then
                local dragDef = ZSCAV:GetGearDef(drag.entry.class)
                local torsoTarget = nil
                if self.slotID == "body_armor" or self.slotID == "tactical_rig" or self.slotID == "vest" then
                    torsoTarget = ZSCAV.GetTorsoArmorSlotForClass and ZSCAV:GetTorsoArmorSlotForClass(drag.entry.class) or nil
                    if torsoTarget == "vest" then
                        torsoTarget = "body_armor"
                    end
                end

                if self.slotID == "backpack" then
                    equipHint = "EQUIP PACK"
                elseif self.slotID == "body_armor" and torsoTarget == "body_armor" then
                    if dragDef and (dragDef.compartment or dragDef.slot == "tactical_rig" or dragDef.slot == "vest") then
                        equipHint = "EQUIP CARRIER"
                    else
                        equipHint = "EQUIP ARMOR"
                    end
                elseif (self.slotID == "tactical_rig" or self.slotID == "vest") and torsoTarget == "tactical_rig" then
                    equipHint = "EQUIP RIG"
                else
                    equipHint = "EQUIP HERE"
                end
            elseif acceptsEquip and self.kind == "quickslot" then
                equipHint = acceptHint or "BIND HOTKEY"
            end
        end
    end

    local bg = COL_SLOT()
    if drag then
        bg = accepts and COL_OK() or COL_BAD()
    elseif hovered then
        bg = COL_SLOT_HOVER()
    end

    draw.RoundedBox(R12(), 0, slotY, w, slotH, bg)
    surface.SetDrawColor(COL_LINE())
    surface.DrawOutlinedRect(0, slotY, w, slotH, 1)

    if drag and accepts then
        local routeColor = acceptsDirectAttachment and Color(212, 192, 118, 220) or Color(146, 218, 146, 230)
        local routeFill = acceptsDirectAttachment and Color(118, 98, 46, 72) or Color(64, 122, 74, 84)

        surface.SetDrawColor(routeColor)
        surface.DrawOutlinedRect(0, slotY, w, slotH, 2)
        surface.DrawOutlinedRect(Nexus:Scale(2), slotY + Nexus:Scale(2), w - Nexus:Scale(4), slotH - Nexus:Scale(4), 1)

        if acceptsContainer then
            local inset = Nexus:Scale(8)
            local previewY = slotY + Nexus:Scale(28)
            local previewH = math.max(Nexus:Scale(26), slotH - Nexus:Scale(44))
            draw.RoundedBox(R8(), inset, previewY, w - inset * 2, previewH, routeFill)

            local columns = (self.slotID == "tactical_rig" or self.slotID == "vest") and 5 or 4
            local rows = (self.slotID == "tactical_rig" or self.slotID == "vest") and 3 or 2
            local cellGap = Nexus:Scale(3)
            local cellW = math.max(Nexus:Scale(10), math.floor((w - inset * 2 - cellGap * (columns + 1)) / columns))
            local cellH = math.max(Nexus:Scale(8), math.floor((previewH - cellGap * (rows + 1)) / rows))

            for row = 0, rows - 1 do
                for col = 0, columns - 1 do
                    local cellX = inset + cellGap + col * (cellW + cellGap)
                    local cellY = previewY + cellGap + row * (cellH + cellGap)
                    draw.RoundedBox(R4(), cellX, cellY, cellW, cellH, Color(routeColor.r, routeColor.g, routeColor.b, 54))
                end
            end

            draw.SimpleText("DROP TO STORAGE", Nexus:GetFont(11, nil, true), w - Nexus:Scale(8), slotY + slotH - Nexus:Scale(8), routeColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        elseif acceptsEquip then
            local inset = Nexus:Scale(8)
            local previewY = slotY + Nexus:Scale(28)
            local previewH = math.max(Nexus:Scale(24), slotH - Nexus:Scale(46))
            draw.RoundedBox(R8(), inset, previewY, w - inset * 2, previewH, Color(routeColor.r, routeColor.g, routeColor.b, 38))

            if equipHint then
                draw.SimpleText(equipHint, Nexus:GetFont(11, nil, true), w - Nexus:Scale(8), slotY + slotH - Nexus:Scale(8), routeColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
            end
        elseif acceptsDirectAttachment then
            draw.SimpleText("INSTALL", Nexus:GetFont(11, nil, true), w - Nexus:Scale(8), slotY + slotH - Nexus:Scale(8), routeColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        end
    elseif drag and self.kind == "quickslot" and rejectHint then
        draw.SimpleText(rejectHint, Nexus:GetFont(11, nil, true), w - Nexus:Scale(8), slotY + slotH - Nexus:Scale(8), Color(236, 206, 170), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    end

    local eq = self:GetEquipped()
    if eq and eq.class then
        draw.SimpleText(PrettyName(eq.class), Nexus:GetFont(14), Nexus:Scale(8), slotY + Nexus:Scale(10), COL_TXT())
        DrawWeaponAttachmentOverlay(eq, Nexus:Scale(6), slotY + Nexus:Scale(6), w - Nexus:Scale(12), slotH - Nexus:Scale(12))
        ZSCAV_DrawMedicalCounterBadgeCL(eq, 0, slotY, w, slotH)
    else
        draw.SimpleText(self.emptyText, Nexus:GetFont(13), Nexus:Scale(8), slotY + Nexus:Scale(10), COL_DIM())
    end
end

function SLOT:OnMousePressed(code)
    local eq = self:GetEquipped()
    if not (eq and eq.class) then return end
    local mx, my = self:CursorPos()

    if code == MOUSE_LEFT then
        if self.kind ~= "quickslot" and IsShiftDown() then
            local stashUID = GetOpenPlayerStashRootUID()
            if stashUID ~= "" then
                SendContainerAction("quick_move_slot_to_container", {
                    kind = self.kind,
                    slot = self.slotID,
                    target_uid = stashUID,
                })
                return
            end
        end

        if self.kind ~= "quickslot" and (IsCtrlDown() or IsShiftDown()) then
            SendAction("quick_move_slot", {
                kind = self.kind,
                slot = self.slotID,
            })
            return
        end

        local sz = nil
        if self.kind == "gear" then
            local gd = ZSCAV:GetGearDef(eq.class) or {}
            if gd.w and gd.h then
                sz = { w = tonumber(gd.w) or 1, h = tonumber(gd.h) or 1 }
            end
        end
        sz = sz or ZSCAV:GetItemSize(eq) or { w = 1, h = 1 }
        local step = CELL() + PAD()
        local ghostW = math.max(1, (math.max(1, tonumber(sz.w) or 1) * step) - PAD())
        local ghostH = math.max(1, (math.max(1, tonumber(sz.h) or 1) * step) - PAD())
        local slotY = Nexus:Scale(20)
        StartDrag(self, "__slot__", self.slotID, {
            class = eq.class,
            uid = eq.uid,
            actual_class = eq.actual_class,
            weapon_uid = eq.weapon_uid,
            preferred_grid = eq.preferred_grid,
            preferred_slot = eq.preferred_slot,
            kind = eq.kind,
            w = math.max(1, tonumber(sz.w) or 1),
            h = math.max(1, tonumber(sz.h) or 1),
        }, false, "", {
            fromSlot = true,
            slotKind = self.kind,
            slotID = self.slotID,
            grabOffX = math.Clamp(mx, 0, ghostW - 1),
            grabOffY = math.Clamp(my - slotY, 0, ghostH - 1),
        })
        return
    end

    if code ~= MOUSE_RIGHT then return end

    local m = DermaMenu()
    if self.kind == "quickslot" then
        local hotbarSlot = ZSCAV_GetHotbarSlotNumberForQuickslotIndexCL(self.slotID)
        if hotbarSlot then
            m:AddOption("Use " .. PrettyName(eq.class), function()
                SendAction("activate_hotbar_slot", { slot = hotbarSlot })
            end)
            m:AddSpacer()
        end
        m:AddOption("Clear Hotkey", function()
            SendAction("clear_quickslot", { quickslot = tonumber(self.slotID) })
        end)
        m:Open()
        return
    end

    if self.kind == "gear" then
        local def = ZSCAV:GetGearDef(eq.class)
        local hasNested = (
            self.slotID == "backpack"
            or self.slotID == "tactical_rig"
            or self.slotID == "vest"
            or (def and (def.compartment or def.secure))
        )
        if hasNested then
            m:AddOption("Open " .. PrettyName(eq.class), function()
                SendContainerAction("open_owned", { uid = eq.uid, slot = self.slotID })
            end)
            m:AddSpacer()
        end
        m:AddOption("Unequip " .. PrettyName(eq.class), function()
            SendAction("unequip_gear", { slot = self.slotID })
        end)
    else
        m:AddOption("Inspect " .. PrettyName(eq.class), function()
            OpenInspect({
                slot = self.slotID,
                weapon_uid = eq.weapon_uid,
            }, eq)
        end)
        m:AddSpacer()
        m:AddOption("Unholster " .. PrettyName(eq.class), function()
            SendAction("unequip_weapon", { slot = self.slotID })
        end)
    end
    m:Open()
end

function SLOT:HandleZScavDrop(drag, screenX, screenY)
    if not drag then return false end

    local lx, ly = self:ScreenToLocal(screenX, screenY)
    if lx < 0 or ly < 0 or lx > self:GetWide() or ly > self:GetTall() then
        return false
    end

    if self.kind == "quickslot" then
        local quickslotIndex = math.floor(tonumber(self.slotID) or 0)
        if quickslotIndex <= 0 then return false end

        local canBind = select(1, self:GetQuickslotDragValidation(drag))
        if not canBind then return false end

        if drag.fromSlot then
            if drag.slotKind == "quickslot" then
                local fromQuickslot = math.floor(tonumber(drag.slotID) or 0)
                if fromQuickslot <= 0 then return false end
                if fromQuickslot == quickslotIndex then return true end

                SendAction("set_quickslot", {
                    quickslot = quickslotIndex,
                    from_quickslot = fromQuickslot,
                    move = true,
                })
                return true
            end

            if drag.slotKind ~= "weapon" then return false end

            SendAction("set_quickslot", {
                quickslot = quickslotIndex,
                from_slot = drag.slotID,
            })
            return true
        end

        SendAction("set_quickslot", {
            quickslot = quickslotIndex,
            from_grid = drag.fromGrid,
            from_index = drag.fromIndex,
        })
        return true
    end

    local eq = self:GetEquipped()

    local directAttachPlacement = self:GetDirectAttachmentPlacement(drag)
    if directAttachPlacement then
        return SendDirectAttachmentInstall(drag, {
            slot = self.slotID,
            weapon_uid = eq and eq.weapon_uid,
        }, directAttachPlacement)
    end

    if eq and eq.class then
        if not self:CanDropIntoEquippedContainer(drag) then
            return false
        end

        if drag.fromSlot then
            SendAction("move_slot_to_slot_container", {
                kind = drag.slotKind,
                slot = drag.slotID,
                target_slot = self.slotID,
            })
        elseif drag.fromContainer then
            SendContainerAction("put_to_owned_slot", {
                from_uid = drag.fromContainerUID,
                from_index = drag.fromIndex,
                slot = self.slotID,
            })
        else
            SendAction("move_to_slot_container", {
                from_grid = drag.fromGrid,
                from_index = drag.fromIndex,
                slot = self.slotID,
            })
        end
        return true
    end

    if not self:Accepts(drag.entry) then
        return false
    end

    if drag.fromContainer then
        SendContainerAction("equip_from_container", {
            from_uid = drag.fromContainerUID,
            from_index = drag.fromIndex,
            kind = self.kind,
            slot = self.slotID,
        })
        return true
    end

    if self.kind == "gear" then
        SendAction("equip_gear", { grid = drag.fromGrid, index = drag.fromIndex })
    else
        SendAction("equip_weapon", { grid = drag.fromGrid, index = drag.fromIndex })
    end

    return true
end

vgui.Register("ZScavSlotTile", SLOT, "Panel")

local HEALTH_TILE = {}

function HEALTH_TILE:Init()
    self.partID = ""
    self:SetTall(Nexus:Scale(76))
end

function HEALTH_TILE:Setup(partID)
    self.partID = tostring(partID or ""):lower()
end

function HEALTH_TILE:GetDragValidation(drag)
    if not drag then
        return false, nil, nil
    end

    if drag.fromContainer then
        return false, nil, "MOVE TO INVENTORY FIRST"
    end

    if drag.fromSlot then
        return false, nil, "DRAG FROM GRID"
    end

    if not ZSCAV_IsHealthTargetMedicalEntryCL(drag.entry) then
        return false, nil, "MEDICAL ITEMS ONLY"
    end

    local profile = ZSCAV.GetMedicalUseProfile and ZSCAV:GetMedicalUseProfile(drag.entry.class) or nil
    if profile and profile.health_tab == true and ZSCAV.DoesMedicalProfileSupportHealthPart and not ZSCAV:DoesMedicalProfileSupportHealthPart(profile, self.partID) then
        return false, nil, "UNSUPPORTED AREA"
    end

    return true, profile and profile.health_tab == true and "APPLY TREATMENT" or "TARGET USE", nil
end

function HEALTH_TILE:Paint(w, h)
    local targetPly = select(1, ZSCAV_GetHealthTabSubjectCL())
    local snapshot = ZSCAV_BuildHealthSnapshotCL(targetPly)
    local state = snapshot.parts and snapshot.parts[self.partID] or nil
    if not state then
        draw.RoundedBox(R10(), 0, 0, w, h, COL_PANEL())
        return
    end

    local root = FindRoot(self)
    local drag = root and root.zsDrag or nil
    local canDrop, acceptHint, rejectHint = self:GetDragValidation(drag)

    local bg = COL_PANEL()
    if drag then
        bg = canDrop and Color(46, 74, 56, 185) or Color(88, 48, 48, 176)
    end

    draw.RoundedBox(R10(), 0, 0, w, h, bg)
    surface.SetDrawColor(COL_LINE())
    surface.DrawOutlinedRect(0, 0, w, h, 1)

    local padX = Nexus:Scale(10)
    local fillColor = ZSCAV_GetHealthFillColorCL(state.ratio)
    local hpText = string.format("%d / %d", state.current_hp, state.max_hp)
    local detail = tostring(state.status or "")
    if state.wound_load > 0 then
        detail = detail .. string.format(" | WND %.0f", state.wound_load)
    end

    draw.SimpleText(string.upper(state.def.label or self.partID), Nexus:GetFont(15, nil, true), padX, Nexus:Scale(12), COL_TXT())
    draw.SimpleText(hpText, Nexus:GetFont(15, nil, true), w - padX, Nexus:Scale(12), fillColor, TEXT_ALIGN_RIGHT)
    draw.SimpleText(detail, Nexus:GetFont(11), padX, Nexus:Scale(34), state.arterial and Color(236, 148, 148) or COL_DIM())

    local barX = padX
    local barY = h - Nexus:Scale(22)
    local barW = math.max(0, w - (padX * 2))
    local barH = Nexus:Scale(10)
    draw.RoundedBox(R4(), barX, barY, barW, barH, Color(12, 14, 18, 210))

    local fillW = math.Clamp(math.floor(barW * state.ratio), 0, barW)
    if state.current_hp > 0 and fillW <= 0 then
        fillW = 1
    end
    if fillW > 0 then
        draw.RoundedBox(R4(), barX, barY, fillW, barH, fillColor)
    end

    if drag then
        local hintText = canDrop and (acceptHint or "APPLY TREATMENT") or (rejectHint or "MEDICAL ITEMS ONLY")
        local hintColor = canDrop and fillColor or Color(236, 206, 170)
        draw.SimpleText(hintText, Nexus:GetFont(11, nil, true), w - padX, h - Nexus:Scale(36), hintColor, TEXT_ALIGN_RIGHT)
    end
end

function HEALTH_TILE:HandleZScavDrop(drag, screenX, screenY)
    if not drag then return false end

    local lx, ly = self:ScreenToLocal(screenX, screenY)
    if lx < 0 or ly < 0 or lx > self:GetWide() or ly > self:GetTall() then
        return false
    end

    local canDrop = select(1, self:GetDragValidation(drag))
    if not canDrop then return false end

    SendAction("use_medical_target", {
        body_part = self.partID,
        from_grid = drag.fromGrid,
        from_index = drag.fromIndex,
    })
    return true
end

vgui.Register("ZScavHealthPartTile", HEALTH_TILE, "Panel")

-- ---------------------------------------------------------------------
-- Build / toggle
-- ---------------------------------------------------------------------
local function Build()
    if IsValid(PANEL_REF) then PANEL_REF:Remove() end

    local root = vgui.Create("EditablePanel")
    root:SetSize(ScrW(), ScrH())
    -- Use mouse-only popup so the engine still reads movement keys,
    -- allowing the player to walk while the inventory is open.
    root:SetMouseInputEnabled(true)
    root:SetKeyboardInputEnabled(false)
    gui.EnableScreenClicker(true)
    root.zsDragRoot = true
    root.zsDrag = nil

    function root:CloseInventory()
        EndDrag(self)
        if IsTraderTradeActive() then
            SendTraderTradeAction("cancel", {})
        end
        local hasOpenContainers = next(CONT_WINDOWS) ~= nil
        if hasOpenContainers then
            SendContainerAction("close_all", {})
        end
        CloseContainerWindow("")  -- close all windows immediately client-side
        if ZSCAV.CloseWeaponInspect then
            ZSCAV.CloseWeaponInspect()
        end
        ZSCAV.InventoryPanelRef = nil
        gui.EnableScreenClicker(false)
        self:Remove()
    end

    root.OnRemove = function()
        if ZSCAV.InventoryPanelRef == root then
            ZSCAV.InventoryPanelRef = nil
        end
    end

    root.OnMouseReleased = function(self, code)
        if code ~= MOUSE_LEFT then return end
        if self.zsDrag then
            ResolveDropTarget(self)
            EndDrag(self)
        end
    end

    root.Think = function(self)
        if self.zsDrag and not input.IsMouseDown(MOUSE_LEFT) then
            ResolveDropTarget(self)
            EndDrag(self)
        end

        -- Rotate-on-R: while a drag is active rotate the ghost so the
        -- preview reflects the new shape; otherwise rotate the item the
        -- cursor is hovering inside its grid (server validates fit).
        local rDown = input.IsKeyDown(KEY_R)
        if rDown and not self._zsRPrev then
            if self.zsDrag and self.zsDrag.entry then
                local e = self.zsDrag.entry
                if e.w ~= e.h then
                    e.w, e.h = e.h, e.w
                    self.zsDrag.rotated = not self.zsDrag.rotated
                end
            else
                local hovered = vgui.GetHoveredPanel()
                while IsValid(hovered) do
                    if hovered.HandleZScavRotate then
                        if hovered:HandleZScavRotate() then break end
                    end
                    if hovered == self then break end
                    hovered = hovered:GetParent()
                end
            end
        end
        self._zsRPrev = rDown
    end

    root.Paint = function(self, w, h)
        Nexus:Blur(self, 3, 3, 220, w, h)
        surface.SetDrawColor(COL_SCRIM())
        surface.DrawRect(0, 0, w, h)
    end

    local compactInventoryLayout = ScrW() < 1600 or ScrH() < 940
    local shellOuterPad = Nexus:Scale(compactInventoryLayout and 6 or 8)
    local shellSideGap = Nexus:Scale(compactInventoryLayout and 4 or 6)
    local topButtonY = Nexus:Scale(compactInventoryLayout and 10 or 12)
    local topButtonTall = Nexus:Scale(compactInventoryLayout and 40 or 44)
    local shellW = math.floor(ScrW() * (compactInventoryLayout and 0.96 or 0.9))
    local shellY = math.max(topButtonY + topButtonTall + Nexus:Scale(10), Nexus:Scale(compactInventoryLayout and 58 or 70))
    local shellH = math.max(0, ScrH() - shellY - Nexus:Scale(compactInventoryLayout and 8 or 14))
    local topButtonWide = math.Clamp(math.floor(shellW * (compactInventoryLayout and 0.14 or 0.15)), Nexus:Scale(compactInventoryLayout and 116 or 136), Nexus:Scale(170))
    local mailboxButtonWide = math.Clamp(math.floor(shellW * (compactInventoryLayout and 0.18 or 0.2)), Nexus:Scale(compactInventoryLayout and 148 or 170), Nexus:Scale(220))
    local safeZoneButtonGap = Nexus:Scale(12)
    local leftWide = math.Clamp(math.floor(shellW * (compactInventoryLayout and 0.25 or 0.22)), Nexus:Scale(compactInventoryLayout and 210 or 230), Nexus:Scale(compactInventoryLayout and 300 or 360))
    local rightWide = math.Clamp(math.floor(shellW * (compactInventoryLayout and 0.4 or 0.44)), Nexus:Scale(compactInventoryLayout and 280 or 340), Nexus:Scale(compactInventoryLayout and 430 or 520))
    do
        local minMiddleWide = math.max(Nexus:Scale(compactInventoryLayout and 200 or 240), CELL() * 5 + PAD() * 7)
        local sideBudget = math.max(0, shellW - minMiddleWide - shellOuterPad * 2 - shellSideGap * 4)
        local sideTotal = leftWide + rightWide
        if sideBudget > 0 and sideTotal > sideBudget then
            local ratio = sideBudget / sideTotal
            leftWide = math.max(Nexus:Scale(180), math.floor(leftWide * ratio))
            rightWide = math.max(Nexus:Scale(240), math.floor(rightWide * ratio))
        end
    end

    local backButton = root:Add("Nexus:Button")
    backButton:SetText("BACK")
    backButton:SetColor(Nexus.Colors.Secondary)
    backButton:SetSize(topButtonWide, topButtonTall)
    backButton:SetPos((ScrW() - backButton:GetWide()) / 2, topButtonY)
    backButton.DoClick = function()
        root:CloseInventory()
    end

    local stashButton = root:Add("Nexus:Button")
    stashButton:SetText("STASH")
    stashButton:SetColor(Nexus.Colors.Primary)
    stashButton:SetSize(topButtonWide, topButtonTall)

    local mailboxButton = root:Add("Nexus:Button")
    mailboxButton:SetSize(mailboxButtonWide, topButtonTall)

    local tradeReadyButton
    local tradeCancelButton

    local function layoutTopButtons()
        local baseX, baseY = backButton:GetPos()
        local nextX = baseX + backButton:GetWide() + safeZoneButtonGap

        if IsValid(stashButton) and stashButton:IsVisible() then
            stashButton:SetPos(nextX, baseY)
            nextX = nextX + stashButton:GetWide() + safeZoneButtonGap
        end

        if IsValid(mailboxButton) and mailboxButton:IsVisible() then
            mailboxButton:SetPos(nextX, baseY)
            nextX = nextX + mailboxButton:GetWide() + safeZoneButtonGap
        end

        if IsValid(tradeReadyButton) then
            tradeReadyButton:SetPos(nextX, baseY)
            nextX = nextX + tradeReadyButton:GetWide() + safeZoneButtonGap
        end

        if IsValid(tradeReadyButton) and IsValid(tradeCancelButton) then
            tradeCancelButton:SetPos(nextX, baseY)
        end
    end

    local function updateSafeZoneActionButtons()
        if not IsValid(stashButton) or not IsValid(mailboxButton) then return end

        local inSafeZone = LocalPlayer():GetNWBool("ZCityInSafeZone", false)
        local unread = math.max(LocalPlayer():GetNWInt("ZScavMailboxUnread", 0), 0)
        stashButton:SetVisible(inSafeZone)
        stashButton:SetColor(Nexus.Colors.Primary)
        mailboxButton:SetText(unread > 0 and string.format("MAILBOX (%d)", unread) or "MAILBOX")
        mailboxButton:SetVisible(inSafeZone)
        mailboxButton:SetColor(Nexus.Colors.Primary)
        layoutTopButtons()
    end

    updateSafeZoneActionButtons()
    stashButton.Think = updateSafeZoneActionButtons
    mailboxButton.Think = updateSafeZoneActionButtons
    stashButton.DoClick = function()
        SendAction("open_stash", {})
    end
    mailboxButton.DoClick = function()
        SendAction("open_mailbox", {})
    end

    tradeReadyButton = root:Add("Nexus:Button")
    tradeReadyButton:SetSize(topButtonWide, topButtonTall)
    layoutTopButtons()
    tradeReadyButton:SetText("READY TRADE")
    tradeReadyButton:SetVisible(false)
    tradeReadyButton.DoClick = function()
        if not IsTraderTradeActive() then return end
        SendTraderTradeAction(TRADER_TRADE_STATE.player_ready and "unready" or "ready", {})
    end

    tradeCancelButton = root:Add("Nexus:Button")
    tradeCancelButton:SetSize(topButtonWide, topButtonTall)
    layoutTopButtons()
    tradeCancelButton:SetText("CANCEL TRADE")
    tradeCancelButton:SetVisible(false)
    tradeCancelButton.DoClick = function()
        if not IsTraderTradeActive() then return end
        SendTraderTradeAction("cancel", {})
    end

    local shell = root:Add("DPanel")
    shell:SetSize(shellW, shellH)
    shell:SetPos(math.floor((ScrW() - shellW) * 0.5), shellY)
    shell.Paint = function(_, w, h)
        draw.RoundedBox(R16(), 0, 0, w, h, COL_SHELL())
        surface.SetDrawColor(COL_LINE())
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end
    root.zs_shell = shell

    local left = shell:Add("DPanel")
    left:Dock(LEFT)
    left:SetWide(leftWide)
    left:DockMargin(shellOuterPad, shellOuterPad, shellSideGap, shellOuterPad)
    left.Paint = function(_, w, h)
        draw.RoundedBox(R12(), 0, 0, w, h, COL_BLOCK())
    end

    local right = shell:Add("DPanel")
    right:Dock(RIGHT)
    right:SetWide(rightWide)
    right:DockMargin(shellSideGap, shellOuterPad, shellOuterPad, shellOuterPad)
    right.Paint = function(_, w, h)
        draw.RoundedBox(R12(), 0, 0, w, h, COL_BLOCK())
    end
    local rightBaseWide = rightWide
    local rightMinCenterWide = math.max(Nexus:Scale(180), CELL() * 3 + PAD() * 4)

    local middleScroll = shell:Add("DScrollPanel")
    middleScroll:Dock(FILL)
    middleScroll:DockMargin(shellSideGap, shellOuterPad, shellSideGap, shellOuterPad)
    middleScroll.Paint = function(_, w, h)
        draw.RoundedBox(R12(), 0, 0, w, h, COL_BLOCK())
    end
    do
        local sb = middleScroll:GetVBar()
        if sb then sb:SetWide(Nexus:Scale(8)) end
    end
    local middle = middleScroll:GetCanvas()
    middle.Paint = function() end

    local activeLeftTab = "gear"

    local tabs = left:Add("DPanel")
    tabs:Dock(TOP)
    tabs:SetTall(Nexus:Scale(42))
    tabs:DockMargin(Nexus:Scale(8), Nexus:Scale(8), Nexus:Scale(8), Nexus:Scale(6))
    tabs.Paint = function(_, w, h)
        draw.RoundedBox(R8(), 0, 0, w, h, COL_PANEL())
    end

    local gearTabButton = tabs:Add("DButton")
    gearTabButton:Dock(LEFT)
    gearTabButton:DockMargin(0, 0, Nexus:Scale(4), 0)
    gearTabButton:SetText("")

    local healthTabButton = tabs:Add("DButton")
    healthTabButton:Dock(FILL)
    healthTabButton:SetText("")

    local leftContent = left:Add("DPanel")
    leftContent:Dock(FILL)
    leftContent:DockMargin(Nexus:Scale(8), 0, Nexus:Scale(8), 0)
    leftContent.Paint = function() end

    local gearWrap = leftContent:Add("DPanel")
    gearWrap.Paint = function() end

    local healthWrap = leftContent:Add("DPanel")
    healthWrap.Paint = function() end

    local function SetLeftTab(tabID)
        activeLeftTab = tabID == "health" and "health" or "gear"

        if IsValid(gearWrap) then
            gearWrap:SetVisible(activeLeftTab == "gear")
        end
        if IsValid(healthWrap) then
            healthWrap:SetVisible(activeLeftTab == "health")
        end
        if IsValid(leftContent) then
            leftContent:InvalidateLayout(true)
        end
    end

    local function PaintLeftTabButton(self, w, h)
        local isActive = activeLeftTab == self.tabID
        draw.RoundedBox(R8(), 0, 0, w, h, isActive and COL_BLOCK() or Color(180, 180, 180, 38))
        draw.SimpleText(self.label, Nexus:GetFont(20, nil, true), Nexus:Scale(12), h / 2, isActive and COL_TXT() or COL_DIM(), 0, 1)
    end

    gearTabButton.tabID = "gear"
    gearTabButton.label = "GEAR"
    gearTabButton.Paint = PaintLeftTabButton
    gearTabButton.DoClick = function()
        SetLeftTab("gear")
    end

    healthTabButton.tabID = "health"
    healthTabButton.label = "HEALTH"
    healthTabButton.Paint = PaintLeftTabButton
    healthTabButton.DoClick = function()
        SetLeftTab("health")
    end

    tabs.PerformLayout = function(_, w, _h)
        gearTabButton:SetWide(math.floor((w - Nexus:Scale(4)) * 0.5))
    end

    leftContent.PerformLayout = function(_, w, h)
        if IsValid(gearWrap) then
            gearWrap:SetPos(0, 0)
            gearWrap:SetSize(w, h)
        end
        if IsValid(healthWrap) then
            healthWrap:SetPos(0, 0)
            healthWrap:SetSize(w, h)
        end
    end

    local function AddSlot(parent, kind, slotID, title, emptyText, h, dock, ml, mt, mr, mb)
        local s = parent:Add("ZScavSlotTile")
        s:Setup(kind, slotID, title, emptyText, h)
        s:Dock(dock or TOP)
        s:DockMargin(ml or 0, mt or 0, mr or 0, mb or Nexus:Scale(6))
        return s
    end

    local earsHelmetFace = gearWrap:Add("DPanel")
    earsHelmetFace:Dock(TOP)
    earsHelmetFace:SetTall(Nexus:Scale(95))
    earsHelmetFace.Paint = function() end
    local earsSlot = AddSlot(earsHelmetFace, "gear", "ears", "Earpiece", "EMPTY", Nexus:Scale(58), LEFT, 0, 0, Nexus:Scale(4), 0)
    AddSlot(earsHelmetFace, "gear", "helmet", "Headwear", "EMPTY", Nexus:Scale(58), FILL, 0, 0, Nexus:Scale(4), 0)
    local faceSlot = AddSlot(earsHelmetFace, "gear", "face_cover", "Face Cover", "EMPTY", Nexus:Scale(58), RIGHT, 0, 0, 0, 0)
    earsHelmetFace.PerformLayout = function(_, w)
        local sideW = math.floor((w - Nexus:Scale(8)) * 0.3)
        earsSlot:SetWide(sideW)
        faceSlot:SetWide(sideW)
    end

    local armorRig = gearWrap:Add("DPanel")
    armorRig:Dock(TOP)
    armorRig:SetTall(Nexus:Scale(95))
    armorRig.Paint = function() end
    local armorSlot = AddSlot(armorRig, "gear", "body_armor", "Body Armor", "EMPTY", Nexus:Scale(58), LEFT, 0, 0, Nexus:Scale(4), 0)
    AddSlot(armorRig, "gear", "tactical_rig", "Tactical Rig", "EMPTY", Nexus:Scale(58), FILL, 0, 0, 0, 0)
    armorRig.PerformLayout = function(_, w)
        armorSlot:SetWide(math.floor((w - Nexus:Scale(4)) * 0.5))
    end

    AddSlot(gearWrap, "gear", "backpack", "Backpack", "EMPTY", Nexus:Scale(58), TOP, 0, 0, 0, Nexus:Scale(6))
    AddSlot(gearWrap, "gear", "secure_container", "Secure Container", "EMPTY", Nexus:Scale(58), TOP, 0, 0, 0, Nexus:Scale(6))

    AddSlot(gearWrap, "weapon", "primary", "On Back", "EMPTY", Nexus:Scale(72), TOP, 0, 0, 0, Nexus:Scale(6))
    AddSlot(gearWrap, "weapon", "secondary", "On Sling", "EMPTY", Nexus:Scale(72), TOP, 0, 0, 0, Nexus:Scale(6))

    local sideMelee = gearWrap:Add("DPanel")
    sideMelee:Dock(TOP)
    sideMelee:SetTall(Nexus:Scale(90))
    sideMelee.Paint = function() end
    local sidearmSlot = AddSlot(sideMelee, "weapon", "sidearm", "Holster 1", "EMPTY", Nexus:Scale(56), LEFT, 0, 0, Nexus:Scale(4), 0)
    local sidearm2Slot = AddSlot(sideMelee, "weapon", "sidearm2", "Holster 2", "EMPTY", Nexus:Scale(56), LEFT, 0, 0, Nexus:Scale(4), 0)
    AddSlot(sideMelee, "weapon", "melee", "Scabbard", "EMPTY", Nexus:Scale(56), FILL, 0, 0, 0, 0)
    sideMelee.PerformLayout = function(_, w)
        local gap = Nexus:Scale(8)
        local sw = math.floor((w - gap) / 3)
        sidearmSlot:SetWide(sw)
        sidearm2Slot:SetWide(sw)
    end

    local hotbarQuickslots = gearWrap:Add("DPanel")
    hotbarQuickslots:Dock(TOP)
    hotbarQuickslots:SetTall(Nexus:Scale(162))
    hotbarQuickslots:DockMargin(0, 0, 0, Nexus:Scale(6))
    hotbarQuickslots.Paint = function(_, w, _h)
        draw.SimpleText("HOTBAR 4-0", Nexus:GetFont(15, nil, true), 0, 0, COL_TXT())
        draw.SimpleText("Drag to bind. Meds: pocket/rig only", Nexus:GetFont(11), w, Nexus:Scale(2), COL_DIM(), TEXT_ALIGN_RIGHT)
    end

    local hotbarRow1 = hotbarQuickslots:Add("DPanel")
    hotbarRow1.Paint = function() end

    local hotbarRow2 = hotbarQuickslots:Add("DPanel")
    hotbarRow2.Paint = function() end

    local quickslotPanelsRow1 = {}
    local quickslotPanelsRow2 = {}

    for quickslotIndex = 1, 4 do
        local hotbarSlot = ZSCAV_GetHotbarSlotNumberForQuickslotIndexCL(quickslotIndex) or (quickslotIndex + 3)
        quickslotPanelsRow1[#quickslotPanelsRow1 + 1] = AddSlot(
            hotbarRow1,
            "quickslot",
            quickslotIndex,
            ZSCAV:GetCustomHotbarKeyLabel(hotbarSlot),
            "UNBOUND",
            Nexus:Scale(46),
            LEFT,
            0,
            0,
            quickslotIndex < 4 and Nexus:Scale(4) or 0,
            0
        )
    end

    for quickslotIndex = 5, 7 do
        local hotbarSlot = ZSCAV_GetHotbarSlotNumberForQuickslotIndexCL(quickslotIndex) or (quickslotIndex + 3)
        quickslotPanelsRow2[#quickslotPanelsRow2 + 1] = AddSlot(
            hotbarRow2,
            "quickslot",
            quickslotIndex,
            ZSCAV:GetCustomHotbarKeyLabel(hotbarSlot),
            "UNBOUND",
            Nexus:Scale(46),
            LEFT,
            0,
            0,
            quickslotIndex < 7 and Nexus:Scale(4) or 0,
            0
        )
    end

    hotbarQuickslots.PerformLayout = function(_, w, _h)
        local topY = Nexus:Scale(24)
        local rowH = Nexus:Scale(66)
        local rowGap = Nexus:Scale(6)

        hotbarRow1:SetPos(0, topY)
        hotbarRow1:SetSize(w, rowH)

        hotbarRow2:SetPos(0, topY + rowH + rowGap)
        hotbarRow2:SetSize(w, rowH)
    end

    hotbarRow1.PerformLayout = function(_, w, _h)
        local gap = Nexus:Scale(4)
        local slotW = math.floor((w - gap * 3) / 4)
        for _, panel in ipairs(quickslotPanelsRow1) do
            if IsValid(panel) then
                panel:SetWide(slotW)
            end
        end
    end

    hotbarRow2.PerformLayout = function(_, w, _h)
        local gap = Nexus:Scale(4)
        local slotW = math.floor((w - gap * 2) / 3)
        for _, panel in ipairs(quickslotPanelsRow2) do
            if IsValid(panel) then
                panel:SetWide(slotW)
            end
        end
    end

    local healthSummary = healthWrap:Add("DPanel")
    healthSummary:Dock(TOP)
    healthSummary:SetTall(Nexus:Scale(92))
    healthSummary:DockMargin(0, 0, 0, Nexus:Scale(6))
    healthSummary.Paint = function(_, w, h)
        local targetPly, isRemote, subjectName = ZSCAV_GetHealthTabSubjectCL()
        local snapshot = ZSCAV_BuildHealthSnapshotCL(targetPly)
        local ratio = snapshot.max_hp > 0 and (snapshot.current_hp / snapshot.max_hp) or 0
        local fillColor = ZSCAV_GetHealthFillColorCL(ratio)
        local guidance = "Drag a med item onto a body part to target treatment."
        if isRemote then
            local label = string.Trim(tostring(subjectName or ""))
            guidance = label ~= ""
                and ("Treating " .. label .. ". Drag a med item onto a body part to treat them.")
                or "Treating remote patient. Drag a med item onto a body part to treat them."
        end

        draw.RoundedBox(R10(), 0, 0, w, h, COL_PANEL())
        draw.SimpleText(isRemote and "PATIENT STATUS" or "BODY STATUS", Nexus:GetFont(16, nil, true), Nexus:Scale(10), Nexus:Scale(10), COL_TXT())
        draw.SimpleText(string.format("%d / %d TOTAL HP", snapshot.current_hp, snapshot.max_hp), Nexus:GetFont(18, nil, true), Nexus:Scale(10), Nexus:Scale(32), fillColor)
        draw.SimpleText(ZSCAV_GetHealthTotalStatusTextCL(snapshot), Nexus:GetFont(11, nil, true), w - Nexus:Scale(10), Nexus:Scale(12), COL_DIM(), TEXT_ALIGN_RIGHT)
        draw.SimpleText(guidance, Nexus:GetFont(11), w - Nexus:Scale(10), Nexus:Scale(34), COL_DIM(), TEXT_ALIGN_RIGHT)

        local barX = Nexus:Scale(10)
        local barY = h - Nexus:Scale(24)
        local barW = math.max(0, w - Nexus:Scale(20))
        local barH = Nexus:Scale(12)
        draw.RoundedBox(R4(), barX, barY, barW, barH, Color(12, 14, 18, 210))

        local fillW = math.Clamp(math.floor(barW * ratio), 0, barW)
        if snapshot.current_hp > 0 and fillW <= 0 then
            fillW = 1
        end
        if fillW > 0 then
            draw.RoundedBox(R4(), barX, barY, fillW, barH, fillColor)
        end
    end

    local healthScroll = healthWrap:Add("DScrollPanel")
    healthScroll:Dock(FILL)
    healthScroll.Paint = function() end
    do
        local sb = healthScroll:GetVBar()
        if sb then sb:SetWide(Nexus:Scale(8)) end
    end

    local healthCanvas = healthScroll:GetCanvas()
    healthCanvas.Paint = function() end

    for _, partDef in ipairs(ZSCAV.GetHealthPartDefinitions and ZSCAV:GetHealthPartDefinitions() or {}) do
        local tile = healthCanvas:Add("ZScavHealthPartTile")
        tile:Setup(partDef.id)
        tile:Dock(TOP)
        tile:DockMargin(0, 0, 0, Nexus:Scale(6))
    end

    SetLeftTab("gear")

    local hpBar = left:Add("DPanel")
    hpBar:Dock(BOTTOM)
    hpBar:SetTall(Nexus:Scale(70))
    hpBar:DockMargin(Nexus:Scale(8), Nexus:Scale(6), Nexus:Scale(8), Nexus:Scale(8))
    hpBar.Paint = function(_, w, h)
        local snapshot = ZSCAV_BuildHealthSnapshotCL(LocalPlayer())
        local ratio = snapshot.max_hp > 0 and (snapshot.current_hp / snapshot.max_hp) or 0
        local fillColor = ZSCAV_GetHealthFillColorCL(ratio)
        draw.RoundedBox(R8(), 0, 0, w, h, COL_PANEL())
        local kg = ZSCAV_GetVisibleWeightCL()
        draw.SimpleText(string.format("Load %.2f kg", kg), Nexus:GetFont(19, nil, true), Nexus:Scale(10), Nexus:Scale(8), COL_TXT())
        draw.SimpleText(string.format("%d / %d HP", snapshot.current_hp, snapshot.max_hp), Nexus:GetFont(17, nil, true), w - Nexus:Scale(10), Nexus:Scale(10), fillColor, TEXT_ALIGN_RIGHT)
        draw.SimpleText(ZSCAV_GetHealthTotalStatusTextCL(snapshot), Nexus:GetFont(11), Nexus:Scale(10), Nexus:Scale(36), COL_DIM())

        local barX = Nexus:Scale(10)
        local barY = h - Nexus:Scale(22)
        local barW = math.max(0, w - Nexus:Scale(20))
        local barH = Nexus:Scale(10)
        draw.RoundedBox(R4(), barX, barY, barW, barH, Color(12, 14, 18, 210))

        local fillW = math.Clamp(math.floor(barW * ratio), 0, barW)
        if snapshot.current_hp > 0 and fillW <= 0 then
            fillW = 1
        end
        if fillW > 0 then
            draw.RoundedBox(R4(), barX, barY, fillW, barH, fillColor)
        end
    end

    -- Bodycam consent toggle (sits directly above the Load/HP bar).
    -- Default state: OFF (deny). Click to toggle. Persisted via cookie in
    -- lua/zscav_bodycam/cl_bodycam_consent_ui.lua. Takes effect from the next
    -- raid; mid-raid toggling does not retroactively start/stop broadcasting.
    local bodycamBtn = left:Add("DButton")
    bodycamBtn:Dock(BOTTOM)
    bodycamBtn:SetTall(Nexus:Scale(34))
    bodycamBtn:DockMargin(Nexus:Scale(8), 0, Nexus:Scale(8), Nexus:Scale(6))
    bodycamBtn:SetText("")
    bodycamBtn.Paint = function(self, w, h)
        local on = ZSCAV and ZSCAV.Bodycam and ZSCAV.Bodycam:LocalGetConsent() or false
        local hovered = self:IsHovered()
        local panelCol = hovered and Color(45, 50, 62) or Color(35, 40, 51)
        draw.RoundedBox(R4(), 0, 0, w, h, panelCol)
        surface.SetDrawColor(58, 63, 75)
        surface.DrawOutlinedRect(0, 0, w, h)

        local dotCol = on and Color(34, 197, 94) or Color(220, 38, 38)
        surface.SetDrawColor(dotCol)
        draw.NoTexture()
        draw.RoundedBox(8, Nexus:Scale(10), h * 0.5 - Nexus:Scale(4), Nexus:Scale(8), Nexus:Scale(8), dotCol)

        draw.SimpleText("BODYCAM BROADCAST",
            Nexus:GetFont(13, nil, true),
            Nexus:Scale(26), h * 0.5,
            COL_TXT(), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        draw.SimpleText(on and "ON" or "OFF",
            Nexus:GetFont(13, nil, true),
            w - Nexus:Scale(10), h * 0.5,
            dotCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    bodycamBtn.DoClick = function()
        if not (ZSCAV and ZSCAV.Bodycam) then return end
        local was = ZSCAV.Bodycam:LocalGetConsent()
        ZSCAV.Bodycam:LocalSetConsent(not was)
        surface.PlaySound("ui/buttonclick.wav")
    end
    bodycamBtn:SetTooltip("Voice and weapon sounds will be broadcast to safe-zone monitors. Takes effect next raid.")

    local vestGrid = middle:Add("ZScavGrid")
    vestGrid:SetGrid("vest", "TACTICAL RIG")

    local pocket = middle:Add("ZScavGrid")
    pocket:SetGrid("pocket", "POCKETS")

    local backpack = middle:Add("ZScavGrid")
    backpack:SetGrid("backpack", "BACKPACK STORAGE")

    local secure = middle:Add("ZScavGrid")
    secure:SetGrid("secure", "SECURE CONTAINER")

    right.Paint = function(_, w, h)
        draw.RoundedBox(R12(), 0, 0, w, h, COL_BLOCK())
        -- Title bar
        local title = "CONTAINERS"
        local subtitle = nil
        if IsTraderTradeActive() then
            title = "TRADER OFFER"
            subtitle = string.format("%s | %s", tostring(TRADER_TRADE_STATE.trader_name or "Trader"), TRADER_TRADE_STATE.player_ready and "READY" or "REVIEW")
        elseif ROOT_CONT_UID and SECONDARY_ROOT_CONT_UID and CONT_WINDOWS[ROOT_CONT_UID] and CONT_WINDOWS[SECONDARY_ROOT_CONT_UID] then
            title = "STASH + MAILBOX"
            subtitle = "Side-by-side access"
        elseif ROOT_CONT_UID and CONT_WINDOWS[ROOT_CONT_UID] then
            local cd = CONT_WINDOWS[ROOT_CONT_UID]
            if IsCorpseContainerState(cd) then
                title = "BODY"
                subtitle = "Corpse Loot"
            else
                title = PrettyName(tostring(cd.class or ""))
                    .. "  " .. (cd.gw or 0) .. "\xc3\x97" .. (cd.gh or 0)
            end
        end
        draw.SimpleText(title, Nexus:GetFont(17, nil, true), Nexus:Scale(10), Nexus:Scale(8), COL_TXT())
        local floatCount = 0
        for _, e in pairs(CONT_WINDOWS) do
            if e.panel and IsValid(e.panel) then floatCount = floatCount + 1 end
        end
        if subtitle then
            draw.SimpleText(subtitle, Nexus:GetFont(13), Nexus:Scale(10), Nexus:Scale(28), COL_DIM())
        end
        if IsTraderTradeActive() then
            draw.SimpleText("Payment basket stays centered while trading.",
                Nexus:GetFont(13), Nexus:Scale(10), subtitle and Nexus:Scale(44) or Nexus:Scale(28), COL_DIM())
        elseif floatCount > 0 then
            draw.SimpleText("Nested bags: " .. floatCount .. "/" .. MAX_CONT_WINDOWS,
                Nexus:GetFont(13), Nexus:Scale(10), subtitle and Nexus:Scale(44) or Nexus:Scale(28), COL_DIM())
        end
    end

    -- Spacer so children sit below the title bar drawn in Paint.
    local rightTitleSpacer = right:Add("DPanel")
    rightTitleSpacer:Dock(TOP)
    rightTitleSpacer:SetTall(Nexus:Scale(60))
    rightTitleSpacer.Paint = function() end

    -- Container area: hint and scroll occupy the same region, toggled by
    -- visibility. Using a wrapper + PerformLayout so the dock system doesn't
    -- allocate space for the hidden panel.
    local rightContArea = right:Add("DPanel")
    rightContArea:Dock(FILL)
    rightContArea:DockMargin(Nexus:Scale(4), 0, Nexus:Scale(4), Nexus:Scale(4))
    rightContArea.Paint = function() end

    local rightHint = rightContArea:Add("DPanel")
    rightHint.Paint = function(_, w, h)
        draw.SimpleText("SHIFT+E on a bag or rig to open it",
            Nexus:GetFont(14), w * 0.5, h * 0.5 - Nexus:Scale(10), COL_DIM(), 1, 1)
        draw.SimpleText("Right-click a bag in your inventory to open from gear",
            Nexus:GetFont(14), w * 0.5, h * 0.5 + Nexus:Scale(10), COL_DIM(), 1, 1)
    end

    local rightScroll = rightContArea:Add("DScrollPanel")
    rightScroll:SetVisible(false)
    do
        local sb = rightScroll:GetVBar()
        if sb then sb:SetWide(Nexus:Scale(8)) end
    end

    local rightRootHost = rightScroll:Add("DPanel")
    rightRootHost:Dock(TOP)
    rightRootHost:DockMargin(Nexus:Scale(6), Nexus:Scale(6), Nexus:Scale(6), Nexus:Scale(6))
    rightRootHost:SetTall(1)
    rightRootHost.Paint = function() end
    rightRootHost.OnGridResize = function(self)
        self:InvalidateLayout(true)
    end
    rightRootHost.PerformLayout = function(self, w, _h)
        local primary = root.zs_rootCont
        local secondary = root.zs_rootContSecondary
        local hasPrimary = IsValid(primary)
        local hasSecondary = IsValid(secondary)
        local primaryState = hasPrimary and CONT_WINDOWS[tostring(ROOT_CONT_UID or "")] or nil
        local secondaryState = hasSecondary and CONT_WINDOWS[tostring(SECONDARY_ROOT_CONT_UID or "")] or nil
        local hasCorpseRoot = IsCorpseContainerState(primaryState) or IsCorpseContainerState(secondaryState)
        local gap = Nexus:Scale(compactInventoryLayout and 8 or 10)
        local requiredContentW = 0

        if hasPrimary then
            requiredContentW = GetEmbeddedRightPanelPanelNaturalWidth(primary, primaryState)
        end

        if hasSecondary then
            requiredContentW = requiredContentW + GetEmbeddedRightPanelPanelNaturalWidth(secondary, secondaryState)
            if hasPrimary then
                requiredContentW = requiredContentW + gap
            end
        end

        local requiredPanelW = rightBaseWide
        local rightPanelChromeW = math.max(0, right:GetWide() - w)
        if requiredContentW > 0 then
            requiredPanelW = math.max(
                rightBaseWide,
                requiredContentW + rightPanelChromeW + Nexus:Scale(compactInventoryLayout and 24 or 28)
            )
        end

        local maxPanelW = math.max(
            rightBaseWide,
            shell:GetWide() - left:GetWide() - shellSideGap * 2 - shellOuterPad * 2 - rightMinCenterWide
        )
        if hasCorpseRoot then
            maxPanelW = math.min(maxPanelW, GetCorpseRightPanelMaxWidth())
        end
        local targetPanelW = math.Clamp(requiredPanelW, rightBaseWide, maxPanelW)
        if math.abs(right:GetWide() - targetPanelW) > 1 then
            right:SetWide(targetPanelW)
            return
        end

        if hasPrimary and hasSecondary then
            local requiredSplitW = GetEmbeddedRightPanelPanelNaturalWidth(primary, primaryState)
                + GetEmbeddedRightPanelPanelNaturalWidth(secondary, secondaryState)
                + gap + Nexus:Scale(16)

            if w < requiredSplitW then
                local primaryW, primaryH = PrepareEmbeddedRightPanelPanel(primary, primaryState, w)
                primary:SetPos(math.max(0, math.floor((w - primaryW) * 0.5)), 0)

                local secondaryW, secondaryH = PrepareEmbeddedRightPanelPanel(secondary, secondaryState, w)
                secondary:SetPos(math.max(0, math.floor((w - secondaryW) * 0.5)), primaryH + gap)

                self:SetTall(math.max(primaryH + gap + secondaryH, 1))
                return
            end

            local slotW = math.max(0, math.floor((w - gap) * 0.5))
            local primaryW, primaryH = PrepareEmbeddedRightPanelPanel(primary, primaryState, slotW)
            local secondaryW, secondaryH = PrepareEmbeddedRightPanelPanel(secondary, secondaryState, slotW)
            primary:SetPos(math.max(0, math.floor((slotW - primaryW) * 0.5)), 0)
            secondary:SetPos(slotW + gap + math.max(0, math.floor((slotW - secondaryW) * 0.5)), 0)
            self:SetTall(math.max(primaryH, secondaryH, 1))
            return
        end

        if hasPrimary then
            local primaryW, primaryH = PrepareEmbeddedRightPanelPanel(primary, primaryState, w)
            primary:SetPos(math.max(0, math.floor((w - primaryW) * 0.5)), 0)
            self:SetTall(math.max(primaryH, 1))
            return
        end

        if hasSecondary then
            local secondaryW, secondaryH = PrepareEmbeddedRightPanelPanel(secondary, secondaryState, w)
            secondary:SetPos(math.max(0, math.floor((w - secondaryW) * 0.5)), 0)
            self:SetTall(math.max(secondaryH, 1))
            return
        end

        self:SetTall(1)
    end

    local rightTradeScroll = rightContArea:Add("DScrollPanel")
    rightTradeScroll:SetVisible(false)
    do
        local sb = rightTradeScroll:GetVBar()
        if sb then sb:SetWide(Nexus:Scale(8)) end
    end

    rightContArea.PerformLayout = function(self, w, h)
        if IsValid(rightHint)   then rightHint:SetPos(0, 0);   rightHint:SetSize(w, h)   end
        if IsValid(rightScroll) then rightScroll:SetPos(0, 0); rightScroll:SetSize(w, h) end
        if IsValid(rightTradeScroll) then rightTradeScroll:SetPos(0, 0); rightTradeScroll:SetSize(w, h) end
    end

    root.zs_rightHint   = rightHint
    root.zs_rightScroll = rightScroll
    root.zs_rightRootHost = rightRootHost
    root.zs_tradeOfferScroll = rightTradeScroll
    root.zs_rootCont    = nil
    root.zs_rootContSecondary = nil
    root.zs_tradeReadyButton = tradeReadyButton
    root.zs_tradeCancelButton = tradeCancelButton

    function shell:PerformLayout()
        local pad = Nexus:Scale(8)
        local y = pad
        for _, p in ipairs({ vestGrid, pocket, backpack, secure }) do
            if IsValid(p) then
                p:SetPos(pad, y)
                y = y + p:GetTall() + pad
            end
        end
        -- Expand canvas so the scroll panel knows the full content height.
        if IsValid(middle) then
            middle:SetTall(math.max(y, 1))
        end
    end

    local dragGhost = root:Add("Panel")
    dragGhost:SetMouseInputEnabled(false)
    dragGhost:SetKeyboardInputEnabled(false)
    dragGhost.Paint = function(_, w, h)
        local d = root.zsDrag
        if not d then return end

        local mx, my = input.GetCursorPos()
        local rw, rh = root:GetWide(), root:GetTall()
        if mx < 0 or my < 0 or mx > rw or my > rh then return end

        local iw = d.entry.w * (CELL() + PAD()) - PAD()
        local ih = d.entry.h * (CELL() + PAD()) - PAD()
        local x = mx - (tonumber(d.grabOffX) or (iw * 0.5))
        local y = my - (tonumber(d.grabOffY) or (ih * 0.5))

        draw.RoundedBox(R8(), x, y, iw, ih, Color(255, 255, 255, 75))
        surface.SetDrawColor(COL_LINE())
        surface.DrawOutlinedRect(x, y, iw, ih, 1)
        draw.SimpleText(PrettyName(d.entry.class), Nexus:GetFont(14, nil, true), mx, my, COL_TXT(), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    dragGhost.Think = function(self)
        self:SetPos(0, 0)
        self:SetSize(root:GetWide(), root:GetTall())
    end

    PANEL_REF = root
    ZSCAV.InventoryPanelRef = root
    UpdateTraderTradeUI()
end

local function Toggle()
    if IsValid(PANEL_REF) then
        PANEL_REF:CloseInventory()
        return
    end

    if not ZScav_CanOpenInventoryCL() then return end

    Build()
end

local zscavNextToggleAt = 0
local zscavInventoryHoldDepth = 0
local zscavInventoryOpenedByHold = false

local function ZSCAV_ResetInventoryHoldState()
    zscavInventoryHoldDepth = 0
    zscavInventoryOpenedByHold = false
end

local function ZSCAV_CloseInventoryCL()
    ZSCAV_ResetInventoryHoldState()
    if not IsValid(PANEL_REF) then return false end
    PANEL_REF:CloseInventory()
    return true
end

local function ZSCAV_OpenInventoryCL(openedByHold)
    if IsValid(PANEL_REF) then
        if openedByHold then
            zscavInventoryOpenedByHold = true
        end
        return true
    end

    if not ZScav_CanOpenInventoryCL() then return false end

    Build()
    if IsValid(PANEL_REF) and openedByHold then
        zscavInventoryOpenedByHold = true
    end

    return IsValid(PANEL_REF)
end

function ZSCAV.ToggleInventoryCL()
    local now = RealTime()
    if now < zscavNextToggleAt then return false end
    zscavNextToggleAt = now + 0.2

    if IsValid(PANEL_REF) then
        return ZSCAV_CloseInventoryCL()
    end

    ZSCAV_ResetInventoryHoldState()
    return ZSCAV_OpenInventoryCL(false)
end

function ZSCAV.BeginHoldInventoryCL()
    zscavInventoryHoldDepth = zscavInventoryHoldDepth + 1
    if zscavInventoryHoldDepth > 1 then return true end

    local openedExisting = IsValid(PANEL_REF)
    local opened = ZSCAV_OpenInventoryCL(not openedExisting)
    if not opened then
        zscavInventoryHoldDepth = 0
        zscavInventoryOpenedByHold = false
    end

    return opened
end

function ZSCAV.EndHoldInventoryCL()
    if zscavInventoryHoldDepth > 0 then
        zscavInventoryHoldDepth = zscavInventoryHoldDepth - 1
    end

    if zscavInventoryHoldDepth > 0 then return true end

    zscavInventoryHoldDepth = 0
    if not zscavInventoryOpenedByHold then return false end

    zscavInventoryOpenedByHold = false
    if not IsValid(PANEL_REF) then return false end
    PANEL_REF:CloseInventory()
    return true
end

function ZSCAV.GetInventoryBindActionCL(bind)
    local normalized = string.Trim(string.lower(tostring(bind or "")))
    if normalized == "zscav_inv" then return "toggle" end
    if normalized == "+zscav_inv" then return "hold" end
    if normalized == "-zscav_inv" then return "release" end
    return nil
end

ZSCAV.InventoryBindHintShown = ZSCAV.InventoryBindHintShown or false

hook.Add("Think", "ZSCAV_InventoryBindHint", function()
    local ply = LocalPlayer()
    if not (IsValid(ply) and ply:Alive() and ZScav_IsActiveCL()) then
        ZSCAV.InventoryBindHintShown = false
        return
    end

    if ZSCAV_IsInventoryBoundCL() then
        ZSCAV.InventoryBindHintShown = false
        return
    end

    if ZSCAV.InventoryBindHintShown then return end
    ZSCAV.InventoryBindHintShown = true

    local msg = "No inventory key is bound. Use bind <key> zscav_inv for toggle or bind <key> +zscav_inv for hold."
    notification.AddLegacy("[ZScav] " .. msg, NOTIFY_HINT, 6)
    surface.PlaySound("buttons/button15.wav")
    chat.AddText(Color(200, 200, 80), "[ZScav] ", Color(230, 230, 230), msg)
end)

hook.Add("Think", "ZSCAV_InventoryActionBlockGuard", function()
    if not IsValid(PANEL_REF) then return end
    if ZSCAV_CanManipulateInventoryCL() then return end

    if PANEL_REF.CloseInventory then
        PANEL_REF:CloseInventory()
        return
    end

    PANEL_REF:Remove()
end)

hook.Add("PlayerBindPress", "ZSCAV_InventoryBindPress", function(ply, bind, pressed)
    if ply ~= LocalPlayer() then return end

    local action = ZSCAV.GetInventoryBindActionCL(bind)
    if not action then return end

    if action == "toggle" then
        if pressed ~= false then
            ZSCAV.ToggleInventoryCL()
        end
        return true
    end

    if action == "hold" then
        if pressed == false then
            ZSCAV.EndHoldInventoryCL()
        else
            ZSCAV.BeginHoldInventoryCL()
        end
        return true
    end

    ZSCAV.EndHoldInventoryCL()
    return true
end)

hook.Add("PlayerBindPress", "ZSCAV_HotbarBindPress", function(ply, bind, pressed)
    if ply ~= LocalPlayer() then return end

    local hotbarSlot = ZSCAV_GetHotbarBindSlotCL(bind)
    if not hotbarSlot then return end
    if not ZScav_IsActiveCL() then return end

    if pressed ~= false then
        ZSCAV_TriggerHotbarSlotCL(hotbarSlot)
    end

    return true
end)

hook.Add("PlayerButtonDown", "ZSCAV_HotbarPhysicalKeys", function(ply, button)
    if ply ~= LocalPlayer() then return end

    local hotbarSlot = HOTBAR_PHYSICAL_KEY_TO_SLOT[button]
    if not hotbarSlot then return end
    if not ZScav_IsActiveCL() then return end

    if ZSCAV_TriggerHotbarSlotCL(hotbarSlot) then
        return true
    end
end)

net.Receive("ZScavInvOpen", function()
    if not IsValid(PANEL_REF) then
        ZSCAV_OpenInventoryCL(false)
    end
end)

net.Receive("ZScavInvClose", function()
    ZSCAV_CloseInventoryCL()
end)

hook.Add("PlayerBindPress", "ZSCAV_BlockModifierMovementWhileInv", function(_ply, bind, _pressed)
    if not IsValid(PANEL_REF) then return end
    local b = string.lower(tostring(bind or ""))
    if b:find("+reload", 1, true) then return true end
    if b:find("+duck", 1, true) then return true end
    if b:find("+speed", 1, true) then return true end
    if b:find("+walk", 1, true) then return true end
end)

net.Receive("ZScavInvNotice", function()
    local msg = net.ReadString()
    notification.AddLegacy("[ZScav] " .. msg, NOTIFY_HINT, 2)
    surface.PlaySound("buttons/button15.wav")
    chat.AddText(Color(200, 200, 80), "[ZScav] ", Color(230, 230, 230), msg)
end)

net.Receive("ZScavWorldPickupPrompt", function()
    local entIndex = net.ReadUInt(16)
    local className = net.ReadString()
    local canEquip = net.ReadBool()
    OpenWorldPickupPrompt(entIndex, className, canEquip)
end)

net.Receive("ZScavBagOpenProgress", function()
    local active = net.ReadBool()
    local finishAt = tonumber(net.ReadFloat()) or 0
    local duration = tonumber(net.ReadFloat()) or 0
    local class = tostring(net.ReadString() or "")

    if not active then
        BAG_OPEN_PROGRESS = nil
        return
    end

    BAG_OPEN_PROGRESS = {
        finishAt = finishAt,
        duration = math.max(duration, 0.01),
        class = class,
    }
end)

net.Receive("ZScavSurgeryProgress", function()
    local active = net.ReadBool()
    local finishAt = tonumber(net.ReadFloat()) or 0
    local duration = tonumber(net.ReadFloat()) or 0
    local class = tostring(net.ReadString() or "")
    local partLabel = tostring(net.ReadString() or "")

    if not active then
        SURGERY_PROGRESS = nil
        return
    end

    SURGERY_PROGRESS = {
        finishAt = finishAt,
        duration = math.max(duration, 0.01),
        class = class,
        partLabel = partLabel,
    }
end)

hook.Add("HUDPaint", "ZSCAV_SurgeryProgressBar", function()
    if not SURGERY_PROGRESS then return end

    local now = CurTime()
    local finishAt = SURGERY_PROGRESS.finishAt or 0
    local duration = SURGERY_PROGRESS.duration or 0.01
    if now >= finishAt then
        SURGERY_PROGRESS = nil
        return
    end

    local frac = 1 - math.Clamp((finishAt - now) / duration, 0, 1)
    local sw, sh = ScrW(), ScrH()
    local bw, bh = Nexus:Scale(380), Nexus:Scale(24)
    local x, y = math.floor((sw - bw) * 0.5), math.floor(sh * 0.72)
    local pad = Nexus:Scale(2)

    surface.SetDrawColor(0, 0, 0, 190)
    surface.DrawRect(x, y, bw, bh)
    surface.SetDrawColor(44, 32, 32, 230)
    surface.DrawRect(x + pad, y + pad, bw - pad * 2, bh - pad * 2)
    surface.SetDrawColor(156, 72, 60, 235)
    surface.DrawRect(x + pad, y + pad, math.floor((bw - pad * 2) * frac), bh - pad * 2)

    local label = "Performing surgery"
    local partLabel = string.Trim(tostring(SURGERY_PROGRESS.partLabel or ""))
    if partLabel ~= "" then
        label = label .. " on " .. partLabel
    end

    local cls = string.Trim(tostring(SURGERY_PROGRESS.class or ""))
    if cls ~= "" then
        label = label .. " (" .. PrettyName(cls) .. ")"
    end

    draw.SimpleText(label, "Trebuchet18", x + bw * 0.5, y - Nexus:Scale(4), Color(240, 232, 228), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
end)

hook.Add("HUDPaint", "ZSCAV_BagOpenProgressBar", function()
    if not BAG_OPEN_PROGRESS then return end

    local now = CurTime()
    local finishAt = BAG_OPEN_PROGRESS.finishAt or 0
    local duration = BAG_OPEN_PROGRESS.duration or 0.01
    if now >= finishAt then
        BAG_OPEN_PROGRESS = nil
        return
    end

    local frac = 1 - math.Clamp((finishAt - now) / duration, 0, 1)
    local sw, sh = ScrW(), ScrH()
    local bw, bh = Nexus:Scale(360), Nexus:Scale(24)
    local x, y = math.floor((sw - bw) * 0.5), math.floor(sh * 0.78)
    local pad = Nexus:Scale(2)

    surface.SetDrawColor(0, 0, 0, 180)
    surface.DrawRect(x, y, bw, bh)
    surface.SetDrawColor(50, 54, 60, 220)
    surface.DrawRect(x + pad, y + pad, bw - pad * 2, bh - pad * 2)
    surface.SetDrawColor(164, 132, 74, 230)
    surface.DrawRect(x + pad, y + pad, math.floor((bw - pad * 2) * frac), bh - pad * 2)

    local label = "Opening bag"
    local cls = tostring(BAG_OPEN_PROGRESS.class or "")
    if cls ~= "" then
        label = label .. ": " .. PrettyName(cls)
    end
    draw.SimpleText(label, "Trebuchet18", x + bw * 0.5, y - Nexus:Scale(4), Color(235, 235, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
end)

hook.Add("HUDPaint", "ZSCAV_StaminaBarHUD", function()
    if not ZScav_IsActiveCL() then return end

    local ply = LocalPlayer()
    if not (IsValid(ply) and ply:Alive()) then return end

    local curStamina, maxStamina = ZSCAV_GetStaminaStateCL()
    if not curStamina then return end

    local curBreath, maxBreath, holdingBreath = ZSCAV_GetBreathStateCL()

    local visibleWeightKg = ZSCAV_GetVisibleWeightCL()
    local movementWeightKg = ZSCAV_GetMovementWeightCL()
    local profile = ZSCAV.GetWeightMovementProfile and ZSCAV:GetWeightMovementProfile(movementWeightKg) or nil
    local frac = math.Clamp(curStamina / math.max(maxStamina, 1), 0, 1)
    local breathFrac = curBreath and math.Clamp(curBreath / math.max(maxBreath, 1), 0, 1) or 1

    local sw, sh = ScrW(), ScrH()
    local panelW = Nexus:Scale(300)
    local panelH = Nexus:Scale(curBreath and 86 or 58)
    local barW = panelW - Nexus:Scale(20)
    local barH = Nexus:Scale(12)
    local x = Nexus:Scale(18)
    local y = sh - panelH - Nexus:Scale(18)
    local barX = x + Nexus:Scale(10)
    local barY = y + Nexus:Scale(25)
    local lungLabelY = y + Nexus:Scale(40)
    local lungBarY = y + Nexus:Scale(57)

    local accent = Color(96, 196, 110, 220)
    local detail = Color(165, 170, 175, 220)
    local lungAccent = holdingBreath and Color(102, 184, 220, 230) or Color(96, 150, 198, 210)
    if profile and profile.severity == 1 then
        accent = Color(156, 196, 96, 220)
        detail = Color(196, 205, 132, 220)
    elseif profile and profile.severity == 2 then
        accent = Color(204, 176, 88, 220)
        detail = Color(218, 192, 128, 220)
    elseif profile and profile.severity == 3 then
        accent = Color(220, 138, 78, 220)
        detail = Color(226, 170, 116, 220)
    elseif profile and profile.severity >= 4 then
        accent = Color(214, 90, 82, 220)
        detail = Color(224, 132, 122, 220)
    end

    if frac <= 0.35 then
        accent = Color(220, 86, 86, 230)
    end

    if curBreath and breathFrac <= 0.25 then
        lungAccent = Color(220, 98, 86, 230)
    end

    draw.RoundedBox(R8(), x, y, panelW, panelH, COL_PANEL())
    draw.SimpleText("STAMINA", Nexus:GetFont(15, nil, true), x + Nexus:Scale(10), y + Nexus:Scale(8), COL_TXT())
    draw.SimpleText(string.format("%.0f / %.0f", curStamina, maxStamina), Nexus:GetFont(14, nil, true), x + panelW - Nexus:Scale(10), y + Nexus:Scale(8), COL_DIM(), TEXT_ALIGN_RIGHT)

    surface.SetDrawColor(12, 14, 16, 210)
    surface.DrawRect(barX, barY, barW, barH)
    surface.SetDrawColor(42, 46, 52, 220)
    surface.DrawRect(barX + 1, barY + 1, barW - 2, barH - 2)
    surface.SetDrawColor(accent.r, accent.g, accent.b, accent.a)
    surface.DrawRect(barX + 1, barY + 1, math.floor((barW - 2) * frac), barH - 2)

    if curBreath then
        draw.SimpleText("LUNGS", Nexus:GetFont(14, nil, true), x + Nexus:Scale(10), lungLabelY, COL_TXT())
        draw.SimpleText(
            string.format("%.1fs / %.1fs", curBreath, maxBreath),
            Nexus:GetFont(13, nil, true),
            x + panelW - Nexus:Scale(10),
            lungLabelY,
            COL_DIM(),
            TEXT_ALIGN_RIGHT
        )

        surface.SetDrawColor(12, 14, 16, 210)
        surface.DrawRect(barX, lungBarY, barW, barH)
        surface.SetDrawColor(42, 46, 52, 220)
        surface.DrawRect(barX + 1, lungBarY + 1, barW - 2, barH - 2)
        surface.SetDrawColor(lungAccent.r, lungAccent.g, lungAccent.b, lungAccent.a)
        surface.DrawRect(barX + 1, lungBarY + 1, math.floor((barW - 2) * breathFrac), barH - 2)
    end

    local status = profile and profile.sprintLabel or "Full sprint"
    local band = profile and profile.label or "Unburdened"
    local footer = string.format(
        "Load %.1f kg  |  %s  |  %s%s",
        visibleWeightKg,
        band,
        status,
        holdingBreath and "  |  Holding breath" or ""
    )
    draw.SimpleText(footer, Nexus:GetFont(13), x + Nexus:Scale(10), y + panelH - Nexus:Scale(8), detail, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
end)

hook.Add("HUDPaint", "ZSCAV_HotbarHUD", function()
    if not ZScav_IsActiveCL() then return end

    local ply = LocalPlayer()
    if not (IsValid(ply) and ply:Alive()) then return end

    local inv = GetInv()
    if not inv then return end

    inv.weapons = inv.weapons or {}

    local totalSlots = math.max(math.floor(tonumber(ZSCAV.CustomHotbarMax) or 10), 3)
    local gap = Nexus:Scale(6)
    local maxSlotW = math.floor((ScrW() - Nexus:Scale(40) - gap * (totalSlots - 1)) / totalSlots)
    local slotW = math.max(Nexus:Scale(48), math.min(Nexus:Scale(72), maxSlotW))
    local slotH = math.max(Nexus:Scale(56), math.floor(slotW * 0.92))
    local totalW = slotW * totalSlots + gap * (totalSlots - 1)
    local x = math.floor((ScrW() - totalW) * 0.5)
    local y = ScrH() - slotH - Nexus:Scale(22)

    local outline = Color(8, 10, 12, 210)
    local textColor = Color(235, 237, 238, 235)
    local dimColor = Color(165, 170, 175, 220)
    local selectedAccent = Color(146, 218, 146, 235)

    for slotNumber = 1, totalSlots do
        local entry = ZSCAV_GetHotbarEntryCL(slotNumber)
        local selected = ZSCAV_IsHotbarSlotSelectedCL(slotNumber)
        local cardX = x + (slotNumber - 1) * (slotW + gap)

        local bg = entry and Color(28, 32, 37, 200) or Color(20, 24, 28, 155)
        if selected then
            bg = Color(52, 72, 56, 228)
        end

        draw.RoundedBox(R8(), cardX, y, slotW, slotH, bg)
        surface.SetDrawColor(outline)
        surface.DrawOutlinedRect(cardX, y, slotW, slotH, 1)
        if selected then
            surface.SetDrawColor(selectedAccent)
            surface.DrawOutlinedRect(cardX + 1, y + 1, slotW - 2, slotH - 2, 1)
        end

        local keyLabel = ZSCAV:GetCustomHotbarKeyLabel(slotNumber)
        draw.SimpleText(keyLabel, Nexus:GetFont(14, nil, true), cardX + Nexus:Scale(7), y + Nexus:Scale(6), selected and textColor or dimColor)

        local roleLabel = ZSCAV_GetHotbarRoleLabelCL(slotNumber, entry)
        draw.SimpleText(roleLabel, Nexus:GetFont(11, nil, true), cardX + slotW - Nexus:Scale(6), y + Nexus:Scale(8), selected and selectedAccent or dimColor, TEXT_ALIGN_RIGHT)

        if entry and entry.class then
            local line1, line2 = ZSCAV_SplitHotbarTextCL(PrettyName(entry.class), slotNumber <= 3 and 10 or 11)
            draw.SimpleText(line1, Nexus:GetFont(13, nil, true), cardX + Nexus:Scale(7), y + Nexus:Scale(27), textColor)
            if line2 ~= "" then
                draw.SimpleText(line2, Nexus:GetFont(12), cardX + Nexus:Scale(7), y + Nexus:Scale(43), dimColor)
            end
            ZSCAV_DrawMedicalCounterBadgeCL(entry, cardX, y, slotW, slotH, {
                font = Nexus:GetFont(10, nil, true),
                marginX = Nexus:Scale(6),
                marginY = Nexus:Scale(22),
            })
        else
            local emptyText = slotNumber <= 3 and "EMPTY" or "UNBOUND"
            draw.SimpleText(emptyText, Nexus:GetFont(12, nil, true), cardX + Nexus:Scale(7), y + math.floor(slotH * 0.58), dimColor)
        end

        if slotNumber == 3 and inv.weapons.sidearm and inv.weapons.sidearm2 then
            draw.SimpleText("Swap", Nexus:GetFont(11), cardX + slotW - Nexus:Scale(6), y + slotH - Nexus:Scale(6), selected and selectedAccent or dimColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        end
    end
end)

-- ---------------------------------------------------------------------
-- Container snapshots (server → client)
-- ---------------------------------------------------------------------
net.Receive("ZScavContainerOpen", function()
    local sz = net.ReadUInt(32)
    if sz <= 0 or sz > 200000 then return end
    local raw = net.ReadData(sz)
    local data = util.JSONToTable(raw or "")
    if not istable(data) then return end

    -- Coerce numeric keys back from JSON string keys for safety.
    data.gw = tonumber(data.gw) or 4
    data.gh = tonumber(data.gh) or 4
    data.chain = data.chain or {}
    data.contents = data.contents or {}
    for _, it in ipairs(data.contents) do
        it.x, it.y = tonumber(it.x) or 0, tonumber(it.y) or 0
        it.w, it.h = tonumber(it.w) or 1, tonumber(it.h) or 1
    end

    local uid = tostring(data.uid or "")
    if uid == "" then return end

    -- Ensure inventory UI is open so windows have a parent.
    if not IsValid(PANEL_REF) then Build() end

    -- Chain root (chain[1]) → embed in the right panel (scrollable).
    -- The stash/mailbox pair may also embed as a shared secondary root.
    -- Nested containers → floating windows.
    local chainRoot = tostring((data.chain or {})[1] or "")
    local isRoot = (uid == chainRoot and chainRoot ~= "")
    -- Owned bags always use floating windows; right-panel roots are reserved for
    -- world loot plus the stash/mailbox pair.
    local forceWindow = data.owned == true

    if not forceWindow and (isRoot or ShouldEmbedSharedRightPanelState(uid, data)) then
        SetRightPanelContainer(uid, data)
        return
    end

    -- Enforce max floating-window limit (root in right panel not counted).
    local floatCount = 0
    for _, e in pairs(CONT_WINDOWS) do
        if e.panel and IsValid(e.panel) then floatCount = floatCount + 1 end
    end
    if not CONT_WINDOWS[uid] and floatCount >= MAX_CONT_WINDOWS then
        -- Evict oldest floating window (prefer chain order).
        local oldestUID = nil
        for _, chainUID in ipairs(data.chain or {}) do
            local e = CONT_WINDOWS[chainUID]
            if e and e.panel and IsValid(e.panel) then oldestUID = chainUID; break end
        end
        if not oldestUID then
            for k, e in pairs(CONT_WINDOWS) do
                if e.panel and IsValid(e.panel) then oldestUID = k; break end
            end
        end
        if oldestUID then
            CloseContainerWindow(oldestUID)
            SendContainerAction("close_window", { uid = oldestUID })
        end
    end

    CreateContainerWindow(PANEL_REF, uid, data)
end)

net.Receive("ZScavContainerClose", function()
    local uid = net.ReadString()
    CloseContainerWindow(uid)
end)

net.Receive("ZScavTraderTradeState", function()
    local payload = util.JSONToTable(net.ReadString() or "") or {}
    local previousUID = tostring(IsTraderTradeActive() and TRADER_TRADE_STATE.player_offer_uid or "")

    if payload.closed == true then
        TRADER_TRADE_STATE = nil
        local closingUID = tostring(payload.player_offer_uid or previousUID or "")
        if closingUID ~= "" then
            CloseContainerWindow(closingUID)
        end
    else
        TRADER_TRADE_STATE = payload
    end

    if IsValid(PANEL_REF) then
        UpdateTraderTradeUI()
    end
end)

-- Receive updated GearItems (layout blocks, compartments) from server.
net.Receive("ZScavGearItemsSync", function()
    local sz = net.ReadUInt(32)
    if sz <= 0 or sz > 64000 then return end
    local raw = net.ReadData(sz)
    local t = util.JSONToTable(raw or "")
    if not istable(t) then return end
    ZSCAV.GearItems = ZSCAV.GearItems or {}
    for class, def in pairs(t) do
        if isstring(class) and istable(def) then
            ZSCAV.GearItems[class] = ZSCAV.GearItems[class] or {}
            if def.layoutBlocks ~= nil then 
                ZSCAV.GearItems[class].layoutBlocks = def.layoutBlocks 
                _layoutBlocksCache[class] = def.layoutBlocks  -- Also update cache (Option C).
            end
            if def.internal ~= nil then ZSCAV.GearItems[class].internal = def.internal end
            if def.compartment ~= nil then ZSCAV.GearItems[class].compartment = def.compartment end
            if def.compartments ~= nil then ZSCAV.GearItems[class].compartments = def.compartments end
        end
    end
end)

concommand.Add("zscav_inv", function()
    ZSCAV.ToggleInventoryCL()
end)

concommand.Add("+zscav_inv", function()
    ZSCAV.BeginHoldInventoryCL()
end)

concommand.Add("-zscav_inv", function()
    ZSCAV.EndHoldInventoryCL()
end)

-- Receive updated BaseGrids from server (after admin applies config changes).
net.Receive("ZScavBaseGridsSync", function()
    local sz = net.ReadUInt(32)
    if sz <= 0 or sz > 64000 then return end
    local raw = net.ReadData(sz)
    local t = util.JSONToTable(raw or "")
    if not istable(t) then return end
    ZSCAV.BaseGrids = ZSCAV.BaseGrids or {}
    for k, v in pairs(t) do
        if istable(v) then
            ZSCAV.BaseGrids[k] = ZSCAV.BaseGrids[k] or {}
            if v.w ~= nil then ZSCAV.BaseGrids[k].w = tonumber(v.w) or 0 end
            if v.h ~= nil then ZSCAV.BaseGrids[k].h = tonumber(v.h) or 0 end
        end
    end
end)
