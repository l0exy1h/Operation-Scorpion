local wfc  = game.WaitForChild
local rep = game.ReplicatedStorage
local lp = game.Players.LocalPlayer
local gm   = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local events     = wfc(rep, "Events")
local memeClient = requireGm("Network").loadRe(wfc(events, "Mainframe"), false)

local audioSys = requireGm("AudioSystem")
local rigInfo = requireGm("RigInfo")
local myMath = requireGm("Math")
	local v3ToCyl = myMath.v3ToCyl
	local cylToCf = myMath.cylToCf
local keyframeAnimation = requireGm("KeyframeAnimation")
local animations = requireGm("TppAnimations")
for aniName, ani in pairs(animations) do
	ani.name = aniName
end


local memers = {}
local function newMemer(plr, args)
	local meme = {}

	local char         = plr.Character
	local hrp          = wfc(char, "HumanoidRootPart")
	local humanoid     = wfc(char, "Humanoid")
	local looky, lookx = v3ToCyl(args.spawnLocation.CFrame.lookVector)

	-- disable movement
	if plr == lp then 
		humanoid.AutoRotate = false
		humanoid.JumpPower = 0
		humanoid.WalkSpeed = 0
	end

	local aniparts, joints, defC0, sounds, stash = {}, {}, {}, {}, {}
	do
		local chars      = wfc(workspace, "Chars")
		local nonHitbox  = wfc(workspace, "NonHitbox")

		-- assigned later
		local newInstance = Instance.new
		local isA         = game.IsA
		local ffcWia      = game.FindFirstChildWhichIsA
		local getChildren = game.GetChildren

  	for _, bp in ipairs(getChildren(char)) do
  		local joint = ffcWia(bp, "Motor6D")
  		if isA(bp, "BasePart") and joint then
  			local bpn = bp.Name
  			aniparts[bpn] = bp
  			joints[bpn]   = joint
  			defC0[bpn]    = joint.C0
  		end

  		if isA(bp, "BasePart") and not rigInfo.isTppVisPart(bp) and plr ~= lp then
  			bp.Parent = char
  		end
  	end
  	stash = {
			Hitbox    = char,
			NonHitbox = char,
		}
  end

  do-- load skin in
  	local skin = args.skin or "Default"
  	local rigInfo = requireGm("RigInfo")
  	rigInfo.loadSkin(char, aniparts, "Atk", "Tpp", skin, {})
 	end

  local hrpDirY, hrpDirX = v3ToCyl(hrp.CFrame.lookVector)
  joints.TppLook.C0 = cylToCf(looky - hrpDirY, 0) * defC0.TppLook

  local kfs = keyframeAnimation.new(aniparts, joints, defC0, stash)
  kfs.loadAnimation(animations[args.showtimeDance], 1, true)

  function meme.step(dt, now)
  	kfs.playAnimation(dt)
  end

  function meme.destroy()
  	kfs.loadAnimation(animations["standDeath"..math.random(1, 4)])
  	if plr == lp then
  		audioSys.play("DeathScream", "2D")
  	end
  	delay(1, function()
  		hrp.Anchored = true
  	end)
  end

	return meme
end

memeClient.listen("spawnDancing", function(plr, args)
	if memers[plr.Name] then
		memers[plr.Name].destroy()
	end
	memers[plr.Name] = newMemer(plr, args)
end)
memeClient.listen("stopDancing", function(plr)
	if memers[plr.Name] then
		memers[plr.Name].destroy()
	else
		warn("cant find memer", plr)
	end
end)
spawn(function()
	local rs       = game:GetService("RunService").RenderStepped
	local evwait   = game.Changed.Wait
	local lastTick = tick()
	while evwait(rs) do		
		local now = tick()
		local dt = now - lastTick
		for _, memer in pairs(memers) do
			memer.step(dt)
		end
		lastTick = now
	end
end)