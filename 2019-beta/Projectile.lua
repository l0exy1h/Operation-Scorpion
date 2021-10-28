local projectile = {}

local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

do -- getMatDrag
	local huge = 100
	local conversion = {
		Plastic       = "Stone",
		Wood          = "Wood",
		Slate         = "Stone",
		Concrete      = "Stone",
		CorrodedMetal = "Metal",
		DiamondPlate  = "Metal",
		Foil          = "Stone",
		Grass         = "Grass",
		Ice           = "Ice",
		Marble        = "Stone",
		Granite       = "Stone",
		Brick         = "Stone",
		Pebble        = "Stone",
		Sand          = "Sand",
		Fabric        = "Stone",
		SmoothPlastic = "Stone",
		Metal         = "Metal",
		WoodPlanks    = "Wood",
		Cobblestone   = "Stone",
		Water         = "Water",
		Rock          = "Stone",
		Glacier       = "Ice",
		Snow          = "Snow",
		Sandstone     = "Stone",
		Mud           = "Mud",
		Basalt        = "Stone",
		CrackedLava   = "Mud",
		Neon          = "Stone",
		Glass         = "Stone",
		Asphalt       = "Stone",
		LeafyGrass    = "Grass",
		Salt          = "Ice",
		Limestone     = "Stone",
		Pavement      = "Stone",
		Air           = "Air",
	}
	local presets = {
		Stone = 8,
		Metal = 7,
		Ice   = 4,
		Wood  = 2,
		Glass = 0,
		Grass = 0,
		Water = 0,
		Air   = 0,
		Flesh = 0,
	}
	local matDrags = {}
	for _, v in ipairs(Enum.Material:GetEnumItems()) do
		local matName = v.Name
		matDrags[v.Value] = conversion[matName] and presets[conversion[matName]] or huge
	end
	local terrain = wfc(workspace, "Terrain")
	local water = Enum.Material.Water
	local ido   = game.IsDescendantOf
	local chars = wfc(workspace, "Chars")
	function projectile.getMatDrag(hit, mat)
		local hitName = hit and hit.Name
		if hitName == "u_glass" then
			return huge
		elseif hitName == "glass" then
			return presets.Glass
		elseif hit == terrain and mat ~= water then
			return huge
		elseif ido(hit, chars) then
			return presets.Flesh
		else
			return matDrags[mat.Value] or huge
		end
	end
end

do -- getVelLeft: get the percentage of speed left after penetration
	local sqrt = math.sqrt
	local max  = math.max
	local getMatDrag = projectile.getMatDrag
	--@param hit (part)
	--@param mat (material)
	--@param pen (num): penetration power
	--@param l (num): impactLeft length
	--@param v (number): speed before penetration
	function projectile.getVelLeft(hit, mat, pen, l, v)
		v = typeof(v) == "Vector3" and v.magnitude or v
		local m = pen / 100
		local F = getMatDrag(hit, mat) * 10000
		return sqrt(max(0, 1 - (2 * F * l) / (m * v * v)))
	end
end

do -- .new
	local clone = game.Clone
	local newCf = CFrame.new
	local newV3 = Vector3.new
	local newBrickColor = BrickColor.new
	local dot = newV3().Dot
	local huge = math.huge
	local projTemp = wfc(script, "Proj")
	local tmpHolder = wfc(workspace, "Projectiles")
	local raycastWl2pts = requireGm("Raycasting").raycastWl2pts
	local showV3 = requireGm("Raycasting").showV3
	local destroy = game.Destroy
	local getVelLeft = projectile.getVelLeft
	local out = CFrame.new(0, 10000, 0)

	--@param [args.width] :
	--@param [args.length] :
	--@param [args.grav] : a number indicating the gravity
	--@param [args.drag] : a num between [0, 1]
	--@param [args.pen] : [0, 20]
	--@param [args.maxDist] : 
	--@param [args.rayWl] : whitelist
	--@param [args.onHit] : callback function
	function projectile.new(p0, v0, args)
		local self = {}

		local pt = clone(projTemp) -- use parts as beams
		pt.Parent = nil
		wfc(pt, "AntiG").Force = newV3(0, workspace.Gravity, 0)

		-- not replicated. should upload this to server
		local w = args.width or pt.Size.X
		local l = args.length or pt.Size.Z
		pt.Size = newV3(w, w, l) 	
		if args.color then
			pt.BrickColor = newBrickColor(args.color)
		end

		local vel = v0 -- velocity (this frame)
		local bv = wfc(pt, "BodyVelocity")
		bv.Velocity = v0
		pt.CFrame = newCf(p0, p0 + v0)  -- set by body movers not us
		local lastPos = pt.CFrame.p  -- for raycasting
		local lastCf  = pt.CFrame  -- for tracking distance

		-- invisible when created
		pt.Transparency = 1

		local grav = newV3(0, -(args.grav or 0) * workspace.Gravity, 0)
		local drag = (args.drag or 0) / 100

		local sunk = false
		local impactLeft = 1
		local pen = args.pen or 0  -- the power of penetration
		local distSum = 0
		local maxDist = args.maxDist or 1000   -- use dist as lifetime
		local rayWl = args.rayWl or {workspace}
		local onHit = args.onHit
		local showDist = args.showDist or 2

		local pt2_ = nil
		function self.replaceWithOnlinePart(pt2)
			pt2_ = pt2
		end

		local function destroyQ()
			return sunk or vel.magnitude < 10 or distSum > maxDist
		end
		function self.destroy()
			self = nil
			if pt2_ then
				destroy(bv)
				pt.CFrame = out --pt.CFrame + vel.Unit * 10000
				-- pt.Anchored = true
				-- the part will be deleted automatically by the server
			else
				destroy(pt)
			end
			return "destroyed"
		end

		local rc = 0
		function self.step(dt)
			if pt.Parent == nil then
				pt.Parent = tmpHolder
			end
			if pt.Transparency == 1 and distSum > showDist then
				pt.Transparency = 0
			end

			-- calc cf and vel for this frame
			vel = (vel + grav * dt) * (1 - drag * dt)
			distSum = distSum + (pt.CFrame.p - lastCf.p).magnitude

			-- raycast the objects in between
			do
				local p0 = lastPos   -- not pt.CFrame.p, to ensure the segments are connected
				local p3 = p0 + vel * dt
				lastPos = p3
				local originalDir = p3 - p0

				while not destroyQ() do

					-- raycast
					local hit, p1, p2, dist, normal, mat = raycastWl2pts(p0, p3 - p0, rayWl)

					-- rc = rc+1
					-- if p1 then showV3(p1, {name = "in"..rc, brickColor = "Bright red"}) end
					-- if p2 then showV3(p2, {name = "out"..rc, brickColor = "Bright yellow"}) end
					-- if p0 then showV3(p0, {name = "start"..rc, brickColor = "Bright blue"}) end
					-- if p3 then showV3(p3, {name = "end"..rc, brickColor = "Br. yellowish green"}) end

					-- cost
					if not hit then
						break
					else
						-- onHit
						if onHit then
							onHit(hit, p1, normal, mat, impactLeft, distSum)
						end
						if not p2 then
							sunk = true
							-- print("projectile sunk")
						else
							local mult = getVelLeft(hit, mat, pen, dist, vel) 
							impactLeft = impactLeft * mult
							p0  = p2
							if not (dot((p3 - p0), originalDir) > 0) then
								break
							end

							-- print(string.format("penetration: dist = %.2f, mult = %.2f, speedBefore = %.2f, speedAfter = %.2f, mat = %s", dist, mult, vel.magnitude, (vel * mult).magnitude, tostring(mat)))

							vel = vel * mult
						end
					end
				end
			end

			-- check if should die
			if destroyQ() then
				return self.destroy()
			end

			-- update pos and vel
			lastCf = pt.CFrame
			pt.CFrame = newCf(pt.CFrame.p, pt.CFrame.p + vel)
			bv.Velocity = vel

			-- check if online part is added
			if pt2_ and pt ~= pt2_ then
				-- print("proj: got online part")

				local cf = pt.CFrame
				local trans = pt.Transparency
				destroy(pt)

				pt = pt2_
				pt.Transparency = trans
				pt.CFrame = cf
				bv = wfc(pt, "BodyVelocity")
				bv.Velocity = vel
			end
		end

		return self
	end
end

return projectile