local MuzzleSystem = {}

local wfc   = game.WaitForChild
local ffc   = game.FindFirstChild
local attc_ = wfc(wfc(script, "Part"), "MuzzleEffects")
local clone = game.Clone
local emit  = Instance.new("ParticleEmitter").Emit

function MuzzleSystem.new(firepoint)
	assert(firepoint, "MuzzleSystem.new: firepoint is nil")

	local ms = {}

	local attc  = ffc(firepoint, "MuzzleEffects") or clone(attc_)
	attc.Parent = firepoint 

	local flash      = attc.Flash
	local dustyFlash = attc.DustyFlash
	local smoke      = attc.Smoke
	local pointLight = attc.PointLight
	local bri        = 0

	function ms.shoot(flashMult, smokeMult, lightMult)
		flashMult = flashMult or 1
		smokeMult = smokeMult or 1
		lightMult = lightMult or 1
		
		emit(flash, 50 * flashMult)
		emit(dustyFlash, 0.8 * flashMult)
		emit(smoke, 1 * smokeMult)
		bri = 1 * lightMult
	end

	function ms.step() 
		pointLight.Brightness = bri
		bri = bri * 0.9
	end

	return ms
end

return MuzzleSystem


