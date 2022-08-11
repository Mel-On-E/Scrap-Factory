dofile("$CONTENT_DATA/Scripts/Upgraders/Upgrader.lua")

RandomUpgrader = class(Upgrader)

function RandomUpgrader:sv_onUpgrade(shape)
    local data = shape.interactable:getPublicData()
    local upgrade = self.data.upgrade
    if upgrade.addMin and upgrade.addMax then
        data.value = data.value + math.random(upgrade.addMin, upgrade.addMax)
    end
    if upgrade.multiplierMin and upgrade.multiplierMax then
        local multiplierRange = upgrade.multiplierMax - upgrade.multiplierMin
        local multiplier = upgrade.multiplierMin + math.random()*multiplierRange
        data.value = data.value + multiplier
    end
    return data
end