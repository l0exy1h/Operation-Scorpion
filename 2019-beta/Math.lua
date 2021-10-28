-- math module
-- cframe, v3, math
-------------------------------------
local myMath = {
	intInf    = 233333333,
	doubleInf = 1e233,
}
local pi         = math.pi
local sin, cos   = math.sin, math.cos
local asin, acos = math.asin, math.acos
local atan2      = math.atan2
local abs        = math.abs
local sqrt       = math.sqrt
local exp        = math.exp
local ran        = math.random

myMath.halfPi    = pi/2
myMath.newCf     = CFrame.new
myMath.iCf       = myMath.newCf()
myMath.invCf     = myMath.iCf.inverse
myMath.oCf       = CFrame.fromOrientation
myMath.cfLerp    = myMath.iCf.lerp

myMath.deg       = pi / 180
local deg = myMath.deg

function myMath.clamped(x, l, r)
	return l <= x and x <= r
end
function myMath.clamp(x, l, r)
	return x < l and l or x > r and r or x
end
do
	local abs = math.abs
	function myMath.delta(a, b)
		return abs(a - b)
	end
	local _eps = 1e-3
	function myMath.near(a, b, eps)
		eps = eps or _eps
		return abs(b - a) < eps
	end
end
function myMath.lerp(a, b, p)
	return a + (b - a) * p
end
do
	local _anglesCF = CFrame.Angles
	function myMath.degToCf(x, y, z) -- x y z order
		return _anglesCF(x * deg, y * deg, z * deg)
	end
end
do -- cyl related stuff
	local oCf   = CFrame.fromOrientation
	local sin   = math.sin
	local cos   = math.cos
	local atan2 = math.atan2
	local asin  = math.asin
	local acos  = math.acos
	local newV3 = Vector3.new
	function myMath.cylToCf(y, x)		-- y x order
		return oCf(x * deg, y * deg, 0)
	end	
	function myMath.cylToV3(y, x)
		x, y = x * deg, y * deg
		local cosx = cos(x)
		return newV3(cosx * sin(y), sin(x), cosx * cos(y))
	end
	function myMath.v3ToCyl(v)
		local x, y, z = v.x, v.y, v.z
		local alpha = atan2(x, z) / deg
		if alpha < 0 then alpha = alpha + 360 end
		return alpha, asin(y / v.magnitude) / deg 
	end
	local v3ToCyl = myMath.v3ToCyl
	function myMath.lvToCf(v)
		local y, x = v3ToCyl(v)
		return oCf(x * deg, (y - 180) * deg, 0)
	end
end
function myMath.cmp(a, b)
	if a < b then return 1
	elseif a > b then return -1
	else return 0 end
end
function myMath.mod(a, m)
	local b = a % m
	return b >= 0 and b or b + m
end
do
	local exp = math.exp
	function myMath.getLogisticFunction(h, r, x0, y0)
		y0 = y0 or 1
		return function(x)
			return y0 + (1 / (1 + exp(-4 / r * (x - x0))) - 0.5) * 2 * h
		end		
	end
	local ln = math.log
	local getLogisticFunction = myMath.getLogisticFunction
	function myMath.getLogisticFunction2(h1, h2, r, x0, y0)
		local hp = (h1 + h2) / 2
		local yp = (y0 + h1 + y0 - h2) / 2
		local xp = (r/4) * ln((2 * hp) / (y0 - yp + hp) - 1) + x0
		return getLogisticFunction(hp, r, xp, yp)
	end
end
do
	local cylToV3 = myMath.cylToV3
	local _fromAxisAngle = CFrame.fromAxisAngle
	function myMath.axisAngleRotCf(v3, theta)
		return _fromAxisAngle(v3, theta * deg)
	end
	function myMath.cylAngleRotCf(y, x, theta)
		return _fromAxisAngle(cylToV3(y, x), theta * deg)
	end
end
do
	local ran = math.random
	function myMath.randomDouble(l, r)
		return ran() * (r - l) + l
	end
end
function myMath.rotOnlyCf(cf)
	return cf - cf.p
end
do--lerpto
	local clamp = myMath.clamp
	function myMath.lerpTo(a, b, t)
		if a < b then
			return clamp(a + t, a, b)
		else
			return clamp(a - t, b, a)
		end
	end
end
do--smoothlerp
	local lerp = myMath.lerp
	function myMath._smoothLerp(n, g, t)
		if t < 0.001 then
			return n
		elseif t > 0.999 then
			return g
		else
			return lerp(n, g, cos(t * pi - pi) + 1) / 2
		end
	end
end
function myMath.getPara(a, b, h)
	return function(x)
		return (-4 * h) / (a-b)^2 * (x-a) * (x-b)
	end
end
do-- getBouncingPara
	local getPara = myMath.getPara
	function myMath.getBouncingPara(a, b, h)
		local p1 = getPara(0, a, h)
		local p2 = getPara(a, b, h * 0.5)
		return function(x)
			if x < 0 then return 0
			elseif x < a then return p1(x)
			elseif x < b then return p2(x)
			else return 0 end
		end
	end
end
do -- getOscillatingSine
	local sin = math.sin
	function myMath.getOscillatingSine(T, a, b)
		local halfDelta = (b - a) / 2
		local w = 2 * pi / T
		return function(x)
			return a + halfDelta * (1 + sin(w * x))
		end
	end
end
function myMath.getPercentage(x, a, b)
	return (x - a) / (b - a)
end


return myMath