-- client side gui for hardpoint
--------------------------------

local HPMarker = {}
HPMarker.__index = HPMarker

-- def
local rep = game.ReplicatedStorage
local gm = rep:WaitForChild("GlobalModules")
local ga = require(gm:WaitForChild("GeneralAnimation"))
local sd = require(gm:WaitForChild("ShadedTexts"))
local white = Color3.fromRGB(255, 255, 255)
local rs = game:GetService("RunService").RenderStepped
local remote = rep:WaitForChild("Events"):WaitForChild("MainRemote")
local cam = workspace.CurrentCamera
local cx, cy = cam.ViewportSize.X/2, cam.ViewportSize.Y/2 
local hideRadius = 75
local lp = game.Players.LocalPlayer
local hpBar = lp:WaitForChild("PlayerGui"):WaitForChild("ScreenGui"):WaitForChild("Gameplay"):WaitForChild("HpBar")
local atBar = 0.22			-- animation time for the bar 

local function getTeamColor(t)
	if t == nil then
		return white
	else
		return t.TeamColor.Color
	end
end

-- static variables
HPMarker.TransparencyLo = .44
HPMarker.TransparencyMi = .88
HPMarker.TransparencyHi = .90

-- instance variables
function HPMarker:reset()
	self.mouseIn  = false
	self.lpIn     = false
	self.changing = false
	self.owner    = nil
	--self.lpCaptured = false
	self:setTransparency(HPMarker.TransparencyLo)
	self.bgui.Changing.Size = UDim2.new(1.5, 0, 0, 0)
	self:changeOwner(nil)	
	self:hideGui()
end

-- constructor
function HPMarker.new(cyl)
	local hp = {}
	setmetatable(hp, HPMarker)
	-- connect the module to the cyl
	hp.name = cyl.Name
	hp.cyl = cyl
	
	-- connect the module to the gui, and clear all existing guis
	hp.bgui = script.BillboardGui:Clone()
	for _i, gui in ipairs(cyl:GetChildren()) do
		if gui:IsA("BillboardGui") then
			gui:Destroy()
		end
	end
	hp.bgui.Parent = cyl	
	sd.setProperty(hp.bgui.SmallTri, "Text", hp.name)
	
	-- setup the capture bar
	hp.sgui = script.Sample:Clone()
	hp.sgui.Name = hp.name
	hp.sgui.Visible = true
	hp.sgui.Parent = hpBar
	
	-- setup listeners
	hp:setupListeners()
	
	-- intialize instance variables
	hp:reset()
	return hp
end

function HPMarker:changeOwner(t)
	local c = getTeamColor(t)
	self.bgui.CurrTri.ImageColor3 = c
	self.bgui.SmallTri.text.TextColor3 = c
	self.owner = t
	self.sgui.Bar.ImageColor3 = c
	if t == lp.Team then
		sd.setProperty(self.sgui.CaptureText, "Text", "Captured  "..self.name)
	else
		sd.setProperty(self.sgui.CaptureText, "Text", "Capturing  "..self.name)
	end
end

function HPMarker:setChangingHeight(t, T)
	self.bgui.Changing.Size = UDim2.new(1.5, 0, 1.5 * (T - t) / T, 0)
	self.sgui.Bar.Inner.Size = UDim2.new((T - t) / T, 0, 1, 0)
end

function HPMarker:getTransparency()
	return self.bgui.CurrTri.ImageTransparency
end

function HPMarker:startChanging(curr, next, startT, totalT)
	if self.changing then
		self.changing = false
	end
	
	self:changeOwner(curr)
	local c = getTeamColor(next)
	self.bgui.Changing.Tri.ImageColor3 = c
	self.sgui.Bar.Inner.ImageColor3 = c
	self:setChangingHeight(startT, totalT)
	
	local t = startT
	local st = tick()
	local tmpInc = .01	-- transparency increment
	self.changing = true
	spawn(function()		
		while self.changing and t >= 0 and rs:wait() do
			t = startT - (tick() - st)
			self:setChangingHeight(t, totalT)
			
			-- the flashing effect
			if not self.mouseIn and not self.lpIn then				
				local tmpTrans = self:getTransparency() + tmpInc 
				if tmpTrans > HPMarker.TransparencyMi then
					tmpTrans = HPMarker.TransparencyMi
					tmpInc   = -tmpInc
				elseif tmpTrans < HPMarker.TransparencyLo then
					tmpTrans = HPMarker.TransparencyLo
					tmpInc   = -tmpInc
				end
				self:setTransparency(tmpTrans)
			end
		end
	end)
end

function HPMarker:pauseChanging()
	self.changing = false
end

function HPMarker:stopChanging()
	self.changing = false
	wait(0.1)
	self.bgui.Changing.Size = UDim2.new(1.5, 0, 0, 0)
	self.sgui.Bar.Inner.Size = UDim2.new(0, 0, 1, 0)
end

function HPMarker:setTransparency(t)
	for _, gui in ipairs(self.bgui:GetDescendants()) do
		if gui:IsA("ImageLabel") then
			gui.ImageTransparency = t
		elseif gui:IsA("TextLabel") then
			gui.TextTransparency = t
		end
	end
end

function HPMarker:setupListeners()
	remote.OnClientEvent:connect(function(func, args)
		if string.find(func, "HP::") and args[1] == self.name then
			if func == "HP::showGui" then
				self:showGui()
			elseif func == "HP::hideGui" then
				self:hideGui()
			elseif func == "HP::changeOwner" then
				self:changeOwner(args[2])
			elseif func == "HP::pauseChanging" then
				self:pauseChanging()
			elseif func == "HP::startChanging" then
				self:startChanging(args[2], args[3], args[4], args[5])
			elseif func == "HP::stopChanging" then
				self:stopChanging()
			elseif func == "HP::reset" then
				self:reset()
			end
		end
	end)
	
	-- transparency control: mouseIn || lpIn
	spawn(function()
		while rs:wait() do
			-- hide the marker when the local player is in
			local inCyl = self:inCyl(lp)
			if not self.lpIn and inCyl then
				self.lpIn = true
				self:setTransparency(1)
				
				-- show bar gui
				if self.owner == lp.Team then
					self.sgui.Bar.Inner.Size = UDim2.new(1, 0, 1, 0)
					sd.setProperty(self.sgui.CaptureText, "Text", "Captured  "..self.name)
				else
					sd.setProperty(self.sgui.CaptureText, "Text", "Capturing  "..self.name)
					self.sgui.Bar.Inner.Size = UDim2.new(0, 0, 1, 0)
				end

				sd.fade(self.sgui.CaptureText, -1, atBar)				
				ga.animateProperty(self.sgui.Bar, "ImageTransparency", 0.5, atBar)
				ga.animateProperty(self.sgui.Bar.Inner, "ImageTransparency", 0.1, atBar)
			elseif self.lpIn and not inCyl then
				self.lpIn = false
				
				-- hide bar gui
				sd.fade(self.sgui.CaptureText, 1, atBar)
				ga.animateProperty(self.sgui.Bar, "ImageTransparency", 1, atBar)
				ga.animateProperty(self.sgui.Bar.Inner, "ImageTransparency", 1, atBar)
			end
			--warn(self.name, self.lpIn, inCyl)
				
			if not self.lpIn then
				-- increase transparency when mouse hover
				local vec = cam:WorldToScreenPoint(self.cyl.CFrame.p)
				local vx, vy = vec.X, vec.Y
				local a, A = (cx - vx) * (cx - vx) + (cy - vy) * (cy - vy), hideRadius * hideRadius
				if a <= A then
					self.mouseIn = true
					self:setTransparency(HPMarker.TransparencyHi 
						+ (HPMarker.TransparencyLo - HPMarker.TransparencyHi) * a / A)
				else 
					if self.mouseIn then
						self.mouseIn = false
						self:setTransparency(HPMarker.TransparencyLo)
					end
				end
			end
		end
	end)	
	
	--[[rep.Stage.Changed:connect(function()
		if rep.Stage.Value == "Wait End" then
			self:showGui()
		end
	end)--]]
end

function HPMarker:inCyl(plr)
	if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
		local plrP = plr.Character.HumanoidRootPart.CFrame.p
		return (plrP * Vector3.new(1, 0, 1) - self.cyl.CFrame.p * Vector3.new(1, 0, 1)).magnitude <= self.cyl.Size.z/2
			and self.cyl.CFrame.p.y + self.cyl.Size.y/2 > plrP.y and plrP.y > self.cyl.CFrame.p.y - self.cyl.Size.y/2
	end
	return false
end

function HPMarker:showGui()
	self.bgui.Enabled = true	
	self.sgui.Visible = true
end

function HPMarker:hideGui()
	self.bgui.Enabled = false
	self.sgui.Visible = false
end

return HPMarker