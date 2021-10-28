local Room = {}
Room.__index = Room

local rep = game.ReplicatedStorage
local gm  = rep:WaitForChild("GlobalModules")
local Timer = gm:WaitForChild("Timer")
local tableUtils = require(gm:WaitForChild("TableUtils"))

local ser = game.ServerStorage
local sm  = ser:WaitForChild("ServerModules")
local sql = require(sm:WaitForChild("SQL"))

local events  = rep:WaitForChild("Events")
local mmEvent = events:WaitForChild("MatchMaking")

local VoteOption = require(script:WaitForChild("VoteOption"))

local mmbf = script.Parent:WaitForChild("Function")

local ser = game.ServerStorage
local sm  = ser:WaitForChild("ServerModules")
local mp  = require(sm:WaitForChild("MatchPrepare"))

-- static
local voteTime      = 20
local countdownTime = 15
local voteOptionCnt = 3 
local singleOneMatchAllowed = false

function Room.new(plrs, _roomIdx)
	assert(#plrs <= 5)
	local self = {
		alpha = plrs,
		beta  = {},
		stage = "wait",
		timer = voteTime,
		voteOptions = {},
		roomIdx = _roomIdx,
		plrVoteChoice = {},		-- plrName -> optIdx
	}
	setmetatable(self, Room)
	self:pushUpdate("entirePlayerList")
	self:main()			-- there will be a push update in main()
	return self
end

-- the client will reload some guis based on the partialUpdate
-- partialUpdate:
--  wait: clearMap Options, reset timer
--  entirePlayerList
function Room:pushUpdate(partialUpdate, a)		-- partialUpdate: timer, voteOptions, voteCnt, plrList, all
	local args = nil
	if partialUpdate == "wait" then
		args = {partialUpdate, self.voteOptions}
	elseif partialUpdate == "entirePlayerList" then
		args = {partialUpdate, self.alpha, self.beta}
	elseif partialUpdate == "voteInitiated" then
		args = {partialUpdate}
	elseif partialUpdate == "timer" then
		args = {partialUpdate, self.timer}
	elseif partialUpdate == "voteCnt" then
		args = {partialUpdate, a[1], a[2]}
	elseif partialUpdate == "countdownInitiated" then
		args = {partialUpdate, self.finalOptionIndex}
	elseif partialUpdate == "plrListUpdated" then
		args = {partialUpdate, a[1], a[2], a[3]}
	end 
	for _, plr in ipairs(self.alpha) do
		mmEvent:FireClient(plr, "roomUpdated", args)
	end
	for _, plr in ipairs(self.beta) do
		mmEvent:FireClient(plr, "roomUpdated", args)
	end
end

-- pre: isJoinable(#plrs)
function Room:add(plrs)
	local targetTeam = #self.alpha < #self.beta and self.alpha or self.beta
	local targetName = #self.alpha < #self.beta and "Alpha" or "Beta"
	self:pushUpdate("plrListUpdated", {"add", targetName, plrs})
	for _, plr in ipairs(plrs) do
		targetTeam[#targetTeam + 1] = plr
	end
end

function Room:leave(leaver)
	local function func(team, teamName)
		for i, plr in ipairs(team) do
			if plr == leaver then
				table.remove(team, i)
				self:pushUpdate("plrListUpdated", {"remove", teamName, {leaver}})
				local voteChoice = self.plrVoteChoice[leaver.Name]
				if voteChoice then
					if self.stage == "vote" then
						self.voteOptions[voteChoice]:decVotes()
						self:pushUpdate("voteCnt", {voteChoice, self.voteOptions[voteChoice].votes})
						self.plrVoteChoice[leaver.Name] = nil
					end
				end
				break
			end
		end
	end
	func(self.alpha, "Alpha")
	func(self.beta , "Beta")
end

function Room:isJoinable(howManyNewPlrs)
	return self.stage ~= "countdown" and (#self.alpha + howManyNewPlrs <= 5 or #self.beta + howManyNewPlrs <= 5)
end

function Room:hasEnoughPlayersToStart()
	if not singleOneMatchAllowed then
		return #self.alpha >= 1 and #self.beta >= 1
	else
		return #self.alpha >= 1 or #self.beta >= 1 			-- change this back!!
	end
end

function Room:onVoteReceived(voter, optIdx)
	if self.stage == "vote" then
		local oldChoice = self.plrVoteChoice[voter.Name]
		if oldChoice == nil then		-- todo: need to clean this in wait!!!!
			self.voteOptions[optIdx]:incVotes()
		elseif oldChoice ~= optIdx then
			self.voteOptions[oldChoice]:decVotes()
			self:pushUpdate("voteCnt", {oldChoice, self.voteOptions[oldChoice].votes})
			self.voteOptions[optIdx]:incVotes()
		end
		self.plrVoteChoice[voter.Name] = optIdx
		self:pushUpdate("voteCnt", {optIdx, self.voteOptions[optIdx].votes})
	end
end

function Room:main()
	self.voteOptions = VoteOption.generateList(voteOptionCnt)
	--mmEvent:pushUpdate("wait")
	spawn(function()
		while wait(0.1) do
			-- wait
			self.stage = "wait"
			for _, opt in ipairs(self.voteOptions) do
				opt:resetVotes()
			end
			self:pushUpdate("wait")
			repeat 
				wait(0.1)
			until self:hasEnoughPlayersToStart()
			
			-- vote
			self.stage = "vote"
			self.timer = voteTime
			self.plrVoteChoice = {}
			self:pushUpdate("voteInitiated")
			
			while self:hasEnoughPlayersToStart() and self.timer > 0 do
				wait(1)
				self.timer = self.timer - 1
				self:pushUpdate("timer")
			end
			
			-- countdown & start match
			if self:hasEnoughPlayersToStart() then
				self.stage = "countdown"
				self.timer = countdownTime
				
				local optionsWithMostVotes = {}
				local mostVotes            = 0
				for _, opt in ipairs(self.voteOptions) do
					if opt.votes > mostVotes then
						mostVotes = opt.votes
						optionsWithMostVotes = {opt}
					elseif opt.votes == mostVotes then
						optionsWithMostVotes[#optionsWithMostVotes + 1] = opt
					end
				end
				self.finalOption      =  optionsWithMostVotes[math.random(1, #optionsWithMostVotes)]
				self.finalOptionIndex = nil
				for i, opt in ipairs(self.voteOptions) do
					if opt == self.finalOption then
						self.finalOptionIndex = i
						break
					end
				end
				assert(self.finalOptionIndex ~= nil)
				self:pushUpdate("countdownInitiated")
				
				spawn(function()
					--  self:hasEnoughPlayersToStart() and
					while self.timer > 0 do
						wait(1)
						self.timer = self.timer - 1
						self:pushUpdate("timer")
					end
				end)
			
				-- start match
				self.finalOption:randWeather()	
				local templatePlaceId = self.finalOption:getPlaceId()
				local placeDesc       = self.finalOption:getPlaceDesc()
				local accessCode      = game:GetService("TeleportService"):ReserveServer(templatePlaceId)
				local plrList         = {}
				local isVipServer = (game.VIPServerOwnerId ~= 0)
				local dataTable = {
					alphaInit = {},
					betaInit  = {},
					gamemode  = self.finalOption.modeName,
					plrData   = {},
					placeDesc = placeDesc,
					joinType  = "freshStart",
					accessCode= accessCode,
					isVipRoom = isVipServer,
				}
				if isVipServer then
					dataTable.vipServerInstanceId = game.JobId
				end
				local function foo(team, nameList)
					for _, plr in ipairs(team) do
						local plrName = plr.Name
						plrList[#plrList + 1]      = plr
						nameList[#nameList + 1]    = plrName
						dataTable.plrData[plrName] = mp.addPlrData(plrName) 
					end
				end				  	
				foo(self.alpha, dataTable.alphaInit)
				foo(self.beta,  dataTable.betaInit)

				tableUtils.printTable(dataTable)
				
				game:GetService("TeleportService"):	
TeleportToPrivateServer(templatePlaceId, accessCode, plrList, "", dataTable)

				break
			end			
		end
		mmbf:Invoke("gcRoom", {self.roomIdx})
	end)
end

return Room

