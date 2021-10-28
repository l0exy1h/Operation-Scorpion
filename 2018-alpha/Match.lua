local md = {}

-- defs
local rep = game.ReplicatedStorage
local sharedVars = rep:WaitForChild("SharedVars")
local fpsCoreMd = require(game.ServerScriptService:WaitForChild("FPSCore"))
local disGamemode = nil
local remote = rep:WaitForChild("Events"):WaitForChild("MainRemote")
local gm = rep:WaitForChild("GlobalModules")
local levelExpMd = require(gm:WaitForChild("LevelExp"))
local expConsts = levelExpMd
local errMd = require(gm:WaitForChild("ErrorHandling"))
local plrs = game.Players
local svMds = game.ServerStorage:WaitForChild("ServerModules")
local dssMd = require(svMds:WaitForChild("dssmodule"))
local dss = game:GetService("DataStoreService")

-- consts
local gamemodeMd = {}
for i, gm in ipairs(script:GetChildren()) do
	if gm:IsA("ModuleScript") then
		gamemodeMd[gm.Name] = require(gm)
	end
end

local function waitForOpeningScene()
	wait(14)
	warn("the server thinks the opening scene has ended")
end

local function setupFinalScreen()
	rep.Stage.Value = "Match FinalScreen"
	
	remote:FireAllClients("hideScoreBar")
	disGamemode.getFinalArrangement()
	remote:FireAllClients("setFinalScreenCam", {disGamemode.matchWinner})
	wait(15)			-- << final secs
	fpsCoreMd.killAll() -- classic scene stays
	wait(5)
	
	rep.Stage.Value = "Match End"
end

local function uploadExp()
	for i, plr in ipairs(plrs:GetChildren()) do
		if plr:FindFirstChild("Stats") then
			local dsstats = dss:GetDataStore("stats", plr.UserId)		
			local plrName = plr.Name
			local ds = _G.plrStats[plrName]

			if plr.Team == disGamemode.matchWinner then
				ds.casualWinsInc = 1
				dssMd.update("inc", plr.Name, "casualWins", 1)
			end

			-- PRE: creditInc should be 0
			-- credits related to the match performance		
			local rawCreditInc = disGamemode.getCreditInc(ds)
			local actualCreditInc = rawCreditInc * (1.08 ^ dssMd.updateMatchCntToday(plr, dsstats))
			warn("server:", plr, "has gained", actualCreditInc, "credits from this match. original:", rawCreditInc)
				
			-- credits due to leveling up
			ds.newExp = ds.oldExp + ds.expInc
			plr.Stats.Exp.Value = ds.newExp
			local newLevel = levelExpMd.lvl(ds.newExp)
			if newLevel > ds.level then
				ds.level = newLevel
				actualCreditInc = actualCreditInc + expConsts.levelUpCreditInc
				plr.Stats.Level.Value = newLevel
				dssMd.update("set", plr.Name, "level", ds.level)
			end
						
			-- update the unordered data store
			dssMd.setdata(dsstats, "inc", "exp", ds.expInc)
			dssMd.setdata(dsstats, "inc", "damage", ds.damageInc)
			dssMd.setdata(dsstats, "inc", "assists", ds.assistsInc)
			
			-- for the gears
			local gears = dssMd.getdata(dsstats, "gears")
			for gearName, gearData in pairs(_G.plrStats[plr.Name].gears) do
				gears[gearName].kills     = gears[gearName].kills + gearData.killsInc
				gears[gearName].headshots = gears[gearName].headshots + gearData.headshotsInc
				gears[gearName].exp   = gears[gearName].exp + gearData.expInc
				gears[gearName].level = levelExpMd.gearLevel(gears[gearName].exp) 
			end
			dssMd.setdata(dsstats, "set", "gears", gears)	
			

			-- update the ordered data store
			dssMd.update("inc", plr.Name, "credit", actualCreditInc)
			dssMd.update("inc", plr.Name, "kills", ds.killsInc)
			dssMd.update("inc", plr.Name, "headshots", ds.headshotsInc)
			dssMd.update("inc", plr.Name, "accCredit", actualCreditInc)
			dssMd.update("inc", plr.Name, "captures", ds.capturesInc)
		end
	end
end

local function setupInstaKill()
	for _, pt in ipairs(workspace:WaitForChild("Map"):WaitForChild("Rekt"):GetChildren()) do
		
		pt.Touched:connect(function(p)
			if p:IsDescendantOf(workspace.Characters) then
				for _, customChar in ipairs(workspace.Characters:GetChildren()) do
					if p:IsDescendantOf(customChar) then
						md.kill(plrs:FindFirstChild(customChar.Name))
						break
					end
				end
			end
		end)
		
	end
end

-- main
function md.main()
	game.ReplicatedStorage.Events.MainRemote:FireAllClients("matchBegin")
	waitForOpeningScene()
	
	setupInstaKill()	
	
	rep.Stage.Value = "Match"
	sharedVars.ScorpionWins.Value, sharedVars.ScorpionWins.Value = 0, 0
	
	disGamemode = gamemodeMd[sharedVars.Gamemode.Value]
	disGamemode.setup()
	
	uploadExp()	
	
	setupFinalScreen()
end

return md
