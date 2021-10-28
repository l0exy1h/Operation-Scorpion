-- @ditched

local replicationServer = {}
do
	local connect    = game.Changed.Connect
	local wfc        = game.WaitForChild
	local rep        = game.ReplicatedStorage
	local gm         = wfc(rep, "GlobalModules")
	local tableUtils = require(wfc(gm, "TableUtils"))

	local function getPlrName(plr)
		return type(plr) == "string" and plr or plr.Name
	end
	
	function replicationServer.loadReRf(re, rf)
		local fireAllClients = re.FireAllClients
		local fireClient     = re.FireClient
		local serverHandler  = {}
		local keys           = {}
		local cache          = {}

		-- for rement event
		connect(re.OnServerEvent, function(updater, repKey, ...)
			--print("replication server:", re.Name, "received from client:", updater.Name, repKey, tableUtils.stringifyTableOneLine({...}))
			local validKeyQ = keys[repKey] 
			if validKeyQ then
				fireAllClients(re, updater, repKey, ...)

				-- caching
				if cache[updater.Name] == nil then 		-- should consider player removing
					cache[updater.Name] = {}
				end
				cache[updater.Name][repKey] = {...}

				-- running tracker func
				if typeof(validKeyQ) == "function" then
					validKeyQ(updater, ...)
				end
			else
				warn(repKey, "not a valid replication key")
			end
		end)

		-- setup keys for replication
		function serverHandler.forward(repKey, trackerFunc)
			assert(keys[repKey] == nil or warn(repKey, "already connected"))
			keys[repKey] = trackerFunc or true
		end
		function serverHandler.stopForwarding(repKey)
			assert(keys[repKey] or warn(repKey, "not connected yet"))
			keys[repKey] = nil
		end

		-- for remotefunction
		rf.OnServerInvoke = function(requester, repKey, requestee)
			if requestee then
				requestee = getPlrName(requestee)
				local c   = cache[requestee]
				return c and c[repKey] or nil
			end
		end

		-- garbage collection for cache for remotefunction
		function serverHandler.freeCache(plr)
			if plr then
				plr        = getPlrName(plr)
				cache[plr] = nil
			else
				warn("freeing all cache for replication", re, rf)
				cache = {}
			end
		end

		return serverHandler
	end
end
return replicationServer