local Madwork = _G.Madwork
--[[
{Madwork}

-[SignalThrottle]---------------------------------------
	Usually used to throttle client controlled modes - slow rates are processed instantly while
		excessive rates will be denied and only the latest value will be processed
		
	Notice: SignalThrottle will be more efficient when throttle_rate is set to 0
	
	Functions:
	
		SignalThrottle.NewSignalThrottle(throttle_rate, signal_listener) --> [SignalThrottle]
			throttle_rate   [number] -- Signals will be resumed next Heartbeat when set to 0
		
	Methods [SignalThrottle]:
	
		SignalThrottle:Fire(...) -- signal_listener(...)
		SignalThrottle:Destroy() -- Throttled signals will be dismissed
		
--]]

local SETTINGS = {
	
}

----- Module Table -----

local SignalThrottle = {
	_next_heartbeat_throttle = {}, -- [signal_throttle] = true
	_timed_throttle = {}, -- {signal_throttle, ...} -- Objects are sorted by the _throttled value
}

----- Private Variables -----

local RunService = game:GetService("RunService")

local NextHeartbeatThrottle = SignalThrottle._next_heartbeat_throttle
local TimedThrottle = SignalThrottle._timed_throttle

----- Public functions -----

-- SignalThrottle object:
local SignalThrottleObject = {
	--[[
		_throttle_rate = 0,
		_signal_listener = signal_listener,
		_throttled = nil or 0 or future_os_clock, -- Throttle in progress
		_pending_value = nil,
	--]]
}
SignalThrottleObject.__index = SignalThrottleObject

function SignalThrottleObject:Fire(...) -- signal_listener(...)
	if self._throttled == nil then
		self.signal_listener(...)
		if self._throttle_rate == 0 then
			self._throttled = 0
			NextHeartbeatThrottle[self] = true
		else
			local process_time = os.clock() + self._throttle_rate
			self._throttled = process_time
			local insert_index = 1
			for i = 1, #TimedThrottle do
				if TimedThrottle[i]._throttled < process_time then
					insert_index += 1
				else
					break
				end
			end
			table.insert(TimedThrottle, insert_index)
		end
	else
		self._pending_value = {...}
	end
end

function SignalThrottleObject:Destroy()
	local process_time = self._throttled
	if process_time ~= nil then
		if self._throttle_rate == 0 then
			NextHeartbeatThrottle[self] = nil
		else
			table.remove(TimedThrottle, table.find(TimedThrottle, self))
		end
	end
	setmetatable(self, { -- Throw errors for any further method calls:
		_index = function()
			error("[SignalThrottle]: Can't call SignalThrottle methods after the object has been destroyed")
		end,
	})
end

-- Module functions:

function SignalThrottle.NewSignalThrottle(throttle_rate, signal_listener) --> [SignalThrottle]
	assert(throttle_rate >= 0, "[SignalThrottle]: Invalid throttle_rate parameter")
	assert(type(signal_listener) == "function", "[SignalThrottle]: Invalid signal_listener parameter")
	local signal_throttle = {
		_throttle_rate = throttle_rate,
		_signal_listener = signal_listener,
		_throttled = nil,
		_pending_value = nil,
	}
	setmetatable(signal_throttle, SignalThrottleObject)
	return signal_throttle
end

----- Connections -----

RunService.Heartbeat:Connect(function()
	-- Next Heartbeat throttle:
	for signal_throttle in pairs(NextHeartbeatThrottle) do
		signal_throttle._throttled = nil
		NextHeartbeatThrottle[signal_throttle] = nil
		local pending_value = signal_throttle._pending_value
		if pending_value ~= nil then
			signal_throttle._pending_value = nil
			signal_throttle._signal_listener(table.unpack(pending_value))
		end
	end
	-- Timed throttle:
	local get_os_clock = os.clock()
	local signal_throttle = TimedThrottle[1]
	while signal_throttle ~= nil do
		if signal_throttle._throttled <= get_os_clock then
			signal_throttle._throttled = nil
			table.remove(TimedThrottle, 1)
			local pending_value = signal_throttle._pending_value
			if pending_value ~= nil then
				signal_throttle._pending_value = nil
				signal_throttle._signal_listener(table.unpack(pending_value))
			end
			signal_throttle = TimedThrottle[1]
		else
			break
		end
	end
end)

return SignalThrottle