local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.mk16_shortbarrel)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		aimTime = -0.045,
		weight = -0.0028,
		dist0 = -110,
		bulletSpeed = -65,
		bulletShowDist = 4,
	}
end

local newCf = CFrame.new
function attcData.getAniData()
	return {
	}
end

function attcData.getCompatibleAttachments()
	return {
	}
end

return attcData