local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.m4a1_shortbarrel)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		aimTime = -0.03,
		weight = -0.002,
		dist0 = -75,
		bulletSpeed = -110,
		bulletShowDist = 5,
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