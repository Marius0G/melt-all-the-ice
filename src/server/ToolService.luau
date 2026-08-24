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
local GOLD = Color3.fromRGB(214, 168, 58)
local GOLD_LIGHT = Color3.fromRGB(255, 216, 118)

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


-- Fire head shared by every fire tool: a glowing core, a light, and an emitter.
-- Colour is the only thing that changes between them, which is what makes green
-- greek fire read as a different element rather than a recoloured torch.
local function addFlame(
	tool: Tool,
	handle: Part,
	offset: CFrame,
	size: number,
	tint: Color3,
	hot: Color3,
	brightness: number,
	range: number
): Part
	local flame = piece("Flame", Vector3.new(size, size, size), offset, tint, Enum.Material.Neon)
	flame.Shape = Enum.PartType.Ball

	local light = Instance.new("PointLight")
	light.Name = "ToolLight"
	light.Brightness = brightness
	light.Range = range
	light.Color = tint
	light.Shadows = false
	light.Parent = flame

	local attachment = Instance.new("Attachment")
	attachment.Parent = flame

	local fire = Instance.new("ParticleEmitter")
	fire.Texture = Feel.TEXTURES.GLOW
	fire.Rate = 26
	fire.Lifetime = NumberRange.new(0.25, 0.55)
	fire.Speed = NumberRange.new(1.5, 3.5)
	fire.SpreadAngle = Vector2.new(20, 20)
	fire.Acceleration = Vector3.new(0, 14, 0)
	fire.LightEmission = 1
	fire.LightInfluence = 0
	fire.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, hot),
		ColorSequenceKeypoint.new(0.5, tint),
		ColorSequenceKeypoint.new(1, tint:Lerp(Color3.new(0, 0, 0), 0.6)),
	})
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 1.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	fire.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	fire.Parent = attachment

	return flame
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
	-- The torch is the cave capstone precisely because it is a light source,
	-- not only a stronger tool. The cave starts with none.
	local flame = addFlame(
		tool, handle, CFrame.new(0, 0, -1.6), 0.7,
		FLAME, Color3.fromRGB(255, 230, 150), 3, 34
	)
	assemble(tool, handle, { wrap, flame })
end

local function buildCampfire(tool: Tool)
	-- A bundle of kindling carried under one arm, lit at the top.
	local handle = piece("Handle", Vector3.new(0.5, 0.5, 2.2), CFrame.new(), WOOD, Enum.Material.Wood)
	local extras = {}
	for i = 1, 4 do
		local angle = (i - 1) * (math.pi / 2)
		table.insert(extras, piece(
			"Log",
			Vector3.new(0.28, 0.28, 2.0),
			CFrame.new(math.cos(angle) * 0.34, math.sin(angle) * 0.34, -0.1)
				* CFrame.Angles(math.rad(math.cos(angle) * 12), math.rad(math.sin(angle) * 12), 0),
			Color3.fromRGB(96, 66, 38),
			Enum.Material.Wood
		))
	end
	local flame = addFlame(
		tool, handle, CFrame.new(0, 0, -1.5), 1.1,
		Color3.fromRGB(255, 150, 46), Color3.fromRGB(255, 232, 158), 4, 42
	)
	table.insert(extras, flame)
	assemble(tool, handle, extras)
end

local function buildScepter(tool: Tool)
	-- Ra's: a long gold staff carrying a sun disc.
	local handle = piece("Handle", Vector3.new(0.26, 0.26, 3.6), CFrame.new(), GOLD, Enum.Material.Metal)
	local extras = {}
	table.insert(extras, piece(
		"Disc", Vector3.new(1.5, 1.5, 0.18), CFrame.new(0, 0, -2.1) * CFrame.Angles(0, math.rad(90), 0),
		GOLD, Enum.Material.Metal
	))
	-- Sun rays around the disc.
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8)
		table.insert(extras, piece(
			"Ray",
			Vector3.new(0.12, 0.5, 0.1),
			CFrame.new(math.cos(angle) * 0.95, math.sin(angle) * 0.95, -2.1)
				* CFrame.Angles(0, 0, angle),
			GOLD_LIGHT,
			Enum.Material.Metal
		))
	end
	local flame = addFlame(
		tool, handle, CFrame.new(0, 0, -2.1), 0.9,
		Color3.fromRGB(255, 206, 74), Color3.fromRGB(255, 248, 210), 5, 54
	)
	table.insert(extras, flame)
	assemble(tool, handle, extras)
end

local function buildGreekFire(tool: Tool)
	-- A siphon: clay vessel on a short shaft, burning green.
	local handle = piece("Handle", Vector3.new(0.3, 0.3, 2.0), CFrame.new(), WOOD, Enum.Material.Wood)
	local extras = {}
	table.insert(extras, piece(
		"Vessel", Vector3.new(0.9, 0.9, 1.1), CFrame.new(0, 0, -1.2),
		Color3.fromRGB(168, 116, 78), Enum.Material.Slate
	))
	table.insert(extras, piece(
		"Spout", Vector3.new(0.32, 0.32, 0.7), CFrame.new(0, 0, -2.0),
		Color3.fromRGB(140, 96, 62), Enum.Material.Slate
	))
	local flame = addFlame(
		tool, handle, CFrame.new(0, 0, -2.4), 0.85,
		Color3.fromRGB(96, 240, 120), Color3.fromRGB(214, 255, 220), 4, 44
	)
	table.insert(extras, flame)
	assemble(tool, handle, extras)
end

local function buildChains(tool: Tool)
	-- Kratos': a grip trailing chain links to a blade, running red hot.
	local handle = piece("Handle", Vector3.new(0.34, 0.34, 1.4), CFrame.new(), Color3.fromRGB(72, 54, 40), Enum.Material.Fabric)
	local extras = {}
	for i = 1, 6 do
		table.insert(extras, piece(
			"Link",
			Vector3.new(0.26, 0.26, 0.34),
			CFrame.new(0, 0, -0.9 - i * 0.4) * CFrame.Angles(0, 0, math.rad(i * 45)),
			Color3.fromRGB(96, 84, 78),
			Enum.Material.Metal
		))
	end
	table.insert(extras, piece(
		"Blade", Vector3.new(0.16, 1.5, 1.4), CFrame.new(0, 0, -3.7) * CFrame.Angles(0, 0, math.rad(20)),
		Color3.fromRGB(198, 74, 42), Enum.Material.Metal
	))
	local flame = addFlame(
		tool, handle, CFrame.new(0, 0, -3.7), 1.0,
		Color3.fromRGB(255, 96, 48), Color3.fromRGB(255, 216, 150), 5, 48
	)
	table.insert(extras, flame)
	assemble(tool, handle, extras)
end

local BUILDERS: { [string]: (Tool) -> () } = {
	stone = buildStone,
	axe = buildAxe,
	torch = buildTorch,
	campfire = buildCampfire,
	scepter = buildScepter,
	greekfire = buildGreekFire,
	chains = buildChains,
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
