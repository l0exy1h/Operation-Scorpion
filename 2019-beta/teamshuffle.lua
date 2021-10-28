local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local printTable = requireGm("TableUtils").printTable

local self = {}

local parties = {}
local settings = {maxPlayerImbalance = 1}

do-- setup team shuffling
	-- returns an array of parties {memberCnt, members}
	-- should NOT modify the parties.
	-- no duplicate parties
	-- and all members are all in game
	local function getParties()
		local ret = {}
		local a = {}
		for plrName, plr in pairs(players) do
			local party = parties[plrName]
			if party then
				if not a[plrName] then
					for memberName, _ in pairs(party.members) do
						a[memberName] = true
					end
					ret[#ret + 1] = party
				end
			else
				warn("room: try shuffling teams but", plr, "'s party is not found")
			end
		end
		return ret
	end


	-- @param: ps: parties
	-- a heuristic greedy algorithm O(n log n)
	function self.balance(ps)
		table.sort(ps, function(p1, p2) return p1.memberCnt > p2.memberCnt end)
		local alpha = {playerCnt = 0, players = {}}
		local beta  = {playerCnt = 0, players = {}}

		for _, p in ipairs(ps) do
			if alpha.playerCnt < beta.playerCnt then
				alpha.playerCnt = alpha.playerCnt + p.memberCnt
				for _, plr in pairs(p.members) do
					alpha.players[plr.Name] = plr
				end
			else
				beta.playerCnt = beta.playerCnt + p.memberCnt
				for _, plr in pairs(p.members) do
					beta.players[plr.Name] = plr
				end
			end
		end

		return alpha, beta
	end

	local abs = math.abs
	local balance = self.balance
	-- @pre: shouldnt localize alpha / beta outside cuz they may be changed
	function self.attemptToShuffleTeam()
		local im = abs(teams.alpha.playerCnt - teams.beta.playerCnt)
		if im <= settings.maxPlayerImbalance then return end

		-- @pre: party members must all be present in a room
		local newAlpha, newBeta = balance(getParties())

		if im == abs(newAlpha.playerCnt - newBeta.playerCnt) then
			teams.alpha = newAlpha
			teams.beta  = newBeta
			print("team shuffled")
		end
	end
end

function self.testBalance(input)
	local ps = {}
	for i, t in ipairs(input) do
		local p = {memberCnt = #t, members = {}}
		for _, v in ipairs(t) do
			p.members[v] = {Name = v};
		end
		ps[i] = p
	end
	local newAlpha, newBeta = self.balance(ps)
	printTable(newAlpha)
	printTable(newBeta)
end

return self