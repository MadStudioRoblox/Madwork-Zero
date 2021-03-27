local Madwork = _G.Madwork
--[[
{Madwork}

-[InputController]---------------------------------------
	Basic centralized management of user input devices
	
	Members:
	
		InputController.ICEnum                   [table] -- Custom input enumerators
		
		InputController.UIDPadSignal             [ScriptSignal](vector2) -- Custom DPad controller for navigating UI; Can only go in direction of one axis at a time
			-- Vector2.new(1, 0) or Vector2.new(-1, 0) or Vector2.new(0, 1) or Vector2.new(0, -1)
			
		InputController.UserInputDevice          [string] -- "Keyboard" / "Gamepad" / "Touch"
		InputController.UserInputDeviceChanged   [ScriptSignal](user_input_device)
	
	Functions:
	
		-- SETUP:
		InputController.SetupDefaultActions(game_type) -- Chosen from SETTINGS.DefaultActionSetup
		InputController.SetupCustomActions(action_setup)
			action_setup   [table]:
				{
					[ActionName] = { -- Default binds:
						MachineType = input_enum,
						...
					},
					...
				}
				
		InputController.ToggleModalInterface(is_enabled) -- Will disable input for binds with ModalDisable = true
				
		-- ACTIONS:
		InputController.IsActionActive(action_name) --> is_active
		InputController.GetActionSignal(action_name) --> [ScriptSignal](is_active)
		InputController.ToggleAction(action_name, is_active)
		InputController.TriggerAction(action_name) -- Sets action to active and then inactive instantly
		InputController.ResetActions() -- Sets all actions to inactive
		
		InputController.GetActionEnum(action_name, input_type) --> [EnumItem] or [Enum] or [ICEnum] or nil
			-- If multiple binds exist for an action input type (table of binds), first bind is returned
		
		-- GAMEPAD:
		InputController.SetThumbstickDeadzone(deadzone) -- Clamping value for thumbstick orientation getters
		InputController.GetThumbstick1() --> [Vector2] -- Starts at {0, 0} from deadzone
		InputController.GetThumbstick2() --> [Vector2] -- Starts at {0, 0} from deadzone
		
		InputController.GetTrigger1() --> [number]
		InputController.GetTrigger2() --> [number]
		
--]]

local ICEnum = {
	MouseWheelUp = {Axis = "Z", Direction = 1},
	MouseWheelDown = {Axis = "Z", Direction = -1},
	
	Thumbstick1Up = {Axis = "Y", Direction = 1},
	Thumbstick1Down = {Axis = "Y", Direction = -1},
	Thumbstick1Right = {Axis = "X", Direction = 1},
	Thumbstick1Left = {Axis = "X", Direction = -1},
	
	ManualToggle = {},
}

local SETTINGS = {
	
	UIDPadRepeattime = 0.5, -- Seconds
	UIDPadSpeed = 5, -- Per second
	
	DefaultThumbstickDeadzone = 0.25,
	
	ThumbstickDirectionalThreshold = 0.8,
	Thumbstick1Enums = {"Thumbstick1Up", "Thumbstick1Down", "Thumbstick1Right", "Thumbstick1Left"},
	
	-- TriggerOnly = true : disables continous active state of an action
	-- ModalDisable = true : disables input when modal interface is enabled
	
	BuiltInActions = {
		-- Universal interface:
		Up = {Keyboard = Enum.KeyCode.Up, Gamepad = {Enum.KeyCode.DPadUp, ICEnum.Thumbstick1Up}},
		Down = {Keyboard = Enum.KeyCode.Down, Gamepad = {Enum.KeyCode.DPadDown, ICEnum.Thumbstick1Down}},
		Right = {Keyboard = Enum.KeyCode.Right, Gamepad = {Enum.KeyCode.DPadRight, ICEnum.Thumbstick1Right}},
		Left = {Keyboard = Enum.KeyCode.Left, Gamepad = {Enum.KeyCode.DPadLeft, ICEnum.Thumbstick1Left}},
		
		-- No thumbstick bind directions:
		DPadUp = {Keyboard = Enum.KeyCode.Up, Gamepad = {Enum.KeyCode.DPadUp}},
		DPadDown = {Keyboard = Enum.KeyCode.Down, Gamepad = {Enum.KeyCode.DPadDown}},
		DPadRight = {Keyboard = Enum.KeyCode.Right, Gamepad = {Enum.KeyCode.DPadRight}},
		DPadLeft = {Keyboard = Enum.KeyCode.Left, Gamepad = {Enum.KeyCode.DPadLeft}},
		
		Confirm = {Keyboard = Enum.KeyCode.Return, Gamepad = {Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2}},
		Cancel = {Keyboard = Enum.KeyCode.Backspace, Gamepad = Enum.KeyCode.ButtonB},
		Interact1 = {Keyboard = Enum.KeyCode.Semicolon, Gamepad = Enum.KeyCode.ButtonX},
		Interact2 = {Keyboard = Enum.KeyCode.Quote, Gamepad = Enum.KeyCode.ButtonY},
		
		NextPage = {Keyboard = Enum.KeyCode.RightBracket, Gamepad = Enum.KeyCode.ButtonR1},
		PreviousPage = {Keyboard = Enum.KeyCode.LeftBracket, Gamepad = Enum.KeyCode.ButtonL1},
		
		Menu = {TriggerOnly = true, Keyboard = Enum.KeyCode.M, Gamepad = Enum.KeyCode.ButtonSelect},
	},
	
	DefaultActionSetup = {
		Shooter = {
			-- Gameplay:
			Primary = {ModalDisable = true, Keyboard = Enum.UserInputType.MouseButton1, Gamepad = Enum.KeyCode.ButtonR2},
			Secondary = {ModalDisable = true, Keyboard = Enum.UserInputType.MouseButton2, Gamepad = Enum.KeyCode.ButtonL2},
			Reload = {ModalDisable = true, Keyboard = Enum.KeyCode.R, Gamepad = Enum.KeyCode.ButtonX},
			
			NextTool = {TriggerOnly = true, ModalDisable = true, Keyboard = ICEnum.MouseWheelDown, Gamepad = Enum.KeyCode.ButtonR1},
			PreviousTool = {TriggerOnly = true, ModalDisable = true, Keyboard = ICEnum.MouseWheelUp, Gamepad = Enum.KeyCode.ButtonL1},
			QuickSwap = {ModalDisable = true, Keyboard = Enum.KeyCode.Q, Gamepad = Enum.KeyCode.DPadUp},
			Taunt = {ModalDisable = true, Keyboard = Enum.KeyCode.G, Gamepad = Enum.KeyCode.DPadDown},
			
			PreviewTool = {ModalDisable = true, Keyboard = Enum.KeyCode.F, Gamepad = Enum.KeyCode.DPadRight},
			
			Use = {ModalDisable = true, Keyboard = Enum.KeyCode.E, Gamepad = Enum.KeyCode.ButtonY},
			
			Leaderboard = {ModalDisable = true, Keyboard = Enum.KeyCode.Tab, Gamepad = Enum.KeyCode.ButtonB},
			
			ChangePerspective = {ModalDisable = true, Keyboard = Enum.KeyCode.P, Gamepad = Enum.KeyCode.DPadLeft},
			
			Crouch = {ModalDisable = true, Keyboard = Enum.KeyCode.LeftControl, Gamepad = Enum.KeyCode.ButtonL3},
			Jump = {ModalDisable = true, Keyboard = Enum.KeyCode.Space, Gamepad = Enum.KeyCode.ButtonA},
			Sprint = {ModalDisable = true, Keyboard = Enum.KeyCode.LeftShift, Gamepad = Enum.KeyCode.ButtonR3},
		},
	},
	
	UserInputDeviceReference = {
		[Enum.UserInputType.MouseButton1] = "Keyboard",
		[Enum.UserInputType.MouseButton2] = "Keyboard",
		[Enum.UserInputType.MouseButton3] = "Keyboard",
		[Enum.UserInputType.MouseWheel] = "Keyboard",
		[Enum.UserInputType.MouseMovement] = "Keyboard",
		[Enum.UserInputType.Touch] = "Touch",
		[Enum.UserInputType.Keyboard] = "Keyboard",
		-- [Enum.UserInputType.Focus] = "",
		-- [Enum.UserInputType.Accelerometer] = "",
		-- [Enum.UserInputType.Gyro] = "",
		[Enum.UserInputType.Gamepad1] = "Gamepad",
		[Enum.UserInputType.Gamepad2] = "Gamepad",
		[Enum.UserInputType.Gamepad3] = "Gamepad",
		[Enum.UserInputType.Gamepad4] = "Gamepad",
		[Enum.UserInputType.Gamepad5] = "Gamepad",
		[Enum.UserInputType.Gamepad6] = "Gamepad",
		[Enum.UserInputType.Gamepad7] = "Gamepad",
		[Enum.UserInputType.Gamepad8] = "Gamepad",
		-- [Enum.UserInputType.TextInput] = "",
		-- [Enum.UserInputType.InputMethod] = "",
		-- [Enum.UserInputType.None] = "",
	},

}

----- Controller Table -----

local InputController = {
	
	ICEnum = ICEnum,
	UIDPadSignal = Madwork.NewScriptSignal(),
	
	UserInputDevice = "Keyboard",
	UserInputDeviceChanged = Madwork.NewScriptSignal(),
	
	Analog = {
		Thumbstick1 = Vector2.new(0, 0),
		Thumbstick2 = Vector2.new(0, 0),
		Trigger1 = 0,
		Trigger2 = 0,
	},
	
	IsSetUp = false,
	
}

----- Private Variables -----

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local UIDPadSignal = InputController.UIDPadSignal

local Analog = InputController.Analog
local ThumbstickDeadzone = SETTINGS.DefaultThumbstickDeadzone

local TextBoxFocused = false
local ModalInterfaceActive = false

local Actions = {
	--[[
		[action_name] = {
			ActionName = "",
			ActionParams = {},
			Signal = script_signal,
			TriggerOnly = false,
			ModalDisable = false,
			IsActive = false,
			ActivatedEnums = {},
		}
	--]]
}

-- Action hash:
local ActionHash = {} -- [enum] = {action, ...}

----- Private functions -----

local function GetClampedVector2(vector2)
	local input_magnitude = vector2.Magnitude
	if input_magnitude <= ThumbstickDeadzone then
		return Vector2.new(0, 0)
	else
		return vector2.Unit * math.clamp((input_magnitude - ThumbstickDeadzone) / (1 - ThumbstickDeadzone), 0, 1)
	end
end

local function IsICEnum(check_enum)
	if type(check_enum) == "table" then
		for _, enum in pairs(ICEnum) do
			if check_enum == enum then
				return true
			end
		end
	end
	return false
end

local function IsSupportedEnum(check_enum)
	if typeof(check_enum) == "EnumItem" then
		local enum_type = check_enum.EnumType
		if enum_type == Enum.KeyCode then
			return true
		elseif enum_type == Enum.UserInputType then
			if check_enum == Enum.UserInputType.MouseButton1 or check_enum == Enum.UserInputType.MouseButton2 then
				return true
			end
		end
	elseif IsICEnum(check_enum) then
		return true
	end
	return false
end

local function GetInputEnums(input_object)
	local result = {}
	
	local user_input_type = input_object.UserInputType
	local key_code = input_object.KeyCode
	
	table.insert(result, user_input_type)
	if user_input_type == Enum.UserInputType.Keyboard or user_input_type == Enum.UserInputType.Gamepad1 then
		table.insert(result, key_code)
	end
	return result
end

local function ActivateAction(action, input_enum)
	if action.ModalDisable == true and ModalInterfaceActive == true then return end -- Can't use this bind while a modal interface is active
	if action.TriggerOnly == true then
		action.Signal:Fire(true)
	else
		local previous_is_active = action.IsActive
		action.ActivatedEnums[input_enum] = true
		action.IsActive = true
		if previous_is_active == false then
			action.Signal:Fire(true)
		end
	end
end

local function DisableAction(action, input_enum)
	if action.TriggerOnly == false then
		local previous_is_active = action.IsActive
		action.ActivatedEnums[input_enum] = nil
		local new_is_active = next(action.ActivatedEnums) ~= nil
		action.IsActive = new_is_active
		if previous_is_active == true and new_is_active == false then
			action.Signal:Fire(false)
		end
	end
end

local function AddActionHash(action, input_enum)
	local get_actions = ActionHash[input_enum]
	if get_actions == nil then
		get_actions = {}
		ActionHash[input_enum] = get_actions
	end
	table.insert(get_actions, action)
end

local function SetupAction(action_name, action_params)
	assert(type(action_name) == "string", "[InputController]: Invalid action name \"" .. tostring(action_name) .. "\"")
	
	local action = {
		ActionName = action_name,
		ActionParams = action_params,
		Signal = Madwork.NewScriptSignal(),
		TriggerOnly = action_params.TriggerOnly == true,
		ModalDisable = action_params.ModalDisable == true,
		IsActive = false,
		ActivatedEnums = {},
	}
	Actions[action_name] = action
	
	-- Adding action to hash:
	for param_name, param_value in pairs(action_params) do
		if param_name ~= "TriggerOnly" and param_name ~= "ModalDisable" then
			if type(param_name) == "string" then
				if type(param_value) == "table" and IsICEnum(param_value) ~= true then -- Multiple binds
					for _, input_enum in ipairs(param_value) do
						if IsSupportedEnum(input_enum) == true then
							AddActionHash(action, input_enum)
						else
							error("[InputController]: Enum \"" .. tostring(input_enum) .. "\" not supported (Action \"" .. action_name .. "\")")
						end
					end
				else -- One bind
					if IsSupportedEnum(param_value) == true then
						AddActionHash(action, param_value)
					else
						error("[InputController]: Enum \"" .. tostring(param_value) .. "\" not supported (Action \"" .. action_name .. "\")")
					end
				end
			else
				error("[InputController]: Invalid action \"" .. action_name .. "\" parameter name \"" .. tostring(param_name) .. "\"")
			end
		end
	end
end

local function InitializeUIDPad()
	
	local direction_reference = {
		Up = Vector2.new(0, 1),
		Down = Vector2.new(0, -1),
		Left = Vector2.new(-1, 0),
		Right = Vector2.new(1, 0),
	}
	
	local current_direction = nil
	local current_vector2 = Vector2.new()
	local direction_start = 0
	local last_signal = 0
	
	local function update_direction(direction, is_active)
		if is_active == true then
			current_direction = direction
			current_vector2 = direction_reference[direction]
			direction_start = os.clock()
			last_signal = 0
			UIDPadSignal:Fire(current_vector2)
		elseif current_direction == direction then
			current_direction = nil
		end
	end
	
	for direction in pairs(direction_reference) do
		InputController.GetActionSignal(direction):Connect(function(is_active)
			update_direction(direction, is_active)
		end)
	end
	
	RunService.Heartbeat:Connect(function()
		if current_direction ~= nil then
			local get_time = os.clock()
			if last_signal == 0 then
				if get_time - direction_start >= SETTINGS.UIDPadRepeattime then
					last_signal = get_time
					UIDPadSignal:Fire(current_vector2)
				end
			elseif get_time - last_signal >= SETTINGS.UIDPadSpeed then
				last_signal += SETTINGS.UIDPadSpeed
				UIDPadSignal:Fire(current_vector2)
			end
		end
	end)
	
end

local function SetupActions(action_settings)
	if InputController.IsSetUp == true then
		error("[InputController]: Actions were already set up")
	end
	InputController.IsSetUp = true
	
	for action_name, action_params in pairs(action_settings) do
		if SETTINGS.BuiltInActions[action_name] ~= nil then
			error("[InputController]: Can't override built-in action \"" .. action_name .. "\"")
		end
		SetupAction(action_name, action_params)
	end
end

local function CheckUserInputChange(user_input_type)
	local get_device = SETTINGS.UserInputDeviceReference[user_input_type]
	if get_device ~= nil then
		if get_device ~= InputController.UserInputDevice then
			InputController.ResetActions()
			InputController.UserInputDevice = get_device
			InputController.UserInputDeviceChanged:Fire(get_device)
		end
	end
end

----- Public functions -----

-- Controller functions:

function InputController.SetupDefaultActions(default_type)
	local get_default_type = SETTINGS.DefaultActionSetup[default_type]
	if get_default_type == nil then
		error("[InputController]: Default type \"" .. tostring(default_type) .. "\" was not defined")
	end
	SetupActions(get_default_type)
end

function InputController.SetupCustomActions(action_setup)
	SetupActions(action_setup)
end

function InputController.ToggleModalInterface(is_enabled)
	ModalInterfaceActive = is_enabled
	if is_enabled == true then
		for _, action in pairs(Actions) do
			if action.ModalDisable == true then
				local old_is_active = action.IsActive
				action.IsActive = false
				for input_enum in pairs(action.ActivatedEnums) do
					action.ActivatedEnums[input_enum] = nil
				end
				if action.TriggerOnly == false and old_is_active == true then
					action.Signal:Fire(false)
				end
			end
		end
	end
end

function InputController.IsActionActive(action_name) --> is_active
	local get_action = Actions[action_name]
	if get_action == nil then
		error("[InputController]: Action \"" .. tostring(action_name) .. "\" was not defined")
	end
	return get_action.IsActive
end

function InputController.GetActionSignal(action_name) --> [ScriptSignal](is_active)
	local get_action = Actions[action_name]
	if get_action == nil then
		error("[InputController]: Action \"" .. tostring(action_name) .. "\" was not defined")
	end
	return get_action.Signal
end

function InputController.ToggleAction(action_name, is_active)
	local get_action = Actions[action_name]
	if get_action == nil then
		error("[InputController]: Action \"" .. tostring(action_name) .. "\" was not defined")
	end
	if is_active == true then
		ActivateAction(get_action, ICEnum.ManualToggle)
	else
		DisableAction(get_action, ICEnum.ManualToggle)
	end
end

function InputController.TriggerAction(action_name) -- Only fires listeners connected to the action
	local get_action = Actions[action_name]
	if get_action == nil then
		error("[InputController]: Action \"" .. tostring(action_name) .. "\" was not defined")
	end
	get_action.Signal:Fire(true)
end

function InputController.ResetActions()
	for _, action in pairs(Actions) do
		local old_is_active = action.IsActive
		action.IsActive = false
		for input_enum in pairs(action.ActivatedEnums) do
			action.ActivatedEnums[input_enum] = nil
		end
		if action.TriggerOnly == false and old_is_active == true then
			action.Signal:Fire(false)
		end
	end
end

function InputController.GetActionEnum(action_name, input_type) --> [EnumItem] or [Enum] or [ICEnum] or nil
	local get_action = Actions[action_name]
	if get_action == nil then
		error("[InputController]: Action \"" .. tostring(action_name) .. "\" was not defined")
	end
	local get_input_type = get_action.ActionParams[input_type]
	if type(get_input_type) == "table" then
		return get_input_type[1]
	else
		return get_input_type
	end
end

-- Gamepad:

function InputController.SetThumbstickDeadzone(deadzone) -- Clamping value for thumbstick orientation getters
	ThumbstickDeadzone = math.clamp(deadzone, 0, 0.99)
end

function InputController.GetThumbstick1() --> [Vector2] -- Starts at {0, 0} from deadzone
	return Analog.Thumbstick1
end

function InputController.GetThumbstick2() --> [Vector2] -- Starts at {0, 0} from deadzone
	return Analog.Thumbstick2
end

function InputController.GetTrigger1() --> [number]
	return Analog.Trigger1
end

function InputController.GetTrigger2() --> [number]
	return Analog.Trigger2
end

----- Initialize -----

-- Get initial device type:
if UserInputService.KeyboardEnabled == true then
	InputController.UserInputDevice = "Keyboard"
elseif UserInputService.GamepadEnabled == true then
	InputController.UserInputDevice = "Gamepad"
elseif UserInputService.TouchEnabled == true then
	InputController.UserInputDevice = "Touch"
else
	-- Mind controller:
	InputController.UserInputDevice = "Keyboard"
end

-- Textbox mode listeners:
UserInputService.TextBoxFocused:Connect(function()
	InputController.ResetActions()
	TextBoxFocused = true
end)
UserInputService.TextBoxFocusReleased:Connect(function()
	TextBoxFocused = false
end)

-- Setting up built-in actions:
for action_name, action_params in pairs(SETTINGS.BuiltInActions) do
	SetupAction(action_name, action_params)
end

InitializeUIDPad()

----- Connections -----

--[[
	https://developer.roblox.com/en-us/api-reference/class/InputObject
	input_object [InputObject]:
		{
			Delta            [Vector3]
			KeyCode          [Enum.KeyCode]
			Position         [Vector3]
			UserInputState   [Enum.UserInputState]
			UserInputType    [Enum.UserInputType]
		}
--]]

UserInputService.InputBegan:Connect(function(input_object, is_game_processed)
	CheckUserInputChange(input_object.UserInputType)
	if TextBoxFocused == true then return end
	local input_enums = GetInputEnums(input_object)
	for _, input_enum in ipairs(input_enums) do
		local get_actions = ActionHash[input_enum]
		if get_actions ~= nil then
			for _, action in ipairs(get_actions) do
				ActivateAction(action, input_enum)
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input_object, is_game_processed)
	local input_enums = GetInputEnums(input_object)
	for _, input_enum in ipairs(input_enums) do
		local get_actions = ActionHash[input_enum]
		if get_actions ~= nil then
			for _, action in ipairs(get_actions) do
				DisableAction(action, input_enum)
			end
		end
	end
	-- Trigger analog:
	local key_code = input_object.KeyCode
	if key_code == Enum.KeyCode.ButtonR1 then
		-- Left trigger analog 0
		Analog.Trigger1 = 0
	elseif key_code == Enum.KeyCode.ButtonR2 then
		-- Right trigger analog 0
		Analog.Trigger2 = 0
	end
end)

UserInputService.InputChanged:Connect(function(input_object, is_game_processed)
	CheckUserInputChange(input_object.UserInputType)
	local user_input_type = input_object.UserInputType
	local key_code = input_object.KeyCode
	local position = input_object.Position
	
	if user_input_type == Enum.UserInputType.Gamepad1 then
		if key_code == Enum.KeyCode.Thumbstick1 then
			-- Thumbstick1 directional controls:
			for _, enum_name in ipairs(SETTINGS.Thumbstick1Enums) do
				local icenum = ICEnum[enum_name]
				local axis_value = position[icenum.Axis]
				local is_active = math.abs(axis_value) > SETTINGS.ThumbstickDirectionalThreshold and math.sign(axis_value) == math.sign(icenum.Direction)
				
				local get_actions = ActionHash[icenum]
				if get_actions ~= nil then
					for _, action in ipairs(get_actions) do
						if is_active == true then
							ActivateAction(action, icenum)
						else
							DisableAction(action, icenum)
						end
					end
				end
			end
			-- Thumbstick1 analog:
			Analog.Thumbstick1 = GetClampedVector2(Vector2.new(position.X, position.Y))
		elseif key_code == Enum.KeyCode.Thumbstick2 then
			-- Thumbstick2 analog:
			Analog.Thumbstick2 = GetClampedVector2(Vector2.new(position.X, position.Y))
		elseif key_code == Enum.KeyCode.ButtonR1 then
			-- Left trigger analog
			Analog.Trigger1 = position.Z
		elseif key_code == Enum.KeyCode.ButtonR2 then
			-- Right trigger analog
			Analog.Trigger2 = position.Z
		end
	elseif user_input_type == Enum.UserInputType.MouseWheel then
		if position[ICEnum.MouseWheelUp.Axis] == ICEnum.MouseWheelUp.Direction then
			local get_actions = ActionHash[ICEnum.MouseWheelUp]
			if get_actions ~= nil then
				for _, action in ipairs(get_actions) do
					ActivateAction(action, ICEnum.MouseWheelUp)
				end
			end
		elseif position[ICEnum.MouseWheelDown.Axis] == ICEnum.MouseWheelDown.Direction then
			local get_actions = ActionHash[ICEnum.MouseWheelDown]
			if get_actions ~= nil then
				for _, action in ipairs(get_actions) do
					ActivateAction(action, ICEnum.MouseWheelDown)
				end
			end
		end
	end

end)

-- UserInputService.LastInputTypeChanged:Connect(CheckUserInputChange) -- Does not work in Studio

return InputController

--[[
local UserInputService = game:GetService("UserInputService")

local function onInputBegan(input, gameProcessed)
	print(input.UserInputType, input.KeyCode, input.Position)
end

UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputBegan)
UserInputService.InputChanged:Connect(onInputBegan)
--]]