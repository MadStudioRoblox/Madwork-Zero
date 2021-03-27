local Madwork = _G.Madwork
--[[
{Madwork}

-[GlobalState]---------------------------------------
	Globally accessed state management
	
	Functions:
	
		GlobalState.SetupStates(state_settings) -- Can only be called once
			state_settings   [table]:
				{
					StateName = {
						Default = value,
						-- Optional params:
						Values = {value, ...}, -- Restricts state to only these values
					},
					...
				}
				
		GlobalState.GetState(state_name) --> [GlobalState]
		
	Members [GlobalState]:
	
		GlobalState.Value     [any] -- read-only
		GlobalState.Changed   [ScriptSignal] (value)
		
	Methods [GlobalState]:
	
		GlobalState:SetValue(value)
		
--]]

local SETTINGS = {
	
}

----- Module Table -----

local GlobalState = {
	_global_states = {},
}

----- Private Variables -----

local GlobalStates = GlobalState._global_states

----- Private functions -----

local GlobalStateObject = {
	--[[
		Value = value,
		Changed = script_signal,
		
		_state_name = "",
		_values = {} or nil,
	--]]
}
GlobalStateObject.__index = GlobalStateObject

function GlobalStateObject:SetValue(value)
	if self._values ~= nil then
		if table.find(self._values, value) == nil then
			error("[GlobalState]: Tried to set invalid value \"" .. tostring(value) .. "\" for state \"" .. self._state_name .. "\"")
		end
	end
	local old_value = self.Value
	if value ~= old_value then
		self.Value = value
		self.Changed:Fire(value)
	end
end

----- Public functions -----

function GlobalState.SetupStates(state_settings)
	for state_name, state_params in pairs(state_settings) do
		assert(type(state_name) == "string", "[GlobalState]: Invalid state name")
		if state_params.Values ~= nil then
			if table.find(state_params.Values, state_params.Default) == nil then
				error("[GlobalState]: Default value \"" .. tostring(state_params.Default) .. "\" does not exist in possible values of state \"" .. state_name .. "\"")
			end
		end
		local global_state = {
			Value = state_params.Default,
			Changed = Madwork.NewScriptSignal(),
			
			_state_name = state_name,
			_values = state_params.Values,
		}
		setmetatable(global_state, GlobalStateObject)
		GlobalStates[state_name] = global_state
	end
end

function GlobalState.GetState(state_name) --> [GlobalState]
	local get_state = GlobalStates[state_name]
	if get_state == nil then
		error("[GlobalState]: State \"" .. tostring(state_name) .. "\" was not defined")
	end
	return get_state
end

return GlobalState