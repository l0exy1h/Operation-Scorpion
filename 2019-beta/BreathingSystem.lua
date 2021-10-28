local breathingSystem = {}

local rep         = game.ReplicatedStorage
local plrs        = game.Players
local lp          = plrs.LocalPlayer
local wfc         = game.WaitForChild
local newInstance = Instance.new
local destroy     = game.Destroy

local gm      = wfc(rep, "GlobalModules")
local play    = require(wfc(gm, "AudioSystem")).play
local myMath  = require(wfc(gm, "Math"))
local clamped = myMath.clamped
local lerp    = myMath.lerp

local breathingSound = wfc(wfc(rep, "Sounds"), "Breathing")
local maxVol         = breathingSound.Volume
local pref           = {looped = true, volume = 0}
local threshold      = 75 / 100
local volCurve       = function(s)
	return s > threshold and 0 or lerp(maxVol, 0, s / threshold)
end
-- print("loading breathingSystem, maxBreathingVol =", maxVol)

function breathingSystem.new(parent)
	local bs = {}

	local adjuster
	local holder 
	if parent == lp then
		adjuster = play("Breathing", "2D", pref)
		holder   = adjuster.sound
	else
		local breathingAttc = newInstance("Attachment", parent)
		breathingAttc.Name  = "BreathingSoundHolder"
		adjuster = play(breathingSound, breathingAttc, pref)
		holder   = breathingAttc
	end

	-- @param: stamina [0..1]
	function bs.adjust(stamina)
		stamina = stamina / 100
		assert(clamped(stamina, 0, 1), string.format("stamina not in range, stamina = %.1f", stamina))
		adjuster.sound.Volume = volCurve(stamina)
	end

	function bs.destroy()
		destroy(holder)
		adjuster = nil
	end

	function bs.reset()
		adjuster.Volume = 0
	end

	return bs 
end

return breathingSystem