dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
local renderables = { "$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook.rend" }
local renderablesTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_logbook.rend",
	"$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook_tp_animlist.rend" }
local renderablesFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_logbook.rend",
	"$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook_fp_animlist.rend" }
dofile("$CONTENT_DATA/Scripts/util.lua")
sm.tool.preloadRenderables(renderables)
sm.tool.preloadRenderables(renderablesTp)
sm.tool.preloadRenderables(renderablesFp)
---@class Research : ToolClass
Research = class()

function Research:cl_onCreate()
	g_researchTool = self.tool
	self.cl = {}
	if self.tool:isLocal() then
		self.tiers = sm.json.open("$CONTENT_DATA/tiers.json")
		self.cl.tier = 1

		self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Research.layout")

		self.gui:setButtonCallback("NextTier", "cl_tier_next")
		self.gui:setButtonCallback("PrevTier", "cl_tier_prev")
		self:update_gui()

		self.gui:setOnCloseCallback("cl_onGuiClosed")

		self.cl.seatedEquiped = false
	end
	self:client_onRefresh()
end

function Research:client_onFixedUpdate()
	--self:update_gui() DEBUG
	--sm.gui.displayAlertText("I'M THE GREATEST CODERR ON TEHRE INTERE (flat) EARTH")
end

function Research:update_gui()
	self.gui:setText("TierName", "Tier " .. tostring(self.cl.tier))
	local i = 1
	for uuid, quantity in pairs(self.tiers[self.cl.tier].goals) do
		if g_research.tier == self.cl.tier then
			local precentage = math.floor((g_research[uuid].quantity / g_research[uuid].goal) * 100)
			self.gui:setText("Progress" .. tostring(i),
				"$" ..
				tostring(g_research[uuid].quantity) .. "/" .. tostring(g_research[uuid].goal) .. " (" .. tostring(precentage) .. "%)")
		else
			self.gui:setText("Progress" .. tostring(i), "$0/" .. tostring(quantity) .. " (0%)")
		end

		self.gui:setIconImage("Icon" .. tostring(i), sm.uuid.new(uuid))


		i = i + 1
	end
end

function Research:cl_tier_next()
	self.cl.tier = math.min(self.cl.tier + 1, #self.tiers)
	self:update_gui()
end

function Research:cl_tier_prev()
	self.cl.tier = math.max(self.cl.tier - 1, 1)
	self:update_gui()
end