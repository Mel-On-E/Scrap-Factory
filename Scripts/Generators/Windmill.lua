dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")

---@class Windmill : Generator
Windmill = class(Generator)

function Windmill:server_onCreate()
    Generator.server_onCreate(self)
    sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "WindmillPlaced")
end

function Windmill:getPower()
    local heightMultiplier = math.max(self.shape.worldPosition.z / 100 + 1, 1)
    return math.min(math.floor(heightMultiplier * self.data.power), self.data.power * 2)
end
