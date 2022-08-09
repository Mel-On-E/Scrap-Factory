Power = class (nil)

function Power:server_onCreate()
    self.prevActive = true
    self.powerUpdate = 1
    self.hasPower = false
end

function Power:server_onFixedUpdate(effect)
    self.powerUpdate = self.powerUpdate - 1

    local parent = self.interactable:getSingleParent()
    if not parent then 
        self.active = true
    else
        self.active = parent:isActive()
    end

    if self.powerUpdate == 0 then
        self.powerUpdate = 40
        if not change_power(-self.data.power) then
            self.hasPower = false
        else
            self.hasPower = true
        end
    end

    self.active = self.active and self.hasPower

    if self.active ~= self.prevActive then
        if effect and type(effect) == "string" then
            self.network:sendToClients(effect, self.active)
        end
    end

    self.prevActive = self.active
end