dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A PopcornDrop is a drop ...
---@class PopcornDrop : Drop
---@field popped boolean is this drop popped
PopcornDrop = class(Drop)

local popTimeMin = 40 * 1.5
local popTimeMax = 40 * 3

local poppedUuid = sm.uuid.new("b1b00f76-b8eb-4d64-93cc-a6e5bfd6fe40")

--------------------
-- @region Server
--------------------

function PopcornDrop:server_onCreate()
    Drop.server_onCreate(self)
    self.popped = self.shape:getShapeUuid() == poppedUuid
    self.sv.time = sm.noise.randomRange(popTimeMin, popTimeMax)
end

function PopcornDrop:server_onFixedUpdate()
    Drop.server_onFixedUpdate(self)
    if not self.popped then
        self.sv.time = self.sv.time - 1
        if self.sv.time <= 0 then
            self.shape:destroyShape(0)
            local shape = sm.shape.createPart(poppedUuid, self.shape.worldPosition, self.shape.worldRotation)
            local publicData = {
                value = self:getValue() * 2, --TODO balance multiplier
                pollution = nil,
                upgrades = {},
                impostor = false,
            }
            shape.interactable:setPublicData(publicData)
        end
    end
end

-- #endregion

--------------------
-- @region Client
--------------------

function PopcornDrop:client_onCreate()
    Drop.client_onCreate(self)
    if self.shape:getShapeUuid() == poppedUuid then
        local e = sm.effect.createEffect( "Cotton - Picked", self.interactable )
        e:setOffsetPosition(sm.vec3.new(0,0,-1)) --offset down because cotton plants are tall
        e:start()
    end
end

-- #endregion
