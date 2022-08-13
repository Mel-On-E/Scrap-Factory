LootCrate = class( nil )

local despawnTime = 600--seconds
local minUnboxTime = 3--seconds
local maxUnboxTime = 7--seconds

function LootCrate:server_onCreate()
    local body = self.shape:getBody()
    body:setErasable(false)
    body:setPaintable(false)
    body:setBuildable(false)
    self.timeout = 0
end

function LootCrate:server_onFixedUpdate()
    if self.shape:getVelocity():length() < 0.1 then
        self.timeout = self.timeout + 1
    else
        self.timeout = 0
    end

    if self.timeout > 40*600 then
        self.shape:destroyShape(0)
    end
end

function LootCrate:sv_openBox(params, player)
    self.network:sendToClients("cl_openBoxForReal", player)
end

function LootCrate:sv_giveItem( params )
	sm.container.beginTransaction()
	sm.container.collect( params.player:getInventory(), params.item, params.quantity, false )
	sm.container.endTransaction()
    sm.effect.playEffect( "Woc - Destruct", self.shape.worldPosition )
    sm.effect.playEffect("Loot - Pickup", self.shape.worldPosition)

    self.shape:destroyPart(0)
end



function LootCrate:client_onCreate()
    self.opened = false
end

function LootCrate:client_onFixedUpdate()
    if self.opened and self.openTick then
        local tick = sm.game.getCurrentTick()
        if tick % 5 == 0 then
            self.loot = self:get_random_item()
            self.gui:setIconImage( "Icon", self.loot )
            self.gui:setText( "Name", sm.shape.getShapeTitle(self.loot) )
            sm.effect.playEffect("Horn - Honk", sm.localPlayer.getPlayer():getCharacter():getWorldPosition(), sm.vec3.zero(), sm.quat.identity(), sm.vec3.one(), {pitch = 1 - (self.openTick - tick)/self.unboxTime})
        end
        if tick > self.openTick then
            self.openTick = nil
            self.network:sendToServer( "sv_giveItem", { player = sm.localPlayer.getPlayer(), item = self.loot, quantity = 1 } )
            sm.gui.displayAlertText("Found #df7f01" .. sm.shape.getShapeTitle(self.loot) .. "#ffffff x" .. tostring(1))
        end
    end
end

function LootCrate:client_canInteract(character, state)
    return not self.opened
end

function LootCrate:client_onInteract(character, state)
    if state then
        self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Crate.layout")
        self.gui:open()
        self.gui:setIconImage( "Icon", self.shape:getShapeUuid() )
        self.gui:setButtonCallback("Open", "cl_openBox")
    end
end

function LootCrate:cl_openBox()
    self.network:sendToServer("sv_openBox", nil)
end

function LootCrate:cl_openBoxForReal(player)
    self.opened = true
    if sm.localPlayer.getPlayer() == player then
        self.unboxTime = math.random(minUnboxTime, maxUnboxTime) * 40
        self.openTick = sm.game.getCurrentTick() + self.unboxTime
        self.gui:setVisible( "Open", false )
    elseif self.gui:isActive() then
        self.gui:close()
    end
end

dofile("$SURVIVAL_DATA/Scripts/game/survival_items.lua")

function LootCrate:get_random_item()
    if not self.lootTable then
        self.lootTable = self:get_loot_table()
    end
    return self.lootTable[math.random(1, #self.lootTable)]
end

function LootCrate:get_loot_table()
    local itemPool = {}
    for uuid, item in pairs(g_shop) do
        if item.price <= g_moneyEarned + 1000 then
            itemPool[#itemPool+1] = {price = item.price, uuid = uuid}
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

        sortedPool[#sortedPool+1] = sm.uuid.new(itemPool[mostExpensiveItem].uuid)
        table.remove(itemPool, mostExpensiveItem)
    end

    return sortedPool
end

