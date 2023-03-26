dofile("$CONTENT_DATA/Scripts/Managers/Interfaces/Interface.lua")

---@type integer number of items each page of the gui can show at max
local ITEMS_PER_PAGE = 32

---The Shop can be used to buy new items for money. Doing research will unlock more items.
---@class Shop : Interface
---@field cl ShopCl
---@diagnostic disable-next-line: param-type-mismatch
Shop = class(Interface)

--------------------
-- #region Server
--------------------

---@param params { quantity: number, item: Item }
---@param player Player
function Shop:sv_buy(params, player)
	if not MoneyManager.sv_trySpendMoney(params.item.price * params.quantity) then return end

	sm.event.sendToGame("sv_giveItem", { player = player, item = params.item.uuid, quantity = params.quantity })

	if params.item.uuid == obj_upgrader_basic then
		sm.event.sendToScriptableObject(g_tutorialManager.scriptableObject, "sv_e_questEvent", "UpgraderBought")
	end
end

-- #endregion

--------------------
-- #region Client
--------------------

function Shop:client_onCreate()
	g_cl_shop = g_cl_shop or self

	Interface.client_onCreate(self, "$CONTENT_DATA/Gui/Layouts/shop.layout")

	self:cl_setup()
	self:cl_setupGui()
end

---Setups the self.cl table
function Shop:cl_setup()
	self.cl = {
		curPage = 1,
		sortHighest = false,
		category = "All",
		sortedItems = {},
		renderedPages = { {} },
		tier = -1,
		item = 1,
		quantity = 1,
		gui = self.cl.gui
	}

	self:cl_setupSortedItems()
end

---Create a list of items sorted by price in `self.cl.sortedItems`
function Shop:cl_setupSortedItems()
	for uuid, item in pairs(g_shop) do
		if not item.special then
			table.insert(self.cl.sortedItems,
				{ category = item.category, price = tonumber(item.price), tier = item.tier, uuid = sm.uuid.new(uuid) })
		end
	end

	table.sort(self.cl.sortedItems, function(a, b)
		return a.price > b.price
	end)
end

function Shop:client_onFixedUpdate()
	if not (self.cl.clearWarning and (self.cl.clearWarning <= sm.game.getCurrentTick())) then return end

	self.cl.clearWarning = nil
	self.cl.gui:setVisible("OutOfMoney", false)
end

function Shop.cl_e_open_gui()
	Shop.gui_setLang(g_cl_shop)
	Shop.gui_render(g_cl_shop)
	Shop.gui_displayPage(g_cl_shop)

	Interface.cl_e_open_gui(g_cl_shop)
end

---@param category string The name of the widget that invokes this func
function Shop:cl_changeCategory(category)
	local category = category:sub(1, -4)
	self.cl.category = category

	self:gui_render()
	self:gui_displayPage()
end

function Shop:cl_changeSort()
	self.cl.sortHighest = not self.cl.sortHighest

	self.cl.gui:setText("SortText", self.cl.sortHighest and language_tag("SortHighest") or language_tag("SortLowest"))

	self:gui_render()
	self:gui_displayPage()
end

---@param optionName string
function Shop:cl_tierChange(optionName)
	if optionName == self.cl.filterByText then
		self.cl.tier = -1

		self:gui_render()
		self:gui_displayPage()

		return
	end

	local tier = tonumber(optionName:sub(#self.cl.tierText + 3))

	---@diagnostic disable-next-line: assign-type-mismatch
	self.cl.tier = tier

	self:gui_render()
	self:gui_displayPage()
end

---@param widgetName string
function Shop:cl_changePage(widgetName)
	if widgetName == "NextPage" then
		self.cl.curPage = math.min(self.cl.curPage + 1, #self.cl.renderedPages)
	elseif widgetName == "LastPage" then
		self.cl.curPage = math.max(self.cl.curPage - 1, 1)
	else
		return
	end

	self:gui_displayPage()
end

---@param widgetName string
function Shop:cl_changeItem(widgetName)
	self.cl.gui:setButtonState("Item_" .. self.cl.item, false)

	---@diagnostic disable-next-line: assign-type-mismatch
	self.cl.item = tonumber(widgetName:sub(6))

	local uuid = self.cl.renderedPages[self.cl.curPage][self.cl.item].uuid

	self.cl.gui:setButtonState(widgetName, true)
	self.cl.gui:setMeshPreview("Preview", uuid)
	self.cl.gui:setText("ItemName", sm.shape.getShapeTitle(uuid))
	self.cl.gui:setText("ItemDesc", sm.shape.getShapeDescription(uuid))
end

function Shop:cl_buy()
	local money = MoneyManager.getMoney()
	local item = self.cl.renderedPages[self.cl.curPage][self.cl.item]
	if money < item.price * self.cl.quantity then
		self.cl.gui:setVisible("OutOfMoney", true)
		self.cl.clearWarning = sm.game.getCurrentTick() + 40 * 2.5

		sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_e_playAudio", "RaftShark")
		return
	end

	sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "cl_e_playEffect", { effect = "Nice Sound", pos = sm.vec3.zero() })

	self.cl.clearWarning = nil
	self.network:sendToServer("sv_buy", { quantity = self.cl.quantity, item = item })
end

---@param widgetName string
function Shop:cl_changeQuantity(widgetName)
	self.cl.gui:setText("Buy_x" .. self.cl.quantity, "#ffffffx" .. self.cl.quantity)
	self.cl.gui:setButtonState("Buy_x" .. self.cl.quantity, false)

	---@diagnostic disable-next-line: assign-type-mismatch
	self.cl.quantity = tonumber(widgetName:sub(6))

	self.cl.gui:setText(widgetName, "#000000x" .. self.cl.quantity)
	self.cl.gui:setButtonState(widgetName, true)
end

function Shop.cl_close()
	Interface.cl_close(g_cl_shop)
end

function Shop.cl_e_isGuiOpen()
	return Interface.cl_e_isGuiOpen(g_cl_shop)
end

-- #endregion

--------------------
-- #region Gui
--------------------

---Setups the gui callbacks
function Shop:cl_setupGui()
	---Quantity
	local quantityButtons = { "Buy_x1", "Buy_x10", "Buy_x100", "Buy_x999" }
	Interface.setupButtons(self.cl.gui, quantityButtons, "cl_changeQuantity")

	---Categories
	local categoryButtons = { "AllTab", "DroppersTab", "UpgradesTab", "FurnacesTab", "GeneratorsTab", "UtilitiesTab",
		"DecorTab" }
	Interface.setupButtons(self.cl.gui, categoryButtons, "cl_changeCategory")

	---Other
	Interface.setupButtons(self.cl.gui, { "NextPage", "LastPage" }, "cl_changePage")
	self.cl.gui:setButtonCallback("SortBtn", "cl_changeSort")
	self.cl.gui:setVisible("OutOfMoney", false)
	self.cl.gui:setButtonCallback("BuyBtn", "cl_buy")

	for i = 1, ITEMS_PER_PAGE do
		self.cl.gui:setButtonCallback("Item_" .. i, "cl_changeItem")
	end

	self:gui_setupTiers()
end

---Setups the tiers DropDown
function Shop:gui_setupTiers()
	self.cl.filterByText = language_tag("FilterBy")
	self.cl.tierText = language_tag("Tier")

	local tiers = { language_tag("FilterBy") }

	--TODO: Remove -1 when tier fix
	for i = 0, ResearchManager.cl_getTierCount() - 1 do
		table.insert(tiers, language_tag("Tier") .. " : " .. tostring(i))
	end

	self.cl.gui:createDropDown("DropDown", "cl_tierChange", tiers)
end

---Setups the language for every element that needs translation
function Shop:gui_setLang()
	local function setGuiTexts(widgets)
		for _, widget in ipairs(widgets) do
			self.cl.gui:setText(widget[1], language_tag(widget[#widget == 1 and 1 or 2]))
		end
	end

	local widgets = {
		{ "title",        "ShopTitle" },
		{ "BuyBtn",       "Buy" },
		{ "AllTab" },
		{ "UpgradesTab" },
		{ "FurnacesTab" },
		{ "DroppersTab" },
		{ "GeneratorsTab" },
		{ "UtilitiesTab" },
		{ "DecorTab" },
		{ "Shop",         "ShopTitle" },
		{ "SortText",     self.cl.sortHighest and "SortHighest" or "SortLowest" },
		{ "OutOfMoney" },
		{ "Description" }
	}

	setGuiTexts(widgets)

	self.cl.gui:setVisible("OutOfMoney", false)
end

---Render all pages based on tiers, sort and category
function Shop:gui_render()
	self.cl.renderedPages = { {} }

	--Clear the blocked tier items and different category items
	local availableItems = {}

	for _, item in pairs(self.cl.sortedItems) do
		local categoryCheck = item.category == self.cl.category or self.cl.category == "All"
		--TODO: remove -1 after we do stuff to fix tiers
		local tierCheck = item.tier <= (ResearchManager.cl_getCurrentTier() - 1)
		local selectTierCheck = item.tier == self.cl.tier or self.cl.tier == -1

		if categoryCheck and tierCheck and selectTierCheck then
			table.insert(availableItems, item)
		end
	end

	--Sort
	if self.cl.sortHighest then
		availableItems = array_reverse(availableItems)
	end

	--Generate pages
	local page = 1
	local i = 1
	for _, item in pairs(availableItems) do
		table.insert(self.cl.renderedPages[page], item)

		i = i + 1
		if i % (ITEMS_PER_PAGE + 1) == 0 then --new page
			page = page + 1
			table.insert(self.cl.renderedPages, {})
		end
	end
end

function Shop:gui_displayPage()
	self:cl_changeItem("Item_1")
	self:cl_changeQuantity("Buy_x1")

	local page = self.cl.renderedPages[self.cl.curPage]

	for i = 1, ITEMS_PER_PAGE do
		if page[i] == nil then
			self.cl.gui:setVisible("Item_" .. tostring(i), false)
			self.cl.gui:setVisible("ItemPrice_" .. tostring(i), false)

			goto continue
		end
		self.cl.gui:setVisible("Item_" .. tostring(i), true)
		self.cl.gui:setVisible("ItemPrice_" .. tostring(i), true)

		self.cl.gui:setIconImage("ItemPic_" .. tostring(i), page[i].uuid)
		self.cl.gui:setText("ItemPrice_" .. tostring(i), format_number({ format = "money", value = page[i].price }))

		::continue::
	end

	self.cl.gui:setText("PageNum", self.cl.curPage .. " / " .. #self.cl.renderedPages)
end

-- #endregion

--------------------
-- #region Types
--------------------

---@class ShopCl
---@field gui GuiInterface The gui instance
---@field curPage number Current page
---@field sortHighest boolean Wheater the gui should sort from highest price or the lowest
---@field category "All" | "Generators" | "Utilities" | "Upgrades" | "Furnaces" | "Decor" The current category
---@field sortedItems Item[] List containing all items sorted by price ***DONT MODIFY***
---@field renderedPages Page[] The rendered pages
---@field tier number What tier to filter to -1 == No filter
---@field tierText string Used for the dropdown cuz lang doesnt change ***DONT MODIFY***
---@field filterByText string Used for dropdown cuz lang doesnt change ***DONT MODIFY***
---@field item number The item selected
---@field clearWarning number? The tick on which the OutOfMoney text should be hidden
---@field quantity number The amount of items you buy at once

---@class ShopDb
---@field tier integer
---@field price string
---@field category string
---@field special boolean?
---@field prestige boolean?

---@class Item
---@field tier integer
---@field price integer
---@field category "All" | "Generators" | "Utilities" | "Upgrades" | "Furnaces" | "Decor"
---@field uuid Uuid

---Has also a highestValueItem wich i dont know how to use luadoc syntax to document it
---@alias Page Item[]

-- #endregion
