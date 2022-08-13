dofile("$CONTENT_DATA/Scripts/util/util.lua")

Generator = class( nil )

function Generator:server_onCreate()
    if self.data.power then
        self.data.power = tonumber(self.data.power)
    end

    if self.data.powerLimit then
        self.data.powerLimit = tonumber(self.data.powerLimit)
        PowerManager.sv_changePowerLimit(self.data.powerLimit)
    end
end

function Generator:server_onDestroy()
    if self.data.powerLimit then
        PowerManager.sv_changePowerLimit(-self.data.powerLimit)
    end
end

function Generator:server_onFixedUpdate()
    if self.data.power and sm.game.getCurrentTick() % 40 == 0 then
        PowerManager.sv_changePower(self:getPower())
    end
end

function Generator:getPower()
    print(self.data.power)
    return self.data.power
end