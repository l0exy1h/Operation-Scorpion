local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.silencerco_osprey45)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		dmg0       = 2,
		dist0      = 65,
		recoilX    = -0.17,
		recoilXRec = .06,
		recoilYMult= -0.045,
		weight     = 0.004,
		suppressed = true,
		bulletPen      = -0.33,
		bulletSpeed    = -55,
		bulletShowDist = 1.5,
	}
end

function attcData.getAniData()
	return {

	}
end

return attcData