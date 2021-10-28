-- load/unload skin
-- toggle tpp/fpp visibility
local rigHelper = {}

local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

-- use small-case "tpp" and "fpp"
-- safe means call it twice will result in no errors.

do -- loadskin, safe
	local skins = {}
	do -- configure the skin table. 
		 -- skin -> {[sideName_skinName] -> [the skin module]}
		local skinsLib = wfc(rep, "Skins")
		for _, side in ipairs(skinsLib:GetChildren()) do
			local sideName = string.lower(side.Name)
			for _, skin in ipairs(side:GetChildren()) do
				local skinName = skin.Name
				skins[sideName.."_"..skinName] = skin
			end
		end
	end
	local isA      = game.IsA
	local clone    = game.Clone
	local ffcWia   = game.FindFirstChildWhichIsA
	local format   = string.format
	local destroy  = game.Destroy
	local welding          = requireGm("Welding")
	local weldModel        = welding.weldModel
	local setPartsProperty = welding.setPartsProperty
	-- @param skin: the name of the skin plus the side. (a string)
	-- @param charNH: char non hit box folder
	-- @param skinObjs: for each pp, store the clothes models (@pre assuming one bodypart has at most one clothes)
	-- loads the skin to char, given the pp, modifies skinsObjs,
	-- puts the clothes/pants into char and clothes models into charNH
	function rigHelper.loadSkin(char, aniparts, pp, skin, skinObjs, charNH)
		charNH = charNH or char
		local ppSkinObjs = skinObjs[pp] or {}
		assert(typeof(skin) == "string")
		assert(skins[skin], skin.." is not a valid side-skin")

		for _, model in ipairs(skins[skin][pp]:GetChildren()) do

			if isA(model, "Pants") or isA(model, "Shirt") then
				local cloned = clone(model)
				cloned.Parent = char

				local oldObj = ppSkinObjs[model.ClassName]
				if oldObj then
					warn("loadskin, oldObj", model.ClassName, "is not cleaned. cleaning it now")
					destroy(oldObj)
				end
				ppSkinObjs[model.ClassName] = cloned 

			else
				local bpn    = model.Name
				local cloned = clone(model)
				local joint  = ffcWia(cloned.PrimaryPart, "Motor6D")

				assert(joint, format("skin %s's primary part has no joint", skin))
				joint.Part0 = aniparts[bpn]
				assert(aniparts[bpn], format("skin %s attempted to attach to body part %s which is not found in aniparts", skin, bpn))

				weldModel(cloned)
				cloned.Parent = charNH
				setPartsProperty(cloned, {
					Anchored     = false,
					CanCollide   = false,
				})

				local oldObj = ppSkinObjs[bpn] 
				if oldObj then
					warn("loadSkin, old clothing for", bpn, "is not cleaned. cleaning it now")
					destroy(oldObj)
				end
				ppSkinObjs[bpn] = cloned
			end
		end
	end
end

do -- unloadSkin, afe
	local isA     = game.IsA
	local destroy = game.Destroy
	-- @param skinObjs: a table containing the clothes models for each side
	function rigHelper.unloadSkin(pp, skinObjs)
		local ppSkinObjs = skinObjs[pp]
		for idx, model in pairs(ppSkinObjs) do
			if model and isA(model, "Model") then
				destroy(model)
				skinObjs[idx] = nil
			end
		end
	end
end

do -- isVisBodypart
	local tppVisPart = {
		LeftFoot      = 1,
		LeftHand      = 1,
		LeftLowerArm  = 1,
		LeftLowerLeg  = 1,
		LeftUpperArm  = 1,
		LeftUpperLeg  = 1,
		RightFoot     = 1,
		RightHand     = 1,
		RightLowerArm = 1,
		RightLowerLeg = 1,
		RightUpperArm = 1,
		RightUpperLeg = 1,
		UpperTorso    = 1,
		LowerTorso    = 1,
		Head          = 1,
	}
	local fppVisPart = {
	}
	local tppRigPart = {  -- just for rigging, not visible
		TppLook      = 1,
		--TppLowerRoot = 1,
		TppShoulder  = 1,
	}
	local fppRigPart = {
		FppEye     = 1,
		FppInertia = 1,
		FppLook    = 1,
		FppRoot    = 1,
		FppLeftArm = 1,
		FppRightArm= 1,
		-- Collision  = 1,
	}		

	-- @param bp: bodypart or the name thereof
	-- @param pp: "fpp" or "tpp"
	function rigHelper.isVisBodypart(bp, pp)
		bp = typeof(bp) == "string" and bp or bp.Name
		if pp == "tpp" then
			return tppVisPart[bp]
		elseif pp == "fpp" then
			return fppVisPart[bp]
		end
	end

	function rigHelper.isRigPart(bp, pp)
		bp = typeof(bp) == "string" and bp or bp.Name
		if pp == "tpp" then
			return tppRigPart[bp]
		elseif pp == "fpp" then
			return fppRigPart[bp]
		end
	end
end

do -- toggleBodyparts, safe
	local isA              = game.IsA
	local welding          = requireGm("Welding")
	local isVisBodypart        = rigHelper.isVisBodypart
	local setPartsProperty = welding.setPartsProperty

	-- @param pp: fpp (turn on fpp and turn of tpp)
	-- @param vis: true/false (0 / 1)
	-- @param exc: the excluding list?
	-- toggles visibility of given body parts based on the specified side
	function rigHelper.toggleBodyparts(parts, pp, vis, exc)
		exc = exc or {}
		local trans = vis and 0 or 1
		for _, v in pairs(parts) do 
			local name = v.Name
			if not exc[name] and isA(v, "BasePart") and isVisBodypart(v, pp) then
				v.Transparency = trans
			end
		end
	end
end

do -- toggleFace, afe
	local clone = game.Clone
	local destroy = game.Destroy
	local ffc = game.FindFirstChild

	local faceTemp = wfc(wfc(wfc(wfc(game:GetService("StarterPlayer"), "StarterCharacter"), "Head"), "Neck"), "face")

	function rigHelper.toggleFace(head, bool)
		assert(head, "head is nil")

		local oldFace = ffc(head, "face")

		if bool then
			if not oldFace then
				clone(faceTemp).Parent = head
			end
		else
			if oldFace then
				destroy(oldFace)
			end
		end
	end
end

do -- set tpp / fpp enabled, safe
	local toggleBodyparts = rigHelper.toggleBodyparts
	local toggleFace      = rigHelper.toggleFace
	local loadSkin        = rigHelper.loadSkin
	local unloadSkin      = rigHelper.unloadSkin

	local myMath  = requireGm("Math")
	local cylToCf = myMath.cylToCf
	local newCf   = CFrame.new
	local ffc     = game.FindFirstChild

	function rigHelper.setCharVisibility(pp, bool, char, aniparts, skinObjs, args)
		args = args or {}

		-- body parts
		toggleBodyparts(aniparts, pp, bool)

		-- clothes
		skinObjs = skinObjs or {tpp = {}, fpp = {}}
		if bool then
			local skin = args.skin or (math.random(1, 2) == 1 and "atk" or "def").."_Default"
			loadSkin(char, aniparts, pp, skin, skinObjs, args.charNH)
		else
			unloadSkin(pp, skinObjs)
		end

		-- gun (args)
		if args.gunModel then
			args.gunModel.Parent = bool and (args.gunHolder or char) or nil
		end

		if pp == "tpp" then
			-- face
			toggleFace(ffc(char, "Head") or aniparts.Head, bool)
		end
	end
end

do -- initRig
	local ffcWia = game.FindFirstChildWhichIsA
	local isA    = game.IsA
	local getC   = game.GetChildren
	local pwd    = game.GetFullName

	local function isBodypart(v)
		local motor6d = ffcWia(v, "Motor6D")
		local bool = isA(v, "BasePart") and motor6d ~= nil
		return bool, motor6d 
	end

	-- fillin the arrays passed
	function rigHelper.initRig(char, aniparts, joints, defC0)
		for _, v in ipairs(getC(char)) do
			local b, joint = isBodypart(v)
			if b then
				aniparts[v.Name] = v
				joints[v.Name]   = joint
				defC0[v.Name]    = joint.C0
				assert(joint.Part1 == v or print(pwd(joint), pwd(v), joint.Part1))
			end
		end
	end
end

return rigHelper