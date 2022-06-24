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
---@class Shop : ToolClass
Shop = class()

function Shop:client_onCreate()
	self.cl = {}
	if self.tool:isLocal() then
		self.cl.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/shop.layout")
		self.cl.gui:setOnCloseCallback("cl_onGuiClosed")
		self.cl.seatedEquiped = false
		local json = sm.json.open("$CONTENT_DATA/shop.json")
		self.cl.pages = math.floor(#json / 32) == 0 and 1 or
			math.floor(#json / 32)
		self.cl.page = 1
		self.cl.item = 1
		self.cl.quantity = 1
		self.cl.gui:setText("PageNum", tostring(self.cl.page) .. "/" .. tostring(self.cl.pages))
		self.cl.gui:setButtonCallback("BuyBtn", "cl_buyItem")
		self.cl.gui:setButtonCallback("Buy_x1", "changeQuantity")
		self.cl.gui:setButtonCallback("Buy_x10", "changeQuantity")
		self.cl.gui:setButtonCallback("Buy_x100", "changeQuantity")
		self.cl.gui:setButtonCallback("Buy_x999", "changeQuantity")
		self.cl.gui:setButtonCallback("AllTab", "changeCategory")
		self.cl.gui:setButtonCallback("DroppersTab", "changeCategory")
		self.cl.gui:setButtonCallback("UpgradesTab", "changeCategory")
		self.cl.gui:setButtonCallback("FurnacesTab", "changeCategory")
		self.cl.gui:setButtonCallback("GeneratorsTab", "changeCategory")
		self.cl.gui:setButtonCallback("UtilitiesTab", "changeCategory")
		self.cl.gui:setButtonCallback("DecorTab", "changeCategory")
		self.cl.gui:setButtonCallback("NextPage", "changePage")
		self.cl.gui:setButtonCallback("LastPage", "changePage")
		self.cl.itemPages = { {} }
		self.cl.filteredPages = { {} }
		local page = 1
		local i = 1
		for k, v in pairs(json) do
			table.insert(self.cl.itemPages[page], { uuid = k, price = v.price, category = v.category })
			if i % 32 == 0 then
				page = page + 1
			end
			i = i + 1
		end
		for i, _ in pairs(self.cl.itemPages) do
			table.sort(self.cl.itemPages[i], function(a, b)
				if a.price == b.price then
					return true
				end
				return a.price > b.price
			end)
		end
		for i = 1, 32 do
			self.cl.gui:setButtonCallback("Item_" .. i, "changeItem")
		end
		self:gui_filter("All")
		self:gen_page(self.cl.page)
		self:changeItem("Item_" .. self.cl.item)
	end

	self:client_onRefresh()
end

function Shop:gen_page(num)
	---@type GuiInterface
	self.cl.gui = self.cl.gui
	local pageLen = #self.cl.filteredPages[num]
	for i = 1, 32 do
		self.cl.gui:setVisible("Item_" .. tostring(i), true)
		self.cl.gui:setVisible("ItemPrice_" .. tostring(i), true)
	end
	for i, v in pairs(self.cl.filteredPages[num]) do
		self.cl.gui:setIconImage("ItemPic_" .. tostring(i), sm.uuid.new(v.uuid))
		self.cl.gui:setText("ItemPrice_" .. tostring(i), format_money(v.price))
	end
	if pageLen == 32 then return end
	for i = pageLen + 1, 32 do
		self.cl.gui:setVisible("Item_" .. tostring(i), false)
		self.cl.gui:setVisible("ItemPrice_" .. tostring(i), false)
	end

end

---@param category string
function Shop:gui_filter(category)
	self.cl.filteredPages = { {} }
	if category == "All" then
		self.cl.filteredPages = self.cl.itemPages
		return
	end
	local page = 1
	for i, v in pairs(self.cl.itemPages) do
		for i, v in pairs(v) do
			if v.category == category then
				table.insert(self.cl.filteredPages[page], v)
			end
		end
		if i % 32 then
			page = page + 1
		end
	end
end

---@param itemName string
function Shop:changeItem(itemName)
	local uuid = sm.uuid.new(self.cl.filteredPages[self.cl.page][self.cl.item].uuid)
	---@type GuiInterface
	self.cl.gui = self.cl.gui
	self.cl.gui:setButtonState("Item_" .. self.cl.item, false)
	self.cl.item = tonumber(string.reverse(string.sub(string.reverse(itemName), 1, #itemName - 5)))
	self.cl.gui:setButtonState(itemName, true)
	self.cl.gui:setMeshPreview("Preview", uuid)
	self.cl.gui:setText("ItemName", sm.shape.getShapeTitle(uuid))
	self.cl.gui:setText("ItemDesc", sm.shape.getShapeDescription(uuid))
end

function Shop:changePage(wigetName)
	if wigetName == "NextPage" then
		if self.cl.page == self.cl.pages then
			return
		end
		self.cl.page = self.cl.page + 1
	elseif wigetName == "LastPage" then
		if self.cl.page == 1 then
			return
		end
		self.cl.page = self.cl.page - 1
	end
	self.cl.item = 1
	self:gen_page(self.cl.page)
	self:changeItem("Item_" .. self.cl.item)
end

---@param wigetName string
function Shop:changeQuantity(wigetName)
	self.cl.gui:setButtonState("Buy_x" .. tostring(self.cl.quantity), false)
	self.cl.gui:setText("Buy_x" .. tostring(self.cl.quantity), "#ffffffx" .. self.cl.quantity)
	self.cl.quantity = tonumber(string.reverse(string.sub(string.reverse(wigetName), 1, #wigetName - 5)))
	self.cl.gui:setButtonState(wigetName, true)
	self.cl.gui:setText(wigetName, "#4f4f4fx" .. self.cl.quantity)
end

function Shop:cl_buyItem()
	self.network:sendToServer("sv_buyItem",
		{ price = self.cl.filteredPages[self.cl.page][self.cl.item].price,
			uuid = self.cl.filteredPages[self.cl.page][self.cl.item].uuid, quantity = self.cl.quantity })
end

function Shop:changeCategory(categoryName)
	local category = string.sub(categoryName, 1, -4)
	self:gui_filter(category)
	self.cl.page = 1
	self.cl.item = 1
	self:gen_page(self.cl.page)
	self:changeItem("Item_" .. self.cl.item)
end

function Shop:sv_buyItem(params, player)
	params.player = player
	sm.event.sendToGame("sv_e_buyItem", params)
end

function Shop.client_onRefresh(self)
	self:cl_loadAnimations()
end

function Shop.client_onUpdate(self, dt)
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

function Shop.client_onEquip(self)
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
		self.cl.gui:open()
	end

	self:cl_loadAnimations()
	setTpAnimation(self.tpAnimations, "pickup", 0.0001)

	if self.tool:isLocal() then
		swapFpAnimation(self.fpAnimations, "unequip", "equip", 0.2)
	end
end

function Shop.client_equipWhileSeated(self)
	if not self.cl.seatedEquiped then
		self.cl.gui:open()
		self.cl.seatedEquiped = true
	end
end

function Shop.client_onUnequip(self)
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

function Shop.cl_loadAnimations(self)
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

function Shop.cl_onGuiClosed(self)
	sm.tool.forceTool(nil)
	self.cl.seatedEquiped = false
end
