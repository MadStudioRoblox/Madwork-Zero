local Madwork = _G.Madwork
--[[
{Madwork}

-[LatencyService]---------------------------------------
	Tracks client network health; Mainly for use in CharacterService constraints
	
	Members:
	
		LatencyService.HeartbeatHook   [ScriptSignal] -- Fired every time LatencyService finishes a Heartbeat update

	Functions:
	
		LatencyService.GetPlayerLatency(player) --> [PlayerLatency] -- Returned object auto cleans up after the player leaves;
			-- Consecutive calls with the same player will return a reference to an already existing object
			
		LatencyService.Get
		
	Members [PlayerLatency]:
	
		PlayerLatency.Connected              [bool] (Read-only) -- Set to true after first returned ping from client
		PlayerLatency.Latency                [number] (Read-only) (seconds) (half round trip) -- Latency the player is currently experiencing
		PlayerLatency.LatencyDeviation       [number] (Read-only) (seconds) (of half round trip) -- Latency deviation the player is likely 
			to experience for a while
			
		PlayerLatency.PoorConnectionSignal   [ScriptSignal] (is_poor_connection)
		PlayerLatency.PoorConnection         [bool] (Read-only) -- Whether the client is likely having a poor game experience
--]]

local SETTINGS = {

	PoorConnection = {
		Latency = 1, -- seconds
		LatencyDeviation = 0.25, -- seconds
		Duration = 1, -- How long will the PoorConnection state last after last trigger
	},
	
	LatencyBufferSize = 10, -- That many latency entries will be used to calculate a smoother latency average
	
	DeviationBufferSize = 10,
	DeviationBufferDecay = 30, -- (seconds) How long it takes for a LatencyDeviation buffer entry to be forgotten
	
}

----- Service Table -----

local LatencyService = {

	HeartbeatHook = Madwork.NewScriptSignal(), -- Fired every time LatencyService finishes a Heartbeat update

	_active_player_latencies = {
		--[[
			[player] = {
				Connected = false,
				Latency = 0,
				LatencyDeviation = 0,
				PoorConnectionSignal = Madwork.NewScriptSignal(),
				PoorConnection = false,
				
				_latency_buffer = {}, -- Integer values
				_latency_pointer = 1,
				_latency_buffer_sum = 0, -- Integer value
				
				_deviation_buffer = {}, -- Integer values
				_deviation_pointer = 1,
				
				_last_time_sent = 0,
			},
			...
		--]]
	},
	
}

----- Loaded Services & Modules -----

local ReplicaService = Madwork.GetService("ReplicaService")

----- Private Variables -----

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local rev_Ping = Madwork.SetupRemoteEvent("LatencyService_Ping") -- Server: (server_time, latency, latency_deviation, is_poor_connection) / Client: (server_time_back)

local HeartbeatHook = LatencyService.HeartbeatHook
local ActivePlayerLatencies = LatencyService._active_player_latencies

-- Performance variables:

local sett_LatencyBufferSize = SETTINGS.LatencyBufferSize
local sett_DeviationBufferSize = SETTINGS.DeviationBufferSize
local sett_DeviationBufferDecay = SETTINGS.DeviationBufferDecay

local sett_PoorConnection_Latency = SETTINGS.PoorConnection.Latency
local sett_PoorConnection_LatencyDeviation = SETTINGS.PoorConnection.LatencyDeviation
local sett_PoorConnection_Duration = SETTINGS.PoorConnection.Duration

----- Public functions -----

function LatencyService.GetPlayerLatency(player) 
	local player_latency
	if ActivePlayerLatencies[player] ~= nil then
		player_latency = ActivePlayerLatencies[player]
	else
		player_latency = {
			Connected = false,
			Latency = 0,
			LatencyDeviation = 0,
			PoorConnectionSignal = Madwork.NewScriptSignal(),
			PoorConnection = false,

			_latency_buffer = table.create(SETTINGS.LatencyBufferSize, 0),
			_latency_pointer = 1,
			_latency_buffer_sum = 0,
			
			_deviation_buffer = table.create(SETTINGS.DeviationBufferSize, 0),
			_deviation_pointer = 1,
			
			_last_time_sent = 0,
			_poor_connection_start = 0,
		}
		if player.Parent == Players then
			ActivePlayerLatencies[player] = player_latency
			if ReplicaService.ActivePlayers[player] == true then -- Use ReplicaService to check if a player is ready to receive data
				local os_clock = os.clock()
				player_latency._last_time_sent = os_clock
				rev_Ping:FireClient(player, os_clock, nil, nil, false)
			end
		end
	end
	return player_latency
end

----- Connections -----

RunService.Heartbeat:Connect(function()
	local os_clock = os.clock()
	for player, player_latency in pairs(ActivePlayerLatencies) do
		if player_latency.Connected == true then
			-- Detect latency deviation spikes before the client returns the ping:
			local new_latency_ms = math.ceil((os_clock - player_latency._last_time_sent) * 500) -- Half round trip, milliseconds
			-- Check poor connection trigger:
			if new_latency_ms >= sett_PoorConnection_Latency * 1000 then
				player_latency._poor_connection_start = os_clock
				if player_latency.PoorConnection == false then
					player_latency.PoorConnection = true
					player_latency.PoorConnectionSignal:Fire(true)
				end
			end
			local latency_pointer = player_latency._latency_pointer
			local last_latency_ms = player_latency._latency_buffer[latency_pointer == 1 and sett_LatencyBufferSize or latency_pointer - 1]
			if new_latency_ms > last_latency_ms then -- Perform during lag spikes
				local new_deviation_ms = math.floor(math.abs(last_latency_ms - new_latency_ms))
				if new_deviation_ms > player_latency.LatencyDeviation * 1000 then -- We only need to increase LDTCurrent as the next ping receive will
					player_latency.LatencyDeviation = new_deviation_ms / 1000
					-- Check poor connection trigger:
					if new_deviation_ms >= sett_PoorConnection_LatencyDeviation * 1000 then
						player_latency._poor_connection_start = os_clock
						if player_latency.PoorConnection == false then
							player_latency.PoorConnection = true
							player_latency.PoorConnectionSignal:Fire(true)
						end
					end
					-- print("Auto latency deviation increase: " .. player.Name .. " - " .. math.floor(player_latency.LatencyDeviation * 1000) .. " ms")
				end
			end
		end
	end
	HeartbeatHook:Fire() -- Hook for services dependent on player latency
end)

rev_Ping.OnServerEvent:Connect(function(player, server_time_back)
	local os_clock = os.clock()
	local player_latency = ActivePlayerLatencies[player]
	if player_latency ~= nil then
		if server_time_back == player_latency._last_time_sent then
			-- Latency:
			local new_latency = os_clock - server_time_back
			local new_latency_ms = math.ceil(new_latency * 500) -- Half round trip, milliseconds
			local latency_buffer = player_latency._latency_buffer
			local latency_pointer = player_latency._latency_pointer
			if player_latency.Connected == false then -- Fill the latency buffer with the first received latency value
				player_latency.Connected = true
				for i = 1, sett_LatencyBufferSize do
					latency_buffer[i] = new_latency_ms
				end
				player_latency._latency_buffer_sum = new_latency_ms * sett_LatencyBufferSize
				player_latency.Latency = new_latency
				-- Set deviation buffer left of desired deviation pointer:
				local deviation_pointer_desired = math.floor(os_clock % sett_DeviationBufferDecay / sett_DeviationBufferDecay * sett_DeviationBufferSize) + 1
				player_latency._deviation_pointer = deviation_pointer_desired == 1 and sett_DeviationBufferSize or deviation_pointer_desired - 1
			end
			local old_latency_ms = latency_buffer[latency_pointer]
			local last_latency_ms = latency_buffer[latency_pointer == 1 and sett_LatencyBufferSize or latency_pointer - 1]
			latency_buffer[latency_pointer] = new_latency_ms
			player_latency._latency_pointer = latency_pointer == sett_LatencyBufferSize and 1 or latency_pointer + 1
			player_latency._latency_buffer_sum = player_latency._latency_buffer_sum - old_latency_ms + new_latency_ms
			player_latency.Latency = player_latency._latency_buffer_sum / sett_LatencyBufferSize / 1000
			-- Deviation:
			local new_deviation_ms = math.floor(math.abs(last_latency_ms - new_latency_ms))
			local deviation_buffer = player_latency._deviation_buffer
			local deviation_pointer = player_latency._deviation_pointer
			local deviation_pointer_desired = math.floor(os_clock % sett_DeviationBufferDecay / sett_DeviationBufferDecay * sett_DeviationBufferSize) + 1
			if deviation_pointer ~= deviation_pointer_desired then -- Deviation pointer has to be moved tighr
				-- Fill entries up to "deviation_pointer_desired" with new_deviation_ms
				while deviation_pointer ~= deviation_pointer_desired do
					deviation_pointer = deviation_pointer == sett_DeviationBufferSize and 1 or deviation_pointer + 1
					player_latency._deviation_pointer = deviation_pointer
					deviation_buffer[deviation_pointer] = new_deviation_ms
				end
				-- Find maximum deviation in buffer
				local max_deviation_ms = 0
				for i = 1, sett_DeviationBufferSize do
					max_deviation_ms = math.max(max_deviation_ms, deviation_buffer[i])
				end
				player_latency.LatencyDeviation = max_deviation_ms / 1000
			else -- Deviation pointer doesn't have to be moved right yet
				if deviation_buffer[deviation_pointer] < new_deviation_ms then
					deviation_buffer[deviation_pointer] = new_deviation_ms
					if new_deviation_ms > player_latency.LatencyDeviation * 1000 then
						player_latency.LatencyDeviation = new_deviation_ms / 1000
					end
				end
			end
			-- Check poor connection trigger:
			if player_latency.Latency >= sett_PoorConnection_Latency or player_latency.LatencyDeviation >= sett_PoorConnection_LatencyDeviation then
				player_latency._poor_connection_start = os_clock
				if player_latency.PoorConnection == false then
					player_latency.PoorConnection = true
					player_latency.PoorConnectionSignal:Fire(true)
				end
			end
			if player_latency.PoorConnection == true then
				if os_clock - player_latency._poor_connection_start > sett_PoorConnection_Duration then
					player_latency.PoorConnection = false
					player_latency.PoorConnectionSignal:Fire(false)
				end
			end
			-- Send new ping:
			player_latency._last_time_sent = os_clock
			rev_Ping:FireClient(player, os_clock, player_latency.Latency, player_latency.LatencyDeviation, player_latency.PoorConnection)
			-- print(player.Name .. " - PING: " .. new_latency_ms .. " ms; Latency: " .. math.floor(player_latency.Latency * 1000) .. " ms; Deviation: " .. math.floor(player_latency.LatencyDeviation * 1000) .. " ms")
		end
	end
end)

ReplicaService.NewActivePlayerSignal:Connect(function(player)
	local player_latency = ActivePlayerLatencies[player]
	if player_latency ~= nil then
		if player_latency._last_time_sent == 0 then
			local os_clock = os.clock()
			player_latency._last_time_sent = os_clock
			rev_Ping:FireClient(player, os_clock, nil, nil, false)
		end
	end
end)

ReplicaService.RemovedActivePlayerSignal:Connect(function(player)
	local player_latency = ActivePlayerLatencies[player]
	if player_latency ~= nil then
		player_latency.Connected = false
		ActivePlayerLatencies[player] = nil
	end
end)

return LatencyService