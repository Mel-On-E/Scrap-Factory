dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")
dofile("$CONTENT_DATA/Scripts/Managers/LanguageManager.lua")

Storage = class( Generator )

function Storage:client_canInteract()
    local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"
    sm.gui.setInteractionText(o1 .. language_tag("PowerCapacity") .. format_energy({power = g_cl_powerStored, color = "#4f4f4f", unit = "J"}) .. " / " .. format_energy({power = g_cl_powerLimit, color = "#4f4f4f", unit = "J"}) .. o2)
    return true
end