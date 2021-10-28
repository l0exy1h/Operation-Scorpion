-- handle's gear/attc selection
-- I call the content panel inside "List" here

local EquipmentSlider = {}
EquipmentSlider.__index = EquipmentSlider

-- defs
local rep          = game.ReplicatedStorage
local gm           = rep:WaitForChild("GlobalModules")
local SlidingFrame = require(gm:WaitForChild("SlidingFrame"))
local dsReader     = require(gm:WaitForChild("CustDSReader"))
local sd           = require(gm:WaitForChild("ShadedTexts"))
local Gear         = rep:WaitForChild("Gear")
local Attachment   = rep:WaitForChild("Attachment")

-- consts
local at = 0.2		-- animation time

function EquipmentSlider.new(_sfr, _bfSelect, _ds, _loadoutIdx)
	local self = {
		sfr      = _sfr,
		list     = nil,
		slider   = SlidingFrame.new(_sfr.Sfr),
		visible  = true,
		bfSelect = _bfSelect,
		ds  = _ds,
		loadoutIdx = _loadoutIdx,
		butConnections = {},
	}
	setmetatable(self, EquipmentSlider)
	self:setVisible(false)
	return self
end

-- generate a list based on arguments
local function genButton(title, imagePath, owned, equipped)
	local but = script.Button:Clone()
	--sd.setText(but.Title, string.gsub(title, "Standard", ""))
	sd.setText(but.Title, title)
	but.Preview.Image = imagePath
	but.Check.Visible = owned
	if equipped then but.Check.ImageColor3 = Color3.fromRGB(0, 213, 255) end
	return but
end
-- TODO: insert image paths for gears/attcs
local function getImage(itemType, itemName)
	return rep[itemType]:FindFirstChild(itemName, true).ImagePath.Value
end

local function inDict(a, dict)
	local rev = {}
	warn(a)
	for _, v in pairs(dict) do
		rev[v] = true
		warn(v)
	end
	if type(a) == "string" then
		return rev[a] == true
	elseif type(a) == "table" then
		for _, v in ipairs(a) do
			if rev[v] == true then
				return true
			end
		end
		return false
	else 
		error(type(a), "is not recognized")
	end
end

-- function EquipmentSlider:genList(mode1, mode2, gearName, attcTypeName)
-- "Gear", {"Primary"}
-- "Attachment", {(custGear obj: M4A1), "Sight"}
function EquipmentSlider:genList(itemType, args)
	self:clearList()
	self.lastItemType = itemType
	self.lastArgs = args
	
	local loadoutIdx = self.loadoutIdx

	if itemType == "Gear" then
		local listFrame = script.List:Clone()
		local listWidth  = -listFrame.UIListLayout.Padding.Offset

		local gearType = args[1]
		for _, gearFolder in ipairs(Gear[gearType]:GetChildren()) do

			local gearName = gearFolder.Name
			local owned    = dsReader.ownedQ(self.ds, "Gear", {gearName})
			local equipped = dsReader.equippedQ(self.ds, loadoutIdx, "Gear", {gearName, gearType})

			local but  = genButton(gearName, getImage("Gear", gearName), owned, equipped)
			but.Parent = listFrame
			but.Name   = gearName

			self.butConnections[#self.butConnections + 1] = but.MouseButton1Click:connect(function()
				self.bfSelect:Invoke("Gear", {gearName, gearType})
			end)

			listWidth = listWidth + listFrame.UIListLayout.Padding.Offset - but.Size.X.Scale * self.sfr.AbsoluteSize.Y
		end
		
		self.bfSelect:Invoke("Gear", {self.ds.loadouts[loadoutIdx][gearType], gearType})
		
		self.slider:loadContentFrame(listFrame, listWidth)
		self.list = listFrame

	elseif itemType == "Attachment" then
		local listFrame = script.List:Clone()
		local listWidth  = -listFrame.UIListLayout.Padding.Offset

		local custGear = args[1]
		local gearName = custGear.name
		local attcType = args[2]
		for _, attc in ipairs(Attachment[attcType]:GetChildren()) do

			local attcName = attc.Name

			-- check if the attc is compatible with this gear
			-- considering the CAA rail case here
			local prereq = require(attc.Reqs).compatible[gearName]
			if prereq == true 
				or (prereq and prereq[1] == "with" and inDict(prereq[2], custGear.attcList)) 
				or (prereq and prereq[1] == "without" and not inDict(prereq[2], custGear.attcList)) then 
--				prereq[1] == "without" and custGear.attcList.Barrel ~= prereq[2]) 

				local owned    = dsReader.ownedQ(self.ds, "Attachment", {gearName, attcName})
				local equipped = dsReader.equippedQ(self.ds, loadoutIdx, "Attachment", {gearName, attcName, attcType})

				local but  = genButton(attcName, getImage("Attachment", attcName), owned, equipped)
				but.Parent = listFrame
				but.Name   = attcName

				listWidth = listWidth + listFrame.UIListLayout.Padding.Offset - but.Size.X.Scale * self.sfr.AbsoluteSize.Y

				self.butConnections[#self.butConnections + 1] = but.MouseButton1Click:connect(function()
					self.bfSelect:Invoke("Attachment", {gearName, attcName, attcType})
				end)
			end
		end
		self.bfSelect:Invoke(gearName, self.ds.loadouts[loadoutIdx].customizations[gearName].attcList[attcType], attcType)

		self.slider:loadContentFrame(listFrame, listWidth)
		self.list = listFrame
	end
end
function EquipmentSlider:clearList()
	if self.list then
		self.list:Destroy()
		for _, connection in ipairs(self.butConnections) do
			connection:disconnect()
		end
		self.butConnections = {}
	end
end
function EquipmentSlider:updateCheckIcon()
	local itemType = self.lastItemType
	local args     = self.lastArgs
	for _, but in ipairs(self.slider.fr) do
		if itemType == "Gear" then
			local gearName = but.Name
			local gearType = args[1]
			local owned    = dsReader.ownedQ(self.ds, itemType, {gearName})
			local equipped = dsReader.equippedQ(self.ds, )
		
		end
	end
end
function EquipmentSlider:setVisible(bool)
	if bool and not self.visible then
		self.sfr:TweenPosition(UDim2.new(0, 0, 1, 0), "Out", "Quad", at, true)
	elseif not bool and self.visible then
		self.sfr:TweenPosition(UDim2.new(0, 0, 1.2, 0), "Out", "Quad", at, true)
	end
	self.visible = bool
end

return EquipmentSlider
