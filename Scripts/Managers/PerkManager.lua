---@class PerkManager : ScriptableObjectClass
PerkManager = class()
PerkManager.isSaveObject = true

function PerkManager:server_onCreate()
    self.saved = self.storage:load()

    if self.saved == nil then
        self.saved = {}
        self.saved.perks = {}
        self.saved.multipliers = {
            research = 1,
            pollution = 1
        }
    end

    if not g_perkManager then
        g_perkManager = self
    end

    self:sv_saveDataAndSync()
end

function PerkManager:sv_saveDataAndSync()
    self.storage:save(self.saved)
    self.network:setClientData({ perks = self.saved.perks })
end

function PerkManager.sv_addPerk(perk)
    g_perkManager.saved.perks[perk.name] = true

    if perk.multiplier then
        for k, v in pairs(perk.multiplier) do
            g_perkManager.sv.saved.multipliers[k] = v * g_perkManager.sv.saved.multipliers[k]
        end
    end

    sm.event.sendToScriptableObject(g_perkManager.scriptableObject, "sv_saveDataAndSync")
end

function PerkManager:client_onCreate()
    self.cl = {}
    self.cl.perks = {}

    if not g_perkManager then
        g_perkManager = self
    end
end

function PerkManager:client_onClientDataUpdate(clientData, channel)
    self.cl.perks = clientData.perks
end



function PerkManager.isPerkOwned(perk)
    return (g_perkManager.saved and g_perkManager.saved.perks[perk]) or g_perkManager.cl.perks[perk]
end