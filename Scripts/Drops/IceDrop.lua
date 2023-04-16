dofile("$CONTENT_DATA/Scripts/Drops/Drop.lua")

---An IceDrop is a `Drop` that has low friction and slowly "melts" over time, reducing its value
---@class IceDrop : Drop
---@diagnostic disable-next-line: param-type-mismatch, assign-type-mismatch
IceDrop = class(Drop)

--------------------
-- #region Server
--------------------

local meltRatePerTick = 0.99995

function IceDrop:server_onFixedUpdate()
    if self.interactable.publicData then
        self.interactable.publicData.value = self.interactable.publicData.value * meltRatePerTick
    end

    Drop.server_onFixedUpdate(self)
end

-- #endregion
