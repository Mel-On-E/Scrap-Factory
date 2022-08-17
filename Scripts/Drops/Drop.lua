Drop = class( nil )

local oreCount = 0
local lifeTime = 40*5--ticks

function Drop:server_onCreate()
    local body = self.shape:getBody()
    body:setErasable(false)
    body:setPaintable(false)
    body:setBuildable(false)
    body:setLiftable(false)
    self.interactable:setPublicData( {value = tonumber(self.data.value), upgrades = {}})
    self.timeout = 0
end

function Drop:server_onFixedUpdate()
    if self.shape:getVelocity():length() < 0.01 then
        self.timeout = self.timeout + 1
    else
        self.timeout = 0
    end

    if self.timeout > lifeTime then
        self.shape:destroyShape(0)
    end
end

function Drop:client_onCreate()
    oreCount = oreCount + 1
    if oreCount >= 100 then
        sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_e_drop_dropped")
    end
end

function Drop:client_onDestroy()
    oreCount = oreCount - 1
end