local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.magpul_afg)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		recoilX          = -0.28,
		recoilXRec       = 0.14,
		recoilYMult      = -0.035,
		spread           = 1.6,
		weight           = 0.0015,
		recoilZ          = 0.01,
		recoilZBackDur = 0.015,
	}
end

local newCf = CFrame.new
function attcData.getAniData()
	return {
		moveLeftHandDown = {
			M4A1                = newCf(0.1, -0.05, -0.1),
			["Kriss Vector G2"] = newCf(0, 0, -0.1),
			["MK16 Scar-L"]     = newCf(0.02, 0, -0.22),
			["VSSM Vintorez"]   = newCf(0, 0, -0.1),
			["UMP45"]           = newCf(0.08, -0.05, -0.25),
			["AK74N"]           = newCf(0.03, -0.02, -0.05),
			["SIG MCX Virtus"]  = newCf(0.05, -0.09, -0.5),
			["MP5A3"]           = newCf(0.05, -0.05, -0.1),
		},
	}
end

return attcData