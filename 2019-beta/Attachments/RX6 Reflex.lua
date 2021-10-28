local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script["rx06-11"])
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		aimMult = 1.5,
		aimTime = 0.03,
		weight  = 0.002,
	}
end

function attcData.getAniData()
	return {
		aniparts = {
			AimPart = attcName..".aimpart",
		},
		reticle = attcName..".reticle",
	}
end

return attcData