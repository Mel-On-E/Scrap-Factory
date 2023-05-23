
---a pad that will launch drops and players into the air
---@class Jumppad : ShapeClass
---@field powerUtil PowerUtility
Jumppad = class()
Jumppad.maxParentCount = 1
Jumppad.connectionInput = sm.interactable.connectionType.logic
Jumppad.colorNormal = sm.color.new(0x2222ddff)
Jumppad.colorHighlight = sm.color.new(0x4444ffff)

-- Server

function Jumppad:server_onCreate()
    PowerUtility.sv_init(self)

    self.sv = {}

    local size = sm.vec3.new(self.data.box.x, self.data.box.y, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    self.sv.trigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.character)
    self.sv.trigger:bindOnEnter("sv_onEnter")
end

function Jumppad:sv_onEnter(_, results)
    if not self.powerUtil.active then return end

    for _, result in ipairs(results) do
        if not sm.exists(result) then goto continue end
        ---@type Character|Body
        result = result

        ---@type Character|Shape
        local thing
        if false then --TODO check if it is a character
            result = result ---@class Character
            if result:isPlayer() then thing = result end
        else
            for _, shape in pairs(result:getShapes()) do
                local interactable = shape:getInteractable()
                if not interactable then goto continue end
                if interactable.type ~= "scripted" then goto continue end

                local publicData = interactable:getPublicData()
                if not publicData or not publicData.value then goto continue end

                thing = shape
            end
        end
        sm.physics.applyImpulse(thing, self.shape.at*thing.mass*20)

        ::continue::
    end
end

function Jumppad:server_onFixedUpdate(dt)
    PowerUtility.sv_fixedUpdate(self, "cl_toggleEffect")
end

-- Client

function Jumppad:client_onCreate()
    
end

function Jumppad:cl_toggleEffect(active)
    
end
