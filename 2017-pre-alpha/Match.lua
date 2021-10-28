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
--local dssMd = require(svMds:WaitForChild("dssmodule"))
local dss = game:GetService("DataStoreService")

local ser = game.ServerStorage
local sm  = ser:WaitForChild("ServerModules")
local sql = require(sm:WaitForChild("SQL"))
local http= game:GetService("HttpService")

local inStudio = game.JobId == ""

-- consts
local gamemodeMd = {}
for i, gm in ipairs(script:GetChildren()) do
	if gm:IsA("ModuleScript") then
		gamemodeMd[gm.Name] = require(gm)
	end
end

local function waitForOpeningScene()
	if rep:WaitForChild("Debug"):WaitForChild("DirectSpawn").Value == false then
		wait(14)
	end
	warn("the server thinks the opening scene has ended")
end

local function setupFinalScreen()
	rep.Stage.Value = "Match FinalScreen"
	
	--remote:FireAllClients("hideScoreBar")
	disGamemode.getFinalArrangement()
	remote:FireAllClients("setFinalScreen", {disGamemode.matchWinner})
	wait(15)			-- << final secs
	fpsCoreMd.killAll() -- classic scene stays
	wait(5)
	
	rep.Stage.Value = "Match End"
end

local function uploadExp()
	for i, plr in ipairs(plrs:GetChildren()) do
		if plr:FindFirstChild("Stats") then
			spawn(function()
				local plrName = plr.Name
				local userId = plr.UserId
				local ds = _G.plrStats[plrName]
				local raw = _G.plrRawData[plrName]
	
				if plr.Team == disGamemode.matchWinner then			
					sql.query(string.format("update playerstats set casual_wins = casual_wins + 1 where user_id = %d", userId))
				end
	
				-- PRE: creditInc should be 0
				-- credits related to the match performance		
				local rawCreditInc = disGamemode.getCreditInc(ds)
				local actualCreditInc = rawCreditInc-- * (1.08 ^ dssMd.updateMatchCntToday(plr, raw))
				warn("server:", plr, "has gained", actualCreditInc, "credits from this match. original:", rawCreditInc)
					
				-- credits due to leveling up
				ds.newExp = ds.oldExp + ds.expInc
				--plr.Stats.Exp.Value = ds.newExp
				local newLevel = levelExpMd.lvl(ds.newExp)
				if newLevel > ds.level then
					ds.level = newLevel
					actualCreditInc = actualCreditInc + expConsts.levelUpCreditInc
					plr.Stats.Level.Value = newLevel
				end
				
				-- for the gears
				local gears = raw.gears
				for gearName, gearData in pairs(_G.plrStats[plr.Name].gears) do
					gears[gearName].kills     = gears[gearName].kills + gearData.killsInc
					gears[gearName].headshots = gears[gearName].headshots + gearData.headshotsInc
					gears[gearName].exp   = gears[gearName].exp + gearData.expInc
					gears[gearName].level = levelExpMd.gearLevel(gears[gearName].exp) 
				end		
				
				sql.query(string.format([[
					update playerstats set
						level = %d,
						exp = exp + %d,
						damage = damage + %d,
						assists = assists + %d,
						credit = credit + %d,
						kills = kills + %d,
						headshots = headshots + %d,
						acc_credit = acc_credit + %d,
						captures = captures + %d,
						gears = '%s'
					where user_id = %d			
					]],
					ds.level,
					ds.expInc,
					ds.damageInc, 
					ds.assistsInc,
					actualCreditInc,
					ds.killsInc,
					ds.headshotsInc,
					actualCreditInc,
					ds.capturesInc,
					http:JSONEncode(gears),
					plr.UserId
				))
			end)
		end
	end
end

local function setupInstaKill()
	for _, pt in ipairs(workspace:WaitForChild("Map"):WaitForChild("Rekt"):GetChildren()) do
		pt.Touched:connect(function(p)
			if p:IsDescendantOf(workspace.Alive) then			-- on the server, all the char is in the alive
				for _, char in ipairs(workspace.Alive:GetChildren()) do
					if p:IsDescendantOf(char) then
						fpsCoreMd.kill(plrs:FindFirstChild(char.Name))
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
	sharedVars.AlphaWins.Value, sharedVars.AlphaWins.Value = 0, 0
	
	sql.query(string.format([[update rbxserver set open = true where instanceid = '%s']], game.JobId))
	
	disGamemode = gamemodeMd[sharedVars.Gamemode.Value]
	disGamemode.setup()
	
	if not inStudio then
		uploadExp()	
	end
	
	setupFinalScreen()
end

return md
