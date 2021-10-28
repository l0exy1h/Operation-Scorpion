local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.silencerco_sakerasr556)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		dmg0       = 3,
		dist0      = 110,
		recoilX    = -0.11,
		recoilXRec = 0.04,
		recoilYMult= -0.08,
		weight     = 0.0045,
		suppressed = true,
		bulletPen      = -0.8,
		bulletSpeed    = -145,
		bulletShowDist = 3,
	}
end

function attcData.getAniData()
	return {

	}
end

return attcData