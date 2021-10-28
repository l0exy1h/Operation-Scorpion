-- the data store handler in the server side

local rep        = game.ReplicatedStorage
local Gear       = rep:WaitForChild("Gear")
local Attachment = rep:WaitForChild("Attachment")
local gm         = rep:WaitForChild("GlobalModules")
local levelExpMd = require(gm:WaitForChild("LevelExp"))
local dsReader   = require(gm:WaitForChild("CustDSReader"))

local Events      = rep:WaitForChild("Events")
local dsEvent     = Events:WaitForChild("DS")
local RemoteFuncs = rep:WaitForChild("RemoteFuncs")
local dsFunc      = RemoteFuncs:WaitForChild("DS")	-- for data store
local ds          = game:GetService("DataStoreService")

local http = game:GetService("HttpService")

local ser = game.ServerStorage
local sm  = ser:WaitForChild("ServerModules")
local sql = require(sm:WaitForChild("SQL"))

local currVersion = "beta.reserveServerUpdate"

local plrs    = game.Players
_G.plrData = {}
_G.passed  = {}			-- plrName -> true, the players who passed the ban

-- ban module
-------------------------------------
local ban = game.ServerStorage:WaitForChild("Ban")
local whiteList = ban:WaitForChild("WhiteList"):GetChildren()
local blackList = ban:WaitForChild("BlackList"):GetChildren()
local whiteListOn = ban:WaitForChild("WhiteListOn").Value
local blackListOn = ban:WaitForChild("BlackListOn").Value

local function isBanned(plr)
	local plrName = plr.Name
	if blackListOn then
		for _, str in ipairs(blackList) do
			if str.Name == plrName then
				return true
			end
		end
	end
	if whiteListOn then
		local banned = true
		for _, str in ipairs(whiteList) do
			if str.Name == plrName then
				banned = false
			end
		end
		return banned
	end
	return false
end

-- check integrity
--------------------------------------

local function appendNewColumns(plr, data)
	local ret = false
	
	local default = require(script.DefaultData).get()
	sql.printTable(data)
	for k, v in pairs(default) do
		if data[k] == nil then
			data[k] = v
			print(plr, "data table missing:", k, "; already appended")
			ret = true
			
			-- upload to sql
			if type(v) == "string" then
				sql.query(string.format("update playerstats set %s = '%s' where user_id = %d", k, v, plr.UserId))
			elseif type(v) == "number" then
				sql.query(string.format("update playerstats set %s = %d where user_id = %d", k, v, plr.UserId))
			elseif type(v) == "boolean" then
				sql.query(string.format("update playerstats set %s = %s where user_id = %d", k, tostring(v), plr.UserId))
			elseif type(v) == "table" then
				sql.query(string.format("update playerstats set %s = '%s' where user_id = %d", k, http:JSONEncode(v), plr.UserId))
			else
				error("type not supported:", type(v))
			end
		end
	end

	return ret
end

-- upload and download data from external sql
--------------------------------------------------
local function updateDs(plr, data, newPlayerQ)
	local suc, msg = pcall(function()
		if newPlayerQ then
			sql.query(string.format([[
				insert into playerstats(
					user_id, user_name, is_alpha_tester, last_login_version, exp, 
					headshots, kills, level, credit, acc_credit, 
					casual_wins, captures, rank, ranked_wins, match_cnt_today, 
					synced_from_old_os,
					gears,
					loadouts,
					damage, assists
				)
				values(%d, '%s', %s, '%s', %d, 
					%d, %d, %d, %d, %d, 
					%d, %d, %d, %d, %d, 
					%s, '%s', '%s',
					%d, %d
				)
				]], 
				plr.UserId,
				plr.Name,
				tostring(data.is_alpha_tester),
				data.last_login_version,
				data.exp,		--5
				data.headshots,
				data.kills,
				data.level,
				data.credit,
				data.acc_credit,	-- 10
				data.casual_wins,
				data.captures,
				data.rank,
				data.ranked_wins,
				data.match_cnt_today,	-- 15
				tostring(data.synced_from_old_os),
				http:JSONEncode(data.gears),
				http:JSONEncode(data.loadouts),
				data.damage,
				data.assists
			))
		else
			sql.query(string.format([[
				update playerstats set
					last_login_version = '%s',
					gears = '%s',
					loadouts = '%s'
				where user_id = %d
				]],
				data.last_login_version,
				http:JSONEncode(data.gears),
				http:JSONEncode(data.loadouts),
				plr.UserId
			))
			
			if rep:WaitForChild("Debug"):WaitForChild("InfiniteMoney").Value == false then 
				sql.query(string.format([[
					update playerstats set
						credit = %d
					where user_id = %d
					]],
					data.credit,
					plr.UserId
				))
			end
		end
	end)		
	
	if not suc then
		warn("error uploading player data!, plr = ", plr, msg)
	end
end

local function parseData(raw)
	print("parseData:")
	--sql.printTable(raw)
	
	--[[local column = raw[1]
	local ret = {
		is_alpha_tester    = column.is_alpha_tester,
		last_login_version = column.last_login_version,
		exp                = column.exp,
		headshots          = column.headshots,
		kills              = column.kills,
		level              = column.level,
		credit             = column.credit,
		acc_credit         = column.acc_credit,
		casual_wins        = column.casual_wins,
		captures           = column.captures,
		rank               = column.rank,
		ranked_wins        = column.ranked_wins,
		last_match_date    = column.last_match_date,
		match_cnt_today    = column.match_cnt_today,
		synced_from_old_os = column.synced_from_old_os,
		gears              = column.gears,
		loadouts           = column.loadouts,
	}
	print("parsed result:")
	sql.printTable(ret)	--]]
	local ret = raw
	
	return ret
end

-- main entry
------------------------------------------
local function onPlayerAdded(plr)
	warn("playeradded")
	if isBanned(plr) then
		plr:kick("P Means Private")
		return
	end

	local plrName   = plr.Name
	local userId    = plr.UserId
	local rawData   = sql.query(string.format([[select * from playerstats where user_id = %d]], userId)) 
	local newPlayer = rawData[1] == nil 
	local data = nil

	--firstTimeBeta = true
	warn("plr =", plr, ", newPlayerQ =", newPlayer)
	if newPlayer then
		data = require(script.DefaultData).get()
		updateDs(plr, data, true)
	else
		data = parseData(rawData)[1]
		if appendNewColumns(plr, data) then
			
		end
	end

	if rep:WaitForChild("Debug"):WaitForChild("InfiniteMoney").Value == true then 
		data.credit = 1000000
	end

	_G.passed[plr.Name] = true
	-- preload the player image
	local avatar  = Instance.new("StringValue")
	avatar.Value  = plrs:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	avatar.Name   = "Avatar"
	avatar.Parent = plr	
	
	local level   = Instance.new("IntValue")
	level.Value   = data.level
	level.Name    = "Level"
	level.Parent  = plr
	
	local exp     = Instance.new("IntValue")
	exp.Value     = data.exp
	exp.Name      = "Exp"
	exp.Parent    = plr
	

	_G.plrData[plr.Name] = data
	dsEvent:FireClient(plr, data)		-- PRE: data does not contain integer entries
	
	game.ServerScriptService:WaitForChild("MatchMaking"):WaitForChild("Function"):Invoke("createSingleParty", {plr})
end
plrs.PlayerAdded:connect(onPlayerAdded)
	
-- save when player quits (this case contains teleportation)
plrs.PlayerRemoving:connect(function(plr)
	if _G.plrData[plr.Name] then
		updateDs(plr, _G.plrData[plr.Name], false)
	end
end)


-- for weapon customization
------------------------------------------------------------

-- example arguments
-- "buy", {"Gear", "M4A1 Carbine"}
-- "buy", {"Attachment", "M4A1 Carbine", "TRIJC ACOG Sight"}
-- "claim", {"Gear", "M4A1 Carbine"}
-- "claim", {"Attachment", "M4A1 Carbine", "TRIJC ACOG Sight"}
-- "equip", {"loadout1", "Gear", "M4A1 Carbine", "Primary"}
-- "equip", {"loadout1", "Attachment", "M4A1 Carbine", "TRIJC ACOG Sight", "Sight"}
dsFunc.OnServerInvoke = function(plr, request, args)
	local data = _G.plrData[plr.Name]
	if request == "buy" then
		-- server-side check: is credit enough?

		local itemType = args[1]
		if itemType == "Gear" then
			local gearName  = args[2]
			local gearPrice = require(Gear:FindFirstChild(gearName, true).Reqs).price

			if data.credit < gearPrice then
				return false, "not enough credit in the server side: "..tostring(data.credit)
			end

			data.credit   = data.credit - gearPrice
			data.gears[gearName].owned = true

		elseif itemType == "Attachment" then
			local gearName  = args[2]
			local attcName  = args[3]
			local attcPrice = require(Attachment:FindFirstChild(attcName, true).Reqs).price

			if data.credit < attcPrice then
				return false, "not enough credit in the server side: "..tostring(data.credit)
			end

			data.credit = data.credit - attcPrice
			data.gears[gearName].ownedAttcs[attcName] = true
		end

	elseif request == "claim" then
		-- server-side check: is req met?

		local itemType = args[1]
		if itemType == "Gear" then
			local gearName  = args[2]

			local suc, msg1, msg2 = dsReader.reqMetQ(data, itemType, {gearName})
			if not suc then
				return false, msg1 or msg2
			end

			data.gears[gearName].owned = true

		elseif itemType == "Attachment" then
			local gearName  = args[2]
			local attcName  = args[3]

			local suc, msg1, msg2 = dsReader.reqMetQ(data, itemType, {gearName, attcName})
			if not suc then
				return false, msg1 or msg2
			end

			data.gears[gearName].ownedAttcs[attcName] = true
		end

	elseif request == "equip" then

		-- server-side check: is item owned?
		local loadoutIdx = args[1]
		local itemType   = args[2]
		if itemType == "Gear" then
			local gearName = args[3]
			local gearType = args[4]

			if not dsReader.ownedQ(data, itemType, {gearName}) then
				return false, "The player hasn't owned "..gearName
			end

			data.loadouts[loadoutIdx][gearType] = gearName

		elseif itemType == "Attachment" then
			local gearName = args[3]
			local attcName = args[4]
			local attcType = args[5]

			if not dsReader.ownedQ(data, itemType, {gearName, attcName}) then
				return false, string.format("The player hasn't owned %s for %s", attcName, gearName)
			end

			data.loadouts[loadoutIdx].customizations[gearName].attcList[attcType] = attcName
		end
	end

	return true
end



-- money!!!!
------------------------------------------------------
-- defs
local mps = game:GetService("MarketplaceService")
local dss = game:GetService("DataStoreService")

-- 4 credit
local creditProducts = {} 
--[[= {
	[270789727] = {["creditInc"] = 2500},
	[270789935] = {["creditInc"] = 250},
	[270790291] = {["creditInc"] = 35000},
	[270790437] = {["creditInc"] = 750},
	[270790654] = {["creditInc"] = 77000},
	[270790824] = {["creditInc"] = 9000}
}--]]
for _, prod in ipairs(script:WaitForChild("Products"):GetChildren()) do
	creditProducts[tostring(prod:WaitForChild("ProductId").Value)] = {
		creditInc = prod:WaitForChild("CreditInc").Value
	}
end

local function isForCredit(productId)
	assert(type(productId) == "string")
	return creditProducts[productId] ~= nil
end

mps.ProcessReceipt = function(r)
	local plr = plrs:GetPlayerByUserId(r.PlayerId)
	local plrId = plr.UserId
	local purchaseId = r.PurchaseId
	assert(type(purchaseId) == "string")
	local productId  = tostring(r.ProductId)
	
	warn("process receipt received: ", plrId, purchaseId, productId, isForCredit(productId))
	
	if isForCredit(productId) then
		local processedInfo = sql.query(string.format([[
			select * from devproducts where 
				purchase_id = '%s' and user_id = %d
			]],
			purchaseId,
			plrId
		))
		local processedQ = processedInfo[1] ~= nil
		
		-- if processed before, ignore it
		if processedQ then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		
		-- if not, grant the credit
		local creditInc = creditProducts[productId].creditInc
		
		local suc, msg = pcall(function()
			sql.query(string.format([[
				update playerstats set
					credit        = credit + %d,
					acc_credit    = acc_credit + %d 
				where user_id = %d
				]],
				creditInc,
				creditInc,
				plr.UserId
			))
			sql.query(string.format([[
				insert into devproducts(
					purchase_id, user_id, user_name, purchase_time, product_id, 
					robux_spent, credit_gain
				)
				values(
					'%s', %d, '%s', current_timestamp, '%s',
					%d, %d 				
				)]],
				purchaseId, plrId, plr.Name, productId,
				r.CurrencySpent, creditInc
			))
		end)		
		if not suc then
			warn("An error occured while processing a product purchase")
			print("\t ProductId:", r.ProductId)
			print("\t Player:", plr.Name)
			print("\t Error message:", msg) -- log it to the output
			return Enum.ProductPurchaseDecision.NotProcessedYet	
		end
		
		local data = _G.plrData[plr.Name]
		data.credit = data.credit + creditInc
		dsEvent:FireClient(plr, "set credit", {data.credit})
	
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

