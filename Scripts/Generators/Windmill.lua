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

local animSpeeds = {
    Prop_R = 20,
    Idle_R = 20,
    --Idle_L = 20
}
function Windmill:client_onCreate()
    Generator.client_onCreate(self)

    self:cl_setAnim("Prop_R")
end

function Windmill:cl_setAnim(anim)
    for _anim, v in pairs(animSpeeds) do
        self.interactable:setAnimEnabled(_anim, _anim == anim)
        self.interactable:setAnimProgress(_anim, 0)
    end

    self.activeAnim = anim
    self.animDuration = self.interactable:getAnimDuration(anim)
    self.animProgress = 0
end

function Windmill:client_onUpdate(dt)
    self.animProgress = self.animProgress + dt * animSpeeds[self.activeAnim]
    local progress = self.animProgress/self.animDuration
    self.interactable:setAnimProgress(self.activeAnim, progress)

    if progress >= 1 then
        local anim
        if math.random() < 0.85 then
            anim = "Prop_R"
        else
            anim = "Idle_R" --"Idle_"..(math.random() < 0.5 and "R" or "L")
        end

        self:cl_setAnim(anim)
    end
end