--!strict
--[[
	ToolService - builds the cave tools and keeps a backpack in step with what
	the player owns.

	The tools are Blender meshes now rather than assemblies of boxes and
	cylinders (see assets/blender/tools.py, ids in ToolAssets). Most are two
	meshes, a haft and a head, which is what lets a skin put a stone edge on a
	wooden handle instead of painting the whole thing one colour.

	Meshes are preloaded once at startup and cloned per tool. CreateMeshPartAsync
	yields on a network round trip, and create() runs inside loops on every spawn
	and every purchase - fetching there would stall the server a tool at a time.

	The Tools themselves stay dumb: they exist so the client has something to
	activate and so a swing reads on screen. Every rule about what a swing does
	lives in MeltService, which looks up the equipped tool by its ToolKey
	attribute rather than trusting anything the client sends.
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Feel = require(Shared:WaitForChild("Feel"))
local Skins = require(Shared:WaitForChild("Skins"))
local ToolAssets = require(Shared:WaitForChild("ToolAssets"))
local Tools = require(Shared:WaitForChild("Tools"))

local ToolService = {}

local FALLBACK = Color3.fromRGB(128, 122, 116)

local templates: { [string]: BasePart } = {}

local function loadMesh(piece: ToolAssets.Piece): BasePart?
	local existing = templates[piece.meshId]
	if existing then
		return existing
	end

	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(piece.meshId), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise,
		})
	end)
	if not ok or not result then
		warn(string.format("[MeltAllTheIce] could not load tool mesh %s: %s", piece.meshId, tostring(result)))
		return nil
	end

	local mesh = result :: MeshPart
	-- Authored dimensions win. The importer normalises a whole model and the
	-- factor changes with the file's contents, so what it reports is not a
	-- number anything should depend on.
	mesh.Size = piece.size
	mesh.Anchored = false
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.CastShadow = false
	mesh.Massless = true
	mesh.Parent = nil

	templates[piece.meshId] = mesh
	return mesh
end

-- Fetch every tool mesh up front, concurrently.
function ToolService.preload()
	local pieces: { ToolAssets.Piece } = {}
	for _, model in ToolAssets.MODELS do
		table.insert(pieces, model.body)
		if model.head then
			table.insert(pieces, model.head :: ToolAssets.Piece)
		end
	end
	if #pieces == 0 then
		return
	end

	local completed = 0
	local signal = Instance.new("BindableEvent")
	for _, piece in pieces do
		task.spawn(function()
			loadMesh(piece)
			completed += 1
			if completed == #pieces then
				signal:Fire()
			end
		end)
	end
	if completed < #pieces then
		signal.Event:Wait()
	end
	signal:Destroy()
end

local function spawnPiece(piece: ToolAssets.Piece, name: string): BasePart
	local template = templates[piece.meshId] or loadMesh(piece)
	local part: BasePart
	if template then
		part = template:Clone()
	else
		-- A missing mesh should cost the player a nice-looking tool, not a
		-- working one.
		local block = Instance.new("Part")
		block.Size = piece.size
		block.Material = Enum.Material.Slate
		block.Color = FALLBACK
		part = block
	end
	part.Name = name
	part.CFrame = CFrame.new(piece.offset)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	return part
end

-- Everything hangs off Handle, which is the part Roblox welds to the hand.
local function assemble(tool: Tool, handle: BasePart, extras: { BasePart })
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

-- Fire tools carry a glowing core, a light and an emitter. Colour is the only
-- thing that changes between them, which is what makes green greek fire read as
-- a different element rather than a recoloured torch.
local function makeFlame(at: number, size: number, tint: Color3): BasePart
	local flame = Instance.new("Part")
	flame.Name = "Flame"
	flame.Shape = Enum.PartType.Ball
	flame.Size = Vector3.new(size, size, size)
	flame.CFrame = CFrame.new(0, 0, at)
	flame.Color = tint
	flame.Material = Enum.Material.Neon
	flame.Anchored = false
	flame.CanCollide = false
	flame.CanQuery = false
	flame.CanTouch = false
	flame.CastShadow = false
	flame.Massless = true

	local light = Instance.new("PointLight")
	light.Name = "ToolLight"
	light.Brightness = 3.5
	light.Range = 38
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
		ColorSequenceKeypoint.new(0, tint:Lerp(Color3.new(1, 1, 1), 0.6)),
		ColorSequenceKeypoint.new(0.5, tint),
		ColorSequenceKeypoint.new(1, tint:Lerp(Color3.new(0, 0, 0), 0.6)),
	})
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 1.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	fire.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	fire.Parent = attachment

	return flame
end

-- Skins apply by part name, so adding one never means touching a model.
local function applySkin(tool: Tool, skin: Skins.Skin)
	for _, part in tool:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		if part.Name == "Handle" then
			part.Color = skin.body
			part.Material = skin.material
		elseif part.Name == "Flame" then
			local flame = skin.flame
			if flame then
				part.Color = flame
				for _, child in part:GetDescendants() do
					if child:IsA("PointLight") then
						child.Color = flame
					elseif child:IsA("ParticleEmitter") then
						child.Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, flame:Lerp(Color3.new(1, 1, 1), 0.6)),
							ColorSequenceKeypoint.new(0.5, flame),
							ColorSequenceKeypoint.new(1, flame:Lerp(Color3.new(0, 0, 0), 0.6)),
						})
					end
				end
			end
		else
			part.Color = skin.accent
		end
	end
end

function ToolService.create(key: string, skinKey: string?): Tool?
	local def = Tools.get(key)
	local model = ToolAssets.get(key)
	if not def or not model then
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

	local chosen = skinKey or Skins.defaultFor(key)
	local skin = if chosen then Skins.get(chosen) else nil
	if skin and skin.tool ~= key then
		skin = nil
	end

	local handle = spawnPiece(model.body, "Handle")
	local extras: { BasePart } = {}

	if model.head then
		table.insert(extras, spawnPiece(model.head :: ToolAssets.Piece, "Head"))
	end

	local flameAt = model.flameAt
	if flameAt then
		local tint = (skin and skin.flame) or Color3.fromRGB(255, 158, 52)
		table.insert(extras, makeFlame(flameAt, model.flameSize or 0.9, tint))
	end

	assemble(tool, handle, extras)

	if skin then
		applySkin(tool, skin)
		-- Recorded so sync can tell when the look has changed and needs
		-- rebuilding, rather than rebuilding every tool on every call.
		tool:SetAttribute("SkinKey", skin.key)
	end
	return tool
end

-- Give the player exactly the tools they own, and nothing they do not. Called on
-- spawn and again whenever a purchase changes the set.
function ToolService.sync(
	player: Player,
	owned: { [string]: boolean },
	equipped: { [string]: string }?
)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local character = player.Character

	local function existing(key: string): Tool?
		local label = (Tools.get(key) :: Tools.ToolDef).label
		local found = backpack:FindFirstChild(label)
		if not found and character then
			found = character:FindFirstChild(label)
		end
		return if found and found:IsA("Tool") then found else nil
	end

	for _, def in Tools.DEFS do
		local shouldHave = def.key == "stone" or owned[def.key] == true
		if not shouldHave then
			continue
		end

		local wanted = (equipped and equipped[def.key]) or Skins.defaultFor(def.key)
		local current = existing(def.key)

		if current then
			-- Already held: only rebuild it if the chosen look has changed.
			if wanted and current:GetAttribute("SkinKey") ~= wanted then
				local wasEquipped = current.Parent == character
				current:Destroy()
				local replacement = ToolService.create(def.key, wanted)
				if replacement then
					replacement.Parent = if wasEquipped and character then character else backpack
				end
			end
		else
			local tool = ToolService.create(def.key, wanted)
			if tool then
				tool.Parent = backpack
			end
		end
	end
end

return ToolService
