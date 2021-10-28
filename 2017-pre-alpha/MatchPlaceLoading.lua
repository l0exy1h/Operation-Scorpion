local loadingGUI = script.Parent
loadingGUI:WaitForChild("Frame").Visible = true

-- configs
--------------------------------------

local waitTable = {
	TeleportationData = false,
	PlayerAnimation   = false,
	AnimatedPlayer    = false,
	CompleteDataTable = false,
	Decals            = false
}
local function countDictionary(dict)
	local cnt = 0
	for key, value in pairs(dict) do
		cnt = cnt + 1
	end
	return cnt
end
local curr       = 0
local totalGoal  = countDictionary(waitTable)
local goal       = 0 -- totalGoal > 0 and 1 / totalGoal or 1
local defaultT   = 5
--local T          = 2
local startTime  = tick()
local received   = 0 

-- listeners
--------------------------------------
local rep = game.ReplicatedStorage
local events = rep:WaitForChild("Events")
local loadingEvent = events:WaitForChild("Loading")

local function onScriptLoaded(s)
	local name = nil
	
	if type(s) == "string" then
		name = s
	else
		name = s.Name
	end
	
	if waitTable[name] == false then
		warn("script loaded", name)
		received         = received + 1
		waitTable[name]  = true
		goal             = goal + 1.0 / totalGoal
		--T    = defaultT
		startTime = tick()
	end
end
for _, s in ipairs(loadingEvent:GetChildren()) do
	onScriptLoaded(s)
end
loadingEvent.ChildAdded:connect(onScriptLoaded)
 
-- animation
-------------------------------------
local gm  = rep:WaitForChild("GlobalModules")
local ga  = require(gm:WaitForChild("GeneralAnimation"))
local rs  = game:GetService("RunService").RenderStepped
local bar = loadingGUI.Frame:WaitForChild("Bar"):WaitForChild("inner")

spawn(function()
	local function f(p)
		return 1 - (1 - p) * (1 - p)
	end
	startTime = tick()
	while rs:wait() and curr < 1 do
		local t  = tick() - startTime
		local p  = math.min(t / defaultT, 1) 
		curr     = curr + (goal - curr) * f(p)
		bar.Size = UDim2.new(curr, 0, 1, 0)
	end	
	
	warn("received = ", received)	
	
	wait(0.5)
	local fadeoutT = 1
	ga.animateProperty(loadingGUI.Frame, "BackgroundTransparency", 1, fadeoutT, "sin2")
	ga.animateProperty(loadingGUI.Frame.Bar, "ImageTransparency", 1, fadeoutT, "sin2")
	ga.animateProperty(loadingGUI.Frame.Bar.inner, "ImageTransparency", 1, fadeoutT, "sin2")
	ga.animateProperty(loadingGUI.Frame.Logo, "ImageTransparency", 1, fadeoutT, "sin2")
	wait(fadeoutT)
	loadingGUI.Enabled = false
end)

-- decals and 3d objects
-----------------------------------
spawn(function()
	repeat
		wait(0.1)
		print(game.ContentProvider.RequestQueueSize)
	until game.ContentProvider.RequestQueueSize < 1
	onScriptLoaded("Decals")
end)

-- skip after 15 seconds
spawn(function()
	wait(15)
	local msg = Instance.new("TextLabel")
	msg.Position = UDim2.new(0.4, 0, 0.51, 66)
	msg.Size     = UDim2.new(0.2, 0, 0.1, 0)
	msg.BackgroundTransparency = 1
	msg.TextColor3 = Color3.fromRGB(220, 220, 220)
	msg.TextScaled = false
	msg.Font = Enum.Font.SourceSansLight
	msg.TextSize = 25
	msg.TextWrapped = true
	msg.TextXAlignment = Enum.TextXAlignment.Center
	msg.TextYAlignment = Enum.TextYAlignment.Top
	msg.Text = "CLICK TO SKIP"
	msg.Parent = loadingGUI.Frame
	
	local lp = game.Players.LocalPlayer
	local mouse = lp:GetMouse()
	mouse.Button1Down:connect(function()
		loadingGUI.Enabled = false
	end)
end)