local raycasting = {}

-- p0: origin of the ray
-- p1: enter pos
-- p2: exit pos

local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

local newV3  = Vector3.new

do -- debug function: showV3
	-- @param q: position
	-- @param [args.size]: the diameter
	-- @param [args.brickColor] (string)
	-- @param [args.name]
	-- @param [args.parent]
	function raycasting.showV3(q, args)
		args = args or {}

		local ball = Instance.new("Part")
		ball.Shape = "Ball"
		ball.Anchored = true
		ball.CanCollide = false
		ball.Position = q

		local size = args.size or 0.25
		ball.Size = newV3(size, size, size)

		ball.BrickColor = args.brickColor and BrickColor.new(args.brickColor) or ball.BrickColor
		ball.Name = args.name or "DebugBall"

		ball.Parent = args.parent or workspace

		return ball
	end
end

-- @param p0, d (vector3): for the ray
-- @param list (array): the whitelist
do -- raycast with whitelist
	local newRay = Ray.new
	local raycastWl = workspace.FindPartOnRayWithWhitelist
	function raycasting.raycastWl(p0, d, list)
		return raycastWl(workspace, newRay(p0, d), list)
	end
end
local raycastWl = raycasting.raycastWl

do
	local down = Vector3.new(0, -5, 0)
	function raycasting.raycastWlDown(p0, list)
		return raycasting.raycastWl(p0, down, list)
	end
end

-- @param p1 (vector3)
-- @param d (vector3): the portion of the direction vector starting from p1.
-- @param part (basepart): maybe a meshpart which has complex shapes
-- @ret p2 (vector3), dist: exit vector3(maybe nil), and the dist
do
	local showV3 = raycasting.showV3
	function raycasting.findExitPoint(p1, d, part)
		-- showV3(p1, {brickColor = "Bright blue", name = "p1"})
		local _, q = raycastWl(p1, d, {part})
		-- showV3(q, {brickColor = "Bright red", name = "q"})
		local hit2, p2 = raycastWl(q, p1 - q, {part})
		if hit2 then
			-- showV3(p2, {brickColor = "Bright yellow", name = "p2"})
			return p2, (p2 - p1).magnitude
		end
	end
end

do
	local min = math.min
	-- local maxPeneLength = 5
	local raycastWl = raycasting.raycastWl
	local findExitPoint = raycasting.findExitPoint
	-- returns also the exit point
	-- @ret hit, p1, p2, dist, mat, normal
	-- @param d: the direction of the ray, magnitude does not matter
	function raycasting.raycastWl2pts(p0, d, list)
		local hit, p1, normal, mat = raycastWl(p0, d, list)
		local p2, dist
		if hit then
			d = d - (p1 - p0)
			p2, dist = findExitPoint(p1, d.Unit * (hit.Size.magnitude + 0.1), hit)
			return hit, p1, p2, p2 and (p2 - p1).magnitude or nil, normal, mat
		end
	end
end

return raycasting