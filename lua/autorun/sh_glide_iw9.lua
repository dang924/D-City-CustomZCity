if CLIENT then
    list.Set( "GlideCategories", "Neekosharediw9", {
        name = "Modern Warfare II",
        icon = "glide/icons/beeic.png"
    } )
end

hook.Add( "InitPostEntity", "iw9veh.GlideCheck", function()
    if Glide then return end

    timer.Simple( 5, function()

        local BASE_ADDON_NAME = "Glide // Styled's Vehicle Base"
        local SUB_ADDON_NAME = "Neeko's Glide Vehicles"

        local colorHighlight = Color( 255, 0, 0 )
        local colorText = Color( 255, 200, 200 )

        local function Print( ... )
            if SERVER then MsgC( ..., "\n" ) end
            if CLIENT then chat.AddText( ... ) end
        end

        Print(
            colorHighlight, SUB_ADDON_NAME,
            colorText, " is installed, but ",
            colorHighlight, BASE_ADDON_NAME,
            colorText, " is missing! Please install the base addon."
        )

    end )
end )

sound.Add( {
	name = "iw9.aircraft.impact.light",
	channel = CHAN_AUTO,
	volume = 1.0,
	level = 90,
	pitch = {90,105},
	sound = {"neek0/iw9/veh/shared/impact/aircraft_light-01.wav",
             "neek0/iw9/veh/shared/impact/aircraft_light-02.wav",
             "neek0/iw9/veh/shared/impact/aircraft_light-03.wav",
             "neek0/iw9/veh/shared/impact/aircraft_light-04.wav"
            }
} )

sound.Add( {
	name = "iw9.aircraft.impact.heavy",
	channel = CHAN_AUTO,
	volume = 1.0,
	level = 90,
	pitch = {90,105},
	sound = {"neek0/iw9/veh/shared/impact/aircraft_heavy-01.wav",
             "neek0/iw9/veh/shared/impact/aircraft_heavy-02.wav",
             "neek0/iw9/veh/shared/impact/aircraft_heavy-03.wav",
             "neek0/iw9/veh/shared/impact/aircraft_heavy-04.wav"
            }
} )

sound.Add( {
	name = "iw9.Flares.Deploy",
	channel = CHAN_AUTO,
	volume = 1.0,
	level = 120,
	pitch = {95,105},
	sound = "^neek0/iw9/veh/shared/flares_deploy.wav"
} )