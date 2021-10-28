local md = {}

-- defs 
local rep = game.ReplicatedStorage
local sv = rep:WaitForChild("SharedVars")
local plrs = game.Players
local fpsCoreMd = require(game.ServerScriptService:WaitForChild("FPSCore"))	-- server side utils for fps
local events = rep:WaitForChild("Events")
local remote = events.MainRemote		-- for character replication
local mm = events:WaitForChild("MatchEvent") -- server side bindable, for exp
local matchRemote = rep.Events:WaitForChild("MatchRemote") -- for gamemodes

local gm = rep.GlobalModules
local sd = require(gm.ShadedTexts)
local invade = require(gm:WaitForChild("Invade"))
local sharedUtils = require(gm:WaitForChild("SharedUtils"))

local ser = game.ServerStorage
local sm  = ser:WaitForChild("ServerModules")
local sql = require(sm:WaitForChild("SQL"))

local audios = rep:WaitForChild("Audios")

--local loc  = workspace:WaitForChild("Map"):WaitForChild("BombSite")	-- a folder containing all the locations

-- consts
local inStudio = game.JobId == ""

local bo = 5
local maxWins = (bo + 1) / 2

-- vars
md.matchWinner = nil
local timer = -1
local atk = nil
local def = nil
local bombPlanted = false
local bombPlantedNew = false	-- used to update bombPlanted
local bombDefused = false
local bombDefusedNew = false  -- used to update bombDefused
local bombDetonated = false
local hasBomb = {}

-- bomb spawn and destroy
-----------------------------------------
local function spawnBomb(pos)
	if sv.Bomb.Value then
		warn("spawnBomb: previous bomb not destroyed, destroy it now")
		sv.Bomb.Value:Destroy()
	end
	local bomb = script:WaitForChild("Bomb"):clone()
	local simDrop = sharedUtils.downWardRayCasting(pos)
	bomb:SetPrimaryPartCFrame(CFrame.new(simDrop + Vector3.new(0, bomb.PrimaryPart.Size.Z / 2, 0)) * CFrame.fromOrientation(math.pi/2, 0, 0))
	bomb.Parent = workspace.Ignore
	return bomb
end

local function detonateBomb()
	
	-- sound holder serves as a temp block bc the bomb will be destroyed
	if workspace.Ignore:FindFirstChild("BombSoundHolder") then
		workspace.Ignore.BombSoundHolder:Destroy()
	end
	local soundHolder = script.BombSoundHolder:Clone()
	soundHolder.CFrame = sv.Bomb.Value:GetPrimaryPartCFrame()
	soundHolder.Parent = workspace.Ignore
	
	-- play sound
	spawn(function()
		local sound = audios.BombDetonated:clone()
		sound.Parent = soundHolder
		wait(0.1)
		sound:Play()
		sound:Stop()
		wait(0.1)
		sound:Play()
	end)
	
	-- detonate
	local function isDetonationEfx(v)
		return v:IsA("ParticleEmitter") and string.sub(v.Name, 1, 3) == "Exp"
	end
	for _, v in ipairs(sv.Bomb.Value.MeshPart:GetChildren()) do
		if isDetonationEfx(v) then
			v.Parent = soundHolder
		end
	end
	spawn(function()
		for _, v in ipairs(soundHolder:GetChildren()) do
			if isDetonationEfx(v) then
				v.Enabled = true
			end
		end
		wait(3)
		for _, v in ipairs(soundHolder:GetChildren()) do
			if isDetonationEfx(v) then
				v.Enabled = false
			end
		end
	end)
	
	fpsCoreMd.killAll()
	
	sv.Bomb.Value:Destroy()
	sv.Bomb.Value = nil
	matchRemote:FireAllClients("bombDetonated", {sv.BombPlanter.Value})
	mm:Fire("bombDetonated", {sv.BombPlanter.Value})
end

-- planting and defusing
------------------------------------------
local plantingCancelled = {}
local function cancelPlanting(plr)
	plantingCancelled[plr.Name] = true
	warn(string.format("%s has cancelled planting", plr.Name))	
end
local defusingCancelled = {}
local function cancelDefusing(plr)
	defusingCancelled[plr.Name] = true
	warn(string.format("%s has cancelled defusing", plr.Name))
end
local function listenToPlantingAndDefusing()
	
	-- helper functio]n to verify whether the player can plant
	local function canPlant(plr, site)
		return fpsCoreMd.isAlive(plr) 
			and plr.Team and plr.Team == atk and atk
			and not bombPlantedNew and not bombPlanted
			and sharedUtils.inShape(plr.Character.HumanoidRootPart, site)
			and hasBomb[plr.Name] == true
	end
	local function plant(plr, site)
		bombPlantedNew = true
		sv.BombPlantedSite.Value = site
		sv.Bomb.Value = spawnBomb(plr.Character.HumanoidRootPart.Position)
		
		sv.Bomber.Value = nil
		hasBomb[plr.Name] = false
		
		warn(string.format("server: bomb planted at %s by %s", site.Name, plr.Name))
		matchRemote:FireAllClients("bombPlanted", {plr, site}) 
		mm:Fire("bombPlanted", {plr, site})
		
		sv.BombPlanter.Value = plr
		
		sharedUtils.playServerSound(audios.BombPlantedVoice)
		
		-- bomb beeping sound & flare
		audios.BombBeep:Clone().Parent = sv.Bomb.Value
		local bomb = sv.Bomb.Value
		local function beepFlareAsync()
			spawn(function()
				bomb.BeepContainer.BeepParticle.Enabled = true
				wait(0.2)
				bomb.BeepContainer.BeepParticle.Enabled = false
			end)
		end
		spawn(function()
			local function beep(times)
				print("beep: times = ", times)
				spawn(function()
					for i = 1, times, 1 do
						bomb.BombBeep:Play()
						beepFlareAsync()
						wait(1 / times)
					end
				end)
			end
			local currRound = sv.Round.Value
			for i = 1, math.ceil(invade.defusePhaseTL), 1 do
				if bombDefused or bombDefusedNew or sv.Round.Value ~= currRound then 
					break
				end
				print(bomb:GetFullName())
				if i < invade.defusePhaseTL - 5 then
					bomb.BombBeep:Play()
					beepFlareAsync()
				else
					beep(math.max(1, math.ceil(8 - invade.defusePhaseTL + i)))
				end
				wait(1)
			end
		end)
	end
		
	local function canDefuse(plr)
		warn("canDefuse: ", fpsCoreMd.isAlive(plr), plr.Team and plr.Team == def and def, bombPlanted, not bombDefused and not bombDefusedNew, sharedUtils.withinCharDistance(plr, sv.Bomb.Value, invade.maxBombDefuseRange))
		return fpsCoreMd.isAlive(plr)
			and plr.Team and plr.Team == def and def
			and bombPlanted
			and not bombDefused and not bombDefusedNew
			and sharedUtils.withinCharDistance(plr, sv.Bomb.Value, invade.maxBombDefuseRange)
	end
	local function defuse(plr)
		bombDefusedNew = true
		warn(string.format("bomb defused by %s", plr.Name))
		matchRemote:FireAllClients("bombDefused", {plr}) 
		mm:Fire("bombDefused", {plr}) 
		
		sharedUtils.playServerSound(audios.BombDefusedVoice)
	end
	
	matchRemote.OnServerEvent:connect(function(caller, func, args)
		if func == "requestInitiatingPlanting" then
			
			local site = args[1]
			local round = sv.Round.Value
			plantingCancelled[caller.Name] = false
			
			if canPlant(caller, site) then
				warn(string.format("%s starts planting at %s", caller.Name, site.Name))
				for _, attacker in ipairs(atk:GetPlayers()) do
					matchRemote:FireClient(attacker, "plantingInitiated", {caller, site})
				end
				
				-- bomb planting sound
				local sound = audios.BombPlanting:Clone()
				if caller.Character.Torso:FindFirstChild("BombPlanting") then
					caller.Character.Torso.BombPlanting:Destroy()
				end
				sound.Parent = caller.Character.Torso
				sound.PlaybackSpeed = sound.TimeLength / invade.plantTime 
				sound:Play()
				
				local plantingSt = tick()
				while wait(0.1) and not plantingCancelled[caller.Name] and not bombPlantedNew do
					local t = tick() - plantingSt
					if t > invade.plantTime then
						if canPlant(caller, site) and not plantingCancelled[caller.Name]	
							and md.roundWinner == nil and round == sv.Round.Value then			-- still the same round
							plant(caller, site)
						end		
						break
					end
				end
				
				if not bombPlantedNew then 	-- planting cancelled
					sound:Stop()
					for _, attacker in ipairs(atk:GetPlayers()) do
						matchRemote:FireClient(attacker, "plantingCancelled", {caller, site})
					end
				end
			end
			
		elseif func == "cancelPlanting" then
			cancelPlanting(caller)
			
		elseif func == "requestInitiatingDefusing" then
			
			local round = sv.Round.Value
			defusingCancelled[caller.Name] = false
			
			if canDefuse(caller) then
				warn(string.format("%s starts defusing", caller.Name))
				for _, defender in ipairs(def:GetPlayers()) do
					matchRemote:FireClient(defender, "defusingInitiated", {caller})
				end		
				
				local defusingSt = tick()
				while wait(0.1) and not defusingCancelled[caller.Name] and not bombDefusedNew and not bombDetonated do
					local t = tick() - defusingSt
					if t > invade.defuseTime then
						if canDefuse(caller) and not defusingCancelled[caller.Name]
							and md.roundWinner == nil and round == sv.Round.Value then
							defuse(caller)
						end
						break
					end
				end
				
				if not bombDefusedNew then	-- defusing cancelled
					for _, defender in ipairs(def:GetPlayers()) do
						matchRemote:FireClient(defender, "defusingCancelled", {caller})
					end
				end 
			end
	
		elseif func == "cancelDefusing" then
			cancelDefusing(caller)
		end
	end)
		
	-- debug features, plant / defuse bombs directly
	script.Debug.Event:Connect(function(func, args)
		if func == "plant" then
			local plr = plrs:GetPlayers()[1]
			local site = workspace.Map.BombSite[args[1]]
			plant(plr, site)
		elseif func == "defuse" then
			local plr = plrs:GetPlayers()[1]
			defuse(plr)
		end
	end)
end

-- bomb drop and pick up
-------------------------------------
repeat
	wait(0.1)
until _G.lastAlivePos
local function handleBombDropAndPickUp()
	
	-- dropping
	-----------------------------------------------
	local function dropBomb(plr)
		local bombDropPos = nil
		if fpsCoreMd.isAlive(plr) then
			print("drop bomb, plr alive")
			bombDropPos = plr.Character.HumanoidRootPart.Position
		elseif _G.lastAlivePos[plr.Name] ~= nil then
			print("drop bomb, plr dead, lastAlivePos Found")
			bombDropPos = _G.lastAlivePos[plr.Name]
		else
			warn(string.format("%s not alive and last alive pos is nil, use the spawn location as drop location", plr.Name))
			bombDropPos = workspace.Map.BombSpawn[plr.Team.Name].Position
		end
		
		hasBomb[plr.Name] = false
		sv.Bomb.Value = spawnBomb(bombDropPos)
		sv.Bomber.Value = nil
		cancelPlanting(plr)
		warn(string.format("%s has dropped the bomb", plr.Name))
		
		matchRemote:FireAllClients("bombDropped", {plr}) 
	end
	
	game.Players.PlayerRemoving:connect(function(leaver)
		if hasBomb[leaver.Name] then
			dropBomb(leaver)
		end
		cancelDefusing(leaver)
	end)
	events:WaitForChild("PlayerRekt").Event:connect(function(plr)
		if hasBomb[plr.Name] then
			dropBomb(plr)		-- included cancel planting
		end
		cancelDefusing(plr)
	end)
	matchRemote.OnServerEvent:connect(function(caller, func, args)
		if func == "requestDroppingBomb" then
			if hasBomb[caller.Name] then
				dropBomb(caller)
			end
		end
	end)
	
	-- picking up
	matchRemote.OnServerEvent:connect(function(caller, func, args)
		if func == "requestPickingUpBomb" then
			print("server:", fpsCoreMd.isAlive(caller), caller.Team == atk, hasBomb[caller.Name] ~= true, sv.Bomb.Value ~= nil, bombPlanted == false, sharedUtils.withinCharDistance(caller, sv.Bomb.Value, invade.maxBombPickUpDistance))
			if fpsCoreMd.isAlive(caller)
				and caller.Team == atk
				and hasBomb[caller.Name] ~= true
				and sv.Bomb.Value ~= nil
				and bombPlanted == false
				and sharedUtils.withinCharDistance(caller, sv.Bomb.Value, invade.maxBombPickUpDistance) then
				
				sv.Bomb.Value:Destroy()
				sv.Bomb.Value = nil
				sv.Bomber.Value = caller
				hasBomb[caller.Name] = true
				warn(string.format("%s has picked up the bomb", caller.Name))
				
				matchRemote:FireAllClients("bombPickedUp", {caller}) 
			end
		end
	end)
end

local function putFlareInSites()
	for _, site in ipairs(workspace.Map.BombSite:GetChildren()) do
		site.Transparency = 1
		local flare = script.Flare:Clone()
		flare:SetPrimaryPartCFrame()
		flare.Parent = site
	end
end

-- main logic
-----------------------------------------
function md.setup()
	md.matchWinner = nil
	
	listenToPlantingAndDefusing()
	handleBombDropAndPickUp()
	putFlareInSites()
	
	sv.Round.Value = 1
	while md.matchWinner == nil and sv.Round.Value <= bo do
		
		-- init values
		md.roundWinner = nil
		
		bombPlanted = false
		bombDefused = false	
		bombDetonated = false
		bombPlantedNew = false
		bombDefusedNew = false
		sv.BombPlantedSite.Value = nil
		if sv.Bomb.Value then
			sv.Bomb.Value:Destroy()
		end
		sv.Bomb.Value = nil
		sv.BombPlanter.Value = nil
		
		-- assign sides
		if sv.Round.Value == 1 then 	
			-- first round, randomly assign sides
			-- change this back!
			local rand = math.random(0, 1)
			rand = 0
			if rand == 0 then
				atk = game.Teams.Alpha
				def = game.Teams.Beta
			else
				def = game.Teams.Alpha
				atk = game.Teams.Beta
			end
		else	
			-- not first round, swap sides
			local tmp = atk
			atk = def
			def = tmp
		end
		
		-- announce the sides
		sv.Atk.Value = atk
		sv.Def.Value = def
		sv.TeamSided.Value = true
		matchRemote:FireAllClients("sideSwitched", {
			Atk = sv.Atk.Value,
			Def = sv.Def.Value,
			[sv.Atk.Value.Name] = "Atk",
			[sv.Def.Value.Name] = "Def",
		})
		
		-- assign bomber
		--[[for _, plr in ipairs(def:GetPlayers()) do
			hasBomb[plr.Name] = false
		end
		local bomberCandidates = {}
		for _, plr in ipairs(atk:GetPlayers()) do
			hasBomb[plr.Name] = false
			if fpsCoreMd.isAlive(plr) then
				bomberCandidates[#bomberCandidates + 1] = plr
			end
		end
		local firstBomber = bomberCandidates[math.random(1, #bomberCandidates)]
		hasBomb[firstBomber.Name] = true
		sv.Bomber.Value = firstBomber	-- remember to verify hasBomb when attempting to plant--]]
		-- spawn the bomb on the ground
		sv.Bomb.Value = spawnBomb(workspace.Map.Spawn["Atk"].Position)
		sv.Bomber.Value = nil
		
		-- spawn all players
		remote:FireAllClients("resetTVnGlass")
		remote:FireAllClients("clearBodies")
		fpsCoreMd.spawnAll()
		sv.AlphaTotalLives.Value = #game.Teams.Alpha:GetPlayers()
		sv.BetaTotalLives.Value  = #game.Teams.Beta:GetPlayers()
		sv.AlphaLives.Value      = sv.AlphaTotalLives.Value
		sv.BetaLives.Value       = sv.BetaTotalLives.Value
		fpsCoreMd.unlockAll()		
		
		-- enter the plantPhase (the 1st phase)
		local plantPhaseSt, t = tick(), 0
		while t <= invade.plantPhaseTL do		-- todo: check the condition here
			wait(0.5)
			t = tick() - plantPhaseSt
			sv.FPSTimer.Value   = math.floor(invade.plantPhaseTL - t)
			sv.AlphaLives.Value = fpsCoreMd.getAlivePlayersCnt(game.Teams.Alpha)
			sv.BetaLives.Value  = fpsCoreMd.getAlivePlayersCnt(game.Teams.Beta)
			local atkLives = fpsCoreMd.getAlivePlayersCnt(atk)
			local defLives = fpsCoreMd.getAlivePlayersCnt(def)			
			
			if bombPlantedNew and not bombPlanted then
				bombPlanted = true
				
				-- enter defusePhase (the 2nd phase)
				local defusePhaseSt = tick()
				t = 0
				while t <= invade.defusePhaseTL do
					t = tick() - defusePhaseSt
					sv.FPSTimer.Value = math.floor(invade.defusePhaseTL - t)
					sv.AlphaLives.Value = fpsCoreMd.getAlivePlayersCnt(game.Teams.Alpha)
					sv.BetaLives.Value  = fpsCoreMd.getAlivePlayersCnt(game.Teams.Beta)
					atkLives = fpsCoreMd.getAlivePlayersCnt(atk)
					defLives = fpsCoreMd.getAlivePlayersCnt(def)
					
					if bombDefusedNew and not bombDefused then
						bombDefused = true
						md.win(def)
						break
					else
						if not inStudio then
							if defLives == 0 then
								md.win(atk)
								break
							end
						end
					end	
					
					wait(0.5)
				end
				
				if not bombDefused and md.roundWinner == nil then
					bombDetonated = true
					detonateBomb()
					md.win(atk)
				end
				
				break 
			else
				
				if not inStudio then
					if atkLives == 0 then
						md.win(def)
						break
					elseif defLives == 0 then
						md.win(atk)
						break
					end
				end
			end			
		end
		
		if not bombPlanted and md.roundWinner == nil then
			md.win(def)
		end
				
		-- round intermission
		fpsCoreMd.lockAll()
		rep.Stage.Value = "Match Intermission"
		fpsCoreMd.announceWinner(md.roundWinner, md.matchWinner)
		wait(15)		-- 19 = round intermission secs
		fpsCoreMd.killAll()
		wait(4)
		
		if md.matchWinner then 
			wait(5)
			break 
		end
		
		rep.Stage.Value = "Match"
	end
end

-- sounds
-----------------------------------------



-- standard helper functions for a gamemode 
-----------------------------------------

function md.incRound()
	sv.Round.Value = sv.Round.Value + 1 
end

-- set the roundWinner and matchWinner (if possible)
function md.win(team)
	if team == nil then -- draw
		
	else
		md.roundWinner = team
		mm:Fire("roundWinner", {team})
		
		md.incRound()
		sv[team.Name.."Wins"].Value = sv[team.Name.."Wins"].Value + 1
		if sv[team.Name.."Wins"].Value >= maxWins then
			md.matchWinner = team
			mm:Fire("matchWinner", {team})
		end
		if sv[team.Name.."Wins"].Value == maxWins - 1 then
			sql.query(string.format([[update rbxserver set open = false where instanceid = '%s']], game.JobId))
		end
	end
	
	warn("round end, round winner =", md.roundWinner)
	
	-- check if a team contains no players
	if fpsCoreMd.getPlayersCnt(game.Teams.Alpha) == 0 and not inStudio then
		md.matchWinner = game.Teams.Beta
	end
	if fpsCoreMd.getPlayersCnt(game.Teams.Beta) == 0 and not inStudio then
		md.matchWinner = game.Teams.Alpha
	end
end

function md.getFinalArrangement()
	local winners = md.matchWinner:GetPlayers()
	table.sort(winners, function(x, y)
		return x.Stats.Kills.Value > y.Stats.Kills.Value
	end)
	for i, plr in ipairs(winners) do
		local block = workspace.Map.Final[tostring(i)]
		fpsCoreMd.spawn(plr, "precise", block.CFrame)
		local gui = block.gui.BillboardGui
		local fr  = gui.Frame
		fr.Plr.text.TextColor3 = md.matchWinner.TeamColor.Color
		sd.setProperty(fr.Plr, "Text", plr.Name)
		sd.setProperty(fr.P1, "Text", string.format("Score: %d", plr.Stats.ExpInc.Value))
		sd.setProperty(fr.P2, "Text", "")
		gui.Enabled = true
	end
end

function md.getCreditInc(ds)
	return ds ~= nil and ds.expInc / 50 or 0	
end

return md
