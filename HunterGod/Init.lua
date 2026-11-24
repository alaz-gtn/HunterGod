local addonName, ns = ...
local L = ns.L

-- Settings: whatever is missing from the saved ones is filled in from here
local defaults = {
	-- World map
	arrows = true,
	bullets = true,
	trainers = true,
	stableMasters = true,
	foodVendors = true,
	allFactions = false,
	minimap = true,
	continent = true,
	onlyHunter = true,
	learned = {},
	notAmmo = {},
	names = {},
	playstyle = "auto", -- auto | ranged | melee: Survival fights in melee
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
		plateSide = "top", -- top | bottom | left | right: where on the target's nameplate
		plateGap = 2, -- pixels between it and the nameplate
		units = "yards", -- yards | meters
		display = "number", -- number | bracket
		font = "fredoka", -- fredoka | changa | game
		showState = false,
		deadLabel = true, -- "Dead zone" under the number while you're in it, even with the state off
		farGlow = true, -- light blue and glowing in the last 5 yards of your reach
		textSize = 26,
		colors = {
			ranged = { r = 0.3, g = 1, b = 0.3 },
			far = { r = 0.45, g = 0.8, b = 1 },
			melee = { r = 1, g = 0.82, b = 0 },
			dead = { r = 1, g = 0.2, b = 0.2 },
			out = { r = 0.6, g = 0.6, b = 0.6 },
			-- Melee style (Survival): melee is where you want to be, at range you have to close in
			hit = { r = 0.3, g = 1, b = 0.3 },
			approach = { r = 1, g = 0.82, b = 0 },
		},
	},
	aspect = { enabled = true, travel = true, missing = true, preferred = "hawk", melee = "beast", text = false, trueshot = true },
	traps = { enabled = true, freeze = true },
	lowAmmo = { enabled = true, threshold = 1000, merchant = true },
	-- A bar for each weapon's swing: Auto Shot, main hand, off hand
	swing = {
		enabled = true, ranged = true, main = true, off = true,
		hideBlizzard = true, -- the game's own swing timers off while these show
		byRange = true, -- in melee range only the melee bars, further away only Auto Shot's
		width = 180, height = 14,
		time = true, icon = true,
		windup = true, -- Auto Shot's last half second, when moving holds the shot back
		colors = {
			ranged = { r = 0.67, g = 0.83, b = 0.45 },
			main = { r = 0.89, g = 0.76, b = 0.48 },
			off = { r = 0.73, g = 0.56, b = 0.36 },
		},
	},
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

-- Fonts as shared font objects, one per file, size and outline, applied with SetFontObject.
-- Each text loading the font file itself (SetFont on the FontString) left some texts undrawn in
-- Forever: FarmGod's tabs, 23 Nov 2026, had their text, shown, at full alpha and with a width,
-- and nothing on screen. The game's font goes in first, so a font that can't load still shows
local fontObjects, fontCount = {}, 0
function ns.UseFont(fontString, file, size, flags)
	local gameFont = GameFontNormal:GetFont()
	file, flags = file or gameFont, flags or ""
	local key = file .. "|" .. size .. "|" .. flags
	local font = fontObjects[key]
	if not font then
		fontCount = fontCount + 1
		font = CreateFont("HunterGodFont" .. fontCount)
		font:SetFont(gameFont, size, flags)
		font:SetFont(file, size, flags)
		fontObjects[key] = font
	end
	-- The font object brings its own colour and shadow: the text keeps the ones it had
	local r, g, b, a = fontString:GetTextColor()
	local sx, sy = fontString:GetShadowOffset()
	local sr, sg, sb, sa = fontString:GetShadowColor()
	fontString:SetFontObject(font)
	if r then fontString:SetTextColor(r, g, b, a) end
	if sx then fontString:SetShadowOffset(sx, sy) end
	if sr then fontString:SetShadowColor(sr, sg, sb, sa) end
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

-- Survival in Forever fights in melee. There's no spec to read (one talent tree per class), so
-- its melee talents give it away: Strider Kick, Predator's Edge and Expose Prey (IDs from
-- wow.gg's Forever guide). /huntergod style says what it found
ns.MELEE_TALENTS = { 1317257, 1310627, 1310532 }
local meleeTalent -- the first of them you know, false for none, nil before looking

local function FindMeleeTalent()
	for _, id in ipairs(ns.MELEE_TALENTS) do
		local known
		if IsPlayerSpell then known = IsPlayerSpell(id) elseif IsSpellKnown then known = IsSpellKnown(id) end
		if known and not ns.IsSecret(known) then return id end
	end
	return false
end

-- Melee (Survival) or ranged: what you chose in the options, or what your talents say
function ns.IsMelee()
	local style = ns.db and ns.db.playstyle
	if style == "melee" or style == "ranged" then return style == "melee" end
	if meleeTalent == nil then meleeTalent = FindMeleeTalent() end
	return meleeTalent ~= false
end

local function SpellLabel(id)
	local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
	if not name and GetSpellInfo then name = GetSpellInfo(id) end
	return name or ("#" .. id)
end

local function StyleReport()
	local why
	if ns.db.playstyle == "melee" or ns.db.playstyle == "ranged" then
		why = L.STYLE_CHOSEN
	else
		meleeTalent = FindMeleeTalent()
		if meleeTalent then
			why = format(L.STYLE_FOUND, SpellLabel(meleeTalent))
		else
			local names = {}
			for _, id in ipairs(ns.MELEE_TALENTS) do names[#names + 1] = SpellLabel(id) end
			why = format(L.STYLE_NONE, table.concat(names, ", "))
		end
	end
	ns.Print(format(L.STYLE_REPORT, ns.IsMelee() and L.PLAYSTYLE.melee or L.PLAYSTYLE.ranged, why))
end
ns.commands.style = StyleReport
ns.commands.estilo = StyleReport

-- Changing talents changes the style: everything follows, and the chat says so
local styleWatch = CreateFrame("Frame")
local settled = false
styleWatch:RegisterEvent("PLAYER_LOGIN")
styleWatch:RegisterEvent("SPELLS_CHANGED")
pcall(styleWatch.RegisterEvent, styleWatch, "TRAIT_CONFIG_UPDATED")
styleWatch:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		-- The spells come in bits at login: nothing to say until they have
		C_Timer.After(10, function() settled = true end)
	end
	if not ns.db or not ns.IsHunter() then return end
	local was = ns.IsMelee()
	meleeTalent = FindMeleeTalent()
	if ns.IsMelee() == was then return end
	if settled then ns.Print(was and L.STYLE_NOW_RANGED or L.STYLE_NOW_MELEE) end
	ns.RefreshAll()
end)
