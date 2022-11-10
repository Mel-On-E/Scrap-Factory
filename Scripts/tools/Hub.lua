dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
local renderables = { "$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook.rend" }
local renderablesTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_logbook.rend",
	"$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook_tp_animlist.rend" }
local renderablesFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_logbook.rend",
	"$SURVIVAL_DATA/Character/Char_Tools/Char_logbook/char_logbook_fp_animlist.rend" }
dofile("$CONTENT_DATA/Scripts/util/util.lua")

g_sobSet = sm.json.open("$CONTENT_DATA/ScriptableObjects/ScriptableObjectSets/interfaces.sobSet")
for _, sob in ipairs(g_sobSet.scriptableObjectList) do
	dofile(sob.filename)
end

sm.tool.preloadRenderables(renderables)
sm.tool.preloadRenderables(renderablesTp)
sm.tool.preloadRenderables(renderablesFp)

---@class page
---@field uuid string
---@field price number
---@field category string

---@class client;
---@field gui GuiInterface
---@field filteredPages page[][]
---@field itemPages page[][]
---amount of pages
---@field pageNum number
---current page
---@field curPage number
---current item
---@field curItem number
---current quantity
---@field quantity number


---@class Hub : ToolClass
---@field cl client
Hub = class()

function Hub:server_onCreate()
	if SOBsInit then return end

	for _, sob in ipairs(g_sobSet.scriptableObjectList) do
		sm.scriptableObject.createScriptableObject(sm.uuid.new(sob.uuid), self.tool)
	end
	SOBsInit = true
end

function Hub:client_onCreate()
	self.cl = {}
	self.cl.currentInterface = "Shop"
	self.cl.unequipTicks = 0

	self:client_onRefresh()
end

function Hub:client_onFixedUpdate()
	if self.tool:isLocal() and self.cl.currentInterface then
		local active = false

		for _, sob in ipairs(g_sobSet.scriptableObjectList) do
			if _G[sob.classname].cl_e_isGuiOpen() then
				self.cl.currentInterface = sob.classname
				active = true
				self.cl.unequipTicks = 0
			end
		end

		if not active and self.tool:isEquipped() then
			if self.cl.unequipTicks > 1 then
				self:cl_onGuiClosed()
			else
				self.cl.unequipTicks = self.cl.unequipTicks + 1
			end
		elseif active and not self.tool:isEquipped() then
			sm.tool.forceTool(self.tool)
		end
	end
end

function Hub:cl_openGui()
	local interface = self.cl.currentInterface

	for _, sob in ipairs(g_sobSet.scriptableObjectList) do
		if sob.classname == interface then
			_G[sob.classname]:cl_e_open_gui()
		end
	end
end

function Hub.client_onEquip(self)
	if self.tool:isLocal() then
		if TutorialManager.cl_getTutorialStep() > 5 then
			self:cl_openGui()
		else
			sm.gui.displayAlertText(language_tag("TutorialLockedFeature"))
		end
	end

	self:client_onEquipAnimations()
end

function Hub.client_equipWhileSeated(self)
	if not self.cl.seatedEquiped then
		self:cl_openGui()

		self.cl.seatedEquiped = true
	end
end

function Hub.cl_onGuiClosed(self)
	sm.tool.forceTool(nil)
	self.cl.seatedEquiped = false
end

--ANIMATION STUFF BELOW
function Hub:client_onEquipAnimations()
	self.cl.wantsEquip = true
	self.cl.seatedEquiped = false

	local currentRenderablesTp = {}
	concat(currentRenderablesTp, renderablesTp)
	concat(currentRenderablesTp, renderables)

	local currentRenderablesFp = {}
	concat(currentRenderablesFp, renderablesFp)
	concat(currentRenderablesFp, renderables)

	self.tool:setTpRenderables(currentRenderablesTp)

	if self.tool:isLocal() then
		self.tool:setFpRenderables(currentRenderablesFp)
	end

	--TODO disable animations bc they are funny when broken haha lol xd OMG ROFL LMAO
	self:cl_loadAnimations()
	setTpAnimation(self.tpAnimations, "pickup", 0.0001)

	if self.tool:isLocal() then
		swapFpAnimation(self.fpAnimations, "unequip", "equip", 0.2)
	end
end

function Hub.client_onRefresh(self)
	self:cl_loadAnimations()
end

function Hub.client_onUpdate(self, dt)
	-- First person animation
	local isCrouching = self.tool:isCrouching()

	if self.tool:isLocal() then
		updateFpAnimations(self.fpAnimations, self.cl.equipped, dt)
	end

	if not self.cl.equipped then
		if self.cl.wantsEquip then
			self.cl.wantsEquip = false
			self.cl.equipped = true
		end
		return
	end

	local crouchWeight = isCrouching and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight
	local totalWeight = 0.0

	for name, animation in pairs(self.tpAnimations.animations) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min(animation.weight + (self.tpAnimations.blendSpeed * dt), 1.0)

			if animation.looping == true then
				if animation.time >= animation.info.duration then
					animation.time = animation.time - animation.info.duration
				end
			end
			if animation.time >= animation.info.duration - self.cl.blendTime and not animation.looping then
				if (name == "putdown") then
					self.cl.equipped = false
				elseif animation.nextAnimation ~= "" then
					setTpAnimation(self.tpAnimations, animation.nextAnimation, 0.001)
				end
			end
		else
			animation.weight = math.max(animation.weight - (self.tpAnimations.blendSpeed * dt), 0.0)
		end

		totalWeight = totalWeight + animation.weight
	end

	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs(self.tpAnimations.animations) do

		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation(animation.time, weight)
		elseif animation.crouch then
			self.tool:updateAnimation(animation.info.name, animation.time, weight * normalWeight)
			self.tool:updateAnimation(animation.crouch.name, animation.time, weight * crouchWeight)
		else
			self.tool:updateAnimation(animation.info.name, animation.time, weight)
		end
	end
end

function Hub.client_onUnequip(self)
	self.cl.wantsEquip = false
	self.cl.seatedEquiped = false
	if sm.exists(self.tool) then
		setTpAnimation(self.tpAnimations, "useExit")
		if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" and
			self.fpAnimations.currentAnimation ~= "useExit" then
			swapFpAnimation(self.fpAnimations, "equip", "useExit", 0.2)
		end
	end
end

function Hub.cl_loadAnimations(self)
	-- TP
	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			idle = { "logbook_use_idle", { looping = true } },
			sprint = { "logbook_sprint" },
			pickup = { "logbook_pickup", { nextAnimation = "useInto" } },
			putdown = { "logbook_putdown" },
			useInto = { "logbook_use_into", { nextAnimation = "idle" } },
			useExit = { "logbook_use_exit", { nextAnimation = "putdown" } }
		}
	)

	local movementAnimations = {
		idle = "logbook_use_idle",
		idleRelaxed = "logbook_idle_relaxed",

		runFwd = "logbook_run_fwd",
		runBwd = "logbook_run_bwd",
		sprint = "logbook_sprint",

		jump = "logbook_jump",
		jumpUp = "logbook_jump_up",
		jumpDown = "logbook_jump_down",

		land = "logbook_jump_land",
		landFwd = "logbook_jump_land_fwd",
		landBwd = "logbook_jump_land_bwd",

		crouchIdle = "logbook_crouch_idle",
		crouchFwd = "logbook_crouch_fwd",
		crouchBwd = "logbook_crouch_bwd"
	}

	for name, animation in pairs(movementAnimations) do
		self.tool:setMovementAnimation(name, animation)
	end

	if self.tool:isLocal() then
		-- FP
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				idle = { "logbook_use_idle", { looping = true } },
				equip = { "logbook_pickup", { nextAnimation = "useInto" } },
				unequip = { "logbook_putdown" },
				useInto = { "logbook_use_into", { nextAnimation = "idle" } },
				useExit = { "logbook_use_exit", { nextAnimation = "unequip" } }
			}
		)
	end

	setTpAnimation(self.tpAnimations, "idle", 5.0)
	self.cl.blendTime = 0.2
end
