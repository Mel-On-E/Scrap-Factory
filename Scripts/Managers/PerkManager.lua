---Perks can be bought with prestige points. They are permanent upgrades to help players get even more prestige points!
---@class PerkManager : ScriptableObjectClass
---@field cl PerkManagerCl
---@field sv PerkManagerSv
PerkManager = class()
PerkManager.isSaveObject = true

local perksJson = unpackNetworkData(sm.json.open("$CONTENT_DATA/Scripts/perks.json"))

--------------------
-- #region Server
--------------------

function PerkManager:server_onCreate()
    g_perkManager = g_perkManager or self

    self.sv = {
        saved = self.storage:load(),
        multipliers = {
            research = 1,
            pollution = 1
        },
        items = {}
    }

    self.sv.saved = self.sv.saved or {
        perks = {},
        itemsCollected = {}
    }

    local perks = sm.json.open("$CONTENT_DATA/Scripts/perks.json")
    for name, _ in pairs(self.sv.saved.perks) do
        local perk = perks[name]
        perk.name = name
        self.sv_addPerk(perk)
    end

    self:sv_saveDataAndSync()
    self.sv.init = true
end

function PerkManager:sv_saveDataAndSync()
    self.storage:save(self.sv.saved)
    self.network:setClientData({ perks = self.sv.saved.perks })
end

---activates a perk and saves it
function PerkManager.sv_addPerk(perk)
    g_perkManager.sv.saved.perks[perk.name] = true

    for effect, params in pairs(perk.effects) do
        if effect == "multiplier" then
            for key, multiplier in pairs(params) do
                g_perkManager.sv.multipliers[key] = multiplier * g_perkManager.sv.multipliers[key]
            end
        end

        if effect == "items" then
            for key, uuid in pairs(params) do
                g_perkManager.sv.items[#g_perkManager.sv.items + 1] = sm.uuid.new(uuid)

                if g_perkManager.sv.init then
                    --give item to all players when perk first bought
                    for _, player in ipairs(sm.player.getAllPlayers()) do
                        sm.event.sendToGame("sv_giveItem", { player = player, item = sm.uuid.new(uuid), quantity = 1 })
                        local itemsCollected = g_perkManager.sv.saved.itemsCollected[uuid] or {}
                        itemsCollected[#itemsCollected + 1] = player.id
                        g_perkManager.sv.saved.itemsCollected[uuid] = itemsCollected
                    end
                end
            end
        end
    end

    if g_perkManager.sv.init then
        print(g_perkManager.sv.saved.itemsCollected)
        sm.event.sendToScriptableObject(g_perkManager.scriptableObject, "sv_saveDataAndSync")
    end
end

---clear the list of items to give to offline players
function PerkManager.Sv_clearItemsToCollect()
    g_perkManager.sv.saved.itemsCollected = {}
    sm.event.sendToScriptableObject(g_perkManager.scriptableObject, "sv_saveDataAndSync")
end

---give a player perk items that have not been given bc the player was offline
function PerkManager:sv_giveItemsLeftToCollect(player)
    for uuid, playerIDs in pairs(self.sv.saved.itemsCollected) do
        for _, id in ipairs(playerIDs) do
            if player.id == id then
                goto continue
            end
        end

        sm.event.sendToGame("sv_giveItem", { player = player, item = sm.uuid.new(uuid), quantity = 1 })
        local itemsCollected = g_perkManager.sv.saved.itemsCollected[uuid] or {}
        itemsCollected[#itemsCollected + 1] = player.id
        g_perkManager.sv.saved.itemsCollected[uuid] = itemsCollected

        ::continue::
    end
    sm.event.sendToScriptableObject(g_perkManager.scriptableObject, "sv_saveDataAndSync")
end

---returns a prestige multiplier
---@param name string name of the multiplier
---@return number multiplier prestige multiplier
function PerkManager.sv_getMultiplier(name)
    return g_perkManager.sv.multipliers[name] or 1
end

-- #endregion

--------------------
-- #region Client
--------------------

function PerkManager:client_onCreate()
    g_perkManager = g_perkManager or self

    self.cl = {
        data = {
            perks = {}
        }
    }
end

function PerkManager:client_onClientDataUpdate(clientData, channel)
    self.cl.data = clientData
end

-- #endregion

---Check if a perk is already owned
---@param perk string
---@return boolean owned whether the perk is already owned
function PerkManager.isPerkOwned(perk)
    return (g_perkManager.sv and g_perkManager.sv.saved.perks[perk]) or g_perkManager.cl.data.perks[perk]
end

---Check if a perk is unlocked
---@param perk string
---@return boolean unlocked whether the perk is unlocked
function PerkManager.isPerkUnlocked(perk)
    for _, requirement in ipairs(perksJson[perk].requires) do
        if not PerkManager.isPerkOwned(requirement) then
            return false
        end
    end
    return true
end

--------------------
-- #region Types
--------------------

---@class PerkManagerSv
---@field saved PerkManagerSvSaved
---@field multipliers PerkManagerSvMultipliers
---@field init boolean whether the manager has been initialized
---@field items table<integer, Uuid> list of items that have been unlocked via perks (and should be in the player's inventory)

---@class PerkManagerSvSaved
---@field perks table<string, boolean> table of owned perks
---@field itemsCollected table<string, table<integer, integer>> items that have been collected this prestige

---@class PerkManagerSvMultipliers prestige multipliers
---@field research number how research points are boosted
---@field pollution number how much polluton affects research

---@class PerkManagerCl
---@field perks table<string, boolean> table of owned perks
