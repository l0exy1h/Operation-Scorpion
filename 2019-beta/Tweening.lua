local tweening = {}

local rep   = game.ReplicatedStorage
local wfc   = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

local tweenService = game:GetService("TweenService")
local newTweenInfo = TweenInfo.new
local easingStyle  = Enum.EasingStyle.Sine
local easingDir    = Enum.EasingDirection.InOut
local create = tweenService.Create
local play   = create(tweenService, Instance.new("Part"), newTweenInfo(0, easingStyle, easingDir), {}).Play

function tweening.tween(instance, time, properties)
	assert(time)
	assert(instance)
	assert(properties)
	local tween = create(tweenService, instance, newTweenInfo(
		time,
		easingStyle,
		easingDir,
		0
	), properties)
	play(tween)
	return tween
end

do-- tweenModelCf
	local pwd    = game.GetFullName
	local format = string.format
	local hb     = game:GetService("RunService").Heartbeat
	local evwait = game.Changed.Wait
	local spcf   = Instance.new("Model").SetPrimaryPartCFrame
	local myMath = requireGm("Math")
	local cfLerp = myMath.cfLerp
	local clamp  = myMath.clamp
	-- @param [args.callback]
	function tweening.tweenModelCf(model, at, cf1, args)
		assert(model.PrimaryPart, format('try to call tweenModelCf with %s but it does not have a primary part', pwd(model)))
		local self = {}

		args = args or {}
		local callback = args.callback

		local cf0     = model.PrimaryPart.CFrame
		local running = true
		local t       = 0
		spawn(function()
			while running do
				t = t + evwait(hb)

				local p = clamp(t / at, 0, 1)
				spcf(model, cfLerp(cf0, cf1, p))

				if p == 1 then
					running = false
				end
			end
			if callback then
				callback()
			end
		end)

		function self.cancel()
			running = false
			self = nil
		end

		return self
	end
end

return tweening