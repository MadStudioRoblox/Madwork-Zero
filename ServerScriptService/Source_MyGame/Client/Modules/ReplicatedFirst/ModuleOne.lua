--[[
[MPBR]

-[ModuleOne]---------------------------------------
	First piece of game code ran for clients; No access to custom resources beyond parent folder

	Members:
	
		ModuleOne.Storage   nil or [any] -- Optionally set to a reference to loading screen instances;
			Set immediately after "GameLoaded()" is triggered
	
	Functions:
	
		ModuleOne.CoreReady(madwork) -- Called BEFORE Madwork.CoreReadySignal is triggered
			madwork   [Madwork] -- Reference to Madwork namespace
		
--]]

local SETTINGS = {

}

----- Module Table -----

local ModuleOne = {
	Storage = nil,
}

----- Private Variables -----

local Player = game:GetService("Players").LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

----- Utils -----

----- Private functions -----

----- Public functions -----

function ModuleOne.CoreReady(madwork)
	
end

----- Initialize -----

print("ModuleOne running!")

----- Connections -----

return ModuleOne