local Madwork = _G.Madwork
--[[
{Madwork}

-[LatencyController]---------------------------------------
	Client latency tracking

	Members:
	
		LatencyController.Connected              [bool] (Read-only) -- Set to true after first latency value arrives from server
		LatencyController.Latency                [number] (Read-only) (seconds) (half round trip) -- Latency the player is currently experiencing
		LatencyController.LatencyDeviation       [number] (Read-only) (seconds) (of half round trip) -- Latency deviation the player is likely 
			to experience for a while
			
		LatencyController.PoorConnectionSignal   [ScriptSignal] (is_poor_connection)
		LatencyController.PoorConnection         [bool] (Read-only) -- Whether the client is likely having a poor game experience
		
		LatencyController.LastTimeServer     [number]
		LatencyController.LastTimeClient     [number]
		
	Functions:
	
		LatencyController.ServerTimeToClientTime(server_time) --> (client_time) -- For live updates with "delta = os.clock() - client_time"
			-- Notice: Resulting client_time might need value clamping for animations - delta = math.max(os.clock() - client_time, 0)
--]]

local SETTINGS = {
	
}

----- Controller Table -----

local LatencyController = {

	Connected = false,
	Latency = 0,
	LatencyDeviation = 0,
	PoorConnectionSignal = Madwork.NewScriptSignal(),
	PoorConnection = false,
	
	LastTimeServer = 0,
	LastTimeClient = 0,
	
}

----- Private Variables -----

local rev_Ping = Madwork.SetupRemoteEvent("LatencyService_Ping")

----- Public functions -----

function LatencyController.ServerTimeToClientTime(server_time)
	local last_time_server = LatencyController.LastTimeServer
	local last_time_client = LatencyController.LastTimeClient
	if last_time_server ~= 0 then
		-- return last_time_client + last_time_server - server_time
		return server_time - last_time_server + last_time_client
	end
	return 0
end

----- Connections -----

rev_Ping.OnClientEvent:Connect(function(server_time, latency, latency_deviation, is_poor_connection)
	-- print("PING GET - os.clock() difference: " .. math.floor((os.clock() - server_time) * 1000) / 1000)
	rev_Ping:FireServer(server_time)
	LatencyController.LastTimeServer = server_time
	LatencyController.LastTimeClient = os.clock()
	if latency ~= nil then
		LatencyController.Connected = true
		LatencyController.Latency = latency
		LatencyController.LatencyDeviation = latency_deviation
		if LatencyController.PoorConnection ~= is_poor_connection then
			LatencyController.PoorConnection = is_poor_connection
			LatencyController.PoorConnectionSignal:Fire(is_poor_connection)
		end
	end
end)

return LatencyController