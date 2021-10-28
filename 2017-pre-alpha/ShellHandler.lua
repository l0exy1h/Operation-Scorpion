local md = {}

-- defs
local rep   = game.ReplicatedStorage
local gm    = rep:WaitForChild("GlobalModules")
local Mathf = require(gm:WaitForChild("Mathf"))
local lerp  = Mathf.lerp
local cam   = workspace.CurrentCamera
local HB    = game:GetService("RunService").Heartbeat
local audioEvent = script.Parent.Parent.Parent:WaitForChild("AudioEngine"):WaitForChild("AudioEvent")

-- vars
local Shells = {}

local function EmitShell(shellType,cf,direction,velmult, shellDropSound)
	local s = workspace.SavedShells:FindFirstChild(shellType)
	local gs
	if s == nil then
		gs = script.RoundCasings:FindFirstChild(shellType)
		if gs then
			s = gs:clone()
		else
			s = script.RoundCasings.Default:Clone()
		end
	end
	local vel = direction * lerp(6, 12, math.random()) * velmult + 
		Vector3.new(0, lerp(2, 3, math.random()), 0) * velmult
	
	s.Parent = workspace.ActiveShells
	s.CFrame = cf*CFrame.fromEulerAnglesYXZ(
		math.rad(s.RotOffset.Value.x),
		math.rad(s.RotOffset.Value.y),
		math.rad(s.RotOffset.Value.z)
	)
	table.insert(Shells, {s, s.CFrame, vel, tick(), 
		Vector3.new(math.random()*4,math.random()*4,math.random()*4)}
	)
	
	wait(0.5)
	audioEvent:Fire("Play", {shellDropSound, false, true})
end

function md.setup()
	script.EmitShell.Event:connect(EmitShell)
	spawn(function()
		while HB:wait() do
			for i,v in ipairs(Shells) do
				if tick()-v[4] > 0.6 then
					v[1].Parent = workspace.SavedShells
					v[1].CFrame = CFrame.new(0,0,0)
					table.remove(Shells,i)
				else
					v[1].CFrame = v[2]*CFrame.fromEulerAnglesYXZ((tick()-v[4])*v[5].x,(tick()-v[4])*v[5].y,(tick()-v[4])*v[5].z) + v[3]*(tick()-v[4]) - Vector3.new(0,40*(tick()-v[4])^2,0)			
				end
			end
		end
	end)
end

return md
