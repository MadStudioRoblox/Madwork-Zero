local Madwork = _G.Madwork
--[[
{Madwork}

-[ContentService]---------------------------------------
	Standard game content lookup referencing;
	WARNING: Content can only be loaded before CoreReadySignal
	See "Shared.ContentLoader" for more info
	
	Functions:

		ContentService.LoadGameContent(game_tag, root_folder) -- Also moves root_folder to a replicated container
		ContentService.GetGameContent(game_tag) --> [GameContent]
		
	Members [GameContent]:
	
		GameContent.Collectible   [table] ["ElementType"]["ElementName"] = element_data
		GameContent.Progress      [table] ["ElementType"]["ElementName"] = element_data
		GameContent.Resources     [table] ["ElementType"]["ElementName"] = element_data
		GameContent.Settings      [table] ["SettingsModuleName"] = module_script
	
	Methods [GameContent]:
	
		GameContent:GetData(base_category, element_type, element_name) --> [table] or nil (returns ContentElement.Data)
		GameContent:GetElement(base_category, element_type, element_name) --> [ContentElement] or nil
		
		GameContent:GetSettings(settings_name) --> [ModuleScript] or nil
		
	Members [ContentElement]:
	
		ContentElement.Data           [table]
		
		ContentElement.BaseCategory   [string]
		ContentElement.Type           [string]
		ContentElement.Name           [string]
		
		ContentElement.GameContent    [GameContent]
	
	Methods [ContentElement]:
	
		ContentElement:GetFile(file_name) --> [Instance] / [ContentElement] -- WARNING: Will error if file is not found
		ContentElement:CheckFile(file_name) --> [Instance] / [ContentElement] / nil -- Same as :GetFile(), but will not error if file is not found
		
		ContentElement:GetFullName() --> [string] -- For debug purposes
	
--]]

local SETTINGS = {
	
}

----- Service Table -----

local ContentService = {
	
	_game_content_objects = {
		--[[
			["game_tag"] = {
				Collectible = { -- "Progress" and "Resources" follow the same structure
					["ElementType"] = {
						["ElementName"] = element_data,
						...
					},
					...
				},
				Progress = {},
				Resources = {},
				Settings = {
					["SettingsModuleName"] = module_script,
					...
				},
			}
		--]]
	}

}

----- Loaded Services & Modules -----

local ContentLoader = require(Madwork.GetShared("Madwork", "ContentLoader"))

----- Private Variables -----

local GameContentObjects = ContentService._game_content_objects

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicatedGameContent -- [Folder]

----- Public functions -----

-- ContentElement object: --
local ContentElement = {
	--[[
		Data = data_table,
		
		BaseCategory = base_category,
		Type = element_type,
		Name = element_name,
		
		GameContent = game_content,
	--]]
}
ContentElement.__index = ContentElement

function ContentElement:GetFile(file_name) --> [Instance] / [ContentElement]
	if type(file_name) ~= "string" then
		error("[ContentService]: file_name must be a string")
	end
	local get_file = self.Data.File
	if get_file == nil then
		error("[ContentService]: \"File\" table not declared in element data (" .. self.BaseCategory .. "." .. self.Type .. "." .. self.Name .. ")")
	else
		get_file = get_file[file_name]
		if get_file == nil then
			error("[ContentService]: File name (\"" .. file_name .. "\") not declared in element data file table (" .. self.BaseCategory .. "." .. self.Type .. "." .. self.Name .. ")")
		elseif get_file == "NotReplicated" then
			error("[ContentService]: File \"" .. file_name .. "\" is marked as not replicated (" .. self.BaseCategory .. "." .. self.Type .. "." .. self.Name .. ")")
		elseif type(get_file) == "table" then
			return self.GameContent:GetElement(get_file[1], get_file[2], get_file[3])
		else
			return get_file
		end
	end
end

function ContentElement:CheckFile(file_name) --> [Instance] / [ContentElement]
	if type(file_name) ~= "string" then
		error("[ContentService]: file_name must be a string")
	end
	local get_file = self.Data.File
	if get_file ~= nil then
		get_file = get_file[file_name]
		if get_file == "NotReplicated" or get_file == nil then
			return nil
		elseif type(get_file) == "table" then
			return self.GameContent:GetElement(get_file[1], get_file[2], get_file[3])
		else
			return get_file
		end
	end
	return nil
end

function ContentElement:GetFullName() --> [string]
	return self.BaseCategory .. "." .. self.Type .. "." .. self.Name
end

-- GameContent object:
local GameContent = {
	--[[
		Collectible = { -- "Progress" and "Resources" follows the same structure
			["ElementType"] = {
				["ElementName"] = element_data,
				...
			},
			...
		},
		Progress = {},
		Resources = {},
		Settings = {
			["SettingsModuleName"] = module_script,
			...
		},
	--]]
}
GameContent.__index = GameContent

function GameContent:Get(base_category, element_type, element_name) --> [table / nil]
	local get_base_category = self[base_category]
	if get_base_category == nil then
		error("[ContentService]: Invalid base category \"" .. tostring(base_category) .. "\"")
	end
	local get_element_type = get_base_category[element_type]
	if get_element_type ~= nil then
		return get_element_type[element_name]
	end
	return nil
end

function GameContent:GetElement(base_category, element_type, element_name) --> [ContentElement]
	local get_base_category = self[base_category]
	if get_base_category == nil then
		error("[ContentService]: Invalid base category \"" .. tostring(base_category) .. "\"")
	end
	local get_element_type = get_base_category[element_type]
	if get_element_type ~= nil then
		local element_data = get_element_type[element_name]
		if element_data ~= nil then
			local content_element = {
				Data = element_data,
				
				BaseCategory = base_category,
				Type = element_type,
				Name = element_name,
				
				GameContent = self,
			}
			setmetatable(content_element, ContentElement)
			return content_element
		end
	end
	return nil
end

function GameContent:GetSettings(settings_name) --> [ModuleScript / nil]
	return self.Settings[settings_name]
end

-- Service functions:

function ContentService.LoadGameContent(game_tag, root_folder)
	if type(game_tag) ~= "string" then
		error("[ContentService]: Invalid game_tag parameter")
	else
		if string.len(game_tag) <= 0 then
			error("[ContentService]: Invalid game_tag parameter")
		end
	end
	if GameContentObjects[game_tag] ~= nil then
		error("[ContentService]: Game content for \"" .. game_tag .. "\" is already loaded")
	end
	if root_folder.ClassName ~= "Folder" then
		-- This can help in cases where you load content with InsertService and forget that loaded instances can be stored inside a Model
		error("[ContentService]: Game content root folder must be a \"Folder\" Instance (not \"" .. root_folder.ClassName .. "\")")
	end
	if Madwork.CoreReady == true then
		error("[ContentService]: Game content can only be loaded before CoreReadySignal")
	end
	local game_content = {
		Collectible = {},
		Progress = {},
		Resources = {},
		Settings = {},
	}
	setmetatable(game_content, GameContent)
	ContentLoader(game_tag, game_content, root_folder, true)
	root_folder.Name = "Content_" .. game_tag
	root_folder.Parent = ReplicatedGameContent
	GameContentObjects[game_tag] = game_content
end

function ContentService.GetGameContent(game_tag) --> [GameContent]
	local game_content = GameContentObjects[game_tag]
	if game_content ~= nil then
		return game_content
	else
		error("[ContentService]: Game content for \"" .. tostring(game_tag) .. "\" was not loaded")
	end
end

----- Initialize -----

ReplicatedGameContent = Instance.new("Folder")
ReplicatedGameContent.Name = "ReplicatedGameContent"
ReplicatedGameContent.Parent = ReplicatedStorage

return ContentService