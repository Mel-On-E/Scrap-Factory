dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_units.lua")

---A type of `Generator` that produces power when the player runs on it
---@class Treadmill : Generator
---@field trigger AreaTrigger
---@field data TreadmillData
---@field sv TreadmillSv
---@field cl TreadmillCl
Treadmill = class(Generator)

---the min time inbetween messages in ticks
local minMessageTime = 1 * 40
---the max time inbetween messages in ticks
local maxMessageTime = 4 * 40
---precent that the message will tell them to speed up if they aren't running
local speedUpPrecent = 0.2

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
    --TODO non billboarded text, place it on the screen of treadmill
    -- sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_tryStartTutorial", "SolarTutorial")
end

function Treadmill:sv_enter(_, results)
    self:sv_updateChar(results[1])
end

function Treadmill:sv_exit()
    self:sv_updateChar(nil)
end

function Treadmill:sv_updateChar(char)
    self.sv.char = char
    self.network:setClientData({ typ = 'char', char = char })
end

function Treadmill:sv_getPower()
    if self.sv.char == nil then return 0 end
    return self:getSpeed(self.sv.char)
end

function Treadmill:server_onFixedUpdate()
    Generator.server_onFixedUpdate(self)
    if self.sv.char then
        local direction = self.shape.at * self.data.trigger.direction.at +
            self.shape.right * self.data.trigger.direction.right +
            self.shape.up * self.data.trigger.direction.up
        local force = direction * (self.sv.char.mass / 4) * self:getSpeed(self.sv.char)
        sm.physics.applyImpulse(self.sv.char, force)
    end
end

-- #endregion

--------------------
-- #region Client
--------------------

function Treadmill:client_onCreate()
    Generator.client_onCreate(self)
    self.cl.uvIndex = 0
    self.cl.messageCount = self:cl_getMessageCount()
    self:cl_pickTime()
end

function Treadmill:client_onClientDataUpdate(data)
    if data.typ == 'char' then
        self.cl.char = data.char
    else
        Generator.client_onClientDataUpdate(self, data)
    end
end

function Treadmill:client_onFixedUpdate(dt)
    if self.cl.char ~= nil then
        --update uv animation
        local uvFrames = 50
        local timeScale = 0.58 * self:getSpeed(self.cl.char)
        self.cl.uvIndex = (self.cl.uvIndex + dt * timeScale) % 1
        self.interactable:setUvFrameIndex(uvFrames - (self.cl.uvIndex * uvFrames))

        --display message
        self.cl.messageTimer = self.cl.messageTimer - 1
        if self.cl.messageTimer <= 0 then
            self:cl_pickTime()
            ---@type string|number language tag suffex
            local name
            if not self.cl.char:isSprinting() and sm.noise.randomRange(0, 1) < speedUpPrecent then
                name = 'Faster'
            else
                name = math.floor(sm.noise.randomRange(1, self.cl.messageCount + 1))
            end
            sm.event.sendToPlayer(sm.localPlayer.getPlayer(), 'cl_numberEffect', {
                value = language_tag('TreadmillMessage' .. name),
                pos = self.shape.worldPosition + self.shape:getAt() + self.shape:getRight()
            })
        end
    end
end

function Treadmill:cl_pickTime()
    self.cl.messageTimer = sm.noise.randomRange(minMessageTime, maxMessageTime)
end

function Treadmill:cl_getMessageCount()
    local i = 1
    local count = 0
    while language_tag("TreadmillMessage" .. tostring(i)) ~= "nil" do
        count = i
        i = i + 1
    end
    return count
end

-- #endregion

---@param char Character
---@return number
function Treadmill:getSpeed(char)
    local speed = 0
    local animations = char:getActiveAnimations()
    for k, v in pairs(animations) do
        if string.find(v.name, "run") then
            speed = 4
        elseif string.find(v.name, "sprint") then
            speed = 8
        end
    end

    return speed
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
---@field messageTimer number the ticks until it will display a message
---@field messageCount integer number of messages in `tags.json`

---@class TreadmillTrigger
---@field box BeltVec size of the areaTrigger
---@field offset BeltVec offset of the areaTrigger
---@field direction BeltRotStuffPlsHelpIHateNamingThis direction in which shapes are pushed

-- #endregion
