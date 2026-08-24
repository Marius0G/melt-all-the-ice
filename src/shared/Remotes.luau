--!strict
--[[
	Remotes - single source of truth for remote instances.

	The server creates them on demand; the client waits for them. Only one
	remote exists in this slice: everything the server reports back to the
	client travels as Player attributes instead, which replicate automatically
	and cannot be written from the client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"

local function container(): Instance
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			local created = Instance.new("Folder")
			created.Name = FOLDER_NAME
			created.Parent = ReplicatedStorage
			return created
		end
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function event(name: string): RemoteEvent
	local parent = container()
	if RunService:IsServer() then
		local existing = parent:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = parent
		return remote
	end
	return parent:WaitForChild(name) :: RemoteEvent
end

-- Client -> server. Payload is the player's aim direction and nothing else.
function Remotes.swing(): RemoteEvent
	return event("Swing")
end

return Remotes
