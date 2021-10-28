-- client side:
-- just put it in dyn env client
----------------------

local rep   = game.ReplicatedStorage
local wfc   = game.WaitForChild
local plrs  = game.Players
local ffc   = game.FindFirstChild
-- local tween = requireGm("Tweening").tween
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

do-- tweenModelCf
	local pwd    = game.GetFullName
	local format = string.format
	local hb     = game:GetService("RunService").Heartbeat
	local evwait = game.Changed.Wait
	local spcf   = Instance.new("Model").SetPrimaryPartCFrame
	local myMath = requireGm("Math")
	local cfLerp = myMath.cfLerp
	local clamp  = myMath.clamp
	function tweenModelCf(model, at, cf1)
		assert(model.PrimaryPart, format('try to call tweenModelCf with %s but it does not have a primary part', pwd(model)))
		local self = {}

		local cf0     = model.PrimaryPart.CFrame
		local running = true
		local t       = 0
		spawn(function()
			while running do
				t = t + evwait(hb)

				local p = clamp(t / at, 0, 1)
				spcf(model, cfLerp(cf0, cf1, p))

				if p == 1 then
					running = false
				end
			end
		end)

		function self.cancel()
			running = false
		end

		return self
	end
end

local doors = {}
do-- scanning the map for all doors
	local isPointInPart = requireGm("RotatedRegion3").isPointInPart
	local tweenModelCf  = tweenModelCf
	local destroy       = game.Destroy
	local getC          = game.GetChildren
	local format        = string.format
	local pwd           = game.GetFullName
	local isA           = game.IsA
	local connect       = game.Changed.Connect
	local play          = requireGm("AudioSystem").play
	local function waitForField(a, key)
		if a[key] then return a[key] end
		local st, now = tick(), nil
		repeat 
			now = tick()
			if now - st > 5 then
				warn("waiting for", pwd(a), ".", key, "for more than 5 seconds")
			end
			wait(0.1)
		until a[key]
		if now - st > 5 then
			warn("finally got", pwd(a), ".", key)
		end
		return a.key
	end
	for _, v in ipairs(workspace:GetDescendants()) do
		if v.Name == "SlidingDoor" then    -- part or not?
			local door = {
				open = false,
			}

			print("loading sliding door", pwd(v))
			local open, closed = wfc(v, "Open"), wfc(v, "Closed")
			local openCf       = waitForField(open, "PrimaryPart").CFrame
			local closedCf     = waitForField(closed, "PrimaryPart").CFrame
			destroy(open)
			local model        = closed

			local dur = wfc(v, "Duration").Value

			local detectionBoxes = {}
			-- do-- get detection boxes
			-- 	local function onChildAdded(u)
			-- 		if isA(u, "BasePart") then
			-- 			detectionBoxes[#detectionBoxes + 1] = u
			-- 			u.Transparency = 1
			-- 			assert(u.Anchored, format("sliding door: detection box %s is not Anchored", pwd(u)))
			-- 			assert(not u.CanCollide, format("sliding door: detection box %s is CanCollide", pwd(u)))
			-- 		end
			-- 	end
			-- 	for _, u in ipairs(getC(v)) do
			-- 		onChildAdded(u)
			-- 	end
			-- 	connect(v.ChildAdded, onChildAdded)
			-- end
			detectionBoxes[#detectionBoxes + 1] = wfc(workspace, "slidedetect")
			detectionBoxes[1].Transparency = 1

			local tw = nil
			local s = nil
			function door.changeState(open)
				door.open = open
				if tw then
					tw.cancel()
				end
				if s then
					s.destroy()
				end
				print("changed to ", open)
				tw = tweenModelCf(model, dur, open and openCf or closedCf)
				s = play("SlidingDoor", openCf.p)
			end

			function door.shouldOpenQ()
				for _, plr in ipairs(getC(plrs)) do
					if plr.Character and ffc(plr.Character, "Head") then
						for _, detectionBox in ipairs(detectionBoxes) do
							if isPointInPart(plr.Character.Head.Position, detectionBox) then
								return true
							end
						end
					end
				end
				return false
			end

			doors[#doors + 1] = door
			print("loaded sliding door", pwd(v))
		end
	end
end

do -- start the detection thread
	local hb     = game:GetService("RunService").Heartbeat
	local evwait = game.Changed.Wait

	spawn(function()
		while evwait(hb) do
			for _, door in ipairs(doors) do
				local shouldOpen = door.shouldOpenQ()
				if shouldOpen ~= door.open then
					door.changeState(shouldOpen)
				end
			end
		end
	end)
end