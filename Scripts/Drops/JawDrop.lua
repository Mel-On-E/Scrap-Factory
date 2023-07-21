dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A JawDrop is a `Drop`
---@class JawDrop : Drop
JawDrop = class(Drop)
JawDrop.poseWeightCount = 1

--------------------
-- #region Client
--------------------

--the fraction of the game tick used for the sine wave
local speedFraction = 4

function JawDrop:client_onFixedUpdate()
    local v = (math.sin(sm.game.getCurrentTick()/speedFraction)+1)/2 --the (x+1)/2 turns -1 -> 1 into 0 -> 1 range
    self.interactable:setPoseWeight(0, v)
end

-- #endregion
