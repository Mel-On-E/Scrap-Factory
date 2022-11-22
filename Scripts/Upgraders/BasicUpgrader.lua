dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

---@class RandomUpgrader : Upgrader
BasicUpgrader = class(Upgrader)

function BasicUpgrader:sv_onUpgrade(shape, data)
    local upgrade = self.data.upgrade

    if upgrade.multiplier then
        data.value = data.value * upgrade.multiplier
    end
    if upgrade.add then
        data.value = data.value + upgrade.add
    end

    Upgrader.sv_onUpgrade(self, shape, data)
end
