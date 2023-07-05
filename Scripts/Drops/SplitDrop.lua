dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---A SplitDrop is a Drop that will randomly split into 2 Drops each half its value
---@class SplitDrop : Drop
SplitDrop = class(Drop)

--------------------
-- #region Server
--------------------

local splitChancePerTick = 0.001
local colorLossPerSplit = 20 / 255

function SplitDrop:server_onFixedUpdate()
    Drop.server_onFixedUpdate(self)

    if math.random() > splitChancePerTick then return end
    if self.shape.color.r == 0 then return end

    self.interactable.publicData.value = self.interactable.publicData.value / 2
    self.shape.color = sm.color.new(self.shape.color.r - colorLossPerSplit, self.shape.color.g - colorLossPerSplit,
        self.shape.color.b - colorLossPerSplit)

    --spawn drop
    local shape = sm.shape.createPart(self.shape.uuid, self.shape.worldPosition,
        self.shape:getWorldRotation())
    shape:setColor(self.shape.color)

    shape.interactable:setPublicData(table.copy(self.interactable.publicData))
end

-- #endregion
