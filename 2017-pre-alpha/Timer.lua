-- the timer class for counting down the capture time
-----------------------------------------------------

local Timer = {}
Timer.__index = Timer

-- statics
Timer.dec = 0.1

-- instance variables
function Timer:reset()
	self.on = false
	self.T = self.maxT
end

function Timer.new(maxT)
	local timer = {}
	setmetatable(timer, Timer)
	timer.maxT = maxT
	timer:reset()
	return timer
end

function Timer:continue()
	if self.on then
		return
	end
	self.on = true
	spawn(function()
		while self.on and wait(Timer.dec) do
			if self.T - self.dec < 0 then
				self.T = 0
			else
				self.T = self.T - self.dec
			end
		end
	end)
end

function Timer:freeze()
	self.on = false
end

function Timer:isOver()
	return self.T <= 0
end

return Timer
