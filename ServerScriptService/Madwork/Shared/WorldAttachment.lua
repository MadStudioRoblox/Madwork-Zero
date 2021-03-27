--[[
{Madwork}

-[WorldAttachment]---------------------------------------
	One part to attach lots of things to
--]]

local world_attachment = Instance.new("Part")
world_attachment.Name = "WorldAttachment"
world_attachment.Anchored = true
world_attachment.CanCollide = false
world_attachment.Massless = true
world_attachment.Size = Vector3.new(0.2, 0.2, 0.2)
world_attachment.Transparency = 1
world_attachment.CFrame = CFrame.new(0, 0, 0)
world_attachment.Parent = game:GetService("Workspace")

return world_attachment