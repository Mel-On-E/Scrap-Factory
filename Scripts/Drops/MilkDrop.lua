dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A MilkDrop is a Drop that will spill the milk when it falls over and becomes much less valueable.
---@class MilkDrop : Drop
MilkDrop = class(Drop)

--------------------
-- #region Server
--------------------

local empty_milk = sm.uuid.new("09bf3314-f60e-4178-9259-2e321a466a2c")
local spillAngle = 69

function MilkDrop:server_onFixedUpdate()
    Drop.server_onFixedUpdate(self)

    if self.shape.uuid == empty_milk then return end

    local angle = math.deg(angle(sm.vec3.new(0, 0, 1), self.shape.at))

    if angle > spillAngle then
        self.interactable.publicData.value = math.sqrt(self.interactable.publicData.value)

        sm.effect.playEffect("Milk Spill", self.shape.worldPosition)
        self.shape:replaceShape(empty_milk)
    end
end

-- #endregion
