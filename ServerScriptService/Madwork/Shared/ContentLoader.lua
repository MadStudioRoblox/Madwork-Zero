--[[
{Madwork}

-[ContentLoader]---------------------------------------
	Creates a reference table by scanning a content folder;

	Hardcoded content loading tree structure:
	
		[ROOT][Folder] "Content_game_tag"
			- [Folder] "Collectible" or "Progress" or "Resources" (Base category)
				- [Folder] "ElementType" (e.g. "Knife", "Gun", "Clothing") (Element type)
					- [Folder] "Element" (e.g. "DearestGratitude", "SkullCrusher") (Element)
						- [ModuleScript] "ElementTypeData" (Element module) -- (MUST BE NAMED "ElementType" + "Data")
			- [Folder] "Settings"
				- [ModuleScript] "ElementSettingsModule" (e.g. "KnifeUnlockSettings", "GunPricingSettings")
		
	"Collectible", "Progress" and "Resources" have same directory rules;
	Nodes inside the base category branches can be grouped with "Model" instances;
	The following example would be a valid structure:
		
		[ROOT][Folder] "Content_TMM3"
			- [Folder] "Collectible"
				- [Model] "PrimaryWeapons"
					- [Folder] "Knife"
						- [Folder] "StockKnife"
							- [ModuleScript] "KnifeData"
						- [Model] "Premium"
							- [Folder] "Ruby"
								- [ModuleScript] "KnifeData"
							- [Folder] "Carbon"
								- [ModuleScript] "KnifeData"
			- [Folder] "Progress" (You can have the content base category empty)
			- [Folder] "Resources"
				- [Folder] "Map"
					- [Model] "FFA_Maps"
						- [Folder] "Factory"
							- [ModuleScript] "MapData"
					- [Model] "Mystery_Maps"
						- [Folder] "Hotel"
							- [ModuleScript] "MapData"
			- [Folder] "Settings"
				- [ModuleScript] "PricingSettings"
				- [Model] "UnlockSettings"
					- [ModuleScript] "KnifeUnlockSettings"
					- [ModuleScript] "GunUnlockSettings"
	
--]]

local SETTINGS = {
	
	BaseElementCategories = {
		"Collectible", -- Data of elements (items) that are or can become tradable
		"Progress", -- Data of elements (items) that will remain locked to individual players
		"Resources", -- Various game data ranging from weapon behaviour scripts to game maps
	},
	
	SettingsCategory = "Settings", -- Storage of element-specific configuration data

}

----- Private Variables -----

local sett_BaseElementCategories = SETTINGS.BaseElementCategories
local sett_SettingsCategory = SETTINGS.SettingsCategory

----- Private functions -----

local function FilePathToArray(path) --> [table]
	local result = {}
	for s in string.gmatch(path, "[^%.]+") do
		table.insert(result, s)
	end
	return result
end

local function FilePathError(error_type, file_name, file_path, element_name, element_type_name, base_category_name, game_tag)
	error("[ContentLoader]: " .. error_type .. " (\"" .. tostring(file_name) .. "\", \"" .. tostring(file_path) .. "\") for element \"" .. element_name .. "\" in element type \"" .. element_type_name .. "\" in base category \"" .. base_category_name .. "\" (" .. game_tag .. ")")
end

----- Public functions -----

local function ContentLoader(game_tag, game_content, root_folder, is_server)
	local element_container_reference = {} -- ["base_category"]["element_type"]["element_name"]
	for _, base_category_name in ipairs(sett_BaseElementCategories) do
		element_container_reference[base_category_name] = {}
		local base_category = root_folder:FindFirstChild(base_category_name)
		if base_category ~= nil then
			if base_category.ClassName ~= "Folder" then
				error("[ContentLoader]: Base categroy container \"" .. base_category_name .. "\" must be a \"Folder\" Instance (not \"" .. base_category.ClassName .. "\")")
			end
			-- Fetching element type containers:
			local element_types = {} -- ["element_type_name"] = element_type
			local scan_queue = base_category:GetChildren()
			while #scan_queue > 0 do
				local scan = table.remove(scan_queue, 1)
				if scan.ClassName == "Folder" then
					local element_type_name = scan.Name
					if element_types[element_type_name] ~= nil then
						error("[ContentLoader]: Duplicate element type container \"" .. element_type_name .. "\" in base category \"" .. base_category_name .. "\" (" .. game_tag .. ")")
					else
						element_types[element_type_name] = scan
					end
				else
					for _, obj in ipairs(scan:GetChildren()) do
						table.insert(scan_queue, obj)
					end
				end
			end
			-- Fetching elements:
			for element_type_name, element_type in pairs(element_types) do
				local container_reference = {}
				element_container_reference[base_category_name][element_type_name] = container_reference
				local module_name = element_type_name .. "Data"
				local elements = {} -- ["element_name"] = element_data
				game_content[base_category_name][element_type_name] = elements
				local scan_queue = element_type:GetChildren()
				while #scan_queue > 0 do
					local scan = table.remove(scan_queue, 1)
					if scan.ClassName == "Folder" then
						local element_name = scan.Name
						if elements[element_name] ~= nil then
							error("[ContentLoader]: Duplicate element \"" .. element_name .. "\" in element type \"" .. element_type_name .. "\" in base category \"" .. base_category_name .. "\" (" .. game_tag .. ")")
						else
							local element_module = scan:FindFirstChild(module_name)
							if element_module == nil then
								error("[ContentLoader]: \"" .. root_folder.Name .. "." .. base_category_name .. "." .. element_type_name .. "." .. element_name .. "\" must contain a ModuleScript named \"" .. module_name .. "\"")
							end
							elements[element_name] = require(element_module)
							container_reference[element_name] = scan
						end
					else
						for _, obj in ipairs(scan:GetChildren()) do
							table.insert(scan_queue, obj)
						end
					end
				end
			end
		end
	end
	local settings_container = root_folder:FindFirstChild(sett_SettingsCategory)
	if settings_container ~= nil then
		if settings_container.ClassName ~= "Folder" then
			error("[ContentLoader]: \"Settings\" container must be a \"Folder\" Instance (" .. settings_container.ClassName .. ")")
		end
		-- Fetching settings modules:
		local settings_table = game_content.Settings -- ["settings_name"] = module_script
		local scan_queue = settings_container:GetChildren()
		while #scan_queue > 0 do
			local scan = table.remove(scan_queue, 1)
			if scan.ClassName == "ModuleScript" then
				local settings_name = scan.Name
				if settings_table[settings_name] ~= nil then
					error("[ContentLoader]: Duplicate settings module \"" .. settings_name .. "\" in \"Settings\" (" .. game_tag .. ")")
				else
					settings_table[settings_name] = scan
				end
			else
				for _, obj in ipairs(scan:GetChildren()) do
					table.insert(scan_queue, obj)
				end
			end
		end
	end
	-- Loading file references: -- local element_container_reference = {} -- ["base_category"]["element_type"]["element_name"]
	for base_category_name, base_category in pairs(element_container_reference) do
		for element_type_name, element_type in pairs(base_category) do
			for element_name, element_container in pairs(element_type) do
				local element_files = game_content[base_category_name][element_type_name][element_name]["File"]
				if type(element_files) == "table" then
					for file_name, file_path in pairs(element_files) do
						if type(file_name) == "string" and type(file_path) == "string" then
							
							local file_tables_stack = {{element_files, file_name}} --{{element_files, file_name}, ...}
							
							local top_file_name = file_name
							local top_file_path = file_path
							local top_file_path_array = FilePathToArray(file_path)
							
							local top_element_container = element_container
							local top_element_name = element_name
							local top_element_type_name = element_type_name
							local top_base_category_name = base_category_name
							
							local result_file = nil
							
							while true do
								local top_file_path_array_length = #top_file_path_array
								if top_file_path_array_length == 0 then
									FilePathError("Empty file path", top_file_name, top_file_path, top_element_name, top_element_type_name, top_base_category_name, game_tag)
								elseif top_file_path_array_length == 1 then
									local local_file = top_element_container:FindFirstChild(top_file_path_array[1])
									if local_file ~= nil then
										result_file = local_file
										break
									else
										if is_server == true then
											FilePathError("Missing local file", top_file_name, top_file_path, top_element_name, top_element_type_name, top_base_category_name, game_tag)
										else
											result_file = "NotReplicated"
											break
										end
									end
								elseif top_file_path_array_length > 1 then
									if top_file_path_array[1] == sett_SettingsCategory and top_file_path_array_length == 2 then
										local get_settings_module = game_content.Settings[top_file_path_array[2]]
										if get_settings_module ~= nil then
											result_file = get_settings_module
											break
										else
											if is_server == true then
												FilePathError("Settings module does not exist in path", top_file_name, top_file_path, top_element_name, top_element_type_name, top_base_category_name, game_tag)
											else
												result_file = "NotReplicated"
												break
											end
										end
									elseif table.find(sett_BaseElementCategories, top_file_path_array[1]) ~= nil and (top_file_path_array_length == 3 or top_file_path_array_length == 4) then
										-- BaseCategory.ElementType.ElementName(.FileName)
										local element_data_link = game_content[top_file_path_array[1]][top_file_path_array[2]]
										if element_data_link == nil then
											FilePathError("Missing element type", top_file_name, top_file_path, top_element_name, top_element_type_name, top_base_category_name, game_tag)
										end
										element_data_link = element_data_link[top_file_path_array[3]]
										if element_data_link == nil then
											FilePathError("Missing element in path", top_file_name, top_file_path, top_element_name, top_element_type_name, top_base_category_name, game_tag)
										end
										if top_file_path_array_length == 3 then
											result_file = top_file_path_array
											break
										else
											local element_container_link = element_container_reference[top_file_path_array[1]][top_file_path_array[2]][top_file_path_array[3]]
											local element_files_link = element_data_link["File"]
											local stack_continues = false
											if type(element_files_link) == "table" then
												local new_path = element_files_link[top_file_path_array[4]]
												if new_path ~= nil then
													stack_continues = true
													
													table.insert(file_tables_stack, {element_files_link, top_file_path_array[4]})
													
													top_file_name = top_file_path_array[4]
													top_file_path = new_path
													top_file_path_array = FilePathToArray(new_path)
													
													top_element_container = element_container_link
													top_element_name = top_file_path_array[3]
													top_element_type_name = top_file_path_array[2]
													top_base_category_name = top_file_path_array[1]
												end
											end
											if stack_continues == false then
												local linked_file = element_container_link:FindFirstChild(top_file_path_array[4])
												if linked_file ~= nil then
													result_file = linked_file
													break
												else
													if is_server == true then
														FilePathError("Missing file in path", top_file_name, top_file_path, top_element_name, top_element_type_name, top_base_category_name, game_tag)
													else
														result_file = "NotReplicated"
														break
													end
												end
											end
										end
									else
										FilePathError("Invalid file path", top_file_name, top_file_path, top_element_name, top_element_type_name, top_base_category_name, game_tag)
									end
								end
							end
							
							for _, file_table_reference in ipairs(file_tables_stack) do
								file_table_reference[1][file_table_reference[2]] = result_file
							end
							
						elseif type(file_name) ~= "string" or typeof(file_path) ~= "Instance" then
							FilePathError("Invalid file path", file_name, file_path, element_name, element_type_name, base_category_name, game_tag)
						end
					end
				elseif element_files ~= nil then
					error("[ContentLoader]: Invalid \"File\" argument for element \"" .. element_name .. "\" in element type \"" .. element_type_name .. "\" in base category \"" .. base_category_name .. "\" (" .. game_tag .. ")")
				end
			end
		end
	end
	-- Disabling replication for files marked with a "NotReplicated" Instance:
	if is_server == true then
		local not_replicated_container = Instance.new("Folder")
		not_replicated_container.Name = "NotReplicated"
		not_replicated_container.Parent = game:GetService("ServerScriptService")
		
		for base_category_name, base_category in pairs(element_container_reference) do
			for element_type_name, element_type in pairs(base_category) do
				local data_module_name = element_type_name .. "Data"
				for element_name, element_container in pairs(element_type) do
					for _, file in ipairs(element_container:GetChildren()) do
						local not_replicated_tag = file:FindFirstChild("NotReplicated")
						if not_replicated_tag ~= nil then
							if file.Name ~= data_module_name then
								if file:IsA("ModuleScript") == true then
									-- Include element tags with the module name to be shown in the error stack:
									file.Name = base_category_name .. "_" .. element_type_name .. "_" .. element_name .. "_" .. file.Name
									file.Parent = not_replicated_container
								else
									file.Parent = nil
								end
								not_replicated_tag.Parent = nil
							else
								error("[ContentLoader]: \"NotReplicated\" instance can't be parented to the \"" .. element_type_name .. "Data\" module for element \"" .. element_name .. "\" in element type \"" .. element_type_name .. "\" in base category \"" .. base_category_name .. "\" (" .. game_tag .. ")")
							end
						end
					end
				end
			end
		end
		for _, settings_module in pairs(game_content.Settings) do
			local not_replicated_tag = settings_module:FindFirstChild("NotReplicated")
			if not_replicated_tag ~= nil then
				not_replicated_tag.Parent = nil
				settings_module.Parent = not_replicated_container
			end
		end
	end
end

return ContentLoader