hg = hg or {}

local SLIDERS_ROOT = "homigrad/new_appearance/sliders/"

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

    if SERVER and side == "sv_" then
        include(path)
    elseif side == "sh_" then
        if SERVER then AddCSLuaFile(path) end
        include(path)
    elseif side == "cl_" then
        if SERVER then
            AddCSLuaFile(path)
        else
            include(path)
        end
    else
        if SERVER then AddCSLuaFile(path) end
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

    for _, dirName in ipairs(directories or {}) do
        IncludeDir(dir .. dirName .. "/")
    end
end

local function LoadSlidersModule()
    if hg.__CubSlidersLoaded then return end
    hg.__CubSlidersLoaded = true
    IncludeDir(SLIDERS_ROOT)
end

local function EnsureSlidersModuleLoaded()
    if hg.__CubSlidersLoaded then return end
    LoadSlidersModule()
end

hook.Add("HomigradRun", "CubSlidersLoadAppearanceSliders", EnsureSlidersModuleLoaded)
hook.Add("Initialize", "CubSlidersLoadAppearanceSlidersInitialize", EnsureSlidersModuleLoaded)
hook.Add("InitPostEntity", "CubSlidersLoadAppearanceSlidersInitPostEntity", EnsureSlidersModuleLoaded)
hook.Add("OnGamemodeLoaded", "CubSlidersLoadAppearanceSlidersOnGamemodeLoaded", EnsureSlidersModuleLoaded)
hook.Add("PostGamemodeLoaded", "CubSlidersLoadAppearanceSlidersPostGamemodeLoaded", EnsureSlidersModuleLoaded)

timer.Simple(0, EnsureSlidersModuleLoaded)
timer.Simple(1, EnsureSlidersModuleLoaded)
timer.Simple(5, EnsureSlidersModuleLoaded)

if hg.loaded then
    EnsureSlidersModuleLoaded()
end
