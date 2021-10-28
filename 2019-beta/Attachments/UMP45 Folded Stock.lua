local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.ump45_stdstockcllpsd)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		recoilCamRot = -0.25,
		recoilFov    = 0.2,
	}
end

local newCf = CFrame.new
function attcData.getAniData()
	return {}
end

return attcData

