dofile("$CONTENT_DATA/Scripts/util/power.lua")
dofile("$CONTENT_DATA/Scripts/Generators/Generator.lua")
dofile("$CONTENT_DATA/Scripts/Furnaces/Furnace.lua")


Burner = class(nil)

function Burner:server_onCreate()
    Furnace.server_onCreate(self)
    Generator.server_onCreate(self)
end

function Burner:server_onDestroy()
    Generator.server_onDestroy(self)
end

function Burner:sv_onEnter(trigger, results)
    for _, result in ipairs(results) do
        if not sm.exists(result) then goto continue end
        for k, shape in pairs(result:getShapes()) do
            if not self.data.drops[tostring(shape.uuid)] then goto continue end

            local interactable = shape:getInteractable()
            if not interactable then goto continue end

            local data = interactable:getPublicData()
            if not data or not data.value then goto continue end

            shape:destroyPart(0)
            local power = data.value
            if self.data.powerFunction == "root" then
                power = (power ^ (1/(4/3)))
            end
            power = power + 1

            sm.event.sendToGame("sv_e_stonks", { pos = shape:getWorldPosition(), value = power, effect = "Fire -medium01_putout", format = "energy" })
            PowerManager.sv_changePower(power)
        end
        ::continue::
    end
end

function Burner:client_onCreate()
    --[[local size = sm.vec3.new(self.data.box.x, self.data.box.y, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    self.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
	self.effect:setParameter("uuid", sm.uuid.new("5f41af56-df4c-4837-9b3c-10781335757f"))
	self.effect:setParameter("color", sm.color.new(1,1,1))
    self.effect:setScale(size)
    self.effect:setOffsetPosition(offset)
	self.effect:start()]]
end
