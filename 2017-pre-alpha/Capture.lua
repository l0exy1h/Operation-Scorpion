-- an abstract data type for the point to be captured in Hardpoint mode
-- no gui (the gui is local, called HardpointMarker/HPMarker)
-----------------------------------------------------------------------

local Capture = {}
Capture.__index = Capture

-- defs
local rep = game.ReplicatedStorage
local gm = rep:WaitForChild("GlobalModules")
local sharedVars = rep.SharedVars
local timerMd = require(script.Timer)
local plrs = game.Players
local fpsCoreMd = require(game.ServerScriptService.FPSCore)
local remote = rep.Events.MainRemote
--local captureRemote = script.PointCaptured

-- consts
local incDefault = 1
local captureTime = 5
local dsEnabled = true
local expConsts = require(gm:WaitForChild("LevelExp"))
--local captureExp = 200

-- instance variables
function Capture:reset()
	self.on = false
	self.owner = nil
	self.inc = incDefault
	self.changingOwner = nil
	self.timer:reset()
	self.detectAlpha = false
	self.detectBeta = false
	remote:FireAllClients("HP::reset", {self.name})
	--warn("server: capture module reset:", self.name)
end

function Capture:enableDoubleInc()
	self.inc = self.inc * 2
end

function Capture:stopInc()
	self.inc = 0
	self.on  = false
end

function Capture.new(cyl)
	local cap = {}
	setmetatable(cap, Capture)
	cap.cyl = cyl
	cap.name = cyl.Name
	cap.timer = timerMd.new(captureTime)
	--warn("server: new capture module:", cap.name)

	local flare = script.Flare:Clone()
	flare:SetPrimaryPartCFrame(CFrame.new(cyl.CFrame.p - Vector3.new(0, cyl.Size.X/2 - 0.5, 0)) * CFrame.fromOrientation(0, math.rad(152), math.rad(-90)))
	flare.Parent = workspace.Map.Hardpoints[cap.name]
	
	cap:reset()
	return cap
end

function Capture:print()
	warn(self.name, self.owner, self.changingOwner, self.timer.T, self.detectAlpha, self.detectBeta)
end

function Capture:start()
	--warn("server: capture module on", self.name)
	if self.on then
		--warn("server: capture module warning: call start() when it has already started")
		return
	end
	self.on = true
	spawn(function()
		while self.on and wait(0.25) do
			
			-- add score whenever we can
			if self.owner then
				if fpsCoreMd.getAlivePlayersCnt(self.owner) > 0 then
					self:incTeamPts(self.owner)
				else
					-- the point becomes neutral is the team gets wiped out
					self.owner = nil
					remote:FireAllClients("HP::changeOwner", {self.name, self.owner})
				end
			end
			
			-- set self.detectAlpha and self.detectBeta
			self.detectAlpha = false
			self.detectBeta = false
			for _, char in ipairs(workspace.Alive:GetChildren()) do
				local plr = plrs:GetPlayerFromCharacter(char)
				if self:inCyl(plr) and plr.Team then
					self["detect"..plr.Team.Name] = true
				end
			end
			
			-- no team in			
			if not self.detectAlpha and not self.detectBeta then
				if self.changingOwner then
					self.changingOwner = nil
					self.timer:reset()
					remote:FireAllClients("HP::stopChanging", {self.name})
				end
			end
			
			-- one team in
			if self.detectAlpha ~= self.detectBeta then
				-- get teamIn
				local teamIn = nil
				if self.detectAlpha then
					teamIn = game.Teams.Alpha
				else
					teamIn = game.Teams.Beta
				end
				
				-- start the countdown
				if self.changingOwner == nil and self.owner ~= teamIn then
					self.changingOwner = teamIn
					self.timer:reset()
					self.timer:continue()
					remote:FireAllClients("HP::startChanging", 
						{self.name, self.owner, teamIn, captureTime, captureTime})
				
				-- continue capturing
				elseif self.changingOwner == teamIn then

					-- change the owner!
					if self.timer:isOver() then
						self.owner = teamIn
						self.timer:reset()
						self.changingOwner = nil
						remote:FireAllClients("HP::changeOwner", {self.name, teamIn})
						
						-- add exp
						if dsEnabled then
							for _, plr in ipairs(teamIn:GetPlayers()) do
								if self:inCyl(plr) then
									local plrStats = _G.plrStats[plr.Name]
									plrStats.expInc = plrStats.expInc + expConsts.captureExpInc
									plrStats.capturesInc = plrStats.capturesInc + 1
									
									plr.Stats.ExpInc.Value = plrStats.expInc 
									plr.Stats.Captures.Value = plrStats.capturesInc
								end 
							end
						end
						
						-- respawn the team
						fpsCoreMd.teamSpawnDead(self.owner, "random", self.cyl.CFrame)
						
					-- continue capturing
					else
						if self.timer.on == false then
							remote:FireAllClients("HP::startChanging", 
								{self.name, self.owner, self.changingOwner, self.timer.T, captureTime})			
						end
						self.timer:continue()
					end
					
				-- the jedis are taking over!
				elseif self.changingOwner ~= teamIn then
					
					-- doesn't own before
					if self.owner ~= teamIn then
						self.changingOwner = teamIn
						self.timer:reset()
						self.timer:continue()
						remote:FireAllClients("HP::startChanging", 
							{self.name, self.owner, teamIn, captureTime, captureTime})
						
					-- own the place before
					else
						self.changingOwner = nil
						self.timer:reset()
						remote:FireAllClients("HP::stopChanging", {self.name})
					end
				end
			end
			
			-- both teams in
			if self.detectAlpha and self.detectBeta then
				self.timer:freeze()
				remote:FireAllClients("HP::pauseChanging", {self.name})		
			end
			
			--self:print()
		end
	end)
end

function Capture:inCyl(plr)
	if plr.Character and plr.Character.HumanoidRootPart then
		local plrP = plr.Character.HumanoidRootPart.CFrame.p
		return (plrP * Vector3.new(1, 0, 1) - self.cyl.CFrame.p * Vector3.new(1, 0, 1)).magnitude <= self.cyl.Size.z/2
			and self.cyl.CFrame.p.y + self.cyl.Size.y/2 > plrP.y and plrP.y > self.cyl.CFrame.p.y - self.cyl.Size.y/2
	end
	return false
end

function Capture:incTeamPts(team)
	local t = sharedVars[team.Name.."Hardpoints"]
	local maxT = sharedVars[team.Name.."TotalHardpoints"].Value
	if t.Value + self.inc <= maxT then
		t.Value = t.Value + self.inc
	else
		t.Value = maxT
	end
end

return Capture
























