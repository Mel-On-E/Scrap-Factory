dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A MagneticDrop is a Drop that is attracted to drops of opposite magnetic polarisation and attracted to drops of opposite.
---@class MagneticDrop : Drop
---@field data MagneticDropData
MagneticDrop = class(Drop)

--------------------
-- #region Server
--------------------

local triggerSize = sm.vec3.one() * 8

function MagneticDrop:server_onCreate()
    Drop.server_onCreate(self)

    if not sm.exists(self.shape) or not self.interactable.publicData then return end

    self.interactable.publicData.magnetic = self.data.magnetic
    self.sv.trigger = sm.areaTrigger.createAttachedBox(self.interactable, triggerSize / 2, sm.vec3.zero(),
        sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody)
    self.sv.trigger:bindOnStay("sv_onStay")
end

function MagneticDrop:sv_onStay(_, results)
    local shapes = self:sv_getValidShapes(results)

    for _, shape in ipairs(shapes) do
        local publicData = shape.interactable.publicData

        if publicData.magnetic then
            local direction = (self.interactable.publicData.magnetic == publicData.magnetic and -1) or 1
            if publicData.magnetic == "sticky" then
                direction = 1
            elseif publicData.magnetic == "repell" then
                direction = -1
            end

            local distance = shape.worldPosition - self.shape.worldPosition
            local factor = 1 / distance:length()
            local force = distance:normalize() * direction * factor

            sm.physics.applyImpulse(self.shape:getBody(), force, true)
        end
    end
end

---@param results table table of shapes to be validated
---@return table<integer, Shape> shapes a list of shapes that are vaild
function MagneticDrop:sv_getValidShapes(results)
    local shapes = {}
    for _, result in ipairs(results) do
        if sm.exists(result) then
            if type(result) ~= "Body" then goto continue end
            if result.id == self.shape.body.id then goto continue end

            if #result:getShapes() > 1 then goto continue end

            local shape = result:getShapes()[1]
            local interactable = shape:getInteractable()

            if not interactable then goto continue end
            if interactable.type ~= "scripted" then goto continue end

            local data = interactable:getPublicData()
            if not data or not data.value then goto continue end

            shapes[#shapes + 1] = shape
        end
        ::continue::
    end

    return shapes
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class MagneticDropData
---@field magnetic "north"|"south"|"sticky"|"repell" the polarisation of the drop

-- #endregion
