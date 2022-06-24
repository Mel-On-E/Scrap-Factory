Stonks = class (nil)

function Stonks:client_onCreate()
    self.cl = {}
    self.cl.stonks = {}
end


function Stonks:cl_stonks(params)
    local gui = sm.gui.createNameTagGui()
    gui:setWorldPosition(params.pos)
    gui:open()
    gui:setMaxRenderDistance(100)
    gui:setText("Text", format_money(params.value))

    sm.effect.playEffect("Loot - Pickup", params.pos - sm.vec3.new(0, 0, 0.25))

    self.cl.stonks[#self.cl.stonks + 1] = { gui = gui, endTick = sm.game.getCurrentTick() + 80, pos = params.pos }
end

function Stonks:client_onFixedUpdate()
    for k, stonks in pairs(self.cl.stonks) do
        if stonks and sm.game.getCurrentTick() > stonks.endTick then
            stonks.gui:destroy()
            self.cl.stonks[k] = nil
        end
    end
end

function Stonks:client_onUpdate(dt)
    for k, stonks in pairs(self.cl.stonks) do
        stonks.pos = stonks.pos + sm.vec3.new(0, 0, 0.1) * dt
        stonks.gui:setWorldPosition(stonks.pos)
    end
end