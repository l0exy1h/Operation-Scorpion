local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.ak_opticrailmount)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		weight = 0.002,
	}
end

local newCf = CFrame.new
function attcData.getAniData()
	return {
	}
end

function attcData.getCompatibleAttachments()
	return {
		Optic = {
			["ET Holographic Sight"] = 1,
			["TA31H Acog"] = 1,
			["RX6 Reflex"] = 1,
			["SRS Red Dot"] = 1,
		},
	}
end

return attcData