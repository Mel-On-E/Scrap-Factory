dofile("$CONTENT_DATA/Scripts/util.lua")

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

---@class Shop
---@field cl client
Shop = class()

function Shop:client_onCreate()
	self.cl = {}
	self.cl.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/shop.layout")
	self.cl.gui:setOnCloseCallback("cl_onGuiClosed")
	self.cl.seatedEquiped = false
	local json = sm.json.open("$CONTENT_DATA/shop.json")
	self.cl.pageNum = math.floor(#json / 32) == 0 and 1 or
		math.floor(#json / 32)
	self.cl.curPage = 1
	self.cl.curItem = 1
	self.cl.quantity = 1
	self.cl.gui:setButtonState("Buy_x1", true)
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
	self.cl.gui:setButtonCallback("research", "openReserch")
	self:changeQuantity("Buy_x1")
	self.cl.itemPages = { {} }
	self.cl.filteredPages = { {} }
	local pages = {}
	for k, v in pairs(json) do
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
	self:client_onRefresh()
end

function Shop:gen_page(num)
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
		for _, v in pairs(v) do
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
		{ price = self.cl.filteredPages[self.cl.curPage][self.cl.curItem].price,
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
	sm.event.sendToGame("sv_e_buyItem", params)
end
