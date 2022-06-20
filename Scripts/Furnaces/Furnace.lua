dofile("$CONTENT_DATA/Scripts/util.lua")

Furnace = class(nil)

function Furnace:server_onCreate()
    local size = sm.vec3.new(self.data.box.x, self.data.box.y, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)
    self.trigger = sm.areaTrigger.createAttachedBox(self.interactable, size / 2, offset, sm.quat.identity(),
        sm.areaTrigger.filter.dynamicBody)
    self.trigger:bindOnEnter("sv_onEnter")
    self.trigger:bindOnStay("sv_onEnter")
end

function Furnace:sv_onEnter(trigger, results)
    for _, result in ipairs(results) do
        if not sm.exists(result) then goto continue end
        for k, shape in pairs(result:getShapes()) do
            local interactable = shape:getInteractable()
            if not interactable then goto continue end
            local data = interactable:getPublicData()
            if not data or not data.value then goto continue end
            if not consume_power(self.data.power) then goto continue end
            shape:destroyPart(0)
            self.network:sendToClients("cl_stonks", { pos = shape:getWorldPosition(), value = data.value })
            sm.event.sendToGame("sv_e_addMoney", data.value)
        end
        ::continue::
    end
end

function Furnace:client_onCreate()
    --[[
    local size = sm.vec3.new(self.data.box.x, self.data.box.y, self.data.box.z)
    local offset = sm.vec3.new(self.data.offset.x, self.data.offset.y, self.data.offset.z)

    self.effect = sm.effect.createEffect("ShapeRenderable", self.interactable)
	self.effect:setParameter("uuid", sm.uuid.new("5f41af56-df4c-4837-9b3c-10781335757f"))
	self.effect:setParameter("color", sm.color.new(1,1,1))
    self.effect:setScale(size)
    self.effect:setOffsetPosition(offset)
	self.effect:start()
    ]]

    self.cl = {}
    self.cl.stonks = {}
end

function Furnace:client_onUpdate(dt)
    for k, stonks in pairs(self.cl.stonks) do
        stonks.pos = stonks.pos + sm.vec3.new(0, 0, 0.1) * dt
        stonks.gui:setWorldPosition(stonks.pos)
    end
end

function Furnace:client_onFixedUpdate()
    for k, stonks in pairs(self.cl.stonks) do
        if stonks and sm.game.getCurrentTick() > stonks.endTick then
            stonks.gui:destroy()
            self.cl.stonks[k] = nil
        end
    end
end

function Furnace:cl_stonks(params)
    local gui = sm.gui.createNameTagGui()
    gui:setWorldPosition(params.pos)
    gui:open()
    gui:setMaxRenderDistance(100)
    gui:setText("Text", "#00ff00" .. format_money(params.value))

    sm.effect.playEffect("Loot - Pickup", params.pos - sm.vec3.new(0, 0, 0.25))

    self.cl.stonks[#self.cl.stonks + 1] = { gui = gui, endTick = sm.game.getCurrentTick() + 80, pos = params.pos }
end
