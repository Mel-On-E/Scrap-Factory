Drop = class( nil )

function Drop:server_onCreate()
    local body = self.shape:getBody()
    body:setErasable(false)
    body:setPaintable(false)
    body:setBuildable(false)
    self.interactable:setPublicData( {value = self.data.value, upgrades = {}})
    self.timeout = 0
end

function Drop:server_onFixedUpdate()
    if self.shape:getVelocity():length() < 0.01 then
        self.timeout = self.timeout + 1
    else
        self.timeout = 0
    end

    if self.timeout > 40*10 then
        self.shape:destroyShape(0)
    end
end

--[[
function Drop:client_onCreate()
    self.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
	self.effect:setParameter("uuid", sm.uuid.new("5f41af56-df4c-4837-9b3c-10781335757f"))
	self.effect:setParameter("color", sm.color.new(1,0,0))
    self.effect:setScale(sm.vec3.one()*0.25)
	self.effect:start()
end
]]