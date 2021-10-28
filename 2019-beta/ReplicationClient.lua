-- @ditched 

local debugSettings = {
	-- blockAll = true,
	-- showAllTraffic = true,
}

local replicationClient = {}
do
	local connect    = game.Changed.Connect
	local wfc        = game.WaitForChild
	local rep        = game.ReplicatedStorage
	local gm         = wfc(rep, "GlobalModules")
	local tableUtils = require(wfc(gm, "TableUtils"))
	local printTable = tableUtils.printTable
	
	function replicationClient.loadReRf(re, rf)
		local fireServer    = re.FireServer
		local invokeServer  = rf.InvokeServer
		local clientHandler = {}
		local funcs         = {}

		function clientHandler.setDistributer(distributer)
			connect(re.OnClientEvent, distributer)
		end

		connect(re.OnClientEvent, function(updater, repKey, ...)
			local func = funcs[repKey]
			if func then
				func(updater, ...)
			end
		end)

		-- setup key listeners
		function clientHandler.listen(key, func)
			--assert(funcs[key] == nil, key.." already connected")
			if funcs[key] then
				funcs[key] = nil
				warn(re.Name, "replacing the old key", key)
			end
			funcs[key] = func
		end
		function clientHandler.unListen(repKey)
			assert(funcs[repKey], string.format("%s not connected yet", repKey))
			funcs[repKey] = nil
		end

		-- uplaod 
		function clientHandler.update(repKey, ...)
			if not debugSettings.blockAll then
				if debugSettings.showAllTraffic then
					print(repKey)
					printTable({...})
				end
				fireServer(re, repKey, ...)
			end
		end

		-- fetch cache from server
		function clientHandler.fetch(repKey, requestee)		-- yield function. be careful
			local cache = invokeServer(rf, repKey, requestee)
			assert(cache == nil or type(cache) == "table")
			return cache and unpack(cache) or nil
		end
		function clientHandler.fetchWait(repKey, requestee, maxWaitTime)
			local st      = tick()
			local warned  = false
			local ret     = nil
			maxWaitTime   = maxWaitTime or 2
			repeat
				local cache = invokeServer(rf, repKey, requestee)
				if cache then
					assert(type(cache) == "table")
					ret = cache
					break
				end
				if not warned and tick() - st > maxWaitTime then
					warn(string.format("fetchWait(%s, %s) has been wating for %d secs", repKey, tostring(requestee), maxWaitTime))
					warned = true
				end
				wait(0.5)
			until ret
			if warned then
				warn(string.format("fetchWait(%s, %s) success", repKey, tostring(requestee)))
			end
			return unpack(ret)
		end

		return clientHandler
	end
end
return replicationClient