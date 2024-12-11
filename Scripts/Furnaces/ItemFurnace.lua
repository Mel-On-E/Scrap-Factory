---A Furnace that can sell any item like the sell tool
---@class ItemFurnace : Furnace
---@diagnostic disable-next-line: param-type-mismatch
ItemFurnace = class(Furnace)

--------------------
-- #region Server
--------------------

function ItemFurnace:server_onCreate()
    local params = {
        filters = sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.staticBody
    }
    Furnace.server_onCreate(self, params)
    self.sv.trigger:setShapeDetection(true)
end

function ItemFurnace:server_onFixedUpdate()
    Furnace.server_onFixedUpdate(self)

    if not self.powerUtil.active then return end

    --sell shapes
    for k, v in pairs(self.sv.trigger:getShapes()) do
        if not sm.exists(v.shape) then goto continue end

        local sellValue = Sell.calculateSellValue(v.shape)
        if not sellValue then goto continue end

        sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_numberEffect",
            {
                pos = v.shape:getWorldPosition(),
                value = tostring(sellValue),
                format = "money",
                effect = "Furnace - Sell"
            })
        MoneyManager.sv_addMoney(sellValue)

        v.shape:destroyShape(0)
        ::continue::
    end
end

function ItemFurnace:sv_onEnter(trigger, results)
    return
end

-- #endregion

--------------------
-- #region Client
--------------------

function ItemFurnace:client_onCreate()
    Furnace.client_onCreate(self)

    Furnace.cl_setSellAreaEffectColor(self, sm.color.new(1, 1, 0))
end

function ItemFurnace:client_canInteract()
    return false
end

-- #endregion
