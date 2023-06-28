dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A VampireDrop is a drop that 
---@class VampireDrop : Drop
VampireDrop = class(Drop)

local durability = 4

--------------------
-- #region Server
--------------------

function VampireDrop:server_onCreate()
    Drop.server_onCreate(self)
end

function VampireDrop:server_onMeleeDrop(position, attacker, damage, power, direction, normal)
    if (damage>durability) then
        self.shape:destroyPart()
    end
end

-- ERROR the shape collides with the spawner (line 1996 in droppers.shapeset)
-- TODO destroy explosion guts effect

-- #endregion
