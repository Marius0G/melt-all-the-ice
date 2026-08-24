--!strict
--[[
	Feel - every knob for how the game *presents* itself.

	Config.luau owns gameplay: HP, damage, money, stamina. This owns feedback:
	shake, particles, sound, timing, palette. The split follows AD-6 - the
	server decides state and reads Config, the client draws it and reads Feel.
	Nothing in here may ever change an outcome.

	The timing numbers are not arbitrary. Input to visible response wants to be
	under 50ms; past 200ms it reads as lag even at a locked 60fps. Hit-stop sits
	at 40-80ms across every source that quantifies it - at SWING_COOLDOWN 0.45
	anything longer than ~90ms gets reported as a bug rather than felt as weight.
]]

local Feel = {}

-- Cold world, warm rewards. Every payout colour is deliberately the complement
-- of every environment colour, so a "+$1" is legible against any background.
Feel.ICE_BRIGHT = Color3.fromRGB(235, 250, 255)
Feel.ICE_MID = Color3.fromRGB(150, 214, 255)
Feel.ICE_DEEP = Color3.fromRGB(90, 160, 210)
Feel.ICE_SHADOW = Color3.fromRGB(27, 76, 120)
Feel.MONEY = Color3.fromRGB(255, 200, 38)

-- Swing arc. The Trail default lifetime is 2.0, which smears into a ribbon that
-- never catches up with the swing; 0.18 reads as a single crisp arc.
Feel.TRAIL_LIFETIME = 0.18
Feel.TRAIL_WIDTH = 0.8

-- Particle counts. The contrast between these two numbers *is* the feedback -
-- the player reads "chipped" vs "shattered" from the size of the burst before
-- they read it from anything else.
Feel.SHARDS_ON_KILL = 22
Feel.SHARDS_ON_CHIP = 7
Feel.PUFF_ON_KILL = 5

-- Camera shake: magnitude, roughness (the frequency noise is sampled at), and
-- duration. Chip shake stays short because at 2.2 swings/second anything longer
-- overlaps itself into nausea.
Feel.SHAKE_CHIP = { magnitude = 0.35, roughness = 14, duration = 0.10 }
Feel.SHAKE_KILL = { magnitude = 1.10, roughness = 18, duration = 0.18 }
Feel.SHAKE_REVEAL = { magnitude = 2.60, roughness = 10, duration = 0.45 }
-- Rotation carries most of what reads as "shake"; position is a light seasoning.
Feel.SHAKE_POSITION_INFLUENCE = 0.15

Feel.HITSTOP = 0.055 -- kills only, never chips

-- 3D sound falloff. The Roblox default RollOffMaxDistance is 10000, which would
-- carry every swing across every plot on the server.
Feel.SOUND_MIN_DISTANCE = 8
Feel.SOUND_MAX_DISTANCE = 110
Feel.PITCH_MIN = 0.90
Feel.PITCH_MAX = 1.12

-- Floating reward numbers.
Feel.POPUP_RISE = 4.2
Feel.POPUP_TIME = 0.85
Feel.POPUP_MAX_DISTANCE = 90

-- Physical fragments. Particles are camera-facing sprites and cannot sell mass;
-- a few tumbling solids can. The global cap matters because six players mining
-- at once would otherwise hold ~80 unanchored parts between them.
Feel.SHARD_COUNT = 4
Feel.SHARD_FADE_AT = 0.9
Feel.SHARD_LIFETIME = 1.45
Feel.MAX_LIVE_SHARDS = 40

-- Nothing renders past this. Plots are PLOT_SPACING apart, so in practice this
-- means "your own cave and nothing else".
Feel.FX_MAX_DISTANCE = 160

--[[
	Sound assets.

	These are Roblox's own ProSoundEffects partner library - free, permanently
	hosted, and safe to depend on. Community uploads are not: most pre-2022
	community audio was deleted in the audio privacy purge, and what survives can
	be moderated away without notice.

	Do not reach for rbxasset://sounds/* paths. Exactly eleven sound files ship
	with the modern client, and none of the ones cited in older tutorials
	(swoosh.wav, unsheath.wav, SWITCH3.wav) are among them - they fail silently.
]]
Feel.SOUNDS = {
	-- Sharp transient, played on every hit.
	IMPACT = {
		"rbxassetid://9118629291",
		"rbxassetid://9118622424",
		"rbxassetid://9118628592",
		"rbxassetid://9118629156",
	},
	-- Body layer, kills only.
	ICE_CRACK = { "rbxassetid://9114858583" },
	-- Tail: debris settling, delayed slightly behind the impact.
	DEBRIS = { "rbxassetid://9118586292" },
	-- Fires client-side the instant the player clicks, before the server replies.
	WHOOSH = {
		"rbxassetid://9120972444",
		"rbxassetid://9120972321",
		"rbxassetid://9120972323",
		"rbxassetid://9120972457",
	},
	DRIP = {
		"rbxassetid://9126190182",
		"rbxassetid://9126190364",
		"rbxassetid://9114175929",
	},
}

-- Several of the above are long recordings; playing them whole would leave a
-- single break ringing for seconds. Clamped to the useful transient.
Feel.SOUND_CLAMP = {
	["rbxassetid://9114858583"] = 0.9,
	["rbxassetid://9118586292"] = 1.1,
}

Feel.TAIL_DELAY = 0.08

--[[
	Built-in particle textures, verified present in the shipping client.

	The .png entries are ordinary RGBA and are safe. sparkles_main.dds is the
	engine's own ParticleEmitter default, so it is the single most reliable one.
	The other *_main.dds files are legacy multi-channel pairs meant for the old
	Fire/Smoke instances and can render with unexpected alpha - avoided here.
]]
Feel.TEXTURES = {
	SPARKLE = "rbxasset://textures/particles/sparkles_main.dds",
	GLOW = "rbxasset://textures/glow.png",
	CIRCLE = "rbxasset://textures/whiteCircle.png",
	SQUARE = "rbxasset://textures/particles/SquareParticle.png",
}

return table.freeze(Feel)
