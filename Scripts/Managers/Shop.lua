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


---@class Shop : ScriptableObjectClass
---@field cl client

Shop = class()

function Shop:client_onCreate()
	if not g_cl_shop then
		g_cl_shop = self
	end

	self.cl = {}
	self.cl.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/shop.layout")

	self.cl.pageNum = math.floor(#g_shop / 32) == 0 and 1 or
		math.floor(#g_shop / 32)
	self.cl.curPage = 1
	self.cl.curItem = 1
	self.cl.quantity = 1
	self.cl.gui:setButtonState("Buy_x1", true)
	self.cl.gui:setText("PageNum", tostring(self.cl.curPage) .. "/" .. tostring(self.cl.pageNum))
	self.cl.gui:setButtonCallback("BuyBtn", "cl_buyItem")
	self.cl.gui:setVisible("OutOfMoney", false)
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
	self.cl.gui:setButtonCallback("research", "cl_openResearch")

	self.cl.gui:setOnCloseCallback("cl_onGuiClosed")

	self:changeQuantity("Buy_x1")
	self.cl.itemPages = { {} }
	self.cl.filteredPages = { {} }
	local pages = {}
	for k, v in pairs(g_shop) do
		table.insert(pages, { uuid = k, price = v.price, category = v.category })
	end
	table.sort(pages, function(a, b)
		return a.price < b.price
	end)
	local page = 1;
	for i, v in pairs(pages) do
		table.insert(self.cl.itemPages[page], v)
		if i % 32 == 0 then
			page = page + 1
		end
	end
	for i = 1, 32 do
		self.cl.gui:setButtonCallback("Item_" .. i, "changeItem")
	end
	self:gui_filter("All")
	self:gen_page(self.cl.curPage)
	self:changeItem("Item_" .. self.cl.curItem)
end

function Shop:gen_page(num)
	print("Page Gen")
	local pageLen = #self.cl.filteredPages[num]
	for i = 1, 32 do
		self.cl.gui:setVisible("Item_" .. tostring(i), true)
		self.cl.gui:setVisible("ItemPrice_" .. tostring(i), true)
	end
	for i, v in pairs(self.cl.filteredPages[num]) do
		self.cl.gui:setIconImage("ItemPic_" .. tostring(i), sm.uuid.new(v.uuid))
		self.cl.gui:setText("ItemPrice_" .. tostring(i), format_money({money = v.price}))
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
	self.cl.gui:setButtonState("Item_" .. self.cl.curItem, false)
	---@diagnostic disable-next-line: assign-type-mismatch
	self.cl.curItem = tonumber(string.reverse(string.sub(string.reverse(itemName), 1, #itemName - 5)))
	local uuid = sm.uuid.new(self.cl.filteredPages[self.cl.curPage][self.cl.curItem].uuid)
	self.cl.gui:setButtonState(itemName, true)
	self.cl.gui:setMeshPreview("Preview", uuid)
	self.cl.gui:setText("ItemName", sm.shape.getShapeTitle(uuid))
	self.cl.gui:setText("ItemDesc", sm.shape.getShapeDescription(uuid))
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
	self:gui_filter(category)
	self.cl.curPage = 1
	self:changeItem("Item_1")
	self:gen_page(self.cl.curPage)
end

function Shop:sv_buyItem(params, player)
	params.player = player
	local price = tonumber(params.price) * params.quantity

	if MoneyManager.sv_spendMoney(price) then
		sm.event.sendToGame("sv_giveItem", { player = params.player, item = sm.uuid.new(params.uuid), quantity = params.quantity })
	else
		self.network:sendToClient(player, "cl_notEnoughMoney")
	end
end

function Shop:cl_notEnoughMoney()
	if self.cl.gui then
		self.cl.gui:setVisible("OutOfMoney", true)
		self.cl.clearWarning = sm.game.getCurrentTick() + 40*2.5
		--sm.audio.play("RaftShark") TODO play sound effect. Probably also on success, etc.
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
	g_cl_shop.cl.gui:setText("research", language_tag("Research"))
	g_cl_shop.cl.gui:setText("prestige", language_tag("Prestige"))
	g_cl_shop.cl.gui:setText("BuyBtn", language_tag("Buy"))
	g_cl_shop.cl.gui:setText("OutOfMoney", language_tag("OutOfMoney"))
	g_cl_shop.cl.gui:setText("AllTab", language_tag("AllTab"))
	g_cl_shop.cl.gui:setText("UpgradesTab", language_tag("UpgradesTab"))
	g_cl_shop.cl.gui:setText("FurnacesTab", language_tag("FurnacesTab"))
	g_cl_shop.cl.gui:setText("DroppersTab", language_tag("DroppersTab"))
	g_cl_shop.cl.gui:setText("GeneratorsTab", language_tag("GeneratorsTab"))
	g_cl_shop.cl.gui:setText("UtilitiesTab", language_tag("UtilitiesTab"))
	g_cl_shop.cl.gui:setText("DecorTab", language_tag("DecorTab"))

	g_cl_shop.cl.gui:open()
end

function Shop.cl_e_isGuiOpen()
	return g_cl_shop and g_cl_shop.cl.gui:isActive() or false
end

function Shop:cl_openResearch()
	self.cl.gui:close()
	self.research = true
end

function Shop:cl_onGuiClosed()
	if self.research then
		Research.cl_e_open_gui()
	end

	self.research = false
end
