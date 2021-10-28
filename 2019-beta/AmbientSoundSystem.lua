local rep       = game.ReplicatedStorage
local wfc       = game.WaitForChild
local ffc       = game.FindFirstChild
local pwd       = game.GetFullName
local gm        = wfc(rep, "GlobalModules")
local myMath    = require(wfc(gm, "Math"))
local rr3       = require(wfc(gm, "RotatedRegion3"))

local isPointInPart = rr3.isPointInPart
local newCf = CFrame.new
local isA   = game.IsA
local newV3 = Vector3.new
local invCf = CFrame.new().inverse
local sgn   = math.sign
local clamp = math.clamp

local runser = game:GetService("RunService")
local hb     = runser.Heartbeat
local evWait = game.Changed.Wait

local cam = workspace.CurrentCamera

-- speed of the linear fade-in/out
local sp = 1

-- preload all ambient sounds
local ambientBoxesLib  = wfc(workspace, "AmbientBoxes")
local ambientSoundsLib = wfc(ambientBoxesLib, "AmbientSounds")
local ambientSounds    = {}
local ambientSoundDefVolume = {}
for _, sound in ipairs(ambientSoundsLib:GetChildren()) do
	assert(isA(sound, "Sound"))
	local ambientName = sound.Name
	ambientSounds[ambientName]         = sound
	ambientSoundDefVolume[ambientName] = sound.Volume
	sound.Volume = 0
	sound.Looped = true
	sound:Play()

	-- print("loaded ambient sound", ambientName)
end
-- game:GetService("ContentProvider"):PreloadAsync(ambientSounds)

-- preload all ambient boxes
local ambientBoxes        = {}     -- just an array of boxes
local ambientVolumes      = {}		-- ambientName -> volume (curr)
local ambientBoxesTouched = {}  -- ambientName -> true / false
for _, v in ipairs(ambientBoxesLib:GetDescendants()) do
	if isA(v, "BasePart") then
		assert(v.Shape == Enum.PartType.Block, "only rectangular bricks are supported"..tostring(v.Shape))
		assert(v.Anchored, string.format("ambientSoundSystem: %s is not Anchored", pwd(v)))
		assert(v.CanCollide == false, string.format("ambientSoundSystem: %s is collidable", pwd(v)))
		local ambientName               = v.Name
		ambientBoxes[#ambientBoxes + 1] = v
		ambientVolumes[ambientName]     = 0

		-- print("loaded ambient box", v)
	end
end
if #ambientBoxes > 100 then
	warn("AmbientSoundSystem: more than 100 ambient boxes, count =", #ambientBoxes)
end

spawn(function()
	local lastTick = tick()
	while evWait(hb) do
		local now = tick()
		local dt  = now - lastTick
		-- O(#ambientBoxes) 
		ambientBoxesTouched = {}
		for _, v in ipairs(ambientBoxes) do
			local ambientName = v.Name
			if isPointInPart(cam.CFrame.p, v) then
				ambientBoxesTouched[ambientName] = true
				-- print("in", ambientName)
			else
				-- print("not in", ambientName)
			end
		end
		for ambientName, volume in pairs(ambientVolumes) do
			local volume_ = ambientBoxesTouched[ambientName] and 1 or 0
			if volume ~= volume_ then
				local dir = sgn(volume_ - volume)
				volume    = clamp(volume + dir * dt * sp, 0, 1)
				ambientVolumes[ambientName]       = volume
				ambientSounds[ambientName].Volume = volume * ambientSoundDefVolume[ambientName]

				-- print(string.format("%s %s", dir == 1 and "entered" or "exited", ambientName))
			end
		end

		lastTick = now
	end
end)

print("Ambient Sound system setup")
