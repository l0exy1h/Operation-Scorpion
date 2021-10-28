--disable roblox core gui chat
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat,false)

local GUI = script.Parent
local CS = GUI:WaitForChild("ChatSender")
local TextArea = CS:WaitForChild("TextArea")
local storage = game.ReplicatedStorage
local CA = GUI:WaitForChild("ChatArea")
local Messages = CA:WaitForChild("Messages")
local chatRemote = storage:WaitForChild("PlayerChatUpdate")
local lp = game.Players.LocalPlayer
local rs = game:GetService("RunService").RenderStepped
local lpGUI = lp:WaitForChild("PlayerGui")

local rep = game.ReplicatedStorage
local gm = rep:WaitForChild("GlobalModules")
local sd = require(gm:WaitForChild("ShadedTexts"))
local chatGUImodule = require(gm:WaitForChild("chatGUI"))
local gf = require(gm:WaitForChild("GeneralAnimation"))

local moveUpTime = 0.22 
local msgStayingSpan = 5
local limit = 44   -- max chat length

-- set screen size to contain integer number of msg frames
---------------------------------
local frameHeight = chatGUImodule.frameHeight + chatGUImodule.gap
local function adjustChatArea()
	local currH = CA.AbsoluteSize.Y
	local maxCnt = math.ceil(GUI.ScreenSize.AbsoluteSize.Y * CA.Size.Y.Scale/ frameHeight)
	local offsetH = math.min(maxCnt, math.ceil(currH * 1.0 / frameHeight)) * frameHeight - currH
	--warn(currH, offsetH)
	CA.Position = CA.Position + UDim2.new(0, 0, 0, -offsetH)
	CA.Size = CA.Size + UDim2.new(0, 0, 0, offsetH)
end
wait(1)
adjustChatArea()
GUI.ScreenSize.Changed:connect(function(p)
	if p == "AbsoluteSize" then
		adjustChatArea()
	end
end)

-- move chat bindable event
---------------------------------
script:WaitForChild("MoveChat").Event:connect(function(pos)
	CA.Position = pos
end)


-- receiver and GUI
---------------------------------
local lastT = tick()
local CAstatus = "shown"
local function toDir(dir)
	return dir == "out" and 1 or -1
end
local function fadeMsgPanel(p, dir, Time)
	--warn("fadeMsgPanel", p, dir, Time)
	--dir = toDir(dir)
	--warn(dir)
	for i, fr in ipairs(p:GetChildren()) do
		if -fr.Position.Y.Offset <= Messages.AbsoluteSize.y + frameHeight * 2 then
			spawn(function()
				gf.animateProperty(fr.msg.RoundBG, "ImageTransparency", dir == "in" and 0.66 or 1, dir == "in" and 1 or 0.66, Time)
			end)
			spawn(function()
				gf.animateProperty(fr.sdr.RoundBG, "ImageTransparency",dir == "in" and 0.66 or 1, dir == "in" and 1 or 0.66, Time)
			end)
			spawn(function()
				if fr.sdr:FindFirstChild("Icon") then
					gf.animateProperty(fr.sdr.Icon, "ImageTransparency", dir == "in" and 0 or 1, dir == "in" and 1 or 0, Time, dir)
				end
			end)
			spawn(function()
				sd.fade(fr.sdr, toDir(dir), Time)
			end)
			spawn(function()
				sd.fade(fr.msg, toDir(dir), Time)
			end)
		end
	end
end
local function appear()
	lastT = tick()
	if CAstatus == "hidden" then
		CAstatus = "toShown"
		fadeMsgPanel(Messages, "in", moveUpTime)
		wait(moveUpTime)
		CAstatus = "shown"
	end
end
local function disappear()
	if CAstatus == "shown" then
		CAstatus = "toHidden"
		fadeMsgPanel(Messages, "out", moveUpTime)
		wait(moveUpTime)
		CAstatus = "hidden"
	end
end
spawn(function()
	while true do
		--warn(CAstatus, tick() - lastT)
		if CAstatus == "shown" and tick() - lastT > msgStayingSpan then
			disappear()
		end
		wait(0.5)
	end
end)
local msgQueue = {}
chatRemote.OnClientEvent:connect(function(sdr, msg, channel)
	print("[client, chat]", sdr, msg, channel)
	table.insert(msgQueue, {["sdr"] = sdr, ["msg"] = msg, ["channel"] = channel})
end)
local processingMsg = false
spawn(function()
	while rs:wait() do
		if processingMsg == false then
			if #msgQueue > 0 then
				processingMsg = true				
				local curr = table.remove(msgQueue, 1)
				--warn("[client, chatQueue]", curr.sdr, curr.msg, curr.channel)
				-- show the current message frames
				local newFrame = chatGUImodule.createMsgFrame(curr.sdr, curr.msg, curr.channel)	
				-- animation! and deletion
				-- move up previous message frames
				appear()
				for i, frame in ipairs(Messages:GetChildren()) do
					frame:TweenPosition(frame.Position + UDim2.new(0, 0, 0, -frameHeight), "Out", "Quad", moveUpTime)
					if -frame.Position.Y.Offset > Messages.AbsoluteSize.y + frameHeight * 2 then
						--warn("delete frame of height", -frame.Position.Y.Offset)
						frame:Destroy()
					end
				end
				newFrame.Position = UDim2.new(0, 0, 1, 0)
				newFrame.Parent = Messages
				newFrame:TweenPosition(UDim2.new(0, 0, 1, -frameHeight), "Out", "Quad", moveUpTime)								
				wait(moveUpTime)
				processingMsg = false
			end
		end
	end
end)

---------------------------------


-- input bar
---------------------------------
local CSinPos = UDim2.new(0, 0, 1, -26)
local CSoutPos = UDim2.new(0, 0, 1, 0)
local channel = nil
local function onSlashPressed(actionName, inputState, inputObject)
	appear()
	CS:TweenPosition(CSinPos, "In", "Sine", 0.1)
	if inputState == Enum.UserInputState.End then		
		TextArea.TextBox:CaptureFocus()
		TextArea.TextBox.Text = ""
		if inputObject.KeyCode == Enum.KeyCode.Period and lp.Neutral == false then
			channel = "team"
			TextArea.TextBox.PlaceholderText = "Team Chat"
		else
			channel = "global"
			TextArea.TextBox.PlaceholderText = "Global Chat"
		end
	end
	--warn(actionName, inputState, inputObject.KeyCode == Enum.KeyCode.Y and "global" or "team")
end
game:GetService("ContextActionService"):BindAction("Chatting", onSlashPressed, false, Enum.KeyCode.Slash, Enum.KeyCode.Period)
local function onCommaPressed(actionName, inputState, inputObject)
	appear()
end
game:GetService("ContextActionService"):BindAction("viewChat", onCommaPressed, false, Enum.KeyCode.Comma)
TextArea.TextBox.FocusLost:connect(function(enterPressed) 
	if enterPressed and TextArea.TextBox.Text ~= "" then
		chatRemote:FireServer(TextArea.TextBox.Text, channel)
	end
	TextArea.TextBox.Text = ""
	CS:TweenPosition(CSoutPos, "In", "Sine", 0.1)
end)
--[[storage.MainframeEvents.Stage.MatchBegin.OnClientEvent:connect(function()
	if TextArea.TextBox:IsFocused() == false then
		CS:TweenPosition(CSoutPos, "In", "Sine", 0.1)
	end
end)--]] 
-- limiting the length of the input
TextArea.TextBox.Changed:connect(function(p)
	if p == "Text" and TextArea.TextBox:IsFocused() then
		if string.len(TextArea.TextBox.Text) > limit then
			TextArea.TextBox.Text = string.sub(TextArea.TextBox.Text, 1, limit)
		end
	end
end)
---------------------------

local events = rep:WaitForChild("Events")
local loadingEvent = events:WaitForChild("Loading")
local scriptLoaded = Instance.new("BoolValue")
scriptLoaded.Name  = "LocalChatHandler"
scriptLoaded.Parent= loadingEvent
-- 