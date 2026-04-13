-- cl_block_failure_fade.lua
-- Blocks unexpected mid-round fade-to-black "failure screens".
--
-- Two independent layers:
--   zc_block_zb_fade  (default 1) – blocks the ZB_ScreenFade net overlay
--                                    (zh_pluvis.lua RenderScreenspaceEffects fade)
--   zc_block_env_fade (default 0) – periodically purges engine ScreenFade calls
--                                    (env_fade map entities, ply:ScreenFade from server)
--                                    NOTE: also suppresses round-end transition fades.
--                                    Enable only if you're seeing stuck black screens
--                                    from map entities mid-round.

if not CLIENT then return end

local CV_ZB  = CreateClientConVar("zc_block_zb_fade",  "1", true, false,
    "Block ZB_ScreenFade overlay (ZBattle pluvis fade)")
local CV_ENV = CreateClientConVar("zc_block_env_fade", "0", true, false,
    "Purge engine ScreenFade / env_fade mid-round blackouts (also suppresses round-end fade)")

-- ─────────────────────────────────────────────────────────────────
-- Layer 1: ZB_ScreenFade override
-- ZBattle sends this net message; the default receiver adds a
-- RenderScreenspaceEffects hook that fades in a full black rect.
-- We override the receiver so the message is silently discarded
-- when the cvar is on.
-- ─────────────────────────────────────────────────────────────────
net.Receive("ZB_ScreenFade", function()
    if CV_ZB:GetBool() then
        -- swallow; don't install the black overlay hook
        return
    end

    -- Reproduce original sh_pluvis.lua behaviour if cvar is off
    local fade = 0
    timer.Simple(6, function()
        hook.Add("RenderScreenspaceEffects", "ZB_ScreenFade", function()
            surface.SetDrawColor(0, 0, 0, 255 * fade)
            surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1)
            fade = Lerp(FrameTime() * 10, fade, 2)
        end)
        timer.Simple(2, function()
            hook.Remove("RenderScreenspaceEffects", "ZB_ScreenFade")
        end)
    end)
end)

-- ─────────────────────────────────────────────────────────────────
-- Layer 2: Engine ScreenFade purge
-- Runs every 0.4 s and clears any active engine screenfade.
-- Only fires when the cvar is enabled.
-- ─────────────────────────────────────────────────────────────────
local lastPurge = 0

hook.Add("Think", "DCityPatch_BlockEnvFade", function()
    if not CV_ENV:GetBool() then return end

    local now = CurTime()
    if now - lastPurge < 0.4 then return end
    lastPurge = now

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if not lp:Alive() then return end -- let death fades through

    lp:ScreenFade(SCREENFADE.PURGE, Color(0, 0, 0), 0, 0)
end)
