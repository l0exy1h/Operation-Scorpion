local md = {}

-- defs
local plrs = game.Players
local rep = game.ReplicatedStorage
local remote = rep.Events.MainRemote
local gm = rep:WaitForChild("GlobalModules")

-- consts
local scares = {"Calm","Nervous","Scared"}
local Uniforms = {}
Uniforms["Alpha"] = {
	"ScorpionShirt",
	"TacticalMask",
	"PistolHolster_Right",
	"helmet",
	"militaryBackpack",
	"militaryVest",
	"nVGoggles",
	"tacticalHeadphones"
}
Uniforms["Beta"] = {
	"SkullShirt",
	"skullsVest",
	"coverMask",
	"duffelBag",
	"PistolHolster_Right_Dark"	
}

local dsEnabled = true
local function waitForDsModule()
	while _G.plrStats == nil do wait() end
	return _G.plrStats
end


function md.isAlive(plr)
	return plr.Character and plr.Character.Parent and plr.Character.Parent.Name == "Alive"
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

function md.resetAmmo(plr)
	remote:FireClient(plr, "resetAmmo")
end

function md.resetHealth(plr)
	remote:FireClient(plr, "resetHealth")
end

local function waitForTeamAssigned(plr)
	repeat
		wait(0.25)
	until plr.Team
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
			plr.Character.HumanoidRootPart.CFrame = workspace.Map.Spawn[plr.Team.Name].CFrame + randomOffset
		end
	end
end

function md.teamSpawnDead(team, teleOpt, pos)
	for _, plr in ipairs(team:GetPlayers()) do
		if not md.isAlive(plr) then
			md.spawn(plr, teleOpt, pos)
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

function md.spawnAll()
	for _, plr in ipairs(plrs:GetPlayers()) do
		spawn(function()
			md.spawn(plr, "random")
		end)
	end
end

function md.spawnR6(plr)
	plr:LoadCharacter()
end

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

function md.kill(plr)
	if md.isAlive(plr) then
		remote:FireAllClients("changeHealth", {plr.Name, 0})
		plr.Stats.Health.Value = 0
		local plrStats = waitForDsModule()
		plrStats[plr.Name].assisters = {}
	end
end

function md.killAll()
	for _, plr in ipairs(plrs:GetPlayers()) do
		md.kill(plr)
	end
end

function md.announceWinner(roundWinner, matchWinner)
	remote:FireAllClients("roundEnd", {roundWinner, matchWinner})
end


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

local function aliveQ(plr)
	return plr:FindFirstChild("Stats") 
		and plr.Stats:FindFirstChild("Health")
		and plr.Stats.Health.Value > 0.01
		and plr.Character
		and plr.Character.Parent == workspace.Alive
end
local function changeHealth(attacker, attackerName, victimName, healthDelta, gearName)
	local plrStats = waitForDsModule()
	local attackerStats = plrStats[attackerName]
	local victimStats = plrStats[victimName]

	local victim = plrs:FindFirstChild(victimName)
	if victim 
		and victim.Team ~= attacker.Team
		and aliveQ(victim) and aliveQ(attacker) then
		
		victim.Character.Parent = workspace.Ragdolls

		local orginal = victim.Stats.Health.Value
		victim.Stats.Health.Value = victim.Stats.Health.Value + healthDelta
		local current = victim.Stats.Health.Value

		remote:FireAllClients("changeHealth", {victimName, current})
		victim.Stats.Health.Value = 0
		victim.Stats.Health.Value = current
		-- the victim is killed
		if orginal >= 0.01 and current < 0.01 then
			
			
			-- killer
			attackerStats.expInc   = attackerStats.expInc + expConsts.killExpIncCharacter
			attackerStats.killsInc    = attackerStats.killsInc + 1
			local gearStats = attackerStats.gears[gearName]
			gearStats.expInc = gearStats.expInc + expConsts.killExpIncGear
			gearStats.killsInc = gearStats.killsInc + 1
			
			attacker.Stats.ExpInc.Value = attackerStats.expInc
			attacker.Stats.Kills.Value  = attackerStats.killsInc

			if healthDelta == -233 then     -- a headshot is -233
				attackerStats.headshotsInc = attackerStats.headshotsInc + 1
				gearStats.headshotsInc = gearStats.headshotsInc + 1
			end

			-- assister expinc
			for _, assistData in ipairs(victimStats.assisters) do
				local assisterName = assistData[1]
				local gearName = assistData[2]
				if assisterName ~= attackerName then
					local assisterStats = plrStats[assisterName]
					assisterStats.expInc = assisterStats.expInc + expConsts.assistExpIncCharacter
					local assisterGearStats = assisterStats.gears[gearName]
					assisterGearStats.expInc = assisterGearStats.expInc + expConsts.assistExpIncGear

					local assister = plrs:FindFirstChild(assisterName)
					if assister then
						assister.Stats.ExpInc.Value = assisterStats.expInc
	
						assisterStats.assistsInc = assisterStats.assistsInc + 1
					end
				end
			end
			victimStats.assisters = {}

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
		elseif func == "changeHealth" then
			local victimName, healthDelta, gearName = args[1], args[2], args[3]
			local attackerName = plr.Name

			if verifyChangeHealth(plr, func, args) then
				changeHealth(plr, attackerName, victimName, healthDelta, gearName)
			end

		elseif verifyPath(args[1]) then
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
end

return md
