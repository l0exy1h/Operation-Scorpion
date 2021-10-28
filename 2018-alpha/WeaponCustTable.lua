-- oop: class for weapon customization, a PHYSICAL table
-- along with customizable weapons
-- renders GUI and handles mouse input and payment
-- camera control

local WeaponCustTable = {}
WeaponCustTable.__index = WeaponCustTable

-- defs
local lp               = game.Players.LocalPlayer
local rep              = game.ReplicatedStorage
local Attachment       = rep:WaitForChild("Attachment")
local Gear             = rep:WaitForChild("Gear")
local uis              = game:GetService("UserInputService")
local mouse            = lp:GetMouse()
local CustomizableGear = require(script:WaitForChild("CustomizableGear"))
local DynamicCamera    = require(script:WaitForChild("DynamicCamera"))
local EquipmentSlider  = require(script:WaitForChild("EquipmentSlider"))
local ItemDescription  = require(script:WaitForChild("ItemDescription"))
local GetPanel         = require(script:WaitForChild("GetPanel"))
local StatsPanel       = require(script:WaitForChild("StatsPanel"))
local lpGui            = lp:WaitForChild("PlayerGui")
local changeTopBar     = lpGui:WaitForChild("Top"):WaitForChild("TopBarScript"):WaitForChild("ChangeContent")
local colorCorrection  = game:GetService("Lighting"):WaitForChild("Customization")
local gm               = rep:WaitForChild("GlobalModules")
local dsReader         = require(gm:WaitForChild("CustDSReader"))
--local gm               = rep:WaitForChild("GlobalModules")
--local SlidingFrame     = require(gm:WaitForChild("SlidingFrame"))
-- local bfSelect   = script:WaitForChild("Select")

-- consts
local modes1 = {"Primary", "Secondary", "Equipment", "Deactivated"}
local modes2 = {"Gear", "Attachment", "Skin"}
local at = 0.2

-- stats
-- get
-- descPanel
-- slider
-- 3d model
	-- floating gui
-- top bar
-- camera
-- playerStats (communication with Data Store)

function WeaponCustTable.new(_tableModel, _gui, _ds, _loadoutIdx)
	local self = {
		mode1            = nil,
		savedMode1       = nil,
		mode2            = nil,
		savedMode2       = nil,
		tableModel       = _tableModel,
		custGears        = {},
		front            = nil,
		gui              = _gui,		-- TODO: for future updates: init/clone gui here instead
		modeChanging     = false,
		fullscreen       = false,
		bfSelect         = Instance.new("BindableFunction"),			-- bf: bindable function. pass is down to slider
		bfSelectAttcPart = Instance.new("BindableFunction"),
		cam              = DynamicCamera.new(),
		descPanel        = ItemDescription.new(_gui.Description),
		statsPanel       = StatsPanel.new(_gui.Stats),
		ds               = _ds,
		loadoutIdx       = _loadoutIdx,
		bright           = false,			-- status for colorcorrection
	}
	setmetatable(self, WeaponCustTable)
	self.getPanel= GetPanel.new(_gui.Get, _ds, _loadoutIdx, self)
	self.slider  = EquipmentSlider.new(_gui.Sliding, self.bfSelect, _ds, _loadoutIdx)

	-- load customizable gears
	local custGears = self.custGears
	for _, type in ipairs(Gear:GetChildren()) do		-- type = Primary, secondary, equipment..
		for _, gearFolder in ipairs(type:GetChildren()) do
			local gearName = gearFolder.Name
			custGears[gearName] = CustomizableGear.new(
				gearFolder,
				-- require(gearFolder.DefaultAttcList),
				_ds.loadouts[_loadoutIdx].customizations[gearName].attcList
				_tableModel.Stash,
				_tableModel.ModelContainer,
				_gui.AttcPartsGuiHolder,
				self.bfSelectAttcType,
			)
		end
	end
	-- self.Primary = self.custGears["M4A1"]
	self.Primary = self.custGears[_ds.loadouts[_loadoutIdx].Primary]
	self.Primary:moveTo(_tableModel.PrimaryBack)
	-- self.Secondary = self.custGears["USP"]
	self.Secondary = self.custGears[_ds.loadouts[_loadoutIdx].Secondary]
	self.Secondary:moveTo(_tableModel.SecondaryBack)
	-- self.Equipment = nil
	-- self.equipment:moveTo(_tableModel.EquipmentBack)

	-- set the default modes
	self:setMode("Deactivated", nil)

	-- setup the listener for activating the area
	_tableModel.Activate.Touched:connect(function(p)
		if lp.Character and p:IsDescendantOf(lp.Character) and self.mode1 == "Deactivated" then
			lp.Character.HumanoidRootPart.CFrame = _tableModel.TeleportOut.CFrame + Vector3.new(0, 3, 0)
			self:setMode("Primary", nil)
		end
	end)

	-- for fullscreen previewing
	mouse.KeyDown:connect(function(key)
		if key == " " and not self.modeChanging and self.mode1 ~= "Deactivated" then
			self:toggleFullscreen()
		end
	end)

	-- for equipment selection (invoked from slider)
	-- "Gear", {"M4A1", "Primary"}
	-- "Attachment", {"M4A1", "TRIJC ACOG Sight", "Sight"}
	function self.bfSelect.OnInvoke(itemType, args)

		if itemType == "Gear" then
			local gearName = args[1]
			local gearType = args[2]

			local newFront = self.custGears[gearName]
			assert(newFront, gearName.."is not found in custGears")
			if self.front then self.front:setRotable(false) end
			self:updateFront(newFront)
			newFront:setRotable(true)

			self.statsPanel:showcase("Gear", newFront.baseStats, newFront.stats)
			self.getPanel:setup("Gear", {gearName, gearType})
			self.descPanel:setDescription("Gear", gearName)--, require(Gear:FindFirstChild(gearName, true).Desc))
			self:setColorBright(dsReader.ownedQ(_ds, "Gear", {gearName}))

		elseif itemType == "Attachment" then
			local gearName = args[1]
			local attcName = args[2]
			local attcType = args[3]
			local front    = self.front

			-- pre: only the valid options will be shown in the list and be selected
			front:loadAttc(attcName, attcType)
			self.statsPanel:showcase("Attachment", front.baseStats, front.stats)
			self.getPanel:setup("Attachment", {gearName, attcName, attcType})
			self.descPanel:setDescription("Attachment", attcName)--, require(Attachments:FindFirstChild(attcName, true).Desc))
			self:setColorBright(dsReader.ownedQ(_ds, "Attachment", {gearName, attcName}))
		--[[
		elseif itemType == "Skin" then
		--]]
		end
	end

	function self.bfSelectAttcType.OnInvoke(attcType)
		local gearName = self.front.name
		self.slider:genList("Attachment", {self.front, attcType})
		self.slider:setVisible(true)
		self.cam:moveTo(self.front.model.AttcCam[attcType])
	end

	return self
end

local function setTopLinePos(top, posName)
	local line = top.Line
	local buts = top.Buttons
	line:TweenPosition(UDim2.new(0, buts[posName].AbsolutePosition.X - buts.AbsolutePosition.X, 0, 0), "Out", "Quad", at, true)
end

function WeaponCustTable:makeTopButs()
	local top = script.Top:clone()
	local buts = top.Buttons
	local line = top.Line

	buts.Exit.Exit.MouseButton1Click:connect(function()
		self:setMode("Deactivated")
		setTopLinePos(top, "Exit")
	end)
	buts.Exit.Back.MouseButton1Click:connect(function()
		-- deselect attcType
		if not self.front.attcPartsShown and self.mode2 == "Attachment" then
			self:setMode(self.mode1, "Attachment", true)

		-- go back to Primary/secondary, gear
		elseif self.front.attcPartsShown and self.mode2 == "Attachment" then
			self:setMode(self.mode1, "Gear")
			buts.Exit.Back.Visible = false
			buts.Exit.Exit.Visible = true
			setTopLinePos(top, self.mode1)

		else
			error("but logic error:", self.mode1, self.mode2, self.front.attcPartsShown)
		end
	end)
	buts.Primary.MouseButton1Click:connect(function()
		self:setMode("Primary")
		setTopLinePos(top, "Primary")
	end)
	buts.Secondary.MouseButton1Click:connect(function()
		self:setMode("Secondary")
		setTopLinePos(top, "Secondary")
	end)
	buts.Attachment.MouseButton1Click:connect(function()
		local gearOwned = dsReader.ownedQ(self.ds, "Gear", self.front.name)
		if gearOwned then
			self:setMode(self.mode1, "Attachment")
			setTopLinePos(top, "Attachment")
			buts.Exit.Back.Visible = true
			buts.Exit.Exit.Visible = false
		end
	end)
	return top
end

-- set mode1 and mode2
function WeaponCustTable:setMode(_mode1, _mode2, forceReloadMode2)
	warn("setMode ".._mode1, _mode2)
	self.modeChanging = true

	-- for optimization
	local tableModel = self.tableModel
	local cam = self.cam

	local forceReloadMode2 = false
	if self.mode1 ~= _mode1 then
		self:setColorBright(true)
		if _mode1 == "Deactivated" then
			self:putAwayFront()
			cam:setEnabled(false)

		else
			self:updateFront(self[_mode1])
			cam:setEnabled(true)
			cam:moveTo(tableModel.CamFront)
			cam:setDynamic(true)

			local topButs = makeTopButs()
			changeTopBar.Fire(topButs)

			_mode2 = "Gear"
			forceReloadMode2 = true
		end
		self.mode1 = _mode1
	end

	if self.mode1 ~= "Deactivated" and self.mode2 ~= _mode2 or forceReloadMode2 then
		self.mode2 = _mode2
		assert(self.front)
		if _mode2 == "Gear" then
			self.slider:genList(self.mode2, {self.mode1})
			self.slider:setVisible(true)
			self.cam:moveTo(self.tableModel.CamFront)
		elseif _mode2 == "Attachment" then
			self:setColorBright(true)
			self.slider:setVisible(false)
			self.front:setRotable(false)
			self.front:showAttcParts(true)
			self.statsPanel:setVisible(false)
			self.getPanel:setVisible(false)
			self.descPanel:setVisible(false)
			self.cam:moveTo(self.tableModel.CamFront)
		--[[
		elseif _mode2 == "Skin" then
			self.front:rotable(true)
			self.front:showAttcParts(false)
			self.cam:moveTo(self.tableModel.CamClose)
		--]]
		end
	end

	self.modeChanging = false
end

-- helper function for putting back the gear in front
function WeaponCustTable:putAwayFront()
	local front = self.front
	if front then
		front:setAutoRotate(false)
		front:setRotable(false)
		front:showAttcParts(false)

		if front == self.Primary then
			front:moveTo(self.tableModel.PrimaryBack)
		elseif front == self.Secondary then
			front:moveTo(self.tableModel.SecondaryBack)
		else
			front:moveTo(self.tableModel.Stash)
		end

		self.front = nil
	end
end
function WeaponCustTable:updateFront(_front)
	self:putAwayFront()
	self.front = _front
	if _front then
		_front:moveTo(self.tableModel.Front)
	end
end

-- TODO: fullscreen shit
-- fullscreen toggler (press spacebar)
function WeaponCustTable:toggleFullscreen()
	self.modeChanging = true
	local newState    = not self.fullscreen

	assert(self.front)
	self.front:setAutoRotate(newState)

	-- TODO: stats panel, get panel, sliding frame

	assert(self.cam)
	--self.cam:setDynamic(not newState)
	self.cam:setScrolling(newState)

	self.fullscreen   = newState
	self.modeChanging = false
end

-- color correction effects:
-- make the screen black and white the the item is not owned by the player
function WeaponCustTable:setColorBright(bool)
	if bool and not self.bright then
		colorCorrection.Saturation = 0
	elseif not bool and self.bright then
		colorCorrection.Saturation = -1
	end
	self.bright = bool
end

return WeaponCustTable
