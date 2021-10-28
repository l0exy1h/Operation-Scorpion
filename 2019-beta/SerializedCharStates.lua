local scs = {}

local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local printTable = requireGm("TableUtils").printTable

local order = {
	"fullbodyStance",
	"upperStance",
	"lowerStance",
	"leaning",
	"aiming",
	-- "gearIdx",
}
local n = #order
local enums = {
	aiming = {
		false,
		true,
	},
	-- gearIdx = {  -- sent manually through fpsser
	-- 	1,
	-- 	2,
	-- },
	upperStance = {
		"holding",
		"lowering",
		"drawing",
		"reloading",
	},
	lowerStance = {
		"standing",
		"crouching",
		"jumping",
	},
	fullbodyStance = {
		-- "idle",
		-- "walking",
		"none",
		"sprinting",
		"dancing",
		"climbing",
		"vaulting",
	},
	leaning = {
		"mid",
		"left",
		"right",
	},
}
local cnt = {}
do-- setup enums: (reverse mapping) string -> int (starting from 0) based on int->string
	-- setup cnt: i -> how many values can there be
	for i = 1, #order do
		local key = order[i]
		local values = enums[key]
		cnt[i] = #values

		for j, value in ipairs(values) do
			local idx = j - 1
			values[idx] = value
			values[tostring(value)] = idx			
		end
		values[cnt[i]] = nil 
	end
	cnt[0] = 0
	
	-- printTable(enums)
	-- printTable(cnt)
end

-- @param states: key -> value
function scs.serialize(states)
	-- print("fpp:")
	-- printTable(states)
	local num = 0
	for i = 1, n do
		local key = order[i]
		num = num * cnt[i] + enums[key][tostring(states[key])]
	end
	return num
end

-- @param dest: destination table
function scs.deserialize(num, dest)
	for i = n, 1, -1 do
		local key = order[i]
		local idx = num % cnt[i]
		dest[key] = enums[key][idx]
		num = (num - idx) / cnt[i]
	end
	-- print("tpp:")
	-- printTable(dest)
end

function scs.initStates(states)
	for i, key in ipairs(order) do
		states[key] = enums[key][0]
	end
end

-- fetch is handled using fetch server
do -- loadre
	local isClient = game:GetService("RunService"):IsClient()

	-- socketenabled by default
	function scs.loadRe(re)
		local self = {}

		if isClient then

			-- for senders (eg.fpp)
			-----------------------------

			local states = {}
			scs.initStates(states)

			local new = true -- if there's any thing to update

			function self.forward(key, value)  -- same name as in network module
				if states[key] ~= value then
					new = true
					states[key] = value
				end
			end

			do -- fireServerAtmpt
				local fireServer = re.FireServer
				local serialize  = scs.serialize

				-- the socket
				local bool = false
				local ur = 0.1 -- update rate
				local lu = tick()-- last update

				function self.fireServerAtmpt()   -- safe to call every frame
					if new and tick() - lu > ur then
						fireServer(re, serialize(states), bool)
						bool = not bool
						new  = false
						lu   = tick()
					end
				end
			end

			-- for receivers (eg. tpp)
			-------------------------------
			do -- setPlrStatesGetter
				local deserialize = scs.deserialize
				local con = nil 	-- the connection for onclientevent (receiving replication)
													-- will be disconnected after a new plrstatesGetter is set

				-- @param plrStatesGetter
				--		should accept a plr
				--		and return the tpp.states table for that plr if it exists.
				function self.setPlrStatesGetter(plrStatesGetter)
					if con then
						con:Disconnect()
					end
					con = re.OnClientEvent:Connect(function(plr, num)
						local states = plrStatesGetter(plr)
						if states then
							deserialize(num, states)
						end
					end)
				end
			end


		else 	-- isServer
			local cache = {}  -- plrName -> num
			self.cache = cache
			function self.freeCache()  -- for fetch server
				for k, v in pairs(cache) do
					cache[k] = nil
				end
			end

			local kick = require(wfc(game.ServerStorage, "KickSystem")).kick
			local fireAllClients = re.FireAllClients

			local nextBool = {}	-- the predicted bool (for sockets)

			re.OnServerEvent:Connect(function(plr, num, bool)
				if not (plr and num and bool ~= nil) then
					return 
				end

				local plrName = plr.Name

				-- verify bool
				if bool ~= nextBool[plrName] then
					kick(plr, "hacking using replication remote. boolean mismatch.")
					return
				end
				nextBool[plrName] = not bool

				-- forward to all clients
				fireAllClients(re, plr, num)

				-- caching
				cache[plrName] = num
			end)

			-- handle player added / leaving
			local plrs = game.Players
			plrs.PlayerRemoving:Connect(function(plr)
				nextBool[plr.Name] = nil
				cache[plr.Name] = nil
			end)
			plrs.PlayerAdded:Connect(function(plr)  -- what if player joins later? server shouldn't have this issue
				nextBool[plr.Name] = false
			end)
		end

		return self
	end
end

return scs