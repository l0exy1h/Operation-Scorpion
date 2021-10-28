local attcData = {}
local clone    = game.Clone
local attcName = script.Name

function attcData.getModel()
	local model = clone(script.mp5a3_rishandguard)
	model.Name  = script.Name
	return model
end

function attcData.getStats()
	return {
		weight = 0.0025,
	}
end

local newCf = CFrame.new
function attcData.getAniData()
	return {
	}
end

function attcData.getCompatibleAttachments()
	return {
		Underbarrel = {
			["MG Angled Grip"] = 1,
			["DD Vertical Grip"] = 1,
		},
		-- muzzle point is enabled by the original gun
	}
end

return attcData