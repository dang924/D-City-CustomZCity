-- sv_rotor_occupant_fix.lua
-- DCityPatch1.1
--
-- Glide's glide_rotor trace filter is built at Initialize time:
--   filter = { self, self:GetParent() }
-- Players seated in the vehicle are not in the filter, so the spinning
-- rotor trace hits and kills occupants. This patches CheckRotorClearance
-- to rebuild the filter each tick using the vehicle's seats table directly
-- (vehicle.seats is the authoritative list of prop_vehicle_prisoner_pod
-- entities that Glide manages, each carrying GlideSeatIndex).

if CLIENT then return end

local function ApplyRotorFix()
    local stored = scripted_ents.GetStored("glide_rotor")
    if not stored or not stored.t then return false end
    if stored.t._DCityRotorPatched then return true end

    local original = stored.t.CheckRotorClearance
    if not original then return false end

    stored.t.CheckRotorClearance = function(self, dt, parent)
        local filter = { self, parent }

        -- parent.seats is the table Glide builds in base_glide:CreateSeat.
        -- Each entry is a prop_vehicle_prisoner_pod. Its current driver
        -- is the occupant we need to exclude.
        if IsValid(parent) and istable(parent.seats) then
            for _, seat in pairs(parent.seats) do
                if IsValid(seat) then
                    local occupant = seat:GetDriver()
                    if IsValid(occupant) then
                        filter[#filter + 1] = occupant
                        -- Exclude homigrad fake ragdoll too
                        if IsValid(occupant.FakeRagdoll) then
                            filter[#filter + 1] = occupant.FakeRagdoll
                        end
                    end
                end
            end
        end

        self.traceData.filter = filter
        return original(self, dt, parent)
    end

    stored.t._DCityRotorPatched = true
    print("[DCityPatch] Rotor occupant fix applied.")
    return true
end

hook.Add("InitPostEntity", "DCityPatch_RotorOccupantFix", function()
    timer.Simple(1, function()
        if not ApplyRotorFix() then
            print("[DCityPatch] WARNING: glide_rotor not found, rotor fix not applied.")
        end
    end)
end)
