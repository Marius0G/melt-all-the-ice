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

-- Server -> client, owner only. Fired when the last of the ice over a buried
-- find comes away: (position, label, reward, hero, rarityKey).
function Remotes.discovery(): RemoteEvent
	return event("Discovery")
end

-- Client -> server. Payload is an upgrade key and nothing else; cost and
-- eligibility are decided entirely on the server.
function Remotes.purchase(): RemoteEvent
	return event("Purchase")
end

-- Server -> client: (key, ok, reason). The reason exists so the shop can say
-- why a purchase was refused rather than appearing to ignore the click.
function Remotes.purchaseResult(): RemoteEvent
	return event("PurchaseResult")
end

-- Server -> client: (found, total, resetDelay). The map is clear.
function Remotes.finale(): RemoteEvent
	return event("Finale")
end

-- Client -> server: (action, key) where action is "buy" or "equip". Cost and
-- ownership are decided server-side; the payload carries no authority.
function Remotes.skin(): RemoteEvent
	return event("Skin")
end

-- Server -> client: (key, ok, reason).
function Remotes.skinResult(): RemoteEvent
	return event("SkinResult")
end

-- Client -> server: a quest key to claim. Completion and the reward are both
-- decided server-side; the key carries no authority.
function Remotes.claimQuest(): RemoteEvent
	return event("ClaimQuest")
end

-- Server -> client: (key, ok, reward, message).
function Remotes.claimResult(): RemoteEvent
	return event("ClaimResult")
end

-- Client -> server. No payload at all: there is only one thing to rebirth into
-- and eligibility is the server's to decide.
function Remotes.rebirth(): RemoteEvent
	return event("Rebirth")
end

-- Server -> client: (ok, message).
function Remotes.rebirthResult(): RemoteEvent
	return event("RebirthResult")
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
	Remotes.discovery()
	Remotes.purchase()
	Remotes.purchaseResult()
	Remotes.finale()
	Remotes.skin()
	Remotes.skinResult()
	Remotes.claimQuest()
	Remotes.claimResult()
	Remotes.rebirth()
	Remotes.rebirthResult()
end

return Remotes
