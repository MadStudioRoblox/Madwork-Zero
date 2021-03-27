local Madwork = _G.Madwork
--[[
[MPBR]

-[SpawnArea]---------------------------------------
	Provides common functions for handling spawn points
	
	Functions:
	
		Spawn.NewSpawnArea(spawn_params) --> [SpawnArea]
			spawn_params   [table]:
				{
					Model = model, -- [Instance] -- Any BaseParts inside are assumed to be spawn parts - characters will spawn above these parts
					YOffset = 0, -- Studs above spawn part surface to return by SpawnArea:GetCFrame()
					MinProximity = 5, -- Desirable distance from "avoid_positions" in studs
					AvoidFunction = function or nil, -- [function] --> {position, ...}
				}
		
	Methods [SpawnArea]:
	
		SpawnArea:GetCFrame() --> [CFrame] -- Returns a random CFrame to spawn the character on;
			Tries to find a CFrame that's away from other characters.

--]]

local SETTINGS = {
	DesirableCharacterProximity = 5, -- (studs) Desirable distancing between characters at spawn
	RandomRotationFlag = "RandomRotation", -- Instance name of a part instance child to request for random spawn rotation
	RandomRetries = 20,
}

----- Module Table -----

local SpawnArea = {
	
}

----- Public functions -----

-- SpawnArea object:
local SpawnAreaObject = {
	--[[
		_planes = {
			{
				CFrame = cframe,
				Bounds = vector3, -- Half size
				IsRandom = false,
			},
			...
		},
		_min_proximity = 0,
		_avoid_function = function or nil,
		
		_box_bound1 = vector3,
		_box_bound2 = vector3,
	--]]
}
SpawnAreaObject.__index = SpawnAreaObject

function SpawnAreaObject:GetCFrame(min_proximity, avoid_positions) --> [CFrame]
	
	local avoid_positions = {} -- {position, ...}
	
	-- Fetching character positions near spawn:
	
	if self._avoid_function ~= nil then
	
		local box_bound1, box_bound2 = self._box_bound1, self._box_bound2
		
		for _, position in ipairs(self._avoid_function()) do
			local b1c, b2c = position - box_bound1, box_bound2 - position -- Bound check
			if b1c.X > 0 and b1c.Y > 0 and b1c.Z > 0 and b2c.X > 0 and b2c.Y > 0 and b2c.Z > 0 then
				table.insert(avoid_positions, position)
			end
		end
		
	end
	
	-- Generating random position:
	
	local best_cframe, best_magnitude, is_random = CFrame.new(), 0, false
	local retries = SETTINGS.RandomRetries
	
	local planes = self._planes
	
	repeat
		
		local plane = planes[math.random(1, #planes)]
		local cframe = plane.CFrame * CFrame.new(plane.Bounds * Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 2)
		local position = cframe.Position
		local min_magnitude = math.huge
		
		for _, avoid_pos in ipairs(avoid_positions) do
			min_magnitude = math.min(min_magnitude, ((avoid_pos - position) * Vector3.new(1, 0, 1)).Magnitude)
		end
		
		if min_magnitude > best_magnitude then
			best_cframe = cframe
			best_magnitude = min_magnitude
			is_random = plane.IsRandom
		end
		
		retries -= 1
		
	until best_magnitude > self._min_proximity or retries == 0
	
	-- Locking cframe rotation to XZ plane:
	
	local look_vector = best_cframe.LookVector * Vector3.new(1, 0, 1)
	if look_vector.Magnitude == 0 then
		look_vector = Vector3.new(0, 0, -1)
	end
	
	best_cframe = CFrame.lookAt(best_cframe.Position, best_cframe.Position + look_vector)
	
	-- Applying random rotation if a plane with a random rotation flag is selected:
	
	if is_random == true then
		best_cframe *= CFrame.Angles(0, math.random() * math.pi * 2, 0)
	end
	
	return best_cframe

end

-- Module functions:

function SpawnArea.NewSpawnArea(spawn_params) --> [SpawnArea]
	
	-- Fetching parts:
	
	local parts = {} -- {part, ...}
	
	for _, part in ipairs(spawn_params.Model:GetDescendants()) do
		if part:IsA("BasePart") == true then
			table.insert(parts, part)
			if part.ClassName ~= "Part" then
				warn("[SpawnArea]: Part \"" .. part:GetFullName() .. "\" expected to be of \"Part\" class; Traceback:\n" .. debug.traceback())
			elseif part.CFrame.UpVector.Y < 0.3 then
				warn("[SpawnArea]: Part \"" .. part:GetFullName() .. "\" TopSurface is not pointing up; Traceback:\n" .. debug.traceback())
			end
		end
	end
	
	if #parts == 0 then
		error("[SpawnArea]: No parts given for SpawnArea; Traceback:\n" .. debug.traceback())
	end

	-- Extracting spawn planes:
	
	local planes = {} -- {{CFrame = cframe, bounds = vector3, IsRandom = false}, ...}
	
	for _, part in ipairs(parts) do
		table.insert(planes,
			{
				CFrame = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0) + Vector3.new(0, spawn_params.YOffset or 0, 0),
				Bounds = part.Size * Vector3.new(0.5, 0, 0.5),
				IsRandom = part:FindFirstChild(SETTINGS.RandomRotationFlag) ~= nil,
			}
		)
	end
	
	-- Finding box bounds:
	
	local axis_list = {"X", "Y", "Z"}
	local corner_list = {Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1)}
	
	local box_bound1_raw, box_bound2_raw = {math.huge, math.huge, math.huge}, {-math.huge, -math.huge, -math.huge}
	
	for _, plane in ipairs(planes) do
		local cframe = plane.CFrame
		local bounds = plane.Bounds
		for _, corner_unit in ipairs(corner_list) do
			local corner = (cframe * CFrame.new(bounds * corner_unit)).Position
			for axis_index, axis in ipairs(axis_list) do
				box_bound1_raw[axis_index] = math.min(box_bound1_raw[axis_index], corner[axis])
				box_bound2_raw[axis_index] = math.max(box_bound2_raw[axis_index], corner[axis])
			end
		end
	end
	
	-- Creating SpawnArea object:
	
	local spawn_area = {
		_planes = planes,
		_min_proximity = spawn_params.MinProximity or 0,
		_avoid_function = spawn_params.AvoidFunction,
		_box_bound1 = Vector3.new(table.unpack(box_bound1_raw)),
		_box_bound2 = Vector3.new(table.unpack(box_bound2_raw)),
	}
	setmetatable(spawn_area, SpawnAreaObject)
	
	return spawn_area
	
end

return SpawnArea