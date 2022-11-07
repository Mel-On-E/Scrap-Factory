dofile("$CONTENT_DATA/Scripts/Managers/Interfaces/Interface.lua")


---@class page
---@field uuid string
---@field price number
---@field category string
---@field tier number

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
---wheater it should sort from highest value item or lowest value item
---@field sortHighest boolean
---current category
---@field category string
---Selected tier filter
---@field tier number


---@class Shop : Interface
---@field cl client
---@diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
Shop = class(Interface)

function Shop:client_onCreate()
	if not g_cl_shop then
		g_cl_shop = self
	end
	local params = {}
	params.layout = "$CONTENT_DATA/Gui/Layouts/shop.layout"
	Interface.cient_onCreate(self, params)

	self.cl.sortHighest = true

	self.cl.pageNum = math.floor(#g_shop / 32) == 0 and 1 or
		math.floor(#g_shop / 32)
	self.cl.curPage = 1
	self.cl.curItem = 1
	self.cl.quantity = 1
	self.cl.category = "All"
	self.cl.tier = -1
	self.cl.gui:setButtonState("Buy_x1", true)
	self.cl.gui:setVisible("OutOfMoney", false)
	self.cl.gui:setText("PageNum", tostring(self.cl.curPage) .. "/" .. tostring(self.cl.pageNum))

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
	self.cl.gui:setButtonCallback("SortBtn", "changeSort")
	local tiers = { language_tag("FilterBy") }
	for i = 0, ResearchManager.cl_getTierCount() do
		table.insert(tiers, language_tag("Tier") .. " : " .. tostring(i))
	end

	self.cl.gui:createDropDown("DropDown", "tierChange", tiers)
	for i = 1, 32 do
		self.cl.gui:setButtonCallback("Item_" .. i, "changeItem")
	end
end

function Shop:gen_page(num)
	local pageLen = #self.cl.filteredPages[num]
	for i = 1, 32 do
		self.cl.gui:setVisible("Item_" .. tostring(i), true)
		self.cl.gui:setVisible("ItemPrice_" .. tostring(i), true)
	end
	for i, v in pairs(self.cl.filteredPages[num]) do
		self.cl.gui:setIconImage("ItemPic_" .. tostring(i), sm.uuid.new(v.uuid))
		self.cl.gui:setText("ItemPrice_" .. tostring(i), format_number({ format = "money", value = v.price }))
	end
	if pageLen == 32 then return end
	for i = pageLen + 1, 32 do
		self.cl.gui:setVisible("Item_" .. tostring(i), false)
		self.cl.gui:setVisible("ItemPrice_" .. tostring(i), false)
	end

end

function Shop:changeSort()
	self.cl.sortHighest = not self.cl.sortHighest
	self.cl.gui:setText("SortText", self.cl.sortHighest and language_tag("SortHighest") or language_tag("SortLowest"))

	local tier = ResearchManager.cl_getCurrentTier()
	local pages = {}
	self.cl.itemPages = { {} }
	for k, v in pairs(g_shop) do
		if v.tier < tier and not v.special and not v.prestige then
			table.insert(pages, { uuid = k, price = v.price, category = v.category, tier = v.tier })
		end
	end
	table.sort(pages, function(a, b)
		if self.cl.sortHighest then
			return a.price < b.price
		end
		return a.price > b.price
	end)
	local page = 1;
	for i, v in pairs(pages) do
		table.insert(self.cl.itemPages[page], v)
		if i % 32 == 0 then
			page = page + 1
		end
	end

	self:gui_filter(self.cl.category, self.cl.tier)
	self:gen_page(self.cl.curPage)
	self:changeItem("Item_1")
end

---@param optionName string
function Shop:tierChange(optionName)
	if optionName == language_tag("FilterBy") then
		self.cl.tier = -1
		self:gui_filter(self.cl.category, self.cl.tier)
		self:gen_page(self.cl.curPage)
		self:changeItem("Item_1")
		return
	end
	---@type number
	local tier = tonumber(optionName.sub(optionName, #(language_tag("Tier") .. " : "), #optionName))
	self.cl.tier = tier
	self:gui_filter(self.cl.category, self.cl.tier)
	self:gen_page(self.cl.curPage)
	self:changeItem("Item_1")
end

---@param category string
---@param tier number
function Shop:gui_filter(category, tier)
	self.cl.filteredPages = { {} }
	local page = 1
	if category == "All" then
		for i, v in pairs(self.cl.itemPages) do
			for _, v in pairs(v) do
				if (tier == -1 or v.tier == tier) and v.tier < ResearchManager.cl_getCurrentTier() then
					table.insert(self.cl.filteredPages[page], v)
				end
			end
			if i % 32 then
				page = page + 1
			end
		end
		return
	end

	for i, v in pairs(self.cl.itemPages) do
		for _, v in pairs(v) do

			if ((v.category == category) and (tier == -1 or v.tier == tier)) and v.tier < ResearchManager.cl_getCurrentTier() then
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
	if #self.cl.filteredPages[self.cl.curPage] > 0 then

		self.cl.gui:setButtonState("Item_" .. self.cl.curItem, false)
		---@diagnostic disable-next-line: assign-type-mismatch
		self.cl.curItem = tonumber(string.reverse(string.sub(string.reverse(itemName), 1, #itemName - 5)))
		local uuid = sm.uuid.new(self.cl.filteredPages[self.cl.curPage][self.cl.curItem].uuid)
		self.cl.gui:setButtonState(itemName, true)
		self.cl.gui:setMeshPreview("Preview", uuid)
		self.cl.gui:setText("ItemName", sm.shape.getShapeTitle(uuid))
		self.cl.gui:setText("ItemDesc", sm.shape.getShapeDescription(uuid))
	end
end

function Shop:changePage(wigetName)
	if wigetName == "NextPage" then
		if self.cl.curPage == self.cl.pageNum then
			return
		end
		self.cl.curPage = self.cl.curPage + 1
	elseif wigetName == "LastPage" then
		if self.cl.curPage == 1 then
			return
		end
		self.cl.curPage = self.cl.curPage - 1
	end
	self.cl.curItem = 1
	self:gen_page(self.cl.curPage)
	self:changeItem("Item_1")
end

---@param wigetName string
function Shop:changeQuantity(wigetName)
	sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_e_playAudio", "Button on")

	self.cl.gui:setButtonState("Buy_x" .. tostring(self.cl.quantity), false)
	self.cl.gui:setText("Buy_x" .. tostring(self.cl.quantity), "#ffffffx" .. self.cl.quantity)
	---@diagnostic disable-next-line: assign-type-mismatch
	self.cl.quantity = tonumber(string.reverse(string.sub(string.reverse(wigetName), 1, #wigetName - 5)))
	self.cl.gui:setButtonState(wigetName, true)
	self.cl.gui:setText(wigetName, "#4f4f4fx" .. self.cl.quantity)
end

function Shop:cl_buyItem()
	self.network:sendToServer("sv_buyItem",
		{ price = tostring(self.cl.filteredPages[self.cl.curPage][self.cl.curItem].price),
			uuid = self.cl.filteredPages[self.cl.curPage][self.cl.curItem].uuid, quantity = self.cl.quantity })
end

function Shop:changeCategory(categoryName)
	local category = string.sub(categoryName, 1, -4)
	self:gui_filter(category, self.cl.tier)
	self.cl.category = category

	self.cl.curPage = 1
	self:changeItem("Item_1")
	self:gen_page(self.cl.curPage)
end

function Shop:sv_buyItem(params, player)
	params.player = player
	local price = tonumber(params.price) * params.quantity

	if MoneyManager.sv_spendMoney(price) then
		sm.event.sendToGame("sv_giveItem",
			{ player = params.player, item = sm.uuid.new(params.uuid), quantity = params.quantity })
		if sm.uuid.new(params.uuid) == obj_upgrader_basic then
			sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "UpgraderBought")
		end
		self.network:sendToClient(player, "cl_moneyCheck", true)
	else
		self.network:sendToClient(player, "cl_moneyCheck", false)
	end
end

function Shop:cl_moneyCheck(success)
	if success then
		sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_e_playEffect", { effect = "Nice Sound", pos = sm.vec3.zero() })
		self.cl.clearWarning = sm.game.getCurrentTick()
	else
		if self.cl.gui then
			self.cl.gui:setVisible("OutOfMoney", true)
			self.cl.clearWarning = sm.game.getCurrentTick() + 40 * 2.5
			sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_e_playAudio", "RaftShark")
		end
	end
end

function Shop:client_onFixedUpdate()
	if self.cl.clearWarning and self.cl.clearWarning <= sm.game.getCurrentTick() then
		self.cl.clearWarning = nil
		if self.cl.gui then
			self.cl.gui:setVisible("OutOfMoney", false)
		end
	end
end

function Shop.cl_e_open_gui()
	g_cl_shop.cl.gui:setVisible("OutOfMoney", false)
	g_cl_shop.cl.gui:setText("title", language_tag("ShopTitle"))
	g_cl_shop.cl.gui:setText("BuyBtn", language_tag("Buy"))
	g_cl_shop.cl.gui:setText("OutOfMoney", language_tag("OutOfMoney"))
	g_cl_shop.cl.gui:setText("AllTab", language_tag("AllTab"))
	g_cl_shop.cl.gui:setText("UpgradesTab", language_tag("UpgradesTab"))
	g_cl_shop.cl.gui:setText("FurnacesTab", language_tag("FurnacesTab"))
	g_cl_shop.cl.gui:setText("DroppersTab", language_tag("DroppersTab"))
	g_cl_shop.cl.gui:setText("GeneratorsTab", language_tag("GeneratorsTab"))
	g_cl_shop.cl.gui:setText("UtilitiesTab", language_tag("UtilitiesTab"))
	g_cl_shop.cl.gui:setText("DecorTab", language_tag("DecorTab"))
	g_cl_shop.cl.gui:setText("DecorTab", language_tag("DecorTab"))
	g_cl_shop.cl.gui:setText("SortText",
		g_cl_shop.cl.sortHighest and language_tag("SortHighest") or language_tag("SortLowest"))

	g_cl_shop.cl.itemPages = { {} }
	g_cl_shop.cl.filteredPages = { {} }

	local tier = ResearchManager.cl_getCurrentTier()
	local pages = {}
	for k, v in pairs(g_shop) do
		if v.tier < tier and not v.special and not v.prestige then
			table.insert(pages, { uuid = k, price = v.price, category = v.category, tier = v.tier })
		end
	end
	table.sort(pages, function(a, b)
		if g_cl_shop.cl.sortHighest then
			return a.price < b.price
		end
		return a.price > b.price
	end)
	local page = 1;
	for i, v in pairs(pages) do
		table.insert(g_cl_shop.cl.itemPages[page], v)
		if i % 32 == 0 then
			page = page + 1
		end
	end

	g_cl_shop:gui_filter(g_cl_shop.cl.category, g_cl_shop.cl.tier)
	g_cl_shop:gen_page(g_cl_shop.cl.curPage)
	g_cl_shop:changeItem("Item_" .. g_cl_shop.cl.curItem)



	Interface.cl_e_open_gui(g_cl_shop)
end

function Shop.cl_e_isGuiOpen()
	return Interface.cl_e_isGuiOpen(g_cl_shop)
end

function Shop.cl_close()
	Interface.cl_close(g_cl_shop)
end

--types
---@class ShopDb
---@field tier integer
---@field price string
---@field category string
---@field special boolean?
---@field prestige boolean?
