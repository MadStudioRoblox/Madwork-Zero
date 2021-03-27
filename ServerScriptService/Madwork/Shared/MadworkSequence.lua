local Madwork = _G.Madwork
--[[
{Madwork}

-[MadworkSequence]---------------------------------------

	Functions:
	
		MadworkSequence.NewSequenceTemplate() --> [SequenceTemplate]
			
	Methods [SequenceTemplate]:
	
		SequenceTemplate:Next(duration, executor) --> [SequenceTemplate]
			duration       [number] -- (seconds)
			executor       [function] (step) or nil -- nil will create a passive step
				-- NOTICE: Executor function cannot yield - use "Step:OnUpdate()" for repeating updates
				
		SequenceTemplate:SkipPoint(skip_point_name) --> [SequenceTemplate] -- Creates a skip point between sequence steps
			skip_point_name   [string]
		
		SequenceTemplate:UseRenderStepped() --> [SequenceTemplate] -- Switches from Heartbeat to RenderStepped for driving Step:OnUpdate()

		SequenceTemplate:Start(props) --> [Sequence]
			props   [table] or nil -- Passed to Step.Props; Defaults to an empty table
				
	Members [Step]:
	
		Step.Props        [table] -- Properties passed through SequenceTemplate:Start(props)
		Step.Duration     [number] -- Step duration in seconds
		Step.Progress     [number] -- Value between 0 and 1 indicating current step progress
		
		Step.Sequence     [Sequence] -- Reference to the sequence running this step
		
	Methods [Step]:
	
		Step:OnUpdate(func) --> [Step]
			func   [function] (progress) -- Will be eagerly called right after the executor function finishes
				progress   [number] -- Value between 0 and 1 indicating current step progress
		Step:OnFinish(func) --> [Step]
		Step:OnSkip(func) --> [Step]
			func   [function] ()
		
		Step:Skip() -- Moves to the next step or finishes the sequence
		
	Members [Sequence]:
	
		Sequence.Progress   [number] -- Value between 0 and 1 indicating total progress of the sequence
		Sequence.Duration   [number] -- (seconds)
	
	Methods [Sequence]:
	
		Sequence:OnFinish(func) --> [Sequence] -- Called when the sequence reaches the end without being cancelled
		Sequence:OnCancel(func) --> [Sequence] -- Called when the sequence is cancelled
		Sequence:OnEnd(func) --> [Sequence] -- Called when the sequence ends by finishing or cancelling
			func   [function] (props)
		
		Sequence:SkipTo(skip_point_name)
		Sequence:Cancel()
		Sequence:Destroy() -- Same as Sequence:Cancel()
	
--]]

local SETTINGS = {

}

----- Module Table -----

local MadworkSequence = {

}

----- Private Variables -----

local RunService = game:GetService("RunService")

local Step

----- Private functions -----

local function FinishSequence(sequence, is_skipped)
	if sequence._is_end == true then
		return
	end

	-- Finishing sequence:
	sequence.Progress = 1
	sequence._is_end = true
	sequence._is_finished = true
	sequence._update_connection:Disconnect()

	-- Handling last running step:
	if is_skipped == true then
		local step = sequence._current_step
		for _, listener in ipairs(step._skip_listeners) do
			listener()
		end
		step._is_skipped = true
	end

	-- Firing sequence listeners:
	for _, listener in ipairs(sequence._finish_listeners) do
		listener(sequence._props)
	end
	for _, listener in ipairs(sequence._end_listeners) do
		listener(sequence._props)
	end
end

local function StartStep(sequence, step_index, is_skipped)
	if sequence._is_end == true or sequence._current_step_index == step_index then
		return
	end

	local steps = sequence._sequence_template._steps

	-- Finishing sequence if step_index exceeds step count:
	if step_index > #steps then
		FinishSequence(sequence, true)
		return
	end

	-- Creating step object:
	local step_params = steps[step_index] -- {start_time, duration, executor}

	local step = {
		Props = sequence._props,
		Duration = step_params[2],
		Progress = 0,

		Sequence = sequence,

		_update_listeners = {}, -- {func, ...}
		_finish_listeners = {}, -- {func, ...}
		_skip_listeners = {}, -- {func, ...}

		_is_skipped = false,
	}
	setmetatable(step, Step)

	-- Getting correct step start time:
	local os_clock = os.clock()
	if is_skipped == true then
		sequence._current_step_start = os.clock()

		local old_step = sequence._current_step
		if old_step ~= nil then
			for _, listener in ipairs(old_step._skip_listeners) do
				listener()
			end
			old_step._is_skipped = true
		end
	else
		local old_step = sequence._current_step
		sequence._current_step_start += old_step.Duration
	end

	sequence._current_step = step
	sequence._current_step_index = step_index

	if step_params[3] ~= nil then
		step_params[3](step)
	end

	if sequence._current_step == step then -- Don't update these values if the step skipped itself
		local step_delta_time = os_clock - sequence._current_step_start
		local step_progress = step.Duration > 0 and math.clamp(step_delta_time / step.Duration, 0, 1) or 1
		sequence.Progress = sequence.Duration > 0 and math.clamp((step_params[1] + step_delta_time) / sequence.Duration, 0, 1) or 1
		step.Progress = step_progress

		for _, listener in ipairs(step._update_listeners) do
			listener(step_progress)
		end
	end
end

local function UpdateSequence(sequence, is_first_update)
	if sequence._is_end == true then
		return
	end

	local steps = sequence._sequence_template._steps

	local os_clock = os.clock()

	while true do

		local step = sequence._current_step
		local step_params = steps[sequence._current_step_index] -- {start_time, duration, executor}

		local step_delta_time = os_clock - sequence._current_step_start
		local step_progress = step.Duration > 0 and math.clamp(step_delta_time / step.Duration, 0, 1) or 1
		sequence.Progress = sequence.Duration > 0 and math.clamp((step_params[1] + step_delta_time) / sequence.Duration, 0, 1) or 1
		step.Progress = step_progress

		if step_progress < 1 then
			if is_first_update ~= true then
				for _, listener in ipairs(step._update_listeners) do
					listener(step_progress)
				end
			end
			break
		else
			for _, listener in ipairs(step._finish_listeners) do
				listener()
			end
			if sequence._current_step_index == #steps then
				FinishSequence(sequence)
				return
			else
				StartStep(sequence, sequence._current_step_index + 1)
				is_first_update = true
			end
		end

	end

end

----- Public functions -----

-- Step object:
Step = {
	--[[
		_update_listeners = {}, -- {func, ...}
		_finish_listeners = {}, -- {func, ...}
		_skip_listeners = {}, -- {func, ...}
	--]]
}
Step.__index = Step

function Step:OnUpdate(func) --> [Step]
	table.insert(self._update_listeners, func)
end

function Step:OnFinish(func) --> [Step]
	table.insert(self._finish_listeners, func)
end

function Step:OnSkip(func) --> [Step]
	if self._is_skipped == true then
		func()
	else
		table.insert(self._skip_listeners, func)
	end
end

function Step:Skip()
	if self.Sequence._current_step == self then
		self.Sequence:_SkipToStep(self.Sequence._current_step_index + 1)
	end
end

-- Sequence object:
local Sequence = {
	--[[
		Progress = 0,
		Duration = self._total_time,
		
		_props = props,
		_sequence_template = self,
		
		_current_step_start = os.clock(),
		_current_step = nil,
		_current_step_index = 0,
		
		_finish_listeners = {}, -- {func, ...}
		_cancel_listeners = {}, -- {func, ...}
		_end_listeners = {}, -- {func, ...}
		
		_is_end = false,
		_is_finished = false,
		_update_connection = nil,
	--]]
}
Sequence.__index = Sequence

function Sequence:OnFinish(func) --> [Sequence] -- Called when the sequence reaches the end without being cancelled
	if self._is_end == true then
		if self._is_finished == true then
			func(self._props)
		end
	else
		table.insert(self._finish_listeners, func)
	end
	return self
end

function Sequence:OnCancel(func) --> [Sequence] -- Called when the sequence is cancelled
	if self._is_end == true then
		if self._is_finished == false then
			func(self._props)
		end
	else
		table.insert(self._cancel_listeners, func)
	end
	return self
end

function Sequence:OnEnd(func) --> [Sequence] -- Called when the sequence ends by finishing or cancelling
	if self._is_end == true then
		func(self._props)
	else
		table.insert(self._end_listeners, func)
	end
	return self
end

function Sequence:_SkipToStep(step_index)
	StartStep(self, step_index, true)
end

function Sequence:SkipTo(skip_point_name)
	local step_index = self._sequence_template._skip_points[skip_point_name]
	if step_index ~= nil then
		self:_SkipToStep(step_index)
	else
		warn("[MadworkSequence]: Skip point \"" .. tostring(skip_point_name) .. "\" was not defined; Traceback:\n" .. debug.traceback())
	end
end

function Sequence:Cancel()
	if self._is_end == true then
		return
	end

	-- Finishing sequence:
	self.Progress = 1
	self._is_end = true
	self._is_finished = false
	self._update_connection:Disconnect()

	-- Handling last running step:
	local step = self._current_step
	for _, listener in ipairs(step._skip_listeners) do
		listener()
	end
	step._is_skipped = true

	-- Firing sequence listeners:
	for _, listener in ipairs(self._cancel_listeners) do
		listener(self._props)
	end
	for _, listener in ipairs(self._end_listeners) do
		listener(self._props)
	end
end

Sequence.Destroy = Sequence.Cancel

-- SequenceTemplate object:
local SequenceTemplate = {
	--[[
		_steps = {}, -- [step_index] = {start_time, duration, executor}
		_skip_points = {}, -- [skip_point_name] = step_index
		_update_step = RunService.Heartbeat,
		_total_time = 0,
	--]]
}
SequenceTemplate.__index = SequenceTemplate

function SequenceTemplate:Next(duration, executor) --> [SequenceTemplate]
	table.insert(self._steps, {self._total_time, duration, executor})
	self._total_time += duration
	return self
end

function SequenceTemplate:SkipPoint(skip_point_name) --> [SequenceTemplate] -- Creates a skip point between sequence steps
	self._skip_points[skip_point_name] = #self._steps + 1
	return self
end

function SequenceTemplate:UseRenderStepped() --> [SequenceTemplate] -- Switches from Heartbeat to RenderStepped for driving Step:OnUpdate()
	self._update_step = RunService.RenderStepped
	return self
end

function SequenceTemplate:Start(props) --> [Sequence]

	local sequence = {
		Progress = 0,
		Duration = self._total_time,

		_props = props,
		_sequence_template = self,

		_current_step_start = os.clock(),
		_current_step = nil,
		_current_step_index = 0,

		_finish_listeners = {}, -- {func, ...}
		_cancel_listeners = {}, -- {func, ...}
		_end_listeners = {}, -- {func, ...}

		_is_end = false,
		_is_finished = false,
		_update_connection = nil,
	}
	setmetatable(sequence, Sequence)

	-- Update connection:
	sequence._update_connection = self._update_step:Connect(function()
		UpdateSequence(sequence)
	end)

	-- Starting first step:
	local steps = self._steps
	if #steps > 0 then
		StartStep(sequence, 1, true)
		UpdateSequence(sequence, true)
	else
		-- Sequence template was empty:
		FinishSequence(sequence)
	end

	return sequence
end

-- Module functions:

function MadworkSequence.NewSequenceTemplate() --> [SequenceTemplate]
	local sequence_template = {
		_steps = {}, -- [step_index] = {start_time, duration, executor}
		_skip_points = {}, -- [skip_point_name] = step_index
		_update_step = RunService.Heartbeat,
		_total_time = 0,
	}
	setmetatable(sequence_template, SequenceTemplate)

	return sequence_template
end

return MadworkSequence