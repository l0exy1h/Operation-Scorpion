local ts = game:GetService("TeleportService")
local Data = nil
ts.LocalPlayerArrivedFromTeleport:connect(function(gui, data)
	warn("arrived from teleportation!")
	Data = data
end)

game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
game.StarterGui:SetCore("TopbarEnabled", false)
spawn(function()
	wait(5)
	local resetBindable = Instance.new("BindableEvent")
	resetBindable.Event:connect(function()
	  game:GetService("TeleportService"):Teleport(1436977294)
	end)
	game.StarterGui:SetCore("ResetButtonCallback", resetBindable)
end)

local lp = game.Players.LocalPlayer
local rep = game.ReplicatedStorage

local lpScripts             = lp:WaitForChild("PlayerScripts")
local animatedPlayer        = lpScripts:WaitForChild("PlayerAnimation"):WaitForChild("AnimatedPlayer")
--require(animatedPlayer)		-- set up OnInvoke first
local animatedPlayerDataBF  = animatedPlayer:WaitForChild("GetData")
--animatedPlayerDataBF.Parent = nil

local gm         = rep:WaitForChild("GlobalModules")
local fpsUtils   = gm:WaitForChild("FpsUtils") 
-- require(fpsUtils)					-- set up OnInvoke first
local fpsUtilsBF = fpsUtils:WaitForChild("GetData")
--fpsUtilsBF.Parent = nil

local arrivedEvent  = rep:WaitForChild("Arrived")
--arrivedEvent.Parent = nil

local inStudio = script:WaitForChild("LocalInStudio").Value

warn(inStudio, "test linked script")
if inStudio then
	warn("Studio Mode")
	wait(2)
	local data = {}
	data.alphaInit = {lp.Name}
	data.betaInit = {}
	--data.alphaInit = {"Player1"}
	--data.betaInit = {"Player2"}
	data.initPlrCnt = #data.alphaInit + #data.betaInit
	--data.mapName = "Yacht"
	--data.weather = "Clear Day"
	--data.fullMapName = data.mapName.."/"..data.weather
	data.placeDesc = "test place"
	data.gamemode = "Invade"
	data.joinType = "freshStart" 
	data.accessCode= "test"

	data.plrData = {
		[lp.Name] = {
		--Player1 = {
			Secondary = {
				name = "USP.45",
				attcList = {
					Magazine = "USP Standard Magazine",
					Muzzle = "No Muzzle",
					Sight  = "No Sight",
				},
			},
			Primary = {
				name = "M4A1 Carbine",
				attcList = {
					Barrel = "M4 Long Barrel",
					Magazine = "M4 Standard Magazine",
					Stock = "M4 Standard Stock",
					Muzzle = "No Muzzle",
					Sight = "SM REFLEX Sight",
					Grip = "No Grip",
					Handle = "M4 Standard Handle",
				},
			},
		},
		--[[Player2 = {
			Primary = { 
				name = "M4A1 Carbine",
				attcList = {
					Barrel = "RIS Barrel",
					Handle = "M4 Standard Handle",
					Magazine = "Extended Magazine",
					Stock  = "M4 Standard Stock",
					Sight  = "TRIJC ACOG Sight",
					Muzzle = "No Muzzle",
					Grip   = "MOE Vertical Grip",
				}
			},
			Secondary = {
				name = "USP.45",
				attcList = {
					Magazine = "USP Standard Magazine",
					Muzzle = "No Muzzle",
					Sight  = "No Sight",
				},
			},
		},
		Player3 = {
			Primary = {
				name = "SCAR-L CQC",
				attcList = {
					Magazine = "SCAR-L Standard Magazine",
					Sight = "SCAR-L Iron Sight I",
					Muzzle = "No Muzzle",
					Grip = "No Grip",
				}, 
			},
			Secondary = {
				name = "USP.45",
				attcList = {
					Magazine = "USP Standard Magazine",
					Muzzle = "No Muzzle",
					Sight  = "No Sight",
				},
			},
		},
		Player4 = {
			Primary = {
				name = "SCAR-L CQC",
				attcList = {
					Magazine = "SCAR-L Standard Magazine",
					Sight = "SCAR-L Iron Sight I",
					Muzzle = "No Muzzle",
					Grip = "No Grip",
				}, 
			},
			Secondary = {
				name = "USP.45",
				attcList = {
					Magazine = "USP Standard Magazine",
					Muzzle = "No Muzzle",
					Sight  = "No Sight",
				},
			},
				},
		Player5 = {
			Primary = {
				name = "SCAR-L CQC",
				attcList = {
					Magazine = "SCAR-L Standard Magazine",
					Sight = "SCAR-L Iron Sight I",
					Muzzle = "No Muzzle",
					Grip = "No Grip",
				}, 
			},
			Secondary = {
				name = "USP.45",
				attcList = {
					Magazine = "USP Standard Magazine",
					Muzzle = "No Muzzle",
					Sight  = "No Sight",
				},
			},
		},--]]
	}	
	
	--arrivedEvent:FireServer("initData", data)
	Data = data
end

-- send the info the the scripts that need data
repeat 
	wait()
	print("wait 4 teleportation data")
until Data
require(game.ReplicatedStorage:WaitForChild("GlobalModules"):WaitForChild("Loading")).loaded("TeleportationData")

if Data.joinType == "quickJoin" then
	--lp:WaitForChild("Sync").Value            = false
	script:WaitForChild("QuickJoined").Value = true	
else
	--lp:WaitForChild("Sync").Value            = true
	script:WaitForChild("QuickJoined").Value = false
end
script.QuickJoined.Parent = lp				-- other scripts wait for this booleanvalue

-- those data is read only
-- should not be public since it contains customizations
-- just have them sent to specific modules
require(fpsUtils)					-- set up OnInvoke first
require(animatedPlayer)	  -- set up OnInvoke first

if Data.joinType == "freshStart" then
	-- push data to local scripts 
	animatedPlayerDataBF:Invoke("setEntireData", {Data})
	fpsUtilsBF:Invoke(Data)
	print("freshstart: data pushed to client modules")
	-- send data to server
	arrivedEvent:FireServer("initData", Data)
else
	arrivedEvent:FireServer("appendData", Data)
end
print("data uploaded to server")

arrivedEvent.OnClientEvent:connect(function(func, args)
	print("received data from server")
	if func == "appendPlrData" then
		local plrName       = args[1]
		local singlePlrData = args[2]
		animatedPlayerDataBF:Invoke("appendPlrData", {plrName, singlePlrData})
	elseif func == "setEntireData" then
		local data = args[1]
		animatedPlayerDataBF:Invoke("setEntireData", {data})
		fpsUtilsBF:Invoke(data)
	end	
end)

arrivedEvent.Parent = nil
fpsUtilsBF.Parent = nil
animatedPlayerDataBF.Parent = nil