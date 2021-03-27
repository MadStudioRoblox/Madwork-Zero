--[[
{Madwork}

-[MadworkInitClient]---------------------------------------
	Initializes Madwork, optional game extension and game source client-side
	
	Execution order:
		0) Detect and check all code packages in ServerScriptStorage and ReplicatedStorage respectively
		1) Load Madwork core (content packages will be loaded by Madwork core)
		2) Load extension code package (optional)
		3) Load game code package
		4) Madwork.CoreReadySignal
		5) ReplicaController.RequestData()
	
	Dependancies will not operate correctly for packages depending on other packages prioritized lower in framework execution;
		A dependancy exception exists for content package modules if they are chain-required later in the execution order
	
--]]

local SETTINGS = {
	MadworkCodePackageTypes = {"Madwork", "Extension", "Game"},
}

----- Private Variables -----

local Madwork
local ReplicaController

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

local ReplicatedFirstDir = ReplicatedFirst:FindFirstChild("ReplicatedFirst")

local CodePackages = {} -- [PackageType] = package_data

----- Private functions -----

local function GetMadworkCodePackageData(package) --> package_data [table], package_error [string] or nil
	local package_data = { -- package_data return table
		Dir = package,

		Client = nil,
		Controllers = nil,
		ClientModules = nil,
		ConfigClient = nil,

		Shared = nil,

		MadworkPackageType = package:GetAttribute("MadworkPackageType"),
		PackageName = package:GetAttribute("PackageName"),
		GameTag = package:GetAttribute("GameTag"),
	}
	
	-- Testing attributes:
	
	if table.find(SETTINGS.MadworkCodePackageTypes, package_data.MadworkPackageType) == nil then
		return package_data, string.format(
			"Invalid \"MadworkPackageType\" attribute (\"%s\"); Expected one of the following: %s",
			tostring(package_data.MadworkPackageType),
			table.concat(SETTINGS.MadworkCodePackageTypes, ", ")
		)
	elseif type(package_data.PackageName) ~= "string" or string.len(package_data.PackageName) == 0 then
		return package_data, string.format("Invalid \"PackageName\" attribute (\"%s\")", tostring(package_data.PackageName))
	elseif package_data.MadworkPackageType == "Game" and (type(package_data.GameTag) ~= "string" or string.len(package_data.GameTag) == 0) then
		if package_data.GameTag == nil then
			return package_data, "Missing \"GameTag\" attribute"
		else
			return package_data, string.format("Invalid \"GameTag\" attribute (\"%s\")", tostring(package_data.GameTag))
		end
	end

	-- Top directories:
	
	for _, top_dir_name in ipairs({"Client", "Shared"}) do
		local dir = package:FindFirstChild(top_dir_name)
		package_data[top_dir_name] = dir
		if dir == nil then
			return package_data, string.format("Folder \"%s\" was not found", top_dir_name)
		end
	end

	-- Nested directories:
	
	package_data.Controllers = package.Client:FindFirstChild("Controllers")
	package_data.ClientModules = package.Client:FindFirstChild("Modules")
	package_data.ConfigClient = package.Client:FindFirstChild("MadworkConfigClient")

	if package_data.Controllers == nil then
		return package_data, "Folder \"Client.Controllers\" was not found"
	elseif package_data.ClientModules == nil then
		return package_data, "Folder \"Client.Modules\" was not found"
	end

	return package_data, nil
end

----- Initialize -----

do
	
	-- ModuleOne:
	
	local module_one
	if ReplicatedFirstDir ~= nil then
		module_one = require(ReplicatedFirstDir:FindFirstChild("ModuleOne"))
	end
	
	-- Waiting for game to fully load so we wouldn't have to use :WaitForChild() in our codebase:
	
	ReplicatedStorage:WaitForChild("_MadworkReplicated") -- Server creates this instance after unpacking everything
	
	while game:IsLoaded() == false do
		RunService.Heartbeat:Wait()
	end
	
	-- Collecting code packages:

	for _, package in ipairs(ReplicatedStorage:GetChildren()) do
		local is_madwork_package = package:GetAttribute("MadworkPackageType") ~= nil
		if is_madwork_package == true then
			local package_data, package_error = GetMadworkCodePackageData(package)
			if package_error ~= nil then
				error(string.format("[Madwork]: Package error for ReplicatedStorage.%s: %s", package.Name, package_error))
			elseif CodePackages[package_data.MadworkPackageType] ~= nil then
				error(string.format("[Madwork]: Duplicate code package type \"%s\" found in ReplicatedStorage", package_data.MadworkPackageType))
			end
			CodePackages[package_data.MadworkPackageType] = package_data
		end
	end
	
	-- Loading core:

	local core_module = CodePackages.Madwork.Controllers:FindFirstChild("CoreController")
	if core_module == nil then
		error("[Madwork]: Missing \"Madwork.Client.Controllers.CoreController\"")
	end

	Madwork = require(core_module)(CodePackages.Madwork.Dir)
	
	-- Setting game tag:

	Madwork.SetGameTag(CodePackages.Game.GameTag)
	
	-- Loading extension code package (if present):

	if CodePackages.Extension ~= nil then
		Madwork.WaitForControllers()

		local extension_data = CodePackages.Extension
		print(string.format("[Madwork]: Loading extension code package \"%s\"", extension_data.PackageName))

		Madwork.LoadPackage(extension_data.PackageName, extension_data.ClientModules, extension_data.Shared)
		require(extension_data.ConfigClient)
		Madwork.LoadControllers(extension_data.Controllers)
	end
	
	-- Loading game code package:

	Madwork.WaitForControllers()

	local game_data = CodePackages.Game
	print(string.format("[Madwork]: Loading game code package \"%s\"", game_data.PackageName))

	Madwork.LoadPackage(game_data.PackageName, game_data.ClientModules, game_data.Shared)
	
	if ReplicatedFirstDir ~= nil then
		-- Injecting "ReplicatedFirst" directory into namespace if it was defined:
		ReplicatedFirstDir.Parent = game_data.ClientModules
	end
	
	require(game_data.ConfigClient)
	Madwork.LoadControllers(game_data.Controllers)
	
	-- Core ready signal:
	
	Madwork.WaitForControllers()
	
	if module_one ~= nil then
		module_one.CoreReady(Madwork)
	end

	Madwork.CoreReady = true
	Madwork.CoreReadySignal:Fire()
	
	-- Requesting data for ReplicaController:
	
	ReplicaController = Madwork.GetController("ReplicaController")
	ReplicaController.RequestData()
	
	print("[Madwork]: CLIENT LOADED!")

end