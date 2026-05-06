ZSCAV = ZSCAV or {}
ZSCAV.ServerHelpers = ZSCAV.ServerHelpers or {}

local helpers = ZSCAV.ServerHelpers
local BAG_OPEN_DELAY = 1.25
local BAG_OPEN_RANGE_SQR = 200 * 200 -- keep in sync with container access range
local DEFERRED_CONTAINER_OPEN_RETRY_DELAY = 0.05
local DEFERRED_CONTAINER_OPEN_RETRY_COUNT = 40
local pendingBagOpen = {}

local function OpenContainerForPlayerDeferred(ply, uid, class, ent)
    if not (IsValid(ply) and uid and uid ~= "") then return false end

    if ZSCAV and isfunction(ZSCAV.OpenContainerForPlayer) then
        ZSCAV:OpenContainerForPlayer(ply, uid, class, ent)
        return true
    end

    local timerName = string.format("ZSCAV_DeferredContainerOpen_%d_%s", ply:EntIndex(), tostring(uid))
    timer.Create(timerName, DEFERRED_CONTAINER_OPEN_RETRY_DELAY, DEFERRED_CONTAINER_OPEN_RETRY_COUNT, function()
        if not IsValid(ply) then
            timer.Remove(timerName)
            return
        end

        if ZSCAV and isfunction(ZSCAV.OpenContainerForPlayer) then
            timer.Remove(timerName)
            ZSCAV:OpenContainerForPlayer(ply, uid, class, ent)
            return
        end

        if timer.RepsLeft(timerName) ~= 0 then return end

        local notice = helpers.Notice
        if isfunction(notice) then
            notice(ply, "Container system still initializing. Try again.")
        else
            ply:ChatPrint("[ZScav] Container system still initializing. Try again.")
        end
    end)

    return true
end

helpers.OpenContainerForPlayerDeferred = OpenContainerForPlayerDeferred

local function BagOpenProgressStart(ply, duration, class)
    if not IsValid(ply) then return end
    net.Start("ZScavBagOpenProgress")
        net.WriteBool(true)
        net.WriteFloat(CurTime() + math.max(duration or BAG_OPEN_DELAY, 0))
        net.WriteFloat(math.max(duration or BAG_OPEN_DELAY, 0))
        net.WriteString(tostring(class or ""))
    net.Send(ply)
end

local function BagOpenProgressStop(ply)
    if not IsValid(ply) then return end
    net.Start("ZScavBagOpenProgress")
        net.WriteBool(false)
        net.WriteFloat(0)
        net.WriteFloat(0)
        net.WriteString("")
    net.Send(ply)
end

local function CancelPendingBagOpen(ply)
    if not IsValid(ply) then return end
    local st = pendingBagOpen[ply]
    if not st then return end
    pendingBagOpen[ply] = nil
    timer.Remove(st.timerName)
    BagOpenProgressStop(ply)
end

local function StartPendingBagOpen(ply, uid, class, ent)
    if not IsValid(ply) or not uid or uid == "" then return end

    local cur = pendingBagOpen[ply]
    if cur and cur.uid == uid and cur.ent == ent then return end
    if cur then CancelPendingBagOpen(ply) end

    local tname = "ZSCAV_BagOpen_" .. tostring(ply:EntIndex())
    local st = {
        uid = uid,
        class = class,
        ent = ent,
        finishAt = CurTime() + BAG_OPEN_DELAY,
        timerName = tname,
    }
    pendingBagOpen[ply] = st
    BagOpenProgressStart(ply, BAG_OPEN_DELAY, class)

    timer.Create(tname, 0.05, 0, function()
        if not IsValid(ply) then
            CancelPendingBagOpen(ply)
            return
        end

        local nowSt = pendingBagOpen[ply]
        if nowSt ~= st then
            timer.Remove(tname)
            return
        end

        if not ZSCAV:IsActive() then
            CancelPendingBagOpen(ply)
            return
        end

        -- Keep the explicit ATTACK2+USE gesture to start, but only require
        -- USE to stay held after that point. Some weapon/hands paths can
        -- consume IN_ATTACK2 before the open timer finishes.
        if not ply:KeyDown(IN_USE) then
            CancelPendingBagOpen(ply)
            return
        end

        local okRange = false
        if IsValid(st.ent) and ZSCAV:GetEntPackUID(st.ent) == st.uid then
            okRange = st.ent:GetPos():DistToSqr(ply:GetPos()) <= BAG_OPEN_RANGE_SQR
        end
        if not okRange then
            CancelPendingBagOpen(ply)
            helpers.Notice(ply, "Container out of reach.")
            return
        end

        if CurTime() >= st.finishAt then
            CancelPendingBagOpen(ply)
            OpenContainerForPlayerDeferred(ply, st.uid, st.class, st.ent)
        end
    end)
end

hook.Add("PlayerDisconnected", "ZSCAV_CancelBagOpenOnLeave", function(ply)
    helpers.FlushSecurePersistence(ply)
    CancelPendingBagOpen(ply)
end)

hook.Add("ShutDown", "ZSCAV_FlushSecureOnShutdown", function()
    for _, ply in player.Iterator() do
        if IsValid(ply) then
            helpers.FlushSecurePersistence(ply)
        end
    end
end)

local function IsStaff(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    if ply:IsAdmin() then return true end
    return false
end

local function NormalizeConfiguredLookupClass(class)
    class = tostring(class or ""):lower()
    if class == "" then return "" end

    if ZSCAV.GetCanonicalItemClass then
        local canonical = tostring(ZSCAV:GetCanonicalItemClass(class) or ""):lower()
        if canonical ~= "" then
            return canonical
        end
    end

    return class
end

local function IsConfiguredItemClass(class)
    class = tostring(class or ""):lower()
    if ZSCAV.IsAttachmentItemClass and ZSCAV:IsAttachmentItemClass(class) and ZSCAV.GetAttachmentItemClass then
        class = tostring(ZSCAV:GetAttachmentItemClass(class) or class):lower()
    end
    local lookupClass = NormalizeConfiguredLookupClass(class)
    if istable(ZSCAV.ConfiguredItemMetaClasses) and not ZSCAV.ConfiguredItemMetaClasses[lookupClass] then
        return false
    end
    local m = ZSCAV.GetItemMeta and ZSCAV:GetItemMeta(class) or (ZSCAV.ItemMeta and ZSCAV.ItemMeta[lookupClass] or nil)
    if not istable(m) then return false end
    return (tonumber(m.w) or 0) > 0 and (tonumber(m.h) or 0) > 0
end

local function IsConfiguredGearClass(class)
    class = tostring(class or ""):lower()
    local lookupClass = NormalizeConfiguredLookupClass(class)
    if istable(ZSCAV.ConfiguredGearClasses) and not ZSCAV.ConfiguredGearClasses[lookupClass] then
        return false
    end
    local g = ZSCAV.GetGearDef and ZSCAV:GetGearDef(class) or (ZSCAV.GearItems and ZSCAV.GearItems[lookupClass] or nil)
    if not istable(g) then return false end
    if (tonumber(g.w) or 0) <= 0 or (tonumber(g.h) or 0) <= 0 then return false end
    if g.compartment then
        local internal = g.internal or {}
        if (tonumber(internal.w) or 0) <= 0 or (tonumber(internal.h) or 0) <= 0 then
            return false
        end
    end
    return true
end

local function HandleUnconfiguredPickup(ply, class, isGear)
    class = tostring(class or ""):lower()
    if class == "" then return true end

    local configured = isGear and IsConfiguredGearClass(class) or IsConfiguredItemClass(class)
    if configured then return false end

    ply.zscav_cfg_prompt_until = ply.zscav_cfg_prompt_until or {}
    local key = (isGear and "gear:" or "item:") .. class
    if (ply.zscav_cfg_prompt_until[key] or 0) > CurTime() then
        return true
    end
    ply.zscav_cfg_prompt_until[key] = CurTime() + 1.0

    if IsStaff(ply) then
        if ZSCAV.OpenConfigForClass then
            ZSCAV:OpenConfigForClass(ply, class)
            ply:ChatPrint("[ZScav] Not configured: " .. class .. " (configure it before pickup).")
        else
            ply:ChatPrint("[ZScav] Not configured: " .. class)
        end
    else
        ply:ChatPrint("Not Configured")
    end

    return true
end

helpers.StartPendingBagOpen = StartPendingBagOpen
helpers.HandleUnconfiguredPickup = HandleUnconfiguredPickup