dofile("$CONTENT_DATA/Scripts/Droppers/AutoDropper.lua")

---An RGBDropper automatically spawns Drops of random color and value
---@class RGBDropper : AutoDropper
RGBDropper = class(AutoDropper)

--------------------
-- #region Server
--------------------

function RGBDropper:sv_onNewDropCreated(shape)
    local randomColor = sm.color.new(math.random(), math.random(), math.random())
    local value = tonumber(string.sub(randomColor:getHexStr(), 0, 6), 16)

    self.shape:setColor(randomColor)
    shape:setColor(randomColor)
    shape.interactable.publicData.value = value
end

-- #endregion
