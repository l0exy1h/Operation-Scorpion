-- sliding frame: implemented using oop (metatables)
-- logic: sfr: the scrolling frame object provided by roblox
--					outsideW: the width of the sfr (in the viewport)
--				fr:  the content inside
--					insideW: the width of the fr
---------------------------------------------
local slidingFrame   = {}
slidingFrame.__index = slidingFrame

-- defs
local lp    = game.Players.LocalPlayer
local rs    = game:GetService("RunService").RenderStepped
local lpGUI = lp:WaitForChild("PlayerGui")
local rep   = game.ReplicatedStorage
local gm    = rep:WaitForChild("GlobalModules")
local ga    = require(gm:WaitForChild("GeneralAnimation"))
local uis   = game:GetService("UserInputService")
local newVec2 = Vector2.new
local mouse = lp:GetMouse()

-- consts
local slideSp  = 10		-- the additive velocity per slide
local friction = .88	-- xv will decline over time by multiplying itself with friction

-- const functions
-- detect if mouse is inside a gui
local function inside(gui, mx, my)
	local x1, x2 = gui.AbsolutePosition.X, gui.AbsolutePosition.X + gui.AbsoluteSize.X
	local y1, y2 = gui.AbsolutePosition.Y, gui.AbsolutePosition.Y + gui.AbsoluteSize.Y
	return x1 <= mx and mx <= x2 and y1 <= my and my <= y2
end

function slidingFrame:isRunning()
	return self.sfr and self.sfr.Parent
end

-- destructor
function slidingFrame:destroy()
	for _, connection in ipairs(self.connections) do
		connection:disconnect()
	end
	self = nil
end

-- constructor: initialize the entire slideing frame
function slidingFrame.new(sfr)
	warn("new sliding frame obj, sfr =", sfr:GetFullName())

	local self = {}
	setmetatable(self, slidingFrame)

	self.sfr = sfr
	self.outsideW  = sfr.AbsoluteWindowSize.X

	self.hasContentFrame = false	-- the slideing frame will only run when this is true
	self.fr = nil
	self.insideW   = self.outsideW * sfr.CanvasSize.X.Scale + sfr.CanvasSize.X.Offset

	self.xv = 0
	self.connections = {}

	-- set up mouse wheel slideing, only working after a content frame is loaded
	self.connections[#self.connections+1] = uis.InputChanged:connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel
			and inside(sfr, input.Position.X, input.Position.X) then
			self.xv = self.xv - input.Position.Z * slideSp
			--sfr.Parent.Parent.Rotation = sfr.Parent.Parent.Rotation + input.Position.Z * 5
		end
	end)

	return self
end

-- dynamic height for different content frames, fuck this
function slidingFrame:getFrameW()
	local ret = 0
	for i, gui in ipairs(self.fr:GetDescendants()) do
		if gui:IsA("GuiObject") and gui.Visible == true then
			local x = gui.AbsolutePosition.X + gui.AbsoluteSize.X - self.sfr.AbsolutePosition.X
			if x > ret then ret = x end
		end
	end
	return ret
end

function slidingFrame:getMaxW()
	local ret = self.frameActualWidth + 50
	if ret > self.insideW then
		ret = self.insideW
	end
	if ret < self.outsideW then
		ret = self.outsideW
	end
	return ret
end

-- or try to find a way to make it centeree
-- load the content frame to make it running
function slidingFrame:loadContentFrame(fr)
	self.hasContentFrame    = false
	self.fr:Destroy()

	self.fr                 = fr
	self.fr.Visible         = false
	self.fr.Parent          = self.sfr
	self.frameActualWidth   = self:getFrameW()

	-- center the gui (assume the viewport is not resizable)
	local pos         = self.sfr.Position
	self.sfr.Position = UDim2.new(0, (mouse.ViewSizeX - self.frameActualWidth) / 2, pos.Y.Scale, pos.Y.Offset)

	self.maxW               = self:getMaxW()
	self.xv                 = 0
	self.sfr.CanvasPosition = newVec2(0, 0)
	self.hasContentFrame    = true
	self.fr.Visible         = true

	-- main loop, only working after a content frame is loaded
	spawn(function()
		while self.hasContentFrame do
			rs:wait()
			-- reduce slideing speed over time
			self.xv = self.xv * friction

			-- shift canvas position
			local nextPos      = sfr.CanvasPosition + newVec2(0, self.xv)
			local validXRange  = self.maxW - self.outsideW
			sfr.CanvasPosition = nextPos.X <= validXRange and nextPos or newVec2(0, validXRange)
		end
	end)
end

return slidingFrame
