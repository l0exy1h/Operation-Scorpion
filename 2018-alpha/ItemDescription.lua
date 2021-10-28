local ItemDescription = {}
ItemDescription.__index = ItemDescription

-- defs
local rep = game.ReplicatedStorage
local gm  = rep:WaitForChlid("GlobalModules")
local sd  = require(rep:WaitForChild("ShadedTexts"))

-- consts
local at = 0.2 -- animation time

function ItemDescription.new(_gui)
	local self = {
		gui = _gui,
		visible = false,
	}
	setmetatable(self, ItemDescription)
	self:setVisible(false)
	script.Desc:clone().Parent = _gui
	script.Title:clone().Parent= _gui
	return self
end

function ItemDescription:setDescription(itemType, itemName)
	local desc = "No Description Available -- Clarence"
	local descFile = rep[itemType]:FindFirstChild(itemName, true):FindFirstChild("Desc")
	if descFile then
		desc = require(descFile)
	end
	sd.setText(self.gui.Title, itemName)
	sd.setText(self.gui.desc,  desc)
end

function ItemDescription:setVisible(bool)
	if bool and not self.visible then
		self.gui:TweenPosition(UDim2.new(0, -400, 0.15, 0), "Out", "Quad", at, true)
	elseif not bool and self.visible then
		self.gui:TweenPosition(UDim2.new(0, 50, 0.15, 0), "Out", "Quad", at, true)
	end
	self.visible = bool
end

return ItemDescription
