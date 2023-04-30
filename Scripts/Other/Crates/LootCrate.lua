---LootCrates randomly spawn in the world. They can be opened to gain random items.
---@class LootCrate : ShapeClass
---@field sv LootCrateSv
---@field cl LootCrateCl
LootCrate = class(nil)

--------------------
-- #region Server
--------------------

---time in minutes until a loot crate despawns
local despawnTime = 10

function LootCrate:server_onCreate()
    self.sv = { timeout = 0 }

    local body = self.shape.body
    body:setLiftable(false)
    body:setErasable(false)
    body:setBuildable(false)
    body:setPaintable(false)
end

function LootCrate:server_onFixedUpdate()
    --handle timeout
    self.sv.timeout = self.sv.timeout + 1

    if self.sv.timeout > 40 * 60 * despawnTime then
        self.shape:destroyShape(0)
    end
end

function LootCrate:sv_openBox(_, player)
    self.network:sendToClients("cl_openBoxForReal", player)
end

---gives an item to a player
---@param params LootCrateItemParams
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

-- #endregion

--------------------
-- #region Client
--------------------
local minUnboxTime = 3 --seconds
local maxUnboxTime = 7 --seconds
local ticksPerItem = 5

function LootCrate:client_onCreate()
    self.cl = {
        opened = false,
        blips = {}
    }
end

function LootCrate:client_onFixedUpdate()
    local tick = sm.game.getCurrentTick()

    if self.cl.opened and self.cl.openTick then
        if tick % ticksPerItem == 0 then
            --cycle through random items and play sounds
            self.loot = self:get_random_item()
            self.cl.gui:setIconImage("Icon", self.loot)
            self.cl.gui:setText("Name", sm.shape.getShapeTitle(self.loot))


            local blip = sm.effect.createEffect("Horn - Honk", sm.localPlayer.getPlayer():getCharacter())
            blip:setParameter("pitch", 1 - (self.cl.openTick - tick) / self.unboxTime)
            blip:start()

            self.cl.blips[#self.cl.blips + 1] = { effect = blip, tick = tick }
        end

        if tick > self.cl.openTick then
            --give item
            self.cl.openTick = nil
            self.network:sendToServer("sv_giveItem",
                { player = sm.localPlayer.getPlayer(), item = self.loot, quantity = 1 })
            sm.gui.displayAlertText("Found #df7f01" .. sm.shape.getShapeTitle(self.loot) .. "#ffffff x" .. tostring(1))
        end
    end

    --destroy old blip effects
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

---opens the crate gui for the player who opened the box
function LootCrate:cl_openBoxForReal(player)
    self.cl.opened = true
    if sm.localPlayer.getPlayer() == player then
        self.unboxTime = math.random(minUnboxTime, maxUnboxTime) * 40
        self.cl.openTick = sm.game.getCurrentTick() + self.unboxTime
        self.cl.gui:setVisible("Open", false)
    elseif self.cl.gui and self.cl.gui:isActive() then
        self.cl.gui:close()
    end
end

-- #endregion

--------------------
-- #region LootTable
--------------------

dofile("$SURVIVAL_DATA/Scripts/game/survival_items.lua")

---returns a random item from the lootTable
---@return Uuid
function LootCrate:get_random_item()
    self.cl.lootTable = self.cl.lootTable or self:get_loot_table()
    return self.cl.lootTable[math.random(1, #self.cl.lootTable)]
end

---returns the lootTable
---@return table<number, Uuid>
function LootCrate:get_loot_table()
    local tier = ResearchManager.cl_getCurrentTier()
    local itemPool = {}
    for uuid, item in pairs(g_shop) do
        --include items up to current tier
        if item.tier < tier then
            --items that are cheaper than money earned + 1000
            if item.price <= MoneyManager.cl_moneyEarned() + 1000 then
                itemPool[#itemPool + 1] = { price = item.price, uuid = uuid }
            end
        end
    end

    --only keep the 10 most expensive items
    --[[local sortedPool = {}
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
    end]]

    return itemPool
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class LootCrateSv
---@field timeout number the number of ticks a crate has existed for

---@class LootCrateItemParams
---@field player Player player to receive the item
---@field item Uuid item to receive
---@field quantity number quantity of the item to receive

---@class LootCrateCl
---@field opened boolean whether the crate has been opened
---@field blips table<number, LootCrateBlip> table of blip effects that have been played
---@field gui GuiInterface the LootCrate gui
---@field openTick number|nil the tick at which the crate will be opened

---@class LootCrateBlip
---@field effect Effect the blip effect
---@field tick number the tick at which the effect started playing


-- #endregion
