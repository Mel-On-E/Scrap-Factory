---@class LootCrate : ShapeClass
LootCrate = class(nil)

local despawnTime = 60 * 10 --seconds
local minUnboxTime = 3 --seconds
local maxUnboxTime = 7 --seconds
local ticksPerItem = 5

function LootCrate:server_onCreate()
    local body = self.shape:getBody()
    body:setErasable(false)
    body:setPaintable(false)
    body:setBuildable(false)

    self.sv = {}
    self.sv.timeout = 0
end

function LootCrate:server_onFixedUpdate()
    if self.shape:getVelocity():length() < 0.1 then
        self.sv.timeout = self.sv.timeout + 1
    else
        self.sv.timeout = 0
    end

    if self.sv.timeout > 40 * despawnTime then
        self.shape:destroyShape(0)
    end
end

function LootCrate:sv_openBox(_, player)
    self.network:sendToClients("cl_openBoxForReal", player)
end

function LootCrate:sv_giveItem(params)
    sm.container.beginTransaction()
    sm.container.collect(params.player:getInventory(), params.item, params.quantity, false)
    if g_shop[tostring(params.item)].special then
        PrestigeManager.sv_addSpecialItem(params.item)
    end
    sm.container.endTransaction()
    sm.effect.playEffect("Woc - Destruct", self.shape.worldPosition)
    sm.effect.playEffect("Loot - Pickup", self.shape.worldPosition)

    self.shape:destroyPart(0)
end

function LootCrate:client_onCreate()
    self.cl = {}
    self.cl.opened = false
    self.cl.blips = {}
end

function LootCrate:client_onFixedUpdate()
    local tick = sm.game.getCurrentTick()

    if self.cl.opened and self.openTick then
        if tick % ticksPerItem == 0 then
            self.loot = self:get_random_item()
            self.cl.gui:setIconImage("Icon", self.loot)
            self.cl.gui:setText("Name", sm.shape.getShapeTitle(self.loot))


            local blip = sm.effect.createEffect("Horn - Honk", sm.localPlayer.getPlayer():getCharacter())
            blip:setParameter("pitch", 1 - (self.openTick - tick) / self.unboxTime)
            blip:start()

            self.cl.blips[#self.cl.blips + 1] = { effect = blip, tick = tick }
        end

        if tick > self.openTick then
            self.openTick = nil
            self.network:sendToServer("sv_giveItem",
                { player = sm.localPlayer.getPlayer(), item = self.loot, quantity = 1 })
            sm.gui.displayAlertText("Found #df7f01" .. sm.shape.getShapeTitle(self.loot) .. "#ffffff x" .. tostring(1))
        end
    end

    for k, blip in pairs(self.cl.blips) do
        if blip.tick <= tick - ticksPerItem then
            blip.effect:destroy()
            self.cl.blips[k] = nil
        end
    end
end

function LootCrate:client_canInteract(character, state)
    return not self.cl.opened
end

function LootCrate:client_onInteract(character, state)
    if state then
        self.cl.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Crate.layout")
        self.cl.gui:open()
        self.cl.gui:setIconImage("Icon", self.shape:getShapeUuid())
        self.cl.gui:setButtonCallback("Open", "cl_openBox")
    end
end

function LootCrate:cl_openBox()
    self.network:sendToServer("sv_openBox", nil)
end

function LootCrate:cl_openBoxForReal(player)
    self.cl.opened = true
    if sm.localPlayer.getPlayer() == player then
        self.unboxTime = math.random(minUnboxTime, maxUnboxTime) * 40
        self.openTick = sm.game.getCurrentTick() + self.unboxTime
        self.cl.gui:setVisible("Open", false)
    elseif self.cl.gui:isActive() then
        self.cl.gui:close()
    end
end

--LootTable
dofile("$SURVIVAL_DATA/Scripts/game/survival_items.lua")

function LootCrate:get_random_item()
    self.cl.lootTable = self.cl.lootTable or self:get_loot_table()
    return self.cl.lootTable[math.random(1, #self.cl.lootTable)]
end

function LootCrate:get_loot_table()
    local tier = ResearchManager.cl_getCurrentTier()
    local itemPool = {}
    for uuid, item in pairs(g_shop) do
        if item.tier < tier then
            if item.price <= MoneyManager.cl_moneyEarned() + 1000 then
                itemPool[#itemPool + 1] = { price = item.price, uuid = uuid }
            end
        end
    end

    local sortedPool = {}
    while #itemPool > 1 and #sortedPool < 10 do
        local mostExpensiveItem
        local highestPrice = 0

        for k, item in ipairs(itemPool) do
            if item.price > highestPrice then
                highestPrice = item.price
                mostExpensiveItem = k
            end
        end

        sortedPool[#sortedPool + 1] = sm.uuid.new(itemPool[mostExpensiveItem].uuid)
        table.remove(itemPool, mostExpensiveItem)
    end

    return sortedPool
end
