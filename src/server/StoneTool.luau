--!strict
--[[
	StoneTool - the starting tool: a rock in your hand.

	Deliberately dumb. The Tool exists so the client has something to activate
	and so the swing reads on screen; every rule about what that swing does
	lives in MeltService. The MeltTool attribute is how the client recognises
	which tools should fire a swing.
]]

local StoneTool = {}

function StoneTool.create(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Stone"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Swing at the ice"
	tool:SetAttribute("MeltTool", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.2, 1.1, 1.6)
	handle.Material = Enum.Material.Slate
	handle.BrickColor = BrickColor.new("Dark stone grey")
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	return tool
end

return StoneTool
