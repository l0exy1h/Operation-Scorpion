local m = {}

-- defs
local dss = game:GetService("DataStoreService")
local svMds = game.ServerStorage:WaitForChild("ServerModules")
local dssMd = require(svMds:WaitForChild("dssmodule"))
local rep = game.ReplicatedStorage
local gm = rep:WaitForChild("GlobalModules")
local levelExpMd = require(gm:WaitForChild("LevelExp"))
local dataRetrieved = false
local plrs = game.Players

-- the data for this match, shared between all server scripts
_G.gameData = nil

-- personal data
_G.plrStats = {}

-- consts
local inStudio = game.CreatorId == 0
local maxWaitTime = inStudio and 35 or 35

-- vars
local arrivedCnt = 0

-- const funcs
local function getTeam(plr)
	warn("try to get team, plr =", plr.Name)
	for i, p in ipairs(_G.gameData.scorpion) do
		if p == plr.Name then
			return game.Teams.Scorpion
		end
	end
	for i, p in ipairs(_G.gameData.skull) do
		if p == plr.Name then 
			return game.Teams.Skull
		end
	end
end

local function waitData()
	repeat
		wait(0.05)
	until	dataRetrieved
end

local receivedFrom = {}
rep.Arrived.OnServerEvent:connect(function(plr, data)
	if receivedFrom[plr.Name] == nil then
		receivedFrom[plr.Name] = true
		
		if dataRetrieved == false then
			dataRetrieved = true
			_G.gameData = data		
			
			rep:WaitForChild("SharedVars"):WaitForChild("Gamemode").Value = _G.gameData.gamemode
			warn("dataTable Retrieved From Clients, gamemode = ", rep.SharedVars.Gamemode.Value)
			warn("scorpions: ")
			for _, plr in pairs(_G.gameData.scorpion) do
				warn(plr)
			end
			warn("skulls: ")
			for _, plr in pairs(_G.gameData.skull) do
				warn(plr)
			end
		end
	else
		warn("received a second time from plr", plr, "must be a hacker")
	end
end)

-- plr list handler
plrs.PlayerAdded:connect(function(plr)
	plr:LoadCharacter()
	waitData()	
	
	if rep.Stage.Value ~= "Wait" then
		plr:Kick("Connection Timeout")
	end
	if getTeam(plr) == nil and inStudio == false then
		plr:Kick("Invalid Request")
	end	
	
	-- pull data from ds and load em into _G.plrStats = {}
	-- and share a few of em with the clients
	local unorderedDs = dss:GetDataStore("stats", plr.UserId)
	_G.plrStats[plr.Name] = {
		oldExp        = unorderedDs:GetAsync("exp"),
		expInc        = 0,
		oldCredit     = unorderedDs:GetAsync("credit"),
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
	data.level = levelExpMd.lvl(data.oldExp)  	
	
	local stats = script.Stats:Clone()
	stats.Name  = "Stats"
	
	-- TODO: shared more values here
	stats.Exp.Value   = data.oldExp
	stats.Level.Value = data.level
	stats.Parent      = plr
	
	plr.Neutral   = false
	plr.TeamColor = getTeam(plr).TeamColor
	
	local waitTime = 15

	wait(10)
	arrivedCnt = arrivedCnt + 1
end)

function m.setWeather(ln)
	local lf = game.ReplicatedStorage.LightingSettings:FindFirstChild(ln)
	if lf then
		for i,v in ipairs(game.Lighting:GetChildren()) do
			if v.Name:find("Map") then
				v:Destroy()
			end
		end
		local sky = lf.Sky:clone()
		sky.Name = "Map_Sky"
		sky.Parent = game.Lighting
		for i,v in ipairs(lf.Shaders:GetChildren()) do
			local sh = v:clone()
			sh.Name = "Map_"..v.Name
			sh.Parent = game.Lighting
		end
		
		local ls = lf.Lighting
		game.Lighting.Ambient = ls.Ambient.Value
		game.Lighting.Brightness = ls.Brightness.Value
		game.Lighting.ClockTime = ls.ClockTime.Value
		game.Lighting.ColorShift_Bottom = ls.ColorShift_Bottom.Value
		game.Lighting.ColorShift_Top = ls.ColorShift_Top.Value
		game.Lighting.FogColor = ls.FogColor.Value
		game.Lighting.FogEnd = ls.FogEnd.Value
		game.Lighting.FogStart = ls.FogStart.Value
		game.Lighting.GeographicLatitude = ls.GeographicLatitude.Value
		game.Lighting.OutdoorAmbient = ls.OutdoorAmbient.Value
	else
		warn(string.format("couldn't find the configuration for lighting type: %s", ln))
	end
end

-- main
function m.main()
	waitData()
	local gameData = _G.gameData
	m.setWeather(gameData.weather)
	
	rep.Stage.Value = "Wait"
	-- wait for players to arrive, with a maxWaitTime 
	for i = maxWaitTime, 1, -1 do
		wait(1)
		rep.SharedVars.HeliCounter.Value = i
		-- keep in mind that there's a 10 sec gap before arriveCnt is inscreased by 1
		if arrivedCnt == gameData.plrCnt then		
			break
		end
	end
	-- wait end
	rep.SharedVars.HeliCounter.Value = 0
	rep.Stage.Value = "Wait End"
end

return m
