local shootingSimulator = {}

local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local myMath    = requireGm("Math")
local clamp     = myMath.clamp
local rand      = myMath.randomDouble
local floor     = math.floor
local ceil      = math.ceil
local max       = math.max
local min       = math.min
local abs       = math.abs
local nsToArray = requireGm("NumberSequence").toArray

local recoilXMax = 10000
local recoilYMax = 10000
local recoilXSmoother = requireGm("Interpolation").getSmoother(5, 0.8)
local recoilYSmoother = requireGm("Interpolation").getSmoother(15, 0.5)

local random = math.random
local function forRandom(x, func)
	local lo = floor(x)
	local hi = ceil(x)
	local d = x - floor(x)
	local T = random() < d and lo or hi
	for _ = 1, T do
		func()
	end
end

-- @ret avg horizontal, vertical recoil
-- @param [args.verbose] (bool)
function shootingSimulator.getAverageRecoils(stats, args)
	math.randomseed(666)

	args = args or {}
	local verbose = args.verbose

	local recoilX_, recoilY_ = 0, 0
	local recoilX, recoilY  = 0, 0 -- equivalent to fpp.recoilX

	local sumX, sumY = 0, 0

	-- input
	local recoilXRec      = stats.recoilXRec / 10
	local recoilXInc      = stats.recoilX
	local recoilXDampDur  = stats.recoilXDampDur
	local recoilXDampInit = stats.recoilXDampInit
	local recoilXDampExp  = stats.recoilXDampExp

	local recoilYRec   = stats.recoilYRec / 10
	-- local recoilYRan   = stats.recoilYRan -- not used
	local recoilYMult  = stats.recoilYMult
	local recoilYStart = stats.recoilYStart
	local recoilYPattern, recoilYPatternLength = nsToArray(stats.recoilYPattern)
	local recoilYLast  = recoilYPattern[recoilYPatternLength - 1]

	local rps = stats.rps
	local spr = 1 / rps

	-- simulation: shootOnce
	local function shootOnce(s)
		if verbose then
			print("  shoot", s)
		end

		-- vertical
		local damp = clamp(
			recoilXDampInit + 
				(1 - recoilXDampInit) * (s / recoilXDampDur) ^ recoilXDampExp, 
			0, 1)		
		recoilX_ = recoilX_ + recoilXInc * damp
		if recoilX_ > recoilXMax then
			recoilX_ = recoilXMax
		end

		-- horizontal
		s = s - recoilYStart
		if s >= 0 then
			recoilY_ = clamp(
				recoilYMult * (
					floor(s / recoilYPatternLength) * recoilYLast
						+ recoilYPattern[(s % recoilYPatternLength) + 1]
					)
				,
				-recoilYMax, 
				recoilYMax
			)
		end
	end

	-- simulation: step
	-- local testCnt = 0
	local function step(dt)
		-- vertical
		recoilX_ = clamp(recoilX_ - recoilXRec, 0, recoilXMax)
		recoilX  = recoilXSmoother(recoilX, recoilX_, dt)
		sumX     = sumX + recoilX

		-- horizontal
		if recoilY_ > 0 then
			recoilY_ = clamp(recoilY_ - recoilYRec, 0, 100000000)
		elseif recoilY_ < 0 then
			recoilY_ = clamp(recoilY_ + recoilYRec, -100000000, 0)
		end
		recoilY = recoilYSmoother(recoilY, recoilY_, dt)
		sumY = sumY + abs(recoilY)

		if verbose then
			print(string.format("recoilX = %.2f recoilY = %.2f", recoilX, recoilY))
		end
	end

	local t = 0
	local dt = 1 / 60
	local framesPerShot = spr / dt

	-- run simulation
	local testRounds = 15
	for s = 1, testRounds do
		shootOnce(s)
		forRandom(framesPerShot, function()
			step(rand(dt - 0.003, dt + 0.003))
		end)
	end

	-- return sumX / testCnt, sumY / testCnt
	return recoilX, abs(recoilY)
end

return shootingSimulator