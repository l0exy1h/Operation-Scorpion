local numericPulse = {}

local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local ns = requireGm("NumericSpring")

-- @param f, pd, td: params for spring
-- @param T: the duration for the goal to stay at 1
function numericPulse.new(f, pd, td, T)
	local self = {}

	local spring = ns.new(f, pd, td)
	local goal = 0
	local t0 = tick()

	function self.pulse()
		t0 = tick()
		goal = 1
	end

	function self.step(dt)
		local x, v = spring.step(dt)
		if tick() - t0 > T then
			goal = 0
		end
		spring.setGoal(goal)
		return x
	end

	return self
end

return numericPulse