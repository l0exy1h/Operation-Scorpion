local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.vss_ext_mag)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		weight = 0.005,
		magSize = 20,
	}
end

function attcData.getAniData()
	return {
		aniparts = {
			WeaponMag = attcName..".vssmvintorez_extmag",
		},
	}
end

return attcData