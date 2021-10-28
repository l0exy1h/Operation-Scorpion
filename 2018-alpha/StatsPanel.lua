-- (oop) Stats Panel for showcasing relevant stats for gear/attc
-- should ccontain animation if the preset is the same
-- contains gui
-- logic: preset = {presetName -> {
--		{f1, f2, displayName, max, reversed?},
--		{..}..
--	}},
-- baseStats = (the default stats for the gear)
-- stats = (the toolstats for gears, processed by weaponCustTable)

local StatsPanel = {}
StatsPanel.__index = StatsPanel

-- defs
local rep = game.ReplicatedStorage
local gm  = rep:WaitForChild("GlobalModules")
local sd  = require(gm:WaitForChild("ShadedTexts"))

-- consts
local at = 0.2		-- animation time
local presets = {
	Gear = {
		{"Damage", "Bar"},
		{"Effect Range", "Bar"},
		{"Bullet Velocity", "Bar"},
		{"Stability", "Bar"},
		{"Aim Speed", "Text"},
		{"Weight", "Text"},
		{"Fire Type", "Text"},
	},
	Sight = {
		{"Aim Speed", "Bar"},
		{"Magnification", "Bar"},
	},
	Magazine = {
		{"Weight", "Bar"},
		{"Ammo Amount", "Bar"},
	},
	Muzzle = {
		{"Sound Volume", "Bar"},
		{"Bullet Velocity", "Bar"},
		{"Vertical Recoil", "Bar"},
		{"Horizontal Recoil", "Bar"},
		{"Kickback", "Bar"},
	},
	Barrel = {
		{"Damage", "Bar"},
		{"Sound Volume", "Bar"},
		{"Bullet Velocity", "Bar"},
		{"Vertical Recoil", "Bar"},
		{"Horizontal Recoil", "Bar"},
		{"Weight", "Bar"},
		{"Aim Speed", "Bar"},
	},
	Stock = {
		{"Aim Speed", "Bar"},
		{"Vertical Recoil", "Bar"},
		{"Horizontal Recoil", "Bar"},
		{"Weight", "Bar"},
	},
	Handle = {
		{"Weight", "Bar"},
		{"Vertical Recoil", "Bar"},
		{"Horizontal Recoil", "Bar"},
	},
	Grip = {
		{"Kickback", "Bar"},
		{"Vertical Recoil", "Bar"},
		{"Horizontal Recoil", "Bar"},
	}
}

-- displayName_displayType -> config
local configs = {
	Damage_Bar = {f1 = "shooting", f2 = "damage", min = 0, max = 100},
	["Effect Range_Bar"] = {f1 = "shooting", f2 = "distance", min = 0, max = 400},
	["Bullet Velocity_Bar"] = {f1 = "shooting", "velocity", min = 100, max = 1500},
	Stability_Bar = {f1 = "shooting", f2 = "camKickUp", min = 2, max = 0},			-- reversed
	["Aim Speed_Bar"] = {f1 = "handling", f2 = "aimSpeed", min = 2, max = 0},
	["Aim Speed_Text"] = {f1 = "handling", f2 = "aimSpeed", desc = function(val) return val end},
	Weight_Text = {f1 = "handling", f2 = "walkSpeedMult", desc = function(val) return 7/val end},
	["Fire Type_Text"] = {f1 = "handling", f2 = "automatic", desc = function(bool) return bool and "Automatic" or "Semi-automatic" end},
	Magnification_Bar = {f1 = "handling", f2 = "aimFOVMult", min = 0, max = 6},
	Weight_Bar = {f1 = "handling", f2 = "walkSpeedMult", min = 0, max = 2},
	["Ammo Amount_Bar"] = {f1 = "resources", f2 = "magSize", min = 0, max = 60},
	["Sound Volume_Bar"] = {f1 = "shooting", f2 = "soundMult", min = 0, max = 2},
	["Vertical Recoil_Bar"] = {f1 = "shooting", f2 = "camKickUp", min = 2, max = 0},
	["Horizontal Recoil_Bar"] = {f1 = "shooting", f2 = "recSwaySize", min = 0.1, max = 0},
	Kickback_Bar = {f1 = "shooting", f2 = "recBack", min = 0.2, max = 0.1},
}

function StatsPanel.new(_fr)
	local self = {
		fr = _fr,
		visible = false,
		currPresetName = nil,
	}
	setmetatable(self, StatsPanel)
	self:setVisible(false)
	return self
end

local function getPrecentage(val, min, max)
	return (val - min) / (max - min)
end

local function genSingleStats(displayName, displayType, guiName, config, baseStats, stats, index, guiHolder)
	local gui = script[displayType.."Stats"]:clone()
	gui.Name = guiName

	local baseVal = baseStats[config.f1][config.f2]
	local val     = stats[config.f1][config.f2]

	sd.setText(gui.Top.Title, displayName)

	if displayType == "Bar" then
		sd.setText(gui.Top.Number, val)
		gui.Bar.Base.Position = UDim2.new(getPrecentage(baseVal, config.min, config.max), 0, 0, 0)
		gui.Bar.Cover.Size    = UDim2.new(getPrecentage(val, config.min, config.max), 0, 1, 0)
	elseif displayType == "Text" then
		sd.setText(gui.Bottom.Desc, config.desc(val))
	end

	gui.LayoutOrder = index + displayType == "Text" and 500 or 0
	gui.Parent = guiHolder

	return gui
end

local function updateSingleStats(gui, displayType, config, baseStats, stats)
	local baseVal = baseStats[config.f1][config.f2]
	local val     = stats[config.f1][config.f2]

	if displayType == "Bar" then
		sd.setText(gui.Top.Number, val)
		gui.Bar.Base:TweenPosition(UDim2.new(getPrecentage(baseVal, config.min, config.max), 0, 0, 0),
		 "Out", "Quad", at, true)
		gui.Bar.Cover:TweenSize(UDim2.new(getPrecentage(val, config.min, config.max), 0, 1, 0),
		 "Out", "Quad", at, true)
	else
		sd.setText(gui.Bottom.Desc, string.gsub(config.desc, "[replace]", tostring(val)))
	end
end

function StatsPanel:showcase(presetName, baseStats, stats)
	local fr = self.fr
	assert(fr)
	if presetName ~= self.currPresetName then
		self.currPresetName = presetName

		-- refill the list
		fr:ClearAllChildren()
		for i, s in ipairs(presets[presetName]) do
			local displayName = s[1]
			local displayType = s[2]
			local guiName = displayName.."_"..displayType
			local config = configs[guiName]
			genSingleStats(displayName, displayType, guiName, config, baseStats, stats, i, fr)
		end
	else
		for i, s in ipairs(presets[presetName]) do
			local displayName = s[1]
			local displayType = s[2]
			local guiName = displayName.."_"..displayType
			local singleStats = fr[guiName]
			local config = configs[guiName]
			updateSingleStats(singleStats, displayType, config, baseStats, stats)
		end
	end
end

function StatsPanel:setVisible(bool)
	if bool and not self.visible then
		self.fr:TweenPosition(UDim2.new(1, 400, 0.03, 0), "Out", "Quad", at, true)
	elseif not bool and self.visible then
		self.fr:TweenPosition(UDim2.new(1, -50, 0.03, 0), "Out", "Quad", at, true)
	end
	self.visible = bool
end

return StatsPanel
