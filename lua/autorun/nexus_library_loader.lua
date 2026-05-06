Nexus = Nexus or {}
Nexus.Config = Nexus.Config or {}

function Nexus:LoadServer(path, bool)
    print("[ Nexus ] "..(bool and "pre-" or "").."loaded sv: "..path)
    include(path)
end

function Nexus:LoadClient(path, bool)
    print("[ Nexus ] "..(bool and "pre-" or "").."loaded cl: "..path)
    if SERVER then
        AddCSLuaFile(path)
    else
        include(path)
    end
end

function Nexus:LoadShared(path, bool)
    print("[ Nexus ] "..(bool and "pre-" or "").."loaded sh: "..path)
    if SERVER then
        AddCSLuaFile(path)
    end
    include(path)
end

function Nexus:LoadFile(path, bool)
    bool = bool or false

    local explode = string.Explode("/", path)
    local fileStr = explode[#explode]

    local fileSide = string.lower(string.Left(fileStr, 3))
    if SERVER and fileSide == "sv_" then
        Nexus:LoadServer(path, bool)
    elseif fileSide == "sh_" then
        Nexus:LoadShared(path, bool)
    elseif fileSide == "cl_" then
        Nexus:LoadClient(path, bool)
    end
end

local filesToLoad = {}
local function GetDirectoryFiles(dir)
    dir = dir.."/"

    local File, Directory = file.Find(dir.."*", "LUA")
    for k, v in ipairs(File) do
        if string.EndsWith(v, ".lua") then
            table.insert(filesToLoad, dir..v)
        end
    end

    for k, v in ipairs(Directory) do
        if dir..v == "nexus_library/modules" then continue end
        GetDirectoryFiles(dir..v)
    end
end

function Nexus:LoadDirectory(dir, loadFirst)
    local curTime = CurTime()
    loadFirst = loadFirst or {}
    print("\n\n\n[Nexus] loading directory: "..dir.."\n")

    filesToLoad = {}
    GetDirectoryFiles(dir)

    for _, path in ipairs(loadFirst) do
        Nexus:LoadFile(path, true)
    end

    local formatedFirst = {}
    for _, path in ipairs(loadFirst) do
        formatedFirst[path] = true
    end

    for _, path in ipairs(filesToLoad) do
        if formatedFirst[path] then continue end
        Nexus:LoadFile(path)
    end

    print("\n[Nexus] successfully loaded: "..(CurTime()-curTime).."\n\n\n")
end

Nexus:LoadDirectory("nexus_library")
Nexus:LoadDirectory("nexus_library/modules")

hook.Run("Nexus:Loaded")


hook.Add("InitPostEntity", "Nexus:Addons:Loaded", function()
    if Nexus and (Nexus.JobCreator or Nexus.Battlepass or Nexus.Leaderboards or Nexus.Suits) and game.IsDedicated() then
        local msg = {
            {"text", "please remove this version of Nexus Library from your server"},
            {"button", "https://steamcommunity.com/sharedfiles/filedetails/?id=3263834890"},
            {"text", "and install this version of the nexus library"},
            {"text", "or your nexus addons will become out of date and break"},
            {"button", "https://steamcommunity.com/sharedfiles/filedetails/?id=3402202751"},
            {"text", "and restart your server!"},
        }
        if CLIENT then
            local frame = vgui.Create("Nexus:Frame")
            frame:SetSize(Nexus:Scale(500), Nexus:Scale(500))
            frame:Center()
            frame:SetTitle("Nexus")
            frame:MakePopup()
            for _, v in ipairs(msg) do
                if v[1] == "text" then
                    local lbl = frame:Add("DLabel")
                    lbl:Dock(TOP)
                    lbl:SetText(v[2])
                    lbl:SetFont(Nexus:GetFont(20))
                    lbl:SizeToContents()
                    lbl:SetContentAlignment(5)
                elseif v[1] == "button" then
                    local button = frame:Add("Nexus:Button")
                    button:Dock(TOP)
                    button:DockMargin(Nexus:Scale(20), Nexus:Scale(5), Nexus:Scale(20), Nexus:Scale(5))
                    button:SetText("Open")
                    button:SetTall(Nexus:Scale(40))
                    button.DoClick = function()
                        gui.OpenURL(v[2])
                    end
                end
            end
        end
    end
end)

timer.Create("Nexus:AddonsLoaded", 2, 0, function()
    if Nexus and (Nexus.JobCreator or Nexus.Battlepass or Nexus.Leaderboards or Nexus.Suits) then
        local msg = {
            {"text", "please remove this version of Nexus Library from your server"},
            {"button", "https://steamcommunity.com/sharedfiles/filedetails/?id=3263834890"},
            {"text", "and install this version of the nexus library"},
            {"text", "or your nexus addons will become out of date and break"},
            {"button", "https://steamcommunity.com/sharedfiles/filedetails/?id=3402202751"},
            {"text", "and restart your server!"},
        }
        
        for _, v in ipairs(msg) do
            print(v[2])
        end
    end
end)