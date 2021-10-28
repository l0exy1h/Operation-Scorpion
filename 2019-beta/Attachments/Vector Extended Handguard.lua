local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.krissvector_exthandguard)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		weight = 0.003,
	}
end

local newCf = CFrame.new
function attcData.getAniData()
	return {
		rotateMuzzle = true, 
	}
end

function attcData.getCompatibleAttachments()
	return {
		Muzzle = {
			["Vector Extended Muzzle"] = 1,
		}
	}
end

return attcData