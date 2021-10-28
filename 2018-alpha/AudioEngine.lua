--Settings and Configuration--
local cfig_speedOfSound = 1125
local ocfig_reverbTransitionTime = 0.45
local cfig_reverbTransitionTime = ocfig_reverbTransitionTime
local cfig_boxGridSize = 10
local cfig_studsPerUpdate = 2
------------------------------


local SOSQueue = {}  -- List of audio waiting due to the speed of sound delay
local MainList = {} -- List of all parts that hold audio, their stats, and the sounds inside em.
local AmbienceAudio = {} --Ambient sounds per zone
local ConnectedBoxes = {}

--Initializing Variables--
local RS = game:GetService("RunService").RenderStepped
local SP = game:GetService("RunService").Stepped
local HB = game:GetService("RunService").Heartbeat
local rep   = game.ReplicatedStorage
local gm    = rep:WaitForChild("GlobalModules")
local Mathf = require(gm:WaitForChild("Mathf"))
local ListenPos = Vector3.new()
local startTick = tick()
local ListenReverb = "None"
local ListenBox = nil
local LastBox = nil

local OriginPart
local AmbientBoxes
local MovingBoxes
local BoxGrid

local PartList = {}
--local Debugger  --Debugger code has been disabled as it caused bugs on death.
local Effects = script.Effects:GetChildren()

local updateTime = 1/60

--deubgging--
tscount = 0
ascount = 0
tecount = 0
aecount = 0

pID = 0
-------------

--------------------------

function cTick() --simplifies tick for more accuracy on other numbers
	return tick()-startTick
end

function GetID()
	pID = pID + 1
	return pID
end

function event_Event(func,args)
	if args[1] == nil then return end -- y0rkl1u
	if func == "Play" then
		event_ActivateSound(args[1],args[2],args[3]) -- 1: sound // 2: create new sound // 3: speed of sound enabled
	elseif func == "PlayNew3D" then
		event_PlayNew3d(args[1],args[2],args[3]) -- 1: sound // 2: position // 3: sos
	end
end

function event_PlayNew3d(s,pos,sos)
	local atc = Instance.new("Attachment",OriginPart)
	atc.Position = pos
	
	local ns = s:clone()
	ns.Parent = atc
	
	rem=Instance.new("BoolValue")
	rem.Name="RemoveWhenDone"
	rem.Parent=s
	
	event_ActivateSound(s,false,sos)
end

function event_ActivateSound(s,cnew,sos)
	if sos then
		local distance = (ListenPos - (s.Parent:IsA("BasePart") and s.Parent.Position or s.Parent.WorldPosition)).magnitude
		local sosTime = distance / cfig_speedOfSound
		if sosTime >= 1/30 then
			table.insert(SOSQueue,{s,cnew,sosTime,cTick()})
		else
			event_PlaySound(s,cnew)
		end
	else
		event_PlaySound(s,cnew)
	end
end

function event_DescendantAdded(obj)
	if obj.Name=="AutoPlaySound" then
		obj.Archivable = false
		event_ActivateSound(obj.Parent,obj.Value,true)
		game.Debris:AddItem(obj,0.01)
	end
end

function event_PlaySound(s,cnew)
	s.RollOffMode = Enum.RollOffMode.Linear
	if cnew then
		ns=s:clone()
		ns.Name = s.Name.."_SENew"
		ns.Parent=s.Parent
		s=ns
		rem=Instance.new("BoolValue")
		rem.Name="RemoveWhenDone"
		rem.Parent=s
	end
	if s:FindFirstChild("SoundStats") == nil then
		s:play()
		return
	end
	local hasloaded = s:FindFirstChild("SELoaded")
	if hasloaded then
		if s.SELoaded.Value==true then
			s:play()
			s.TimePosition = 0.01
			return
		end
	end
	local ptTab
	local ptFound=false
	sID = s.Parent:FindFirstChild("PartID")
	if sID then
		pl = PartList[sID.Value]
		if pl[1] == s.Parent then
			ptFound = true
			ptFound = MainList[pl[2]]
		end
	else
		sID = Instance.new("IntValue")
		sID.Name = "PartID"
		sID.Value = GetID()
		sID.Parent = s.Parent
		PartList[sID.Value] = {s.Parent,MainList[#MainList+1]}
	end
	
	SoundStats = s.SoundStats
	if SoundStats:IsA("StringValue") then
		SoundStats2 = script.SoundTemplates[SoundStats.Value]:clone()
		SoundStats2.Parent = s
		SoundStats2.Name = "SoundStats"
		if s:FindFirstChild("CustomVolume") then
			SoundStats2.Volume.Value = s.CustomVolume.Value
		end
		SoundStats:Destroy()
		SoundStats = SoundStats2
	end
	
	if not ptFound then
		ptTab = {}
		ptTab.Data = {}
		ptTab.Data.Part = s.Parent
		ptTab.Data.LastPosition = Vector3.new()
		ptTab.Data.Reverb = "None"
		ptTab.Data.ParentType = s.Parent:IsA("BasePart")
		--ptTab.Data.ID = 0
		ptTab.Data.Distance = 1  --Sets standard values
		ptTab.Data.MaxRange=SoundStats.Range.Value
		ptTab.Sounds={}
		--[[local IGLayer = s.Parent --Finds the object that the part the sound is in should ignore
		for i = 1,s.Parent.IgnoreLayer.Value do
			IGLayer=IGLayer.Parent
		end
		ptTab.Data.IgnoreLayer=IGLayer]]
	end
	
	ptTab.Data.MaxRange=math.max(ptTab.Data.MaxRange,SoundStats.Range.Value)
	
	if not hasloaded then --Lets the code know the sound is loaded
		nv=Instance.new("BoolValue",s)
		nv.Name="SELoaded"
		nv.Archivable = false
		
		s.RollOffMode = Enum.RollOffMode.Linear
		
		for i,v in ipairs(Effects) do
			vp = v:clone()
			vp.Parent=s
			vp.Archivable = false
		end
	else
		s.SELoaded.Value=true
	end

	s.MaxDistance = SoundStats.Range.Value
	table.insert(ptTab.Sounds,s)
	
	s:play()
	s.TimePosition = 0.01
	s:pause()
	SoundStats.PausedTick.Value = tick()-startTick
	ml_UpdateContainer(ptTab,true)

	if not ptFound then
		table.insert(MainList,ptTab)
	end
end

function ml_GetReverb(pos)
	local cTier=0
	local cVal="None"
	local cBox = nil
	--local cID = 0
	local gSquare = Vector2.new(Mathf.round(pos.x,cfig_boxGridSize,0),Mathf.round(pos.z,cfig_boxGridSize,0))
	local grid = BoxGrid[gSquare.x..","..gSquare.y]	
	--[[if pos == ListenPos then
		if grid ~= nil then
			Debugger.BoxCount.Text = #grid.." Active Boxes"
		else
			Debugger.BoxCount.Text = "No Active Boxes"
		end
	end	]]
	if grid ~= nil then
		for i,v in ipairs(grid) do
			rel = v.CFrame:pointToObjectSpace(pos)
			if math.abs(rel.x) <= v.Size.x/2 and math.abs(rel.y) <= v.Size.y/2 and math.abs(rel.z) <= v.Size.z/2 then
				if v.AmbienceBox.Tier.Value >= cTier then
					cVal = v.AmbienceBox.Value
					cTier = v.AmbienceBox.Tier.Value
					--cID = v.AmbienceBox.ID.Value
					cBox = v
				end
			end
		end
	end
	if #MovingBoxes > 0 then
		for i,v in ipairs(MovingBoxes) do
			rel = v.CFrame:pointToObjectSpace(pos)
			if math.abs(rel.x) <= v.Size.x/2 and math.abs(rel.y) <= v.Size.y/2 and math.abs(rel.z) <= v.Size.z/2 then
				if v.AmbienceBox.Tier.Value > cTier then
					cVal = v.AmbienceBox.Value
					cTier = v.AmbienceBox.Tier.Value
					--cID = v.AmbienceBox.ID.Value
					cBox = v
				end
			end
		end
	end
	return cVal,cBox
end

function GetConnected()
	
end

function ml_UpdateAudio(dat,s,inst,connected)
	if inst then
		cfig_reverbTransitionTime=0.0001
	else
		cfig_reverbTransitionTime=ocfig_reverbTransitionTime
	end
	local SoundStats = s.SoundStats
	local distPerc = Mathf.clamp(1-dat.Distance/SoundStats.Range.Value,0,1)
	s.Volume = SoundStats.Volume.Value*distPerc^SoundStats.VolumeExponent.Value
	if s.Volume > 0.01 then
		if s.IsPaused==true then
			if s.Looped == true or s.TimePosition ~= 0 then
				s:Play()
				s.TimePosition = Mathf.wrap(s.TimePosition+((tick()-startTick)-SoundStats.PausedTick.Value),0.01,s.TimeLength)
			elseif s.Looped == false and s.TimePosition ~= 0 then
				if s.TimePosition+((tick()-startTick)-SoundStats.PausedTick.Value) > s.TimeLength then
					return
				else
					s:Play()
					s.TimePosition = s.TimePosition+((tick()-startTick)-SoundStats.PausedTick.Value)
				end
			else
				return
			end
		end
		ascount = ascount+1
		if script.SimpleSound.Value == false then
			local reverbType = "Default"
			if SoundStats.ReverbType.Value ~= "" then
				if script.Ambiences[dat.Reverb]:FindFirstChild(SoundStats.ReverbType.Value) then
					reverbType = SoundStats.ReverbType.Value
					--print("SetReverbType: "..reverbType)		
				end
			end
			local revt = script.Ambiences[dat.Reverb][reverbType]
			local rev = revt["Standard"]
			local revp = revt
			local revb = rev
			
			local trev = script.Effects.Reverb
			local teq = script.Effects.Equalizer
			if not connected then
				revp = script.Ambiences[dat.Reverb][reverbType]
				revb = revp["Reverb"]
				teq = revb.Equalizer
				trev = revb.Reverb
				--print("Muffled: "..s.Name)
			else
				--print("Close: "..s.Name)
			end
			--print("Sound: "..s.Name..", Reverb: "..(dat.Reverb)..", Connected: "..tostring(connected))
			local dist = revp["Distant"]
			local req = rev.Equalizer
			local rerev = rev.Reverb
			local deq = dist.Equalizer
			local derev = dist.Reverb
					
			local distamt = (1-distPerc)
			local distmult = distamt^SoundStats.DistantExponent.Value*SoundStats.DistantAmount.Value
			local pitchmult = distamt^SoundStats.PitchExponent.Value--*SoundStats.PitchAmount.Value
			s.Equalizer.HighGain=Mathf.lerp(s.Equalizer.HighGain,req.HighGain+teq.HighGain+deq.HighGain*distmult,Mathf.clamp(updateTime/cfig_reverbTransitionTime,0,1))
			s.Equalizer.LowGain=Mathf.lerp(s.Equalizer.LowGain,req.LowGain+teq.LowGain+deq.LowGain*distmult,Mathf.clamp(updateTime/cfig_reverbTransitionTime,0,1))
			s.Equalizer.MidGain=Mathf.lerp(s.Equalizer.MidGain,req.MidGain+teq.MidGain+deq.MidGain*distmult,Mathf.clamp(updateTime/cfig_reverbTransitionTime,0,1))
			s.Reverb.DecayTime=Mathf.lerp(s.Reverb.DecayTime,rerev.DecayTime+trev.DecayTime+derev.DecayTime*distmult,Mathf.clamp(updateTime/cfig_reverbTransitionTime,0,1))
			s.Reverb.Density=Mathf.lerp(s.Reverb.Density,rerev.Density+trev.Density+derev.Density*distmult,Mathf.clamp(updateTime/cfig_reverbTransitionTime,0,1))
			s.Reverb.Diffusion=Mathf.lerp(s.Reverb.Diffusion,rerev.Diffusion+trev.Diffusion+derev.Diffusion*distmult,Mathf.clamp(updateTime/cfig_reverbTransitionTime,0,1))
			s.Reverb.DryLevel=Mathf.lerp(s.Reverb.DryLevel,rerev.DryLevel+trev.DryLevel+derev.DryLevel*distmult,Mathf.clamp(updateTime/cfig_reverbTransitionTime,0,1))
			s.Reverb.WetLevel=Mathf.lerp(s.Reverb.WetLevel,rerev.WetLevel+trev.WetLevel+derev.WetLevel*distmult,Mathf.clamp(updateTime/cfig_reverbTransitionTime,0,1))
			s.Pitch = SoundStats.Pitch.Value+SoundStats.PitchAmount.Value*pitchmult		
		else
			s.Equalizer.HighGain = 0
			s.Equalizer.MidGain = 0
			s.Equalizer.LowGain = 0
			s.Reverb.DecayTime = 0.1
			s.Reverb.Density = 0
			s.Reverb.Diffusion = 0
			s.Reverb.DryLevel = 0
			s.Reverb.WetLevel = -20
			s.Pitch = SoundStats.Pitch.Value
		end
	elseif s.IsPlaying then
		SoundStats.PausedTick.Value = tick()-startTick
		s:Pause()
	end
end

function ml_UpdateContainer(tab,insta)
	if #tab.Sounds < 1 then return end
	tscount = tscount+#tab.Sounds
	local data=tab.Data
	if data.Part then
		local cPos = data.ParentType == true and data.Part.Position or data.Part.WorldPosition
		data.Distance=(ListenPos-cPos).magnitude
		
		if data.Distance > data.MaxRange then
			return
		end
		aecount = aecount +1
		if (cPos - data.LastPosition).magnitude >= cfig_studsPerUpdate then
			data.Reverb,data.AmbienceBox = ml_GetReverb(cPos)
			data.LastPosition=cPos
		end
		local isConnected
		if ListenBox ~= data.AmbienceBox then
			isConnected = false
			if ListenBox and data.AmbienceBox then
				for i,v in ipairs(ConnectedBoxes) do
					if v == data.AmbienceBox then
						isConnected = true
					end
				end
			end
		else
			isConnected = true
		end
		for a,b in ipairs(tab.Sounds) do
			tscount = tscount+1
			active = b.Looped or b.TimePosition ~= 0 or b.IsPlaying == true
			local ok = active and b.Parent ~= nil
			if not active then
				if b:FindFirstChild("RemoveWhenDone") and b.Parent ~= nil then
					b:Destroy()
				elseif b.Parent ~= nil then
					b.SELoaded.Value=false
				end
				table.remove(tab.Sounds,a)
			end
			if ok then
				ml_UpdateAudio(data,b,insta,isConnected)
			end
		end
	end
end




function MainFunction()
	lastUpdate=cTick()
	while true do
		wait(0.01)
		updateTime=cTick()-lastUpdate
		lastUpdate=cTick()
		--[[Temporary thing]]--
		LastBox = ListenBox
		ListenPos = workspace.CurrentCamera.CFrame.p
		ListenReverb,ListenBox= ml_GetReverb(ListenPos)
		if ListenBox ~= LastBox then
			ConnectedBoxes = {}
			if ListenBox then
				--ListenBox.BrickColor = BrickColor.Random()
				--print("Recalculating box")
				for i,v in ipairs(ListenBox.AmbienceBox.Connections:GetChildren()) do
					table.insert(ConnectedBoxes,v.Value)
				end
			end
		end
		--Debugger.Area.Text = ListenReverb.."//"..ListenID
		-----------------------
		--Handles Speed of Sound delay--
		if #SOSQueue > 0 then
			for i,v in ipairs(SOSQueue) do
				if cTick()-v[4] >= v[3]+1/60 then
					event_PlaySound(v[1],v[2])
					table.remove(SOSQueue,i)
				end
			end
		end
		--------------------------------
		tscount = 0
		ascount = 0
		aecount = 0
		if #MainList > 0 then
			for i,partDat in ipairs(MainList) do
				if #partDat.Sounds < 1 then
					table.remove(MainList,i)
				else
					ml_UpdateContainer(partDat,false)		
				end
			end
		end
		
		--More Debugging--
		--[[Debugger.SoundCount.Text = ascount.." Active Sounds"
		Debugger.SoundTotal.Text = tscount.." Total Sounds"		
		Debugger.EmitterCount.Text = aecount.." Active Emitters"		
		Debugger.EmitterTotal.Text = #MainList.." Total Emitters"]]
		------------------
		
		for i,amb in ipairs(AmbienceAudio) do
			if amb[2] == ListenReverb then
				amb[3] = Mathf.lerpTowards(amb[3],1,updateTime/0.5)
			else
				amb[3] = Mathf.lerpTowards(amb[3],0,updateTime/0.625)
			end
			for a,s in ipairs(amb) do
				if a > 3 then
					s[1].Volume = amb[3]*s[2]
				end
			end
		end
	end
end

function DoWait()
	--[[if script.WaitType.Value == 0 then
		RS:wait()
	elseif script.WaitType.Value == 1 then
		HB:wait()
	elseif script.WaitType.Value == 2 then
		SP:wait()
	else
		wait(0.01)
	end]]
	HB:wait()
end

function Initialize()
	workspace.DescendantAdded:connect(event_DescendantAdded)
	script.AudioEvent.Event:connect(event_Event)
	game.ReplicatedStorage.Events.AudioRemote.OnClientEvent:connect(event_Event)
	
	
	--Debugging--
	--[[Debugger = script.Debugger:Clone()
	Debugger.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")]]
	-------------
	
	MovingBoxes = {}
	BoxGrid = {}
	
	OriginPart = Instance.new("Part",workspace)
	OriginPart.Anchored = true
	OriginPart.CanCollide = false
	OriginPart.Transparency = 1
	OriginPart.Name = "AudioOrigin"
	OriginPart.Size = Vector3.new(0,0,0)
	OriginPart.CFrame = CFrame.new()
	
	--Debugger.BoxTotal.Text = #AmbientBoxes.."Total Boxes"
	
	AmbientBoxes = workspace.Map.AmbientBoxes:GetChildren()
	
	for i,v in ipairs(AmbientBoxes) do
		if v.AmbienceBox.Dynamic.Value == false then
			--v.BrickColor = BrickColor.Yellow()
			local r = math.sqrt(v.Size.x^2+v.Size.y^2+v.Size.z^2)/2
			local R = Mathf.round(r,cfig_boxGridSize,0.999)+cfig_boxGridSize
			for x = -R,R,cfig_boxGridSize do
				for z = -R,R,cfig_boxGridSize do
					local p = v.Position + Vector3.new(x,0,z)
					local P = Vector3.new(Mathf.round(p.x,cfig_boxGridSize,0),p.y,Mathf.round(p.z,cfig_boxGridSize,0))
					--local ip = Mathf.InPart(v,P)
					--if ip then
						local bn = P.x..","..P.z
						if BoxGrid[bn] == nil then
							BoxGrid[bn] = {}
						end
						table.insert(BoxGrid[bn],v)
					--end
					--end			
				end
			end
		else
			table.insert(MovingBoxes,v)
		end
	end
	
	for i,v in ipairs(script.Ambiences:GetChildren()) do
		if v:FindFirstChild("AmbientAudio") then
			local ambList = {v.AmbientAudio,v.Name,0}
			for a,b in ipairs(v.AmbientAudio:GetChildren()) do
				b.Volume=0
				b.Looped=true
				b:play()
				table.insert(ambList,{b,b.MaxVolume.Value})
			end
			table.insert(AmbienceAudio,ambList)
		end
	end
	
	
	local p = workspace:FindFirstChild("AutoPlaySound",true)
	local bs = {}
	while p do
		ok = true
		for i,v in ipairs(bs) do
			if p.Parent == v then
				ok = false
			end
		end
		if ok then
			event_ActivateSound(p.Parent)
			table.insert(bs,p.Parent)
		end
		p:Destroy()
		p = workspace:FindFirstChild("AutoPlaySound",true)
	end
	--if true then return end
	local errorCount = 0
	while true do
		DoWait()
		pcall(MainFunction())
		--print("Sound Errored at "..tick().." Restarting...")
		errorCount = errorCount+1
	end
end



Initialize()