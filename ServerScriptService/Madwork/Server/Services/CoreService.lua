return function(dir_Madwork)
--[[
████████████████████	[Madwork 1.0]
████████████████████	
████    ████    ████	- Developed by loleris since 11/2018
████    ████    ████	
████    ████    ████	- "A framework for the most creative projects"
████    ████    ████
████            ████
████            ████
████            ████
████            ████

-[CoreService]---------------------------------------
	Game file managing; Globally accessible service references
	
	Members:
	
		Madwork.GameTag                [string] Game tag of the game running in this server
	
		Madwork.LoadingServicesCount   [number] Number of services pending to load
		Madwork.CoreReadySignal        [ScriptSignal] () Fired once when all services are loaded and configured
		Madwork.CoreReady              [bool] Set to true right before GameReadySignal is fired
	
	Functions:
	
		Madwork.GetService(service_name) --> [Service]
		Madwork.GetModule(package_name, path) --> [Instance]
		Madwork.GetShared(package_name, path) --> [Instance]
		
		Madwork.SetupRemoteEvent(remote_name) --> [RemoteEvent]
		
		Madwork.ConnectToOnClose(task, run_in_studio_mode) -- task function should yield until all nescessary DataStore and HttpService calls are finished
		
		Madwork.LoadPackage(package_name, dir_modules, dir_shared)
		Madwork.LoadServices(dir_services, service_names)
		Madwork.WaitForServices() -- Yields until Madwork.LoadingServicesCount reaches 0
		
		Madwork.SetGameTag(game_tag)
		
		Madwork.NewArrayScriptConnection(listener_table, listener, disconnect_listener, disconnect_param) --> [ScriptConnection]
		Madwork.NewScriptSignal() --> [ScriptSignal]
		
		Madwork.HeartbeatWait(wait_time) --> time_elapsed
		
		Madwork.Instance(class_name, properties) --> [Instance]
		
	Methods [ScriptSignal]:
	
		ScriptSignal:Connect(listener, disconnect_listener, disconnect_param) --> [ScriptConnection] listener(...) -- (listener functions can't yield)
		ScriptSignal:Fire(...)
		
	Methods [ScriptConnection]:
	
		ScriptConnection:Disconnect() -- Disconnect listener from signal
		
--]]

local SETTINGS = {

	PackageName = "Madwork",

	LoadServices = { -- Framework services to load in "dir_Services"
		"ReplicaService",
		"ContentService",
		"ProfileService",
		"LatencyService",
		"RegionService",
		"CharacterService",
		"PlayerProfileService",
	},
	
	LongLoadWarningTime = 5, -- Seconds
	
}

----- Service Table -----

local Madwork = {
	
	GameTag = nil,

	Services = {}, -- ["ServiceName"] = service
	Modules = {}, -- ["PackageName"] = dir_Modules
	Shared = {}, -- ["PackageName"] = dir_Shared
	
	LoadingServices = {}, -- ["ServiceName"] = service_module -- Services that are loaded or are going to be loaded
	LoadingServicesCount = 0, -- Number of services that haven't finished loading
	
	RemoteEvents = {}, -- ["RemoteEventName"] = RemoteEvent
	
	TestMode = false, -- Set to true before Madwork.NewScriptSignal() is fired if the game is in testing mode
	-- CoreReadySignal = Madwork.NewScriptSignal(), -- Fired once when all services are loaded and configured
	CoreReady = false, -- Set to true right before GameReadySignal is fired
	
}
_G.Madwork = Madwork

----- Private Variables -----

local TestService = game:GetService("TestService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Heartbeat = RunService.Heartbeat

local dir_Server = dir_Madwork:FindFirstChild("Server")
	local dir_Services = dir_Server:FindFirstChild("Services")
	local dir_Modules = dir_Server:FindFirstChild("Modules")
	
local dir_Client = dir_Madwork:FindFirstChild("Client")
local dir_Shared = dir_Madwork:FindFirstChild("Shared")

local dir_GameData = Instance.new("Folder")
	dir_GameData.Name = "GameData"
	dir_GameData.Parent = ReplicatedStorage
	Madwork.GameData = dir_GameData -- Reference in framework global
	
local dir_RemoteEvents = Instance.new("Folder")
	dir_RemoteEvents.Name = "RemoteEvents"
	dir_RemoteEvents.Parent = dir_GameData
	
local OnCloseTasks = {} -- {{function, run_in_studio_mode}, ...}
local IsStudio = RunService:IsStudio()

local MadworkScriptSignal

local LastRequiredServiceLog -- {module, service_name}

----- Private functions -----

local function ReadFilePath(dir_root, path) --> [Instance] (Finds file by path format "ChildName.ChildName")
	local destination = dir_root
	for s in string.gmatch(path, "[^%.]+") do
		local new_destination = destination:FindFirstChild(s)
		if new_destination == nil then
			error("[Madwork]: Couldn't find file \"" .. s .. "\" inside " .. destination:GetFullName())
		end
		destination = new_destination
	end
	return destination
end

local function LoadService(service_name, service_module)
	local long_load_start = os.clock()
	local long_load_task
	long_load_task = RunService.Heartbeat:Connect(function()
		if os.clock() - long_load_start > SETTINGS.LongLoadWarningTime then
			long_load_task:Disconnect()
			if LastRequiredServiceLog == nil then
				TestService:Message("[Madwork]: \"" .. service_name .. "\" is taking long to load; Require log empty.")
			else
				TestService:Message("[Madwork]: \"" .. service_name .. "\" is taking long to load; Last require: \"" .. LastRequiredServiceLog[1]:GetFullName() .. "\" required \"" .. LastRequiredServiceLog[2] .. "\"")
			end
		end
	end)
	Madwork.Services[service_name] = require(service_module) -- Publicly available service object
	Madwork.LoadingServicesCount = Madwork.LoadingServicesCount - 1
	long_load_task:Disconnect()
end

local function RunOnCloseTasks()
	local tasks_running = 0
	for _, task in ipairs(OnCloseTasks) do
		tasks_running = tasks_running + 1
		coroutine.wrap(function()
			task()
			tasks_running = tasks_running - 1
		end)()
	end
	
	while tasks_running ~= 0 do Heartbeat:Wait() end
	return -- Allow the session to shut down
end

----- Public functions -----

-- Getting:

function Madwork.GetService(service_name) --> service (May yield if the service is still loading)
	LastRequiredServiceLog = {getfenv(0).script, service_name}
	local service = Madwork.Services[service_name]
	if service == nil then
		local get_loading = Madwork.LoadingServices[service_name]
		if get_loading ~= nil then
			return require(get_loading)
		else
			-- Madwork services can't depend on game source or extension services
			-- Extension services can't depend on game source services
			error("[Madwork]: No loaded service with the name \"" .. service_name .. "\"")
		end
	else
		return service
	end
end

function Madwork.GetModule(package_name, path)
	local dir_modules = Madwork.Modules[package_name]
	if dir_modules == nil then
		error("[Madwork]: No loaded package with the name \"" .. package_name .. "\"")
	end
	return ReadFilePath(dir_modules, path)
end

function Madwork.GetShared(package_name, path)
	local dir_shared = Madwork.Shared[package_name]
	if dir_shared == nil then
		error("[Madwork]: No loaded package with the name \"" .. package_name .. "\"")
	end
	return ReadFilePath(dir_shared, path)
end

-- Code package loading:

function Madwork.LoadPackage(package_name, dir_modules, dir_shared)
	if Madwork.Modules[package_name] ~= nil then
		error("[Madwork]: Attempted to load package \"" .. package_name .. "\" more than once")
	end
	Madwork.Modules[package_name] = dir_modules
	Madwork.Shared[package_name] = dir_shared
	if dir_modules == nil then
		error("[Madwork]: Missing \"Modules\" folder for package \"" .. package_name .. "\"")
	end
	if dir_shared == nil then
		error("[Madwork]: Missing \"Shared\" folder for package \"" .. package_name .. "\"")
	end
end

function Madwork.LoadServices(dir_services)
	local load_services = {} -- [service_name] = service_module -- Services for one package
	for _, service_module in ipairs(dir_services:GetChildren()) do
		if service_module:IsA("ModuleScript") == true then
			local service_name = service_module.Name
			if Madwork.LoadingServices[service_name] ~= nil then
				error("[Madwork]: Service with name \"" .. service_name .. "\" already loaded")
			end
			Madwork.LoadingServices[service_name] = service_module
			Madwork.LoadingServicesCount = Madwork.LoadingServicesCount + 1
			load_services[service_name] = service_module
		end
	end
	-- Loading services
	for service_name, service_module in pairs(load_services) do
		coroutine.wrap(LoadService)(service_name, service_module)
	end
end

function Madwork.WaitForServices()
	while Madwork.LoadingServicesCount > 0 do
		Madwork.HeartbeatWait()
	end
end

-- GameTag:

function Madwork.SetGameTag(game_tag)
	if Madwork.GameTag == nil then
		if type(game_tag) ~= "string" then
			error("[Madwork]: game_tag must be a string")
		end
		Madwork.GameTag = game_tag
	else
		error("[Madwork]: GameTag was already set")
	end
end

-- Remote events:

function Madwork.SetupRemoteEvent(remote_name) --> RemoteEvent
	if Madwork.CoreReady == true then
		error("[Madwork]: Set up RemoteEvent \"" .. remote_name .. "\" after CoreReadySignal - RemoteEvents can only be created before CoreReadySignal")
	end
	
	if Madwork.RemoteEvents[remote_name] ~= nil then
		error("[Madwork]: Can't set up RemoteEvent of name \"" .. remote_name .. "\" again")
	else
		local rev_new = Instance.new("RemoteEvent")
		rev_new.Name = remote_name
		Madwork.RemoteEvents[remote_name] = rev_new
		rev_new.Parent = dir_RemoteEvents
		return rev_new
	end
end

-- OnClose:

function Madwork.ConnectToOnClose(task, run_in_studio_mode)
	if type(task) ~= "function" then
		error("[Madwork]: Only functions can be passed to ConnectToOnClose()")
	end
	if IsStudio == false or run_in_studio_mode == true then
		table.insert(OnCloseTasks, task)
	end
end

-- Heartbeat wait:

function Madwork.HeartbeatWait(wait_time) --> time_elapsed
	if wait_time == nil or wait_time == 0 then
		return Heartbeat:Wait()
	else
		local time_elapsed = 0
		while time_elapsed <= wait_time do
			local time_waited = Heartbeat:Wait()
			time_elapsed = time_elapsed + time_waited
		end
		return time_elapsed
	end
end

-- Instance:

function Madwork.Instance(class_name, properties) --> [Instance]
	local instance = Instance.new(class_name)
	local parent = properties.Parent -- Always set parent property last
	for property, value in pairs(properties) do
		if property ~= "Parent" then
			instance[property] = value
		end
	end
	if parent ~= nil then
		instance.Parent = parent
	end
	return instance
end

-- ScriptConnection and ScriptSignal: (Shared.MadworkScriptSignal)
-- function Madwork.NewArrayScriptConnection(listener_table, listener, disconnect_listener, disconnect_param) --> [ScriptConnection]
-- function Madwork.NewScriptSignal() --> [ScriptSignal]

----- Initialize -----

game:BindToClose(RunOnCloseTasks)

Madwork.LoadPackage(SETTINGS.PackageName, dir_Modules, dir_Shared)

MadworkScriptSignal = require(Madwork.GetShared(SETTINGS.PackageName, "MadworkScriptSignal"))
Madwork.NewArrayScriptConnection = MadworkScriptSignal.NewArrayScriptConnection
Madwork.NewScriptSignal = MadworkScriptSignal.NewScriptSignal

Madwork.CoreReadySignal = Madwork.NewScriptSignal()

Madwork.LoadServices(dir_Services)

return Madwork

---***---
end