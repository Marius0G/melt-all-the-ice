--!strict
--[[
	ShopService - buying upgrades.

	The client sends an upgrade key and nothing else. Cost, prerequisites and
	the current level are all read on this side, so the request carries no
	authority: a client that asks to buy the torch for nothing is refused by the
	same code path as one that genuinely cannot afford it.

	Buying can change what the player is holding and how much stamina they have,
	so the effects are re-applied here rather than left for the next spawn.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local modules = script.Parent
local PlayerStats = require(modules:WaitForChild("PlayerStats"))
local Progression = require(modules:WaitForChild("Progression"))
local ToolService = require(modules:WaitForChild("ToolService"))

local ShopService = {}

-- Push every derived number back onto the player. Called after a purchase and
-- on spawn, so there is one definition of "make the world match the levels".
function ShopService.apply(player: Player)
	PlayerStats.setStaminaLimits(
		player,
		Progression.staminaMax(player),
		Progression.staminaRegen(player)
	)
	PlayerStats.setFuelLimits(player, Progression.fuelMax(player), Progression.fuelRegen(player))
	ToolService.sync(player, Progression.ownedTools(player), Progression.equippedSkins(player))
end

local function onPurchase(player: Player, key: unknown)
	if typeof(key) ~= "string" then
		return
	end

	local stats = PlayerStats.get(player)
	if not stats then
		return
	end

	local ok, reason = Progression.tryPurchase(player, key :: string, stats.money, function(cost)
		return PlayerStats.spendMoney(player, cost)
	end)

	if ok then
		ShopService.apply(player)
	end

	Remotes.purchaseResult():FireClient(player, key, ok, reason)
end

local function onSkin(player: Player, action: unknown, key: unknown)
	if typeof(action) ~= "string" or typeof(key) ~= "string" then
		return
	end

	local stats = PlayerStats.get(player)
	if not stats then
		return
	end

	local ok, reason
	if action == "buy" then
		ok, reason = Progression.buySkin(player, key :: string, stats.money, function(cost)
			return PlayerStats.spendMoney(player, cost)
		end)
	elseif action == "equip" then
		ok, reason = Progression.selectSkin(player, key :: string)
	else
		ok, reason = false, "unknown action"
	end

	if ok then
		-- Rebuilds only the tool whose look actually changed.
		ShopService.apply(player)
	end

	Remotes.skinResult():FireClient(player, key, ok, reason)
end

function ShopService.init()
	Remotes.purchase().OnServerEvent:Connect(onPurchase)
	Remotes.skin().OnServerEvent:Connect(onSkin)
end

return ShopService
