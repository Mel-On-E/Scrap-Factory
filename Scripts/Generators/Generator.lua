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