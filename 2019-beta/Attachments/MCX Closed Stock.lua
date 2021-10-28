local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.mcxvirtus_stockcllpsd)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		recoilCamRot = -0.24,
		recoilFov = 0.18,
	}
end

local newCf = CFrame.new
function attcData.getAniData()
	return {
	}
end

return attcData