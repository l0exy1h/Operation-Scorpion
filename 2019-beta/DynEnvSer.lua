local dynamicLighting = {}
local breakableEnv    = {}

local wfc = game.WaitForChild
local rep = game.ReplicatedStorage
local gm  = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

do -- breakable Env
	local getD             = game.GetDescendants
	local isA              = game.IsA
	local clone            = game.Clone
	local ffc              = game.FindFirstChild
	local ffcWia           = game.FindFirstChildWhichIsA
	local clearAllChildren = game.ClearAllChildren
	local pwd              = game.GetFullName
	local destroy          = game.Destroy

	local network   = requireGm("Network")
	local events    = wfc(rep, "Events")
	local dynServer = network.loadRe(wfc(events, "DynEnvRe"))
	-- local dynLightingSystem = requireGm("DynLightingSystem")

	-- supported breakable objects
	local supportedTypes = {
		TV = {
			is = function(part)
				return part.Name == "TV"
			end;
			getDestroyedTemplate = function(part)
				part = clone(part)
				clearAllChildren(part)
				return part
			end;
		},
		glass = {
			is = function(part)
				return part.Name == "glass"
			end;
			getDestroyedTemplate = function(part)
				return nil
			end;
		},
		light = {
			is = function(part)
				return part.Name == "light"
			end;
			getDestroyedTemplate = function(part)
				part = clone(part)
				clearAllChildren(part)
				part.BrickColor = BrickColor.new("Medium stone grey")
				part.Material   = Enum.Material.Glass
				part.Transparency = 0
				return part
			end;
		},
	}

	-- the breakables table that stores the numbered objects of each type
	local breakables = {}
	for type, _ in pairs(supportedTypes) do
		breakables[type] = {} 		-- actually stores a class
	end

	-- id tag to put in each breakable objs
	local breakableIdTag = Instance.new("IntValue")
	breakableIdTag.Name  = "BreakableId"
	local breakableTypeTag = Instance.new("StringValue")
	breakableTypeTag.Name = "BreakableType"

	-- pre process the tv
	local map = wfc(workspace, "Map")
	for _, v in ipairs(getD(map)) do
		if isA(v, "Model") and ffc(v, "TV") and ffc(v, "Part") then
			v.Part.Parent = v.TV
		end
	end

	-- preprocess the whole map
	for _, v in ipairs(getD(map)) do
		if isA(v, "BasePart") then
			for type, config in pairs(supportedTypes) do
				if config.is(v) then
					-- light up the light by default
					if type == "light" then
						if v.Material ~= Enum.Material.Neon then
							-- warn("auto enabling light")
						end
						v.Material = Enum.Material.Neon
						for _, u in ipairs(getD(v)) do
							if isA(u, "Light") or isA(u, "ParticleEmitter") then
								u.Enabled = true
							end
						end
					end

					local id           = #breakables[type] + 1
					local breakableId  = clone(breakableIdTag)
					breakableId.Value  = id
					breakableId.Parent = v
					local breakableType  = clone(breakableTypeTag)
					breakableType.Value  = type
					breakableType.Parent = v

					local t = {
						curr              = v,
						parent            = v.Parent,
						unbroken          = true,
						restoredTemplate  = clone(v), 	-- the tag will be cloned
						destroyedTemplate = config.getDestroyedTemplate(v) 	-- the tag will be cleared
					}

					function t.destroy()
						-- print("destroy")
						if t.unbroken then
							-- print("destroy2")
							if t.destroyedTemplate == nil then
								-- print("destroy3")
								destroy(t.curr)
								t.curr = nil
							else
								-- print("destroy4")
								destroy(t.curr)
								local cloned  = clone(t.destroyedTemplate)
								cloned.Parent = (t.parent and t.parent.Parent) and t.parent or map
								t.curr        = cloned
								-- print(pwd(cloned))
							end
							t.unbroken    = false
						end
					end
					function t.restore()
						if not t.unbroken then
							if t.curr then
								destroy(t.curr)
							end
							local cloned  = clone(t.restoredTemplate)
							cloned.Parent = (t.parent and t.parent.Parent) and t.parent or map
							t.curr        = cloned
							t.unbroken    = true
						end
					end

					if t.destroyedTemplate then
						assert(ffc(t.destroyedTemplate, "BreakableId", true) == nil, string.format("type %s didn't clear the breakableIdtag", type))
					end

					breakables[type][id] = t

					-- print(string.format("load breakable object %s of type = %s and id = %d", pwd(v), type, id))
				end
			end
		end
	end

	-- night lights shit
	local sv = wfc(rep, "SharedVars")
	local function isNightLight(light)
		return light and light.Name == "light" and light.Parent and light.Parent.Name == "NightLight"
	end
	local function isNightLightOn()
		local l = sv.DynLighting.Value
		return l == "sunset" or l == "night"
	end
	-- -- destroy all night lights if {sunset, night}
	-- sv.DynLighting.Changed:Connect(function()
	-- 	for _, light in ipairs(breakables.light) do
	-- 		if isNightLight(light.curr) and not isNightLightOn() then
	-- 			light.destroy()
	-- 		end
	-- 	end
	-- end)

	-- replication
	dynServer.listen("destroy", function(plr, id, type)
		breakables[type][id].destroy()
	end)
	function breakableEnv.restoreAll()
		-- print(sv.DynLighting.Value, isNightLightOn())
		for type, breakablesOfType in pairs(breakables) do
			for _, breakable in ipairs(breakablesOfType) do
				if isNightLight(breakable.curr) and not isNightLightOn() then
					breakable.destroy()
				else
					breakable.restore()
				end
			end
		end
	end
	breakableEnv.restoreAll()
end

do -- dynamic lighting
	local pv = requireGm("PublicVarsServer")
	local next = {
		sunrise = "day",
		day = "sunset",
		sunset = "night",
		night = "sunrise",
	}
	function dynamicLighting.setLighting(v)
		dynamicLighting.curr = v
		pv.set("DynLighting", v)
	end
	dynamicLighting.setLighting("sunrise")
	function dynamicLighting.advance()
		dynamicLighting.setLighting(next[dynamicLighting.curr])
	end
end

local function change() 
	dynamicLighting.advance()
	breakableEnv.restoreAll()	
end
wfc(wfc(rep, "SharedVars"), "RoundId").Changed:connect(change)

-- test: restore every 10 secs
-- spawn(function()
-- 	while wait(10) do
-- 		dynLightingSystem.advance()
-- 		restoreAll()
-- 	end
-- end)