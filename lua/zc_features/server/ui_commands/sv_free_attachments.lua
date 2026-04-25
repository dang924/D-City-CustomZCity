-- Free attachment menu — server side.
-- Any player can open the attachment menu via !attachments or ulx attachments.
-- Attachments are granted instantly with no cost.

if CLIENT then return end

util.AddNetworkString("ZC_FreeAtt_Request")
util.AddNetworkString("ZC_FreeAtt_Open")
util.AddNetworkString("ZC_FreeAtt_Grant")
util.AddNetworkString("ZC_FreeAtt_Apply")  -- alias used by client

local FALLBACK_ATTACHMENTS = {
    -- Sights
    { label = "EOTech XPS",              attKey = "holo1",        placement = "sight" },
    { label = "Kobra EKP",               attKey = "holo2",        placement = "sight" },
    { label = "SIG Romeo 8T",            attKey = "holo3",        placement = "sight" },
    { label = "Walther MRS",             attKey = "holo4",        placement = "sight" },
    { label = "OKP-7",                   attKey = "holo5",        placement = "sight" },
    { label = "OKP-7 Dovetail",          attKey = "holo6",        placement = "sight" },
    { label = "Belomo PK-06",            attKey = "holo7",        placement = "sight" },
    { label = "Holosun HS401",           attKey = "holo8",        placement = "sight" },
    { label = "Leapers UTG 1x30",        attKey = "holo9",        placement = "sight" },
    { label = "Trijicon SRS-02",         attKey = "holo11",       placement = "sight" },
    { label = "Valday 1P87",             attKey = "holo12",       placement = "sight" },
    { label = "Valday Krechet",          attKey = "holo13",       placement = "sight" },
    { label = "EOTech XPS3",             attKey = "holo14",       placement = "sight" },
    { label = "SIG Romeo 4",             attKey = "holo15",       placement = "sight" },
    { label = "Trijicon RMR",            attKey = "holo16",       placement = "sight" },
    { label = "Compact Prism",           attKey = "holo17",       placement = "sight" },
    { label = "Fullfield Tac30",         attKey = "optic2",       placement = "sight" },
    { label = "Valday PS-320",           attKey = "optic3",       placement = "sight" },
    { label = "PSO-1M2",                 attKey = "optic4",       placement = "sight" },
    { label = "Razor HD",                attKey = "optic5",       placement = "sight" },
    { label = "Leupold Mark 4",          attKey = "optic6",       placement = "sight" },
    { label = "SIG Bravo4",              attKey = "optic7",       placement = "sight" },
    { label = "Leupold HAMR",            attKey = "optic8",       placement = "sight" },
    { label = "ACOG TA01",               attKey = "optic9",       placement = "sight" },
    { label = "PSO-1M2 (Alt)",           attKey = "optic11",      placement = "sight" },
    { label = "EOTech Vudu",             attKey = "optic12",      placement = "sight" },
    { label = "NPZ PAG-17",              attKey = "optic13",      placement = "sight" },
    { label = "Torrey T12W Thermal",     attKey = "optic14",      placement = "sight" },
    { label = "Ultima DIY Thermal",      attKey = "optic15",      placement = "sight" },
    { label = "MBUS Rear",               attKey = "ironsight1",   placement = "sight" },
    { label = "A2 Rear",                 attKey = "ironsight2",   placement = "sight" },
    { label = "A2 Front",                attKey = "ironsight3",   placement = "sight" },
    { label = "MBUS Front",              attKey = "ironsight4",   placement = "sight" },
    -- Mounts
    { label = "AK Rail Mount",           attKey = "mount1",       placement = "mount" },
    { label = "LaRue QD Riser",          attKey = "mount2",       placement = "mount" },
    { label = "Dovetail Pilad",          attKey = "mount3",       placement = "mount" },
    { label = "Pistol UM3 Mount",        attKey = "mount4",       placement = "mount" },
    -- Barrels
    { label = "AK Suppressor",           attKey = "supressor1",   placement = "barrel" },
    { label = "5.56 Suppressor",         attKey = "supressor2",   placement = "barrel" },
    { label = "Pistol Suppressor",       attKey = "supressor3",   placement = "barrel" },
    { label = "9mm Suppressor",          attKey = "supressor4",   placement = "barrel" },
    { label = "12ga Suppressor",         attKey = "supressor5",   placement = "barrel" },
    { label = "Makeshift Suppressor",    attKey = "supressor6",   placement = "barrel" },
    { label = "SRD 762 QD Suppressor",   attKey = "supressor7",   placement = "barrel" },
    { label = "Hybrid 46 Suppressor",    attKey = "supressor8",   placement = "barrel" },
    -- Grips
    { label = "RK-2 Foregrip",           attKey = "grip1",        placement = "grip" },
    { label = "ASh-12 Foregrip",         attKey = "grip2",        placement = "grip" },
    { label = "AFG Foregrip",            attKey = "grip3",        placement = "grip" },
    { label = "AKS-74U Woodgrip",        attKey = "grip_akdong",  placement = "grip" },
    -- Underbarrel
    { label = "NCSTAR Laser",            attKey = "laser1",       placement = "underbarrel" },
    { label = "Kleh2 Laser",             attKey = "laser2",       placement = "underbarrel" },
    { label = "Baldr Pro Laser",         attKey = "laser3",       placement = "underbarrel" },
    { label = "AN/PEQ-2 Laser",          attKey = "laser4",       placement = "underbarrel" },
    { label = "Rail Laser",              attKey = "laser5",       placement = "underbarrel" },
    -- Magwell
    { label = "Glock Drum Mag (50)",     attKey = "mag1",         placement = "magwell" },
}

local ATT_CACHE = {
    list = nil,
    keySet = nil,
    expiresAt = 0,
}

local function PrettyAttachmentKey(attKey)
    local s = tostring(attKey or "")
    s = string.Replace(s, "_", " ")
    s = string.gsub(s, "(%a)([%w_']*)", function(a, b)
        return string.upper(a) .. string.lower(b)
    end)
    return s
end

local function ResolveAttachmentName(attKey, placement, attData)
    local dict = (hg and (hg.attachmentslaunguage or hg.attachmentslanguage)) or nil
    if istable(dict) and isstring(dict[attKey]) and dict[attKey] ~= "" then
        return dict[attKey]
    end

    if istable(attData) then
        if isstring(attData.name) and attData.name ~= "" then
            return attData.name
        end
        if isstring(attData.PrintName) and attData.PrintName ~= "" then
            return attData.PrintName
        end
    end

    return PrettyAttachmentKey(attKey)
end

local function BuildAttachmentList()
    if ATT_CACHE.list and CurTime() < ATT_CACHE.expiresAt then
        return ATT_CACHE.list
    end

    local list = {}

    if hg and istable(hg.validattachments) then
        for placement, placementTbl in pairs(hg.validattachments) do
            if not istable(placementTbl) then continue end

            for attKey, attData in pairs(placementTbl) do
                if not isstring(attKey) or attKey == "" then continue end
                list[#list + 1] = {
                    label = ResolveAttachmentName(attKey, placement, attData),
                    attKey = attKey,
                    placement = tostring(placement or "other"),
                }
            end
        end
    end

    if #list == 0 then
        list = table.Copy(FALLBACK_ATTACHMENTS)
    end

    table.sort(list, function(a, b)
        local ap = tostring(a.placement or "")
        local bp = tostring(b.placement or "")
        if ap ~= bp then return ap < bp end
        return tostring(a.label or "") < tostring(b.label or "")
    end)

    local keySet = {}
    for _, att in ipairs(list) do
        keySet[att.attKey] = true
    end

    ATT_CACHE.list = list
    ATT_CACHE.keySet = keySet
    ATT_CACHE.expiresAt = CurTime() + 5

    return list
end

local function IsValidAttachmentKey(attKey)
    if not isstring(attKey) or attKey == "" then return false end
    BuildAttachmentList()
    return ATT_CACHE.keySet and ATT_CACHE.keySet[attKey] or false
end

local function OpenAttachmentMenuFor(ply)
    if not IsValid(ply) then return false, "invalid player" end
    if not ply:Alive() then return false, "not alive" end

    local attachments = BuildAttachmentList()
    if #attachments == 0 then
        return false, "attachment registry unavailable"
    end

    net.Start("ZC_FreeAtt_Open")
        net.WriteUInt(#attachments, 12)
        for _, att in ipairs(attachments) do
            net.WriteString(att.label)
            net.WriteString(att.attKey)
            net.WriteString(att.placement)
        end
    net.Send(ply)

    return true
end

-- Used by ULX module sh_ulx_attachments.lua
ZC_OpenAttachmentMenu = OpenAttachmentMenuFor

-- Send attachment list to client on request
net.Receive("ZC_FreeAtt_Request", function(_, ply)
    OpenAttachmentMenuFor(ply)
end)

-- Backward compatibility for older clients that still request on _Open.
net.Receive("ZC_FreeAtt_Open", function(_, ply)
    OpenAttachmentMenuFor(ply)
end)

-- Grant attachment — listens on both names (Grant = legacy, Apply = client alias)
local function HandleGrant(len, ply)
    if not IsValid(ply) then return end
    if not ply:Alive() then
        ply:ChatPrint("[Attachments] You must be alive to equip attachments.")
        return
    end

    local attKey = net.ReadString()

    -- Validate key is in our list
    if not IsValidAttachmentKey(attKey) then return end

    local inv = ply:GetNetVar("Inventory", {})
    inv.Attachments = inv.Attachments or {}

    if not table.HasValue(inv.Attachments, attKey) then
        inv.Attachments[#inv.Attachments + 1] = attKey
        ply:SetNetVar("Inventory", inv)
        ply:ChatPrint("[Attachments] Unlocked — equip it from your weapon's attachment menu.")
    else
        ply:ChatPrint("[Attachments] You already have that attachment.")
    end
end
net.Receive("ZC_FreeAtt_Grant", HandleGrant)
net.Receive("ZC_FreeAtt_Apply", HandleGrant)

local function HandleAttachmentsChat(ply, txtTbl)
    if not IsValid(ply) or not ply:Alive() then
        if IsValid(ply) then
            ply:ChatPrint("[Attachments] You must be alive to use this.")
        end
        if istable(txtTbl) then txtTbl[1] = "" end
        return true
    end

    if istable(txtTbl) then txtTbl[1] = "" end
    OpenAttachmentMenuFor(ply)
    return true
end

if ZC_RegisterExactChatCommand then
    ZC_RegisterExactChatCommand("!attachments", HandleAttachmentsChat)
    ZC_RegisterExactChatCommand("/attachments", HandleAttachmentsChat)
else
    hook.Add("HG_PlayerSay", "ZCity_FreeAttachments", function(ply, txtTbl, text)
        local cmd = string.lower(string.Trim(text or ""))
        if cmd ~= "!attachments" and cmd ~= "/attachments" then return end
        return HandleAttachmentsChat(ply, txtTbl)
    end)
end
