local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.eotech_xps3)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		aimMult = 1.35,
		aimTime = 0.015,
		weight = 0.001,
	}
end

function attcData.getAniData()
	return {
		aniparts = {
			AimPart = attcName..".aimpart",
		},
		reticle = attcName..".reticle"
	}
end

return attcData