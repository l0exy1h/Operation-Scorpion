local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm  = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end
local myMath = requireGm("Math")
local itp    = requireGm("Interpolation")

local keyframeAnimationSystem = {}
do
	local cfLerp = myMath.cfLerp
	local clamp  = myMath.clamp
	local clone  = game.Clone
	local ffcWia = game.FindFirstChildWhichIsA

	local function getInterpolator(c0, goalC0, es, dur)
		local t = 0
		return function(dt, sp)
			t = clamp(t + (dt * sp) / dur, 0, 1)
			return cfLerp(c0, goalC0, es(t)), t == 1
		end
	end

	function keyframeAnimationSystem.new(aniparts, joints, defC0, stash, soundPlayer)
		local self = {
			trackCompleted = true,
			currAnimationName = nil,
		}
		local currAnimation = nil
		local interpolators = {}
		self.interpolators = interpolators

		-- on kf loaded
		local t0, dur, fr
	
		-- on track loaded
		local callback, trackEasing, trackDurScale, currFrameNum

		function self.update(aniparts_, joints_, defC0_, stash_)
			aniparts, joints, defC0, stash = aniparts_, joints_, defC0_, stash_
		end

		do -- loadkeyframe
			local actionHandlers = {
				playSound = function(action) 
					if soundPlayer then
						soundPlayer(action.soundName)
					end
				end;
				clone = function(action)
					local cloneName = action.cloneName
					local initC0    = action.initialC0
					local template  = action.template
					local dest      = stash[action.dest]

					local cloned    = clone(aniparts[action.template])
					assert(aniparts[cloneName] == nil or warn(cloneName, "already exists!"))
					
					cloned.Name          = cloneName 
					aniparts[cloneName]  = cloned
					joints[cloneName]    = ffcWia(cloned, "Motor6D")
					defC0[cloneName]     = defC0[template]
					
					joints[cloneName].C0 = initC0
					
					cloned.Parent        = dest
				end;
				rename = function(action)
					local oldName = action.oldName
					local newName = action.newName

					assert(aniparts[newName] == nil or warn(newName, "already exists!"))
					aniparts[newName]      = aniparts[oldName]
					joints[newName]        = joints[oldName]
					defC0[newName]         = defC0[oldName]
					aniparts[newName].Name = newName
					
					aniparts[oldName] = nil
					joints[oldName]   = nil
					defC0[oldName]    = nil
				end;
				destroy = function(action)
					local partName = action.partName
					assert(aniparts[partName] or warn(partName, "does not exist"))

					aniparts[partName]:Destroy()
					aniparts[partName] = nil
					joints[partName]   = nil
					defC0[partName]    = nil
				end;
			}
			function self.loadKeyframe(keyframe, entryDur)
				if keyframe.actions then
					for _, action in ipairs(keyframe.actions) do
						local actionName = action.actionName
						local actionHandler = actionHandlers[actionName]
						if actionHandler then
							actionHandler(action)
						else
							error(string.format("kf action %s is not configured", actionName))
						end
					end
				end

				if keyframe.goalC0 then
					if entryDur ~= 0 then
						dur = (entryDur or keyframe.dur) * trackDurScale
						t0  = 0
						fr  = keyframe
						local es  = trackEasing or itp.easing[keyframe.easing or "linear"]
						for bpn, goalC0 in pairs(keyframe.goalC0) do
							assert(aniparts[bpn], bpn.." does not exist!")
							local c0 = joints[bpn].C0
							interpolators[bpn] = getInterpolator(c0, goalC0, es, dur)
						end
					else
						-- snap first frame when entryDur == 0
						fr  = keyframe
						t0  = 1
						dur = 1
						for bpn, goalC0 in ipairs(fr.goalC0) do
							joints[bpn].C0 = goalC0
						end
					end
				end
			end
		end

		do-- _loadAnimation
			local loadKeyframe = self.loadKeyframe
			local function getLength(animation)
				local length = 0
				for _, v in ipairs(animation) do
					length = length + v.dur
				end
				return length
			end
			function self._loadAnimation(animation, args)

				currAnimation       = animation
				trackDurScale       = animation.trackDurScale or 1
				trackEasing         = animation.trackEasing
				currFrameNum        = args.startingFrameNum or 1
				callback            = args.callback
				self.trackCompleted = false

				if args.fitLength then -- overrides trackdurscale
					animation.length = animation.length or getLength(animation)
					trackDurScale = args.fitLength / animation.length
				end

				loadKeyframe(animation[currFrameNum], args.snapFirstFrame and 0 or animation.entryDur)
			end
			function self.playAnimation(dt, sp)
				sp = sp or 1

				for bpn, interpolator in pairs(interpolators) do
					local currC0, interpolationCompleted = interpolator(dt, sp)
					joints[bpn].C0 = currC0

					if interpolationCompleted then
						interpolators[bpn] = nil
					end
				end

				-- check frame / track completed or not
				if fr then
					self.trackCompleted = false
					t0 = clamp(t0 + (dt * sp) / dur, 0, 1)
					if t0 == 1 then
						local nextKeyframe = currAnimation[currFrameNum + 1]
						if nextKeyframe then
							currFrameNum = currFrameNum + 1
							loadKeyframe(nextKeyframe)
						else
							if currAnimation.looped then
								currFrameNum = 1
								loadKeyframe(currAnimation[1])
							else
								self.trackCompleted = true
								if callback then
									-- print("callback!")
									callback()
									callback = nil
								end
							end
						end
					end
				end
			end
		end

		do-- load animation
			local _loadAnimation = self._loadAnimation

			-- @important use this instead!
			-- @param [args.startingFrameNum]
			-- @param [args.callback]
			-- @param [args.fitLength]
			-- @param [args.snapFirstFrame]
			-- @param [args.reload]: force reload
			-- @param [args.table0]: will find animation in this table first
			function self.load(table, trackName, args)
				args = args or {}

				local track = (args.table0 and args.table0[trackName]) or table[trackName]
				assert(track, "kfs.load:", track, "is not found in", table)

				if args.reload or self.currAnimationName ~= trackName then
					self.currAnimationName = trackName
					_loadAnimation(track, args)
				end
			end
		end

		function self.loadInstant(table, trackName)
			local track = table[trackName]
			assert(track, trackName.." not found")
			for bpn, c0 in pairs(track[1].goalC0) do
				joints[bpn].C0 = c0
				print("set", bpn)
			end
		end

		function self.clearInterpolators()
			for k, v in pairs(interpolators) do
				interpolators[k] = nil
			end
		end

		return self
	end

	-- @deprecated
	function keyframeAnimationSystem.prepAnimations(animations)
		for aniName, ani in pairs(animations) do
			ani.name = aniName
		end
		return animations
	end

	-- @deprecated
	function keyframeAnimationSystem.addTrack(animations, name, track)
		animations[name] = track
		track.name = name
	end
end
return keyframeAnimationSystem