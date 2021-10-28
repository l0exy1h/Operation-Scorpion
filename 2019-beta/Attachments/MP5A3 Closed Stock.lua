local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.mp5a3_stdstock)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		recoilCamRot = -0.22,
		recoilFov = 0.15,
	}
end

local newCf = CFrame.new
function attcData.getAniData()
	return {}
end

return attcData