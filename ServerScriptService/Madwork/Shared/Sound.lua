local Madwork = _G.Madwork
--[[
{Madwork}

-[Sound]---------------------------------------
	Loads sound tables and manages sound groups.
	
	THE "S FORMAT":
	
		SoundName = {S = {"rbxassetid://", ...}, SoundProperty = value, ...}
		
		First member of the S format sound entry must be a table with the key "S"
			which is a table containing zero, one or more sound asset id's.
			Following the S member, any amount of sound properties can be set
			("Volume", "MaxDistance") which are members of the Roblox Sound class.
	
	Members:
	
		Sound.SoundGroups   [table]: -- List of loaded sound groups
			{
				SoundGroupName = {
					Instance = sound_group,
					DisplayName = "",
				},
				...
			}
	
	Functions:
	
		Sound.SetupSoundGroups(sound_groups) -- Creates SoundGroup objects (can only be called once)
			sound_groups   [table]:
				{
					SoundGroupName = {
						Setup = function(sound_group) -- (optional) Passes SoundGroup instance to this function
						
						end,
						DisplayName = "", -- (optional) Name of the sound group to be shown for the user
					},
					...
				}
				
		Sound.GetSoundGroup(sound_group_name) --> [SoundGroup] -- Notice: Will throw a warning if the sound group is missing
			sound_group_name   [string]
			
		Sound.GetSoundInstance(sound_params) --> [Sound] or nil -- Use for custom sound management
			sound_params   [table]:
				{
					Data = {S = {...}, ...}, -- Will only return one sound randomly
					SoundGroupName = "",
					SoundNumber = 1, -- (optional) Selects specified sound id in the S table
				}
			
		Sound.LoadSound(sound_params) --> [SoundPlayer]
			sound_params   [table]:
				{
					Data = {S = {...}, ...},
					SoundGroupName = "",
					Mount = instance,
					Name = "" or nil, -- Applied to Sound.Name whenever a sound instance is created
				}
			
		Sound.LoadSoundPack(pack_params) --> [SoundPack]
			pack_params   [table]:
				{
					Pack = {SoundName = {S = {...}, ...}, ...},
					SoundGroupName = "",
					Mount = instance,
				}
				
	Methods [SoundPlayer]:
	
		SoundPlayer:Play() -- Plays an instance of this sound (stops existing looped instance)
		SoundPlayer:Stop() -- Stops all instances of this sound
		SoundPlayer:Destroy()
		
	Methods [SoundPack]:
	
		SoundPack:Play(sound_name)
		SoundPack:Stop(sound_name)
			sound_name   [sound_name] -- Will not throw an error when sound_name doesn't match any sound
		
		SoundPack:StopAll()	
		SoundPack:Destroy()
		

--]]

local SETTINGS = {
	
}

----- Module Table -----

local Sound = {
	SoundGroups = {
		--[[
			SoundGroupName = {
				Instance = sound_group,
				DisplayName = "",
			},
			...
		--]]
	}
}

----- Private Variables -----

local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local ValidSoundProperties = {} -- [property] = true
local SoundGroupsSetup = false

local IsStudio = RunService:IsStudio()
local CacheFixHack -- Sounds behave weirdly in studio if we don't parent prefabs to the gamemodel

----- Private functions -----

local function SoundFormatToSoundInstance(s_format, sound_number) --> [Sound] or nil
	local sound_ids = s_format.S
	if type(sound_ids) ~= "table" then
		error("[Sound]: Invalid S format - \"S\" member missing")
	end
	if #sound_ids == 0 or (sound_number ~= nil and sound_number > #sound_ids) then
		return nil
	end
	
	local sound = Instance.new("Sound") -- ValidSoundProperties
	sound.SoundId = sound_ids[sound_number or math.random(1, #sound_ids)]
	
	for property, value in pairs(s_format) do
		if property ~= "S" then
			if ValidSoundProperties[property] == true then
				sound[property] = value
			else
				local is_valid = pcall(function()
					local x = sound[property]
				end)
				if is_valid == true then
					ValidSoundProperties[property] = true
					sound[property] = value
				else
					error("[Sound]: Invalid member \"" .. tostring(property) .. "\" in the S format; SoundId = " .. tostring(sound.SoundId))
				end
			end
		end
	end
	
	return sound
end

----- Public functions -----

-- SoundPlayer object:
local SoundPlayer = {
	--[[
		_sound_variants = {}, -- {sound, ...}
		_is_looped = false,
		_active_instances = {}, -- sound = true, ...
		_mount = mount,
	--]]
}
SoundPlayer.__index = SoundPlayer

function SoundPlayer:Play()
	local active_instances = self._active_instances
	-- Clear active instances that need to be cleared:
	local is_looped = self._is_looped
	for active_instance in pairs(active_instances) do
		if is_looped == true or (active_instance.Playing == false and active_instance.IsPlaying == false) then
			if active_instance.IsPlaying == true then
				active_instance:Stop()
				print("STOP", os.clock())
			end
			active_instance:Destroy()
			active_instances[active_instance] = nil
		end
	end
	-- Spawn new sound instance:
	local sound_variants = self._sound_variants
	local sound_variants_length = #sound_variants
	if sound_variants_length == 0 then
		return -- SoundPlayer has no sounds
	end
	
	local sound = sound_variants[math.random(1, sound_variants_length)]:Clone()
	active_instances[sound] = true
	sound.Parent = self._mount
	sound:Play()
end

function SoundPlayer:Stop()
	local active_instances = self._active_instances
	for active_instance in pairs(active_instances) do
		active_instance:Stop()
		active_instance:Destroy()
		active_instances[active_instance] = nil
	end
end

function SoundPlayer:Destroy()
	self:Stop()
	for _, variant in ipairs(self._sound_variants) do
		variant:Destroy()
	end
	self._sound_variants = {}
end

-- SoundPack object:
local SoundPack = {
	--[[
		_sound_players = {}, -- [sound_name] = sound_player
	--]]
}
SoundPack.__index = SoundPack

function SoundPack:Play(sound_name)
	local sound_player = self._sound_players[sound_name]
	if sound_player ~= nil then
		sound_player:Play()
	end
end

function SoundPack:Stop(sound_name)
	local sound_player = self._sound_players[sound_name]
	if sound_player ~= nil then
		sound_player:Stop()
	end
end

function SoundPack:StopAll()
	for _, sound_player in pairs(self._sound_players) do
		sound_player:Stop()
	end
end

function SoundPack:Destroy()
	for _, sound_player in pairs(self._sound_players) do
		sound_player:Destroy()
	end
	self._sound_players = {}
end

-- Module functions:

function Sound.SetupSoundGroups(sound_groups)
	if SoundGroupsSetup == true then
		error("[Sound]: SoundGroups were already setup")
	end
	
	for sound_group_name, params in pairs(sound_groups) do
		
		local sound_group = Instance.new("SoundGroup")
		sound_group.Name = sound_group_name
		if params.Setup ~= nil then
			params.Setup(sound_group)
		end
		sound_group.Parent = SoundService
		
		Sound.SoundGroups[sound_group_name] = {
			Instance = sound_group,
			DisplayName = params.DisplayName or sound_group_name
		}
		
	end

	SoundGroupsSetup = true
end

function Sound.GetSoundGroup(sound_group_name, _ignore_sound_group_warning) --> [SoundGroup]
	local sound_group = Sound.SoundGroups[sound_group_name]
	sound_group = sound_group and sound_group.Instance
	if sound_group == nil then
		if _ignore_sound_group_warning ~= true then
			warn("[Sound]: SoundGroup \"" .. tostring(sound_group_name) .. "\" is missing; Traceback:\n" .. debug.traceback())
		end
	end
	return sound_group
end

function Sound.GetSoundInstance(sound_params) --> [Sound] or nil
	local sound = SoundFormatToSoundInstance(sound_params.Data, sound_params.SoundNumber)
	if sound ~= nil then
		sound.SoundGroup = Sound.GetSoundGroup(sound_params.SoundGroupName)
	end
	return sound
end

function Sound.LoadSound(sound_params, _ignore_sound_group_warning) --> [SoundPlayer]
	local sound_ids = sound_params.Data.S
	if type(sound_ids) ~= "table" then
		error("[Sound]: Invalid S format - \"S\" member missing")
	end
	
	local sound_variants = {}
	for i = 1, #sound_ids do
		local sound = SoundFormatToSoundInstance(sound_params.Data, i)
		sound.SoundGroup = Sound.GetSoundGroup(sound_params.SoundGroupName, _ignore_sound_group_warning)
		if IsStudio == true then
			sound.Parent = CacheFixHack
		end
		_ignore_sound_group_warning = true -- Only throw sound group warning once
		sound.Name = sound_params.Name or "Sound"
		table.insert(sound_variants, sound)
	end
	
	local sound_player = {
		_sound_variants = sound_variants,
		_is_looped = sound_params.Data.Looped == true,
		_active_instances = {},
		_mount = sound_params.Mount,
	}
	setmetatable(sound_player, SoundPlayer)
	
	return sound_player
end

function Sound.LoadSoundPack(pack_params) --> [SoundPack]
	-- Checking sound group; Only throw sound group warning once:
	Sound.GetSoundGroup(pack_params.SoundGroupName)
	
	local sound_players = {}
	for sound_name, s_format in pairs(pack_params.Pack) do
		sound_players[sound_name] = Sound.LoadSound(
			{
				Data = s_format,
				SoundGroupName = pack_params.SoundGroupName,
				Mount = pack_params.Mount,
				Name = sound_name,
			},
			true
		)
	end
	
	local sound_pack = {
		_sound_players = sound_players,
	}
	setmetatable(sound_pack, SoundPack)
	
	return sound_pack
end

----- Initialize -----

if IsStudio == true then
	CacheFixHack = Instance.new("Folder")
	CacheFixHack.Name = "StudioSoundCache"
	CacheFixHack.Parent = SoundService
end

return Sound