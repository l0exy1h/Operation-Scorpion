-- oop: dynamic camrea
-- dynamic means the camera may move a bit based on the player's mouse

local DynamicCamera = {}
DynamicCamera.__index = DynamicCamera

-- static var
local threadCnt = 0

-- defs
local cam   = workspace.CurrentCamera
local rs    = game:GetService("RunService").RenderStepped
local plr   = game.Players.LocalPlayer
local mouse = plr:GetMouse()

local random    = math.random
local noise     = math.noise
local rad       = math.rad
local newCFrame = CFrame.new  

-- consts
local scrollMax = 3 -- in studs
local scrollDelta  = 0.1

function DynamicCamera.new(_tableModel)
	local self = {
		tableModel       = _tableModel,
		camPart          = script:WaitForChild("CamPart"):Clone(),
		enabled          = true, 
		dynamicEnabled   = false,
		scrollingEnabled = false,
		scroll           = 0,
		scrollingCon     = {},
	}
	self.camPart.Parent = _tableModel
	self.camPart.Name   = "CamPart"
	setmetatable(self, DynamicCamera)
	return self
end

function DynamicCamera:moveTo(cf)
	if cf:IsA("BasePart") then cf = cf.CFrame end
	self.camPart.CFrame = cf 
end

function DynamicCamera:setEnabled(bool)
	if bool and not self.enabled then
		cam.CameraType = Enum.CameraType.Scriptable 
		--self.enabled   = true
		spawn(function()
			local tTick   = tick()
			local camPart = self.camPart
			while self.enabled do
				local lu = tick()
				rs:wait()
			
				-- considering scrolling here				
				local base = camPart.CFrame + camPart.CFrame.lookVector * self.scroll				
	
				-- considering dynamic behavior here				
				if self.dynamicEnabled then
					local ut    = tick()-lu
					local uTick = tick()-tTick
					local MX    = ((mouse.X/mouse.ViewSizeX)-0.5)*2 
					local MY    = ((mouse.Y/mouse.ViewSizeY)-0.5)*2		 
					
					cam.CFrame = (base * newCFrame((1-MX)*-0.6,0,(MY)*-0.8))*newCFrame(
							(random()-0.5)*0.005,
							(random()-0.5)*0.005,
							(random()-0.5)*0.005
						)*CFrame.fromEulerAnglesYXZ(
							noise(uTick/5)*rad(3)-MY*rad(20)-rad(10),
							noise(uTick/5+7.76352)*rad(3)-MX*rad(10),
							noise(uTick/5+1.23252)*rad(1)
						)
				else
					cam.CFrame = base
				end
			end
		end)
		threadCnt = threadCnt + 1
		if threadCnt > 1 then
			warn("more than one dynamic cam modules are functioning at the same time!!")
		end
	elseif not bool and self.enabled then
		self.enabled   = false
		threadCnt      = threadCnt - 1 
		cam.CameraType = Enum.CameraType.Custom
		if threadCnt < 1 then
			warn("threadCnt < 1")
		end
	end
end

function DynamicCamera:setDynamic(bool)
	self.dynamicEnabled = bool
end

function DynamicCamera:setScrolling(bool)
	if bool and not self.scrollingEnabled then
		-- set up connections
		self.scrollingCon[#self.scrollingCon + 1] = mouse.WheelForward:connect(function()
			local newScroll = self.scroll + scrollDelta
			self.scroll     = newScroll < scrollMax and newScroll or scrollMax  
		end)
		self.scrollingCon[#self.scrollingCon + 1] = mouse.WheelBackward:connect(function()
			local newScroll = self.scroll- scrollDelta
			self.scroll     = newScroll > 0 and newScroll or 0  
		end)
		
	elseif not bool and self.scrollingEnabled then
		-- disconnects!
		for _, con in ipairs(self.scrollingCon) do
			con:disconnect()
		end
		self.scrollingCon = {}
		self.scroll = 0
	end
	
	self.scrollingEnabled = false
end

return DynamicCamera


