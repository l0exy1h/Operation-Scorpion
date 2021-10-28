-- easing function:
-- functions whose domain is [0,1]
-- and f(0) = 0 and f(1) = 1
-- used for animation
------------------------------------
local exp = math.exp
local md = {
	linear = function(t)
		return t
	end;
	cubicBezier1001 = function(t)
		return 1 / 48 * (36 - 24 * t) + 3 / 4 * ((2 * t - 1) ^ (1 / 3))
	end;
	easeInCubic = function(t)
		return t^3
	end;
	easeOutCubic = function(t)
		return 1 + (t - 1)^3
	end;
	easeInQuart = function(t)
		return t^4
	end;
	easeOutQuart = function(t)
		return 1 - (t-1)^4
	end;
	easeInQuint = function(t)
		return t^5 
	end;
	easeOutQuint = function(t)
		return 1 + (t - 1)^5
	end;
}

-- a special class of bezier
-- specify the percentage of completedness at t = 1/3 and 2/3
md.getCubicBezier = function(u1, u2)
	local _3u1 = 3 * u1
	local _3u2 = 3 * u2
	return function(t)
		local t2   = t  * t
		local t3   = t2 * t
		local invt = 1 - t
		local invt2= invt * invt
		return _3u1 * invt2 * t + _3u2 * invt * t2 + t3
	end
end

md.getEasingInOut = function(a)
	return function(x)
		return (x^a) / (x^a + (1-x)^a)
	end
end

return md