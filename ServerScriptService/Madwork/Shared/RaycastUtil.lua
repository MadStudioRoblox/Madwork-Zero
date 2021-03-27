local Madwork = _G.Madwork
--[[
{Madwork}

-[RaycastUtil]---------------------------------------
	Raycast utilities
	
	Functions:
	
		RaycastUtil.Raycast(raycast_params) --> [RaycastResult] or nil -- Simplified Workspace:Raycast() function
			raycast_params   [table]: {
				Origin = vector3,
				Direction = vector3, -- (unit_vector * distance)
				-- Optional params:
				CollisionGroup = "Default",
				Blacklist = {ignore_part, ...},
				Filter = function(base_part), -- Return true if part has to be blacklisted
			}
	
	
	[RaycastResult]
		RaycastResult.Instance   [BasePart] -- [Terrain] is also a [BasePart]
		RaycastResult.Position   [Vector3]
		RaycastResult.Material   [Enum.Material]
		RaycastResult.Normal     [Vector3]
		
--]]

local SETTINGS = {
	
}

----- Module Table -----

local RaycastUtil = {
	
}

----- Private Variables -----

local Workspace = game:GetService("Workspace")

local RaycastParamsObject = RaycastParams.new()

----- Public functions -----

function RaycastUtil.Raycast(raycast_params) --> [RaycastResult] or nil
	RaycastParamsObject.CollisionGroup = raycast_params.CollisionGroup or "Default"
	local blacklist = raycast_params.Blacklist or {}
	RaycastParamsObject.FilterDescendantsInstances = blacklist
	
	local filter = raycast_params.Filter
	
	if filter == nil then
		return Workspace:Raycast(raycast_params.Origin, raycast_params.Direction, RaycastParamsObject)
	else
		local distance = raycast_params.Direction.Magnitude
		local direction_unit = distance > 0 and raycast_params.Direction.Unit or Vector3.new()
		local segment_position = raycast_params.Origin
		
		while true do
			local raycast_result = Workspace:Raycast(segment_position, direction_unit * distance, RaycastParamsObject)
			if raycast_result ~= nil then
				if filter(raycast_result.Instance) == true then
					table.insert(blacklist, raycast_result.Instance)
					RaycastParamsObject.FilterDescendantsInstances = blacklist
					local hit_pos = raycast_result.Position
					distance -= (segment_position - hit_pos).Magnitude - 0.1
					segment_position = hit_pos - direction_unit * 0.1
				else
					return raycast_result
				end
			else
				return nil
			end
		end
	end
end

----- Initialize -----

RaycastParamsObject.FilterType = Enum.RaycastFilterType.Blacklist
RaycastParamsObject.IgnoreWater = true

return RaycastUtil