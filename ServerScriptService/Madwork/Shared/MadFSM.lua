local Madwork = _G.Madwork
--[[
{Madwork}

-[MadFSM]---------------------------------------
	Finite State Machine implementation with state duration; Used to define tool behaviour, animation sequences, etc.
	
	-- MadFSM events: (Listed in life cycle order)
	[- EventName -> (event_handler_params...)]
		- Entering   (state_name_new, state_name_old)
		- Start      (state_name)
		- Leaving    (state_name_new, state_name_old)
		- Cancel     (state_name)
		- Complete   (state_name)
		(Cancel and Complete are mutually exclusive during a state life cycle)
		
	Functions:
	
		MadFSM.NewMadFSM(states) --> [MadFSM] -- Define first to reference by state handlers defined by MadFSM:DefineStates()
			
	Members [MadFSM]:
	
		MadFSM.State            [string] or nil
		
		MadFSM.Duration         [number] -- >= 0 -- 0 duration means undefined state duration;
			-- States with no duration won't trigger the Complete event.
		MadFSM.StartTime        [number]
		MadFSM.Progress         [number] -- 0 to 1 -- Progress is updated every MadFSM:Update()
		
	Methods [MadFSM]:

		MadFSM:DefineStates(states)
			states   [table]: {
				StateName = {
					Duration = 0,
					-- Event handlers:
					-- All handlers are optional (Available events listed above):
					EventName = function(...), --> [bool] confirm_change -- confirming is "Entering" and "Leaving" only;
						-- Return false to cancel state change (nil will not cancel state change);
					...
					-- WARNING: Cancel handler is not allowed to call state changing methods
				},
			}
			-- NOTICE: MadFSM:Set() the default state as soon as the states are defined
	
		MadFSM:Set(state_name) --> [bool] set_success -- Will return true if state set was not overriden;
			-- Will not trigger event handlers when setting MadFSM state for the first time
		
		MadFSM:RepeatSet(state_name, cycle_time) -- IMPORTANT: Call before MadFSM:Update() during a game step;
			cycle_time   [number] -- (seconds) Time that has to pass between repeating sets
			-- Attempts to MadFSM:Set(state_name) while it successfully sets;
			-- Moves MadFSM.StartTime by MadFSM.Duration increments when repeatedly setting the same
			--	state - useful for maintaining framerate-independent rapid events like tool firing;
			
		MadFSM:ForceSet(state_name) -- Ignores Entering and Leaving handlers
		
		MadFSM:Update() -- Progresses states when they finish; Updates MadFSM.Progress
		
		MadFSM:IsStateDefined(state_name) --> [bool]
		
		MadFSM:OnStart(listener) --> [ScriptSonnection]
		MadFSM:OnCancel(listener) --> [ScriptSonnection]
		MadFSM:OnComplete(listener) --> [ScriptSonnection]
			listener     [function] (state_name)
			
		-- WARNING: MadFSM:On() listener will throw and error if state setting methods are called inside;
		--	MadFSM:On() should only be used for controlling features dependent on MadFSM state
		
		MadFSM:SetTimeSource(time_source)
			time_source   [function]() --> time [number] -- Use for time manipulation
	
		
--]]

local SETTINGS = {
	EventNames = {Entering = true, Start = true, Leaving = true, Cancel = true, Complete = true},
	ExternalListenerEvents = {Start = true, Cancel = true, Complete = true},
}

----- Module Table -----

local MadFSM = {

}

----- Private variables -----

local SetStack = {} -- {is_set_success, ...}

local EventHandlerStack = 0
local ExternalListenerFlag = false
local CancelFlag = false

----- Private functions -----

local function DefaultTimeSource()
	return os.clock()
end

----- Public functions -----

-- MadFSM object:
local MadFSMObject = {
	--[[
		_states = {}, -- {StateName = params, ...}
		_complete_time = clock or nil,
		_events = {}, -- {EventName = script_signal, ...}
		_time_source = func,
	--]]
}
MadFSMObject.__index = MadFSMObject

--[[
	-- MadFSM events: (Listed in life cycle order)
		- Entering   (state_name_new, state_name_old)
		- Start      (state_name)
		- Leaving    (state_name_new, state_name_old)
		- Cancel     (state_name)
		- Complete   (state_name)
		(Cancel and Complete are mutually exclusive)
--]]

function MadFSMObject:DefineStates(states)
	if self._states ~= nil then
		error("[MadFSM]: States were already defined")
	end
	self._states = states
	-- Type checking states:
	for state_name, state_params in pairs(states) do
		if type(state_name) ~= "string" or type(state_params) ~= "table" then
			error("[MadFSM]: Invalid state \"" .. tostring(state_name) .. "\"")
		end
		for param, value in pairs(state_params) do
			if param ~= "Duration" and SETTINGS.EventNames[param] == nil then
				error("[MadFSM]: Unknown param \"" .. tostring(param) .. "\" in state \"" .. tostring(state_name) .. "\"")
			elseif param ~= "Duration" and type(value) ~= "function" then
				error("[MadFSM]: Expected function as value for param \"" .. tostring(param) .. "\" in state \"" .. tostring(state_name) .. "\"")
			end
		end
		if type(state_params.Duration) == nil then
			error("[MadFSM]: Duration must be defined for state \"" .. tostring(state_name) .. "\"")
		elseif state_params.Duration < 0 then
			error("[MadFSM]: Duration can't be negative for state \"" .. tostring(state_name) .. "\"")
		end
	end
end

function MadFSMObject:Set(state_name, _start_time, _force_set) --> [bool] set_success
	if self._states == nil then
		error("[MadFSM]: Can't set MadFSM state when states weren't defined")
	end
	-- External listener handling:
	if ExternalListenerFlag == true then
		error("[MadFSM]: MadFSM:On() listeners are not allowed to change MadFSM state")
		-- You should define state change rules in the state params themselves
	end
	-- Cancel flag handling:
	if CancelFlag == true then
		error("[MadFSM]: \"Cancel\" event handlers are not allowed to change MadFSM state")
	end
	-- Default state set:
	if self.State == nil then
		local clock = self._time_source()
		local new_state = self:_GetState(state_name)

		self.State = state_name
		self.Duration = new_state.Duration
		self.StartTime = _start_time or clock
		self.Progress = 0

		return true
	end
	if #SetStack == 0 and EventHandlerStack == 0 then
		-- Progress MadFSM state for external state setting:
		self:Update()
	end
	table.insert(SetStack, true)
	local stack_id = #SetStack

	local old_state_name = self.State
	local new_state_name = state_name

	local old_state = self:_GetState(old_state_name)
	local new_state = self:_GetState(new_state_name)

	local confirm_change = _force_set == true or self:_ChangeConfirm(old_state_name, new_state_name)

	-- Apply state change if event handlers passed and this :Set() was not overriden by another set:
	if confirm_change == true and SetStack[stack_id] == true then
		-- Flag the rest of the stack as overriden
		for i = 1, stack_id - 1 do
			SetStack[i] = false
		end

		local clock = self._time_source()

		self.State = new_state_name
		self.Duration = new_state.Duration
		self.StartTime = self._complete_time or _start_time or clock
		if self.Duration == 0 then
			self.Progress = 0
		else
			self.Progress = math.clamp((clock - self.StartTime) / self.Duration, 0, 1)
		end

		if self._complete_time ~= nil then
			-- Complete event was already fired:
			self._complete_time = nil
		else
			-- Cancel event:
			ExternalListenerFlag = true
			self._events.Cancel:Fire(old_state_name)
			ExternalListenerFlag = false
			if old_state.Cancel ~= nil then
				CancelFlag = true
				old_state.Cancel(old_state_name)
				CancelFlag = false
			end
		end

		-- Start event:
		ExternalListenerFlag = true
		self._events.Start:Fire(new_state_name)
		ExternalListenerFlag = false
		if new_state.Start ~= nil then
			EventHandlerStack += 1
			new_state.Start(new_state_name)
			EventHandlerStack -= 1
		end
	end

	local set_success = SetStack[stack_id]
	table.remove(SetStack, stack_id)
	return set_success
end

function MadFSMObject:RepeatSet(state_name, cycle_time)
	local iterations = 0
	while true do
		iterations += 1
		local start_time
		if self.State == state_name then
			start_time = self.StartTime + cycle_time
		end
		local set_success = self:Set(state_name, start_time)
		if set_success == false then
			return
		elseif iterations == 100 then
			warn("[MadFSM]: Detected potential invalid use of \"MadFSM:RepeatSet()\" - State: \"" .. state_name .."\"; Traceback:\n" .. debug.traceback())
			return
		end
	end
end

function MadFSMObject:ForceSet(state_name)
	self:Set(state_name, nil, true)
end

function MadFSMObject:Update()
	if self._states == nil then
		error("[MadFSM]: Can't update MadFSM when states weren't defined")
	end
	local clock = self._time_source()
	if self.Duration > 0 then
		self.Progress = math.clamp((clock - self.StartTime) / self.Duration, 0, 1)
		if self.Progress >= 1 then
			ExternalListenerFlag = true
			self._events.Complete:Fire(self.State)
			ExternalListenerFlag = false
			self._complete_time = self.StartTime + self.Duration
			EventHandlerStack += 1

			table.insert(SetStack, true)
			local stack_id = #SetStack

			local old_state = self:_GetState(self.State)

			if old_state.Complete ~= nil then
				old_state.Complete(self.State)
			end

			local was_not_set = SetStack[stack_id]
			table.remove(SetStack, stack_id)

			if was_not_set == true then
				-- Force repeat state if it didn't have a Complete event handler or the handler didn't set a new state
				self:ForceSet(self.State)
			end

			EventHandlerStack -= 1
		end
	end
end

function MadFSMObject:IsStateDefined(state_name)
	return self._states ~= nil and self._states[state_name] ~= nil
end

function MadFSMObject:OnStart(listener)
	return self._events.Start:Connect(listener)
end

function MadFSMObject:OnCancel(listener)
	return self._events.Cancel:Connect(listener)
end

function MadFSMObject:OnComplete(listener)
	return self._events.Complete:Connect(listener)
end

function MadFSMObject:SetTimeSource(time_source)
	MadFSMObject._time_source = time_source
end

function MadFSMObject:_GetState(state_name)
	local state = self._states[state_name]
	if state == nil then
		error("[MadFSM]: State \"" .. tostring(state_name) .. "\" was not defined")
	end
	return state
end

function MadFSMObject:_ChangeConfirm(old_state_name, new_state_name) --> [bool] confirm_change -- Triggers event handlers to confirm state change
	local old_state = self:_GetState(old_state_name)
	local new_state = self:_GetState(new_state_name)
	EventHandlerStack += 1
	if old_state.Leaving ~= nil and old_state.Leaving(old_state_name, new_state_name) == false then
		EventHandlerStack -= 1
		return false
	end
	if new_state.Entering ~= nil and new_state.Entering(old_state_name, new_state_name) == false then
		EventHandlerStack -= 1
		return false
	end
	EventHandlerStack -= 1
	return true
end

-- Module functions:

function MadFSM.NewMadFSM() --> [MadFSM]

	local mad_fsm = {
		State = nil,
		Duration = 0,
		StartTime = 0,
		Progress = 0,

		_states = nil,
		_complete_time = nil,
		_events = {},
		_time_source = DefaultTimeSource,
	}
	setmetatable(mad_fsm, MadFSMObject)

	-- Setting up event signals:
	for event_name in pairs(SETTINGS.ExternalListenerEvents) do
		mad_fsm._events[event_name] = Madwork.NewScriptSignal()
	end

	return mad_fsm
end

return MadFSM