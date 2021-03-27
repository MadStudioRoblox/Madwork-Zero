local Madwork = _G.Madwork
--[[
[MyGame]

-[TestService]---------------------------------------

--]]

local SETTINGS = {
	
}

----- Service Table -----

local TestService = {
	
}

----- Loaded Services & Modules -----

local TestModuleServer = require(Madwork.GetModule("Game", "TestModuleServer"))

----- Private Variables -----

----- Utils -----

----- Private functions -----

----- Public functions -----

----- Initialize -----

TestModuleServer.TestFunction()

----- Connections -----

return TestService