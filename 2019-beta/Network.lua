-- network module
-- with socket system
---------------------------------
local network = {}

local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

do -- loadre
	local printTable = requireGm("TableUtils").printTable
	local isClient   = game:GetService("RunService"):IsClient()
	local connect    = game.Changed.Connect

	-- @param args.re2: re2 (for forwarding)
	-- @param args.socketEnabled
	-- @param args.forwardList (disabled, using socket system to secure it)
	-- @param [args.rf]: for client requesting server
	function network.loadRe(re, args)
		args = args or {}
		local re2 = args.re2
		local rf  = args.rf

		local self  = {}
		local funcs = {}

		function self.listen(key, func)
			if funcs[key] then
				warn("network:", re.Name, "replacing the old key", key)
			end
			funcs[key] = func
		end
		function self.unListen(key)
			if not funcs[key] then
				warn("network:", re.Name, key, "is not connected yet")
			end
			funcs[key] = nil
		end

		-- setup the client side network
		if isClient then

			-- for senders (eg.fpp)
			-----------------------------

			do -- fireServer & forward (if re2 is set)
				local fireServer = re.FireServer
				if args.socketEnabled then
					warn("load client-side socket system", re.Name)
					warn("all the fireserver requests should be sent using only this socket system")

					-- regular fireserver but with socket system
					local bool = false
					function self.fireServer(key, ...)
						fireServer(re, bool, key, ...)
						bool = not bool
					end

					-- forwarding (like replication)
					if re2 then
						function self.forward(key, ...)
							fireServer(re2, bool, key, ...)
							bool = not bool
						end
					end

					-- request
					if rf then
						local invokeServer = rf.InvokeServer
						function self.invokeServer(key, ...)
							local ret = {invokeServer(rf, bool, key, ...)}
							bool = not bool
							return unpack(ret)
						end
					end

				else
					-- regular fireserver
					function self.fireServer(key, ...)
						fireServer(re, key, ...)
					end

					-- forward
					if re2 then
						function self.forward(key, ...)
							fireServer(re2, key, ...)
						end
					end

					-- invokeServer
					if rf then
						local invokeServer = rf.InvokeServer
						function self.invokeServer(key, ...)
							local ret = {invokeServer(rf, key, ...)}
							return unpack(ret)
						end
					end
				end
			end

			-- for receivers 
			----------------------------

			local function onClientEvent(key, ...)
				local func = funcs[key]
				if func then
					func(...)
				end
			end
			connect(re.OnClientEvent, onClientEvent)
			if re2 then
				connect(re2.OnClientEvent, onClientEvent)  -- the first one in ... will be plr
			end
 
			-- no receiver needed for rf (server will return sth to client)

		else -- server

			local fireAllClients = re.FireAllClients
			local fireClient     = re.FireClient

			do -- fire clients
				local ffc = game.FindFirstChild
				local plrs = game.Players

				function self.fireAllClients(key, ...)
					fireAllClients(re, key, ...)
				end
				function self.fireClient(plr, key, ...)
					fireClient(re, plr, key, ...)
				end
				function self.fireClients(plrList, key, ...)
					for _, plr in pairs(plrList) do
						if type(plr) == "string" then
							plr = ffc(plrs, plr)
						end
						if plr then
							fireClient(re, plr, key, ...)
						end	
					end
				end
			end

			local cache = {}
			self.cache = cache
			do -- caching
				function self.cacheKey(key) -- returns a table whose key is playernames (used in fetch server)
					assert(type(key) == "string", "key to cache must be a string")
					cache[key] = {}
					return cache[key]
				end
				function self.freeCache(key)
					local t = cache[key]
					assert(t, key.." is not cached")
					for k, _ in pairs(t) do
						t[k] = nil
					end
				end

				local connect = game.Changed.Connect
				connect(game.Players.PlayerRemoving, function(plr)
					local plrName = plr.Name
					for _, t in pairs(cache) do
						t[plrName] = nil
					end
				end)
			end

			do -- server-side listener and forwarder
				if args.socketEnabled then
					warn("load server-side socket system", re.Name)

					local kick = require(wfc(game.ServerStorage, "KickSystem")).kick

					local nextBool = {} -- the predicted bools for each player

					-- the regular onserver event
					connect(re.OnServerEvent, function(plr, bool, key, ...)
						if not (plr and bool ~= nil and key) then return end

						local plrName = plr.Name
						
						-- verify bool
						if bool ~= nextBool[plrName] then
							kick("hacking using network remote. boolean mismatch")
							return
						end
						nextBool[plrName] = not bool

						-- run func
						local func = funcs[key]
						if func then
							func(plr, ...)
						end

						-- caching 
						if cache[key] then
							cache[key][plrName] = {...}
						end
					end)

					-- forwarder
					if re2 then

						connect(re2.OnServerEvent, function(plr, bool, key, ...)
							if not (plr and bool ~= nil and key) then return end

							local plrName = plr.Name
							
							-- verify bool
							if bool ~= nextBool[plrName] then
								kick("hacking using network remote. boolean mismatch")
								return
							end
							nextBool[plrName] = not bool

							-- forward
							fireAllClients(re2, key, plr, ...)

							-- run func
							local func = funcs[key]
							if func then
								func(plr, ...)
							end

							-- caching 
							if cache[key] then
								cache[key][plrName] = {...}
							end
						end)
					end

					-- rf
					if rf then
						rf.OnServerInvoke = function(plr, bool, key, ...)
							if not (plr and bool ~= nil and key) then return end
							local plrName = plr.Name

							if bool ~= nextBool[plrName] then
								kick("hacking using network remote. boolean mismatch")
								return
							end
							nextBool[plrName] = not bool

							local func = funcs[key]
							if func then
								return func(plr, ...)
							end
						end
					end

					do -- handle player added / leaving
						local plrs = game.Players
						connect(plrs.PlayerAdded, function(plr)
							nextBool[plr.Name] = false
						end)
						connect(plrs.PlayerRemoving, function(plr)
							nextBool[plr.Name] = nil
						end)
					end

				else
					-- the regular onserver event
					connect(re.OnServerEvent, function(plr, key, ...)
						-- run func
						local func = funcs[key]
						if func then
							func(plr, ...)
						end
					end)

					-- forwarder
					if re2 then
						local kick = require(wfc(game.ServerStorage, "KickSystem")).kick

						connect(re2.OnServerEvent, function(plr, key, ...)
							-- forward
							fireAllClients(re2, plr, key, ...)

							-- run func
							local func = funcs[key]
							if func then
								func(plr, ...)
							end
						end)
					end

					-- invokeServer
					if rf then
						rf.OnServerInvoke = function(plr, key, ...)
							if not (plr and key) then return end
							local func = funcs[key]
							if func then
								return func(plr, ...)
							end
						end
					end
				end
			end
		end

		return self
	end
end

return network