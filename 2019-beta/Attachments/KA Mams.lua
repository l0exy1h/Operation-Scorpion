local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.knightsarmament_mams)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		recoilX = -0.25,
		recoilXRec = 0.2,
		spread = 1.5,
		weight = 0.003,
	}
end

function attcData.getAniData()
	return {
	}
end

return attcData