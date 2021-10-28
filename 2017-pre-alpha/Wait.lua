local m = {}

-- deal with player join & leave events

-- defs
local dss = game:GetService("DataStoreService")
local svMds = game.ServerStorage:WaitForChild("ServerModules")
--local dssMd = require(svMds:WaitForChild("dssmodule"))
local rep = game.ReplicatedStorage
local gm = rep:WaitForChild("GlobalModules")
local tableUtils = require(gm:WaitForChild("TableUtils"))
local levelExpMd = require(gm:WaitForChild("LevelExp"))
local dataRetrieved = false
local plrs = game.Players

local ser = game.ServerStorage
local sm  = ser:WaitForChild("ServerModules")
local sql = require(sm:WaitForChild("SQL"))

-- the data for this match, shared between all server scripts
_G.gameData = nil

-- the data table fetched directly from sql
_G.plrRawData = {}

-- personal data
_G.plrStats = {}

-- consts
local inStudio    = game.CreatorId == 0
local maxWaitTime = inStudio and 35 or 45

-- vars
local arrivedCnt = 0

local function waitData()
	repeat
		wait(0.05)
	until	dataRetrieved
end

--local receivedFrom = {}
plrs.PlayerAdded:connect(function(plr)
	-- playeradded	
	plr:LoadCharacter()
end)

-- constantly updating timestamp to tell the server list that
-- this server is alive
local function setServerHeartBeat()
	spawn(function()
		while true do
			sql.query(string.format("update rbxserver set heartbeat = current_timestamp where instanceid = '%s'", game.JobId))
			wait(20)
		end
	end)	
end

rep.Arrived.OnServerEvent:connect(function(plr, func, data)
	if rep.Stage.Value ~= "Wait" and func == "initData" then
		plr:Kick("Connection Timeout")
		return
	end	
	if func == "initData" then
		if dataRetrieved == false then
			dataRetrieved = true
						
			tableUtils.printTable(data)
			
			_G.gameData = {}
			local d = _G.gameData
			d.alphaInit= data.alphaInit
			d.betaInit = data.betaInit
			d.initPlrCnt = #d.betaInit + #d.alphaInit
			d.gamemode = data.gamemode
			d.plrData  = data.plrData
			d.placeDesc = data.placeDesc
			d.isVipRoom = data.isVipRoom
			d.vipServerId = data.vipServerId
			
			rep:WaitForChild("SharedVars"):WaitForChild("Gamemode").Value = d.gamemode
			rep.SharedVars.Gamemode.Value = d.gamemode
			
			warn("dataTable Retrieved From Clients, gamemode = ", rep.SharedVars.Gamemode.Value)
			
			sql.query(string.format([[insert into rbxserver(accesscode, placeid, instanceid, gamemode, open, lastquickjoin, description, alphacnt, betacnt, heartbeat, isviproom) 
				values('%s', %d, '%s', '%s', false, current_time, '%s', 0, 0, current_timestamp, %s);]], data.accessCode, game.PlaceId, game.JobId, d.gamemode, d.placeDesc, tostring(d.isVipRoom)))
			
			setServerHeartBeat()
		end
		
		local function getTeam(plr)
			warn("try to get team, plr =", plr.Name)
			for i, p in ipairs(_G.gameData.alphaInit) do
				if p == plr.Name then
					return game.Teams.Alpha
				end
			end
			for i, p in ipairs(_G.gameData.betaInit) do
				if p == plr.Name then 
					return game.Teams.Beta
				end
			end
		end	
		plr.Neutral = false
		plr.TeamColor = getTeam(plr).TeamColor
		
		spawn(function()
			wait(5)
			arrivedCnt = arrivedCnt + 1			
		end)
	else
		plr.Neutral = false
		plr.TeamColor = game.Teams[data.team].TeamColor
	
		-- update the new data to other clients
		for _, p in ipairs(plrs:GetPlayers()) do
			if p ~= plr then
				rep.Arrived:FireClient(p, "appendPlrData", {plr.Name, data.cust})		-- team is updated tru game.teams
			end
		end
		
		-- send the entire data to plr, not only cust data
		_G.gameData.plrData[plr.Name] = data.cust
		rep.Arrived:FireClient(plr, "setEntireData", {_G.gameData})
	end
	
	-- pull data from ds and load em into _G.plrStats = {}
	-- and share a few of em with the clients
	local rawData = sql.query(string.format([[select * from playerstats where user_id = %d]], plr.UserId))
	if rawData == nil then	-- tmp solution for the studio bug where u cant make http request in studio
		rawData = {}
	else
		rawData = rawData[1]
	end
	_G.plrRawData[plr.Name] = rawData
	_G.plrStats[plr.Name] = {
		oldExp        = rawData.exp,
		expInc        = 0,
		oldCredit     = rawData.credit,
		creditInc     = 0,
		damageInc     = 0,
		assistsInc    = 0,
		killsInc      = 0,
		headshotsInc  = 0,
		casualWinsInc = 0,
		capturesInc   = 0,
		assisters     = {},
		gears = {
			[_G.gameData.plrData[plr.Name].Primary.name] = {
				killsInc     = 0,
				headshotsInc = 0,
				expInc       = 0,
			},
			[_G.gameData.plrData[plr.Name].Secondary.name] = {
				killsInc     = 0,
				headshotsInc = 0,
				expInc       = 0,
			},
		}
	}
	local data = _G.plrStats[plr.Name]
	if data.oldExp == nil then data.oldExp = 0 end
	if data.oldCredit == nil then data.oldCredit = 0 end
	data.level = levelExpMd.lvl(data.oldExp)  	
	
	local stats = script.Stats:Clone()
	stats.Name  = "Stats"
	
	-- TODO: shared more values here
	stats.Exp.Value   = data.oldExp
	stats.Level.Value = data.level
	stats.Parent      = plr
	
	sql.query(string.format([[update rbxserver set %s = %d where instanceid = '%s';]], 
		plr.Team == game.Teams.Alpha and "alphacnt" or "betacnt", #plr.Team:GetPlayers(), game.JobId))
	
	local avatar  = Instance.new("StringValue")
	avatar.Value  = plrs:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	avatar.Name   = "Avatar"
	avatar.Parent = plr	
	
	if data.joinType == "quickJoin" then
		
	else

	end
end)

plrs.PlayerRemoving:connect(function(plr)
	if plr.Team then
		sql.query(string.format([[update rbxserver set %s = %d where instanceid = '%s';]], 
			plr.Team == game.Teams.Alpha and "alphacnt" or "betacnt", #plr.Team:GetPlayers(), game.JobId))
	else
		warn("the player about to leave doesnt belong to either team")
	end
end)

-- main
function m.main()
	waitData()
	local gameData = _G.gameData
	--m.setWeather(gameData.weather)

	rep.Stage.Value = "Wait"
	-- wait for players to arrive, with a maxWaitTime 
	for i = maxWaitTime, 1, -1 do
		wait(1)
		rep.SharedVars.HeliCounter.Value = i
		-- keep in mind that there's a 10 sec gap before arriveCnt is inscreased by 1
		warn(arrivedCnt, gameData.initPlrCnt)
		if arrivedCnt == gameData.initPlrCnt then		
			break
		end
	end
	-- wait end
	rep.SharedVars.HeliCounter.Value = 0
	rep.Stage.Value = "Wait End"
end

return m
