Generator = class( nil )

function Generator:server_onCreate()
    sm.event.sendToGame("sv_e_addPower", self.data.power)
end

function Generator:server_onDestroy()
    sm.event.sendToGame("sv_e_addPower", -self.data.power)
end