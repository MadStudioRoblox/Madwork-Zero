local Madwork = _G.Madwork
--[[
{Madwork}

-[LocalTransparency]---------------------------------------

	Functions:
	
		LocalTransparency.NewLocalTransparency(instance) --> [LocalTransparency]
			instance   [Model] or [BasePart]
		
	Members [LocalTransparency]:
	
		LocalTransparency.Transparency          [number]
		LocalTransparency.TransparencyChanged   [ScriptSignal] (transparency)
		
	Methods [LocalTransparency]:
	
		LocalTransparency:AddInstance(instance)
		LocalTransparency:RemoveInstance(instance)
			instance   [Model] or [BasePart]
			
		LocalTransparency:Update()
			
		LocalTransparency:Destroy()
	
--]]

local SETTINGS = {
	
}

----- Module Table -----

local LocalTransparency = {
	
}

----- Private functions -----

local function AddPart(local_transparency, instance)
	if instance:IsA("BasePart") == true then
		local_transparency._controlled_parts[instance] = true
		instance.LocalTransparencyModifier = local_transparency._transparency
	end
end

local function RemovePart(local_transparency, instance)
	if instance:IsA("BasePart") == true then
		local_transparency._controlled_parts[instance] = nil
		instance.LocalTransparencyModifier = 0
	end
end

local function AddInstance(local_transparency, instance)
	assert(typeof(instance) == "Instance", "[LocalTrasnparency]: Tried to add a non-instance object (" .. tostring(instance) .. ")")
	AddPart(local_transparency, instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		AddPart(local_transparency, descendant)
	end
	local old_connections = local_transparency._connections[instance]
	if old_connections ~= nil then
		for _, connection in ipairs(old_connections) do
			connection:Disconnect()
		end
	end
	local_transparency._connections[instance] = {
		instance.DescendantAdded:Connect(function(descendant)
			AddPart(local_transparency, descendant)
		end),
		instance.DescendantRemoving:Connect(function(descendant)
			RemovePart(local_transparency, descendant)
		end),
	}
end

local function RemoveInstance(local_transparency, instance)
	assert(typeof(instance) == "Instance", "[LocalTrasnparency]: Tried to remove a non-instance object (" .. tostring(instance) .. ")")
	RemovePart(local_transparency, instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		RemovePart(local_transparency, descendant)
	end
	local connections = local_transparency._connections[instance]
	if connections ~= nil then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end
	local_transparency._connections[instance] = nil
end

local function SetTransparency(local_transparency, transparency)
	local new_transparency = math.clamp(transparency, 0, 1)
	if new_transparency ~= local_transparency._transparency then
		local_transparency._transparency = new_transparency
		for part in pairs(local_transparency._controlled_parts) do
			part.LocalTransparencyModifier = new_transparency
		end
		local_transparency.TransparencyChanged:Fire(new_transparency)
	end
end

----- Public functions -----

local LocalTransparencyObject = {
	--[[
		TransparencyChanged = script_signal,
	
		_transparency = 0,
		_controlled_parts = {}, -- [part] = true
		_connections = {}, -- [instance] = {connection, ...}
	--]]
}
LocalTransparencyObject.__index = function(self, index)
	if index == "Transparency" then
		return self._transparency
	else
		return LocalTransparencyObject[index]
	end
end
LocalTransparencyObject.__newindex = function(self, index, value)
	if index == "Transparency" then
		SetTransparency(self, value)
	else
		self[index] = value
	end
end

function LocalTransparency:AddInstance(instance)
	AddInstance(self, instance)
end

function LocalTransparency:RemoveInstance(instance)
	RemoveInstance(self, instance)
end

function LocalTransparency:Update()
	local transparency = self._transparency
	for part in pairs(self._controlled_parts) do
		part.LocalTransparencyModifier = transparency
	end
end

function LocalTransparencyObject:Destroy()
	for instance in pairs(self._connections) do
		self:RemoveInstance(instance)
	end
end

-- Module functions:

function LocalTransparency.NewLocalTransparency(instance) --> [LocalTransparency]
	local local_transparency = {
		TransparencyChanged = Madwork.NewScriptSignal(),
		
		_transparency = 0,
		_controlled_parts = {},
		_connections = {},
	}
	setmetatable(local_transparency, LocalTransparencyObject)
	
	if instance ~= nil then
		AddInstance(local_transparency, instance)
	end
	
	return local_transparency
end

return LocalTransparency