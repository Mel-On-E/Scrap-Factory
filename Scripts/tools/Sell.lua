dofile("$GAME_DATA/Scripts/game/AnimationUtil.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")

dofile("$CONTENT_DATA/Scripts/util/util.lua")
dofile("$CONTENT_DATA/Scripts/Managers/LanguageManager.lua")

---The sell tool can be used to sell objects from the world and inventory
---@class Sell : ToolClass
---@field fpAnimations table
---@field tpAnimations table
---@field blendTime number
---@field cl SellCl
Sell = class()

--------------------
-- #region Server
--------------------

---Sell a shape and additionally items from the players inventory
---@param params SellSvSellParams
function Sell.sv_n_sell(self, params, player)
	if params.shape and sm.exists(params.shape) then
		sm.event.sendToPlayer(sm.player.getAllPlayers()[1], "sv_e_numberEffect",
			{
				pos = params.shape.worldPosition,
				value = tostring(params.value * params.quantity),
				format = "money",
				effect = "Action - Sell"
			})

		if params.quantity > 1 then
			-- sell items from inventory
			sm.container.beginTransaction()
			sm.container.spend(player:getInventory(), params.shape.uuid, params.quantity - 1)
			sm.container.endTransaction()
		end
		params.shape:destroyShape(0)

		MoneyManager.sv_addMoney(tonumber(params.value) * params.quantity, "sellTool")

		self.network:sendToClients("cl_n_onUseAnimation")
	end
end

---tries to start the tutorial explaing the tool
function Sell:sv_startTutorial()
	sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_tryStartTutorial", "SellTutorial")
end

-- #endregion

--------------------
-- #region Client
--------------------

local renderables = { "$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer.rend" }
local renderablesTp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_fertilizer.rend",
	"$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_tp_animlist.rend" }
local renderablesFp = { "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_fertilizer.rend",
	"$SURVIVAL_DATA/Character/Char_Tools/Char_fertilizer/char_fertilizer_fp_animlist.rend" }

local currentRenderablesTp = {}
local currentRenderablesFp = {}

local resellValue = 0.8       --the fraction of the shop price gained back by selling
local maxSellQuantity = 10000 --maximum amount of items to be sold at once

sm.tool.preloadRenderables(renderables)
sm.tool.preloadRenderables(renderablesTp)
sm.tool.preloadRenderables(renderablesFp)

function Sell.client_onCreate(self)
	self:cl_init()
end

function Sell.client_onRefresh(self)
	self:cl_init()
end

function Sell.cl_init(self)
	self:cl_loadAnimations()
	self.cl = {
		quantity = 1
	}
end

function Sell.client_onUpdate(self, dt)
	self:cl_onUpdateAnimations(dt)
end

function Sell.client_onEquip(self)
	self.cl.unlocked = TutorialManager.cl_isTutorialEventComplete("ResearchComplete")

	if self.cl.unlocked and self.tool:isLocal() then
		self.network:sendToServer("sv_startTutorial")
	elseif self.tool:isLocal() then
		sm.gui.displayAlertText(language_tag("TutorialLockedFeature"))
	end

	self:cl_onEquipAnimations()
end

function Sell.client_onUnequip(self)
	self:cl_onUnequipAnimations()
end

function Sell.client_onEquippedUpdate(self, primaryState, secondaryState)
	if not self.cl.unlocked then
		return false, false
	end

	-- Find shape
	local success, result = sm.localPlayer.getRaycast(7.5)
	if success and result.type == "body" then
		local shape = result:getShape()

		local shopItem = g_shop[tostring(shape.uuid)]
		if shopItem then
			local sellValue = math.floor(shopItem.price * resellValue)

			sm.gui.setCenterIcon("Use")
			local keyBindingText1 = sm.gui.getKeyBinding("Create", true)
			local keyBindingText2 = sm.gui.getKeyBinding("NextCreateRotation")
			local o1 = "<p textShadow='false' bg='gui_keybinds_bg_orange' color='#4f4f4f' spacing='9'>"
			local o2 = "</p>"

			local quantity = math.min(self.cl.quantity,
				sm.container.totalQuantity(sm.localPlayer.getInventory(), shape.uuid) + 1)

			sm.gui.setInteractionText(sm.shape.getShapeTitle(shape.uuid))
			sm.gui.setInteractionText("", keyBindingText1,
				language_tag("Sell") ..
				o1 .. format_number({ format = "money", value = sellValue, color = "#4f4f4f" }) ..
				o2 .. "x" .. o1 .. tostring(quantity) .. o2 .. " [" .. keyBindingText2 .. "]")

			if primaryState == sm.tool.interactState.start then
				-- sell items
				self:onUseAnimation()
				self.network:sendToServer("sv_n_sell",
					{ shape = shape, value = tostring(sellValue), quantity = quantity })
			end
		end
	end

	return false, false
end

function Sell:client_onToggle()
	self.cl.quantity = self.cl.quantity == maxSellQuantity and 1
		or math.min(self.cl.quantity * 10, maxSellQuantity)

	sm.gui.displayAlertText(language_tag("NewMaxSellQuantity") .. "#fc8b19" .. tostring(self.cl.quantity))
	sm.audio.play("ConnectTool - Rotate", sm.localPlayer.getPlayer():getCharacter():getWorldPosition())

	return true
end

-- #endregion

--------------------
-- #region Animation
--------------------

function Sell.cl_loadAnimations(self)
	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			idle = { "fertilizer_idle", { looping = true } },
			use = { "fertilizer_paint", { nextAnimation = "idle" } },
			sprint = { "fertilizer_sprint" },
			pickup = { "fertilizer_pickup", { nextAnimation = "idle" } },
			putdown = { "fertilizer_putdown" }
		}
	)
	local movementAnimations = {
		idle = "fertilizer_idle",
		idleRelaxed = "fertilizer_idle_relaxed",
		runFwd = "fertilizer_run_fwd",
		runBwd = "fertilizer_run_bwd",
		sprint = "fertilizer_sprint",
		jump = "fertilizer_jump",
		jumpUp = "fertilizer_jump_up",
		jumpDown = "fertilizer_jump_down",
		land = "fertilizer_jump_land",
		landFwd = "fertilizer_jump_land_fwd",
		landBwd = "fertilizer_jump_land_bwd",
		crouchIdle = "fertilizer_crouch_idle",
		crouchFwd = "fertilizer_crouch_fwd",
		crouchBwd = "fertilizer_crouch_bwd"
	}

	for name, animation in pairs(movementAnimations) do
		self.tool:setMovementAnimation(name, animation)
	end

	if self.tool:isLocal() then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				idle = { "fertilizer_idle", { looping = true } },
				sprintInto = { "fertilizer_sprint_into", { nextAnimation = "sprintIdle", blendNext = 0.2 } },
				sprintIdle = { "fertilizer_sprint_idle", { looping = true } },
				sprintExit = { "fertilizer_sprint_exit", { nextAnimation = "idle", blendNext = 0 } },
				use = { "fertilizer_paint", { nextAnimation = "idle" } },
				equip = { "fertilizer_pickup", { nextAnimation = "idle" } },
				unequip = { "fertilizer_putdown" }
			}
		)
	end
	setTpAnimation(self.tpAnimations, "idle", 5.0)
	self.blendTime = 0.2
end

function Sell.cl_onUpdateAnimations(self, dt)
	if not sm.exists(self.tool) then return end

	-- First person animation
	local isSprinting = self.tool:isSprinting()
	local isCrouching = self.tool:isCrouching()

	if self.tool:isLocal() then
		if self.equipped then
			if isSprinting and self.fpAnimations.currentAnimation ~= "sprintInto" and
				self.fpAnimations.currentAnimation ~= "sprintIdle" then
				swapFpAnimation(self.fpAnimations, "sprintExit", "sprintInto", 0.0)
			elseif not self.tool:isSprinting() and
				(self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto") then
				swapFpAnimation(self.fpAnimations, "sprintInto", "sprintExit", 0.0)
			end
		end
		updateFpAnimations(self.fpAnimations, self.equipped, dt)
	end

	if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
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
			if animation.time >= animation.info.duration - self.blendTime and not animation.looping then
				if (name == "use") then
					setTpAnimation(self.tpAnimations, "idle", 10.0)
				elseif name == "pickup" then
					setTpAnimation(self.tpAnimations, "idle", 0.001)
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

function Sell:cl_onEquipAnimations()
	self.wantEquipped = true

	currentRenderablesTp = {}
	currentRenderablesFp = {}

	for k, v in pairs(renderablesTp) do currentRenderablesTp[#currentRenderablesTp + 1] = v end
	for k, v in pairs(renderablesFp) do currentRenderablesFp[#currentRenderablesFp + 1] = v end
	for k, v in pairs(renderables) do currentRenderablesTp[#currentRenderablesTp + 1] = v end
	for k, v in pairs(renderables) do currentRenderablesFp[#currentRenderablesFp + 1] = v end

	local color = sm.item.getShapeDefaultColor(obj_consumable_fertilizer)
	self.tool:setTpRenderables(currentRenderablesTp)
	self.tool:setTpColor(color)
	if self.tool:isLocal() then
		self.tool:setFpRenderables(currentRenderablesFp)
		self.tool:setFpColor(color)
	end

	self:cl_loadAnimations()

	setTpAnimation(self.tpAnimations, "pickup", 0.0001)
	if self.tool:isLocal() then
		swapFpAnimation(self.fpAnimations, "unequip", "equip", 0.2)
	end
end

function Sell:cl_onUnequipAnimations()
	self.wantEquipped = false
	self.equipped = false
	if sm.exists(self.tool) then
		setTpAnimation(self.tpAnimations, "putdown")
		if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
			swapFpAnimation(self.fpAnimations, "equip", "unequip", 0.2)
		end
	end
end

function Sell.onUseAnimation(self)
	if self.tool:isLocal() then
		setFpAnimation(self.fpAnimations, "use", 0.25)
	end
	setTpAnimation(self.tpAnimations, "use", 10.0)

	if self.tool:isLocal() and self.tool:isInFirstPersonView() then
		local effectPos = sm.localPlayer.getFpBonePos("jnt_fertilizer")
		if effectPos then
			local rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), sm.localPlayer.getDirection())

			local fovScale = (sm.camera.getFov() - 45) / 45

			local xOffset45 = sm.localPlayer.getRight() * 0.12
			local yOffset45 = sm.localPlayer.getDirection() * 0.65
			local zOffset45 = sm.localPlayer.getUp() * -0.1
			local offset45 = xOffset45 + yOffset45 + zOffset45

			local xOffset90 = sm.localPlayer.getRight() * 0.375
			local yOffset90 = sm.localPlayer.getDirection() * 0.65
			local zOffset90 = sm.localPlayer.getUp() * -0.3
			local offset90 = xOffset90 + yOffset90 + zOffset90

			local offset = sm.vec3.lerp(offset45, offset90, fovScale)

			sm.effect.playEffect("Itemtool - FPFertilizerUse", effectPos + offset, nil, rot)
		end
	else
		sm.effect.playHostedEffect("Itemtool - FertilizerUse", self.tool:getOwner():getCharacter(), "jnt_fertilizer")
	end
end

function Sell.cl_n_onUseAnimation(self)
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onUseAnimation()
	end
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class SellSvSellParams
---@field shape Shape the shape to be sold
---@field value string value of each item to be sold
---@field quantity number quantity of items to be sold

---@class SellCl
---@field quantity number the quantity (10^x) to be sold on use
---@field unlocked boolean whether the tool is unlocked i.e. tutorial completed

-- #endregion
