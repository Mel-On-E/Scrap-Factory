Power = class (nil)

function Power:server_onCreate()
    self.prevActive = true
    self.powerUpdate = 1
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
            
            if self.prevActive and effect and type(effect) == "string" then
                self.network:sendToClients(effect, self.active)
            end
            self.prevActive = false
        else
            if self.prevActive ~= self.active then
                if effect and type(effect) == "string" then
                    self.network:sendToClients(effect, self.active)
                end
            end
            self.prevActive = true
        end
    end


    if self.prevActive ~= self.active then
        if self.active then
            if (self.powerUpdate % 40 == 0 and not self.powerUpdate == 0) and change_power(-self.data.power) then
                self.powerUpdate = 40
            else
                self.active = false
            end
        end
    end

    self.prevActive = self.active
end