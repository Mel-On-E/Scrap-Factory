---A utility class that handles power mangement. Data is stored in `self.powerUtil`. Implement `sv_init(self)` and `sv_fixedUpdate(self, callback)` to make it work.
---@class PowerUtility : ShapeClass
---@field powerUtil PowerUtility
---@diagnostic disable-next-line: assign-type-mismatch
PowerUtility = class(nil)

--------------------
-- #region Serveer
--------------------

---initialize the power utility
function PowerUtility.sv_init(self)
    self.data.power = tonumber(self.data.power)

    self.powerUtil = {
        prevActive = true,
        active = false,
        powerUpdate = 1,
        hasPower = false
    }
end

---update the power utility
---@param toggleCallback string|nil name of the client callback used to toggle things, e.g. effects, when the power changes
function PowerUtility.sv_fixedUpdate(self, toggleCallback)
    self.powerUtil.powerUpdate = self.powerUtil.powerUpdate - 1

    local parent = self.interactable:getSingleParent()
    if not parent then
        self.powerUtil.active = true
    else
        self.powerUtil.active = parent:isActive()
    end

    if self.powerUtil.powerUpdate == 0 then
        self.powerUtil.powerUpdate = 40
        self.powerUtil.hasPower = false

        if self.powerUtil.active then
            self.powerUtil.hasPower = PowerManager.sv_changePower(-self.data.power)
        elseif parent then
            self.powerUtil.powerUpdate = 1
        end
    end
    self.powerUtil.active = self.powerUtil.active and self.powerUtil.hasPower

    if self.powerUtil.active ~= self.powerUtil.prevActive then
        if toggleCallback and type(toggleCallback) == "string" then
            self.network:sendToClients(toggleCallback, self.powerUtil.active)
        end
    end

    self.powerUtil.prevActive = self.powerUtil.active
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class PowerUtility
---@field prevActive boolean if the object was turned on during the previous tick
---@field active boolean if the object is "turned on" and should (try) to use power
---@field powerUpdate number ticks until the next power check
---@field hasPower boolean whether the object still has power from the last time power was consumed

-- #endregion
