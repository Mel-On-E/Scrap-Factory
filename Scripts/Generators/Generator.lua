Generator = class( nil )

function Generator:server_onCreate()
    sm.event.sendToGame("sv_e_addPowerLimit", self.data.powerLimit)
end

function Generator:server_onDestroy()
    sm.event.sendToGame("sv_e_addPowerLimit", -self.data.powerLimit)
end

function Generator:server_onFixedUpdate()
    if self.data.power > 0 and sm.game.getCurrentTick() % 40 == 0 then
        sm.event.sendToGame("sv_e_addPower", self.data.power)
    end
end

Windmill = class(Generator)

function Windmill:server_onFixedUpdate()
    if self.data.power > 0 and sm.game.getCurrentTick() % 40 == 0 then
        local heightMultiplier = math.max(self.shape.worldPosition.z/100 + 1, 1)
        local power = math.min(math.floor(heightMultiplier*self.data.power), self.data.power*2)
        print(power)
        sm.event.sendToGame("sv_e_addPower", power)
    end
end
