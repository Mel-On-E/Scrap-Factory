dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_units.lua")

---A type of `Generator` that produces power when the player runs on it
---@class Treadmill : Generator
---@field trigger AreaTrigger
---@field data TreadmillData
---@field sv TreadmillSv
---@field cl TreadmillCl
Treadmill = class(Generator)

--------------------
-- #region Server
--------------------

function Treadmill:server_onCreate()
    Generator.server_onCreate(self)

    local size = sm.vec3.new(self.data.trigger.box.x, self.data.trigger.box.y, self.data.trigger.box.z)
    local offset = sm.vec3.new(self.data.trigger.offset.x, self.data.trigger.offset.y, self.data.trigger.offset.z)
    self.trigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        sm.areaTrigger.filter.character)
    self.trigger:bindOnEnter('sv_enter')
    self.trigger:bindOnExit('sv_exit')

    --TODO add treadmill tutorial
    --TODO balance power
    -- sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_tryStartTutorial", "SolarTutorial")
end

function Treadmill:sv_enter(_, results) self:sv_updateChar(results[1]) end
function Treadmill:sv_exit() self:sv_updateChar(nil) end

function Treadmill:sv_updateChar(char)
    self.sv.char = char
    self.network:setClientData({typ='char', char = char})
end

function Treadmill:sv_getPower()
    if self.sv.char == nil then return 0 end
    return math.abs(self:getSpeed(self.sv.char))
end

-- #endregion

--------------------
-- #region Client
--------------------

function Treadmill:client_onCreate()
    Generator.client_onCreate(self)
    self.cl.uvIndex = 0
end

function Treadmill:client_onClientDataUpdate(data)
    if data.typ == 'char' then
        self.cl.char = data.char
    else
        Generator.client_onClientDataUpdate(self, data)
    end
end

function Treadmill:client_onUpdate(dt)
    ---update uv animation
    if self.cl.char ~= nil then
        local uvFrames = 50
        local timeScale = 0.58 * self:getSpeed(self.cl.char)
        self.cl.uvIndex = (self.cl.uvIndex + dt * timeScale) % 1
        self.interactable:setUvFrameIndex(uvFrames - (self.cl.uvIndex * uvFrames))
    end
end

-- #endregion

---@param char Character
---@return number
function Treadmill:getSpeed(char)
    local direction = self.shape.at * self.data.trigger.direction.at +
                self.shape.right * self.data.trigger.direction.right +
                self.shape.up * self.data.trigger.direction.up
    return char.velocity:dot(direction)
end

--------------------
-- #region Types
--------------------

---@class TreadmillData : GeneratorData
---@field trigger TreadmillTrigger

---@class TreadmillSv : GeneratorSv
---@field char Character|nil

---@class TreadmillCl : GeneratorCl
---@field char Character|nil
---@field active boolean
---@field uvIndex number

---@class TreadmillTrigger
---@field box BeltVec size of the areaTrigger
---@field offset BeltVec offset of the areaTrigger
---@field direction BeltRotStuffPlsHelpIHateNamingThis direction in which shapes are pushed

-- #endregion
