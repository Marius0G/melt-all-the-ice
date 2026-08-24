--!strict
--[[
	ToolService - builds the cave tools and keeps a backpack in step with what
	the player owns.

	The Tools are deliberately dumb: they exist so the client has something to
	activate and so a swing reads on screen. Every rule about what a swing does
	lives in MeltService, which looks up the equipped tool by its ToolKey
	attribute rather than trusting anything the client sends.

	Built from primitives rather than meshes. The props under the ice earn their
	upload because they carry the discovery moment; a rock on a stick does not,
	and a Part-built tool stays in the repo as text.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Feel = require(Shared:WaitForChild("Feel"))
local Tools = require(Shared:WaitForChild("Tools"))

local ToolService = {}

local WOOD = Color3.fromRGB(122, 84, 48)
local STONE = Color3.fromRGB(104, 108, 116)
local FLAME = Color3.fromRGB(255, 158, 52)

local function piece(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Massless = true
	return part
end

-- Everything hangs off Handle, which is the part Roblox welds to the hand.
local function assemble(tool: Tool, handle: Part, extras: { Part })
	handle.Name = "Handle"
	handle.Parent = tool
	for _, part in extras do
		part.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
	end
end

local function buildStone(tool: Tool)
	local handle = piece("Handle", Vector3.new(1.2, 1.1, 1.6), CFrame.new(), STONE, Enum.Material.Slate)
	assemble(tool, handle, {})
end

local function buildAxe(tool: Tool)
	local handle = piece("Handle", Vector3.new(0.35, 0.35, 3.0), CFrame.new(), WOOD, Enum.Material.Wood)
	local head = piece(
		"Head",
		Vector3.new(1.1, 0.9, 1.5),
		CFrame.new(0, 0, -1.2),
		STONE,
		Enum.Material.Slate
	)
	local binding = piece(
		"Binding",
		Vector3.new(0.45, 0.45, 0.5),
		CFrame.new(0, 0, -0.55),
		Color3.fromRGB(78, 62, 44),
		Enum.Material.Fabric
	)
	assemble(tool, handle, { head, binding })
end

local function buildTorch(tool: Tool)
	local handle = piece("Handle", Vector3.new(0.3, 0.3, 2.6), CFrame.new(), WOOD, Enum.Material.Wood)
	local wrap = piece(
		"Wrap",
		Vector3.new(0.5, 0.5, 0.8),
		CFrame.new(0, 0, -1.0),
		Color3.fromRGB(64, 50, 36),
		Enum.Material.Fabric
	)
	local flame = piece(
		"Flame",
		Vector3.new(0.7, 0.7, 0.9),
		CFrame.new(0, 0, -1.6),
		FLAME,
		Enum.Material.Neon
	)
	flame.Shape = Enum.PartType.Ball

	-- The torch is the map capstone precisely because it is a light source, not
	-- only a stronger tool. The cave starts with none.
	local light = Instance.new("PointLight")
	light.Name = "TorchLight"
	light.Brightness = 3
	light.Range = 34
	light.Color = Color3.fromRGB(255, 176, 96)
	light.Shadows = false
	light.Parent = flame

	local attachment = Instance.new("Attachment")
	attachment.Parent = flame

	local fire = Instance.new("ParticleEmitter")
	fire.Texture = Feel.TEXTURES.GLOW
	fire.Rate = 22
	fire.Lifetime = NumberRange.new(0.25, 0.5)
	fire.Speed = NumberRange.new(1.5, 3)
	fire.SpreadAngle = Vector2.new(18, 18)
	fire.Acceleration = Vector3.new(0, 12, 0)
	fire.LightEmission = 1
	fire.LightInfluence = 0
	fire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 150)),
		ColorSequenceKeypoint.new(0.5, FLAME),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 70, 20)),
	})
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	fire.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	fire.Parent = attachment

	assemble(tool, handle, { wrap, flame })
end

local BUILDERS: { [string]: (Tool) -> () } = {
	stone = buildStone,
	axe = buildAxe,
	torch = buildTorch,
}

function ToolService.create(key: string): Tool?
	local def = Tools.get(key)
	local builder = BUILDERS[key]
	if not def or not builder then
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = def.label
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = def.tooltip
	-- The client uses MeltTool to know which tools fire a swing; the server uses
	-- ToolKey to decide what that swing is worth. Neither is client-writable.
	tool:SetAttribute("MeltTool", true)
	tool:SetAttribute("ToolKey", key)

	builder(tool)
	return tool
end

-- Give the player exactly the tools they own, and nothing they do not. Called on
-- spawn and again whenever a purchase changes the set.
function ToolService.sync(player: Player, owned: { [string]: boolean })
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local character = player.Character

	local function has(key: string): boolean
		if backpack:FindFirstChild((Tools.get(key) :: Tools.ToolDef).label) then
			return true
		end
		return character ~= nil
			and character:FindFirstChild((Tools.get(key) :: Tools.ToolDef).label) ~= nil
	end

	for _, def in Tools.DEFS do
		local shouldHave = def.key == "stone" or owned[def.key] == true
		if shouldHave and not has(def.key) then
			local tool = ToolService.create(def.key)
			if tool then
				tool.Parent = backpack
			end
		end
	end
end

return ToolService
