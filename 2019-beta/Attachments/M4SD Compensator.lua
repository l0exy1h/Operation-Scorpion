local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.griffinarmament_m4sdhammpercomp)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		recoilX = 0.33,
		recoilXRec = -0.08,
		recoilYMult = -0.11,
		recoilYStart = 2,
		spread = 0.8,
		weight = 0.0026,
	}
end

function attcData.getAniData()
	return {

	}
end

return attcData