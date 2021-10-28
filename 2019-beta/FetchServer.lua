local fetchServer = {}
do -- load rf
	function fetchServer.loadRf(rf)
		local self = {}
		local cache = {} 		-- cache[key][plrName]

		function self.addTableToCache(key, t) 	-- t's key must be plr names
			cache[key] = t
		end

		-- server-side handler for fetch() and fetchwait() at the client side.
		function rf.OnServerInvoke(requester, key, requestee)
			if requester and key and requestee then
				return cache[key][requestee.Name]
			end
		end

		return self
	end
end
return fetchServer