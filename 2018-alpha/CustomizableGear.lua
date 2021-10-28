-- oop: CustomizableGear: a gear with 3d model and guis, for weapon customization
-- rotatble
-- auto-rotatble
-- support adding attc's
-- position tweening

local CustomizableGear = {}
CustomizableGear.__index = CustomizableGear

-- defs
local ts  = game.TextService
local testVec2 = Vector2.new(1000, 1000)
local rep = game.ReplicatedStorage
local gm  = rep:WaitForChild("GlobalModules")
local sd  = require(gm:WaitForChild("ShadedTexts"))
local rs  = game:GetService("RunService").RenderStepped
local cam = workspace.CurrentCamera
local WeaponAssembly = require(script:WaitForChild("WeaponAssembly"))
local lp = game.Players.LocalPlayer
local mouse = lp:GetMouse()

local newUDim2 = UDim2.new

function CustomizableGear.new(_gearFolder, _attcList, cf, modelContainer, attcPartsGuiHolder, _bfSelectAttcPart)
	if cf:IsA("BasePart") then cf = cf.CFrame end

	local self = {
		gearFolder       = _gearFolder
		name             = _gearFolder.Name
		attcList         = _attcList,
		model            = WeaponAssembly.assemble(_gearFolder, _attcList),
		baseStats        = require(_gearFolder.BaseStats),
		stats            = require(_gearFolder.BaseStats),			-- will be assigned with a deep copy by the weapon module
		attcPartsShown   = false,
		guiContainer     = script.GuiContainer:clone(),		-- the container for this gun's gui
		slider           = _slider,
		cam              = _cam,
		bfSelectAttcType = _bfSelectAttcPart,
	}
	self.guiContainer.Parent = attcPartsGuiHolder
	self.guiContainer.Name   = _gearFolder.Name

	-- anchor and non collidable
	local model = self.model
	for _, pt in ipairs(model:GetDescendants()) do
		if pt:IsA("BasePart") then
			pt.Anchored      = true
			pt.CanCollide    = false
		end
	end
	model.PrimaryPart = model.Main.Center
	model.Parent      = modelContainer
	model.Name        = _gearFolder.Name

	setmetatable(self, CustomizableGear)

	-- initialize attc part gui
	for _, attcPart in ipairs(_gearFolder.Tool.AttachmentParts:GetChildren()) do
		local attcPartGui = script.AttcPartGui:Clone()
		attcPartGui.Visible = false
		attcPartGui.Name = attcPart.Name
		sd.setText(attcPartGui.Title, attcPart.Name)

		-- adjust the length of the rounded thingy
		local text = attcPartGui.Title.text
		local tsx = ts:GetTextSize(attcPart.Name, text.TextSize, text.Font, testVec2).X
		local guiWidth = 2 * 15 + tsx
		attcPartGui.Title.Size = UDim2.new(0, guiWidth, 0, attcPartGui.Title.Size.Y.Offset)
		attcPartGui.Title.Position = UDim2.new(0, -(guiWidth/2 - attcPartGui.Size.X.Offset/2),
			0, attcPartGui.Title.Position.Y.Offset)

		attcPartGui.Parent = self.guiContainer

		attcPartGui.MouseEnter:connect(function()
			if attcPartGui.Title.Visible == false then
				attcPartGui.Title.Visible = true
				attcPartGui.Arrow.Visible = true
			end
		end)
		attcPartGui.MouseMoved:connect(function()
			if attcPartGui.Title.Visible == false then
				attcPartGui.Title.Visible = true
				attcPartGui.Arrow.Visible = true
			end
		end)
		attcPartGui.MouseLeave:connect(function()
			if attcPartGui.Title.Visible == true then
				attcPartGui.Title.Visible = false
				attcPartGui.Arrow.Visible = false
			end
		end)
		spawn(function()
			local function inside(but, mx, my)		-- detect if mouse is in a button
				local x1, x2 = but.AbsolutePosition.X, but.AbsolutePosition.X + but.AbsoluteSize.X
				local y1, y2 = but.AbsolutePosition.Y, but.AbsolutePosition.Y + but.AbsoluteSize.Y
				return x1 <= mx and mx <= x2 and y1 <= my and my <= y2
			end
			while wait(1) do
				if not inside(attcPartGui, mouse.X, mouse.Y) and attcPartGui.Title.Visible == true then
					attcPartGui.Title.Visible = false
					attcPartGui.Arrow.Visible = false
				end
			end
		end)
		attcPartGui.MouseButton1Click:connect(function()
			_bfSelectAttcPart:Invoke(self.name, attcPart.Name)
		end)
	end

	return self
end

function CustomizableGear:moveTo(cf)
	if cf:IsA("BasePart") then cf = cf.CFrame end
	-- TODO: tweening here
	self.model:SetPrimaryPartCFrame(cf)
end

-- TODO
function CustomizableGear:setRotable(bool)
	-- body
end

function CustomizableGear:setAutoRotate(bool)
	-- body
end

function CustomizableGear:showAttcParts(bool)
	local guis = self.guiContainer:GetChildren()
	if bool and not self.attcPartsShown then
		self.attcPartsShown = true

		-- set up the floating guis that follow the gun
		spawn(function()
			local model = self.model
			assert(model)
			local halfButSize = script.AttcPartGui.Size.X.Offset / 2
			while self.attcPartsShown and rs:wait() do
				for _, gui in ipairs(guis) do
					local attcPartName = gui.Name
					local pos, onScreen = cam:WorldToScreenPoint(

					model.AttachmentParts[attcPartName].Position)

					if onScreen then
						gui.Position = newUDim2(0, pos.X - halfButSize, 0, pos.Y - halfButSize)
						--gui:TweenPosition(newUDim2(0, pos.X - halfButSize, 0, pos.Y - halfButSize), "Out", "Quad", 0.02, true)
					else
						warn(attcPartName.." gui is not on screen, gun = "..self.model.name)
					end
				end
			end
		end)

		for _, gui in ipairs(guis) do
			gui.Visible = true
		end
	elseif not bool and self.attcPartsShown then
		self.attcPartsShown = false
		for _, gui in ipairs(guis) do
			gui.Visible = false
		end
	end
end

function CustomizableGear:loadAttc(attcName, attcType)
	self.model:Destroy()

	self.attcList[attcType] = attcName
	self.stats = WeaponAssembly.getStats(self.gearFolder, self.attcList)

	local model = WeaponAssembly.assemble(self.gearFolder, self.attcList)
	for _, pt in ipairs(model:GetDescendants()) do
		if pt:IsA("BasePart") then
			pt.Anchored      = true
			pt.CanCollide    = false
		end
	end
	model.PrimaryPart = model.Main.Center
	model.Parent      = modelContainer
	self.model = model
end

return CustomizableGear
