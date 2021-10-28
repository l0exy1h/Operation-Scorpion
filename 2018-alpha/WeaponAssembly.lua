local module = {}

local rep = game.ReplicatedStorage
local Attachments = rep:WaitForChild("Attachment")

-- desc: there're some parts of the weapon thats need moving to another place
-- there cannot exist two attc that move one part to 2 different CFrames
-- I think this model can be reduced to 2 iterations tho
-- gear : a gear model
function module.attachAll(gear)
	-- since some attachments move parts, it'll detect they were moved,
	-- and re-place the attachments in the next loop based on those moved parts
	local iterationCnt = 0
	local doneMoving = false
	while doneMoving == false do
		iterationCnt = iterationCnt + 1
		if iterationCnt > 50 then
			error("infinite loop")
		end
		doneMoving = true
		for i,v in ipairs(gear.Attachments:GetChildren()) do
			local didmove = module.attach(gear, v)
			if didmove then
				--warn(v:GetFullName())
				doneMoving = false
			end
		end
	end
	
	for _, v in ipairs(gear.AttachmentParts:GetChildren()) do
		if v:IsA("BasePart") then
			v.Transparency = 1
		end
	end
	for _, v in ipairs(gear:GetChildren()) do
		if v:IsA("BasePart") then
			v.Transparency = 1
		end
	end
end

-- gear:  a gear model
-- attc: an attachment model
function module.attach(gear, attc)
	local attachTo = nil
	for i,v in ipairs(attc:GetChildren()) do
		if v.Name:find("attc_") then
			v.Transparency = 1
			attachTo = v
			break
		elseif v:IsA("ModuleScript") then
			v:Destroy()
		end
	end
	attc.PrimaryPart = attachTo

	-- get the substring after 'attc_'
	-- move the model there
	local attcType = string.sub(attachTo.Name, 6)
	attc:SetPrimaryPartCFrame(gear.AttachmentParts[attcType].CFrame)

	-- keep track if there's moved gear parts.
	-- (if there is, then we have to attach all again)
	local moved = false
	for i, v in ipairs(attc:GetChildren()) do
		-- check if there exists the request to move some parts
		if v:FindFirstChild("ReplaceCFrame") then
			if string.sub(v.Name, 0, 2) == "r_" then
				v.Transparency = 1
				-- get the part that needs moving
				local partName = string.sub(v.Name, 3)
				local movePart = gear:FindFirstChild(partName, true)
				if movePart then
					-- v.CFrame is the desired CFrame
					--warn((v.CFrame.p - movePart.CFrame.p):isClose(Vector3.new(0, 0, 0), 1e-4))
					--if tostring(v.CFrame) ~= tostring(movePart.CFrame) then
					if not (v.CFrame.p - movePart.CFrame.p):isClose(Vector3.new(0, 0, 0), 1e-4) then
						moved = true
						movePart.CFrame = v.CFrame
					end
					movePart.Transparency = 1
				elseif string.sub(attc.Name, 1, 3) ~= "No " then
					error("the r_part "..partName.." is not found in "..gear.Name.." for attachment "..attc.Name)
				else
					warn("ignore the r_part error for "..attc.Name)
				end
			end
		end
	end
	return moved
end

-- gear     : the (base) gear model (without attachments but with bricks for animation)
-- attcName: a string representing the name of the attachment
function module.cloneAttcInto(gear, attcName)
	local attc = Attachments:FindFirstChild(attcName, true)
	if attc then
		attc = attc:clone()
		attc.Parent = gear.Attachments

		-- associated attachements, eg front sight
		if attc:FindFirstChild("AttachmentData") then
			for i,v in ipairs(attc.AttachmentData.Effects:GetChildren()) do
				if v.Name == "Adds" then
					module.cloneAttcInto(gear, v.Value)
				end
			end
		end
	else
	 	error("Attachment "..attcName.." is not found for weapon "..gear.Name)
	end
end

-- return the tool with its attachments (not welded tho)
-- and the invisible blocks for animation
function module.assemble(gunFolder, attcList)

	local gear = gunFolder.Tool:Clone()
	gear.PrimaryPart = gear.Main.Center

	for _, attcName in pairs(attcList) do
		module.cloneAttcInto(gear, attcName)
		--warn(attcName)		
	end

	module.attachAll(gear)
	return gear
end

local function availableTo(gunName, validGunNames)
	if validGunNames == "all" then return true end
	for _, g in ipairs(validGunNames) do
		if g == gunName then
			return true
		end
	end
	return false
end

function module.getStats(gunFolder, attcList)
	local baseStats = require(gunFolder.BaseStats)
	local gunName = gunFolder.Name

	-- make a copy
	local stats = {}
	for k1, t in pairs(baseStats) do
		stats[k1] = {}
		local cur = stats[k1]
		for k2, v in pairs(t) do
			cur[k2] = v
		end
	end

	-- adjust the copy based on the attcList
	-- first sort the adjustments(operations, oprs) into three categories
	local oprs = {set = {}, mul = {}, add = {}}
	for _, attcName in pairs(attcList) do
		local attc = Attachments:FindFirstChild(attcName, true)
		local attcStatsFile = attc:FindFirstChild("Stats")
		if attcStatsFile then
			local attcStats = require(attcStatsFile)

			-- interate through each modifications associated with this attc
			for _, opr in ipairs(attcStats) do
				if availableTo(gunName, opr.availableTo) then
					table.insert(oprs[opr.mode], {
						f1  = opr.f1,
						f2  = opr.f2,
						val = opr.val
					})
				end
			end
		else
			warn("No Stats file found for "..attcName)
		end
	end

	-- apply those operations in order (set, mul, add)
	local order = {"set", "mul", "add"}
	for _, oprType in ipairs(order) do
		local t = oprs[oprType]
		for _, opr in ipairs(t) do
			if oprType == "set" then
				stats[opr.f1][opr.f2] = opr.val
			elseif oprType == "mul" then
				stats[opr.f1][opr.f2] = stats[opr.f1][opr.f2] * opr.val
			elseif oprType == "add" then
				stats[opr.f1][opr.f2] = stats[opr.f1][opr.f2] + opr.val
			end
		end
	end

	return stats
end

return module
