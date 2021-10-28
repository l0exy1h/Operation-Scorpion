local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local ffc = game.FindFirstChild
local gm  = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

local function getHeadPosition(plr)
	return plr and plr.Character and ffc(plr.Character, "Head") and plr.Character.Head.Position
end

local myMath = requireGm("Math")
local v3ToCyl = myMath.v3ToCyl
local mod     = myMath.mod
local random  = math.random

-- @param args.hrp
-- @param args.looky
-- @param args.crouching
return function(killMethod, killData, args)
	-- get deathdir and headshotQ
	local deathDir = 1
	local headshotQ = false
	if killMethod == "shot" then
		assert(args.hrp, "killMethod shot requires hrp")
		assert(args.looky, "killMethod shot requires looky")

		-- death from (left / right / front / back)
		local rayP0   = getHeadPosition(killData.attacker) or Vector3.new()
		local rayP1   = args.hrp.Position
		local hitName = killData.hit and killData.hit.Name

		local bulletY = v3ToCyl(rayP0 - rayP1)
		local y       = mod(bulletY - args.looky, 360)
		if y >= 315 or y < 45 then
			deathDir = 1
		elseif y < 135 then
			deathDir = 2
		elseif y < 215 then
			deathDir = 3
		else
			deathDir = 4
		end

		headshotQ = hitName == "Head"
	else
		warn("kill method", killMethod, "doesnt provide any death dir information, choosing a random death pose")
		deathDir = random(1, 4)
	end

	local aniName
	if args.crouching then
		aniName = "crouchDeath"..(deathDir == 3 and 1 or deathDir) -- no crouch death from front animation for now
	else
		if headshotQ then
			aniName = "standDeathHeadshot"..((deathDir == 2 or deathDir == 4) and 1 or deathDir)
		else
			aniName = "standDeath"..deathDir
		end
	end

	return aniName, deathDir, headshotQ
end
