dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")

---A type of `Generator` that produces more power when placed higher.
---@class Windmill : Generator
Windmill = class(Generator)

--------------------
-- #region Server
--------------------

function Windmill:server_onCreate()
    Generator.server_onCreate(self)
    sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "WindmillPlaced")
end

function Windmill:sv_getPower()
    local heightMultiplier = math.max(self.shape.worldPosition.z / 100 + 1, 1)
    return math.min(math.floor(heightMultiplier * self.data.power), self.data.power * 2)
end

-- #endregion
