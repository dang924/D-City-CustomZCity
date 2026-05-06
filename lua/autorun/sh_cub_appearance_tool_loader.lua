if SERVER then
    AddCSLuaFile()
end

hg = hg or {}
hg.AppearanceTool = hg.AppearanceTool or {}

local ROOT = "cub_appearance_tool/"

local sides = {
    ["sv_"] = "sv_",
    ["sh_"] = "sh_",
    ["cl_"] = "cl_",
    ["_sv"] = "sv_",
    ["_sh"] = "sh_",
    ["_cl"] = "cl_",
}

local function AddFile(path)
    local fileName = string.GetFileFromFilename(path)
    local fileSide = string.lower(string.Left(fileName, 3))
    local fileSide2 = string.lower(string.Right(string.sub(fileName, 1, -5), 3))
    local side = sides[fileSide] or sides[fileSide2]

    if side == "sv_" then
        if SERVER then
            include(path)
        end
    elseif side == "sh_" then
        if SERVER then
            AddCSLuaFile(path)
        end

        include(path)
    elseif side == "cl_" then
        if SERVER then
            AddCSLuaFile(path)
        else
            include(path)
        end
    else
        if SERVER then
            AddCSLuaFile(path)
        end

        include(path)
    end
end

local function IncludeDir(dir)
    local files, directories = file.Find(dir .. "*", "LUA")

    for _, fileName in ipairs(files or {}) do
        if string.EndsWith(fileName, ".lua") then
            AddFile(dir .. fileName)
        end
    end

    for _, directoryName in ipairs(directories or {}) do
        IncludeDir(dir .. directoryName .. "/")
    end
end

local function LoadAppearanceTool()
    if hg.__CubAppearanceToolLoaded then return end
    hg.__CubAppearanceToolLoaded = true

    AddFile(ROOT .. "sh_core.lua")
    AddFile(ROOT .. "sv_runtime.lua")
    AddFile(ROOT .. "cl_runtime.lua")
    AddFile(ROOT .. "cl_imports.lua")
    IncludeDir(ROOT .. "derma/")
end

hook.Add("HomigradRun", "CubAppearanceToolLoad", LoadAppearanceTool)
hook.Add("Initialize", "CubAppearanceToolLoadInitialize", LoadAppearanceTool)
hook.Add("InitPostEntity", "CubAppearanceToolLoadInitPostEntity", LoadAppearanceTool)
hook.Add("OnGamemodeLoaded", "CubAppearanceToolLoadOnGamemodeLoaded", LoadAppearanceTool)
hook.Add("PostGamemodeLoaded", "CubAppearanceToolLoadPostGamemodeLoaded", LoadAppearanceTool)

timer.Simple(0, LoadAppearanceTool)
timer.Simple(1, LoadAppearanceTool)

if hg.loaded then
    LoadAppearanceTool()
end
