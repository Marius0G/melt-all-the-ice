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
local Toast = require(modules:WaitForChild("Toast"))

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

local function onDiscovery(position: unknown, label: unknown, reward: unknown, hero: unknown)
	if typeof(position) ~= "Vector3" or typeof(label) ~= "string" then
		return
	end
	local at = position :: Vector3
	local name = label :: string
	local payout = if typeof(reward) == "number" then reward else 0
	local isHero = hero == true

	-- Deliberately delayed. The shatter that uncovered this is still playing;
	-- landing on top of it makes the two read as one muddled event instead of
	-- cause and consequence.
	task.delay(Feel.REVEAL_DELAY, function()
		Particles.reveal(at)
		CameraShake.impulse(Feel.SHAKE_REVEAL)
		Audio.playAt(Audio.pick(Feel.SOUNDS.REVEAL), at, { volume = 0.7, speed = if isHero then 1.0 else 1.15 })
		Popups.show(at + Vector3.new(0, 2, 0), string.format("+$%d", payout), Feel.MONEY, if isHero then 1.6 else 1.25)
		Toast.show(name, payout, isHero)
	end)
end

function MeltEffects.start()
	CameraShake.start()
	Remotes.swingResult().OnClientEvent:Connect(onSwingResult)
	Remotes.discovery().OnClientEvent:Connect(onDiscovery)
end

return MeltEffects
