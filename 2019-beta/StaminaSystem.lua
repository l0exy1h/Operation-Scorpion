local staminaSystem = {}

local debugSettings = {
	fasterRate = true,
}

local wfc = game.WaitForChild
local rep = game.ReplicatedStorage
local gm     = wfc(rep, "GlobalModules")
local myMath = require(wfc(gm, "Math"))
local clamp  = myMath.clamp

local rates = {
	jumping     = -10,
	sprinting   = -2,
	vaulting    = -7,
	standing    = 8,
	nonStanding = 5,
}

function staminaSystem.new()
	local ss = {}

	local staminaP = 100
	local lock     = false
	local rate     = 0
	local lastTick = tick()

	function ss.reset()
		staminaP = 100
	end

	function ss.onStateChanged(state)
		rate = rates[state] * (debugSettings.fasterRate and 3 or 1)
		assert(rate, string.format("staminaSystem: invalid state %s", state))
	end

	function ss.step(now)
		assert(now > 1, "staminaSystem: invalid tick (should not be dt)")
		local dt = now - lastTick
		if rate ~= 0 then
			staminaP = clamp(staminaP + dt * rate, 0, 100)
			if staminaP == 0 then
				lock = true
			end
			if lock and staminaP >= 25 then
				lock = false
			end
		end
		lastTick = now
		-- print(string.format("stamina = %.1f", staminaP))
		return staminaP * 0.01, lock
	end

	return ss 
end

return staminaSystem