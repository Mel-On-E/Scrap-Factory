dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")

---A type of `Generator` that produces more power when placed higher.
---@class Windmill : Generator
---@field cl WindmillCl
Windmill = class(Generator)

--------------------
-- #region Server
--------------------

function Windmill:server_onCreate()
    Generator.server_onCreate(self)
    sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "WindmillPlaced")
end

function Windmill:sv_getPower()
    return math.floor(self.data.power * self:get_height_multiplier())
end

-- #endregion

--------------------
-- #region Client
--------------------

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

    self.cl.activeAnim = anim
    self.cl.animDuration = self.interactable:getAnimDuration(anim)
    self.cl.animProgress = 0
end

function Windmill:client_onUpdate(dt)
    self.cl.animProgress = self.cl.animProgress + dt * animSpeeds[self.cl.activeAnim] * self:get_height_multiplier()
    local progress = self.cl.animProgress / self.cl.animDuration
    self.interactable:setAnimProgress(self.cl.activeAnim, progress)

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

-- #endregion

function Windmill:get_height_multiplier()
    return sm.util.clamp(self.shape.worldPosition.z / 100 + 1, 1, 2)
end

--------------------
-- #region Types
--------------------

---@class WindmillCl
---@field activeAnim string name of the currently active animation
---@field animDuration number duration of the current animation
---@field animProgress number progress of the current animation

-- #endregion
