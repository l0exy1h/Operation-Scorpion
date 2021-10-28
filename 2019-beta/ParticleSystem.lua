
-- particle module
-- just particle effects and sounds
-- doesnt deal with breakable environment
--------------------
local particleSystem = {}

local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local printTable = requireGm("TableUtils").printTable

local attachments = {}
local parts       = {}
local sounds      = {}
local emitFuncs   = {}
do -- get attachments and parts
	local getC = game.GetChildren
	local ffc  = game.FindFirstChild
	local isA  = game.IsA
	for _, v in ipairs(getC(wfc(script, "Particles"))) do
		local tempName = v.Name
		local found = false
		if ffc(v, "Attachment") then
			attachments[tempName] = ffc(v, "Attachment")
			found = attachments[tempName]
		elseif ffc(v, "Part") then
			parts[tempName] = ffc(v, "Part")
			found = parts[tempName]
		end

		if found then
			local s = {}
			sounds[tempName] = s
			for _, v in ipairs(getC(found)) do
				if isA(v, "Sound") then
					s[#s + 1] = v
					-- print("found sound", v, "for", tempName)
				end
			end
			-- printTable(sounds[tempName])
		else
			warn(string.format("Particle %s has no attachment / part", tempName))
		end
	end

	-- get emit funcs
	local delays = {
		Default  = 0.1,
		Snow     = 0.2,
		Sand     = 0.2,
		Dirt     = 0.2,
		Flesh    = 0.2,
		Glass    = 0.2,
		Light    = 0.01,
		Metal    = 0.01,
		Headshot = 0.1,
		TV       = 0.3,
		UGlass   = 0.4,
		Water    = 0.1,
		Wood     = 0.2,
	}
	local getC = game.GetChildren
	local isA  = game.IsA
	local function getEmitFunc(name, delay)
		return function(pt)
			local emitters = {}
			for _, v in ipairs(getC(pt)) do
				if isA(v, "Light") or isA(v, "ParticleEmitter") then
					emitters[#emitters + 1] = v
				end
			end
			for _, emitter in ipairs(emitters) do
				emitter.Enabled = true
			end
			wait(delay)
			for _, emitter in ipairs(emitters) do
				emitter.Enabled = false
			end
		end
	end
	for tempName, delay in pairs(delays) do
		emitFuncs[tempName] = getEmitFunc(tempName, delay * 1);
	end
end


-- putParticlePart
local bigHolder = Instance.new("Part")
do
	bigHolder.Name         = "ParticlePart"
	bigHolder.Anchored     = true
	bigHolder.Transparency = 1
	bigHolder.Size         = Vector3.new()
	bigHolder.CanCollide   = false
	bigHolder.CFrame       = CFrame.new()
	bigHolder.Parent       = wfc(workspace, "NonHitbox")
end

do -- emitParticle
	local clone       = game.Clone
	local myMath      = requireGm("Math")
	local lvToCf      = myMath.lvToCf
	local play        = requireGm("AudioSystem").play
	local debris      = game.Debris
	local addToDebris = debris.AddItem
	-- local emitFuncs   = particleSystem.emitFuncs
	local cam         = workspace.CurrentCamera 

	function particleSystem.emitParticle(tempName, h, p0, p1, distMult, vMult)
		-- printTable({tempName, h, p0, p1, distMult, vMult})

		local holder
		if attachments[tempName] then
			holder = clone(attachments[tempName])
			holder.CFrame = lvToCf(p0 - p1) + p1
		elseif parts[tempName] then
			holder = clone(parts[tempName])
			holder.Transparency = 1
			holder.Anchored     = true
			holder.CanCollide   = false
			holder.Size         = h.Size
			holder.CFrame       = h.CFrame
		else
			error(string.format("particleSystem: %s is not configured", tempName))
		end
		holder.Parent = bigHolder

		local dist  = (cam.CFrame.p - p1).magnitude
		local v     = (1 - (dist / distMult)) * vMult
		play(sounds[tempName], "2D", {volume = v})

		spawn(function()
			emitFuncs[tempName](holder)
			addToDebris(debris, holder, 6)
		end)
	end
end

do -- onHit
	local emitParticle = particleSystem.emitParticle
	local ptToObj      = CFrame.new().pointToObjectSpace
	local ido          = game.IsDescendantOf
	local ranint       = math.random

	local matGrass        = Enum.Material.Grass
	local matGround       = Enum.Material.Ground
	local matSnow         = Enum.Material.Snow
	local matSand         = Enum.Material.Sand
	local matWater        = Enum.Material.Water
	local matWood         = Enum.Material.Wood
	local matDiamondPlate = Enum.Material.DiamondPlate
	local matMetal        = Enum.Material.Metal
	local matNeon         = Enum.Material.Neon

	local chars    = wfc(workspace, "Chars")
	local ragdolls = wfc(workspace, "Ragdolls")

	local plrs = game.Players
	local lp   = plrs.LocalPlayer

	local cam         = workspace.CurrentCamera 

	function particleSystem.onHit(h, p0, p1, mat, plr)
		-- if not rep.ParticleEnabled.Value then return end

		local rel = ptToObj(cam.CFrame, p1)	
		if rel.z  < 30 and (plr == lp or rel.magnitude <= 33) then

			-- characters
			if ido(h, chars) or ido(h, ragdolls) then
				emitParticle(h.Name == "Head" and "Headshot" or "Flesh", h, p0, p1, 100, 1)

			-- special breakable objects
			elseif h.Name == "u_glass" then
				emitParticle("UGlass", h, p0, p1, 60, 1.5)
			elseif h.Name == "glass" then
				emitParticle("Glass", h, p0, p1, 60, 2.5)
			elseif h.Name == "tv" or h.Name == "TV" then
				emitParticle("TV", h, p0, p1, 60, 1.5)
			elseif h.Name == "light" or mat == matNeon then
				emitParticle("Light", h, p0, p1, 100, 2.5)

			-- materials
			elseif mat == matGrass or mat == matGround then
				emitParticle("Dirt", h, p0, p1, 100, 1)
			elseif mat == matSnow then
				emitParticle("Snow", h, p0, p1, 100, 3)
			elseif mat == matSand then
				emitParticle("Sand", h, p0, p1, 100, 2)
			elseif mat == matWater then
				emitParticle("Water", h, p0, p1, 100, 3)
			elseif mat == matWood then
				emitParticle("Wood", h, p0, p1, 100, 2)
			elseif mat == matMetal or mat == matDiamondPlate then
				emitParticle("Metal", h, p0, p1, 100, 1)

			-- default
			else
				emitParticle("Default", h, p0, p1, 35, 0.7)
			end
		end
	end
end

return particleSystem
