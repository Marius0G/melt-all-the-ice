--!strict
--[[
	Codex - what you have done, as opposed to what you can buy.

	Three tabs: the collection log, today's quests, and rebirth. Deliberately a
	separate panel from the skill tree rather than three more tabs on it. The
	tree is "spend money"; this is "look at progress". Five tabs on one panel
	would have made both harder to find, and it keeps a working six-hundred-line
	file from growing another three views.

	Everything it renders comes off Player attributes, which the server owns and
	the client cannot write - the same rule the HUD follows. The collection log
	and the quest state arrive as one packed string each rather than an attribute
	per entry: nineteen attributes changing on every swing is nineteen
	replication messages, and as a string it is one.

	Both actions - claiming a quest, rebirthing - send a key or nothing at all.
	Eligibility and reward are decided server-side, so the panel cannot lie about
	either; a refusal comes back as a message and is shown as-is.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapDefs = require(Shared:WaitForChild("MapDefs"))
local PropAssets = require(Shared:WaitForChild("PropAssets"))
local Quests = require(Shared:WaitForChild("Quests"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UITheme = require(script.Parent:WaitForChild("UITheme"))

local Codex = {}

local player: Player
local open = false
local refresh: () -> ()

-- ---------------------------------------------------------------------------
-- attribute parsing
-- ---------------------------------------------------------------------------

-- "Chest=2,Pot=1" -> { Chest = 2, Pot = 1 }
local function parseCounts(raw: unknown): { [string]: number }
	local out: { [string]: number } = {}
	if typeof(raw) ~= "string" then
		return out
	end
	for entry in string.gmatch(raw, "[^,]+") do
		local key, value = string.match(entry, "^(.-)=(%d+)$")
		if key and value then
			out[key] = tonumber(value) or 0
		end
	end
	return out
end

-- "chunks120=6,rare5=0!" -> progress and claimed. A trailing "!" marks claimed.
local function parseQuests(raw: unknown): ({ [string]: number }, { [string]: boolean })
	local progress: { [string]: number } = {}
	local claimed: { [string]: boolean } = {}
	if typeof(raw) ~= "string" then
		return progress, claimed
	end
	for entry in string.gmatch(raw, "[^,]+") do
		local key, value, mark = string.match(entry, "^(.-)=(%d+)(!?)$")
		if key and value then
			progress[key] = tonumber(value) or 0
			claimed[key] = mark == "!"
		end
	end
	return progress, claimed
end

-- ---------------------------------------------------------------------------
-- build
-- ---------------------------------------------------------------------------

local function buildFindTile(parent: Instance, def: PropAssets.PropDef, order: number): (Frame, TextLabel)
	local tier = Rarity.forReward(def.reward, def.hero)

	local tile = UITheme.panel(parent, def.key, true)
	tile.Size = UDim2.new(0, 148, 0, 92)
	tile.LayoutOrder = order

	-- The rim carries the rarity, which is the whole reason the log is worth
	-- looking at: a wall of tiles where three are gold reads instantly.
	local rim = UITheme.outline(tile, 3, tier.color)
	rim.Name = "Rim"

	-- A swatch of the prop's own colour, standing in for the model. A
	-- ViewportFrame each would look better and would mean sixteen mesh fetches
	-- on the client for a panel that is usually shut.
	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.Size = UDim2.fromOffset(34, 34)
	swatch.Position = UDim2.fromOffset(10, 10)
	swatch.BackgroundColor3 = def.color
	swatch.BorderSizePixel = 0
	UITheme.corner(swatch, 10)
	UITheme.outline(swatch, 2)
	swatch.Parent = tile

	local name = UITheme.label(tile, def.label, 13)
	name.Size = UDim2.new(1, -56, 0, 34)
	name.Position = UDim2.fromOffset(52, 10)
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Top

	local rank = UITheme.label(tile, tier.label, 11, UITheme.DISPLAY)
	rank.Size = UDim2.new(1, -20, 0, 14)
	rank.Position = UDim2.fromOffset(10, 50)
	rank.TextColor3 = tier.color

	local count = UITheme.label(tile, "", 15, UITheme.NUMBER)
	count.Name = "Count"
	count.Size = UDim2.new(1, -20, 0, 18)
	count.Position = UDim2.fromOffset(10, 66)

	return tile, count
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Codex"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local toggle = UITheme.button(gui, "Toggle", "COLLECTION", UITheme.COLD)
	toggle.Size = UDim2.fromOffset(158, 44)
	toggle.Position = UDim2.new(1, -174, 1, -124)
	toggle.AnchorPoint = Vector2.new(0, 0)

	local panel = UITheme.panel(gui, "Panel")
	panel.Size = UDim2.fromOffset(560, 430)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	UITheme.goldStroke(panel, 2)

	local title = UITheme.label(panel, "COLLECTION", 24, UITheme.DISPLAY)
	title.Size = UDim2.new(1, -140, 0, 34)
	title.Position = UDim2.fromOffset(18, 12)
	title.TextColor3 = UITheme.GOLD

	local close = UITheme.button(panel, "Close", "X", UITheme.BAD)
	close.Size = UDim2.fromOffset(38, 38)
	close.Position = UDim2.new(1, -50, 0, 12)

	-- tabs -------------------------------------------------------------------
	local tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.Size = UDim2.new(1, -36, 0, 36)
	tabBar.Position = UDim2.fromOffset(18, 54)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = panel

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabBar

	local TABS = {
		{ key = "log", label = "FINDS" },
		{ key = "quests", label = "QUESTS" },
		{ key = "rebirth", label = "REBIRTH" },
	}
	local tabButtons: { [string]: TextButton } = {}
	for order, tab in TABS do
		local button = UITheme.button(tabBar, tab.key, tab.label, UITheme.PANEL_LIGHT_TOP)
		button.Size = UDim2.fromOffset(120, 36)
		button.LayoutOrder = order
		tabButtons[tab.key] = button
	end

	local function view(name: string): ScrollingFrame
		local frame = Instance.new("ScrollingFrame")
		frame.Name = name
		frame.Size = UDim2.new(1, -36, 1, -110)
		frame.Position = UDim2.fromOffset(18, 100)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.ScrollBarThickness = 5
		frame.ScrollBarImageColor3 = UITheme.GOLD_DARK
		frame.CanvasSize = UDim2.new()
		frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		frame.ScrollingDirection = Enum.ScrollingDirection.Y
		frame.Visible = false
		frame.Parent = panel
		return frame
	end

	-- FINDS ------------------------------------------------------------------
	local logView = view("Log")
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(148, 92)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = logView

	local counts: { [string]: TextLabel } = {}
	local tiles: { [string]: Frame } = {}
	-- Rarest first, so the tiles worth chasing are at the top.
	local ordered = table.clone(PropAssets.DEFS)
	table.sort(ordered, function(a, b)
		local ta = Rarity.forReward(a.reward, a.hero)
		local tb = Rarity.forReward(b.reward, b.hero)
		if ta.order ~= tb.order then
			return ta.order > tb.order
		end
		return a.label < b.label
	end)
	for order, def in ordered do
		local tile, count = buildFindTile(logView, def, order)
		tiles[def.key] = tile
		counts[def.key] = count
	end

	-- QUESTS -----------------------------------------------------------------
	local questView = view("Quests")
	local questLayout = Instance.new("UIListLayout")
	questLayout.Padding = UDim.new(0, 10)
	questLayout.SortOrder = Enum.SortOrder.LayoutOrder
	questLayout.Parent = questView

	type QuestRow = {
		def: Quests.QuestDef,
		fill: Frame,
		progress: TextLabel,
		claim: TextButton,
	}
	local questRows: { QuestRow } = {}

	for order, def in Quests.active() do
		local row = UITheme.panel(questView, def.key, true)
		row.Size = UDim2.new(1, -8, 0, 74)
		row.LayoutOrder = order

		local label = UITheme.label(row, def.label, 16, UITheme.DISPLAY)
		label.Size = UDim2.new(1, -140, 0, 22)
		label.Position = UDim2.fromOffset(14, 10)

		local reward = UITheme.label(row, string.format("$%d", def.reward), 15, UITheme.NUMBER)
		reward.Size = UDim2.fromOffset(90, 22)
		reward.Position = UDim2.fromOffset(14, 44)
		reward.TextColor3 = UITheme.GOLD

		local track, fill = UITheme.bar(row, "Track", UITheme.GOOD)
		track.Size = UDim2.new(1, -270, 0, 18)
		track.Position = UDim2.fromOffset(112, 46)

		-- Sits inside the track rather than beside it. Beside it, the label and
		-- the bar fought for the same strip and overlapped at every panel width.
		local progress = UITheme.label(track, "", 12, UITheme.NUMBER)
		progress.Size = UDim2.fromScale(1, 1)
		progress.TextXAlignment = Enum.TextXAlignment.Center
		progress.ZIndex = 3
		progress.TextColor3 = UITheme.TEXT

		local claim = UITheme.button(row, "Claim", "CLAIM", UITheme.GOOD)
		claim.Size = UDim2.fromOffset(110, 40)
		claim.Position = UDim2.new(1, -124, 0, 17)

		local key = def.key
		claim.MouseButton1Click:Connect(function()
			Remotes.claimQuest():FireServer(key)
		end)

		table.insert(questRows, {
			def = def,
			fill = fill,
			progress = progress,
			claim = claim,
		})
	end

	-- REBIRTH ----------------------------------------------------------------
	local rebirthView = view("Rebirth")
	local rebirthLayout = Instance.new("UIListLayout")
	rebirthLayout.Padding = UDim.new(0, 12)
	rebirthLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rebirthLayout.Parent = rebirthView

	local card = UITheme.panel(rebirthView, "Card", true)
	card.Size = UDim2.new(1, -8, 0, 176)
	card.LayoutOrder = 1

	local rebirthCount = UITheme.label(card, "", 30, UITheme.DISPLAY)
	rebirthCount.Size = UDim2.new(1, -28, 0, 38)
	rebirthCount.Position = UDim2.fromOffset(14, 12)
	rebirthCount.TextColor3 = UITheme.GOLD

	local rebirthBonus = UITheme.label(card, "", 15, UITheme.NUMBER)
	rebirthBonus.Size = UDim2.new(1, -28, 0, 22)
	rebirthBonus.Position = UDim2.fromOffset(14, 52)
	rebirthBonus.TextColor3 = UITheme.GOOD

	local rebirthBlurb = UITheme.label(
		card,
		"Start again from the cave. You keep your skins, your collection and every"
			.. " rebirth bonus. You lose your money, your upgrades and your tools.",
		13
	)
	rebirthBlurb.Size = UDim2.new(1, -28, 0, 46)
	rebirthBlurb.Position = UDim2.fromOffset(14, 78)
	rebirthBlurb.TextWrapped = true
	rebirthBlurb.TextColor3 = UITheme.TEXT_DIM
	rebirthBlurb.TextYAlignment = Enum.TextYAlignment.Top

	local rebirthButton = UITheme.button(card, "Do", "REBIRTH", UITheme.GOLD)
	rebirthButton.Size = UDim2.fromOffset(160, 42)
	rebirthButton.Position = UDim2.new(0, 14, 1, -54)
	rebirthButton.MouseButton1Click:Connect(function()
		Remotes.rebirth():FireServer()
	end)

	local rebirthNote = UITheme.label(card, "", 13, UITheme.NUMBER)
	rebirthNote.Size = UDim2.new(1, -196, 0, 42)
	rebirthNote.Position = UDim2.new(0, 186, 1, -54)
	rebirthNote.TextWrapped = true
	rebirthNote.TextColor3 = UITheme.TEXT_DIM

	-- refresh ----------------------------------------------------------------
	local current = "log"

	function refresh()
		local collection = parseCounts(player:GetAttribute("Collection"))
		local seen = 0
		for key, label in counts do
			local had = collection[key] or 0
			if had > 0 then
				seen += 1
				label.Text = string.format("x%d", had)
				label.TextColor3 = UITheme.TEXT
				tiles[key].BackgroundTransparency = 0
			else
				label.Text = "not found"
				label.TextColor3 = UITheme.TEXT_OFF
				-- Undiscovered tiles fade rather than vanish, so the log always
				-- shows how much is left to find.
				tiles[key].BackgroundTransparency = 0.55
			end
		end
		title.Text = if current == "log"
			then string.format("FINDS  %d / %d", seen, #PropAssets.DEFS)
			elseif current == "quests" then "TODAY'S QUESTS"
			else "REBIRTH"

		local progress, claimed = parseQuests(player:GetAttribute("Quests"))
		for _, row in questRows do
			local at = progress[row.def.key] or 0
			local done = at >= row.def.target
			local isClaimed = claimed[row.def.key] == true

			TweenService:Create(row.fill, UITheme.TWEEN, {
				Size = UDim2.fromScale(math.clamp(at / row.def.target, 0, 1), 1),
			}):Play()
			row.progress.Text = string.format("%d / %d", math.min(at, row.def.target), row.def.target)

			local ready = done and not isClaimed
			row.claim.Text = if isClaimed then "CLAIMED" elseif done then "CLAIM" else "LOCKED"
			row.claim.Active = ready
			row.claim.TextColor3 = if ready then UITheme.TEXT else UITheme.TEXT_OFF
			-- The gradient multiplies the background colour, so draining that is
			-- what actually greys the button out. Transparency alone left a
			-- locked button still reading bright green, which reads as "go".
			row.claim.BackgroundColor3 = if ready then Color3.new(1, 1, 1) else Color3.fromRGB(96, 104, 120)
		end

		local rebirths = player:GetAttribute("Rebirths")
		local count = if typeof(rebirths) == "number" then rebirths else 0
		rebirthCount.Text = string.format("REBIRTH %d", count)
		rebirthBonus.Text = string.format("+%d%% income, permanently", count * 25)

		-- The button only reports eligibility; the server decides it. Finished is
		-- set when the last map is actually cleared, which is not the same as
		-- having unlocked it.
		local last = MapDefs.DEFS[#MapDefs.DEFS]
		local ready = player:GetAttribute("Finished") == true
		rebirthButton.Active = ready
		rebirthButton.BackgroundColor3 = if ready then Color3.new(1, 1, 1) else Color3.fromRGB(96, 104, 120)
		rebirthButton.TextColor3 = if ready then UITheme.TEXT else UITheme.TEXT_OFF
		rebirthNote.Text = if ready
			then string.format("You cleared %s. Go again for +25%% income.", last.label)
			else string.format("Clear %s to unlock rebirth.", last.label)
	end

	local function setTab(name: string)
		current = name
		logView.Visible = name == "log"
		questView.Visible = name == "quests"
		rebirthView.Visible = name == "rebirth"
		for key, button in tabButtons do
			button.TextColor3 = if key == name then UITheme.GOLD else UITheme.TEXT_DIM
			button.BackgroundTransparency = if key == name then 0 else 0.45
		end
		refresh()
	end

	for _, tab in TABS do
		local key = tab.key
		tabButtons[key].MouseButton1Click:Connect(function()
			setTab(key)
		end)
	end
	setTab("log")

	local function setOpen(value: boolean)
		open = value
		panel.Visible = value
		if value then
			refresh()
			UITheme.pop(panel, 0.85)
		end
	end

	toggle.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)
	close.MouseButton1Click:Connect(function()
		setOpen(false)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.C then
			setOpen(not open)
		elseif input.KeyCode == Enum.KeyCode.Escape and open then
			setOpen(false)
		end
	end)

	-- Anything the server changes should show immediately if the panel is open.
	for _, name in { "Collection", "Quests", "Rebirths", "Finished", "CurrentMap" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if open then
				refresh()
			end
		end)
	end

	Remotes.claimResult().OnClientEvent:Connect(function()
		if open then
			refresh()
		end
	end)
	Remotes.rebirthResult().OnClientEvent:Connect(function()
		if open then
			refresh()
		end
	end)
end

function Codex.start()
	player = assert(Players.LocalPlayer, "Codex requires a LocalPlayer")
	build()
end

return Codex
