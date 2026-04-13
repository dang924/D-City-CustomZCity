-- Z-City Scoreboard Nil Fix
-- Patches the undefined 'lply' variable in cl_init.lua:698

if SERVER then return end

-- Hook to fix the scoreboard panel creation error
hook.Add("InitPostEntity", "ZCity_ScoreBoardFix", function()
    -- Define lply globally so it's accessible in the scoreboard function
    -- This fixes the "attempt to index a nil value" error at line 698
    _G.lply = LocalPlayer()
    
    -- Update it whenever scoreboard is opened
    local origOpenFunc = hg and hg.OpenScoreBoard
    if origOpenFunc then
        hg.OpenScoreBoard = function()
            _G.lply = LocalPlayer()
            return origOpenFunc()
        end
    end
end)

-- Alternative: Hook the scoreboard panel creation
hook.Add("CreateMove", "ZCity_UpdateLocalPlayer", function()
    if _G.lply and not IsValid(_G.lply) then
        _G.lply = LocalPlayer()
    elseif not _G.lply then
        _G.lply = LocalPlayer()
    end
end)
