dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A VampireDrop is a drop that
---@class VampireDrop : Drop
---@field sv VampireDropSv
VampireDrop = class(Drop)

local suckFraction = 0.8
local suckDelayTime = 3 * 40

--------------------
-- #region Server
--------------------

function VampireDrop:server_onCreate()
    Drop.server_onCreate(self)
    self.sv.suckDelay = 0
end

function VampireDrop:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    if type(other) == "Shape" and self.sv.suckDelay <= 0 then
        self.sv.suckDelay = suckDelayTime
        ---@cast other Shape
        local interactable = other:getInteractable()
        if not interactable or interactable.type ~= "scripted" then goto continue end
        local data = interactable:getPublicData()
        if not data or not data.value then goto continue end
        -- varify that the collided shape is a drop.

        local stolenValue = suckFraction * data.value
        data.value = math.sqrt(data.value)
        self.interactable.publicData.value = self.interactable.publicData.value + stolenValue

        sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_numberEffect", {
            pos = other.worldPosition,
            value = tostring(stolenValue),
            color = '#de431d'
        })
        :: continue ::
    end
    Drop.server_onCollision(self, other) -- destroy shape if touching ground
end

--TODO hide in light

-- #endregion

-- ERROR the shape collides with the spawner (line 1996 in droppers.shapeset)
-- TODO destroy explosion guts effect

--------------------
-- #region Types
--------------------

---@class VampireDropSv : DropSv
---@field suckDelay number time until a vampire drop can suck again

-- #endregion
