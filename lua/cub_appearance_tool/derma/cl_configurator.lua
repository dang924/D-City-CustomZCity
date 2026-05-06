if SERVER then return end

hg = hg or {}
hg.AppearanceTool = hg.AppearanceTool or {}

local TOOLMODULE = hg.AppearanceTool

local function CreateHost()
    local host = vgui.Create("DFrame")
    host:SetTitle("ZCity Appearance Tool Configurator")
    host:SetSize(math.floor(ScrW() * 0.9), math.floor(ScrH() * 0.92))
    host:Center()
    host:MakePopup()
    host:SetSizable(true)

    function host:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(12, 12, 18, 245))
        surface.SetDrawColor(Color(90, 90, 110, 255))
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local content = vgui.Create("EditablePanel", host)
    content:Dock(FILL)
    content:DockMargin(8, 8, 8, 8)
    host.Content = content

    return host
end

function TOOLMODULE.OpenConfigurator()
    if IsValid(TOOLMODULE.__ConfiguratorHost) then
        TOOLMODULE.__ConfiguratorHost:Remove()
    end

    local oldZpan = zpan
    local host = CreateHost()
    local panel = vgui.Create("ZCAT_AppearanceMenu", host.Content)
    panel:Dock(FILL)
    panel:SetName("HG_AppearanceMenu")
    panel:SetAppearance(TOOLMODULE.GetClientConfig())

    zpan = panel
    TOOLMODULE.__ConfiguratorHost = host

    function host:OnRemove()
        zpan = oldZpan
        if TOOLMODULE.__ConfiguratorHost == self then
            TOOLMODULE.__ConfiguratorHost = nil
        end
        if IsValid(panel) and not panel.__ZCATRemoving then
            panel.__ZCATRemoving = true
            panel:Remove()
        end
    end

    function panel:OnRemove(...)
        if self.CloseImportMenus then
            self:CloseImportMenus()
        end

        if IsValid(host) and not host.__ZCATRemoving then
            host.__ZCATRemoving = true
            host:Remove()
        else
            zpan = oldZpan
        end

        if TOOLMODULE.__ConfiguratorHost == host then
            TOOLMODULE.__ConfiguratorHost = nil
        end
    end
end
