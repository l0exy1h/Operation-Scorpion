local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.moecarbinestock)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		recoilCamRot = 0.07,
		recoilFov = -0.14,
		weight = -0.005,
	}
end

local newCf = CFrame.new
function attcData.getAniData()
	return {
	}
end

return attcData