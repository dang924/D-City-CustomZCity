-- Z-City Command Access Level Type Fix
-- Fixes the "attempt to compare number with string" error in sv_commands.lua:26

if CLIENT then return end

-- Wait for core Z-City to load its command system
hook.Add("InitPostEntity", "FixCommandAccessTypes", function()
    -- Check if COMMAND_ACCES exists
    if COMMAND_ACCES then
        -- Store the original function
        local originalCOMMAND_ACCES = COMMAND_ACCES
        
        -- Replace it with a version that ensures access level is a number
        _G.COMMAND_ACCES = function(ply, cmd)
            local access = cmd[2] or 1
            
            -- Convert access to number if it's a string
            if type(access) == "string" then
                access = tonumber(access) or 1
            end
            
            -- Original logic, but with safe type conversion
            local playerAccess = COMMAND_GETACCES(ply)
            if access ~= 0 and playerAccess < access then 
                return 
            end
            
            return true
        end
    end
end)

-- Also patch COMMAND_GETACCES to ensure it always returns a number
hook.Add("InitPostEntity", "FixCommandGetAccessTypes", function()
    if COMMAND_GETACCES then
        local originalCOMMAND_GETACCES = COMMAND_GETACCES
        
        _G.COMMAND_GETACCES = function(ply)
            local result = originalCOMMAND_GETACCES(ply)
            -- Ensure result is a number
            return tonumber(result) or 0
        end
    end
end)
