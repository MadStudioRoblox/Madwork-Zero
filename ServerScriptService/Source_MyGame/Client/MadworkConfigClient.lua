local Madwork = _G.Madwork
--[[
[MPBR]

-[MadworkConfigClient]---------------------------------------
	Madwork code package configuration - executed first before the rest of this package
--]]

local SETTINGS = {
	
}

----- Loaded Services / Controllers & Modules -----

local InputController = Madwork.GetController("InputController")

----- Private Variables -----

--[[
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:FindFirstChild("PlayerScripts")

local RbxCharacterSounds = PlayerScripts:FindFirstChild("RbxCharacterSounds")
--]]

----- Initialize -----

InputController.SetupDefaultActions("Shooter")

--[[
-- Configuring default Roblox starter scripts:

if RbxCharacterSounds ~= nil then
	RbxCharacterSounds.Disabled = true
	RbxCharacterSounds:Destroy()
end
--]]

return true