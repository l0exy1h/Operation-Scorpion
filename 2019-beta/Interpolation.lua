-- interpolation system
-------------------------------
local itp = {}
do
	local wfc   = game.WaitForChild
	local rep   = game.ReplicatedStorage
	local gm    = wfc(rep, "GlobalModules")
	local myMath= require(wfc(gm, "Math"))
	
	local clamp = myMath.clamp
	local delta = myMath.delta
	local cmp   = myMath.cmp

	itp.easing = require(wfc(gm, "Easing"))

	function itp.getInterpolator(x0, x1, T, easingFunc, t0)
		local delta = x1 - x0
		return function(t)
			return x0 + delta * easingFunc(clamp((t - t0) / T, 0, 1)) 
		end
	end

	-- curve-based interpolation system
	function itp.getGetInterpolator(easingFunc, timeFunc)
		return function(x0, x2, t0)		-- to change interpolator
			return itp.getInterpolator(x0, x2, timeFunc(x0, x2), easingFunc, t0) 
		end
	end

	-- interpolation / smoothing system with varying goal value
	function itp.getSmoother(A, B)
		local function scaler(a, b)
			return A * delta(b, a) ^ B
		end
		return function(a, b, dt)
			local a1 = a + cmp(a, b) * dt * scaler(a, b)
			return (a - b) * (a1 - b) <= 0 and b or a1 
		end
	end
end
return itp