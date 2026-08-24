--!strict
--[[
	SwingInput - turns a tool activation into a swing request.

	The only thing the client is trusted with is where it is aiming. The server
	starts the ray from its own copy of the character's head and enforces
	cooldown, stamina and plot ownership, so this file cannot cheat by design.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local SwingInput = {}

function SwingInput.start()
	local player = assert(Players.LocalPlayer, "SwingInput requires a LocalPlayer")
	local swing = Remotes.swing()

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

		instance.Activated:Connect(function()
			local camera = Workspace.CurrentCamera
			if not camera then
				return
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

	player.CharacterAdded:Connect(watchContainer)
	if player.Character then
		watchContainer(player.Character)
	end
end

return SwingInput
