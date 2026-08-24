--!strict
--[[
	Shards - a few tumbling ice fragments per break.

	Particles are camera-facing sprites with no volume, so they cannot sell mass.
	Three or four real solids can, and the eye does not need more than that.

	Client-only, like every cosmetic here. That is not an optimisation, it is the
	architecture: the outcome was already decided on the server, so a fragment
	spawned here cannot influence anything. It also costs no replication and no
	server-side physics.

	CanQuery = false is load-bearing. A fragment that answers spatial queries can
	land between the player and the ice and swallow the next melt raycast, which
	shows up as a swing that mysteriously did nothing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Feel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Feel"))

local Shards = {}

local SIZES = {
	Vector3.new(0.7, 0.5, 0.6),
	Vector3.new(0.5, 0.7, 0.4),
	Vector3.new(0.6, 0.4, 0.7),
	Vector3.new(0.4, 0.5, 0.5),
}

-- Oldest-first queue. Six players mining at once would otherwise hold roughly
-- eighty unanchored parts between them.
local live: { BasePart } = {}

local function retire(part: BasePart)
	local index = table.find(live, part)
	if index then
		table.remove(live, index)
	end
	if part.Parent then
		part:Destroy()
	end
end

local function trim()
	while #live > Feel.MAX_LIVE_SHARDS do
		local oldest = table.remove(live, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end
end

function Shards.burst(position: Vector3, normal: Vector3)
	local camera = Workspace.CurrentCamera
	if not camera or (position - camera.CFrame.Position).Magnitude > Feel.FX_MAX_DISTANCE then
		return
	end

	for index = 1, Feel.SHARD_COUNT do
		local part = Instance.new("Part")
		part.Size = SIZES[(index - 1) % #SIZES + 1]
		part.Material = Enum.Material.Glacier
		part.Color = Feel.ICE_MID
		part.Transparency = 0.15
		part.Anchored = false
		part.CanCollide = true
		part.CanQuery = false -- see the note at the top; this one matters
		part.CanTouch = false
		part.CastShadow = false
		part.CollisionGroup = "Shards"
		part.CFrame = CFrame.new(position + normal * 0.5)
			* CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28)
		part.AssemblyLinearVelocity = normal * math.random(18, 34)
			+ Vector3.new(math.random(-9, 9), math.random(6, 16), math.random(-9, 9))
		part.AssemblyAngularVelocity =
			Vector3.new(math.random(-14, 14), math.random(-14, 14), math.random(-14, 14))
		-- Parented to Workspace directly, never under the plot folder: a
		-- client instance living under a server-created one streams out with it.
		part.Parent = Workspace

		table.insert(live, part)

		task.delay(Feel.SHARD_FADE_AT, function()
			if part.Parent then
				TweenService
					:Create(part, TweenInfo.new(Feel.SHARD_LIFETIME - Feel.SHARD_FADE_AT), {
						Transparency = 1,
					})
					:Play()
			end
		end)
		task.delay(Feel.SHARD_LIFETIME, function()
			retire(part)
		end)
	end

	trim()
end

return Shards
