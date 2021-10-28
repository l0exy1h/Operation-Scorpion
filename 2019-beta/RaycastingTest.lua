local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local rc = requireGm("Raycasting")
local pj = requireGm("Projectile")

local rayWl = wfc(workspace, "RayWl")

function getBallPos(num)
	return wfc(workspace, "Ball"..num).Position
end

function testRc(a, b)
	local pa = getBallPos(a)
	local pb = getBallPos(b)
	print(rc.raycastWl2pts(pa, pb - pa, {rayWl}))
end

local pjId = 0
function testPj(a, b, speed)
	pjId = pjId + 1
	local thisPjId = pjId
	local pa = getBallPos(a)
	local pb = getBallPos(b)

	local proj = pj.new(pa, (pb - pa).Unit * speed, {
		rayWl = {workspace.RayWl},
		drag = 1,
		grav = 1,
		length = 6,
		pen = 20,
		onHit = function()
			print("hit!")
		end,
		maxDist = 50,
	})

	local runSer = game:GetService("RunService")
	runSer:BindToRenderStep(tostring(pjId), 501, function(dt)
		if proj.step(dt) == "destroyed" then
			print("destroyed")
			runSer:UnbindFromRenderStep(tostring(thisPjId))
		end
	end)
end

wait(2)
testPj(6, 7, 1350)

-- for _ = 1, 1000 do
-- 	wait(1/12)
-- 	testPj(1, 2, 350)
-- end