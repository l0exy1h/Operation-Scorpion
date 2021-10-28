-- handles party and rooms

local rep     = game.ReplicatedStorage
local events  = rep:WaitForChild("Events")
local mmEvent = events:WaitForChild("MatchMaking")

local rFuncs  = rep:WaitForChild("RemoteFuncs")
local mmFunc  = rFuncs:WaitForChild("MatchMaking")  

local rooms   = {}		-- todo: garbage collection on this
local roomOfPlr = {}	-- plrName -> roomIdx
local Room    = require(script:WaitForChild("Room"))

local parties = {}		-- plrName -> party
local Party   = require(script:WaitForChild("Party"))

local plrs    = game.Players

local bf = script:WaitForChild("Function")

local ser = game.ServerStorage
local sm  = ser:WaitForChild("ServerModules")
local sql = require(sm:WaitForChild("SQL"))
local mp  = require(sm:WaitForChild("MatchPrepare"))

-- party system
bf.OnInvoke = function(func, args)
	if func == "createSingleParty" then				-- like playerjoin
		local plr          = args[1]
		local plrName      = plr.Name
		parties[plrName]   = Party.new(plr)
		roomOfPlr[plrName] = nil
		spawn(function()
			wait(2)
			if parties[plrName] then
				parties[plrName]:pushUpdate()
			end
			wait(4)
			if parties[plrName] then
				parties[plrName]:pushUpdate()
			end
			wait(8)
			if parties[plrName] then
				parties[plrName]:pushUpdate()
			end
			wait(16)
			if parties[plrName] then
				parties[plrName]:pushUpdate()
			end
		end)
	elseif func == "gcRoom" then
		local roomIdx  = args[1]
		rooms[roomIdx] = nil
	end
end

-- when player left the game, that plr should also leave the party
repeat wait() until _G.passed
plrs.PlayerRemoving:connect(function(plr)
	if _G.passed[plr.Name] then
		local party = parties[plr.Name]
		if party then
			party:leave(plr)
			parties[plr.Name] = nil
		end
		local roomIdx = roomOfPlr[plr.Name]
		if roomIdx then
			local room = rooms[roomIdx]
			if room then
				room:leave(plr)
				roomOfPlr[plr.Name] = nil
			end
		end
	end
end)

-- casual play
--
mmEvent.OnServerEvent:connect(function(caller, func, args)
	if func == "quickJoin" then
		-- handle all members in the team
		local party = parties[caller.Name]
		if party and party.leader == caller then
			for _, plr in ipairs(party:getAllMembers()) do
				mmEvent:FireClient(plr, "quickJoinInitiated")
			end
			party.inQuickJoin = true
			while party.inQuickJoin do
				local plrCnt = party:getPlrCnt()
				local isVipServer = (game.VIPServerOwnerId ~= 0)
				local lookup = sql.query(string.format([[select * from rbxserver 
					where lastQuickJoin < current_time - interval '15' second
					and current_timestamp < interval '30' second + heartbeat
					and open = true 
					and (alphacnt > 0 and betacnt > 0)
					and (alphacnt <= 5 - %d or betacnt  <= 5 - %d)
					and alphacnt + betacnt <= 10 - %d
					and isviproom = %s
					limit 1]], plrCnt, plrCnt, plrCnt, tostring(isVipServer)))
				if not party.inQuickJoin then break end
				if lookup[1] ~= nil then -- found
					local server = lookup[1] 
					local teamName = server.alphacnt < server.betacnt and "Alpha" or "Beta"
					warn("quickjoin server found", server.placeid, server.alphacnt, server.betacnt, server.gamemode, server.description)

					local suc = false
					for _, plr in ipairs(party:getAllMembers()) do
						spawn(function()
							print("quickjoin: make data table for", plr)
							local dataTable = {
								team = teamName,
								cust = mp.addPlrData(plr.Name),
								joinType = "quickJoin"
							}
							local suc2, msg = pcall(function()
								game:GetService("TeleportService"):TeleportToPrivateServer(server.placeid, server.accesscode, {plr}, nil, dataTable)
							end)
							if suc2 then
								mmEvent:FireClient(plr, "quickJoinFound", {server.gamemode, server.description})
							else
								warn("error when teleporting", plr, msg)
							end
							suc = suc or suc2
						end)
					end
					if suc then
						sql.query(string.format([[update rbxserver 
							set lastquickjoin = current_time 
						 where placeid = %d]], server.placeid))						
					end
					break
				else		-- not found
					for _, plr in ipairs(party:getAllMembers()) do
						mmEvent:FireClient(plr, "quickJoinNotFound")
					end
				end
				wait(5)
			end
		end
	elseif func == "cancelQuickJoin" then
		local party = parties[caller.Name]
		if party and party.leader == caller then
			party.inQuickJoin = false
			for _, plr in ipairs(party:getAllMembers()) do
				mmEvent:FireClient(plr, "quickJoinCancelled")
			end
		end
	elseif func == "acceptInvitation" then
		if parties[caller.Name]:isSingle() then
			local inviter = args[1]
			if inviter and roomOfPlr[inviter.Name] == nil then
				local party = parties[inviter.Name]
				if party and not party.inQuickJoin then
					if #party.members < 4 then
						-- remove the old party
						parties[caller.Name]:clear()
						-- add to the party
						party:add(caller)
						parties[caller.Name] = party
					else
						warn(caller, "cant join", inviter, "coz party is full:")
						for _, m in ipairs(party.members) do warn(m) end
					end
				else
					warn(caller, "cant join", inviter, "coz party doesnt exist or is in qj")
					if party then
						warn(party.inQuickJoin)
					end
				end
			else
				warn(caller, "cant join", inviter, "coz inviter is nil or the roomOfPlr[inviter.Name] is not nil")
			end
		end
	elseif func == "declineInvitation" then
		-- do nothing
	elseif func == "leaveParty" then		-- wot if leader?
		local party = parties[caller.Name]
		if party then
			party:leave(caller)
			parties[caller.Name] = Party.new(caller)
		end
	elseif func == "kickFromParty" then
		local party = parties[caller.Name]
		local kick  = args[1]
		local index = args[2]
		if party and party.leader == caller and party.members[index] and kick and party.members[index] == kick then
			party:kick(kick, index)
			parties[kick.Name] = Party.new(kick)
		end
	elseif func == "clientVote" then
		local roomIdx = roomOfPlr[caller.Name]
		local optIdx  = args[1]
		if roomIdx then
			local room = rooms[roomIdx] 
			if room then
				room:onVoteReceived(caller, optIdx)
			end
		end
	elseif func == "leaveRoom" then
		local party = parties[caller.Name]
		if party and party.leader == caller then
			local room = rooms[roomOfPlr[caller.Name]]
			for _, plr in ipairs(party:getAllMembers()) do
				roomOfPlr[plr.Name] = nil		--reset
				if room then
					room:leave(plr)
				end
				mmEvent:FireClient(plr, "roomLeft")
			end
		end
	end
end)
local cacheFriendList -- todo
local function friendsQ(plr, callerId)
	--return plr:IsFriendsWith(callerId)
	return true
end
mmFunc.OnServerInvoke = function(caller, func, args)
	if func == "freshStart" then		
		local party = parties[caller.Name]
		
		if party == nil then return "error: party not found" end
		if party.leader ~= caller then return "only the leader can initiate a match" end
		 
		local found = false
		for i, room in ipairs(rooms) do			
			local partyPlrCnt = party:getPlrCnt()
			if room:isJoinable(partyPlrCnt) then
				room:add(party:getAllMembers())
				for _, plr in ipairs(party:getAllMembers()) do
					roomOfPlr[plr.Name] = i
					-- tell the party to update their gui (go to the room page)
					mmEvent:FireClient(plr, "roomEntered", {room})
				end
				found = true
				return true
			end
		end
		if not found then
			local newIdx = 1
			while rooms[newIdx] ~= nil do newIdx = newIdx + 1 end
			print("new room index found at", newIdx)
			rooms[newIdx] = Room.new(party:getAllMembers(), newIdx)		-- the index is for garbage collection
			for _, plr in ipairs(party:getAllMembers()) do
				roomOfPlr[plr.Name] = newIdx
				-- tell the party to update their gui (go to the room page)
				mmEvent:FireClient(plr, "roomEntered", {rooms[newIdx]})
			end
			return true
		end
	elseif func == "requestFriendListInServer" then
		local ret = {}
		local callerId = caller.UserId
		for _, plr in ipairs(plrs:GetPlayers()) do
			if plr ~= caller and friendsQ(plr, callerId) then 
				if parties[plr.Name] and parties[plr.Name]:isSingle() and roomOfPlr[plr.Name] == nil then
					ret[#ret + 1] = plr
				end
			end
		end
		return ret
	elseif func == "invite" then
		local friend = args[1]
		if friend and parties[friend.Name] then
			if not parties[friend.Name]:isSingle() then
				return "In another party now"
			else
				-- send invitation
				mmEvent:FireClient(friend, "invitedBy", {caller})
				return true
			end
		else
			return "Has left the server, oof."
		end
	end
end
