local wfc = game.WaitForChild
local rep = game.ReplicatedStorage
local gm  = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local debugSettings = requireGm("DebugSettings")()

local dl = {}
do
	local lighting = game:GetService("Lighting")

	-- universal across all maps
	local objects = {
		lighting = lighting,
		cc       = wfc(lighting, "DynCC"),
		sr       = wfc(lighting, "DynSR"),
	}

	-- different for each map
	local mapLightingPrefs = require(wfc(wfc(rep, "MapSpecific"), "DynamicLightingPrefs"))
	local tweenable        = mapLightingPrefs.tweenable
	local nonTweenable     = mapLightingPrefs.nonTweenable

	local tweenService = game:GetService("TweenService")
	local tweenInfo = TweenInfo.new(
		2,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		0
	)
	local function tween(instance, properties)
		tweenService:Create(instance, tweenInfo, properties):Play()
	end

	local tweenObjs = {}
	local function cancelTweenObjs()
		for i, tw in ipairs(tweenObjs) do
			tw:Cancel()
			tweenObjs[i] = nil
		end
	end
	function dl.changeLighting(l)
		if l == "" then return end
		if debugSettings.brighterLighting then
			l = "day"
		end

		cancelTweenObjs()
		local tw = tweenable[l]
		for objName, properties in pairs(tw) do
			tweenObjs[#tweenObjs + 1] = tween(objects[objName], properties)
		end
		if nonTweenable[l] then
			nonTweenable[l]()
		end
	end

	do-- listen to changes online
		local pv          = requireGm("PublicVarsClient")
		local dynLighting = pv.waitForObj("DynLighting")
		dl.changeLighting(dynLighting.Value)
		dynLighting.Changed:connect(dl.changeLighting)
	end
end