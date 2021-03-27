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

-[CoreController]---------------------------------------
	Game file managing; Globally accessible controller references
	
	Members:
	
		Madwork.GameTag                [string] Game tag of the game running in this server
	
		Madwork.LoadingControllersCount   [number] Number of controllers pending to load
		Madwork.CoreReadySignal           [ScriptSignal] () Fired once when all controllers are loaded and configured
		Madwork.CoreReady                 [bool] Set to true right before GameReadySignal is fired
	
	Functions:
	
		Madwork.GetController(controller_name) --> [Controller]
		Madwork.GetModule(package_name, path) --> [Instance]
		Madwork.GetShared(package_name, path) --> [Instance]
		
		Madwork.SetupRemoteEvent(remote_name) --> [RemoteEvent]
		
		Madwork.LoadPackage(package_name, dir_modules, dir_shared)
		Madwork.LoadControllers(dir_controllers, controller_names)
		Madwork.WaitForControllers() -- Yields until Madwork.LoadingControllersCount reaches 0
		
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

	LoadControllers = { -- Framework controllers to load in "dir_Controllers"
		"ReplicaController",
		"LatencyController",
		"RegionController",
		"CharacterController",
		"PlayerProfileController",
		"ContentController",
		"InputController",
		"CameraController",
	},
	
	LongLoadWarningTime = 5, -- Seconds
	
}

----- Controller Table -----

local Madwork = {

	Controllers = {}, -- ["ControllerName"] = controller
	Modules = {}, -- ["PackageName"] = dir_Modules
	Shared = {}, -- ["PackageName"] = dir_Shared
	
	LoadingControllers = {}, -- ["ControllerName"] = controller_module (Controllers that are loaded or are going to be loaded)
	RequiredControllers = {}, -- ["ControllerName"] = {controller_name, ...}
	LoadingControllersCount = 0, -- Number of controllers that haven't finished loading
	
	RemoteEvents = {}, -- ["RemoteEventName"] = RemoteEvent
	
	-- CoreReadySignal = Madwork.NewScriptSignal(), -- Fired once when all controllers are loaded and configured
	CoreReady = false, -- Set to true right before GameReadySignal is fired
	
}
_G.Madwork = Madwork

----- Private Variables -----

local TestService = game:GetService("TestService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Heartbeat = RunService.Heartbeat

local dir_Client = dir_Madwork:WaitForChild("Client")
	local dir_Controllers = dir_Client:WaitForChild("Controllers")
	local dir_Modules = dir_Client:WaitForChild("Modules")

local dir_Shared = dir_Madwork:WaitForChild("Shared")

local dir_GameData = ReplicatedStorage:WaitForChild("GameData")
	Madwork.GameData = dir_GameData -- Reference in framework global
	
local dir_RemoteEvents = dir_GameData:WaitForChild("RemoteEvents")

local MadworkScriptSignal

local LastRequiredControllerLog -- {module, controller_name}

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

local function LoadController(controller_name, controller_module)
	local long_load_start = os.clock()
	local long_load_task
	long_load_task = RunService.Heartbeat:Connect(function()
		if os.clock() - long_load_start > SETTINGS.LongLoadWarningTime then
			long_load_task:Disconnect()
			if LastRequiredControllerLog == nil then
				TestService:Message("[Madwork]: \"" .. controller_name .. "\" is taking long to load; Require log empty.")
			else
				TestService:Message("[Madwork]: \"" .. controller_name .. "\" is taking long to load; Last require: \"" .. LastRequiredControllerLog[1]:GetFullName() .. "\" required \"" .. LastRequiredControllerLog[2] .. "\"")
			end
		end
	end)
	Madwork.Controllers[controller_name] = require(controller_module) -- Publicly available controller object
	Madwork.LoadingControllersCount = Madwork.LoadingControllersCount - 1
	long_load_task:Disconnect()
end

----- Public functions -----

-- Getting:

function Madwork.GetController(controller_name) --> controller (May yield if the controller is still loading)
	LastRequiredControllerLog = {getfenv(0).script, controller_name}
	local controller = Madwork.Controllers[controller_name]
	if controller == nil then
		local get_loading = Madwork.LoadingControllers[controller_name]
		if get_loading ~= nil then
			return require(get_loading)
		else
			-- Madwork controllers can't depend on game source or extension controllers
			-- Extension controllers can't depend on game source controllers
			error("[Madwork]: No loaded controller with the name \"" .. controller_name .. "\"")
		end
	else
		return controller
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

function Madwork.LoadControllers(dir_controllers)
	local load_controllers = {} -- [controller_name] = controller_module -- Controllers for one package
	for _, controller_module in ipairs(dir_controllers:GetChildren()) do
		if controller_module:IsA("ModuleScript") == true then
			local controller_name = controller_module.Name
			if Madwork.LoadingControllers[controller_name] ~= nil then
				error("[Madwork]: Controller with name \"" .. controller_name .. "\" already loaded")
			end
			Madwork.LoadingControllers[controller_name] = controller_module
			Madwork.LoadingControllersCount = Madwork.LoadingControllersCount + 1
			load_controllers[controller_name] = controller_module
		end
	end
	-- Loading controllers
	for controller_name, controller_module in pairs(load_controllers) do
		coroutine.wrap(LoadController)(controller_name, controller_module)
	end
end

function Madwork.WaitForControllers()
	while Madwork.LoadingControllersCount > 0 do
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

for _, rev in ipairs(dir_RemoteEvents:GetChildren()) do -- Referencing RemoteEvents in a table
	Madwork.RemoteEvents[rev.Name] = rev
end

function Madwork.SetupRemoteEvent(remote_name) --> RemoteEvent
	local get_rev = Madwork.RemoteEvents[remote_name]
	if get_rev ~= nil then
		return get_rev
	else
		error("[Madwork]: RemoteEvent of name \"" .. remote_name .. "\" was not found")
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

Madwork.LoadPackage(SETTINGS.PackageName, dir_Modules, dir_Shared)

MadworkScriptSignal = require(Madwork.GetShared(SETTINGS.PackageName, "MadworkScriptSignal"))
Madwork.NewArrayScriptConnection = MadworkScriptSignal.NewArrayScriptConnection
Madwork.NewScriptSignal = MadworkScriptSignal.NewScriptSignal

Madwork.CoreReadySignal = Madwork.NewScriptSignal()

Madwork.LoadControllers(dir_Controllers)

return Madwork
	
---***---
end