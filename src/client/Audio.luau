--!strict
--[[
	Audio - positional one-shots for the melt loop.

	Everything here is client-local and cosmetic. Sounds are parented to a
	throwaway Attachment on Terrain rather than on the ice: a Sound only becomes
	3D by living on a BasePart or Attachment, and Terrain is the one instance
	guaranteed never to stream out from under it. Parenting to the plot folder
	would work until the moment the chunk it hung from was destroyed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Feel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Feel"))

local Audio = {}

export type PlayOptions = {
	volume: number?,
	speed: number?,
	delay: number?,
}

local group: SoundGroup? = nil

-- One group for every gameplay sound, so a settings slider later has a single
-- thing to turn down.
local function sfxGroup(): SoundGroup
	if group then
		return group
	end
	local existing = SoundService:FindFirstChild("SFX")
	if existing and existing:IsA("SoundGroup") then
		group = existing
		return existing
	end
	local created = Instance.new("SoundGroup")
	created.Name = "SFX"
	created.Volume = 1
	created.Parent = SoundService
	group = created
	return created
end

function Audio.pick(list: { string }): string
	return list[math.random(#list)]
end

-- Without this, 2.2 hits a second is the same waveform on repeat and reads as a
-- broken loop rather than as mining. Kept under +/-15% or ice starts to sound
-- like a cartoon.
local function variedPitch(): number
	return Feel.PITCH_MIN + math.random() * (Feel.PITCH_MAX - Feel.PITCH_MIN)
end

function Audio.playAt(soundId: string, position: Vector3, options: PlayOptions?)
	local camera = Workspace.CurrentCamera
	if camera and (position - camera.CFrame.Position).Magnitude > Feel.FX_MAX_DISTANCE then
		return
	end

	local opts: PlayOptions = options or {}

	local start = function()
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = Workspace.Terrain

		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = opts.volume or 0.6
		sound.PlaybackSpeed = opts.speed or variedPitch()
		-- InverseTapered behaves naturally up close but still reaches actual
		-- silence at the max distance, which plain Inverse never does.
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = Feel.SOUND_MIN_DISTANCE
		sound.RollOffMaxDistance = Feel.SOUND_MAX_DISTANCE
		sound.SoundGroup = sfxGroup()
		sound.Parent = attachment
		sound:Play()

		-- Several of these assets are multi-second recordings. Fade rather than
		-- hard-stop, so clamping does not click.
		local clamp = Feel.SOUND_CLAMP[soundId]
		if clamp then
			task.delay(clamp, function()
				if sound.Parent then
					TweenService:Create(sound, TweenInfo.new(0.15), { Volume = 0 }):Play()
					task.delay(0.16, function()
						attachment:Destroy()
					end)
				end
			end)
		else
			sound.Ended:Once(function()
				attachment:Destroy()
			end)
			task.delay(6, function()
				if attachment.Parent then
					attachment:Destroy()
				end
			end)
		end
	end

	if opts.delay and opts.delay > 0 then
		task.delay(opts.delay, start)
	else
		start()
	end
end

return Audio
