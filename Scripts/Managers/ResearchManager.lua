---@class ResearchManager:ScriptableObjectClass

dofile("$CONTENT_DATA/Scripts/util/util.lua")

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
        local safeData = self.sv.saved
		local research = safeData.research
        local progressFraction = (research[self.sv.tier] or 0)/self.tiers[self.sv.tier].goal

        for tier, progress in ipairs(research) do
            research[tier] = tostring(progress)
        end

		self.storage:save(self.sv.saved)

		self.network:setClientData({ research = safeData.research, tier = self.sv.tier, progress = string.format("%.2f", progressFraction*100)})

        for tier, progress in ipairs(research) do
           research[tier] = tonumber(progress)
        end
    end
end

function ResearchManager.sv_addResearch(shape)
    local tier = g_ResearchManager.tiers[g_ResearchManager.sv.tier]
    if tier.uuid ~= tostring(shape.uuid) then
        return false
    end

    local money = shape.interactable.publicData.value
    local reserachProgress = g_ResearchManager.sv.saved.research[g_ResearchManager.sv.tier]

	g_ResearchManager.sv.saved.research[g_ResearchManager.sv.tier] = math.min((reserachProgress or 0) + money, tier.goal)

    if tier.goal == g_ResearchManager.sv.saved.research[g_ResearchManager.sv.tier] then
        g_ResearchManager.sv.tier = g_ResearchManager.sv.tier + 1
        --TODO send notification
        sm.gui.chatMessage("#0000ffReseach finsihed")
    end

    return true
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
		g_factoryHud:setIconImage( "ResearchIcon", sm.uuid.new(self.tiers[self.cl.tier].uuid) )
        g_factoryHud:setText( "Research","#00dddd" .. self.cl.progress .. "%")
	end
end

function ResearchManager.cl_getCurrentTier()
    if g_ResearchManager then
        return g_ResearchManager.cl.tier
    end
end

function ResearchManager.cl_getTierProgress(tier)
    local progress = g_ResearchManager.sv.saved.research[tier] or 0
    local goal = g_ResearchManager.tiers[tier] and g_ResearchManager.tiers[tier].goal
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