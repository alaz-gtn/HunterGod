local _, ns = ...
local L = ns.L

-- The hunter's procs, drawn around you:
-- - Quick Shots and Quick Strikes (Deadly Aspects: 30% faster shots or swings for 12 sec): wind
--   rushing up both sides of you. A gust as it comes, then calmer wind while it lasts
-- - Rapid Killing (your next Shot deals 20% more): a target on the ground at your feet. It comes
--   down onto you with a flash, then turns slowly while it lasts
-- Forever keeps your buffs from addons in combat, so the game shows them itself, as MageGod's
-- lightning and ForeverAuras do: an aura container watches your buffs for each proc, the drawing
-- goes inside its button, and the game plays the animations it's given: the burst once as the buff
-- comes, the calm ones over and over while it's on. Nothing in there can be touched in combat; the
-- addon only builds it, and fits it to your settings out of combat
local MEDIA = "Interface\\AddOns\\HunterGod\\media\\"
local HEIGHT = 360
local SIDE_WIDTH = 110 -- room for a column of wind and its glow
local RING_Y = -150 -- the target, on the ground at your feet
local TIMER_Y = -200 -- the wind's seconds, under the target
local RUSH = { 0.55, 0.65 } -- one round of each column's wind while it lasts: apart, so they don't move as one
local GUST = 0.4 -- one round of the gust as it comes: it plays three, the last one fading out
local TURN = 2.4 -- the target's dashes going an eighth of the way round
local SPIN = 0.3 -- and as it comes, fast: five rounds, the first coming in and the last fading out
local LAND = 0.25 -- the target coming down onto you
local BREATH = 1.2 -- each half of a glow's breath
local TEST_SECONDS = 5
local DEFAULT_POINT = { "CENTER", "CENTER", 0, -20 } -- a little under the middle, around your character

-- seconds: how long the buff lasts, for the sample's countdown
local EFFECTS = {
	{ key = "speed", spells = { 6150, 1299448 }, seconds = 12 }, -- Quick Shots, Quick Strikes
	{ key = "kill", spells = { 415407 }, seconds = 20 }, -- Rapid Killing
}
local byKey = {}
for _, e in ipairs(EFFECTS) do
	byKey[e.key] = e
	e.default = {}
	for _, id in ipairs(e.spells) do e.default[id] = true end
end
ns.PROC_SPELLS = { speed = EFFECTS[1].spells, kill = EFFECTS[2].spells }

local db
local place, spot -- where it all goes (the box you drag), and the samples you see while moving it or trying it
local pending -- something to do once the fight is over
local formatter -- how the game writes the seconds left: a plain number, rounded up
local arts = {} -- every drawing, to fit them to your settings

local function SpellName(id)
	local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
	if name and not ns.IsSecret(name) then return name end
end

-- "Quick Shots / Quick Strikes", "Rapid Killing": its spells' names as the game writes them
function ns.ProcName(key)
	local names, seen = {}, {}
	for _, id in ipairs(byKey[key].spells) do
		local name = SpellName(id)
		if name and not seen[name] then
			seen[name] = true
			names[#names + 1] = name
		end
	end
	return #names > 0 and table.concat(names, " / ") or key
end

local function Width()
	return 2 * db.gap + SIDE_WIDTH
end

-- A colour taken toward white: the core of a light is nearly white whatever its colour
local function Mix(c, toWhite)
	return c.r + (1 - c.r) * toWhite, c.g + (1 - c.g) * toWhite, c.b + (1 - c.b) * toWhite
end

-- Your colour, the space between the wind's sides and the strength of each layer
local function Fit(art)
	local color = db[art.key].color
	for _, entry in ipairs(art.tinted) do
		pcall(entry[1].SetVertexColor, entry[1], Mix(color, entry[2]))
	end
	for _, entry in ipairs(art.placed) do
		local texture, side, y = entry[1], entry[2], entry[3]
		pcall(texture.ClearAllPoints, texture)
		pcall(texture.SetPoint, texture, "CENTER", art.parent, "CENTER", side * db.gap, y)
	end
	pcall(art.calm.SetAlpha, art.calm, db.calm / 100)
	pcall(art.strike.SetAlpha, art.strike, db.alpha / 100)
	-- The seconds left: the range's font, outlined, in a lighter shade of the colour; the target's
	-- a little smaller, inside it
	local size = art.key == "kill" and max(floor(db.timerSize * 0.8), 10) or db.timerSize
	pcall(ns.UseFont, art.timer, ns.FONTS and ns.FONTS[ns.db.range.font], size, "OUTLINE")
	pcall(art.timer.SetTextColor, art.timer, Mix(color, 0.55))
	pcall(art.timer.SetShown, art.timer, db.timer and not art.noTimer)
end

-- 12, 11 ... 1: whole seconds rounded up, as a countdown goes. Without it the game writes "12 s"
local function Formatter()
	if formatter == nil then
		formatter = false
		local rounding = Enum and Enum.NumericRuleFormatRounding
		if rounding and C_StringUtil and C_StringUtil.CreateNumericRuleFormatter then
			local ok, made = pcall(C_StringUtil.CreateNumericRuleFormatter)
			if ok and made and pcall(made.SetBreakpoints, made, {
				{ threshold = 0, format = "" },
				{ threshold = 0.000001, format = "%d", step = 1, rounding = rounding.Up },
			}) then
				formatter = made
			end
		end
	end
	return formatter or nil
end

-- Drawing pieces. The textures rest invisible and only a playing animation shows them, so if the
-- game doesn't play them nothing shows, not a still picture. side: -1 left, 1 right, 0 the middle
local function Tex(art, layer, file, drawLayer, sublevel, side, y, w, h, toWhite)
	local t = layer:CreateTexture(nil, drawLayer, nil, sublevel)
	t:SetTexture(MEDIA .. file)
	t:SetBlendMode("ADD")
	t:SetSize(w, h)
	t:SetAlpha(0)
	art.tinted[#art.tinted + 1] = { t, toWhite }
	art.placed[#art.placed + 1] = { t, side, y }
	return t
end

-- Animations go to two lists: shown (they loop while the buff is on) and assigned (once, as it comes)
local function Group(art, list, loop)
	local group = art.parent:CreateAnimationGroup()
	if loop then group:SetLooping("REPEAT") end
	list[#list + 1] = group
	return group
end

local function Fade(group, target, from, to, order, seconds)
	local a = group:CreateAnimation("Alpha")
	a:SetTarget(target)
	a:SetFromAlpha(from)
	a:SetToAlpha(to)
	a:SetOrder(order)
	a:SetDuration(seconds)
end

local function Grow(group, target, from, to, order, seconds)
	local a = group:CreateAnimation("Scale")
	a:SetTarget(target)
	a:SetOrigin("CENTER", 0, 0)
	a:SetOrder(order)
	a:SetDuration(seconds)
	if a.SetScaleFrom then
		a:SetScaleFrom(from, from)
		a:SetScaleTo(to, to)
	else
		a:SetScale(to / from, to / from)
	end
end

-- The sixteen pictures of a sheet in turn
local function Flip(group, target, order, seconds)
	local a = group:CreateAnimation("FlipBook")
	a:SetTarget(target)
	a:SetOrder(order)
	a:SetDuration(seconds)
	a:SetFlipBookRows(4)
	a:SetFlipBookColumns(4)
	a:SetFlipBookFrames(16)
	a:SetFlipBookFrameWidth(0)
	a:SetFlipBookFrameHeight(0)
end

-- Quick Shots and Quick Strikes: a column of wind on each side of you
local function Wind(art)
	local function Column(layer, side)
		return Tex(art, layer, "proc_aura", "BACKGROUND", 0, side, 0, 80, 300, 0),
			Tex(art, layer, "wind_glow", "ARTWORK", 0, side, 0, 72, 290, 0),
			Tex(art, layer, "wind_core", "ARTWORK", 1, side, 0, 72, 290, 0.6)
	end
	-- While it lasts: the wind rushing up and its glow breathing slowly
	local breath = Group(art, art.shown, true)
	for i, side in ipairs({ -1, 1 }) do
		local glow, windGlow, windCore = Column(art.calm, side)
		local rush = Group(art, art.shown, true)
		for _, wind in ipairs({ windGlow, windCore }) do
			Flip(rush, wind, 1, RUSH[i])
			Fade(rush, wind, 1, 1, 1, RUSH[i]) -- what shows it
		end
		Fade(breath, glow, 0.35, 0.8, 1, BREATH)
		Fade(breath, glow, 0.8, 0.35, 2, BREATH)
	end
	-- As it comes: a flash, the wind at full and faster for over a second, and then it fades into
	-- the calm
	local gusts, glows, flashes = Group(art, art.assigned), Group(art, art.assigned), Group(art, art.assigned)
	for _, side in ipairs({ -1, 1 }) do
		local glow, windGlow, windCore = Column(art.strike, side)
		local flash = Tex(art, art.strike, "proc_aura", "OVERLAY", 0, side, 0, 110, 360, 0.35)
		for order = 1, 3 do
			for _, wind in ipairs({ windGlow, windCore }) do
				Flip(gusts, wind, order, GUST)
				Fade(gusts, wind, 1, order < 3 and 1 or 0, order, GUST)
			end
		end
		Fade(glows, glow, 0, 0.9, 1, 0.1)
		Fade(glows, glow, 0.9, 0.9, 2, 2 * GUST - 0.1)
		Fade(glows, glow, 0.9, 0, 3, GUST)
		Fade(flashes, flash, 0, 1, 1, 0.07)
		Grow(flashes, flash, 0.5, 1, 1, 0.07)
		Fade(flashes, flash, 1, 0, 2, 0.45)
		Grow(flashes, flash, 1, 1.5, 2, 0.45)
	end
	-- The seconds it has left, under the target's place
	art.timer = art.parent:CreateFontString(nil, "OVERLAY")
	art.timer:SetPoint("TOP", art.parent, "CENTER", 0, TIMER_Y)
end

-- Rapid Killing: a target on the ground at your feet
local function Target(art)
	local function Ring(layer)
		return Tex(art, layer, "proc_spot", "BACKGROUND", 0, 0, RING_Y, 280, 110, 0),
			Tex(art, layer, "ring_base", "ARTWORK", 0, 0, RING_Y, 256, 128, 0.3),
			Tex(art, layer, "ring_glow", "ARTWORK", 1, 0, RING_Y, 256, 128, 0),
			Tex(art, layer, "ring_core", "ARTWORK", 2, 0, RING_Y, 256, 128, 0.6)
	end
	-- While it lasts: the dashes going slowly round, the sight still, its glow breathing
	local glow, base, dashGlow, dashCore = Ring(art.calm)
	local turn = Group(art, art.shown, true)
	for _, dash in ipairs({ dashGlow, dashCore }) do
		Flip(turn, dash, 1, TURN)
		Fade(turn, dash, 1, 1, 1, TURN)
	end
	Fade(turn, base, 1, 1, 1, TURN)
	local breath = Group(art, art.shown, true)
	Fade(breath, glow, 0.3, 0.75, 1, BREATH)
	Fade(breath, glow, 0.75, 0.3, 2, BREATH)
	-- As it comes: the target comes down onto you from big, its dashes spinning fast, a flash as it
	-- lands, and then it fades into the calm
	local landGlow, landBase, spinGlow, spinCore = Ring(art.strike)
	local flash = Tex(art, art.strike, "proc_spot", "OVERLAY", 0, 0, RING_Y, 320, 130, 0.35)
	local land = Group(art, art.assigned)
	Grow(land, landBase, 2.2, 1, 1, LAND)
	Fade(land, landBase, 0, 1, 1, LAND)
	Fade(land, landBase, 1, 1, 2, 0.7)
	Fade(land, landBase, 1, 0, 3, 0.5)
	local spin = Group(art, art.assigned)
	for order = 1, 5 do
		for _, dash in ipairs({ spinGlow, spinCore }) do
			Flip(spin, dash, order, SPIN)
			Fade(spin, dash, order == 1 and 0 or 1, order < 5 and 1 or 0, order, SPIN)
			if order == 1 then Grow(spin, dash, 2.2, 1, 1, SPIN) end
		end
	end
	local glows = Group(art, art.assigned)
	Fade(glows, landGlow, 0, 0.9, 1, LAND)
	Fade(glows, landGlow, 0.9, 0.9, 2, 0.7)
	Fade(glows, landGlow, 0.9, 0, 3, 0.5)
	local flashes = Group(art, art.assigned)
	Fade(flashes, flash, 0, 0, 1, LAND) -- waits for the target to land
	Fade(flashes, flash, 0, 1, 2, 0.07)
	Grow(flashes, flash, 0.5, 1, 2, 0.07)
	Fade(flashes, flash, 1, 0, 3, 0.45)
	Grow(flashes, flash, 1, 1.6, 3, 0.45)
	-- The seconds it has left, in the middle of the target
	art.timer = art.parent:CreateFontString(nil, "OVERLAY")
	art.timer:SetPoint("CENTER", art.parent, "CENTER", 0, RING_Y)
end

-- A proc's drawing inside parent, centred on it, in two layers: the strike and the calm
local function Draw(parent, key)
	local art = { parent = parent, key = key, shown = {}, assigned = {}, tinted = {}, placed = {} }
	for _, layer in ipairs({ "calm", "strike" }) do
		local frame = CreateFrame("Frame", nil, parent)
		frame:SetAllPoints(parent)
		art[layer] = frame
	end
	if key == "speed" then Wind(art) else Target(art) end
	arts[#arts + 1] = art
	if db then Fit(art) end
	return art
end

-- The container's button: the drawing goes in, and its animations to the game
local function Dress(button, box, e)
	button:SetAllPoints(box)
	button:EnableMouse(false)
	local art = Draw(button, e.key)
	art.live = true
	art.ready = pcall(function()
		for _, group in ipairs(art.shown) do button:AddAuraShownAnimation(group) end
		for _, group in ipairs(art.assigned) do button:AddAuraAssignedAnimation(group) end
	end)
	-- The time left is secret in combat: the game fills the text in itself
	local options = Formatter() and { textFormatter = Formatter() }
	if not (pcall(button.SetDurationText, button, art.timer, options)
		or options and pcall(button.SetDurationText, button, art.timer)) then
		art.noTimer = true
		art.timer:Hide()
	end
	e.dressed = art
end

local function Passive(id)
	if not (C_Spell and C_Spell.IsSpellPassive) then return false end
	local passive = C_Spell.IsSpellPassive(id)
	if ns.IsSecret(passive) then return false end
	return passive == true
end

-- The spells a proc watches: Forever's, and any other the addon saw by those names, less the ones it
-- saw always on (a passive, not the proc)
local function WatchList(e)
	local spells, ids = {}, {}
	local function Add(id)
		if spells[id] or db.ignored[id] or Passive(id) then return end
		spells[id] = true
		ids[#ids + 1] = id
	end
	for _, id in ipairs(e.spells) do Add(id) end
	for id, key in pairs(db.learned) do
		if key == e.key then Add(id) end
	end
	table.sort(ids)
	return spells, table.concat(ids, ", ")
end

-- The samples: while you move the displays (the procs you have on) and for a few seconds when you
-- try one
local function ShowSample(e, show)
	if show == e.sampleShown then return end
	e.sampleShown = show
	if show then e.sampleStart = GetTime() end
	e.sampleFrame:SetShown(show)
	for _, list in ipairs({ e.sample.shown, e.sample.assigned }) do
		for _, group in ipairs(list) do
			if show then group:Play() else group:Stop() end
		end
	end
end

function ns.UpdateProcsSample()
	if not spot then return end
	local any = false
	for _, e in ipairs(EFFECTS) do
		local show = (ns.unlocked and db[e.key].enabled and ns.IsHunter()) or GetTime() < (e.testUntil or 0)
		ShowSample(e, show and true or false)
		any = any or show
	end
	spot:SetShown(any and true or false)
end

-- Shows a proc's sample a moment (or both's), as you change how it looks
function ns.PeekProcs(key)
	for _, e in ipairs(EFFECTS) do
		if not key or key == e.key then e.testUntil = max(e.testUntil or 0, GetTime() + TEST_SECONDS) end
	end
	ns.UpdateProcsSample()
	C_Timer.After(TEST_SECONDS + 0.1, ns.UpdateProcsSample)
end

-- And its burst again, as if the buff had just come
function ns.TestProcs(key)
	for _, e in ipairs(EFFECTS) do
		if not key or key == e.key then
			if e.sampleShown then
				e.sampleStart = GetTime()
				for _, group in ipairs(e.sample.assigned) do
					group:Stop()
					group:Play()
				end
			end
			e.testUntil = GetTime() + TEST_SECONDS
		end
	end
	ns.UpdateProcsSample()
	C_Timer.After(TEST_SECONDS + 0.1, ns.UpdateProcsSample)
end

function ns.StyleProcs()
	if not place then return end
	local scale, width = db.size / 100, Width()
	local fight = InCombatLockdown()
	spot:SetScale(scale)
	spot:SetSize(width, HEIGHT)
	for _, art in ipairs(arts) do
		if art.live and fight then pending = true else Fit(art) end
	end
	-- What the game shows, and the box it hangs from, can't be touched in a fight
	if fight then
		pending = true
	else
		place:SetSize(width * scale, HEIGHT * scale)
		ns.PlaceFrame(place)
		if place.mover then place.mover:SetSize(width * scale + 16, HEIGHT * scale + 16) end
		for _, e in ipairs(EFFECTS) do
			if e.holder then
				e.holder:SetScale(scale)
				e.holder:SetSize(width, HEIGHT)
				e.holder:SetShown(db[e.key].enabled and true or false)
			end
		end
	end
	ns.UpdateProcsSample()
end

function ns.SetProcsSize(size)
	db.size = size
	ns.StyleProcs()
end

-- Where it is, from the middle of the screen. A place saved by dragging may hang from another
-- corner: then it's measured
local function Measure()
	local x, y = place:GetCenter()
	local cx, cy = UIParent:GetCenter()
	if not (x and cx) or ns.IsSecret(x) or ns.IsSecret(y) then return end
	return floor(x - cx + 0.5), floor(y - cy + 0.5)
end

function ns.ProcsOffset()
	local p = ns.db.positions.procs
	if p and p[1] == "CENTER" and p[2] == "CENTER" then return p[3], p[4] end
	if p and place then
		local x, y = Measure()
		if x then return x, y end
	end
	return DEFAULT_POINT[3], DEFAULT_POINT[4]
end

function ns.MoveProcs(x, y)
	ns.db.positions.procs = { "CENTER", "CENTER", x, y }
	ns.StyleProcs()
end

-- Built out of combat. A list that changes builds a new one; containers can't be thrown away, so
-- the old one is switched off
local function Build(e)
	if InCombatLockdown() then
		pending = true
		return
	end
	if e.broken or not (ns.IsHunter() and CustomAuraContainerAuraProcessingPolicy and C_UnitAuras) then return end
	local spells, list = WatchList(e)
	if list == e.watching then return end
	if e.container then
		pcall(e.container.SetEnabled, e.container, false)
		e.holder:Hide()
		e.holder, e.container, e.watching, e.dressed = nil, nil, nil, nil
	end
	if list == "" then return end
	local box = CreateFrame("Frame", nil, UIParent)
	box:SetSize(Width(), HEIGHT)
	box:SetFrameStrata("BACKGROUND")
	box:SetPoint("CENTER", place, "CENTER")
	local ok, aurasBox = pcall(CreateFrame, "AuraContainer", nil, box, "CustomAuraContainerTemplate")
	if not ok or not aurasBox then
		e.broken = true
		return
	end
	aurasBox:SetAllPoints(box)
	aurasBox:SetEnabled(false)
	aurasBox:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
	if not pcall(aurasBox.AddAuraSlot, aurasBox, "HunterGodProc" .. e.key, "HELPFUL", {
		candidateFilters = { includeSpellIDs = spells },
		initializeFrame = function(button) Dress(button, box, e) end,
	}) then
		e.broken = true
		return
	end
	aurasBox:SetUnit("player")
	aurasBox:SetEnabled(true)
	e.holder, e.container, e.watching = box, aurasBox, list
	ns.StyleProcs()
end

local function BuildAll()
	for _, e in ipairs(EFFECTS) do Build(e) end
end

-- Out of combat the addon can read your buffs: one of these procs with another number joins its
-- list, and one that never ends (a passive) leaves it
local function Learn()
	if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return end
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
	local byName = {}
	for _, e in ipairs(EFFECTS) do
		for _, id in ipairs(e.spells) do
			local name = SpellName(id)
			if name then byName[name] = e end
		end
	end
	local changed = {}
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if not aura or ns.IsSecret(aura) then break end
		local name, id, duration = aura.name, aura.spellId, aura.duration
		local e = not (ns.IsSecret(name) or ns.IsSecret(id) or ns.IsSecret(duration)) and byName[name]
		if e and type(id) == "number" then
			if type(duration) == "number" and duration > 0 then
				if db.ignored[id] then
					db.ignored[id] = nil
					changed[e] = true
				end
				if not e.default[id] and db.learned[id] ~= e.key then
					db.learned[id] = e.key
					changed[e] = true
				end
			elseif not db.ignored[id] then
				db.ignored[id] = true
				changed[e] = true
			end
		end
	end
	for e in pairs(changed) do Build(e) end
end

-- /huntergod procs: shows them and says what each watches
local function Report()
	ns.TestProcs()
	if not ns.IsHunter() then return end
	for _, e in ipairs(EFFECTS) do
		local name = ns.ProcName(e.key)
		if not e.container then
			ns.Print(format(L.PROCS_NOT_READY, name))
		elseif e.dressed and not e.dressed.ready then
			ns.Print(format(L.PROCS_REFUSED, name))
		else
			ns.Print(format(L.PROCS_WATCHING, name, e.watching))
		end
	end
end
ns.commands.procs = Report

-- For the tests
function ns.ProcsState(key)
	local e = byKey[key]
	return { holder = e.holder, container = e.container, dressed = e.dressed, sample = e.sample,
		sampleFrame = e.sampleFrame, place = place, spot = spot }
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN") -- built once
		db = ns.db.procs
		place = CreateFrame("Frame", "HunterGodProcs", UIParent)
		place:SetSize(Width(), HEIGHT)
		spot = CreateFrame("Frame", nil, place)
		spot:SetPoint("CENTER")
		spot:SetFrameStrata("BACKGROUND")
		spot:Hide()
		for _, e in ipairs(EFFECTS) do
			e.sampleFrame = CreateFrame("Frame", nil, spot)
			e.sampleFrame:SetAllPoints(spot)
			e.sampleFrame:Hide()
			e.sample = Draw(e.sampleFrame, e.key)
		end
		-- Their countdowns: as the real ones would go, from the moment each sample shows
		spot:SetScript("OnUpdate", function()
			local now = GetTime()
			for _, e in ipairs(EFFECTS) do
				if e.sampleShown then
					e.sample.timer:SetText(format("%d", max(ceil(e.seconds - (now - e.sampleStart)), 1)))
				end
			end
		end)
		ns.Movable(place, "procs", DEFAULT_POINT, L.PROCS_NAME)
		-- Dragged: kept as an offset from the middle, as the options set it
		place.mover:HookScript("OnDragStop", function()
			local x, y = Measure()
			if x then ns.MoveProcs(x, y) end
			if ns.RefreshOptionsPage then ns.RefreshOptionsPage("procs") end
		end)
		table.insert(ns.refreshers, ns.StyleProcs)
		self:RegisterUnitEvent("UNIT_AURA", "player")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		Learn()
		BuildAll()
		ns.StyleProcs()
	elseif event == "UNIT_AURA" then
		Learn()
	elseif event == "PLAYER_REGEN_ENABLED" then
		Learn()
		if pending then
			pending = false
			BuildAll()
			ns.StyleProcs()
		end
	end
end)
