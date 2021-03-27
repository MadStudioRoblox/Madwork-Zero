local Madwork = _G.Madwork
--[[
{Madwork}

-[ContentController]---------------------------------------
	Standard game content lookup referencing;
	See "Shared.ContentLoader" for more info
	
	Functions:

		ContentController.GetGameContent(game_tag) --> [GameContent]
		ContentController.CheckGameContent(game_tag) --> [GameContent] or nil
		
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

----- Controller Table -----

local ContentController = {
	
	_game_content_objects = {
		--[[
			["game_tag"] = {
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
			}
		--]]
	}

}

----- Loaded Controllers & Modules -----

local ContentLoader = require(Madwork.GetShared("Madwork", "ContentLoader"))

----- Private Variables -----

local GameContentObjects = ContentController._game_content_objects

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicatedGameContent = ReplicatedStorage:FindFirstChild("ReplicatedGameContent")

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

function GameContent:Get(base_category_name, element_type, element_name) --> [table / nil]
	local get_base_category = self[base_category_name]
	if get_base_category == nil then
		error("[ContentController]: Invalid base category \"" .. tostring(base_category_name) .. "\"")
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

-- Controller functions:

function ContentController.GetGameContent(game_tag) --> [GameContent]
	local game_content = GameContentObjects[game_tag]
	if game_content ~= nil then
		return game_content
	else
		error("[ContentController]: Game content for \"" .. tostring(game_tag) .. "\" was not loaded")
	end
end

function ContentController.CheckGameContent(game_tag) --> [GameContent / nil]
	return GameContentObjects[game_tag]
end

----- Initialize -----

for _, root_folder in ipairs(ReplicatedGameContent:GetChildren()) do
	local root_folder_name = root_folder.Name
	if string.sub(root_folder_name, 1, 8) == "Content_" then
		local game_tag = string.sub(root_folder_name, 9)
		local game_content = {
			Collectible = {},
			Progress = {},
			Resources = {},
			Settings = {},
		}
		setmetatable(game_content, GameContent)
		ContentLoader(game_tag, game_content, root_folder, false)
		GameContentObjects[game_tag] = game_content
	end
end

return ContentController