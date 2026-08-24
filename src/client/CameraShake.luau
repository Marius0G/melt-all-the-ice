--!strict
--[[
	CameraShake - short, decaying, noise-based camera impulses.

	Bound one priority above Enum.RenderPriority.Camera so it runs *after* the
	default camera script has written its CFrame, and composes with it instead of
	fighting it. Tweening Camera.CFrame directly, or driving Humanoid.CameraOffset,
	both lose: the first is overwritten every frame, the second cannot rotate, and
	rotation is most of what reads as shake.

	Perlin noise rather than per-frame randomness. Random offsets look like
	static; noise looks like something heavy landed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Feel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Feel"))

local CameraShake = {}

export type Impulse = {
	magnitude: number,
	roughness: number,
	duration: number,
}

type Active = {
	magnitude: number,
	roughness: number,
	duration: number,
	elapsed: number,
	seed: number,
}

local BINDING = "MeltCameraShake"

local active: { Active } = {}
local intensity = 1 -- accessibility scale; 0 disables shake entirely

function CameraShake.setIntensity(value: number)
	intensity = math.clamp(value, 0, 1)
end

function CameraShake.impulse(impulse: Impulse)
	if intensity <= 0 then
		return
	end
	table.insert(active, {
		magnitude = impulse.magnitude * intensity,
		roughness = impulse.roughness,
		duration = impulse.duration,
		elapsed = 0,
		seed = math.random() * 1000,
	})
end

local function step(deltaTime: number)
	if #active == 0 then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local offset, rotation = Vector3.zero, Vector3.zero

	for index = #active, 1, -1 do
		local shake = active[index]
		shake.elapsed += deltaTime
		if shake.elapsed >= shake.duration then
			table.remove(active, index)
		else
			-- Quadratic decay: punchy on the first frames, soft on the tail.
			-- Linear decay feels mushy at these durations.
			local alpha = shake.elapsed / shake.duration
			local falloff = 1 - alpha
			local amplitude = shake.magnitude * falloff * falloff
			local sample = shake.elapsed * shake.roughness

			offset += Vector3.new(
				math.noise(sample, 0, shake.seed),
				math.noise(0, sample, shake.seed),
				math.noise(shake.seed, sample, 0)
			) * amplitude
			rotation += Vector3.new(
				math.noise(sample + 17, 0, shake.seed),
				math.noise(0, sample + 31, shake.seed),
				math.noise(shake.seed, sample + 53, 0)
			) * amplitude
		end
	end

	camera.CFrame = camera.CFrame
		* CFrame.new(offset * Feel.SHAKE_POSITION_INFLUENCE)
		* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
end

function CameraShake.start()
	RunService:BindToRenderStep(BINDING, Enum.RenderPriority.Camera.Value + 1, step)
end

function CameraShake.stop()
	RunService:UnbindFromRenderStep(BINDING)
	table.clear(active)
end

return CameraShake
