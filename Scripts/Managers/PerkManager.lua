---@class PerkManager : ScriptableObjectClass
PerkManager = class()
PerkManager.isSaveObject = true

function PerkManager:server_onCreate()
    self.sv = {}
    self.sv.saved = self.storage:load()
    self.sv.multipliers = {
        research = 1,
        pollution = 1
    }

    if self.sv.saved == nil then
        self.sv.saved = {}
        self.sv.saved.perks = {}
    end

    if not g_perkManager then
        g_perkManager = self
    end

    local perks = sm.json.open("$CONTENT_DATA/Scripts/perks.json")
    for name, _ in pairs(self.sv.saved.perks) do
        local perk = perks[name]
        perk.name = name
        self.sv_addPerk(perk)
    end

    self:sv_saveDataAndSync()
    self.init = true
end

function PerkManager:sv_saveDataAndSync()
    self.storage:save(self.sv.saved)
    self.network:setClientData({ perks = self.sv.saved.perks })
end

function PerkManager.sv_addPerk(perk)
    print(perk)
    g_perkManager.sv.saved.perks[perk.name] = true

    if perk.multiplier then
        for k, v in pairs(perk.multiplier) do
            print(k,v)
            g_perkManager.sv.multipliers[k] = v * g_perkManager.sv.multipliers[k]
        end
    end

    if g_perkManager.init then
        sm.event.sendToScriptableObject(g_perkManager.scriptableObject, "sv_saveDataAndSync")
    end
end

function PerkManager.sv_getMultiplier(multiplier)
    return g_perkManager.sv.multipliers[multiplier] or 1
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
    return (g_perkManager.sv.saved and g_perkManager.sv.saved.perks[perk]) or g_perkManager.cl.perks[perk]
end