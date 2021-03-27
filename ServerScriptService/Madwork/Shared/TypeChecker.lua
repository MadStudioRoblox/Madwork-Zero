--[[
{Madwork}

-[TypeChecker]---------------------------------------
	An expressive type checker module

	Functions:
	
		-- WILL ERROR IF FAILS CHECK:
		TypeChecker.Check(value, check_data) --> value
			value        [value]
			check_data   [table]:
				{
					-- Generic type check:
					Type = "" / nil, -- typeof() check ("number", "string", "table", "Instance", "Vector3", etc.)
					Default = default_value / nil, -- If passed value is nil, will return default_value
					CanBeNil = true / nil,
					ValueName = "" / nil, -- value name to be printed when an error occurs
					
					Variants = {value, ...} / nil, -- value will have to be one of the following values
					
					-- Instances: (Using these values will lock "Type" to an according type even if "Type" is not set)
					ClassName = "" / nil, -- Will check if value is an instance of ClassName
					-- Numbers:
					Integer = true / nil,
					InBounds = {number_min, number_max} / nil,
					NotNegative = true / nil,
					Positive = true / nil,
					-- Strings:
					StringNotEmpty = true / nil,
					-- Table:
					Array = true / nil,
					Dictionary = true / nil,
					-- Vector3:
					IsUnitV3 = true / nil,
					
					-- Dictionary check:
					DictionaryCheck = true / nil, -- Assumes "value" is a value dictionary and "check_data" is a [value_key] = [check_data] dictionary
				}
				
		-- Will return any thrown error as a string:
		TypeChecker.Test(value, check_data) --> value, error_string or nil
				
	Recommended syntax example:
	
		local function(params)
			local fetched_value = TypeChecker.Check(params.Points, {Type = "number", Integer = true, Default = 0})
			...
		end
--]]

local ReceivedToString
local ValueNameToString

local SETTINGS = {
	
	SpecialisedTypeCheck = {
		ClassName = function(value, param, value_name)
			if value.ClassName ~= param then
				return "[MadworkTypeChecker]:" .. ValueNameToString(value_name) .. " must be of class \"" .. param .. "\"; Received \"" .. tostring(value) .. "\" [" .. value.ClassName .. "]"
			end
		end,
		Integer = function(value, param, value_name)
			if value % 1 ~= 0 then
				return "[MadworkTypeChecker]:" .. ValueNameToString(value_name) .. " must be an integer; Received [" .. value .. "]"
			end
		end,
		InBounds = function(value, param, value_name)
			if type(param) ~= "table" then
				return "[MadworkTypeChecker]: Invalid type check parameters for \"InBounds\""
			end
			local bounds_min = param[1]
			local bounds_max = param[2]
			if type(bounds_min) ~= "number" or type(bounds_max) ~= "number" then
				return "[MadworkTypeChecker]: Invalid type check parameters for \"InBounds\""
			end
			if bounds_min > bounds_max then
				return "[MadworkTypeChecker]: bounds_min must be lower or equal to bounds_max in \"InBounds\""
			end
			if value < bounds_min or value > bounds_max then
				return "[MadworkTypeChecker]:" .. ValueNameToString(value_name) .. " is out of bounds (MIN = " .. bounds_min .. "; MAX = " .. bounds_max .. "); Received [" .. value .. "]"
			end
		end,
		NotNegative = function(value, param, value_name)
			if value < 0 then
				return "[MadworkTypeChecker]:" .. ValueNameToString(value_name) .. " must be a positive value or zero; Received [" .. value .. "]"
			end
		end,
		Positive = function(value, param, value_name)
			if value <= 0 then
				return "[MadworkTypeChecker]:" .. ValueNameToString(value_name) .. " must be a positive value; Received [" .. value .. "]"
			end
		end,
		StringNotEmpty = function(value, param, value_name)
			if string.len(value) == 0 then
				return "[MadworkTypeChecker]:" .. ValueNameToString(value_name) .. " can't be an empty string"
			end
		end,
		Array = function(value, param, value_name)
			-- # is unreliable for sparse arrays
			-- Count upwards using ipairs to avoid false positives from the behavior of #
			local array_size = 0
			for _ in ipairs(value) do
				array_size = array_size + 1
			end
			for key in pairs(value) do
				local bad_key = false
				if type(key) ~= "number" then
					bad_key = true
				elseif key % 1 ~= 0 or key < 1 or key > array_size then
					bad_key = true
				end
				if bad_key then
					return "[MadworkTypeChecker]:" .. ValueNameToString(value_name) .. " must be an array table; Bad key [" .. tostring(key) .. "]"
				end
			end
		end,
		Dictionary = function(value, param, value_name)
			for key in pairs(value) do
				if type(key) ~= "string" then
					return "[MadworkTypeChecker]:" .. ValueNameToString(value_name) .. " must be a dictionary table; Bad key [" .. tostring(key) .. "]"
				end
			end
		end,
		IsUnitV3 = function(value, param, value_name)
			if math.abs(value.Magnitude - 1) >= 0.01 then
				return "[MadworkTypeChecker]:" .. ValueNameToString(value_name) .. " must be a unit vector; Magnitude is not close to 1 [" .. tostring(value.Magnitude) .. "]"
			end
		end
	},
	
	SpecialisedTypeCheck_FixedType = {
		ClassName = "Instance",
		Integer = "number",
		InBounds = "number",
		NotNegative = "number",
		Positive = "number",
		StringNotEmpty = "string",
		Array = "table",
		Dictionary = "table",
		IsUnitV3 = "Vector3",
	},
	
	TypeOfVariants = {
		["function"] = true,
		
		["boolean"] = true,
		["string"] = true,
		["number"] = true,
		["table"] = true,
		
		["Instance"] = true,
		
		["Color3"] = true,
		["Vector3"] = true,
		["Vector2"] = true,
		["CFrame"] = true,
		["UDim2"] = true,
	},
	
	NotSpecialTypeCheck = {
		Type = true,
		Default = true,
		ValueName = true,
		CanBeNil = true,
		Variants = true,
	},
	
}

----- Module Table -----

local TypeChecker = {
	
}

----- Private variables -----

local DictionaryCheck

-- Performance variables:

local sett_SpecialisedTypeCheck = SETTINGS.SpecialisedTypeCheck
local sett_SpecialisedTypeCheck_FixedType = SETTINGS.SpecialisedTypeCheck_FixedType
local sett_TypeOfVariants = SETTINGS.TypeOfVariants
local sett_NotSpecialTypeCheck = SETTINGS.NotSpecialTypeCheck

----- Private functions -----

function ReceivedToString(value)
	return "Received " .. tostring(value)
end

function ValueNameToString(value_name)
	return value_name ~= nil and " \"" .. value_name .. "\"" or " Value"
end

local function TypeCheck(value, check_data) --> value, error_string
	if check_data.DictionaryCheck == true then
		return DictionaryCheck(value, check_data)
	end
	local default_value = check_data.Default
	if value == nil and (default_value ~= nil or check_data.CanBeNil == true) then
		return default_value
	end
	local value_type = check_data.Type
	local value_name = check_data.ValueName
	if sett_TypeOfVariants[value_type] == nil and value_type ~= nil then
		return nil, "[MadworkTypeChecker]: Invalid type check parameter for \"Type\" - " .. tostring(value_type)
	end
	if value_name ~= nil then
		if type(value_name) ~= "string" then
			return nil, "[MadworkTypeChecker]: Invalid type check parameter for \"ValueName\""
		end
	end
	local value_variants = check_data.Variants
	if value_variants ~= nil then
		if table.find(value_variants, value) == nil then
			local concat
			for _, v in ipairs(value_variants) do
				if concat == nil then
					concat = tostring(v)
				else
					concat = concat .. ", " .. tostring(v)
				end
			end
			concat = concat or ""
			return nil, "[MadworkTypeChecker]: Value is not one of the allowed variants: {" .. concat .. "}"
		end
	end
	for check_type, check_param in pairs(check_data) do
		if sett_NotSpecialTypeCheck[check_type] ~= true then
			local fixed_type = sett_SpecialisedTypeCheck_FixedType[check_type]
			if fixed_type == nil then
				return nil, "[MadworkTypeChecker]: Type check method \"" .. tostring(check_type) .. "\" not defined"
			else
				if value_type ~= nil and value_type ~= fixed_type then
					return nil, "[MadworkTypeChecker]: Type check collision: \"Type\" is set to \"" .. value_type .. "\" when method \"" .. check_type .. " expects \"" .. fixed_type .. "\" type"
				else
					value_type = fixed_type
				end
				if typeof(value) ~= value_type then
					return nil, "[MadworkTypeChecker]:" .. ValueNameToString(value_name) .. " must be of type \"" .. value_type .. "\"; Received value of type \"" .. typeof(value) .. "\""
				end
				local error_string = sett_SpecialisedTypeCheck[check_type](value, check_param, value_name)
				if error_string ~= nil then
					return nil, error_string
				end
			end
		end
	end
	if value_type ~= nil then
		if typeof(value) ~= value_type then
			return nil, "[MadworkTypeChecker]:" .. ValueNameToString(value_name) .. " must be of type \"" .. value_type .. "\"; Received value of type \"" .. typeof(value) .. "\""
		end
	end
	return value
end

function DictionaryCheck(value_table, check_data_table, dictionary_stack)
	dictionary_stack = dictionary_stack or ""
	if type(value_table) ~= "table" then
		return nil, "[MadworkTypeChecker]: value must be a table"
	end
	-- Check for undefined keys:
	for key, value in pairs(value_table) do
		if check_data_table[key] == nil then
			return nil, "[MadworkTypeChecker]: Value name \"" .. tostring(key) .. "\" was not defined in check_data"
		end
	end
	for key, check_data in pairs(check_data_table) do
		if key ~= "DictionaryCheck" then
			local value = value_table[key]
			local error_string
			if check_data.DictionaryCheck == true then
				dictionary_stack = dictionary_stack .. (dictionary_stack == "" and "" or ".") .. tostring(key)
				if type(value) ~= "table" then
					return nil, "[MadworkTypeChecker]: \"" .. dictionary_stack .. "\" must be a table"
				else
					value_table[key], error_string = DictionaryCheck(value, check_data, dictionary_stack)
				end
			else
				check_data.ValueName = dictionary_stack .. (dictionary_stack == "" and "" or ".") .. tostring(key)
				value_table[key], error_string = TypeCheck(value, check_data)
			end
			if error_string ~= nil then
				return nil, error_string
			end
		end
	end
	return value_table
end

----- Public functions -----

function TypeChecker.Check(value, check_data)
	local value, error_string = TypeCheck(value, check_data, true)
	if error_string ~= nil then
		error(error_string)
	end
	return value
end

TypeChecker.Test = TypeCheck

return TypeChecker

---***---