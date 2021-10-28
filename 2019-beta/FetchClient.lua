local plrs = game.Players
local lp = plrs.LocalPlayer
local fetchClient = {} 	-- fetches server side vars[key][lp.Name]

do -- load rf
	function fetchClient.loadRf(rf)
		local self = {}
		local invokeServer = rf.InvokeServer
		local ffc = game.FindFirstChild

		-- @param [args.requestee] (defaults to plr)
		-- @param [args.wait] (true/false) waiting time doubles each time
		-- @param [args.maxAttempts = inf]
		function self.fetch(key, args)
			args = args or {}
			local requestee = args.requestee or lp
			local ret = invokeServer(rf, key, requestee)
			if args.wait and not ret then
				local cnt = 1
				local T = 0.25
				local maxAttempts = args.maxAttempts
				local warnAttempts = args.warnAttempts or 2
				while true do
					wait(T)
					print("fetching", key, args.requestee)
					ret = ffc(plrs, requestee.Name) and invokeServer(rf, key, requestee)
					if ret then
						if cnt >= warnAttempts then
							warn("fetching", key, requestee, "success")
						end
						return ret
					else
						T = T * 2
						cnt = cnt + 1
						if cnt == warnAttempts then
							warn("infinite yield possible on fetching", key, requestee)
						end
						if maxAttempts and cnt > maxAttempts then
							warn("fetching", key, requestee, "failed")
							return nil
						end
					end
				end
			else
				return ret
			end
		end

		return self
	end
end

return fetchClient