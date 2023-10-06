dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---A BasicUpgrader that can apply a multiplier to a drop or add a fixed value
---@class TesslaCoil : Upgrader
---@field data BasicUpgraderData
TesslaCoil = class(Upgrader)

--------------------
-- #region Server
--------------------

function TesslaCoil:server_onCreate()
    Upgrader.server_onCreate(self)

    local size, offset = self:get_size_and_offset()
end

function TesslaCoil:sv_onEnter(_, results)
    if not self.powerUtil.active then return end

    for _, result in ipairs(results) do
        if not sm.exists(result) then goto continue end
        if type(result) ~= "Body" then goto continue end

        for _, shape in ipairs(getDrops(result:getShapes())) do
            local data = shape:getInteractable():getPublicData()

            local uuid = tostring(self.shape.uuid)
            if self.data.upgrade.cap and data.value > self.data.upgrade.cap then goto continue end
            if self.data.upgrade.limit and data.upgrades[uuid] and data.upgrades[uuid] >= self.data.upgrade.limit then goto continue end

            --valid drop
            self:sv_onUpgrade(shape, data)
        end
        ::continue::
    end
end

---@param shape Shape
function TesslaCoil:sv_onUpgrade(shape, data)
    local upgrade = self.data.upgrade

    if upgrade.multiplier then
        data.value = data.value * upgrade.multiplier
    end
    if upgrade.add then
        data.value = data.value + upgrade.add
    end

    Upgrader.sv_onUpgrade(self, shape, data)

    --TODO spark effect
end

-- #endregion
