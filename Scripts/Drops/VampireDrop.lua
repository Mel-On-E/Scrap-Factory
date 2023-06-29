dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A VampireDrop is a drop that 
---@class VampireDrop : Drop
---@field suckDelay number ticks until it can suck again (yes)
VampireDrop = class(Drop)

local coefficient = 0.8
--time until a vampire drop can suck again
local suckDelayTime = 3 * 40

--------------------
-- #region Server
--------------------

function VampireDrop:server_onCreate()
    Drop.server_onCreate(self)
    self.suckDelay = 0
end

function VampireDrop:server_onCollision(other, position, selfPointVelocity, otherPointVelocity, normal)
    if type(other) == "Shape" and self.suckDelay < 1 then
        self.suckDelay = suckDelayTime
        ---@cast other Shape
        local interactable = other:getInteractable()
        if not interactable or interactable.type ~= "scripted" then goto continue end
        local data = interactable:getPublicData()
        if not data or not data.value then goto continue end
        -- varify that the collided shape is a drop.

        --TODO maybe have some money lost
        local stole = coefficient * data.value
        data.value = data.value - stole --take from drop
        self.interactable.publicData.value = self.interactable.publicData.value + stole --add to
        sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_numberEffect", {
            pos = other.worldPosition,
            value = tostring(stole),
            color = '#de431d'
        })
        --TODO maybe add boost or smth (like side effect of getting bit by a vampire)
        :: continue ::
    end
    Drop.server_onCollision(self, other) -- destroy shape if touching ground
end

--TODO hide in light

-- #endregion

-- ERROR the shape collides with the spawner (line 1996 in droppers.shapeset)
-- TODO destroy explosion guts effect