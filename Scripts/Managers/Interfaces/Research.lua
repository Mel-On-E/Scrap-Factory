dofile("$CONTENT_DATA/Scripts/Managers/Interfaces/Interface.lua")

---@class Research : Interface
Research = class(Interface)

function Research:client_onCreate()
	if not g_cl_research then
		g_cl_research = self
	end

	local params = {}
	params.layout = "$CONTENT_DATA/Gui/Layouts/Research.layout"
	Interface.cient_onCreate(self, params)

	self.cl.tier = 1
	self.cl.unlockIndex = 0
	self.cl.gui:setButtonCallback("NextTier", "cl_tier_next")
	self.cl.gui:setButtonCallback("PrevTier", "cl_tier_prev")
	self.cl.gui:setButtonCallback("UnlocksNext", "cl_unlocks_next")
	self.cl.gui:setButtonCallback("UnlocksPrev", "cl_unlocks_prev")
end

function Research:client_onFixedUpdate()
	if self.cl.gui:isActive() then
		self:update_gui()
	end
end

function Research:update_gui()
	self.cl.gui:setText("TierName", language_tag("ResearchTier") .. tostring(self.cl.tier))
	local tierUuid = ResearchManager.cl_getTierUuid(self.cl.tier)
	self.cl.gui:setIconImage("Icon", tierUuid)
	self.cl.gui:setText("ResearchName", sm.shape.getShapeTitle(tierUuid))
	self.cl.gui:setText("ResearchDesc", "#ffffff" .. language_tag("DescTier" .. tostring(self.cl.tier)))


	local progress, goal = ResearchManager.cl_getTierProgress(self.cl.tier)
	if self.cl.tier < ResearchManager.cl_getCurrentTier() then
		goal = progress
	end
	self.cl.gui:setText("Progress",
		format_number({ format = "money", value = progress, color = "#00dddd" }) ..
		"/" .. format_number({ format = "money", value = goal, color = "#00dddd" }) ..
		"\n(" .. string.format("%.2f", progress / goal * 100) .. "%)")


	local unlocks = ResearchManager.cl_getTierUnlocks(self.cl.tier)
	for i = 1, 6, 1 do
		local uuid = unlocks[i + self.cl.unlockIndex] or "00000000-0000-0000-0000-000000000000"
		self.cl.gui:setIconImage("IconUnlock_" .. tostring(i), sm.uuid.new(uuid))
	end
end

function Research.cl_e_open_gui()
	g_cl_research.cl.tier = ResearchManager.cl_getCurrentTier()
	Research.update_gui(g_cl_research)
	g_cl_research.cl.gui:setText("Unlocks", language_tag("ResearchUnlocks"))

	Interface.cl_e_open_gui(g_cl_research)
end

function Research.cl_e_isGuiOpen()
	return Interface.cl_e_isGuiOpen(g_cl_research)
end

function Research:cl_tier_next()
	self:change_tier(1)
end

function Research:cl_tier_prev()
	self:change_tier(-1)
end

function Research:change_tier(change)
	self.cl.tier = self.cl.tier + change
	self.cl.tier = math.max(math.min(self.cl.tier, ResearchManager.cl_getTierCount()), 1)
	self.cl.unlockIndex = 0
	self:update_gui()
end

function Research:cl_unlocks_next()
	self:change_unlock_index(1)
end

function Research:cl_unlocks_prev()
	self:change_unlock_index(-1)
end

function Research:change_unlock_index(change)
	self.cl.unlockIndex = self.cl.unlockIndex + change

	local unlocks = #ResearchManager.cl_getTierUnlocks(self.cl.tier)
	local max = math.max(0, unlocks - 6)
	self.cl.unlockIndex = math.min(self.cl.unlockIndex, max)
	self.cl.unlockIndex = math.max(self.cl.unlockIndex, 0)
end

function Research.cl_close()
	Interface.cl_close(g_cl_research)
end
