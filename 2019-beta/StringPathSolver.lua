local sps = {}

local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local ffc = game.FindFirstChild
local pwd = game.GetFullName
local gmatch = string.gmatch
local getChars = function(str)
	return gmatch(str, ".")
end

local gm          = wfc(rep, "GlobalModules")
local printTable  = require(wfc(gm, "TableUtils")).printTable

-- split the string by d
-- return a table of strings
function sps.split(str, d, verbose)
	assert(#d == 1, string.format("The delimiter %s must be a single character", d))
	local ret = {}

	local buffer = ""
	local function addBufferToRet()
		if buffer ~= "" then
			ret[#ret + 1] = buffer
		end
	end
	-- for i = 1, #str do
	for c in getChars(str) do
		-- local c = str[i]
		if c == d then
			addBufferToRet()
			buffer = ""
		else
			buffer = buffer..c
		end
	end
	addBufferToRet()

	if verbose then
		print(string.format("splitting string %s with %s results in", str, d))
		printTable(ret)
	end

	return ret
end
local split = sps.split

local function findObj(root, sp)
	local curr = root
	local next
	for i = 1, #sp do
		next = ffc(curr, sp[i])
		if next then
			curr = next
		else
			error(string.format("%s isn't found in %s", sp[i], pwd(curr)))
		end
	end
	return curr
end

-- @param: paths is a dictionary {key -> pathname}
-- our goal is to convert the pathname into a real reference to the object
function sps.solveStringPaths(paths, root)
	for key, path in pairs(paths) do
		local sp = split(path, ".")
		paths[key] = findObj(root, sp)
		-- loadstring("paths[key] = root"..path)()
	end
	return paths
end
function sps.solveStringPath(path, root)
	local sp = split(path, ".")
	return findObj(root, sp)
end

return sps

