--!strict
--[[
	Remotes - single source of truth for remote instances.

	The server creates them on demand; the client waits for them. Numeric state
	the HUD reads - money, stamina, progress - travels as Player attributes
	instead, which replicate automatically and cannot be written from the client.
	Remotes are only for things attributes cannot carry: an action going up, and
	a one-off event coming back down.
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

-- Server -> client, owner only. Tells the client what its swing actually did so
-- it can play the matching effects: (position, normal, destroyed, hpRatio).
--
-- Fired with FireClient rather than FireAllClients on purpose. Plots sit
-- PLOT_SPACING apart with a smaller streaming radius (AD-2), so no player can
-- ever see another player's ice - broadcasting would spend bandwidth on effects
-- that are guaranteed to be off-screen.
function Remotes.swingResult(): RemoteEvent
	return event("SwingResult")
end

-- Create every remote up front, before any client can ask for one.
--
-- The lazy path above is fine on the server, which creates on demand, but the
-- client blocks on WaitForChild. A remote the server only builds the first time
-- it fires deadlocks any client that listens for it at startup - and a listener
-- is exactly what a server -> client event is for. Add new remotes here too.
function Remotes.initServer()
	Remotes.swing()
	Remotes.swingResult()
end

return Remotes
