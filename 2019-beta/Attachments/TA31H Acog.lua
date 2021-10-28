local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.ta31h)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		aimMult = 2.5,
		aimTime = 0.05,
		weight = 0.005,
	}
end

function attcData.getAniData()
	return {
		aniparts = {
			AimPart = attcName..".aimpart",
		},
		reticle = attcName..".reticle_2",
		reticleExt = {
			attcName..".reticle_1"
		}
	}
end

return attcData