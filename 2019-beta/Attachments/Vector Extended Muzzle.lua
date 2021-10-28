local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.krissvector_barrelextension)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		dmg0       = 5,
		dist0      = 110,
		aimTime    = 0.06,
		weight     = 0.008,

		bulletSpeed    = 125,
		bulletShowDist = -2,
	}
end

function attcData.getAniData()
	return {
		dontRotate = true,
	}
end

return attcData