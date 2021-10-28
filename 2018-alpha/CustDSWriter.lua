-- const funcs
-- local function inListQ(a, list)
-- 	for _, v in ipairs(list) do
-- 		if a == v then
-- 			return true
-- 		end
-- 	end
-- 	return false
-- end


-- defs
local rep = game.ReplicatedStorage
local Gear = rep:WaitForChild("Gear")
local Attachment = rep:WaitForChild("Attachment")
local gm = rep:WaitForChild("GlobalModules")
local checker    = gm:WaitForChild("CustDSChecker")
local levelExpMd = gm:WaitForChild("LevelExp")
local RemoteFuncs = rep:WaitForChild("RemoteFuncs")
local dsFunc = RemoteFuncs:WaitForChild("DS")	-- for data store

local CustDSWriter = {}
CustDSWriter.__index = CustDSWriter

function CustDSWriter.new(dataTable)
	local self = dataTable --[[ {
		exp    = dataTable.exp,
		level  = dataTable.level, 	-- should be calced in the server side
		credit = dataTable.credit,
		gears  = dataTable.gear,
		loadout1 = dataTable.loadout1,
		loadout2 = dataTable.loadout2,
		loadout3 = dataTable.loadout3,
		isAlphaTester = dataTable.isAlphaTester
	}
	--]]
	--self.level = levelExpMd.lvl(self.exp)
	setmetatable(self, CustDSWriter)
	return self
end

-- example arguments
-- "Gear", {"M4A1"}
-- "Attachment", {"M4A1", "TRIJC ACOG Sight"}
function CustDSWriter:buy(itemType, args)
	-- TODO: loading screen here
	local suc, msg = dsFunc:InvokeServer("buy", {itemType, unpack(args)})
	if suc then
		if itemType == "Gear" then
			local gearName  = args[1]
			local gearPrice = require(Gear:FindFirstChild(gearName, true).Reqs).price
			self.gears[gearName].owned = true
			self.credit = self.credit - gearPrice
			assert(self.credit >= 0)
		elseif itemType == "Attachment" then
			local gearName  = args[1]
			local attcName  = args[2]
			local attcPrice = require(Attachment:FindFirstChild(attcName, true).Reqs).price
			self.gears[gearName].ownedAttcs[attcName] = true
			self.credit = self.credit - attcPrice
		end
	else
		warn("cheating??? "..msg)
	end
end

-- example arguments
-- "Gear", {"M4A1"}
-- "Attachment", {"M4A1", "TRIJC ACOG Sight"}
function CustDSWriter:claim(itemType, args)
	local suc, msg = dsFunc:InvokeServer("claim", {itemType, unpack(args)})
	if suc then
		if itemType == "Gear" then
			local gearName  = args[1]
			self.gears[gearName].owned = true
		elseif itemType == "Attachment" then
			local gearName  = args[1]
			local attcName  = args[2]
			self.gears[gearName].ownedAttcs[attcName] = true
		end
	else
		warn("cheating??? "..msg)
	end
end

-- example arguments
-- "loadout1", "Gear", {"M4A1", "Primary"}
-- "loadout1", "Attachment", {"M4A1", "TRIJC ACOG Sight", "Sight"}
function CustDSWriter:equip(loadoutIdx, itemType, args)
	local suc, msg = dsFunc:InvokeServer("equip", {loadoutIdx, itemType, unpack(args)})
	if suc then
		if itemType == "Gear" then
			local gearName = args[1]
			local gearType = args[2]
			self.loadout[loadoutIdx][gearType] = gearName
		elseif itemType == "Attachment" then
			local gearName = args[1]
			local attcName = args[2]
			local attcType = args[3]
			self.loadout[loadoutIdx].customizations[gearName].attcList[attcType] = attcName
		end
	else
		warn("cheating??? "..msg)
	end
end

return CustDSWriter
