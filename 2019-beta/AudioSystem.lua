local as = {}

local rep         = game.ReplicatedStorage
local wfc         = game.WaitForChild
local clone       = game.Clone
local destroy     = game.Destroy
local isA         = game.IsA
local evWait      = game.Changed.Wait
local connect     = game.Changed.Connect
local getChildren = game.GetChildren
local pwd         = game.GetFullName
local ranint      = math.random
local gm          = wfc(rep, "GlobalModules")
local printTable  = require(wfc(gm, "TableUtils")).printTable

local _sound = Instance.new("Sound")
local play   = _sound.Play

local soundsLib = wfc(rep, "Sounds")
local sounds    = {}
for _, v in ipairs(getChildren(soundsLib)) do
	if isA(v, "Sound") then
		assert(sounds[v.Name] == nil, string.format("duplicate sounds in soundLib %s", v.Name))
		sounds[v.Name] = v
	elseif isA(v, "Folder") then
		local t = {}
		for _, u in ipairs(getChildren(v)) do
			t[#t + 1] = u
		end
		sounds[v.Name] = t
	end
end
-- printTable(sounds)

-- put the 3d sound holder
local soundHolder3D        = Instance.new("Part", wfc(workspace, "NonHitbox"))
soundHolder3D.Name         = "SoundHolder3D"
soundHolder3D.Anchored     = true
soundHolder3D.Transparency = 1
soundHolder3D.CanCollide   = false
soundHolder3D.CFrame       = CFrame.new()

-- put the 2d sound folder
local soundHolder2D = Instance.new("Folder", rep)
soundHolder2D.Name  = "SoundHolder2D"

-- converts a sound name / table into an actual sound object
local function getSoundObject(sound)
	assert(sound, "sound is nil")
	local sound_ = sound
	if type(sound) == "string" then
		sound = sounds[sound] 
	end
	if type(sound) == "table" then
		sound = sound[ranint(1, #sound)]
	end
	assert(sound, string.format("%s is not found in rep.sounds", tostring(sound_)))
	assert(isA(sound, "Sound"), string.format("%s found in rep.sonuds but is not a sound", tostring(sound_)))
	sound = clone(sound)
	return sound	
end

-- @param sound: a sound object
-- @param pos: maybe a vector3, "2D", or an attachment
-- @prarm pref: the preference table
function as.play(sound, pos, prefs)
	sound = getSoundObject(sound)
	prefs = prefs or {}

	local holder 		-- the instance to be destroyed when the sound is stopped
	if typeof(pos) == "Vector3" then
		holder = Instance.new("Attachment")
		holder.Name = sound.Name
		holder.Position = pos
		sound.Parent = holder
		holder.Parent = soundHolder3D
	elseif pos == "2D" then
		holder = sound
		holder.Parent = soundHolder2D
	elseif isA(pos, "Attachment") then
		holder = sound
		holder.Parent = pos
	else
		error(string.format("audio system: invalid pos", tostring(pos)))
	end

	-- if pref.looped then
	-- 	connect(sound.Stopped, function()
	-- 		destroy(holder)
	-- 	end)
	-- else
		connect(sound.Stopped, function()
			destroy(holder)
		end)
		connect(sound.Ended, function()
			destroy(holder)
		end)
	-- end

	-- prefs!
	if prefs.looped then 			-- is prefs.looped is unset, the system will follow the property set in the sound. so it still might be looped. (although it will get destroyed once it ends.)
		sound.Looped = true
	end
	if prefs.volume then
		sound.Volume = prefs.volume
	end
	if prefs.fitLength then
		sound.PlaybackSpeed = sound.TimeLength / prefs.fitLength
	end

	play(sound)

	local adjuster = {
		sound  = sound,
		holder = holder,
	}
	function adjuster.destroy()
		destroy(holder)
	end
	return adjuster
end

-- just put sound somewhere
-- will not automatically desrtoy it
function as.put(sound, instance)
	assert(typeof(instance) == "Instance" or warn(instance, "is not an instance"))
	sound = getSoundObject(sound)
	sound.Parent = instance
	return sound
end

return as