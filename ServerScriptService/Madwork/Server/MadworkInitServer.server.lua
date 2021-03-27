--[[
{Madwork}

-[MadworkInitServer]---------------------------------------
	Initializes Madwork, optional game extension and game source server-side
	
	Execution order:
		0) Detect and check all code and content packages in ServerScriptStorage and ReplicatedStorage respectively
		1) Load Madwork core
		2) Move MadworkInitClient and Game.Client.Modules.ReplicatedFirst (optional) to ReplicatedFirst
		3) Load content packages
		4) Load extension code package (optional)
		5) Load game code package
		6) Madwork.CoreReadySignal
	
	Dependancies will not operate correctly for packages depending on other packages prioritized lower in framework execution;
		A dependancy exception exists for content package modules if they are chain-required later in the execution order
--]]

local SETTINGS = {
	MadworkCodePackageTypes = {"Madwork", "Extension", "Game"},
	ContentElementFolders = {"Collectible", "Progress", "Resources", "Settings"},
}

----- Private Variables -----

local Madwork

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local CodePackages = {} -- [PackageType] = package_data
local ContentPackages = {} -- [GameTag] = package_data

----- Private functions -----

local function GetMadworkCodePackageData(package) --> package_data [table], package_error [string] or nil
	
	local package_data = { -- package_data return table
		Dir = package,
		
		Client = nil,
		Controllers = nil,
		ClientModules = nil,
		ConfigClient = nil,
		
		Server = nil,
		Services = nil,
		ServerModules = nil,
		ConfigServer = nil,
		
		Shared = nil,
		
		MadworkPackageType = package:GetAttribute("MadworkPackageType"),
		PackageName = package:GetAttribute("PackageName"),
		GameTag = package:GetAttribute("GameTag"),
	}
	
	-- Testing attributes:
	
	if table.find(SETTINGS.MadworkCodePackageTypes, package_data.MadworkPackageType) == nil then
		if package_data.MadworkPackageType == "Content" then
			return package_data, string.format(
				"\"Content\" type package with GameTag \"%s\" should be a child of ReplicatedStorage",
				tostring(package_data.GameTag)
			)
		else
			return package_data, string.format(
				"Invalid \"MadworkPackageType\" attribute (\"%s\"); Expected one of the following: %s",
				tostring(package_data.MadworkPackageType),
				table.concat(SETTINGS.MadworkCodePackageTypes, ", ")
			)
		end
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
	
	for _, top_dir_name in ipairs({"Client", "Server", "Shared"}) do
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
	
	package_data.Services = package.Server:FindFirstChild("Services")
	package_data.ServerModules = package.Server:FindFirstChild("Modules")
	package_data.ConfigServer = package.Server:FindFirstChild("MadworkConfigServer")
	
	if package_data.Controllers == nil then
		return package_data, "Folder \"Client.Controllers\" was not found"
	elseif package_data.ClientModules == nil then
		return package_data, "Folder \"Client.Modules\" was not found"
	elseif package_data.Services == nil then
		return package_data, "Folder \"Server.Services\" was not found"
	elseif package_data.ServerModules == nil then
		return package_data, "Folder \"Server.Modules\" was not found"
	elseif package_data.ConfigClient == nil and package_data.MadworkPackageType ~= "Madwork" then
		return package_data, "ModuleScript \"Client.MadworkConfigClient\" was not found"
	elseif package_data.ConfigServer == nil and package_data.MadworkPackageType ~= "Madwork" then
		return package_data, "ModuleScript \"Server.MadworkConfigServer\" was not found"
	end

	return package_data, nil
end

local function GetMadworkContentPackageData(package) --> package_data [table], package_error [string] or nil
	local package_data = { -- package_data return table
		Dir = package,
		
		MadworkPackageType = package:GetAttribute("MadworkPackageType"),
		GameTag = package:GetAttribute("GameTag"),
	}
	
	-- Testing attributes:

	if package_data.MadworkPackageType ~= "Content" then
		if table.find(SETTINGS.MadworkCodePackageTypes, package_data.MadworkPackageType) ~= nil then
			return package_data, string.format(
				"\"%s\" type package with GameTag \"%s\" should be a child of ServerScriptService",
				tostring(package_data.MadworkPackageType),
				tostring(package_data.GameTag)
			)
		else
			return package_data, string.format(
				"Invalid \"MadworkPackageType\" attribute (\"%s\"); Expected \"Content\"",
				tostring(package_data.MadworkPackageType)
			)
		end
	elseif type(package_data.GameTag) ~= "string" or string.len(package_data.GameTag) == 0 then
		if package_data.GameTag == nil then
			return package_data, "Missing \"GameTag\" attribute"
		else
			return package_data, string.format("Invalid \"GameTag\" attribute (\"%s\")", tostring(package_data.GameTag))
		end
	end
	
	for _, folder_name in ipairs(SETTINGS.ContentElementFolders) do
		if package:FindFirstChild(folder_name) == nil then
			return package_data, string.format("Missing element folder \"%s\"", folder_name)
		end
	end
	
	return package_data, nil
end

local function CopyAttributes(template, target)
	for name, value in pairs(template:GetAttributes()) do
		target:SetAttribute(name, value)
	end
end

local function CreateClientScriptPackage(package_data) --> package_folder [Instance]
	local replicated_dir = Instance.new("Folder")
	replicated_dir.Name = package_data.Dir.Name
	CopyAttributes(package_data.Dir, replicated_dir)
	
	local client_dir = package_data.Client
	client_dir.Parent = replicated_dir
	
	local shared_dir = package_data.Shared
	shared_dir.Parent = replicated_dir
	
	replicated_dir.Parent = ReplicatedStorage
	
	return replicated_dir
end

----- Initialize -----

-- Code packages:

for _, package in ipairs(ServerScriptService:GetChildren()) do
	local is_madwork_package = package:GetAttribute("MadworkPackageType") ~= nil
	if is_madwork_package == true then
		local package_data, package_error = GetMadworkCodePackageData(package)
		if package_error ~= nil then
			error(string.format("[Madwork]: Package error for ServerScriptService.%s: %s", package.Name, package_error))
		elseif CodePackages[package_data.MadworkPackageType] ~= nil then
			error(string.format("[Madwork]: Duplicate code package type \"%s\" found in ServerScriptService", package_data.MadworkPackageType))
		end
		CodePackages[package_data.MadworkPackageType] = package_data
	end
end

if CodePackages.Madwork == nil then
	error("[Madwork]: \"Madwork\" package was not found - Are MadworkPackageType attributes set properly?")
elseif CodePackages.Game == nil then
	error("[Madwork]: \"Game\" package was not found - Are MadworkPackageType attributes set properly?")
end

-- Content packages:

for _, package in ipairs(ReplicatedStorage:GetChildren()) do
	local is_madwork_package = package:GetAttribute("MadworkPackageType") ~= nil
	if is_madwork_package == true then
		local package_data, package_error = GetMadworkContentPackageData(package)
		if package_error ~= nil then
			error(string.format("[Madwork]: Package error for ReplicatedStorage.%s: %s", package.Name, package_error))
		elseif ContentPackages[package_data.GameTag] ~= nil then
			error(string.format("[Madwork]: Duplicate content package for GameTag \"%s\" found in ServerScriptService", package_data.GameTag))
		end
		ContentPackages[package_data.GameTag] = package_data
	end
end

if ContentPackages[CodePackages.Game.GameTag] == nil then
	warn(string.format("[Madwork]: Missing content package with a matching GameTag \"%s\" to the Game code package", CodePackages.Game.GameTag))
end

do
	
	local package_type_list = ""
	for package_type in pairs(CodePackages) do
		package_type_list ..= (package_type_list ~= "" and ", " or "") .. package_type
	end
	
	print("[Madwork]: Initializing with packages: " .. package_type_list)
	
	-- Loading core:
	
	local core_module = CodePackages.Madwork.Services:FindFirstChild("CoreService")
	if core_module == nil then
		error("[Madwork]: Missing \"Madwork.Server.Services.CoreService\"")
	end
	
	Madwork = require(core_module)(CodePackages.Madwork.Dir)
	local madwork_replicated = CreateClientScriptPackage(CodePackages.Madwork)
	
	-- ReplicatedFirst:
	
	local replicated_first_dir = CodePackages.Game.ClientModules:FindFirstChild("ReplicatedFirst")
	if replicated_first_dir ~= nil then
		
		-- Check if the folder wasn't left in ReplicatedFirst by accident:
		local check_dir = ReplicatedFirst:FindFirstChild("ReplicatedFirst")
		if check_dir ~= nil then
			warn("[Madwork]: Found \"ReplicatedFirst\" directory in DataModel.ReplicatedFirst before initialization; Removing...")
			for _, instance in ipairs(ReplicatedFirst:GetChildren()) do
				if instance.Name == "ReplicatedFirst" then
					instance:Destroy()
				end
			end
		end
		
		local module_one = replicated_first_dir:FindFirstChild("ModuleOne")
		if module_one == nil then
			error(string.format("[Madwork]: \"%s.Client.Modules.ReplicatedFirst\" must contain ModuleScript \"ModuleOne\"", CodePackages.Game.Dir.Name))
		end
		replicated_first_dir.Parent = ReplicatedFirst
	end
	
	local madwork_init_client = madwork_replicated:FindFirstChild("Client"):FindFirstChild("MadworkInitClient")
	if madwork_init_client == nil then
		error("[Madwork]: Missing \"Madwork.Client.MadworkInitClient\"")
	end
	
	madwork_init_client.Parent = ReplicatedFirst
	
	-- Setting game tag:
	
	Madwork.SetGameTag(CodePackages.Game.GameTag)
	
	-- Loading content packages:
	
	for game_tag, package_data in pairs(ContentPackages) do
		Madwork.GetService("ContentService").LoadGameContent(game_tag, package_data.Dir)
	end
	
	-- Loading extension code package (if present):
	
	if CodePackages.Extension ~= nil then
		Madwork.WaitForServices()
		
		local extension_data = CodePackages.Extension
		print(string.format("[Madwork]: Loading extension code package \"%s\"", extension_data.PackageName))
		
		Madwork.LoadPackage(extension_data.PackageName, extension_data.ServerModules, extension_data.Shared)
		require(extension_data.ConfigServer)
		Madwork.LoadServices(extension_data.Services)
		CreateClientScriptPackage(extension_data)
	end
	
	-- Loading game code package:
	
	Madwork.WaitForServices()

	local game_data = CodePackages.Game
	print(string.format("[Madwork]: Loading game code package \"%s\"", game_data.PackageName))

	Madwork.LoadPackage(game_data.PackageName, game_data.ServerModules, game_data.Shared)
	require(game_data.ConfigServer)
	Madwork.LoadServices(game_data.Services)
	CreateClientScriptPackage(game_data)
	
	-- Informing clients that all packages have been replicated:
	
	Madwork.WaitForServices()
	
	local replication_flag = Instance.new("BoolValue")
	replication_flag.Name = "_MadworkReplicated"
	replication_flag.Parent = ReplicatedStorage
	
	-- Core ready signal:
	
	Madwork.CoreReady = true
	Madwork.CoreReadySignal:Fire()
	
	print("[Madwork]: SERVER LOADED!")
	
end