-- Free Attachment Menu — ULX Module
-- Accessible to all players via !attachments or ulx attachments.
-- No admin access required — this is a quality-of-life tool for everyone.

if not ulx then return end

local CATEGORY_NAME = "Attachments"

-- ulx attachments [target] — open attachment menu for self or another player (admin+)
local function ulxAttachments(calling_ply, target_ply)
    local target = target_ply or calling_ply
    if not IsValid(target) then return end

    if target ~= calling_ply and not calling_ply:IsAdmin() then
        ULib.tsay(calling_ply, "You can only open the attachment menu for yourself.")
        return
    end

    if not target:Alive() then
        ULib.tsay(calling_ply, target:Nick() .. " must be alive to use the attachment menu.")
        return
    end

    if ZC_OpenAttachmentMenu then
        ZC_OpenAttachmentMenu(target)
    else
        ULib.tsay(calling_ply, "Attachment menu not loaded — ensure sv_free_attachments.lua is installed.")
    end

    if target ~= calling_ply then
        ULib.log(calling_ply:Nick() .. " opened attachment menu for " .. target:Nick())
    end
end

local cmd = ulx.command(CATEGORY_NAME, "ulx attachments", ulxAttachments)
cmd:addParam{
    type    = ULib.cmds.PlayerArg,
    ULib.cmds.optional,
    ULib.cmds.allowSelf,
}
cmd:defaultAccess(ULib.ACCESS_ALL)
cmd:help("Open the free attachment menu.")
