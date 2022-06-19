Drop = class( nil )

function Drop:server_onCreate()
    local body = self.shape:getBody()
    body:setErasable(false)
    body:setPaintable(false)
    self.interactable:setPublicData( {value = self.data.value, upgrades = {}})
end