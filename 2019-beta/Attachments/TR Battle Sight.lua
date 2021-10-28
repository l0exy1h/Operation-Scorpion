local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script["troybattlesights"])
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		weight  = -0.002,
	}
end

function attcData.getAniData()
	return {
		aniparts = {
			AimPart = attcName..".aimpart",
		},
	}
end

return attcData