local md = {}

function md.runFuncs(funcs, ...)
	for _, func in ipairs(funcs) do
		func(...)
	end
end
function md.removeNilFuncs(funcs, n)
	n = n or 50
	local i = 0
	for j = 1, n do
		if funcs[j] then
			i = i + 1
			funcs[i] = funcs[j]
		else
			-- print("removeNilFuncs: removed nil function at index", j)
		end
	end
	for j = i + 1, n do
		funcs[j] = nil
	end
end

return md