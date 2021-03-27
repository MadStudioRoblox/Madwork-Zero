local Madwork = _G.Madwork
--[[
[MyGame]

-[TestController]---------------------------------------

--]]

local SETTINGS = {
	
}

----- Controller Table -----

local TestController = {
	
}

----- Loaded Controllers & Modules -----

local TestModuleClient = require(Madwork.GetModule("Game", "TestModuleClient"))

----- Private Variables -----

----- Utils -----

----- Private functions -----

----- Public functions -----

----- Initialize -----

TestModuleClient.TestFunction()

----- Connections -----

return TestController