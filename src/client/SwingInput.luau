--!strict
--[[
	SwingInput - turns a tool activation into a swing request.

	The only thing the client is trusted with is where it is aiming. The server
	starts the ray from its own copy of the character's head and enforces
	cooldown, stamina and plot ownership, so this file cannot cheat by design.

	It does predict locally, but only about *presentation*: the arm swing, the
	whoosh and the crosshair pulse fire the instant the button goes down rather
	than waiting for a round trip, because input-to-response past ~200ms reads as
	lag even at a locked frame rate. The break effects still wait for the server
	to say what actually happened.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Feel = require(Shared:WaitForChild("Feel"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local modules = script.Parent
local Audio = require(modules:WaitForChild("Audio"))
local Crosshair = require(modules:WaitForChild("Crosshair"))
local SwingAnimation = require(modules:WaitForChild("SwingAnimation"))

local SwingInput = {}

function SwingInput.start()
	local player = assert(Players.LocalPlayer, "SwingInput requires a LocalPlayer")
	local swing = Remotes.swing()

	local lastSwing = 0

	local function swingOrigin(): Vector3?
		local character = player.Character
		if not character then
			return nil
		end
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			return head.Position
		end
		local root = character.PrimaryPart
		return if root then root.Position else nil
	end

	-- A Tool moves between Backpack and Character on every equip, so we watch
	-- both containers and keep a set of the tools already hooked up. Without
	-- it, re-equipping would stack duplicate connections and one click would
	-- fire several swings.
	local hooked: { [Tool]: boolean } = {}

	local function watch(instance: Instance)
		if not instance:IsA("Tool") or instance:GetAttribute("MeltTool") ~= true then
			return
		end
		if hooked[instance] then
			return
		end
		hooked[instance] = true

		SwingAnimation.attachTrail(instance)

		instance.Activated:Connect(function()
			local camera = Workspace.CurrentCamera
			if not camera then
				return
			end

			-- Local gates, presentation only - the server re-checks both. Held
			-- fractionally shorter than the server's so a clock skew never makes
			-- the client swallow a swing the server would have allowed.
			local now = os.clock()
			if now - lastSwing < Config.SWING_COOLDOWN * 0.95 then
				return
			end

			local stamina = player:GetAttribute("Stamina")
			if typeof(stamina) == "number" and stamina < Config.STAMINA_PER_SWING then
				Crosshair.deny()
				return
			end

			lastSwing = now

			SwingAnimation.play(instance)
			Crosshair.pulse()

			local origin = swingOrigin()
			if origin then
				Audio.playAt(Audio.pick(Feel.SOUNDS.WHOOSH), origin, { volume = 0.3 })
			end

			swing:FireServer(camera.CFrame.LookVector)
		end)

		instance.Destroying:Connect(function()
			hooked[instance] = nil
		end)
	end

	local function watchContainer(container: Instance)
		container.ChildAdded:Connect(watch)
		for _, child in container:GetChildren() do
			watch(child)
		end
	end

	watchContainer(player:WaitForChild("Backpack"))

	player.CharacterAdded:Connect(function(character)
		SwingAnimation.bind(character)
		watchContainer(character)
	end)
	if player.Character then
		SwingAnimation.bind(player.Character)
		watchContainer(player.Character)
	end
end

return SwingInput
