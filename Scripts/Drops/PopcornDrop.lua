dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A PopcornDrop is a drop ...
---@class PopcornDrop : Drop
---@field sv PopcornSv
PopcornDrop = class(Drop)

local popTimeMin = 40 * 1.5
local popTimeMax = 40 * 3

local popedUuid = sm.uuid.new("b1b00f76-b8eb-4d64-93cc-a6e5bfd6fe40")

--------------------
-- @region Server
--------------------

function PopcornDrop:server_onCreate()
    Drop.server_onCreate(self)
    self.sv.poped = self.shape:getShapeUuid() == popedUuid
    self.sv.time = sm.noise.randomRange(popTimeMin, popTimeMax)
end

function PopcornDrop:server_onFixedUpdate()
    Drop.server_onFixedUpdate(self)
    if not self.sv.poped then
        self.sv.time = self.sv.time - 1
        if self.sv.time <= 0 then
            sm.effect.playEffect( "Cotton - Picked", self.shape.worldPosition-sm.vec3.new(0,0,1) )
            self.shape:destroyShape(0)
            local shape = sm.shape.createPart(popedUuid, self.shape.worldPosition, self.shape.worldRotation)
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
-- @region Types
--------------------

---@class PopcornSv : DropSv
---@field time number time remaining until it pops
---@field poped boolean is it poped

-- #endregion
