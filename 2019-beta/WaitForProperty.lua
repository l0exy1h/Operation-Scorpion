-- @param t: table
-- @param k: key
return function(t, k, args)
	args = args or {}
	local clockrate   = args.clockrate or 0.5
	local maxWaitTime = args.maxWaitTime
	local warnTime    = args.warnTime or 5

	local st     = tick()
	local warned = false
	while true do
		if t[k] then
			if warned then
				warn(string.format("got %s.%s", tostring(t), k))
			end
			return t[k]
		end

		local now = tick()
		if not warned and now - st > warnTime then
			warned = true
			warn(string.format("waiting for %s.%s for more than %d seconds", tostring(t), k, warnTime))
		end

		if maxWaitTime and now - st > maxWaitTime then
			warn(string.format("waiting for %s.%s has exceeded time limit of %d seconds. return nil", tostring(t), k, maxWaitTime))
			return nil			
		end

		wait(clockrate)
	end
end