--!strict
--[[
	Combo - the reward for not stopping.

	Every swing that connects with ice extends a streak; a gap longer than the
	window drops it back to nothing. Connecting, not breaking - a 30 HP chunk
	takes three swings from the stone, and the streak has to survive across them.

	The streak multiplies chunk income, so the satisfying thing to do (keep
	swinging at the face in front of you) is also the profitable thing, and
	stopping to wander costs you something real.

	Deliberately forgiving in one direction and strict in the other: a swing that
	*misses* does not break the streak, because punishing aim on a moving camera
	feels like the game is cheating. Only time breaks it. That also means the
	stamina and fuel gates are what actually cap a streak, which is the right
	place for the limit to live - it is already the thing tuned to pace melting.

	Transient by design. A streak is a thing you are doing right now, not a thing
	you own, so nothing here is saved and leaving drops it.

	The count is mirrored onto a Player attribute for the HUD. Attributes
	replicate server -> client and are not client-writable, which is the same
	trick money and stamina already use.
]]

local Players = game:GetService("Players")

local Combo = {}

-- Seconds of no connecting swing before the streak lapses. It has to clear the
-- slowest tool's own rhythm or the streak is unreachable rather than merely
-- hard: the stone swings about every two seconds once stamina is the limit, so
-- anything under about four seconds means the starting tool can never hold one.
local WINDOW = 5.0

-- Each step of the streak is worth this much, up to CAP steps. At 0.02 and 50
-- the ceiling is double income, which is a real prize without making the first
-- few hits feel worthless by comparison.
local STEP = 0.02
local CAP = 50

Combo.WINDOW = WINDOW
Combo.CAP = CAP

type Entry = {
	count: number,
	last: number,
}

local entries: { [Player]: Entry } = {}

local function push(player: Player, count: number)
	player:SetAttribute("Combo", count)
end

local function multiplierFor(count: number): number
	return 1 + math.min(count, CAP) * STEP
end

Combo.multiplierFor = multiplierFor

function Combo.add(player: Player)
	entries[player] = { count = 0, last = 0 }
	push(player, 0)
end

function Combo.remove(player: Player)
	entries[player] = nil
end

-- Called when a swing destroyed at least one chunk. Returns the multiplier to
-- apply to that swing's income, and the streak it now stands at.
function Combo.hit(player: Player): (number, number)
	local entry = entries[player]
	if not entry then
		return 1, 0
	end

	local now = os.clock()
	if now - entry.last > WINDOW then
		entry.count = 0
	end
	entry.count += 1
	entry.last = now
	push(player, entry.count)

	return multiplierFor(entry.count), entry.count
end

function Combo.get(player: Player): number
	local entry = entries[player]
	if not entry then
		return 0
	end
	if os.clock() - entry.last > WINDOW then
		return 0
	end
	return entry.count
end

-- Drop a streak that has gone quiet. Polled rather than timed per player: one
-- loop for the whole server is cheaper than a task.delay per swing, and the
-- attribute only has to be right to within a tick for the HUD to look correct.
function Combo.start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for player, entry in entries do
				if entry.count > 0 and now - entry.last > WINDOW then
					entry.count = 0
					push(player, 0)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		Combo.remove(player)
	end)
end

return Combo
