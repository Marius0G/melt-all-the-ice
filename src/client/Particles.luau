--!strict
--[[
	Particles - one-shot bursts for chipping and shattering ice.

	:Emit(n) rather than Rate throughout. A continuous rate is throttled hard on
	low graphics settings, which is exactly the hardware most Roblox players are
	on - a burst survives that, a stream quietly stops existing.

	Only textures verified to ship with the client are used. The *_main.dds files
	other than sparkles are legacy multi-channel pairs for the old Fire/Smoke
	instances and can render with unexpected alpha.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Feel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Feel"))

local Particles = {}

-- An Attachment whose +Y (the default EmissionDirection) points along `normal`,
-- so the burst sprays out of the surface instead of in a fixed world direction.
local function orientedAttachment(position: Vector3, normal: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	-- CFrame.lookAt degenerates when the direction is parallel to its up vector,
	-- and a floor or ceiling chunk gives exactly that normal.
	local up = if math.abs(normal.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	attachment.WorldCFrame = CFrame.lookAt(position, position + normal, up)
		* CFrame.Angles(-math.pi / 2, 0, 0)
	attachment.Parent = Workspace.Terrain
	return attachment
end

local function shardEmitter(): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Feel.TEXTURES.SPARKLE
	emitter.Enabled = false
	emitter.Lifetime = NumberRange.new(0.35, 0.65)
	emitter.Speed = NumberRange.new(14, 30)
	emitter.SpreadAngle = Vector2.new(55, 55)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-220, 220)
	-- Roughly 3.5x gravity. Shards that fall fast read as heavy; at real gravity
	-- they float and read as paper.
	emitter.Acceleration = Vector3.new(0, -70, 0)
	emitter.Drag = 1.5
	-- Stretches each sprite along its travel direction, which is the difference
	-- between a shard and a dot.
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Squash = NumberSequence.new(0.6)
	emitter.LightEmission = 0.55
	-- LightInfluence defaults to 0, so particles ignore the scene entirely and
	-- glow flat white in a dark cave. Some influence ties them to the room.
	emitter.LightInfluence = 0.35
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Feel.ICE_BRIGHT),
		ColorSequenceKeypoint.new(0.5, Feel.ICE_MID),
		ColorSequenceKeypoint.new(1, Feel.ICE_DEEP),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.75, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	return emitter
end

local function puffEmitter(): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Feel.TEXTURES.GLOW
	emitter.Enabled = false
	emitter.Lifetime = NumberRange.new(0.45, 0.8)
	emitter.Speed = NumberRange.new(2, 6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 6, 0) -- cold vapour drifts up
	emitter.Drag = 5
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.LightEmission = 0.25
	emitter.LightInfluence = 0.6
	emitter.ZOffset = -0.5 -- sit behind the shards
	emitter.Color = ColorSequence.new(Feel.ICE_BRIGHT)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 3.5),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	return emitter
end

local function chipEmitter(): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Feel.TEXTURES.SQUARE
	emitter.Enabled = false
	emitter.Lifetime = NumberRange.new(0.2, 0.4)
	emitter.Speed = NumberRange.new(10, 20)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, -90, 0)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.LightEmission = 0.4
	emitter.LightInfluence = 0.4
	emitter.Color = ColorSequence.new(Feel.ICE_MID)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	return emitter
end

local function withinRange(position: Vector3): boolean
	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end
	return (position - camera.CFrame.Position).Magnitude <= Feel.FX_MAX_DISTANCE
end

-- Emitters are built, fired and thrown away. At roughly two breaks a second
-- that is cheap, and it avoids holding a pool of live emitters that each cost
-- something just by existing.
local function fire(attachment: Attachment, emitters: { ParticleEmitter }, counts: { number })
	local longest = 0
	for index, emitter in emitters do
		emitter.Parent = attachment
		emitter:Emit(counts[index])
		longest = math.max(longest, emitter.Lifetime.Max)
	end
	task.delay(longest + 0.2, function()
		attachment:Destroy()
	end)
end

function Particles.shatter(position: Vector3, normal: Vector3)
	if not withinRange(position) then
		return
	end
	local attachment = orientedAttachment(position, normal)
	fire(attachment, { shardEmitter(), puffEmitter() }, { Feel.SHARDS_ON_KILL, Feel.PUFF_ON_KILL })
end

function Particles.chip(position: Vector3, normal: Vector3)
	if not withinRange(position) then
		return
	end
	local attachment = orientedAttachment(position, normal)
	fire(attachment, { chipEmitter() }, { Feel.SHARDS_ON_CHIP })
end

return Particles
