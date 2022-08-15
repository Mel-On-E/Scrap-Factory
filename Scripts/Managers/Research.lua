dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
local renderables = { "$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook.rend" }
local renderablesTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_logbook.rend",
	"$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook_tp_animlist.rend" }
local renderablesFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_logbook.rend",
	"$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook_fp_animlist.rend" }
dofile("$CONTENT_DATA/Scripts/util/util.lua")
sm.tool.preloadRenderables(renderables)
sm.tool.preloadRenderables(renderablesTp)
sm.tool.preloadRenderables(renderablesFp)
---@class Research : ScriptableObjectClass
Research = class()

function Research:client_onCreate()
	if not g_cl_research then
		g_cl_research = self
	end

	self.cl = {}
	self.cl.tier = 1
	self.cl.unlockIndex = 0
	self.cl.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Research.layout")
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
	local progress, goal = ResearchManager.cl_getTierProgress(self.cl.tier)
	self.cl.gui:setText("Progress", format_money({money = progress}) .. "/" .. format_money({money = goal}) ..
		" (" .. string.format("%.2f", progress/goal*100) .. "%)")
	self.cl.gui:setIconImage("Icon", ResearchManager.cl_getTierUuid(self.cl.tier))

	local unlocks = ResearchManager.cl_getTierUnlocks(self.cl.tier)
	for i = 1, 6, 1 do
		local uuid = unlocks[i + self.cl.unlockIndex] or "00000000-0000-0000-0000-000000000000"
		self.cl.gui:setIconImage("IconUnlock_" .. tostring(i), sm.uuid.new(uuid))
	end
end

function Research.cl_e_open_gui()
	g_cl_research.cl.tier = ResearchManager.cl_getCurrentTier()
	Research.update_gui(g_cl_research)
	g_cl_research.cl.gui:open()
end

function Research.cl_e_isGuiOpen()
	return g_cl_research.cl.gui:isActive()
end

function Research:cl_tier_next()
	self:change_tier(1)
end

function Research:cl_tier_prev()
	self:change_tier(-1)
end

function Research:change_tier(change)
	self.cl.tier = self.cl.tier + change
	self.cl.tier =  math.max(math.min(self.cl.tier,  ResearchManager.cl_getTierCount()), 1)
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