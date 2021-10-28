local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.danieldefense_verticalgrip)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		recoilX        = 0.65,
		recoilXRec     = -0.06,
		recoilYMult    = 0.1,
		spread         = -2.88,
		weight         = 0.0012,
		recoilZ        = -0.03,
		recoilZBackDur = -0.03,
	}
end

local newCf = CFrame.new
function attcData.getAniData()
	return {
		moveLeftHandDown = {
			M4A1                = newCf(0.13, -0.12, -0.08),
			["Kriss Vector G2"] = newCf(0.05, -0.07, -0.1),
			["MK16 Scar-L"]     = newCf(0.1, -0.07, -0.22),
			["VSSM Vintorez"]   = newCf(0.05, -0.075, -0.1),
			["UMP45"]           = newCf(0.08, -0.1, -0.25),
			["AK74N"]           = newCf(0.05, -0.075, -0.075),
			["SIG MCX Virtus"]  = newCf(0.05, -0.125, -0.5),
			["MP5A3"]           = newCf(0.05, -0.135, -0.1),
		},
	}
end

return attcData