local Madwork = _G.Madwork
--[[
{Madwork}

-[Spring]---------------------------------------

	Functions:
	
		Spring.NewSpring(spring_params) --> [Spring] (number)
		Spring.NewSpringV2(spring_params) --> [Spring] (Vector2)
		Spring.NewSpringV3(spring_params) --> [Spring] (Vector3)
		
			spring_params   [table]:
				{
					-- All params are optional; Values below as defaults:
					Target = 0 or Vector2.new(0, 0) or Vector3.new(0, 0, 0),
					Position = 0 or Vector2.new(0, 0) or Vector3.new(0, 0, 0),
					Velocity = 0 or Vector2.new(0, 0) or Vector3.new(0, 0, 0),
					
					Power = 1,
					Damping = 1,
					SimulationSpeed = 1,
				}
				
	Members [Spring]:
	
		Spring.Target            [Vector3] or [Vector2] or [number]
		Spring.Position          [Vector3] or [Vector2] or [number]
		Spring.Velocity          [Vector3] or [Vector2] or [number]
		
		Spring.Power             [number]
		Spring.Damping           [number]
		Spring.SimulationSpeed   [number]
		
		Spring.Acceleration      [Vector3] or [Vector2] or [number] (read-only) -- Last acceleration the spring experienced (after update)
		Spring.Energy            [Vector3] or [Vector2] or [number] (read-only) -- Remaining energy in the system (after update)
		
	Methods [Spring]:
	
		Spring:Shove(force)
		Spring:Update(delta_time) -- delta_time optional
	
--]]

local SETTINGS = {
	
	IterationsPerSecond = 480,
	
	Defaults = {
		Power = 1,
		Damping = 1,
		SimulationSpeed = 1,
	},
	
}

----- Module Table -----

local Spring = {
	
}

----- Private Variables -----

local deriv_IterationTime = 1 / SETTINGS.IterationsPerSecond
local Defaults = SETTINGS.Defaults

----- Public functions -----

-- Spring object:
local SpringObject = {}
SpringObject.__index = SpringObject

function SpringObject:Shove(force)
	self.Velocity += force
end

function SpringObject:Update(delta_time)
	local os_clock = os.clock()
	delta_time = delta_time or (os_clock - self._last_update)
	self._last_update = os_clock
	
	local delta_queue = self._delta_queue
	delta_time += delta_queue
	local iterations = math.floor(delta_time / deriv_IterationTime)
	delta_time = iterations * deriv_IterationTime
	self._delta_queue = delta_queue - math.min(delta_queue, delta_time)
	
	local scaled_delta_time = deriv_IterationTime * self.SimulationSpeed
	local distance_to_target
	local acceleration
	
	for i = 1, iterations do
		distance_to_target = self.Target - self.Position
		acceleration = (distance_to_target * self.Power) - self.Velocity * self.Damping
		self.Velocity = self.Velocity + acceleration * scaled_delta_time
		self.Position = self.Position + self.Velocity * scaled_delta_time
	end
	
	if acceleration ~= nil then
		self.Acceleration = acceleration
		if self._is_vector == true then
			self.Energy = 0.5 * self.Velocity.Magnitude ^ 2 + 0.5 * self.Power * distance_to_target.Magnitude ^ 2
		else
			self.Energy = 0.5 * self.Velocity ^ 2 + 0.5 * self.Power * math.abs(distance_to_target) ^ 2
		end
	end
	
	return self.Position
end

-- Module functions:

function Spring.NewSpring(spring_params) --> [Spring] (number)
	local spring = {
		Target = spring_params.Target or 0,
		Position = spring_params.Position or 0,
		Velocity = spring_params.Velocity or 0,
		
		Power = spring_params.Power or Defaults.Power,
		Damping = spring_params.Damping or Defaults.Damping,
		SimulationSpeed = spring_params.SimulationSpeed or Defaults.SimulationSpeed,
		Acceleration = 0,
		
		_delta_queue = 0,
		_last_update = os.clock(),
		_is_vector = false,
	}
	setmetatable(spring, SpringObject)
	
	return spring
end

function Spring.NewSpringV2(spring_params) --> [Spring] (Vector2)
	local spring = {
		Target = spring_params.Target or Vector2.new(0, 0),
		Position = spring_params.Position or Vector2.new(0, 0),
		Velocity = spring_params.Velocity or Vector2.new(0, 0),
		
		Power = spring_params.Power or Defaults.Power,
		Damping = spring_params.Damping or Defaults.Damping,
		SimulationSpeed = spring_params.SimulationSpeed or Defaults.SimulationSpeed,
		Acceleration = Vector2.new(0, 0),
		
		_delta_queue = 0,
		_last_update = os.clock(),
		_is_vector = true,
	}
	setmetatable(spring, SpringObject)
	
	return spring
end

function Spring.NewSpringV3(spring_params) --> [Spring] (Vector3)
	local spring = {
		Target = spring_params.Target or Vector3.new(0, 0, 0),
		Position = spring_params.Position or Vector3.new(0, 0, 0),
		Velocity = spring_params.Velocity or Vector3.new(0, 0, 0),
		
		Power = spring_params.Power or Defaults.Power,
		Damping = spring_params.Damping or Defaults.Damping,
		SimulationSpeed = spring_params.SimulationSpeed or Defaults.SimulationSpeed,
		Acceleration = Vector3.new(0, 0, 0),
		
		_delta_queue = 0,
		_last_update = os.clock(),
		_is_vector = true,
	}
	setmetatable(spring, SpringObject)
	
	return spring
end

return Spring