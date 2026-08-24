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
local Feel = require(Shared:WaitForChild("Feel"))
local Rarity = require(Shared:WaitForChild("Rarity"))
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

local function onSwingResult(
	position: unknown,
	normal: unknown,
	destroyed: unknown,
	hpRatio: unknown,
	earned: unknown
)
	if typeof(position) ~= "Vector3" or typeof(normal) ~= "Vector3" then
		return
	end
	local at = position :: Vector3
	local face = normal :: Vector3
	-- A strike can break several chunks at once now, so this is a count rather
	-- than a flag. The count scales the response: a scepter crater should not
	-- feel like a stone chip.
	local broke = if typeof(destroyed) == "number" then destroyed else 0
	local ratio = if typeof(hpRatio) == "number" then hpRatio else 0
	local payout = if typeof(earned) == "number" then earned else 0

	Crosshair.confirm(broke > 0)

	if broke > 0 then
		SwingAnimation.hitStop()
		Particles.shatter(at, face, broke)
		local weight = math.min(3, 1 + (broke - 1) * 0.35)
		CameraShake.impulse({
			magnitude = Feel.SHAKE_KILL.magnitude * weight,
			roughness = Feel.SHAKE_KILL.roughness,
			duration = Feel.SHAKE_KILL.duration * math.min(2, weight),
		})
		Shards.burst(at, face)

		-- Three layers: the sharp transient, the body of the break, then the
		-- debris settling a beat later. One sample alone sounds like a click.
		Audio.playAt(Audio.pick(Feel.SOUNDS.IMPACT), at, { volume = 0.55 })
		Audio.playAt(Audio.pick(Feel.SOUNDS.ICE_CRACK), at, { volume = 0.45 })
		Audio.playAt(Audio.pick(Feel.SOUNDS.DEBRIS), at, {
			volume = 0.22,
			delay = Feel.TAIL_DELAY,
		})

		if payout > 0 then
			Popups.show(at, string.format("+$%d", payout), nil, math.min(1.8, 1 + broke * 0.08))
		end
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

local function onDiscovery(
	position: unknown,
	label: unknown,
	reward: unknown,
	hero: unknown,
	rarityKey: unknown
)
	if typeof(position) ~= "Vector3" or typeof(label) ~= "string" then
		return
	end
	local at = position :: Vector3
	local name = label :: string
	local payout = if typeof(reward) == "number" then reward else 0
	local isHero = hero == true

	-- The tier decides how loud this is. A common pot and a legendary mammoth
	-- used to get the same burst, the same shake and the same two seconds of
	-- label, which threw away the one moment the game has to feel like a jackpot.
	local tier = (if typeof(rarityKey) == "string" then Rarity.get(rarityKey) else nil) or Rarity.COMMON

	-- Deliberately delayed. The shatter that uncovered this is still playing;
	-- landing on top of it makes the two read as one muddled event instead of
	-- cause and consequence.
	task.delay(Feel.REVEAL_DELAY, function()
		Particles.reveal(at, tier.glow, tier.shards)
		CameraShake.impulse({
			duration = Feel.SHAKE_REVEAL.duration,
			magnitude = Feel.SHAKE_REVEAL.magnitude * tier.shake,
			roughness = Feel.SHAKE_REVEAL.roughness,
		})
		Audio.playAt(Audio.pick(Feel.SOUNDS.REVEAL), at, {
			volume = 0.7,
			-- Rarer finds ring lower, which is what makes them sound heavier.
			speed = 1.25 - tier.order * 0.06,
		})
		Popups.show(
			at + Vector3.new(0, 2, 0),
			string.format("+$%d", payout),
			tier.color,
			1.1 + tier.order * 0.18
		)
		Toast.show(name, payout, isHero, tier)
	end)
end

local function onFinale(label: unknown, found: unknown, total: unknown, seconds: unknown)
	local name = if typeof(label) == "string" then label else "The map"
	local f = if typeof(found) == "number" then found else 0
	local t = if typeof(total) == "number" then total else 0
	local s = if typeof(seconds) == "number" then seconds else 12

	CameraShake.impulse(Feel.SHAKE_REVEAL)
	Toast.finale(name, f, t, s)
end

function MeltEffects.start()
	CameraShake.start()
	Remotes.swingResult().OnClientEvent:Connect(onSwingResult)
	Remotes.discovery().OnClientEvent:Connect(onDiscovery)

	Remotes.claimResult().OnClientEvent:Connect(function(_, ok, reward, message)
		if ok == true then
			Toast.notice("QUEST COMPLETE", tostring(message), if typeof(reward) == "number" then reward else 0)
		end
		-- A refusal is silent on purpose. The only way to press a locked CLAIM
		-- is to race the server, and a banner saying "not finished" for that is
		-- noise rather than information.
	end)

	Remotes.rebirthResult().OnClientEvent:Connect(function(ok, message)
		Toast.notice(
			if ok == true then "REBIRTH" else "NOT YET",
			tostring(message),
			0,
			if ok == true then Color3.fromRGB(255, 200, 38) else Color3.fromRGB(224, 88, 88)
		)
	end)
	Remotes.finale().OnClientEvent:Connect(onFinale)
end

return MeltEffects
