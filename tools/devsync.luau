--!nocheck
--[[
	Studio half of devsync. Run through the Studio MCP's execute_luau in the
	Edit datamodel; pulls src/ from tools/devsync.py and writes it into the
	DataModel exactly where default.project.json says it belongs.

	Not shipped game code - it never runs in a live server. Kept in the repo so
	the sync loop is reproducible rather than improvised each session.
]]

local HttpService = game:GetService("HttpService")

local PORT = 8777

HttpService.HttpEnabled = true

local function container(path: string): Instance
	local node: Instance = game
	for segment in string.gmatch(path, "[^/]+") do
		local child = node:FindFirstChild(segment)
		if not child then
			-- Services already exist; anything deeper is ours to create.
			child = Instance.new("Folder")
			child.Name = segment
			child.Parent = node
		end
		node = child
	end
	return node
end

local body = HttpService:GetAsync(string.format("http://127.0.0.1:%d/", PORT))
local entries = HttpService:JSONDecode(body)

local written, replaced = 0, 0
for _, entry in entries do
	local parent = container(entry.path)
	local existing = parent:FindFirstChild(entry.name)

	-- Class can change between runs (a module becoming a Script), so replace
	-- rather than assume the existing instance is still the right type.
	if existing and existing.ClassName ~= entry.class then
		existing:Destroy()
		existing = nil
		replaced += 1
	end

	local target = existing
	if not target then
		target = Instance.new(entry.class)
		target.Name = entry.name
		target.Parent = parent
	end
	;(target :: any).Source = entry.source
	written += 1
end

return string.format("devsync: wrote %d modules (%d reclassed)", written, replaced)
