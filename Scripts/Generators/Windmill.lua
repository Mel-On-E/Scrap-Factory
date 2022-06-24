Windmill = class(Generator)

function Windmill:server_onCreate()
    self.powerLimit = self:getPower(self.data.powerLimit)
    sm.event.sendToGame("sv_e_addPowerLimit", self.powerLimit)
end

function Windmill:server_onDestroy()
    sm.event.sendToGame("sv_e_addPowerLimit", -self.powerLimit)
end

function Windmill:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        sm.event.sendToGame("sv_e_addPower", self:getPower(self.data.power))
    end
end

function Windmill:getPower(power)
    local heightMultiplier = math.max(self.shape.worldPosition.z/100 + 1, 1)
    return math.min(math.floor(heightMultiplier*power), power*2)
end
