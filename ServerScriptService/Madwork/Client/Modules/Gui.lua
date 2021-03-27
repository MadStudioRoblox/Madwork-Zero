local Madwork = _G.Madwork
--[[
{Madwork}

-[Gui]---------------------------------------
	Library for Gui macro state management using prefabs;
	Notice: This library assumes that prefabs are fully replicated to the client -
		WaitForChild() is not used.
		
	Members:
	
		Gui.LocalPlayer   [Player] -- Quick reference
		Gui.PlayerGui     [PlayerGui] -- Quick reference
	
	Functions:
	
		Gui.Get(instance, name_array) --> [Instance] -- Throws an error if not found
		Gui.Check(instance, name_array) --> [Instance] or nil
			instance     [Instance] -- Instance to find children in
			name_array   [table] -- {"name", ...} -- Chain of children to find
			
		Gui.AutoScale(auto_scale_params) --> [function] () -- Returns a function that stops auto scaling when called
			-- Looks for GuiBase2d instances named specifically "AutoCenter", "AutoTop", "AutoBottom",
				"AutoLeft", "AutoRight", "AutoTopLeft", "AutoTopRight", "AutoBottomLeft" or "AutoBottomRight"
				inside the defined container and automatically scales these instances with UIScale to desired
				size and aligns them in the boundaries of the container (parent) GuiBase2d accordingly.
			auto_scale_params   [table]:
				{
					
					Container = frame, -- [GuiBase2d]
					-- Optional:
					MaximumSize = vector2, -- (pixels) -- If not defined scales targets to maximum size in container boundaries
					PowerRelationshipPastMaximum = 1, -- [0 < x < 1] Continues to scale targets past MaximumSize in an exponential relationship
				}
				
		Gui.GetInset() --> [number] -- Returns pixel height of the topbar (positive value in pixels)
	
		Gui.NewScreen(screen_params) --> [Screen]	
			screen_params   [table]:
				{
					Name = "", -- Primary screen identifier
					
					-- Optional:
					ScreenContainer = GuiBase2d,
					PromptContainer = GuiBase2d,
					Children = {
						screen, -- A screen can only be parented to another screen once;
							-- A screen cannot be active when parenting to another screen!
						...
					},
					IsPrompt = false,
					DefaultProps = {}, -- Must be a dictionary
				}
		
	Members [Screen]:
	
		Screen.Name                  [string]
		Screen.ScreenContainer       [GuiBase2d] or nil
		Screen.PromptContainer       [GuiBase2d] or nil
		
		Screen.IsPrompt              [bool]
		Screen.Children              [table] -- {[screen_name] = screen}
		Screen.Parent                [Screen] or nil
		
		Screen.IsActive              [bool]
		
		Screen.ActiveScreen          [Screen] or nil -- Active Screen that is a child of this screen
		Screen.ActivePrompt          [Screen] or nil -- Active prompt type Screen that is a child of this screen
		
		Screen.OnDisable             [ScriptSignal] ()
		Screen.OnActivate            [ScriptSignal] (props)
		Screen.ActiveScreenChanged   [ScriptSignal] (screen or nil)
		Screen.ActivePromptChanged   [ScriptSignal] (screen or nil)
		
		Screen.OnParented            [ScriptSignal] (parent_screen)
		
	Methods [Screen]:
	
		-- WARNING: Activate, Disable, ActivateChild & DisableChild can't be used inside OnDisable & OnActivate listeners!
	
		Screen:Activate(props)
		Screen:Disable()
		Screen:ActivateChild(child_name, props)
		Screen:DisableChild(child_name, props)
			child_name   [string] -- Will throw a warning if a child with this name is not found
			props        [table] or nil -- Defaults to an empty table
			is_froced    [bool] or nil -- Whether ShouldDisable callback is going to be ignored
	
		-- Cleanup:
		Screen:AddCleanupTask(task) -- Tasks are performed after Screen.OnDisable fires
		Screen:RemoveCleanupTask(task)
	
--]]

local SETTINGS = {
	AutoScaleAlign = {
		AutoCenter = Vector2.new(0.5, 0.5),
		AutoTop = Vector2.new(0.5, 0),
		AutoBottom = Vector2.new(0.5, 1),
		AutoLeft = Vector2.new(0, 0.5),
		AutoRight = Vector2.new(1, 0.5),
		AutoTopLeft = Vector2.new(0, 0),
		AutoTopRight = Vector2.new(1, 0),
		AutoBottomLeft = Vector2.new(0, 1),
		AutoBottomRight = Vector2.new(1, 1),
	},
	AutoScaleRemoveInstances = {"UIScale"},
}

----- Module Table -----

local Gui = {
	LocalPlayer = game:GetService("Players").LocalPlayer,
	PlayerGui = nil,
}

----- Loaded Controllers & Modules -----

local MadworkMaid = require(Madwork.GetShared("Madwork", "MadworkMaid"))

----- Private Variables -----

local GuiService = game:GetService("GuiService")

----- Utils -----

local function DeepCopyTable(t)
	local copy = {}
	for key, value in pairs(t) do
		if type(value) == "table" then
			copy[key] = DeepCopyTable(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function ReconcileTable(target, template)
	for k, v in pairs(template) do
		if type(k) == "string" then -- Only string keys will be reconciled
			if target[k] == nil then
				if type(v) == "table" then
					target[k] = DeepCopyTable(v)
				else
					target[k] = v
				end
			elseif type(target[k]) == "table" and type(v) == "table" then
				ReconcileTable(target[k], v)
			end
		end
	end
end

----- Private functions -----

local function EnableActiveLock(screen)
	while screen ~= nil do
		screen._active_lock += 1
		screen = screen.Parent
	end
end

local function DisableActiveLock(screen)
	while screen ~= nil do
		screen._active_lock -= 1
		screen = screen.Parent
	end
end

----- Public functions -----

-- Screen object:
local Screen = {
	--[[
		_active_lock = 0,
		_default_props = {},
		_active_maid = maid,
	--]]
}
Screen.__index = Screen

function Screen:Activate(props)
	
	local parent = self.Parent
	
	-- Active lock catch:
	if parent ~= nil and parent._active_lock ~= 0 then
		warn("[Gui]: Tried to enable ancestor/sibling screen \"" .. self.Name .. "\" inside OnActivate/OnDisable listener; Traceback:\n" .. debug.traceback())
		return
	end
	
	-- Check whether all ancestors are active:
	local trace = self.Name
	local ancestor = parent
	while ancestor ~= nil do
		trace = ancestor.Name .. "." .. trace
		if ancestor.IsActive == false then
			warn("[Gui]: Tried to activate screen (\"" .. trace .. "\") with an inactive ancestor; Traceback:\n" .. debug.traceback())
			return
		end
		ancestor = ancestor.Parent
	end
	
	-- Disable sibling screen of same type (screen / prompt):
	if parent ~= nil then
		if self.IsPrompt == true and parent.ActivePrompt ~= nil then
			parent.ActivePrompt:Disable(true)
		elseif self.IsPrompt == false and parent.ActiveScreen ~= nil then
			parent.ActiveScreen:Disable(true)
		end
	end
	
	-- Enable screen:
	EnableActiveLock(parent)
	
	self.IsActive = true
	self.OnActivate:Fire(ReconcileTable(props or {}, self._default_props))
	
	DisableActiveLock(parent)
	
	-- Changing parent values:
	if parent ~= nil then
		if self.IsPrompt == true then
			parent.ActivePrompt = self
			parent.ActivePromptChanged:Fire(self)
		else
			parent.ActiveScreen = self
			parent.ActiveScreenChanged:Fire(self)
		end
	end
end

function Screen:Disable(_is_changing_screens)
	if self.IsActive == false then
		return
	end
	
	local parent = self.Parent
	
	-- Active lock catch:
	if parent ~= nil and parent._active_lock ~= 0 then
		warn("[Gui]: Tried to disable ancestor/sibling screen \"" .. self.Name .. "\" inside OnActivate/OnDisable listener; Traceback:\n" .. debug.traceback())
		return
	end
	
	-- Disabling all descendants:
	for _, screen in pairs(self.Children) do
		screen:Disable()
	end
	
	-- Disabling this screen:
	EnableActiveLock(parent)
	
	self.IsActive = false
	self.OnDisable:Fire()
	self._active_maid:Cleanup()
	self._active_maid = MadworkMaid.NewMaid()
	
	DisableActiveLock(parent)
	
	-- Changing parent values:
	if parent ~= nil then
		if self.IsPrompt == true then
			parent.ActivePrompt = nil
			if _is_changing_screens ~= true then
				parent.ActivePromptChanged:Fire(nil)
			end
		else
			parent.ActiveScreen = nil
			if _is_changing_screens ~= true then
				parent.ActiveScreenChanged:Fire(nil)
			end
		end
	end
end

function Screen:ActivateChild(child_name, props)
	local screen = self.Children[child_name]
	if screen ~= nil then
		screen:Activate(props)
	else
		warn("[Gui]: Child screen \"" .. tostring(child_name) .. "\" was not defined; Traceback:\n" .. debug.traceback())
	end
end

function Screen:DisableChild(child_name)
	local screen = self.Children[child_name]
	if screen ~= nil then
		screen:Disable()
	else
		warn("[Gui]: Child screen \"" .. tostring(child_name) .. "\" was not defined; Traceback:\n" .. debug.traceback())
	end
end

-- Cleanup:
function Screen:AddCleanupTask(task) -- Tasks are performed after Screen.OnDisable fires
	self._active_maid:AddCleanupTask(task)
end

function Screen:RemoveCleanupTask(task)
	self._active_maid:RemoveCleanupTask(task)
end

-- Module functions:

function Gui.Get(instance, name_array) --> [Instance] -- Throws an error if not found
	local pointer = instance
	local pointer_debug
	local index = 1
	
	while pointer ~= nil do
		pointer_debug = pointer
		if index > #name_array then
			break
		end
		pointer = pointer:FindFirstChild(name_array[index])
		index += 1
	end
	
	if pointer ~= nil then
		return pointer
	else
		if instance == nil then
			error("[Gui]: Passed nil to Gui.Get()")
		else
			index -= 1
			error("[Gui]: Could not find \"" .. tostring(name_array[index]) .. "\" inside of \"" .. pointer_debug:GetFullName() .. "\"")
		end
	end
end

function Gui.Check(instance, name_array) --> [Instance] or nil
	local pointer = instance
	local index = 1

	while pointer ~= nil do
		if index > #name_array then
			break
		end
		pointer = pointer:FindFirstChild(name_array[index])
		index += 1
	end

	return pointer
end

function Gui.AutoScale(auto_scale_params) --> [function] ()

	local container = auto_scale_params.Container
	local maximum_size = auto_scale_params.MaximumSize -- [Vector2]
	local power_relationship = auto_scale_params.PowerRelationshipPastMaximum -- [number] or nil

	if container == nil or container:IsA("GuiBase2d") ~= true then
		error("[Gui]: Invalid Container property")
	end

	local connections = {}

	for _, target in ipairs(container:GetChildren()) do
		local align = SETTINGS.AutoScaleAlign[target.Name]
		if target:IsA("GuiBase2d") == true and align ~= nil then

			for _, child in ipairs(target:GetChildren()) do
				for _, remove_class in ipairs(SETTINGS.AutoScaleRemoveInstances) do
					if child:IsA(remove_class) == true then
						child:Destroy()
						break
					end
				end
			end

			local ui_scale = Instance.new("UIScale")
			ui_scale.Parent = target

			local function scale_update()

				local container_size = container.AbsoluteSize
				local target_size_udim2 = target.Size
				local target_size = Vector2.new(target_size_udim2.X.Offset, target_size_udim2.Y.Offset)

				if target_size_udim2.X.Scale ~= 0 or target_size_udim2.Y.Scale ~= 0 then
					warn("[Gui]: Expecting target to not use scale (" .. target:GetFullName() .. "); Traceback:\n" .. debug.traceback())
					target.Size = UDim2.new(0, target_size.X, 0, target_size.Y)
				end

				local container_ratio = container_size.X / container_size.Y
				local target_ratio = target_size.X / target_size.Y

				local desired_scale

				if container_ratio > target_ratio then
					-- Scale by Y relationship:
					local desired_y
					if maximum_size ~= nil then
						desired_y = math.min(maximum_size.Y, container_size.Y)
					else
						desired_y = container_size.Y
					end
					if power_relationship ~= nil then
						desired_y = math.min(container_size.Y, desired_y + (container_size.Y - desired_y) ^ power_relationship)
					end
					desired_scale = (desired_y / container_size.Y) / (target_size.Y / container_size.Y)
				else
					-- Scale by X relationship:
					local desired_x
					if maximum_size ~= nil then
						desired_x = math.min(maximum_size.X, container_size.X)
					else
						desired_x = container_size.X
					end
					if power_relationship ~= nil then
						desired_x = math.min(container_size.X, desired_x + (container_size.X - desired_x) ^ power_relationship)
					end
					desired_scale = (desired_x / container_size.X) / (target_size.X / container_size.X)
				end

				ui_scale.Scale = desired_scale

				local new_target_size = target_size * desired_scale -- align

				local align_position_raw = {0, 0, 0, 0} -- Creating a UDim2 position that will align the target accordingly
				for index, axis in ipairs({"X", "Y"}) do
					align_position_raw[((index - 1) * 2) + 1] = align[axis] -- Scale
					align_position_raw[((index - 1) * 2) + 2] = -align[axis] * new_target_size[axis] -- Offset
				end

				target.Position = UDim2.new(table.unpack(align_position_raw))

			end

			table.insert(connections, target:GetPropertyChangedSignal("Size"):Connect(scale_update))
			table.insert(connections, container:GetPropertyChangedSignal("AbsoluteSize"):Connect(scale_update))
			scale_update()

		end
	end

	return function()
		if connections ~= nil then
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
			connections = nil
		end
	end

end

function Gui.GetInset() --> [number]
	local inset_TL, inset_BR = GuiService:GetGuiInset()
	return inset_TL.Y - inset_BR.Y
end

function Gui.NewScreen(screen_params) --> [Screen]
	
	if type(screen_params.Name) ~= "string" then
		error("[Gui]: Screen name must be a string")
	end
	
	local screen = {
		Name = screen_params.Name,
		ScreenContainer = screen_params.ScreenContainer,
		PromptContainer = screen_params.PromptContainer,
		
		IsPrompt = screen_params.IsPrompt or false,
		Children = screen_params.Children or {},
		Parent = nil,
		
		IsActive = false,
		
		ActiveScreen = nil,
		ActivePrompt = nil,
		
		OnDisable = Madwork.NewScriptSignal(),
		OnActivate = Madwork.NewScriptSignal(),
		ActiveScreenChanged = Madwork.NewScriptSignal(),
		ActivePromptChanged = Madwork.NewScriptSignal(),
		
		OnParented = Madwork.NewScriptSignal(),
		
		_active_lock = 0, -- Preventing ancestor/sibling screen active state changing inside OnDisable & OnActivate listeners
		_default_props = screen_params.DefaultProps or {},
		_active_maid = MadworkMaid.NewMaid(),
	}
	setmetatable(screen, Screen)
	
	-- Check whether descendants are not active:
	local function recursive_active_check(check_screen, stack)
		for _, child_screen in pairs(check_screen.Children) do
			recursive_active_check(child_screen, stack .. "." .. child_screen.Name)
		end
		if check_screen.IsActive == true then
			error("[Gui]: Screens can't be active when being parented to another screen (\"" .. stack .. "\")")
		end
	end
	recursive_active_check(screen, screen.Name)
	
	-- Trigger onParented for Screen children:
	for _, child_screen in pairs(screen.Children) do
		child_screen.OnParented:Fire(screen)
	end
	
	return screen
end

----- Initialize -----

Gui.PlayerGui = Gui.LocalPlayer:WaitForChild("PlayerGui")

return Gui