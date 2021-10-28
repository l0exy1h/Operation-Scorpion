local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.m4a1_stdstockext)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		recoilCamRot = 0.16,
		recoilFov = -0.36,
	}
end

local newCf = CFrame.new
function attcData.getAniData()
	return {}
end

return attcData