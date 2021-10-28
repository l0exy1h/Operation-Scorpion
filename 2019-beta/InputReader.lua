

local inputSystem = {}

local funcs = {}	  -- {inputType -> {actionName -> func}}
local actions = {}	-- {actionName -> {typeName, keyCode, func, ...}}

local function getHash(inputState, inputType, keyCode)
	return keyCode.Value * 110 + inputType.Value * 5 + inputState.Value
end

function inputSystem.listen(actionName, inputState, inputType, keyCode, func)
	assert(actionName, "actionName is nil")
	assert(inputState, "inputState is nil")
	assert(inputType,  "inputType is nil")
	keyCode = keyCode or "Unknown"
	assert(func,       "func is nil")

	if type(inputState) == "string" then
		inputState = Enum.UserInputState[inputState]
	end
	if type(inputType) == "string" then
		inputType = Enum.UserInputType[inputType]
	end
	if type(keyCode) == "string" then
		keyCode = Enum.KeyCode[keyCode]
	end

	local hash = getHash(inputState, inputType, keyCode)
	actions[actionName] = {
		inputState = inputState,
		inputType  = inputType,
		keyCode    = keyCode,
		func       = func,
		hash       = hash,
	}
	if not funcs[hash] then
		funcs[hash] = {}
	end
	funcs[hash][actionName] = func
end

function inputSystem.unlisten(actionName)
	local action = actions[actionName]
	if action then
		actions[actionName] = nil
		funcs[action.hash][actionName] = nil
	else
		warn("inputSystem.unlisten:", actionName, "is not found.")
	end
end

local function inputHandler(input, g)
	if g then return end
	local hash = getHash(input.UserInputState, input.UserInputType, input.KeyCode)
	local funcs = funcs[hash]
	if funcs then
		for _, func in pairs(funcs) do
			func(input)
		end
	end
end
game:GetService("UserInputService").InputBegan:Connect(inputHandler)
game:GetService("UserInputService").InputEnded:Connect(inputHandler)
game:GetService("UserInputService").InputChanged:Connect(inputHandler)

return inputSystem
