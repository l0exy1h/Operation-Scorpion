local md = {}

-- server side fps core module
-- for spawning, killing, and gamemodes

-- defs
local plrs = game.Players
local rep = game.ReplicatedStorage
local events = rep:WaitForChild("Events")
local remote = events.MainRemote
local mm = events:WaitForChild("MatchEvent") -- server side bindable, for exp
local gm = rep:WaitForChild("GlobalModules")
local sv = rep:WaitForChild("SharedVars")

local dsEnabled = true
local function waitForDsModule()
	while _G.plrStats == nil do wait() end
	return _G.plrStats
end

-- alive-related
--------------------------------
function md.isAlive(plr)
	return plr.Character and plr.Character.Parent and plr.Character.Parent == workspace.Alive and plr.Character:FindFirstChild("HumanoidRootPart") ~= nil
end
function md.getAlivePlayersCnt(team)
	local ret = 0
	if team == nil then
		for _, plr in ipairs(plrs:GetPlayers()) do
			if md.isAlive(plr) then
				ret = ret + 1
			end
		end
	else
		for _, plr in ipairs(team:GetPlayers()) do
			if md.isAlive(plr) then
				ret = ret + 1
			end
		end
	end
	return ret
end
function md.getPlayersCnt(team)
	if team == nil then
		return #plrs:GetPlayers()
	else
		return #team:GetPlayers()
	end
end

-- insta kill
----------------------------------


-- stats resetting
----------------------------------
function md.hasStats(plr, property)
	return plr:FindFirstChild("Stats") and plr.Stats:FindFirstChild(property)
end
function md.resetAmmo(plr)
	remote:FireClient(plr, "resetAmmo")
end
function md.resetHealth(plr)
	if md.hasStats(plr, "Health") then
		plr.Stats.Health.Value = 100
	end
	remote:FireClient(plr, "resetHealth")
end

-- spawn and teleportation
------------------------------------
local function waitForTeamAssigned(plr)
	repeat
		wait(0.25)
	until plr.Team
end
local function getSide(team)
	if sv.Atk.Value == team then
		return "Atk"
	elseif sv.Def.Value == team then
		return "Def"
	else
		error(string.format("Team %s is neither atk nor def", team.Name))
	end
end
function md.teleport(plr, teleOpt, pos)
	if teleOpt == nil or (teleOpt ~= "precise" and teleOpt ~= "random") then
		error("argument error: ", plr, teleOpt, pos)
	end
	
	local randomOffset
	if teleOpt == "precise" then
		randomOffset = Vector3.new(0, 0, 0)
	elseif teleOpt == "random" then
		randomOffset = Vector3.new( (math.random()-0.5)*2*5, 0, (math.random()-0.5)*2*5 )	
	end
	
	if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
		if pos then
			plr.Character.HumanoidRootPart.CFrame = pos + randomOffset
		else
			waitForTeamAssigned(plr) 
			local gamemode = sv.Gamemode.Value
			local spawnName = gamemode == "Invade" and getSide(plr.Team) or plr.Team.Name
			plr.Character.HumanoidRootPart.CFrame = workspace.Map.Spawn[spawnName].CFrame + randomOffset
		end
	else
		warn(string.format("fpscore.teleport: character or hrp not found for %s", plr.Name))
	end
end
function md.teamSpawnDead(team, teleOpt, pos)
	for _, plr in ipairs(team:GetPlayers()) do
		if not md.isAlive(plr) then
			md.spawnAsync(plr, teleOpt, pos)
			md.unlock(plr)
		end 
	end
end
function md.spawn(plr, teleOpt, pos)
	if plr.Character.Parent == workspace.Alive then
		-- reset ammo
		md.resetAmmo(plr)
		md.resetHealth(plr)
		md.teleport(plr, teleOpt, pos)
	else
		md.teleport(plr, teleOpt, pos)	
		plr.Character.Parent = workspace.Alive
	
		if plr:WaitForChild("Stats") then
			plr.Stats.Health.Value = 100
		end
	end
end
function md.spawnAsync(plr, teleOpt, pos)
	spawn(function()
		md.spawn(plr, teleOpt, pos)				
	end)
end
function md.spawnAll()
	for _, plr in ipairs(plrs:GetPlayers()) do
		md.spawnAsync(plr, "random")
	end
end

--[[
function md.spawnR6(plr)	-- outdated, now the char should be alive all the time
	plr:LoadCharacter()
end
--]]

-- lock/unlock control
-----------------------------------------
function md.lock(plr)		-- use remote events!!
	remote:FireClient(plr, "lock")
end
function md.lockAll()
	for _, plr in ipairs(plrs:GetPlayers()) do
		md.lock(plr)
	end
end
function md.unlock(plr)
	remote:FireClient(plr, "unlock")
end
function md.unlockAll()
	for _, plr in ipairs(plrs:GetPlayers()) do
		md.unlock(plr)
	end
end

-- kill
---------------------------------------------
function md.kill(plr)
	if md.isAlive(plr) then
		--remote:FireAllClients("changeHealth", {plr.Name, 0})
		--plr.Stats.Health.Value = 0
		plr.Character.Parent = workspace.Ragdolls
		local plrStats = waitForDsModule()
		plrStats[plr.Name].assisters = {}
	end
end
function md.killAsync(plr)
	spawn(function()
		md.kill(plr)
	end)
end
function md.killAll()
	for _, plr in ipairs(plrs:GetPlayers()) do
		md.killAsync(plr)
	end
end

-- for gamemodes
--------------------------------------------
function md.announceWinner(roundWinner, matchWinner)
	remote:FireAllClients("roundEnd", {roundWinner, matchWinner})
end


-- replication for procedual animation
-- and health system
---------------------------------------------
local validPath = {
	["equipment.goal"]     = true,
	["scared"]             = true,
	["server.aim"]         = true,
	["server.angleX"]      = true,
	["server.angleY"]      = true,
	["server.cover"]       = true,
	["server.flashlight"]  = true,
	["server.freeP"]       = true,
	["server.freeX"]       = true,
	["server.freeY"]       = true,
	["server.lean"]        = true,
	["server.nightVision"] = true,
	["server.position"]    = true,
	["server.reload"]      = true,
	["server.run"]         = true,
	["server.stance"]      = true,
	["server.velocity"]    = true,
	["shoot.shoot"]        = true,
	["walk.recover"]       = true,
	["server.jump"]        = true,
}
local function verifyPath(path)
	return validPath[path] == true
end

local function verifyChangeHealth(plr, func, args)
	-- todo: figure out the position of the player and check the ray
	return args[4] == Ray.new(Vector3.new(1, 2, 3), Vector3.new(4, 5, 6))
end
--
-- consts for progression
local expConsts = require(gm:WaitForChild("LevelExp"))

_G.lastAlivePos = {}

-- @pre: humanoidrootpart
spawn(function()
	while wait(0.2) do
		for _, plr in ipairs(plrs:GetPlayers()) do
			if md.isAlive(plr) then
				_G.lastAlivePos[plr.Name] = plr.Character.HumanoidRootPart.Position
			end
		end
	end
end)
function md.kill(victim)
	if md.isAlive(victim) then
		_G.lastAlivePos[victim.Name] = victim.Character.HumanoidRootPart.Position
		victim.Character.Parent = workspace.Ragdolls
		events:WaitForChild("PlayerRekt"):Fire(victim)
	else
		warn(string.format("fpscore.kill: %s is not alive", victim.Name))
	end
end
local function changeHealth(attacker, attackerName, victimName, healthDelta, gearName)
	local plrStats = waitForDsModule()
	local attackerStats = plrStats[attackerName]
	local victimStats = plrStats[victimName]

	local victim = plrs:FindFirstChild(victimName)
	if victim 
		and victim.Team ~= attacker.Team
		and md.isAlive(victim) and md.isAlive(attacker) then
		
		local orginal = victim.Stats.Health.Value
		victim.Stats.Health.Value = victim.Stats.Health.Value + healthDelta
		local current = victim.Stats.Health.Value

		remote:FireAllClients("changeHealth", {victimName, current})
		victim.Stats.Health.Value = current
		
		-- the victim is killed
		if orginal >= 0.01 and current < 0.01 then
			md.kill(victim)
			mm:Fire("killing", {attacker, victim, gearName, healthDelta})
			
		-- the victim is still alive, count as assist
		else
			-- check not on the list
			local onList = false
			for _, assistData in ipairs(victimStats.assisters) do
				local assisterName = assistData[1]
				local assisterGearName = assistData[2]
				if assisterName == attackerName and assisterGearName == gearName then
					onList = true
				end
			end
			if not onList then
				table.insert(victimStats.assisters, {attackerName, gearName})
			end 
		end

		attackerStats.damageInc = attackerStats.damageInc - healthDelta	-- health Delta is negative
	end
end

function md.init()
	remote.OnServerEvent:connect(function(plr, func, args)
		if func == "SpawnR6" then
			error("Spawn R6 is deprecated now")
			--md.spawnR6(plr)
		elseif func == "toggleAlive" then
			if md.isAlive(plr) then
				warn(string.format("%s suicides", plr.Name))
				md.kill(plr)
				if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
					plr.Character:FindFirstChild("HumanoidRootPart").CFrame = workspace.Collector.SpawnLocation.CFrame
				end
			else
				warn(string.format("%s spawns via toggleAlive", plr.Name))
				md.spawn(plr, "random")
			end
		elseif func == "changeHealth" then
			local victimName, healthDelta, gearName = args[1], args[2], args[3]
			local attackerName = plr.Name

			if verifyChangeHealth(plr, func, args) then
				changeHealth(plr, attackerName, victimName, healthDelta, gearName)
			end

		elseif args and args[1] and verifyPath(args[1]) then
			-- specify which player to be updated
			table.insert(args, 1, plr.Name)		

			if func == "setValue" then
				remote:FireAllClients("setValue", args)
			elseif func == "setLocalValue" then
				for _, p in ipairs(plrs:GetPlayers()) do
					if p ~= plr then
						remote:FireClient(p, "setValue", args)
					end
				end
			end
		else 
			warn(plr.Name, func, ": invalid path", args[1])
		end  
	end)
	spawn(function()
		while true do
			if _G.plrStats == nil then
				print("fpscore: _G.plrStats = nil")
			end
			wait(5)
		end
	end)
end

return md
