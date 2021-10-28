-- bodypart module
-- identify which part is for fpp / tpp and stuff
---------------------------------
local rep = game.ReplicatedStorage
local wfc = game.WaitForChild
local gm  = wfc(rep, "GlobalModules")
local function requireGm(name)
	return require(wfc(gm, name))
end

local rigInfo = {}
do
	local ffc = game.FindFirstChild
	local ido = game.IsDescendantOf
	local isA = game.isA

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
		-- FppLeftArm  = 1,
		-- FppRightArm = 1,
	}
	-- local tppVisModel = {
	-- 	TppGun     = 1,
	-- 	Head       = 1,
	-- 	UpperTorso = 1,
	-- }
	-- local fppVisModel = {
	-- 	FppGun     = 1,
	-- 	FppLeftArm = 1,
	-- 	FppRightArm = 1,
	-- }
	local tppExtPart = {
		TppLook      = 1,
		--TppLowerRoot = 1,
		TppShoulder  = 1,
	}
	local fppExtPart = {
		FppEye     = 1,
		FppInertia = 1,
		FppLook    = 1,
		FppRoot    = 1,
		Collision  = 1,
	}		
	-- local function isVisPartOfGun(char, bp, gunName)
	-- 	if char then
	-- 		local gun = ffc(char, gunName)
	-- 		return gun and ido(bp, gun) and not ido(bp, gun.attachpoint)
	-- 	end
	-- end
	-- function rigInfo.isTppPart(bp)
	-- 	return isA(bp, "BasePart") and tppVisPart[bp.Name] or tppExtPart[bp.Name] or isVisPartOfGun(char, bp, "TppGun")
	-- end
	-- function rigInfo.isFppPart(char, bp)
	-- 	return fppVisPart[bp.Name] or fppExtPart[bp.Name] or isVisPartOfGun(char, bp, "FppGun")
	-- end
	-- function rigInfo.isTppVisPart(bp)
	-- 	local bpn = bp.Name
	-- 	return (isA(bp, "BasePart") and tppVisPart[bpn]) or (isA(bp, "Model") and tppVisModel[bpn])
	-- end
	-- function rigInfo.isFppVisPart(bp)
	-- 	local bpn = bp.Name
	-- 	return (isA(bp, "BasePart") and fppVisPart[bpn]) or (isA(bp, "Model") and fppVisModel[bpn])
	-- end
	function rigInfo.isTppVisPart(bp)
		return tppVisPart[bp.Name]
	end
	function rigInfo.isFppVisPart(bp)
		return fppVisPart[bp.Name]
	end
	-- function rigInfo.isTppExtPart(bp)
	-- 	return tppExtPart[bp.Name]
	-- end
	-- function rigInfo.isFppExtPart(bp)
	-- 	return fppExtPart[bp.Name]
	-- end
	do
		local isA     = game.IsA
		local welding = requireGm("Welding")
		local setPartsProperty = welding.setPartsProperty

		-- @param: pp = fpp (turn on fpp and turn of tpp)
		-- @param: vis = true/false (0 / 1)
		function rigInfo.toggleVis(list, pp, vis, exc)--, skinModels)
			exc = exc or {}
			local is = rigInfo["is"..pp.."VisPart"]
			local trans = vis and 0 or 1
			for _, v in pairs(list) do 
				local name = v.Name
				if not exc[name] and is(v) then
					if isA(v, "BasePart") then
						-- print("toggling part trans", v, trans)
						v.Transparency = trans
					-- elseif isA(v, "Model") then
					-- 	print("toggling model trans", v, trans)
					-- 	setPartsProperty(v, {Transparency = trans})
					end
				end
			end
		end
	end

	do-- configure the load skin function
		local skins = {}
		do -- configure the skin table. 
			 -- skin -> {[sideName_skinName] -> [the skin module]}
			local skinsLib = wfc(rep, "Skins")
			for _, side in ipairs(skinsLib:GetChildren()) do
				local sideName = side.Name
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
		local welding          = requireGm("Welding")
		local weldModel        = welding.weldModel
		local setPartsProperty = welding.setPartsProperty
		function rigInfo.loadSkin(char, aniparts, pp, skin, skinObjs, charNH)
			charNH = charNH or char
			print(char, aniparts, pp, skin, skinObjs, charNH)
			local ppSkinObjs = skinObjs[pp] or {}
			assert(typeof(skin) == "string")
			for _, model in ipairs(skins[skin][pp]:GetChildren()) do
				if isA(model, "Pants") or isA(model, "Shirt") then
					local cloned = clone(model)
					cloned.Parent = char
					ppSkinObjs[model.ClassName] = cloned 
				else
					local bpn = model.Name
					local cloned = clone(model)
					local joint = ffcWia(cloned.PrimaryPart, "Motor6D")
					assert(joint, format("skin %s's primary part has no joint", skin))
					joint.Part0 = aniparts[bpn]
					assert(aniparts[bpn], format("skin %s attempted to attach to body part %s which is not found in aniparts", skin, bpn))
					weldModel(cloned)
					cloned.Parent = charNH
					ppSkinObjs[bpn] = cloned

					setPartsProperty(cloned, {
						-- Transparency = pp == "Fpp" and 0 or 1, 
						Anchored     = false,
						CanCollide   = false,
					})
				end
			end
		end
	end

	do--configure unload skin
		local isA = game.IsA
		local destroy = game.Destroy
		function rigInfo.unloadSkin(pp, skinObjs)
			local ppSkinObjs = skinObjs[pp]
			for idx, model in pairs(ppSkinObjs) do
				if model and isA(model, "Model") then
					destroy(model)
					skinObjs[idx] = nil
				end
			end
		end
	end
end
return rigInfo