local md = {}

-- defs 
local rep = game.ReplicatedStorage
local sharedVars = rep.SharedVars
local plrs = game.Players
local fpsCoreMd = require(game.ServerScriptService.FPSCore)
local remote = rep.Events.MainRemote
local gm = rep.GlobalModules
local sd = require(gm.ShadedTexts)

local ser = game.ServerStorage
local sm  = ser:WaitForChild("ServerModules")
local sql = require(sm:WaitForChild("SQL"))

-- consts
md.roundCount = 9
md.bestOf = (md.roundCount + 1) / 2
md.roundTimeMax = 3 * 60
md.isMatchPoint = false
local inStudio = game.JobId == ""
inStudio = false -- july 23
warn("[linked] elimination: instudio: ", inStudio)

if inStudio then
	md.roundTimeMax = 60
	md.roundCount = 3
	md.bestOf = 2
end

function md.incRound()
	sharedVars.Round.Value = sharedVars.Round.Value + 1 
end

-- set the roundWinner and matchWinner (if possible)
function md.win(team)
	if team == nil then -- draw
		
	else
		md.roundWinner = team
		md.incRound()
		sharedVars[team.Name.."Wins"].Value = sharedVars[team.Name.."Wins"].Value + 1
		if sharedVars[team.Name.."Wins"].Value >= md.bestOf then
			md.matchWinner = team
		end
		if sharedVars[team.Name.."Wins"].Value == md.bestOf - 1 then
			sql.query(string.format([[update rbxserver set open = false where instanceid = '%s']], game.JobId))
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

function md.setup()
	md.matchWinner = nil
	
	sharedVars.Round.Value = 1
	while md.matchWinner == nil and sharedVars.Round.Value <= md.roundCount do
		md.roundWinner = nil
		
		remote:FireAllClients("resetTVnGlass")
		remote:FireAllClients("clearBodies")	
		fpsCoreMd.spawnAll()
		sharedVars.AlphaTotalLives.Value = #game.Teams.Alpha:GetPlayers()
		sharedVars.BetaTotalLives.Value  = #game.Teams.Beta:GetPlayers()
		sharedVars.AlphaLives.Value      = sharedVars.AlphaTotalLives.Value
		sharedVars.BetaLives.Value       = sharedVars.BetaTotalLives.Value
		spawn(function()
			wait(2)		
			fpsCoreMd.unlockAll()
			wait(2)		
			fpsCoreMd.unlockAll()
		end)
		wait(2)
		
		
		local matchSt, t = tick(), 0
		while md.roundWinner == nil and t <= md.roundTimeMax do
			wait(1)
			t = tick() - matchSt
			sharedVars.FPSTimer.Value   = math.floor(md.roundTimeMax - t)
			sharedVars.AlphaLives.Value = fpsCoreMd.getAlivePlayersCnt(game.Teams.Alpha)
			sharedVars.BetaLives.Value  = fpsCoreMd.getAlivePlayersCnt(game.Teams.Beta)	
			if inStudio == false then
				if sharedVars.AlphaLives.Value == 0 and sharedVars.BetaLives.Value == 0 then
					md.win(nil)
					break
				elseif sharedVars.AlphaLives.Value == 0 then
					md.win(game.Teams.Beta)
					break
				elseif sharedVars.BetaLives.Value == 0 then
					md.win(game.Teams.Alpha)
					break
				end
			end
		end
		
		if md.roundWinner == nil then
			if sharedVars.AlphaLives.Value > sharedVars.BetaLives.Value then
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
		return x.Stats.Kills.Value > y.Stats.Kills.Value
	end)
	for i, plr in ipairs(winners) do
		local block = workspace.Map.Final[tostring(i)]
		fpsCoreMd.spawn(plr, "precise", block.CFrame)
		local gui = block.gui.BillboardGui
		local fr  = gui.Frame
		fr.Plr.text.TextColor3 = md.matchWinner.TeamColor.Color
		sd.setProperty(fr.Plr, "Text", plr.Name)
		sd.setProperty(fr.P1, "Text", string.format("Kills: %d", plr.Stats.Kills.Value))
		sd.setProperty(fr.P2, "Text", "")
		gui.Enabled = true
	end
end

function md.getCreditInc(ds)
	return ds ~= nil and ds.expInc / 50 or 0	
end

return md
