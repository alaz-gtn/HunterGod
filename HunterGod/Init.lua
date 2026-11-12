local addonName, ns = ...
local L = ns.L

-- Settings: whatever is missing from the saved ones is filled in from here
local defaults = {
	-- World map
	arrows = true,
	bullets = true,
	trainers = true,
	foodVendors = true,
	allFactions = false,
	minimap = true,
	continent = true,
	onlyHunter = true,
	learned = {},
	notAmmo = {},
	names = {},
	-- Range to the target
	range = {
		enabled = true,
		meleeWarning = true,
		meleeAlpha = 50, -- % opacity of the MELEE RANGE warning
		threat = true,
		threatPct = 90, -- warn from this % of the pet's threat, as the game's tooltip shows it
		onlyCombat = false,
		style = "text", -- text | icon | both
		anchor = "plate", -- plate | free
		units = "yards", -- yards | meters
		display = "number", -- number | bracket
		font = "fredoka", -- fredoka | changa | game
		showState = false,
		farGlow = true, -- light blue and glowing in the last 5 yards of your reach
		textSize = 26,
		colors = {
			ranged = { r = 0.3, g = 1, b = 0.3 },
			far = { r = 0.45, g = 0.8, b = 1 },
			melee = { r = 1, g = 0.82, b = 0 },
			dead = { r = 1, g = 0.2, b = 0.2 },
			out = { r = 0.6, g = 0.6, b = 0.6 },
		},
	},
	aspect = { enabled = true, travel = true, missing = true, preferred = "hawk", text = false },
	traps = { enabled = true, freeze = true },
	lowAmmo = { enabled = true, threshold = 1000, merchant = true },
	petFood = { enabled = true, bar = true, hideInCombat = true, low = 10, merchant = true },
	growl = { enabled = true, groups = false, miss = true },
	petStatus = { happy = true, health = true, healthPct = 40, wrath = true },
	petToast = { level = true, training = true, sound = true },
	minimapButton = { hide = false, angle = 215 },
	positions = {},
}

local function Fill(saved, default)
	for k, v in pairs(default) do
		if saved[k] == nil then
			saved[k] = type(v) == "table" and Fill({}, v) or v
		elseif type(v) == "table" and type(saved[k]) == "table" then
			Fill(saved[k], v)
		end
	end
	return saved
end

function ns.Print(msg)
	print(L.PREFIX .. msg)
end

-- Forever hides some values from addons during combat
function ns.IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

function ns.IsHunter()
	return select(2, UnitClass("player")) == "HUNTER"
end

-- Each module adds the function that redraws it; the options call them all
ns.refreshers = {}
function ns.RefreshAll()
	for _, refresh in ipairs(ns.refreshers) do
		refresh()
	end
end

-- Displays the player can drag around while they are unlocked
ns.movers = {}
ns.unlocked = false

function ns.PlaceFrame(frame)
	local p = ns.db.positions[frame.moverKey]
	-- Some displays sit on something of the game's until you move them
	if not p and frame.placeDefault then
		frame:placeDefault()
		return
	end
	p = p or frame.defaultPoint
	frame:ClearAllPoints()
	frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

-- While unlocked each display gets a green box on top of it, big enough to grab
-- even when the display is small or full of buttons
local function SizeHandle(frame)
	local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
	if ns.IsSecret(w) or ns.IsSecret(h) then w, h = 0, 0 end
	frame.mover:SetSize(max(w + 16, 140), max(h + 16, 44))
end

function ns.Movable(frame, key, defaultPoint, label)
	frame.moverKey = key
	frame.defaultPoint = defaultPoint
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	local handle = CreateFrame("Frame", nil, frame)
	handle:SetPoint("CENTER")
	handle:SetFrameLevel(frame:GetFrameLevel() + 20)
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function()
		if not InCombatLockdown() then frame:StartMoving() end
	end)
	handle:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local point, _, relPoint, x, y = frame:GetPoint()
		if x and not ns.IsSecret(x) then
			ns.db.positions[key] = { point, relPoint, x, y }
		end
	end)
	local box = handle:CreateTexture(nil, "BACKGROUND")
	box:SetAllPoints()
	box:SetColorTexture(0.3, 0.8, 0.3, 0.35)
	local name = handle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	name:SetPoint("CENTER")
	name:SetText(label)
	handle:Hide()
	frame.mover = handle
	ns.movers[key] = frame
	ns.PlaceFrame(frame)
end

function ns.SetUnlocked(on)
	if InCombatLockdown() then
		ns.Print(L.NOT_IN_COMBAT)
		return
	end
	ns.unlocked = on
	if not on then
		for _, frame in pairs(ns.movers) do ns.PlaceFrame(frame) end
	end
	ns.RefreshAll() -- while unlocked the displays show a sample, so the boxes fit them
	for _, frame in pairs(ns.movers) do
		SizeHandle(frame)
		frame.mover:SetShown(on)
	end
	ns.Print(on and L.UNLOCKED or L.LOCKED)
end

-- Slash command words: each module adds its own
ns.commands = {}

local function Help()
	for _, line in ipairs(L.HELP) do
		print(line)
	end
end

ns.commands.unlock = function() ns.SetUnlocked(true) end
ns.commands.desbloquear = ns.commands.unlock
ns.commands.lock = function() ns.SetUnlocked(false) end
ns.commands.bloquear = ns.commands.lock
ns.commands.help = Help
ns.commands.ayuda = Help

SLASH_HUNTERGOD1 = "/huntergod"
SLASH_HUNTERGOD2 = "/ammo"
SLASH_HUNTERGOD3 = "/municion"
SlashCmdList.HUNTERGOD = function(msg)
	local word = strlower(strtrim(msg or ""))
	if word == "" then
		if ns.ToggleOptions then ns.ToggleOptions() end
		return
	end
	local command = ns.commands[word]
	if command then
		command(word)
	else
		Help()
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
	if name ~= addonName then return end
	HunterGodDB = Fill(HunterGodDB or {}, defaults)
	ns.db = HunterGodDB
	self:UnregisterEvent("ADDON_LOADED")
end)
