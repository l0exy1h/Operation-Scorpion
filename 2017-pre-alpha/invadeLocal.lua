-- local handler for invade
-- gui prompts
-- make request to servers
---- bomb drop
---- bomb pick up
---- bomb defuse
---- bomb plant

local m = {}

local plrs = game.Players
local lp = plrs.LocalPlayer
local rep = game.ReplicatedStorage
local events = rep:WaitForChild("Events")
local actions = events:WaitForChild("Actions")
local hudEvent = events:WaitForChild("HUD")

local settings = rep:WaitForChild("Settings")
local keyBinding = require(settings:WaitForChild("KeyBinding"))

local gm = rep:WaitForChild("GlobalModules")
local sd = require(gm:WaitForChild("ShadedTexts"))
local fpsUtils = require(gm:WaitForChild("FpsUtils"))	-- local utils for fps
local invade = require(gm:WaitForChild("Invade"))
local sharedUtils = require(gm:WaitForChild("SharedUtils"))

local sv = rep:WaitForChild("SharedVars")
local matchRemote = rep.Events:WaitForChild("MatchRemote") -- for gamemodes
local loc = workspace:WaitForChild("Map"):WaitForChild("BombSite")	-- a folder containing all the locations

local hb = game:GetService("RunService").Heartbeat


local function bombSpottedAndNear(bomb, r)
	return fpsUtils.onScreenWithinRange(bomb, 75)
		and  sharedUtils.withinCharDistance(lp, bomb, r)
end

local function canPickUpBombQ()
	return fpsUtils.aliveQ(lp)
		and lp.Team == sv.Atk.Value
		and sv.Bomber.Value == nil
		and sv.Bomb.Value ~= nil
		and sv.BombPlantedSite.Value == nil
		and bombSpottedAndNear(sv.Bomb.Value, invade.maxBombPickUpDistance)
end

local function canDropBombQ()
	return fpsUtils.aliveQ(lp) and sv.Bomber.Value == lp
end

local planting = false
local defusing = false

function m.setup()
	
	-- actions
	------------------------------------------
	
	-- drop / pick
	actions:WaitForChild("DropOrPick").Event:connect(function()
		if canDropBombQ() then
			-- drop
			matchRemote:FireServer("requestDroppingBomb")
			--matchRemote:FireServer("cancelPlanting")
			
		else
			-- pick up
			if canPickUpBombQ() then
				matchRemote:FireServer("requestPickingUpBomb")
			end
		end
	end)
	
	-- pre: bombPlantedSite will change upon bomb planted
	sv.BombPlantedSite.Changed:connect(function()
		planting = false
	end)
	
	-- pre: bomb will change to nil upon bomb defused
	sv.Bomb.Changed:connect(function()
		defusing = false
	end)
	
	local function cancelPlantingAndDefusing()
		if planting then 
			planting = false 
			matchRemote:FireServer("cancelPlanting") 
		end
		if defusing then 
			defusing = false
			matchRemote:FireServer("cancelDefusing") 
		end
	end
	
	actions:WaitForChild("Movement").Event:connect(cancelPlantingAndDefusing)
	actions:WaitForChild("Shooting").Event:connect(cancelPlantingAndDefusing)
	actions:WaitForChild("ADS").Event:connect(cancelPlantingAndDefusing)
	events:WaitForChild("PlayerRektLocally").Event:connect(function()
		planting, defusing = false, false
	end)
	
	-- plant and defuse 
	local currentSiteIn = nil

	spawn(function()		-- optimization
		while hb:wait() do
			local currentSiteInNew = nil
			for _, _site in ipairs(loc:GetChildren()) do
				if sharedUtils.inShape(lp.Character.HumanoidRootPart, _site) then
					currentSiteInNew = _site
				end
			end
			currentSiteIn = currentSiteInNew
		end
	end)
	actions:WaitForChild("PlantOrDefuse").Event:connect(function()
		
		if fpsUtils.aliveQ(lp) then
			if lp.Team == sv.Atk.Value then
				-- attempt to plant
				local site = currentSiteIn
				
				if site then
					if planting then	-- toggle to cancel
						planting = false
						matchRemote:FireServer("cancelPlanting")
						
					elseif sv.BombPlantedSite.Value == nil
						and sv.Bomber.Value == lp then
						
						matchRemote:FireServer("requestInitiatingPlanting", {site})
						planting = true
					end
				end
				
			elseif lp.Team == sv.Def.Value then

				if sv.Bomb.Value then

					-- attempt to defuse
					if defusing then		-- toggle to defuse
						defusing = false
						matchRemote:FireServer("cancelDefusing")
					
					elseif bombSpottedAndNear(sv.Bomb.Value, invade.maxBombDefuseRange) then
							
						matchRemote:FireServer("requestInitiatingDefusing")
						defusing = true
					end
				end
			end
		end
	end)
	
	-- moving guis: site and bomb
	-----------------------------------------------
	-- site markers
	local SiteMarker = require(script:WaitForChild("SiteMarker"))
	local siteMarker = {}
	for _, site in ipairs(workspace.Map.BombSite:GetChildren()) do
		siteMarker[site.Name] = SiteMarker.new(site)
	end
	local function updateSiteMarkers()
		if sv.BombPlantedSite.Value then
			for _, site in ipairs(workspace.Map.BombSite:GetChildren()) do
				if site ~= sv.BombPlantedSite.Value then
					siteMarker[site.Name]:setPlantedOpacity(0)
				end
			end
		else
			for _, site in ipairs(workspace.Map.BombSite:GetChildren()) do
				siteMarker[site.Name]:setPlantedOpacity(1)
			end
		end
	end
	updateSiteMarkers()	-- for qj
	sv.BombPlantedSite.Changed:connect(updateSiteMarkers)
	
	-- bomb marker
	local BombMarker = require(script:WaitForChild("BombMarker"))
	local bombMarker = nil
	local function newBombMarker(newHost)	
		if bombMarker then
			bombMarker:destroy()
		end
		if newHost and fpsUtils.getAtkDefSide(lp.Team) == "Atk" then
			bombMarker = BombMarker.new(newHost)
		end
	end
	
	-- listen to bomb changes
	newBombMarker(sv.Bomb.Value)	-- for qj
	sv.Bomb.Changed:connect(function()
		newBombMarker(sv.Bomb.Value)
	end)
	
	-- listen to bomber changes
	--local oldBomberName = sv.Bomber.Value and sv.Bomber.Value.Name or nil
	if sv.Bomber.Value and fpsUtils.aliveQ(sv.Bomber.Value) then	-- for qj
		newBombMarker(sv.Bomber.Value.Character.Head)
	end
	sv.Bomber.Changed:connect(function()
		if sv.Bomber.Value and fpsUtils.aliveQ(sv.Bomber.Value) then
			newBombMarker(sv.Bomber.Value.Character.Head)

			--[[-- gui: bomb pick up
			local plrName = fpsUtils.getAtkDefSide(lp.Team) == "Def" and "enemy" or sv.Bomber.Value.Name
			hudEvent:Fire("showMsg", {"Msg1", string.format("Bomb picked up by %s", plrName), 2})
		elseif sv.Bomber.Value == nil and oldBomberName then

			-- gui: drop bomb
			local plrName = fpsUtils.getAtkDefSide(lp.Team) == "Def" and "enemy" or (oldBomberName or "teammate")
			hudEvent:Fire("showMsg", {"Msg1", string.format("Bomb dropped by %s", plrName), 2})--]]
		end
		--oldBomberName = sv.Bomber.Value and sv.Bomber.Value.Name or nil
	end)

	-- static huds
	----------------------------------------------
	
	-- gui for can pick up
	spawn(function()
		local canPickUpBomb, canPickUpBombNew = false, false
		while hb:wait() do
			canPickUpBombNew = canPickUpBombQ()
			if canPickUpBombNew and not canPickUpBomb then
				hudEvent:Fire("showMsg", {"Msg2", "Pick Up"})
			elseif not canPickUpBombNew and canPickUpBomb then
				hudEvent:Fire("hideMsgEarly", {"Msg2"})
			end
			canPickUpBomb = canPickUpBombNew
		end
	end)

	-- gui for can plant
	local function canPlantQ()
		return fpsUtils.aliveQ(lp) 
			and lp.Team == sv.Atk.Value 
			and currentSiteIn 
			-- and not planting
			and sv.BombPlantedSite.Value == nil 
			and sv.Bomber.Value == lp
	end
	spawn(function()
		local canPlant, canPlantNew = false, false
		while hb:wait() do
			canPlantNew = canPlantQ()
			if canPlantNew and not canPlant then
				hudEvent:Fire("showMsg", {"Msg2", string.format("Hold %s to plant", keyBinding.PlantBomb.Name)})
			elseif not canPlantNew and canPlant then
				hudEvent:Fire("hideMsgEarly", {"Msg2"})
			end
			canPlant = canPlantNew
		end
	end)
	
	-- gui for canDefuse
	local function canDefuseQ()
		return fpsUtils.aliveQ(lp) 
			and lp.Team == sv.Def.Value
			and sv.Bomb.Value
			and bombSpottedAndNear(sv.Bomb.Value, invade.maxBombDefuseRange)
	end
	spawn(function()
		local canDefuse, canDefuseNew = false, false
		while hb:wait() do
			canDefuseNew = canDefuseQ()
			if canDefuseNew and not canDefuse then
				hudEvent:Fire("showMsg", {"Msg2", string.format("Hold %s to defuse", keyBinding.DefuseBomb.Name)})
			elseif not canDefuseNew and canDefuse then
				hudEvent:Fire("hideMsgEarly", {"Msg2"})
			end
		end
	end)
	
	-- gui for planting/defusing {initiated, cancelled, completed}
	-- and for bomb pick up / drop
	matchRemote.OnClientEvent:connect(function(func, args)		
		if func == "plantingInitiated" then
			local planter = args[1]
			local site = args[2]
			if sv.WatchedPlr.Value == planter then
				hudEvent:Fire("showMsg", {"Msg2", "Planting... Don't move", 2})
				hudEvent:Fire("beginBar", {invade.plantTime, 1})
			else
				hudEvent:Fire("showMsg", {"Msg1", string.format("Teammate %s is planting at Site %s", planter.Name or "", site.Name), 1})
			end
			
		elseif func == "plantingCancelled" then
			local planter = args[1]
			local site = args[2]
			if sv.WatchedPlr.Value == planter then
				hudEvent:Fire("showMsg", {"Msg2", "Planting Cancelled", 2})
				hudEvent:Fire("hideBarEarly")
			else
				hudEvent:Fire("showMsg", {"Msg1", string.format("Teammate %s has stopped planting at Site %s", planter.Name or "", site.Name), 1})
			end
			
		elseif func == "bombPlanted" then
			local planter = args[1]
			local site = args[2]
			if sv.WatchedPlr.Value == planter then
				hudEvent:Fire("showMsg", {"Msg2", "Planting Completed", 2})
			else
				hudEvent:Fire("showMsg", {"Msg1", string.format("Bomb planted at Site %s by %s", site.Name, planter.Name or "teammate"), 2})
			end
		
		elseif func == "defusingInitiated" then
			local defuser = args[1]
			if sv.WatchedPlr.Value == lp then
				hudEvent:Fire("showMsg", {"Msg2", "Defusing... Don't Move", 1})
				hudEvent:Fire("beginBar", {invade.defusingTime, 1})
			else
				hudEvent:Fire("showMsg", {"Msg1", string.format("Teamnate %s is defusing the bomb", defuser.Name), 1})
			end
		
		elseif func == "defusingCancelled" then
			local defuser = args[1]
			if sv.WatchedPlr.Value == defuser then
				hudEvent:Fire("showMsg", {"Msg2", "Defusing Cancelled", 2})
				hudEvent:Fire("hideBarEarly")
			else
				hudEvent:Fire("showMsg", {"Msg1", string.format("Teammate %s has stopped defusing the bomb", defuser.Name or ""), 1})
			end			
		
		elseif func == "bombDefused" then
			local defuser = args[1]
			if sv.WatchedPlr.Value == defuser then
				hudEvent:Fire("showMsg", {"Msg2", "Defusing Completed", 2})
			else
				hudEvent:Fire("showMsg", {"Msg1", string.format("Bomb defused by %s", defuser.Name or "teammate"), 2})
			end
		
		elseif func == "bombDropped" then
			local dropper = args[1]
			local plrName = fpsUtils.getAtkDefSide(lp.Team) == "Def" and "enemy" or (tostring(dropper) or "teammate")
			hudEvent:Fire("showMsg", {"Msg1", string.format("Bomb dropped by %s", plrName), 2 })
			
		elseif func == "bombPickedUp" then
			local planter = args[1]
			local plrName = fpsUtils.getAtkDefSide(lp.Team) == "Def" and "enemy" or (tostring(planter) or "teammate")
			hudEvent:Fire("showMsg", {"Msg1", string.format("Bomb picked up by %s", plrName), 2})
		end
	end)
end

return m