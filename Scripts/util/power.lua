Power = class (nil)

function Power:server_onCreate()
    self.prevActive = true
    self.powerUpdate = 1
end

function Power:server_onFixedUpdate(effect)
    self.powerUpdate = self.powerUpdate -1

    if self.powerUpdate == 0 then
        self.powerUpdate = 40
        if not consume_power(self.data.power) then
            self.prevActive = false
        end
    end

    local parent = self.interactable:getSingleParent()
    if not parent then 
        self.active = true
    else
        self.active = parent:isActive()
    end

    if self.prevActive ~= self.active then
        if self.active then
            if consume_power(self.data.power) then
                self.powerUpdate = 40
            else
                self.active = false
            end
        else     
            self.powerUpdate = -1
        end
        if effect and type(effect) == "string" then
            self.network:sendToClients(effect, self.active)
        end
    end

    self.prevActive = self.active
end