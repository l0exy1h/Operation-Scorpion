local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.mcxvirtus_handguardext)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		dmg0 = 5,
		aimTime = 0.062,
		weight = 0.011,
		dist0 = 95,
		bulletSpeed = 225,
		bulletShowDist = -3,
	}
end

local newCf = CFrame.new
function attcData.getAniData()
	return {
	}
end

function attcData.getCompatibleAttachments()
	return {
		Underbarrel = {
			["MG Angled Grip"] = 1,
			["DD Vertical Grip"] = 1,
		},
		-- muzzle point is enabled by the original gun
	}
end

return attcData