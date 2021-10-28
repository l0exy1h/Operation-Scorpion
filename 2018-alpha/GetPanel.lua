-- (oop) show the requirements to get each class
--

-- TODO: msg system if the player has not enough money?

local GetPanel = {}
GetPanel.__index = GetPanel

-- defs
local ts = game:GetService("TextService")
local rep = game.ReplicatedStorage
local Gear = rep:WaitForChild("Gear")
local Attachment = rep:WaitForChild("Attachment")
local gm = rep:WaitForChild("GlobalModules")
local dsReader  = gm:WaitForChild("CustDSChecker")


-- consts
local testVec2 = Vector2.new(1000, 1000)

local at = 0.2 -- animation time

function GetPanel.new(_gui, _ds, _loadoutIdx, _custTable)
	local self = {
		gui        = _gui,
		visible    = false,
		ds  = _ds,
		loadoutIdx = _loadoutIdx,
		custTable  = _custTable,
		butCon     = nil,
	}
	setmetatable(self, GetPanel)
	self:setVisible(false)
	script.Req:clone().Parent = _gui
	script.Button:clone().Parent = _gui
	script.Price:clone().Parent = _gui
	return self
end

-- need if the plr has owned this weapon
-- plr's stats (kills/ kills using this weapon)
-- requirements (kills/ credits)
-- configure's the buy/claim/equip/equipped button here
function GetPanel:setup(itemType, args)
	if self.butCon then self.butCon:disconnect() end

	local ds, loadoutIdx = self.ds, self.loadoutIdx
	local owned, reqMet, equipped, lockedMsg, unMetMsg
	local itemPrice		-- maybe nil (alpha tester gun)
	local gearName, gearType, attcName, attcType

	if itemType == "Gear" then
		gearName = args[1]
		gearType = args[2]
		owned    = dsReader.ownedQ(ds, "Gear", {gearName})
		equipped = dsReader.equippedQ(ds, loadoutIdx, "Gear", {gearName, gearType})
		reqMet, unMetMsg, lockedMsg = dsReader.reqMetQ(ds, "Gear", {gearName})
		itemPrice = require(Gear:FindFirstChild(gearName, true).Reqs).price
	elseif itemType == "Attachment" then
		gearName = args[1]
		attcName = args[2]
		attcType = args[3]
		owned    = dsReader.ownedQ(ds, "Attachment", {gearName, attcName})
		equipped = dsReader.equippedQ(ds, loadoutIdx, "Attachment", {gearName, attcName, attcType})
		reqMet, unMetMsg, lockedMsg = dsReader.reqMetQ(ds, "Attachment", {gearName, attcName})
		itemPrice = require(Attachment:FindFirstChild(attcName, true).Reqs).price
	end

	local gui = self.gui
	-- ***-exclusive items
	if not owned and not reqMet and lockedMsg then
		-- adjust the position of the lock icon
		sd.setText(gui.Req, lockedMsg)
		gui.Req.Lock.Position = UDim2.new(1, -ts:GetTextSize(lockedMsg, gui.Req.text.TextSize, gui.Req.text.Font, testVec2).X - 40, 0, 0)

		gui.Price.Visible = false

		-- adjust the size of the button
		sd.setText(gui.Button, "LOCKED")
		gui.Button.ImageColor3 = Color3.fromRGB(76, 70, 73)
		gui.Button.Size = UDim2.new(0, ts:GetTextSize("LOCKED", gui.Button.text.TextSize, gui.Button.text.Font, testVec2).X + 44, 0, gui.Button.Size.Y.Offset)

	-- buy!
	elseif not owned and not reqMet and unMetMsg then
		sd.setText(gui.Req, unMetMsg)
		gui.Req.Lock.Position = UDim2.new(1, -ts:GetTextSize(unMetMsg, gui.Req.text.TextSize, gui.Req.text.Font, testVec2).X - 40, 0, 0)

		sd.setText(gui.Price, string.format("Cr. %d", itemPrice))

		sd.setText(gui.button, "Buy")
		gui.Button.Size = UDim2.new(0, ts:GetTextSize("Buy", gui.Button.text.TextSize, gui.Button.text.Font, testVec2).X + 44, 0, gui.Button.Size.Y.Offset)

		self.butCon = gui.Button.MouseButton1Click:connect(function()
			self.butCon:disconnect()
			if ds.credit < itemPrice	then
				self.custTable:setMode("Deactivated")
				-- TODO: open the shop interface here
			else
				ds:buy(itemType, {gearName, attcName})
				if itemType == "Gear" then assert(attcName == nil) end
				self:setUp(itemType, args)	-- refresh the panel
			end
		end)
	-- clarence doesn't like this
	elseif not owned and not reqMet then
		error("Clarence says there should not exist this case since each item can be earned")

	-- claim!
	elseif not owned and reqMet then
		sd.setText(gui.Req, unMetMsg)		-- the unMetMsg here is indeed "metMsg", eg "gun level: 23/23"
		gui.Req.lock.Visible = false
		gui.Price.Visible = false
		sd.setText(gui.Button, "Claim")
		gui.Button.Size = UDim2.new(0, ts:GetTextSize("Claim", gui.Button.text.TextSize, gui.Button.text.Font, testVec2).X + 44, 0, gui.Button.Size.Y.Offset)

		self.butCon = gui.Button.MouseButton1Click:connect(function()
			self.butCon:disconnect()
			ds:claim(itemType, {gearName, attcName})
			if itemType == "Gear" then assert(attcName == nil) end
			self:setUp(itemType, args)	-- refresh the panel
		end)

	-- equip!
	elseif owned and not equipped then
		gui.Req.Visible = false
		gui.Price.Visible = false
		sd.setText(gui.Button, "Equip")
		gui.Button.Size = UDim2.new(0, ts:GetTextSize("Equip", gui.Button.text.TextSize, gui.Button.text.Font, testVec2).X + 44, 0, gui.Button.Size.Y.Offset)

		self.butCon = gui.Button.MouseButton1Click:connect(function()
			self.butCon:disconnect()
			if itemType == "Gear" then
				ds:equip(loadoutIdx, itemType, {gearName, gearType})
			elseif itemType == "Attachment" then
				ds:equip(loadoutIdx, itemType, {gearName, attcName, attcType})
			end
			self:setUp(itemType, args)	-- refresh the panel
		end)

	-- already equipped
	elseif owned and equipped then
		gui.Req.Visible = false
		gui.Price.Visible = false
		sd.setText(gui.Button, "Equipped")
		gui.Button.Size = UDim2.new(0, ts:GetTextSize("Equipped", gui.Button.text.TextSize, gui.Button.text.Font, testVec2).X + 44, 0, gui.Button.Size.Y.Offset)
		gui.Button.ImageColor3 = Color3.fromRGB(76, 70, 73)

	-- shouldn't reach here
	else
		error(string.format("case error: owned = %s, reqMet = %s, equipped = %s", owned, reqMet, equipped))
	end
end

function GetPanel:setVisible(bool)
	if bool and not self.visible then
		self.gui:TweenPosition(UDim2.new(1, 300, 0.6, 0), "Out", "Quad", at, true)
	elseif not bool and self.visible then
		self.gui:TweenPosition(UDim2.new(1, -50, 0.6, 0), "Out", "Quad", at, true)
	end
end

return Get
