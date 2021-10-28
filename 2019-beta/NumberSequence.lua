local nsHelper = {}

local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

local split = requireGm("StringPathSolver").split

-- @param ns (string): the number sequence with keypoints
--   (j,k[,e]);(j,k[,e]);(j,k[,e]), where 
--        j is the position, 
--        k is the value, 
--        e is times repeated
-- @ret a: the full array with everything in between lerped.
--       index starts at 1
-- @ret #a: the size of the array
-- @param [args.mult]: the global multiplier (defaults to 1)
function nsHelper.toArray(ns, args)
	args = args or {}
	local mult = args.mult or 1
	local a = {}
	local i = 0
	local lastK = 0
	for _, pair in ipairs(split(ns, ";")) do
		pair = split(pair, ",")
		local j, k = tonumber(pair[1]), tonumber(pair[2]) * mult

		-- lerp everything in between
		a[j] = k
		local len  = j - i
		local size = k - lastK
		for z = i+1, j-1, 1 do
			a[z] = lastK + size * (z - i) / len
		end

		-- repeat the value for e times
		local e = pair[3] and tonumber(pair[3]) or 1
		for z = j, j + e - 1, 1 do
			a[z] = k
		end
		i, lastK = j + e - 1, k
	end
	return a, i
end

return nsHelper