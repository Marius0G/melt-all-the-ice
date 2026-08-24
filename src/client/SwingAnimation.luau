--!strict
--[[
	SwingAnimation - the arm swing, the arc, and the hit-stop.

	Uses Roblox's own built-in tool-slash animation by asset id. It is a public
	Roblox-owned asset, so it costs no upload and loads for anyone, and unlike
	the three-line `toolanim` trick it hands back an AnimationTrack - which is
	what makes both hit-stop and per-tool swing speed possible later.

	`toolanim` is still the fallback: Roblox's default Animate script watches the
	equipped tool for a StringValue of that name, plays the matching built-in
	animation, and deletes the marker itself. If LoadAnimation ever fails we
	still get a swing.

	Procedurally driving Motor6D.C0 was the third option and is rejected: C0
	writes do not replicate, so nobody but the swinging player would see it, and
	it fights the default Animate script for the same joint every frame.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Feel = require(Shared:WaitForChild("Feel"))

local SwingAnimation = {}

local R15_SLASH = "rbxassetid://522635514"
local R6_SLASH = "rbxassetid://129967390"

local track: AnimationTrack? = nil
local trail: Trail? = nil

-- Called on every spawn: the Animator is recreated with the character, so a
-- cached track from the previous life is dead.
function SwingAnimation.bind(character: Model)
	track = nil

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
		or humanoid:WaitForChild("Animator", 5) :: Animator?
	if not animator then
		return
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = if humanoid.RigType == Enum.HumanoidRigType.R15
		then R15_SLASH
		else R6_SLASH

	-- LoadAnimation always allocates a new track, so it is called once here and
	-- the result reused for every swing rather than per click.
	local ok, loaded = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if ok and loaded then
		loaded.Priority = Enum.AnimationPriority.Action -- must beat the walk cycle
		loaded.Looped = false
		track = loaded
	end
end

-- A Trail with no texture renders as a plain colour ribbon, which is all a
-- swing arc needs and costs no uploaded asset.
function SwingAnimation.attachTrail(tool: Tool)
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end
	if handle:FindFirstChild("SwingTrail") then
		return
	end

	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 0, Feel.TRAIL_WIDTH)
	top.Parent = handle

	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, 0, -Feel.TRAIL_WIDTH)
	bottom.Parent = handle

	local created = Instance.new("Trail")
	created.Name = "SwingTrail"
	created.Attachment0 = top
	created.Attachment1 = bottom
	created.Lifetime = Feel.TRAIL_LIFETIME
	created.MinLength = 0.05
	created.FaceCamera = true
	created.LightEmission = 0.6
	created.Color = ColorSequence.new(Feel.ICE_BRIGHT)
	created.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	created.Enabled = false
	created.Parent = handle
	trail = created
end

function SwingAnimation.play(tool: Tool?)
	if trail then
		trail.Enabled = true
		task.delay(Feel.TRAIL_LIFETIME + 0.04, function()
			if trail then
				trail.Enabled = false
			end
		end)
	end

	local current = track
	if current then
		current:Stop(0)
		-- Scale the clip to land inside the swing cooldown. fadeTime 0.05 rather
		-- than the 0.1 default: at a 450ms cadence the default blend eats a fifth
		-- of the animation and smears the impact frame.
		local speed = 1
		if current.Length > 0 then
			speed = current.Length / (Config.SWING_COOLDOWN * 0.85)
		end
		current:Play(0.05, 1, speed)
		return
	end

	if tool then
		local marker = Instance.new("StringValue")
		marker.Name = "toolanim"
		marker.Value = "Slash"
		marker.Parent = tool
	end
end

-- Freezing the swing for a few frames on impact is the Roblox-shaped version of
-- hit-stop: the world cannot be paused in multiplayer, but the animation can.
-- Kills only - doing it on every chip at this cadence reads as lag.
function SwingAnimation.hitStop()
	local current = track
	if not current or not current.IsPlaying then
		return
	end
	local restore = current.Speed
	current:AdjustSpeed(0)
	task.delay(Feel.HITSTOP, function()
		if current.IsPlaying then
			current:AdjustSpeed(restore)
		end
	end)
end

return SwingAnimation
