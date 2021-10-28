local md = {}

-- for printing tables converted from JSON recursively
local http       = game:GetService("HttpService") 
local pp  = "    "
local function _printTable(a, p)
	if a == nil then return end
	print(p, "{")
	for k, v in pairs(a) do
		if type(v) ~= "table" then
			print(p..pp, string.format("%s (%s)", k, type(v)), ":", v)
		else
			print(p..pp, k, ":")
			_printTable(v, p..pp)
		end
	end
	print(p, "}")
end
function md.printTable(a)
	if a == nil then
		warn("printTable: table is nil")
	end
	_printTable(a, "")
end
function md.printTableOneLine(a)
	print(http:JSONEncode(a))
end
function md.stringifyTableOneLine(a)
	return http:JSONEncode(a)
end

function md.cloneTableShallow(b)
	local a = {}
	for k, v in pairs(b) do
		a[k] = v
	end
	return a
end

function md.countDictSize(d)
	local cnt = 0
	for k, _ in pairs(d) do
		cnt = cnt + 1
	end
	return cnt
end

function md.isEqualShallow(a, b)
	for k, v in pairs(a) do
		if b[k] ~= v then return false end
	end
	for k, v in pairs(b) do
		if a[k] ~= v then return false end
	end
	return true
end

function md.devalue(d)
	local ret = {}
	for k, v in pairs(d) do
		ret[k] = true
	end
	return ret
end

function md.dekey(d)
	local a = {}
	for _, v in pairs(d) do
		a[#a + 1] = v
	end
	return a
end

-- returns if a is in the list of length n
function md.isInList(a, list, n)
	n = n or #list
	for i = 1, n do
		if a == list[i] then
			return true
		end
	end
	return false
end

-- get a set from a list
-- the key can be non-string
function md.getSet(list, n)
	n = n or #list
	local set = {}
	for i = 1, n do
		local key = list[i]
		if key then
			set[key] = true
		end
	end
	return set
end

-- -- array and dictionary operations
-- function md.toDictionaryFromStringArray(array, initVal)
-- 	initVal = initVal or true
-- 	local ret = {} 
-- 	for _, v in ipairs(array) do
-- 		ret[v] = initVal
-- 	end
-- 	return ret
-- end

-- function md.toArrayFromKeys(dict)
-- 	local a = {}
-- 	for key, _ in pairs(dict) do
-- 		a[#a + 1] = key
-- 	end
-- 	return a
-- end

-- function md.inArrayQ(q, a)
-- 	for i, v in ipairs(a) do
-- 		if v == q then
-- 			return true, i 
-- 		end
-- 	end
-- 	return false, -1
-- end

-- -- return a new array containing the elements that are in a1 but not in a2 (a1 - a2)
-- function md.arrayMinus(a1, a2)
-- 	local ret = {}
-- 	for _, v in ipairs(a1) do
-- 		if not md.inArrayQ(v, a2) then
-- 			ret[#ret + 1] = v
-- 		end
-- 	end
-- 	return ret
-- end

-- -- return a1 - a2 (in a1 but not in a2), a2 - a1 (in a2 but not in a2)
-- function md.diffArray(a1, a2)
-- 	return md.arrayMinus(a1, a2), md.arrayMinus(a2, a1)
-- end

-- function md.diffDictionaryKeys()
-- 	error("diffDictionaryKeys, wip")
-- end

return md