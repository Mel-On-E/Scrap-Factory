dofile("$CONTENT_DATA/Scripts/util/util.lua")
dofile("$CONTENT_DATA/Scripts/Managers/PollutionManager.lua")

---@class ResearchManager : ScriptableObjectClass
ResearchManager = class()
ResearchManager.isSaveObject = true

function ResearchManager:server_onCreate()
    self.sv = {}
    self.sv.saved = self.storage:load()

    if self.sv.saved == nil then
        self.sv.saved = {}
        self.sv.saved.research = {}
    else
        for tier, progress in ipairs(self.sv.saved.research) do
            self.sv.saved.research[tier] = tonumber(progress)
        end
    end

    self.tiers = sm.json.open("$CONTENT_DATA/Scripts/tiers.json")

    self.sv.tier = 1
    for tier, progress in ipairs(self.sv.saved.research) do
        if progress == self.tiers[tier].goal then
            self.sv.tier = tier + 1
        end
    end

    if not g_ResearchManager then
        g_ResearchManager = self
    end
end

function ResearchManager:server_onFixedUpdate()
    if sm.game.getCurrentTick() % 40 == 0 then
        self:sv_saveDataAndSync()
    end

    if self.notify then
        self.network:sendToClients("cl_research_done", self.sv.tier - 1)
        self.notify = false
    end
end

function ResearchManager:sv_saveDataAndSync()
    local safeData = self.sv.saved
    local research = safeData.research
    local progressFraction = (research[self.sv.tier] or 0) /
        (self.tiers[self.sv.tier].goal * PollutionManager.getResearchMultiplier())

    for tier, progress in ipairs(research) do
        research[tier] = tostring(progress)
    end

    self.storage:save(self.sv.saved)

    self.network:setClientData({ research = safeData.research, tier = self.sv.tier,
        progress = string.format("%.2f", progressFraction * 100) })

    for tier, progress in ipairs(research) do
        research[tier] = tonumber(progress)
    end
end

function ResearchManager.sv_addResearch(value, shape)
    local tier = g_ResearchManager.tiers[g_ResearchManager.sv.tier]
    if shape and tier.uuid ~= tostring(shape.uuid) then
        return false
    end

    local reserachProgress = g_ResearchManager.sv.saved.research[g_ResearchManager.sv.tier]
    local goal = tier.goal * PollutionManager.getResearchMultiplier()

    g_ResearchManager.sv.saved.research[g_ResearchManager.sv.tier] = math.min((reserachProgress or 0) + value, goal)

    if goal == g_ResearchManager.sv.saved.research[g_ResearchManager.sv.tier] then
        g_ResearchManager.sv.tier = g_ResearchManager.sv.tier + 1
        g_ResearchManager.notify = true
    end

    return true
end

function ResearchManager:sv_resetResearch()
    self.sv.saved.research[self.sv.tier] = 0
    self.storage:save(self.sv.saved)

    self:sv_saveDataAndSync()
end

function ResearchManager:client_onCreate()
    self.cl = {}
    self.cl.research = {}
    self.cl.tier = 0
    self.cl.progress = ""

    self.tiers = sm.json.open("$CONTENT_DATA/Scripts/tiers.json")

    if not g_ResearchManager then
        g_ResearchManager = self
    end
end

function ResearchManager:client_onClientDataUpdate(clientData)
    for tier, progress in ipairs(clientData.research) do
        self.cl.research[tier] = tonumber(progress)
    end
    self.cl.tier = tonumber(clientData.tier)
    self.cl.progress = clientData.progress
end

function ResearchManager:client_onFixedUpdate()
    if g_factoryHud and self.cl.tier > 0 then
        g_factoryHud:setIconImage("ResearchIcon", sm.uuid.new(self.tiers[self.cl.tier].uuid))
        g_factoryHud:setText("Research", "#00dddd" .. self.cl.progress .. "%")
    end

    if self.cl.endEffect and self.cl.endEffect < sm.game.getCurrentTick() then
        self.cl.endEffect = nil
        sm.event.sendToPlayer(player, "cl_e_destroyEffect", "ResearchDone")
    end
end

function ResearchManager:cl_research_done(tier)
    sm.gui.displayAlertText("#00dddd" .. string.format(language_tag("ResearchFinished"), tostring(tier)))
    local unlocks = self.cl_getTierUnlocks(tier)
    for _, uuid in ipairs(unlocks) do
        sm.gui.chatMessage(language_tag("RsearchUnlockItem") .. "#00dddd" .. sm.shape.getShapeTitle(sm.uuid.new(uuid)))
    end

    Shop.cl_close()
    Research.cl_close()

    player = sm.localPlayer.getPlayer()
    sm.event.sendToPlayer(player, "cl_e_createEffect",
        { id = "ResearchDone", effect = "ResearchDone", host = player:getCharacter() })
    sm.event.sendToPlayer(player, "cl_e_startEffect", "ResearchDone")
    self.cl.endEffect = sm.game.getCurrentTick() + 40 * 16
end

function ResearchManager.cl_getCurrentTier()
    if g_ResearchManager then
        return g_ResearchManager.cl.tier
    end
end

function ResearchManager.cl_getTierProgress(tier)
    local progress = g_ResearchManager.sv.saved.research[tier] or 0
    local goal = (g_ResearchManager.tiers[tier] and g_ResearchManager.tiers[tier].goal) *
        PollutionManager.getResearchMultiplier()
    return progress, goal
end

function ResearchManager.cl_getTierUnlocks(tier)
    return g_ResearchManager.tiers[tier].unlocks
end

function ResearchManager.cl_getTierUuid(tier)
    return sm.uuid.new(g_ResearchManager.tiers[tier].uuid)
end

function ResearchManager.cl_getTierCount()
    return #g_ResearchManager.tiers
end
