---The LanguageManager manages localization of strings via the `language_tag()` function
---@class LanguageManager : ScriptableObjectClass
---@field language string The current language
---@field tags string[] The tag table
LanguageManager = class()

local fallbackLanguage = sm.json.open("$CONTENT_DATA/Gui/Language/English/tags.json")

function LanguageManager:client_onCreate()
    g_languageManager = self
end

---Automatically translates a string into the client language:
---
---```lua
--- if sm.gui.getCurrentLanguage() == "English" then
---     print(language_tag("Research"))
---     --> "Research"
--- elseif sm.gui.getCurrentLanguage() == "German" then
---     print(language_tag("Research"))
---     --> "Forschung"
--- end
---```
---@param name string The name of the language tag from $CONTENT_DATA/Gui/Language/${Language_name}/tags.json
function language_tag(name)
    g_languageManager = g_languageManager or { language = "yo mama" } --Stupid fix because quests load before this?

    local currentLang = sm.gui.getCurrentLanguage()
    if currentLang ~= g_languageManager.language then --language changed
        g_languageManager.language = currentLang
        local path = "$CONTENT_DATA/Gui/Language/" .. g_languageManager.language .. "/tags.json"
        if sm.json.fileExists(path) then
            g_languageManager.tags = sm.json.open(path)
        end
    end

    local textInJson = nil
    if g_languageManager.tags then
        textInJson = g_languageManager.tags[name] or fallbackLanguage[name] --return fallback tag if not found
    end

    return tostring(textInJson)
end
