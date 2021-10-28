local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.voodooinnovations_jetcomp556)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		recoilX = 0.47,
		recoilXRec = 0.1,
		recoilYMult = -0.075,
		recoilYStart = 4,
		spread = 0.2,
		weight = 0.0028,
	}
end

function attcData.getAniData()
	return {

	}
end

return attcData