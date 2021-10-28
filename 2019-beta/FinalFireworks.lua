local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local sv = wfc(rep, "SharedVars")
local ffc = game.FindFirstChild

local function fire(v)
	local sounds = wfc(v, "Sounds")
	local scp = v.Firework

	local pink = Color3.new(255, 105, 107)
	local green = Color3.new(43, 255, 85)
	local orange = Color3.new(255, 173, 58)
	local yellow = Color3.new(255, 232, 146)
	local bpink = Color3.new(255, 75, 255)
	local blue = Color3.new(52, 140, 255)
	local bblue = Color3.new(8, 210, 255)
	local red = Color3.new(255, 52, 55)

	local shortlifetime =  NumberRange.new(1,5)
	local longlifetime = NumberRange.new(1,10)

	local keypoints = {}
	 
	for i = 0,1,0.1 do
		local color = Color3.fromHSV(i,1,1)
		local keypoint = ColorSequenceKeypoint.new(i,color)
		table.insert(keypoints,keypoint)
	end

	local Randoms = ColorSequence.new(keypoints)
	while wait(math.random(1,7)) do
		scp.Launch.Sparks.Color = Randoms
		scp.Launch.Sparks.Enabled = true
		wait(0.2)
		scp.Launch.Sparks.Enabled = false
		sounds.Launch:Play()
		wait(1)
		
		scp.Sparks.Drag = (math.random(1,2))
		scp.Sparks.Lifetime = shortlifetime,longlifetime
		
		scp.Sparks.Color = Randoms
		scp.Smoke1.Color = Randoms
		scp.Smoke.Color = Randoms
		scp.Debris.Color = Randoms
		scp.Debris2.Color = Randoms
		scp.Sparks.Enabled = true
		scp.Smoke1.Enabled = true
		scp.Smoke.Enabled = true
		scp.Flash.Enabled = true
		scp.Flash2.Enabled = true
		scp.Debris.Enabled = true
		scp.Debris2.Enabled = true
		scp.PointLight.Enabled = true
		scp.PointLight.Color = pink
		
		
		if scp.Sparks.Drag>1 then
		sounds.Boom2:Play()
		else
		sounds.Boom:Play()
	end
		wait(0.5)
		
		scp.PointLight.Enabled = false
		scp.Sparks.Enabled = false
		scp.Smoke1.Enabled = false
		scp.Smoke.Enabled = false
		scp.Flash.Enabled = false
		scp.Flash2.Enabled = false
		scp.Debris.Enabled = false
		scp.Debris2.Enabled = false
	end
end

local function firework()
	local fireworkLib = wfc(workspace, "FinalFireworks")
	if fireworkLib then
		for _, v in ipairs(fireworkLib:GetChildren()) do
			spawn(function()
				fire(v)
			end)
		end
	end
end


local enabled = false
wfc(sv, "Phase").Changed:Connect(function(phase)
	if phase == "Showtime" then
		if not enabled then
			enabled = false
			firework()
		end
	end
end)
-- firework()







