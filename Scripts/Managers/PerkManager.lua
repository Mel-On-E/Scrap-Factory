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
        }
    }
    self.sv.saved = self.sv.saved or { perks = {} }

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
    end

    if g_perkManager.sv.init then
        sm.event.sendToScriptableObject(g_perkManager.scriptableObject, "sv_saveDataAndSync")
    end
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

---@class PerkManagerSvSaved
---@field perks table<string, boolean> table of owned perks

---@class PerkManagerSvMultipliers prestige multipliers
---@field research number
---@field pollution number

---@class PerkManagerCl
---@field perks table<string, boolean> table of owned perks
