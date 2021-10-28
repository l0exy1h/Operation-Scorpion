local plrs      = game.Players
local rep       = game.ReplicatedStorage
local ss        = game.ServerStorage
local wfc       = game.WaitForChild
local ffc       = game.FindFirstChild
local connect   = game.Changed.Connect

local isVipServer = (game.VIPServerOwnerId ~= 0)

local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local printTable = requireGm("TableUtils").printTable
local pv = requireGm("PublicVarsServer")
local myMath = requireGm("Math")
local db = requireGm("DebugSettings")()

local settings = {
	minPlayerCntEachTeam = db.lobbyMatchmakingAllowSinglePlayer and 0 or 2,
	maxPlayerEachTeam    = db.smallRooms and 1 or db.bombDefusalMaxPlayers / 2,
	maxPlayerImbalance   = db.maxPlayerImbalance,
	votingPhaseTL        = db.fasterMatchMaking and 5 or 15,
	startingPhaseTL      = db.fasterMatchMaking and 5 or 10,
	matchMakingClockRate = 0.5,
	quickjoinRetryTiming = 10,
	quickjoinLockTiming  = 30,
}

-- use remote functions as a cache
-- for players to fetch their user data and party data
-- so the server doesnt have to wait for player events etc.
-- (main logic: in this lobby. the control is mainly handled by the players)
----------------------------------
local fetchServer, lobbyServer
do
	local events = wfc(rep, "Events")
	fetchServer = requireGm("FetchServer").loadRf(wfc(events, "LobbyRf"))
	lobbyServer  = requireGm("Network").loadRe(wfc(events, "LobbyRe"), {socketEnabled = true, rf = wfc(events, "LobbyRf2")})
end

-- matchMakingSystem
local matchMakingSystem = {}
do
	local parties = {} 		-- plrName -> party object
	local partySystem = {}
	do
		fetchServer.addTableToCache("party", parties)

		local cloneTable = requireGm("TableUtils").cloneTableShallow
		local maxMemberCnt = 5

		function partySystem.verbose()
			warn("verbose party:")
			for plrName, party in pairs(parties) do
				print(plrName, "'s party, leader =", party.leader, "memberCnt =", party.memberCnt)
				print("  members:")
				for _, v in pairs(party.members) do
					print("    "..v.Name)
				end
			end
		end

		function partySystem.newParty(firstPlr)
			local members = {}
			local self = {leader = firstPlr, members = members, memberCnt = 0}

			local function pushdown()
				for _, plr in pairs(members) do
					pv.setP(plr, "IsSingle", self.memberCnt == 1)
				end
				lobbyServer.fireClients(members, "party", self)
			end

			function self.joinParty(plr)
				local plrName = plr.Name
				if members[plrName] then
					warn("partySystem: plr", plr, "trying to join party but already a member")
					return
				end

				parties[plrName] = self
				self.memberCnt   = self.memberCnt + 1
				members[plrName] = plr
			  -- partySystem.verbose()
			  pushdown()
			end
			self.joinParty(firstPlr)

			local function getRandomMember()
				for memberName, member in pairs(members) do
					return member
				end
				error(string.format("get random member failed, leader = %s, membercnt = %d", self.leader.Name, self.memberCnt))
			end
			function self.leaveParty(plr)
				local plrName = plr.Name
				if members[plrName] ~= plr then
					warn("partySystem: plr", plr, "trying to leave party but not a member")
					return
				end 

				members[plrName] = nil
				parties[plrName] = nil
				self.memberCnt   = self.memberCnt - 1

				if self.memberCnt > 0 then -- player quits the game
					parties[plrName] = partySystem.newParty(plr)
					if plr == self.leader then
						self.leader = getRandomMember()
					end
					pushdown()
				end
				-- partySystem.verbose()
			end

			function self.isSingle()
				return self.memberCnt == 1
			end
			function self.isLeader(plr)
				return plr == self.leader
			end
			function self.isJoinable()
				return self.memberCnt + 1 <= maxMemberCnt
			end
			function self.tostring()
				local s = "leader = "..self.leader.Name.."\t members: "
				for _, member in pairs(members) do
					s = s..member.Name..", "
				end
				return s
			end

			return self
		end

		function partySystem.onPlayerAdded(plr)
			parties[plr.Name] = partySystem.newParty(plr)
		end

		function partySystem.onPlayerRemoving(plr)
			if parties[plr.Name] then
				parties[plr.Name].leaveParty(plr)
			end
			parties[plr.Name] = nil
		end
	end
	local rooms = {}		-- plrName -> room
	local roomSystem = {}
	do
		function roomSystem.newRoom(firstParty)
			print("roomSystem. creating new room for party", firstParty.tostring())

			local self = {
				phase = "waiting",
				timer = -1,
				players = {},
				playerCnt = 0,
				teams = {
					alpha = {
						players = {},
						playerCnt = 0,
					},
					beta = {
						players = {},
						playerCnt = 0,
					},
				},
				plrVotes = {}, 	-- an index
				options = {		-- not randomly genrated
					[1] = {
						mapName = "Office",
						vote = 0,
					},
					[2] = {
						mapName = "Metro",
						vote = 0,
					},
					[3] = {
						mapName = "Yacht",
						vote = 0,
					},
					[4] = {
						mapName = "Resort",
						vote = 0,
					},
				},
			}
			local players  = self.players
			local teams    = self.teams
			local plrVotes = self.plrVotes
			local options  = self.options

			local function restorePlrVote(plr)
				local oldIdx = plrVotes[plr.Name]
				if oldIdx then
					options[oldIdx].vote = options[oldIdx].vote - 1
				end
				plrVotes[plr.Name] = nil
			end
			function self.receivePlrVote(plr, idx)
				restorePlrVote(plr)
				options[idx].vote = options[idx].vote + 1
				plrVotes[plr.Name] = idx
				lobbyServer.fireClients(players, "room.votes", options)
			end


			do-- setup team shuffling
				-- returns an array of parties {memberCnt, members}
				-- should NOT modify the parties.
				-- no duplicate parties
				-- and all members are all in game
				local function getParties()
					local ret = {}
					local visited = {}
					for plrName, plr in pairs(players) do
						local party = parties[plrName]
						if party then
							if not visited[plrName] then
								print("getParties: add", plrName, "'s party")
								for memberName, _ in pairs(party.members) do
									visited[memberName] = true
									print(memberName)
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
				local function balance(ps)
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
				-- @pre: shouldnt localize alpha / beta outside cuz they may be changed
				function self.attemptToShuffleTeam()
					if not db.teamAutoShuffleInVoting then return end
					local im = abs(teams.alpha.playerCnt - teams.beta.playerCnt)
					if im <= settings.maxPlayerImbalance then return end

					-- @pre: party members must all be present in a room
					local newAlpha, newBeta = balance(getParties())

					if abs(newAlpha.playerCnt - newBeta.playerCnt) < im then
						teams.alpha = newAlpha
						teams.beta  = newBeta
						print("team shuffled")
					end
				end
			end

			do-- join room
				local function _joinRoom(plr, teamName)
					local plrName = plr.Name
					if players[plrName] or teams.alpha.players[plrName] or teams.beta.players[plrName] then
						warn("newroom: plr", plr, "tries to join a room but already in the room. aborted")
						return
					end
					if not teams[teamName] then
						warn("_joinroom: invalid team name", teamName)
						return
					end

					players[plrName] = plr
					self.playerCnt = self.playerCnt + 1

					local team = teams[teamName]
					team.players[plrName] = plr
					team.playerCnt = team.playerCnt + 1

					plrVotes[plrName] = nil
					pv.setP(plr, "InRoom", true)
					rooms[plrName] = self

					lobbyServer.fireClients(players, "freshstart.start", self)
				end
				function self.joinRoom(party, teamName)
					for plrName, plr in pairs(party.members) do
						_joinRoom(plr, teamName)
					end
					self.attemptToShuffleTeam()
					lobbyServer.fireClients(players, "room.teams", teams)
				end
				self.joinRoom(firstParty, "alpha")

				function self.isJoinable(party)	-- returns {alpha, beta, nil}
					if self.phase ~= "starting" then
						local teamName = teams.alpha.playerCnt <= teams.beta.playerCnt and "alpha" or "beta"
						if teams[teamName].playerCnt + party.memberCnt <= settings.maxPlayerEachTeam then
							return teamName
						end
					end
				end
			end

			do-- leave room
				local function isParty(v)
					return typeof(v) == "table"
				end
				local function _leaveRoom(plr)
					local plrName = plr.Name
					if players[plrName] ~= plr then
						warn("_leaveRoom: plr", plr, "tries to leave room but is not in the room. aborted")
						return
					end
					players[plrName] = nil
					self.playerCnt   = self.playerCnt - 1

					local plrTeamName = nil
					for teamName, team in pairs(teams) do
						if team.players[plrName] then
							plrTeamName = teamName
							break
						end
					end
					if not plrTeamName then
						warn("_leaveRoom: plr", plr, "tries to leave room but is not in any team. aborted")
					end
					local plrTeam = teams[plrTeamName]
					plrTeam.playerCnt = plrTeam.playerCnt - 1
					plrTeam.players[plrName] = nil

					restorePlrVote(plr)
					pv.setP(plr, "InRoom", false)
					rooms[plrName] = nil
					lobbyServer.fireClient(plr, "freshstart.cancel")
				end
				function self.leaveRoom(v)
					if isParty(v) then
						-- print("leave room as a party")
						local party = v
						for plrName, plr in pairs(party.members) do
							_leaveRoom(plr)
						end
					else
						-- print("leave room as a single")
						local plr = v
						_leaveRoom(plr)
					end
					self.attemptToShuffleTeam()
					lobbyServer.fireClients(players, "room.teams", teams)
					lobbyServer.fireClients(players, "room.votes", options)
				end
			end

			do-- setup phases
				local phases = {
					waiting = {},
					voting = {},
					starting = {},
				}
				local function changePhase(phase)
					self.phase = phase
					phases[phase].start()
				end

				do -- waiting
					function phases.waiting.start()
						lobbyServer.fireClients(players, "room.phase", self)
					end
					function phases.waiting.step(dt)
						local hasEnoughPlayers = teams.alpha.playerCnt >= settings.minPlayerCntEachTeam 
							and teams.beta.playerCnt >= settings.minPlayerCntEachTeam 
						if hasEnoughPlayers then
							changePhase("voting")
							return
						end
						if self.playerCnt <= 0 then
							warn("room: no players. end room thread.")
							return "ended"
						end
					end
				end

				do -- voting
					function phases.voting.start()
						self.timer = settings.votingPhaseTL
						lobbyServer.fireClients(players, "room.phase", self)
					end
					function phases.voting.step(dt)
						local hasEnoughPlayers = teams.alpha.playerCnt >= settings.minPlayerCntEachTeam 
							and teams.beta.playerCnt >= settings.minPlayerCntEachTeam 
						if not hasEnoughPlayers then
							changePhase("waiting")
							return
						end
						if self.playerCnt <= 0 then
							warn("room: no players. end room thread.")
							return "ended"
						end
						self.timer = self.timer - dt
						lobbyServer.fireClients(players, "room.timer", self.phase, self.timer)
						if self.timer < 0 then
							self.timer = 0
							changePhase("starting")
						end
					end
				end

				do -- starting
					local function getMostPopularOption()		-- returns an index and the option
						local a = {}
						local highestVote
						for i = 1, #options do
							local option = options[i]
							local vote = option.vote
							if not highestVote then
								a[#a + 1] = i
								highestVote = vote
							elseif vote == highestVote then
								a[#a + 1] = i
							elseif vote > highestVote then
								a = {i}
								highestVote = vote
							end
						end
						local idx = math.random(1, #a)
						return a[idx], options[a[idx]]
					end
					local placeIds = db.placeIds
					local function getTemplatePlaceId(option)
						return placeIds[option.mapName]
					end
					local devalue = requireGm("TableUtils").devalue
					local dekey   = requireGm("TableUtils").dekey
					local ts            = game:GetService("TeleportService")
					local reserveServer = ts.ReserveServer
					local groupTeleport = ts.TeleportToPrivateServer
					function phases.starting.start()
						self.timer = settings.startingPhaseTL
						local mpIdx, mpOption = getMostPopularOption()
						self.mpIdx = mpIdx
						lobbyServer.fireClients(players, "room.phase", self)

						-- create server
						local templatePlaceId = getTemplatePlaceId(mpOption)
						local roomInitInfo = {
							Alpha = devalue(teams.alpha.players),
							Beta  = devalue(teams.beta.players),
							access_code = reserveServer(ts, templatePlaceId),
							is_vip_room = isVipServer,
							lobbyPlaceId = game.PlaceId,
							lobbyInstanceId = game.JobId,
						}
						local ps = {}
						local devalue = requireGm("TableUtils").devalue
						for plrName, plr in pairs(players) do
							local party = parties[plrName]
							if party then
								ps[plrName] = devalue(party.members)
							end
						end
						local joinData = {
							roomInitInfo = roomInitInfo,
							joinMethod = "freshstart",
							parties = ps,
						}
						spawn(function()
							groupTeleport(ts, templatePlaceId, roomInitInfo.access_code, dekey(players), "", joinData)
						end)
					end
					function phases.starting.step(dt)
						if self.playerCnt <= 0 then
							warn("room: no players. end room thread.")
							return "ended"
						end
						self.timer = self.timer - dt
						lobbyServer.fireClients(players, "room.timer", self.phase, self.timer)
						if self.timer < 0 then
							return "ended"
						end
					end
				end

				spawn(function()
					local clock = settings.matchMakingClockRate
					local lastTick = tick()
					while wait(clock) and self.playerCnt > 0 do
						local now = tick()
						local dt = now - lastTick
						local ended = phases[self.phase].step(dt)
						if ended then
							break
						end
						lastTick = now
					end
					print("room thread ends")
				end)
			end

			print("new room created")

			return self
		end
		function roomSystem.onPlayerAdded(plr)
			pv.setP(plr, "InRoom", false)
			rooms[plr.Name] = nil
		end
		function roomSystem.onPlayerRemoving(plr)
			if rooms[plr.Name] then
				rooms[plr.Name].leaveRoom(plr)
			end
			rooms[plr.Name] = nil
		end
	end
	local quickjoinSystem = {}
	local qjThreads = {}	-- plrName -> thread
	do
		local sql = require(game.ServerStorage.SQL).query
		local ts  = game:GetService("TeleportService")
		local dekey   = requireGm("TableUtils").dekey
		local devalue = requireGm("TableUtils").devalue
		local region  = require(game.ServerStorage.ServerRegion).region or "err_lobby"
		local groupTeleport = ts.TeleportToPrivateServer
		function quickjoinSystem.newThread(party)
			local self = {}
			local playerCnt = 0
			for _, plr in pairs(party.members) do
				qjThreads[plr.Name] = self
				pv.setP(plr, "InQuickjoin", true)
				lobbyServer.fireClient(plr, "quickjoin.start")
				playerCnt = playerCnt + 1
			end

			local searching = true
			spawn(function()
				local ser = nil
				local ignoreRegion = false
				local cnt = 0
				while searching do
					cnt = cnt + 1
					if cnt == 3 then
						ignoreRegion = true
					end
					ser = sql([[select * from SERVERTABLE where
						is_vip_room = FALSE and
						quickjoin_lock < current_timestamp and
						time_created + interval '15 minutes' > current_timestamp and
						player_cnt + %d <= %d and
						(alpha_cnt + %d <= %d or beta_cnt + %d <= %d) 
						order by region = '%s' desc, player_cnt desc
						limit 1 
						]],
						playerCnt, db.bombDefusalMaxPlayers,
						playerCnt, settings.maxPlayerEachTeam, playerCnt, settings.maxPlayerEachTeam,
						region
					)[1]
					if ser then
						lobbyServer.fireClients(party.members, "quickjoin.serverFound")
						printTable(ser)
						print(ser.place_id)
						local joinData = {
							joinMethod = "quickjoin",
							teamName = ser.alpha_cnt < ser.beta_cnt and "Alpha" or "Beta",
							party = devalue(party.members),
						}
						groupTeleport(ts, ser.place_id, ser.access_code, dekey(party.members), nil, joinData)
						sql([[update SERVERTABLE set quickjoin_lock = current_timestamp + interval '%d seconds' where instance_id = '%s']], settings.quickjoinLockTiming, ser.instance_id)
						break
					else
						lobbyServer.fireClients(party.members, "quickjoin.serverNotFound")
					end
					wait(settings.quickjoinRetryTiming)
				end
				print("quickjoin thread ends")
			end)

			-- only considering this player
			local function _leaveQuickjoin(plr)
				pv.setP(plr, "InQuickjoin", false)
				qjThreads[plr.Name] = nil
				lobbyServer.fireClient(plr, "quickjoin.cancel")
				playerCnt = playerCnt - 1
			end
			function self.leaveQuickjoin(plr)
				if plr then
					_leaveQuickjoin(plr)
				else
					for _, plr in pairs(party.members) do
						_leaveQuickjoin(plr)
					end
					searching = false
				end
				if playerCnt == 0 then
					searching = false
				end
			end

			return self
		end
		function quickjoinSystem.onPlayerAdded(plr)
			pv.setP(plr, "InQuickjoin", false)
		end
		-- independent from the partysystem
		-- the quickjoin will still continue.
		function quickjoinSystem.onPlayerRemoving(plr)
			if qjThreads[plr.Name] then
				qjThreads[plr.Name].leaveQuickjoin(plr)
			end
		end
	end

	do-- handle events from players
		function matchMakingSystem.onPlayerRemoving(plr)
			partySystem.onPlayerRemoving(plr)
			roomSystem.onPlayerRemoving(plr)
			quickjoinSystem.onPlayerRemoving(plr)
		end
		function matchMakingSystem.onPlayerAdded(plr)
			partySystem.onPlayerAdded(plr)
			roomSystem.onPlayerAdded(plr)
			quickjoinSystem.onPlayerAdded(plr)			
		end

		local function isNotInQjOrFs(plr)
			local plrName = plr.Name
			return not qjThreads[plrName] and not rooms[plrName]
		end

		do-- leave party
			lobbyServer.listen("party.leave", function(plr)
				if not plr then return end
				local party = parties[plr.Name]
				if party then
					if not party.isSingle() then
						party.leaveParty(plr)
					else
						warn(plr, "tries to leave party but there's only one left. aborted")
					end
				else
					warn(plr, "tries to leave party but is not in any party")
				end
			end)
		end
		do-- kick player (as a leader)
			lobbyServer.listen("party.kick", function(kicker, kickee)
				if not (kicker and kickee) then return end
				local party = parties[kicker.Name]
				if party then
					if party.isLeader(kicker) then
						if kicker ~= kickee then
							if kickee then
								party.leaveParty(kickee)
							end
						else
							warn(kicker, "tries to kick herself/himself. aborted")
						end
					else
						warn(kicker, "tries to kick somebody but is not the leader")
					end
				else
					warn(kicker, "tries to kick somebody in the party but is not in any party")
				end
			end)
		end
		do-- start quick join
			lobbyServer.listen("quickjoin.start", function(plr)
				if not plr then return end
				local party = parties[plr.Name]
				if party then
					if party.isLeader(plr) then
						if party.memberCnt <= 2 then
							if isNotInQjOrFs(plr) then
								quickjoinSystem.newThread(party)
							else
								warn(plr, "tries to start quickjoin but not in play.home")
							end
						else
							warn(plr, "tries to start quickjoin but has more than 3 members in the team")
						end
					else
						warn(plr, "tries to start quickjoin but is not the leader")
					end
				else
					warn(plr, "tries to start quickjoin in the party but is not in any party")
				end
			end)
		end
		do-- cancel quick join
			lobbyServer.listen("quickjoin.cancel", function(plr)
				if not plr then return end
				local party = parties[plr.Name]
				if party then
					local qjThread = qjThreads[plr.Name]
					if qjThread then
						if party.isLeader(plr) then
							qjThread.leaveQuickjoin()
						else
							qjThread.leaveQuickjoin(plr)
						end
					else
						warn(plr, "tries to cancel quickjoin but is not quickjoining")
						lobbyServer.fireClient(plr, "quickjoin.cancel")
					end
				else
					warn(plr, "tries to cancel quickjoin in the party but is not in any party")
				end
			end)
		end
		do-- fresh start
			lobbyServer.listen("freshstart.start", function(plr)
				if not plr then return end
				local party = parties[plr.Name]
				if party then
					if party.isLeader(plr) then
						if isNotInQjOrFs(plr) then
							print("looking for rooms for", plr, "'s party")
							-- find existing rooms
							local found = false
							for _, room in pairs(rooms) do
								local joinableTeamName = room.isJoinable(party)
								if joinableTeamName then
									print("room found")
									room.joinRoom(party, joinableTeamName)
									found = true
									break
								end
							end
							-- if not found. create a new one
							if not found then
								print("room not found. creating a new one")
								roomSystem.newRoom(party)
							end
						else
							warn(plr, "tries to start freshstart but already in queue")
						end
					else
						warn(plr, "tries to initiate fresh start but is not the leader")
					end
				else
					warn(plr, "tries to initiate fresh start in the party but is not in any party")
				end
			end)
		end
		do-- cancel fresh start
			lobbyServer.listen("freshstart.cancel", function(plr)
				if not plr then return end
				local party = parties[plr.Name]
				if party then
					local room = rooms[plr.Name]
					if room then
						if party.isLeader(plr) then
							room.leaveRoom(party)
						else
							room.leaveRoom(plr)
						end
					else
						warn(plr, "tries to cancel match making but is not in any room")
						lobbyServer.fireClient(plr, "freshstart.cancel")
					end
				else
					warn(plr, "tries to cancel match making but is not in any party")
				end
			end)
		end
		do--vote freshstart
			lobbyServer.listen("freshstart.vote", function(plr, idx)
				if not (plr and idx) then return end
				local party = parties[plr.Name]
				if party then
					local room = rooms[plr.Name]
					if room then
						if room.phase == "voting" or room.phase == "waiting"  then
							room.receivePlrVote(plr, idx)
						else
							warn(plr, "tries to vote but current room.phase = ", room.phase)
						end
					else
						warn(plr, "tries to vote but is not in any room")
					end
				else
					warn(plr, "tries to vote but is not in any party")
				end
			end)
		end
		do-- invite plr
			local function isInvitable(plr)
				local plrName = plr.Name
				local party = parties[plrName]
				return party and party.isSingle() and isNotInQjOrFs(plr)
			end
			lobbyServer.listen("party.sendInvitation", function(inviter, invitee)
				if not (inviter and invitee) then return end
				if isInvitable(invitee) and inviter ~= invitee then
					lobbyServer.fireClient(invitee, "party.receiveInvitationFrom", inviter)
				end
			end)
		end
		-- do-- request invitables (a table containing all players that can be invited)
		-- 	-- the traffic control should be on the client side
		-- 	-- or just use the public var function?
		-- end
		do-- accept invitation
			lobbyServer.listen("party.acceptInvitation", function(invitee, inviter)
				if not (invitee and inviter) then return end
				local inviterParty = parties[inviter.Name]
				if inviterParty then
					if inviterParty.isJoinable() then
						if isNotInQjOrFs(inviter) then
							inviterParty.joinParty(invitee)
						else
							warn(invitee, "accepted", inviter, "'s invitation but", inviter, "'party is already in queue")
						end
					else
						warn(invitee, "accepted", inviter, "'s invitation but", inviter, "'party is no longer joinable")
					end
				else
					warn(invitee, "accepted", inviter, "'s invitation but", inviter, "'party is not found")
				end
			end)
		end
		-- do-- reject invitation
		-- end
	end
end

print("ls1")

local datastore = {}
do
	local data = {}
	datastore.data = data
	-- local dataModified = {}
	fetchServer.addTableToCache("data", data)

	print("ls1.1")

	local misc = {}  -- local data that shoulnt be uplaoded to sql or down to player
	local hasDataOnServer = {}
	datastore.misc = misc
	datastore.hasDataOnServer = hasDataOnServer

	print("ls1.2")

	local def = requireGm("DefaultPlrData")
	local sql = require(game.ServerStorage.SQL).query
	local skinLib = requireGm("GunSkins")
	local http = game:GetService("HttpService")
	local toJSON = http.JSONEncode
	-- local fromJSON = http.JSONDecode

	print("ls1.21")

	local psi = requireGm("ProductStaticInfo")

	print("ls1.22")

	local mps = game:GetService("MarketplaceService")
	local currVersion = db.currVersion
	local function hasBoughtAlpha(plr)
		-- return true
		return mps:PlayerOwnsAsset(plr, 1436977294)
	end

	print("ls1.3")

	do
		local weaponLib          = wfc(rep, "Weapons"):GetChildren()
		-- local attachmentLib      = wfc(rep, "attachments"):GetChildren()
		local psi                = requireGm("ProductStaticInfo")
		local isWeaponReqMet     = psi.isWeaponReqMet
		function datastore.processAfterDownload(raw, plr)
			local temp = def.cloneAll(plr)
			local d = raw
			-- log versions
			-- if d.first_login_version == nil then
				d.first_login_version = hasBoughtAlpha(plr) and 0.01 or (d.first_login_version or currVersion)
			-- end
			d.last_login_version = currVersion

			-- consider editions
			d.highestEditionLevel = 0 	-- free edition
			-- standard edition
			if d.has_edition1 then
				d.highestEditionLevel = 1
			end
			-- gold's edition
			if d.edition2_expiration_date then
				if sql("select '%s'::date >= current_date as b", d.edition2_expiration_date)[1].b then
					d.has_edition2 = true
					d.highestEditionLevel = 2
				end
			end
			-- founder's edition
			if d.edition3_expiration_date then
				if sql("select '%s'::date >= current_date as b", d.edition3_expiration_date)[1].b then
					d.has_edition3 = true
					d.highestEditionLevel = 3
				end
			end

			-- fill in null fields
			for k, v in pairs(temp) do
				if d[k] == nil then
					d[k] = v
					print("ds: fill in the null field", k, "with default data for", plr)
				end
			end

			-- consider weapons
			-- check some requirements here. if met. set owned. 
			for _, v in ipairs(weaponLib) do
				local weaponName = v.Name
				if not d.weapons[weaponName] then
					if isWeaponReqMet(weaponName, d) then
						d.weapons[weaponName] = psi.getDefaultWeaponTable(weaponName)
					end
				end
			end

			-- attachments: needs another table to indicate the all possible attachments of a weapon

			return d
		end
	end
	function datastore.getDataFromRaw(raw, plr)
		if raw == nil then
			print(plr, "is playing os for the first time")
			local d = def.cloneAll(plr)
			datastore.insertNewRow(d, plr)		
			return d
		else
			print(plr, "is NOT playing os for the first time")
			hasDataOnServer[plr.Name] = true
			return datastore.processAfterDownload(raw, plr)
		end
	end
	function datastore.onPlayerAdded(plr)
		local m = {
			purchasedEditions = {},
		}
		misc[plr.Name] = m

		if db.sqlEnabled then
			local raw  =sql("select * from PLAYERTABLE where user_id = %d", plr.UserId)[1]
			data[plr.Name] = datastore.getDataFromRaw(raw, plr)
		else
			data[plr.Name] = def.cloneAll(plr)
			local d = data[plr.Name]
			-- xm8 fix for player that has played alpha but not beta
			-- if d.first_login_version == nil then
				d.first_login_version = hasBoughtAlpha(plr) and 0.01 or currVersion
				if requireGm("ProductStaticInfo").isWeaponReqMet("XM8", d) then
					if not d.weapons.XM8 then
						d.weapons.XM8 = requireGm("ProductStaticInfo").getDefaultWeaponTable("XM8")
					end
				end
			-- end
		end

		print("server: plr data fetched from sql and processed")
		-- printTable(data[plr.Name])
	end

	print("ls1.4")

	function datastore.onPlayerRemoving(plr)
		datastore.upload(plr)
		data[plr.Name] = nil
		misc[plr.Name] = nil
		hasDataOnServer[plr.Name] = nil
	end
	function datastore.processBeforeUpload(raw, plr)
		return raw
	end
	function datastore.upload(plr)
		local raw = data[plr.Name]
		if not db.sqlEnabled then return end
		if raw then
			local d = datastore.processBeforeUpload(raw, plr)
			sql([[update PLAYERTABLE set
				user_name = '%s',
				first_login_version = %.2f, 
				last_login_version = %.2f,
				money = %d,
				all_money = %d,
				loadouts = '%s',
				weapons = '%s',
				dances = '%s',
				gun_skins = '%s',
				crates = '%s',
				has_edition1 = '%s'

				where user_id = %d]], 
				plr.Name,
				d.first_login_version,
				d.last_login_version,
				d.money,
				d.all_money,
				toJSON(http, d.loadouts),
				toJSON(http, d.weapons),
				toJSON(http, d.dances),
				toJSON(http, d.gun_skins),
				toJSON(http, d.crates),
				tostring(d.has_edition1), -- oof

				plr.UserId
			)

			-- handle editions that are subscription based
			-- (update expiration dates if there is a purchase)
			if misc[plr.Name] then
				local purchasedEditions = misc[plr.Name].purchasedEditions
				if purchasedEditions then
					for k, _ in pairs(purchasedEditions) do
						sql("update PLAYERTABLE set edition%d_expiration_date = current_date + 31 where user_id = %d", k, plr.UserId)
					end
					misc[plr.Name].purchasedEditions = {}
				end
			end
		else
			warn("datastore: trying to upload", plr, "'s data but no data is found. aborted")
		end
	end
	function datastore.insertNewRow(d, plr)
		sql([[insert into PLAYERTABLE(
			user_id,
			user_name,

			first_login_version,
			last_login_version,

			exp,
			level,
			money,
			all_money,

			headshots,
			kills,
			casual_wins,
			damage,
			assists,
			deaths,
			bullets_hit,
			bullets_fired,

			has_edition1,

			loadouts,
			weapons,
			dances,
			gun_skins,
			crates
			)

			values(
			%d, '%s', 
			%.2f, %.2f,
			%d, %d, %d, %d, 
			%d, %d, %d, %d, %d, %d, %d, %d,
			'%s',
			'%s', '%s', '%s', '%s', '%s'
			)]],

			plr.UserId,
			plr.Name,

			d.first_login_version,
			d.last_login_version,

			d.exp,
			d.level,
			d.money,
			d.all_money,

			d.headshots,
			d.kills,
			d.casual_wins,
			d.damage,
			d.assists,
			d.deaths,
			d.bullets_hit,
			d.bullets_fired,

			tostring(d.has_edition1),

			toJSON(http, d.loadouts),
			toJSON(http, d.weapons),
			toJSON(http, d.dances),
			toJSON(http, d.gun_skins),
			toJSON(http, d.crates)
		)
	end


	-- @param weaponName: attachment belongs to a weapon
	-- grant the attachment for this weapon to the plr data
	-- without considering the money decreament
	function datastore.grantAttachment(weaponName, attachmentName, d)
		if psi.isSkin(attachmentName) then
			if not d.gun_skins[weaponName] then
				d.gun_skins[weaponName] = {}
			end
			d.gun_skins[weaponName][attachmentName] = true
		else
			d.weapons[weaponName].attachments[attachmentName] = true
		end
	end

	function datastore.buyCrate(crateName, amount, d)
		local crate = skinLib.getCrate(crateName)
		if not crate then
			warn(crateName, "is not a valid crate")
			return 
		end

		local price = crate.price
		if not price then
			warn(crateName, "is not buyable")
			return 
		end

		local totalPrice = amount * price
		if d.money < totalPrice then
			warn("not enough money for", crateName, "x", amount)
			return
		end

		datastore.grantCrate(crateName, amount, d)
		d.money = d.money - totalPrice
	end

	function datastore.grantCrate(crateName, amount, d)
		local crate = skinLib.getCrate(crateName)
		if not crate then
			warn(crateName, "is not a valid crate")
			return 
		end

		local ownedCrates = d.crates
		ownedCrates[crateName] = (ownedCrates[crateName] or 0) + amount
	end

	-- returns suc, ...
	-- "gotSkin", skinName, weaponName
	-- "gotCreditRefund", skinName, weaponName, moneyRefunded
	-- "notEnoughCrates"
	-- "invalidCrateName"
	-- "openError"   (error on my side)
	function datastore.useCrate(crateName, d)
		local crate = skinLib.getCrate(crateName)
		if not crate then
			return "invalidCrateName"
		end

		local ownedCrates = d.crates
		if not (ownedCrates[crateName] and ownedCrates[crateName] > 0) then
			return "notEnoughCrates"
		end

		local skinName, weaponName = skinLib.openCrate(crate, {weapons = d.weapons})
		if not skinName or not weaponName then
			warn("crate open error", crateName, skinName, weaponName)
			return "openError"
		end

		ownedCrates[crateName] = ownedCrates[crateName] - 1
		if psi.isAttachmentOwned(skinName, d, weaponName) then
			local refund = skinLib.getRefund(crate)
			d.money = d.money + refund
			return "gotCreditRefund", skinName, weaponName, refund
		else
			datastore.grantAttachment(weaponName, skinName, d)
			return "gotSkin", skinName, weaponName
		end
	end


	local psi = requireGm("ProductStaticInfo")
	local function updateLocalData(plr)
		lobbyServer.fireClient(plr, "data", data[plr.Name])
	end
	datastore.updateLocalData = updateLocalData
	do-- sync with local
		lobbyServer.listen("buy.weapon", function(plr, weaponName)
			if not (plr and weaponName) then return end
			local d = data[plr.Name]
			if d then
				if not d.weapons[weaponName] then
					local price = psi.getWeaponPrice(weaponName)
					if d.money >= price then
						d.money = d.money - price
						d.weapons[weaponName] = {
							attachments = {}, skins = {},
						}
						updateLocalData(plr)
					else
						warn(plr, "tries to buy", weaponName, "but doesn't have enough money", d.money, price)
					end
				else
					warn(plr, "tries to buy", weaponName, "but already owns it. aborted.")
				end
			else
				warn(plr, "tries to buy", weaponName, "but data is not found. aborted.")
			end
		end)
		lobbyServer.listen("equip.weapon", function(plr, weaponName, slotId)
			if not (plr and weaponName and slotId) then return end
			local d = data[plr.Name]
			if d then
				local w = d.weapons[weaponName]-- or psi.isWeaponReqMet(weaponName, d)
				if w then
					d.loadouts[1].weapons[slotId] = {
						weaponName = weaponName,
						attachments = w.savedAttachments or {},
						skin = w.savedSkin
					}
					updateLocalData(plr)
				else
					warn(plr, "tries to equip", weaponName, "but not owns it. aborted.")
				end
			else
				warn(plr, "tries to equip", weaponName, "but data is not found. aborted.")
			end
		end)
		lobbyServer.listen("equip.attachment", function(plr, weaponName, pas, slotId)
			if not (plr and weaponName and pas and slotId) then return end
			local d = data[plr.Name]
			if d then
				if d.weapons[weaponName] then
					local valid = true
					-- printTable(pas)
					-- printTable(d.weapons[weaponName].attachments)
					for _, attachmentName in pairs(pas) do
						if not psi.isAttachmentOwned(attachmentName, d, weaponName) then
							valid = false
							break
						end
					end
					if valid then
						d.loadouts[1].weapons[slotId].attachments = pas
						d.weapons[weaponName].savedAttachments = pas
						updateLocalData(plr)
					else
						warn(plr, "tries to equip.attachment onto", weaponName, "but not owns one of the attachments. aborted.")
					end
				else
					warn(plr, "tries to equip.attachment onto", weaponName, "but not owns the gun. aborted.")
				end
			else
				warn(plr, "tries to equip.attachment", weaponName, "but data is not found. aborted.")
			end
		end)
		lobbyServer.listen("buy.attachment", function(plr, weaponName, pa)
			if not (plr and weaponName and pa) then return end
			local d = data[plr.Name]
			if d then
				if d.weapons[weaponName] then
					if not psi.isAttachmentOwned(pa, d, weaponName) then
						local price = psi.getAttachmentPrice(pa)
						if price then
							if d.money >= price then
								d.money = d.money - price
								datastore.grantAttachment(weaponName, pa, d)
								updateLocalData(plr)
							else
								warn(plr, "tries to buy", pa, "for", weaponName, "but doesn't have enough money", d.money, price)
							end
						else
							warn(plr, "tries to buy", pa, "for", weaponName, "but the price for that attachment is not found")
						end
					else
						warn(plr, "tries to buy", pa, "for", weaponName, "but already owns the attachment. aborted.")
					end
				else
					warn(plr, "tries to buy", pa, "for", weaponName, "but does not own the gun. aborted.")
				end
			else
				warn(plr, "tries to buy", weaponName, "but data is not found. aborted.")
			end
		end)
		lobbyServer.listen("equip.dance", function(plr, danceName)
			if not (plr and danceName) then return end
			local d = data[plr.Name]
			if d then
				local w = d.dances[danceName]
				if w then
					d.loadouts[1].dance = danceName
					updateLocalData(plr)
				else
					warn(plr, "tries to equip", danceName, "but not owns it. aborted.")
				end
			else
				warn(plr, "tries to equip", danceName, "but data is not found. aborted.")
			end
		end)
		lobbyServer.listen("crate.use", function(plr, crateName) -- invoke
			if not plr or not crateName then
				warn("invalid crate.use signal from client", plr, crateName)
				return 
			end
			local d = data[plr.name]
			if not d then
				warn("plr", plr, "tries to use the crate but data not found")
			end
			local ret = {datastore.useCrate(crateName, d)}
			updateLocalData(plr)
			return unpack(ret)
		end)
		lobbyServer.listen("crate.buy", function(plr, crateName, amount)
			if not plr or not crateName or not amount then
				warn("invalid crate.buy signal from client", plr, crateName, amount)
				return 
			end
			local d = data[plr.Name]
			if not d then
				warn("plr", plr, "tries to buy the crate but data not found")
			end
			datastore.buyCrate(crateName, amount, d)
			updateLocalData(plr)
		end)
	end

	print("ls1.5")

	-- will return nil iff the plr is not in game
	function datastore.waitForPlrData(plr)
		local plrName = plr.Name
		local d       = data[plrName]
		local cnt     = 0

		while not d do
			if not ffc(plrs, plrName) then
				warn("player", plrName, "quits the game. stop wait for its data")
				return nil
			end
			cnt = cnt + 1
			if cnt == 3 then
				warn("waiting for", plrName, "'s data for more than 10 secs")
			end
			wait(3)
			d = data[plrName]
		end
		if cnt >= 3 then
			warn(plrName, "'s data is obtained")			
		end

		return d
	end

	function datastore.recordPayment(r, plr)
		sql([[
			insert into devproducts(
				purchase_id, 
				user_id, 
				user_name, 
				purchase_time, 
				product_id, 
				robux_spent
			)
			values(
				'%s', 
				%d, 
				'%s', 
				current_timestamp, 
				'%s',
				%d
			)]],
			r.PurchaseId, 
			plr.UserId, 
			plr.Name, 
			r.ProductId,
			r.CurrencySpent
		)
	end
end

print("ls2")

local monetization = {}
do
	local data = datastore.data
	local mp = requireGm("MonetizationProducts")
	local mps = game:GetService("MarketplaceService")
	local sql = require(game.ServerStorage.SQL)

  -- CONSIDER sql failures @todo

	-- do-- for game passes
	-- 	connect(mps.PromptGamePassPurchaseFinished, function(plr, id, bought)
	-- 		if bought then
	-- 			local plrName = plr.Name

	-- 			-- wait for data
	-- 			local d = datastore.waitForPlrData(plr)
	-- 			if not d then return nil end

	-- 			local granted = false
	-- 			if mp.getEditionPassFromId(id) then
	-- 				local p = mp.getEditionPassFromId(id)
	-- 				local edition = p.edition
	-- 				d.editions[edition] = true
	-- 				granted = true
	-- 			else
	-- 				warn("mps logic error: cannot identify the category of the game pass", id, "purchased by", plrName)
	-- 				granted = false
	-- 			end

	-- 			if granted then
	-- 				datastore.upload(plr)
	-- 				datastore.updateLocalData(plr)
	-- 			end
	-- 		end			
	-- 	end)
	-- end

	do -- for developer products
		local rbxGranted = Enum.ProductPurchaseDecision.PurchaseGranted
		local rbxNotGranted = Enum.ProductPurchaseDecision.NotProcessedYet
		local function insertIntoRecords()

		end
		function mps.ProcessReceipt(r)
			local userId     = r.PlayerId
			local plr        = plrs:GetPlayerByUserId(userId)
			local plrName    = plr.Name
			local productId  = r.ProductId
			local purchaseId = r.PurchaseId

			local processedInfo = sql.query([[
				select * from devproducts where 
					purchase_id = '%s' and 
					user_id = %d
				]],
				purchaseId,
				userId
			)
			local granted = processedInfo[1] ~= nil
			if granted then
				return rbxGranted
			end

			-- wait for data
			local d = datastore.waitForPlrData(plr)
			if not d then return rbxNotGranted end

			if not granted then
				if mp.getCreditProductFromId(productId) then
					local p = mp.getCreditProductFromId(productId)
					d.money = d.money + p.money
					d.all_money = d.all_money + p.money
					granted = true
				elseif mp.getDanceProductFromId(productId) then
					local p = mp.getDanceProductFromId(productId)
					d.dances[p.dance] = true
					granted = true
				elseif mp.getEditionProductFromId(productId) then
					local p = mp.getEditionProductFromId(productId)
					local k = p.editionLevel
					d["has_edition"..k] = true
					d.highestEditionLevel = k
					if k == 2 or k == 3 then
						local plrMisc = datastore.misc[plrName]
						local purchasedEditions = plrMisc.purchasedEditions
						if not purchasedEditions then
							plrMisc.purchasedEditions = {}
							purchasedEditions = plrMisc.purchasedEditions
						end
						purchasedEditions[k] = true
					end
					granted = true
				else
					warn("mps logic error: cannot identify the category of the product", productId, "purchased by", plrName)
					granted = false
				end
			end

			if granted then
				datastore.updateLocalData(plr)
				-- if datastore.hasDataOnServer[plr.Name] then
				datastore.upload(plr)
				datastore.recordPayment(r, plr)
				-- end
				return rbxGranted
			else
				return rbxNotGranted
			end
		end
	end
end

print("ls3")

local avatarService = {}
do
	function avatarService.onPlayerAdded(plr)
		pv.setP(plr, "Avatar", plrs:GetUserThumbnailAsync(
			plr.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size180x180
		))
	end
end

print("ls4")

local function onPlayerAdded(plr)
	print("playeradded", plr)
	matchMakingSystem.onPlayerAdded(plr)
	print("playeradded, matchmakingsystem inited for", plr)
	datastore.onPlayerAdded(plr)
	print("playeradded, datastore inited for", plr)
	avatarService.onPlayerAdded(plr)
	print("playeradded avatarService inited for", plr)
end
for _, plr in ipairs(game.Players:GetPlayers()) do
	onPlayerAdded(plr)
end
connect(plrs.PlayerAdded, onPlayerAdded)
connect(plrs.PlayerRemoving, function(plr)
	matchMakingSystem.onPlayerRemoving(plr)
	datastore.onPlayerRemoving(plr)
end)

