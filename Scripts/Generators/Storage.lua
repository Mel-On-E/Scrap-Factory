dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")
dofile("$CONTENT_DATA/Scripts/Managers/LanguageManager.lua")

---Storage is a type of `Generator` that produces no power but can store it.
---@class Storage : Generator
Storage = class(Generator)

--------------------
-- #region Server
--------------------

function Storage:server_onCreate()
    Generator.server_onCreate(self)
    sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_tryStartTutorial", "PowerStorageTutorial")
end

--#endregion

--------------------
-- #region Server
--------------------

function Storage:client_canInteract()
    local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
    local o2 = "</p>"
    sm.gui.setInteractionText(language_tag("PowerCapacity"),
        o1 ..
        format_number({ format = "energy", value = PowerManager.cl_getPowerStored(), color = "#4f4f4f", unit = "J" }) ..
        " / "
        ..
        format_number({ format = "energy", value = PowerManager.cl_getPowerLimit(), color = "#4f4f4f", unit = "J" }) ..
        o2)
    return true
end

--#endregion
