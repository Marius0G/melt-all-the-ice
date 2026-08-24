--!strict
--[[
	MeltEffects - draws whatever the server says the last swing did.

	The client is told, never asked: by the time this runs the outcome is already
	settled and paid out on the server. Nothing in here can change a number.

	Everything for one hit fires in the same frame. Any gap between the shake,
	the particles and the sound stops them reading as a single impact.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Feel = require(Shared:WaitForChild("Feel"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local modules = script.Parent
local Audio = require(modules:WaitForChild("Audio"))
local CameraShake = require(modules:WaitForChild("CameraShake"))
local Crosshair = require(modules:WaitForChild("Crosshair"))
local Particles = require(modules:WaitForChild("Particles"))
local Popups = require(modules:WaitForChild("Popups"))
local Shards = require(modules:WaitForChild("Shards"))
local SwingAnimation = require(modules:WaitForChild("SwingAnimation"))

local MeltEffects = {}

local function onSwingResult(position: unknown, normal: unknown, destroyed: unknown, hpRatio: unknown)
	if typeof(position) ~= "Vector3" or typeof(normal) ~= "Vector3" then
		return
	end
	local at = position :: Vector3
	local face = normal :: Vector3
	local killed = destroyed == true
	local ratio = if typeof(hpRatio) == "number" then hpRatio else 0

	Crosshair.confirm(killed)

	if killed then
		SwingAnimation.hitStop()
		Particles.shatter(at, face)
		CameraShake.impulse(Feel.SHAKE_KILL)
		Shards.burst(at, face)

		-- Three layers: the sharp transient, the body of the break, then the
		-- debris settling a beat later. One sample alone sounds like a click.
		Audio.playAt(Audio.pick(Feel.SOUNDS.IMPACT), at, { volume = 0.55 })
		Audio.playAt(Audio.pick(Feel.SOUNDS.ICE_CRACK), at, { volume = 0.45 })
		Audio.playAt(Audio.pick(Feel.SOUNDS.DEBRIS), at, {
			volume = 0.22,
			delay = Feel.TAIL_DELAY,
		})

		Popups.show(at, string.format("+$%d", Config.MONEY_PER_CHUNK))
	else
		Particles.chip(at, face)
		CameraShake.impulse(Feel.SHAKE_CHIP)
		-- Pitch climbs as the chunk nears death, so the last hit before it goes
		-- is audibly the last hit. Free tension, resolved by the shatter.
		Audio.playAt(Audio.pick(Feel.SOUNDS.IMPACT), at, {
			volume = 0.45,
			speed = 0.95 + (1 - ratio) * 0.25,
		})
	end
end

function MeltEffects.start()
	CameraShake.start()
	Remotes.swingResult().OnClientEvent:Connect(onSwingResult)
end

return MeltEffects
