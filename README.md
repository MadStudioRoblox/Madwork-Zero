# Madwork-Zero
Open source version of Madwork

Documentation pending.

NOTICE - Madwork will not run before you run this code in the command line in studio:
``` lua
-- Add attributes to packages - run in console after importing via Rojo:
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Content_MyGame = ReplicatedStorage:FindFirstChild("Content_MyGame")
local Madwork = ServerScriptService:FindFirstChild("Madwork")
local Source_MyGame = ServerScriptService:FindFirstChild("Source_MyGame")

-- GameTag is used to mark content and datastore saves with a unique string
-- PackageName is a package identifier used in "Madwork.GetModule()" and "Madwork.GetShared()"
-- MadworkPackageType defines the type of package

Content_MyGame:SetAttribute("GameTag", "MyGame")
Content_MyGame:SetAttribute("MadworkPackageType", "Content")

Madwork:SetAttribute("PackageName", "Madwork")
Madwork:SetAttribute("MadworkPackageType", "Madwork")

Source_MyGame:SetAttribute("GameTag", "MyGame")
Source_MyGame:SetAttribute("PackageName", "Game")
Source_MyGame:SetAttribute("MadworkPackageType", "Game")
```