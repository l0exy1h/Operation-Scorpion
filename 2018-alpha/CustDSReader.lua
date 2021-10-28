-- a checker that can be called both by the client and server
-- the "ds" field should share the same structure whenever its called by server or client
-- except for the fact that the client one contains a metatable

local md = {}

-- defs
local rep = game.ReplicatedStorage
local Gear = rep:WaitForChild("Gear")
local Attachment = rep:WaitForChild("Attachment")

-- example arguments
-- ds, "Gear", {"M4A1"}
-- ds, "Attachment", {"M4A1", "TRIJC ACOG Sight"}
function md.ownedQ(ds, itemType, args)
	if itemType == "Gear" then
		local gearName = args[1]
		return ds.gears[gearName].owned
	elseif itemType == "Attachment" then
		local gearName = args[1]
		local attcName = args[2]
		return ds.gears[gearName].ownedAttcs[attcName] ~= nil
	end
end

-- example arguments
-- "Gear", {"M4A1"}
-- "Attachment", {"M4A1", "TRIJC ACOG Sight"}
function md.reqMetQ(ds, itemType, args)
	local met, unMetMsg, lockedMsg = false, nil, nil
	local req = nil
	local gearName, attcName
	if itemType == "Gear" then
		gearName = args[1]
		req = require(Gear:FindFirstChild(gearName, true).Reqs).req
	elseif itemType == "Attachment" then
		gearName = args[1]
		attcName = args[2]
		req = require(Attachment:FindFirstChild(attcName, true).Reqs).req[gearName]
	end

	if req then
		local reqType, reqVal = req.recType, req.reqVal
		if reqType == "level" then
			met      = ds.level >= reqVal
			unMetMsg = string.format("Character Level: %d / %d", ds.level, reqVal)
		elseif reqType == "gear level" then
			local gearLevel = ds.gear[gearName].level
			met      = gearLevel >= reqVal
			unMetMsg = string.format("Gear Level: %d / %d", gearLevel, reqVal)
		elseif reqType == "gear headshots" then
			local geatHeadshots = ds.gear[gearName].headshots
			met = gearHeadshots >= reqVal
			unMetMsg = string.format("Gear Headshots: %d / %d", gearHeadshots, reqVal)
		elseif reqType == "gearHeadshots" then
			local headshots = ds.headshots
			met = headshots >= reqVal
			unMetMsg = string.format("Headshots: %d / %d", gearHeadshots, reqVal)
		elseif reqType == "alpha tester only" then
			met = ds.isAlphaTester
			lockedMsg = "Pre-alpha exclusive"
		else
			error("reqType "..reqType.." is not implemented in DSHandler")
		end
	end

	return met, unMetMsg, lockedMsg
end

-- example arguments
-- "loadout1", "Gear", {"M4A1", "Primary"}
-- "loadout1", "Attachment", {"M4A1", "TRIJC ACOG Sight", "Sight"}
function md.equippedQ(ds, loadoutIdx, itemType, args)
	local loadoutIdx = args[1]
	local loadout = ds[loadoutIdx]
	if itemType == "Gear" then
		local gearName = args[2]
		local gearType = args[3]
		return loadout[gearType] == gearName
	elseif itemType == "Attachment" then
		local gearName = args[2]
		local attcName = args[4]
		local attcType = args[5]
		return attcName, loadout.customizations[gearName].attcList[attcType] == attcName
	end
end

return md
