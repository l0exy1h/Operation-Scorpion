local md = {}

-- defs
local rep        = game.ReplicatedStorage
local sharedVars = rep.SharedVars
local plrs       = game.Players
local fpsCoreMd  = require(game.ServerScriptService.FPSCore)
local remote     = rep.Events.MainRemote
local gm         = rep.GlobalModules
local sd         = require(gm.ShadedTexts)
local inStudio   = game.CreatorId == 0
local captureMd  = require(script.Capture)

local ser = game.ServerStorage
local sm  = ser:WaitForChild("ServerModules")
local sql = require(sm:WaitForChild("SQL"))

-- consts
md.roundCount      = 5
md.bestOf          = (md.roundCount + 1) / 2
md.roundTimeMax    = 5*60
md.rushModeTimeMax = 30
--[[if inStudio then
	md.roundTimeMax = 15
	md.bestOf       = 1
end--]]
-- the total hard point is in the replicated storage
md.totalHardpoints = 2048
sharedVars:WaitForChild("AlphaTotalHardpoints").Value = md.totalHardpoints
sharedVars:WaitForChild("BetaTotalHardpoints").Value = md.totalHardpoints

-- vars
md.rushMode = false
md.actualTimeMax = nil

function md.incRound()
	sharedVars.Round.Value = sharedVars.Round.Value + 1 
end

function md.win(team)
	md.roundWinnerDetermined = true
	
	if team == nil then -- draw
		
	else
		md.roundWinner = team
		md.incRound()
		sharedVars[team.Name.."Wins"].Value = sharedVars[team.Name.."Wins"].Value + 1
		if sharedVars[team.Name.."Wins"].Value >= md.bestOf then
			md.matchWinner = team
		end
		if sharedVars[team.Name.."Wins"].Value == md.bestOf - 1 then
			sql.query(string.format([[update rbxserver set quickjoinable = false where placeid = %d]], game.PlaceId))
		end
	end
	
	warn("round end, round winner =", md.roundWinner)	
	
	-- check if a team contains no players
	if fpsCoreMd.getPlayersCnt(game.Teams.Alpha) == 0 and inStudio == false then
		md.matchWinner = game.Teams.Beta
	end
	if fpsCoreMd.getPlayersCnt(game.Teams.Beta) == 0 and inStudio == false then
		md.matchWinner = game.Teams.Alpha
	end	
end

local function makePointsNeutral(points, team)
	for _, p in ipairs(points) do
		if points.owner == team then
			points.owner = nil
		end
	end
end

local function enableDoublePoints(points)
	for _, p in ipairs(points) do
		p:enableDoubleInc()
	end
end

function md.setup()
	md.matchWinner = nil

	-- init the capture modules
	local captureObjs = {}
	for i, cyl in ipairs(workspace.Map.Hardpoints:GetChildren()) do
		table.insert(captureObjs, captureMd.new(cyl))
	end
	
	sharedVars.Round.Value = 1	
	while md.matchWinner == nil and sharedVars.Round.Value <= md.roundCount do
		md.roundWinner           = nil
		md.roundWinnerDetermined = false
		md.rushMode              = false
		
		-- reset the capture modules
		for _, p in ipairs(captureObjs) do
			p:reset()
		end		
		
		--resetTVnGlass()
		remote:FireAllClients("resetTVnGlass")
		remote:FireAllClients("clearBodies")		
		remote:FireAllClients("Spec::changeMode", {"teamOnly"})
		fpsCoreMd.spawnAll()
		spawn(function()
			wait(2)		
			fpsCoreMd.unlockAll()
			wait(2)		
			fpsCoreMd.unlockAll()
		end)
		wait(2)
		
		sharedVars.AlphaTotalLives.Value = #game.Teams.Alpha:GetPlayers()
		sharedVars.BetaTotalLives.Value    = #game.Teams.Beta:GetPlayers()
		sharedVars.AlphaLives.Value      = sharedVars.AlphaTotalLives.Value
		sharedVars.BetaLives.Value         = sharedVars.BetaTotalLives.Value
		sharedVars.AlphaHardpoints.Value = 0
		sharedVars.BetaHardpoints.Value    = 0

		-- start all the capture modules
		for _, p in ipairs(captureObjs) do
			p:start()
			remote:FireAllClients("HP::showGui", {p.name})
		end
		
		local matchSt, t = tick(), 0
		md.actualTimeMax = md.roundTimeMax
		while md.roundWinnerDetermined == false and t <= md.actualTimeMax and wait(1) do
			t = tick() - matchSt
			sharedVars.FPSTimer.Value      = math.floor(md.actualTimeMax - t)
			sharedVars.AlphaLives.Value = fpsCoreMd.getAlivePlayersCnt(game.Teams.Alpha)
			sharedVars.BetaLives.Value    = fpsCoreMd.getAlivePlayersCnt(game.Teams.Beta)
					
			-- normal mode	
			--if not md.rushMode then
				-- max score reached
				-- both
			if not inStudio then
				if sharedVars.AlphaHardpoints.Value >= sharedVars.AlphaTotalHardpoints.Value
					and sharedVars.BetaHardpoints.Value >= sharedVars.BetaTotalHardpoints.Value then
					if sharedVars.AlphaLives.Value > sharedVars.BetaLives.Value then
						md.win(game.Teams.Alpha)
					elseif sharedVars.AlphaLives.Value < sharedVars.BetaLives.Value then
						md.win(game.Teams.Beta)
					else
						md.win(nil)
					end
				-- Alpha reaches the max score
				elseif sharedVars.AlphaHardpoints.Value >= sharedVars.AlphaTotalHardpoints.Value then
					md.win(game.Teams.Alpha)
				-- Beta reaches the max score
				elseif sharedVars.BetaHardpoints.Value >= sharedVars.BetaTotalHardpoints.Value then
					md.win(game.Teams.Beta)
				end
				
				-- all members in a team have died
				-- both died
				if sharedVars.AlphaLives.Value == 0 and sharedVars.BetaLives.Value == 0 then
					if sharedVars.AlphaHardpoints.Value == sharedVars.BetaHardpoints.Value then
						md.win(nil)
					elseif sharedVars.AlphaHardpoints.Value > sharedVars.BetaHardpoints.Value then
						md.win(game.Teams.Alpha)
					else
						md.win(game.Teams.Beta)
					end					
				-- Alpha gets wiped out
				elseif sharedVars.AlphaLives.Value == 0 then 
					-- Beta has higher points, directly wins
					if sharedVars.AlphaHardpoints.Value <= sharedVars.BetaHardpoints.Value then
						md.win(game.Teams.Beta)
					-- Beta needs to capture all the points
					elseif not md.rushMode then
						md.rushMode = true
						md.teamAlive = game.Teams.Beta
						
						-- enable rush mode
						remote:FireAllClients("rushMode", {md.teamAlive, md.rushModeTimeMax})
						makePointsNeutral(captureObjs, game.Teams.Alpha)
						enableDoublePoints(captureObjs)
						
						-- reset timer at 30 secs
						md.actualTimeMax = md.rushModeTimeMax
						matchSt, t = tick(), 0
					end
				-- Alpha is alive and has a higher points
				elseif sharedVars.BetaLives.Value == 0 then
					if sharedVars.AlphaHardpoints.Value >= sharedVars.BetaHardpoints.Value then
						md.win(game.Teams.Alpha)
					elseif not md.rushMode then
						md.rushMode = true						
						md.teamAlive = game.Teams.Alpha
						
						-- enable rush mode
						remote:FireAllClients("rushMode", {md.teamAlive, md.rushModeTimeMax})
						makePointsNeutral(captureObjs, game.Teams.Beta)
						enableDoublePoints(captureObjs)
						
						-- reset timer at 30 secs
						md.actualTimeMax = md.rushModeTimeMax
						matchSt, t = tick(), 0
					end
				end
			end
			-- rushMode: a team gets wiped out and the other team has 30 secs to capture all the points			
			--else
				
			--end
		end
		
		-- stop all the cylinder modules
		for _, p in ipairs(captureObjs) do
			p:stopInc()
			remote:FireAllClients("HP::hideGui", {p.name})
		end				
		
		-- time limit exceeded		
		if md.roundWinnerDetermined == false then
			warn("server: TLE!")
			if sharedVars.AlphaHardpoints.Value > sharedVars.BetaHardpoints.Value then
				md.win(game.Teams.Alpha)
			elseif sharedVars.AlphaHardpoints.Value < sharedVars.BetaHardpoints.Value then
				md.win(game.Teams.Beta) 
			elseif sharedVars.AlphaLives.Value > sharedVars.BetaLives.Value then
				md.win(game.Teams.Alpha)
			elseif sharedVars.AlphaLives.Value < sharedVars.BetaLives.Value then
				md.win(game.Teams.Beta)
			else
				md.win(nil)
			end
		end
		
		-- round intermission
		fpsCoreMd.lockAll()
		rep.Stage.Value = "Match Intermission"
		fpsCoreMd.announceWinner(md.roundWinner, md.matchWinner)
		wait(19)		-- << round intermission secs
		
		if md.matchWinner then 
			wait(5)
			break 
		end
		
		rep.Stage.Value = "Match"
	end
end

function md.getFinalArrangement()
	local winners = md.matchWinner:GetPlayers()
	table.sort(winners, function(x, y)
		return x.Stats.ExpInc.Value > y.Stats.ExpInc.Value
	end)
	for i, plr in ipairs(winners) do
		local block = workspace.Map.Final[tostring(i)]
		fpsCoreMd.spawn(plr, "precise", block.CFrame)
		local gui = block.gui.BillboardGui
		local fr  = gui.Frame
		fr.Plr.text.TextColor3 = md.matchWinner.TeamColor.Color
		sd.setProperty(fr.Plr, "Text", plr.Name)
		sd.setProperty(fr.P1, "Text", string.format("Score: %d", plr.Stats.ExpInc.Value))
		sd.setProperty(fr.P2, "Text", "")
		gui.Enabled = true
	end
end

function md.getCreditInc(ds)
	return ds ~= nil and ds.expInc / 50 or 0	
end

return md
