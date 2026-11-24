local _, ns = ...
local L = ns.L

-- Swing timers: a bar for each weapon (Auto Shot, main hand, off hand), stacked, each with its
-- weapon's icon on a tag at its left. Forever tells addons when each swing goes and how long the
-- next one takes (PLAYER_SWING), so no combat log is needed. Each bar starts dim and lights up as
-- its swing comes, and flashes when it goes. A bar shows while you attack with that weapon and goes
-- a moment after you stop.

local MAIN, OFF, RANGED = 0, 1, 2 -- Enum.PlayerSwingType
local ORDER = { RANGED, MAIN, OFF } -- top to bottom
local SLOTS = { [MAIN] = 16, [OFF] = 17, [RANGED] = 18 }
local KEYS = { [MAIN] = "main", [OFF] = "off", [RANGED] = "ranged" }
local LINGER = 2 -- seconds a bar stays once its swing is done and no other comes
local FLASH = 0.18 -- the flash when a swing goes
local WINDUP = 0.5 -- Auto Shot's last half second, when moving holds the shot back
local GAP = 3 -- between rows
local DEFAULT_POINT = { "CENTER", "CENTER", 0, -100 }
local THIN_FONT = "Fonts\\ARIALN.TTF"
-- For samples, when the game doesn't say how fast your weapons are
local SAMPLE_SPEED = { [RANGED] = 2.8, [MAIN] = 2.6, [OFF] = 1.9 }
local TEST_SECONDS = 6

local db, holder
local bars = {}
local swings = {} -- by swing type: { start, duration }
local inRange = {} -- by swing type: whether the target is in that weapon's reach, nil when the game can't tell
local Zone -- where you stand for your target (below)
local sampleUntil = 0
local pending -- the Blizzard setting waits for the end of a fight

local function OnePixel(frame)
	if not (PixelUtil and PixelUtil.GetPixelToUIUnitFactor) then return 1 end
	local scale = frame:GetEffectiveScale()
	if ns.IsSecret(scale) or not scale or scale <= 0 then return 1 end
	return PixelUtil.GetPixelToUIUnitFactor() / scale
end

local function HasWeapon(swingType)
	return GetInventoryItemID("player", SLOTS[swingType]) ~= nil
end

local function Wanted(swingType)
	return db.enabled and db[KEYS[swingType]] and ns.IsHunter()
end

local function Sampling()
	return ns.unlocked or GetTime() < sampleUntil
end

-- How long a swing of that weapon takes, for the samples
local function Speed(swingType)
	local speed
	if swingType == RANGED and UnitRangedDamage then
		speed = UnitRangedDamage("player")
	elseif UnitAttackSpeed then
		local main, off = UnitAttackSpeed("player")
		speed = swingType == OFF and off or main
	end
	if type(speed) ~= "number" or ns.IsSecret(speed) or speed <= 0 then return SAMPLE_SPEED[swingType] end
	return speed
end

local function Bar(swingType)
	local b = CreateFrame("Frame", nil, holder)
	b.type = swingType
	b.tagEdge = b:CreateTexture(nil, "BACKGROUND", nil, -1)
	b.tagEdge:SetColorTexture(0, 0, 0, 1)
	b.tag = b:CreateTexture(nil, "ARTWORK")
	b.tag:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.edge = b:CreateTexture(nil, "BACKGROUND", nil, -1)
	b.edge:SetColorTexture(0, 0, 0, 1)
	b.back = b:CreateTexture(nil, "BACKGROUND")
	b.back:SetColorTexture(0.03, 0.05, 0.02, 0.85)
	b.fill = b:CreateTexture(nil, "BORDER")
	b.fill:SetPoint("TOPLEFT", b.back)
	b.fill:SetPoint("BOTTOMLEFT", b.back)
	-- A thread of light along the top of what's filled
	b.shine = b:CreateTexture(nil, "ARTWORK")
	b.shine:SetColorTexture(1, 1, 1, 0.14)
	b.shine:SetPoint("TOPLEFT", b.fill)
	b.shine:SetPoint("TOPRIGHT", b.fill)
	b.windup = b:CreateTexture(nil, "ARTWORK", nil, 1)
	b.windup:SetColorTexture(0.91, 0.64, 0.24, 0.22)
	b.windup:SetPoint("TOPRIGHT", b.back)
	b.windup:SetPoint("BOTTOMRIGHT", b.back)
	b.flash = b:CreateTexture(nil, "OVERLAY")
	b.flash:SetColorTexture(1, 1, 1, 1)
	b.flash:SetAllPoints(b.back)
	b.flash:SetAlpha(0)
	b.time = b:CreateFontString(nil, "OVERLAY")
	b.time:SetPoint("RIGHT", b.back, "RIGHT", -4, 0)
	b:Hide()
	bars[swingType] = b
	return b
end

function ns.StyleSwing()
	if not holder then return end
	local px = OnePixel(holder)
	local w, h = db.width, db.height
	local tagWidth = db.icon and h + GAP or 0
	holder:SetSize(tagWidth + w, h * 3 + GAP * 2)
	for _, swingType in ipairs(ORDER) do
		local b = bars[swingType]
		b:SetSize(tagWidth + w, h)
		b.tag:ClearAllPoints()
		b.tag:SetPoint("TOPLEFT")
		b.tag:SetSize(h, h)
		b.tag:SetShown(db.icon)
		b.tagEdge:SetShown(db.icon)
		b.tagEdge:ClearAllPoints()
		b.tagEdge:SetPoint("TOPLEFT", b.tag, -px, px)
		b.tagEdge:SetPoint("BOTTOMRIGHT", b.tag, px, -px)
		b.tag:SetTexture(GetInventoryItemTexture("player", SLOTS[swingType]) or "Interface\\Icons\\INV_Misc_QuestionMark")
		b.back:ClearAllPoints()
		b.back:SetPoint("TOPRIGHT")
		b.back:SetSize(w, h)
		b.edge:ClearAllPoints()
		b.edge:SetPoint("TOPLEFT", b.back, -px, px)
		b.edge:SetPoint("BOTTOMRIGHT", b.back, px, -px)
		b.shine:SetHeight(px)
		ns.UseFont(b.time, THIN_FONT, max(floor(h * 0.85), 9), "")
		b.time:SetShadowOffset(1, -1)
		b.time:SetShadowColor(0, 0, 0, 1)
		b.time:SetTextColor(1, 1, 1)
		b.time:SetShown(db.time)
	end
	ns.UpdateSwing()
end

-- Paints one bar at this moment: how far its swing has come, lit up as it nears the end
local function Paint(b, now)
	local s = swings[b.type]
	local w = db.width
	local p, left = 1, 0
	if s and s.duration > 0 then
		p = min(max((now - s.start) / s.duration, 0), 1)
		left = max(s.start + s.duration - now, 0)
	end
	local c = db.colors[KEYS[b.type]]
	local r, g, bl = c.r, c.g, c.b
	local away = inRange[b.type] == false and not Sampling()
	if away then r, g, bl = 0.5, 0.5, 0.48 end
	local k = 0.45 + 0.55 * p * p
	b.fill:SetColorTexture(r * k, g * k, bl * k, 1)
	b.fill:SetWidth(max(w * p, 0.01))
	b.fill:SetShown(p > 0)
	b.shine:SetShown(p > 0)
	b:SetAlpha(away and 0.55 or 1)
	local since = s and now - s.start or FLASH
	b.flash:SetAlpha(since < FLASH and 0.55 * (1 - since / FLASH) or 0)
	local windup = b.type == RANGED and db.windup and s and s.duration > 0
	b.windup:SetShown(windup or false)
	if windup then b.windup:SetWidth(w * min(WINDUP / s.duration, 1)) end
	b.time:SetText(left > 0 and format("%.1f", left) or "")
end

-- A bar is up while you attack with its weapon, and a little after
local function Active(swingType, now)
	local s = swings[swingType]
	return s ~= nil and now < s.start + s.duration + LINGER
end

local wasSampling = false

function ns.UpdateSwing()
	if not holder then return end
	local now = GetTime()
	local sampling = Sampling()
	-- The samples' swings aren't yours: they go with them
	if wasSampling and not sampling then wipe(swings) end
	wasSampling = sampling
	-- Only the bars for where you are: up close the melee ones, further away Auto Shot's
	local zone = db.byRange and not sampling and Zone() or "both"
	local y, shown = 0, 0
	for _, swingType in ipairs(ORDER) do
		local b = bars[swingType]
		local on = Wanted(swingType)
		if sampling then
			-- Samples: every bar you'd see, swinging on its own
			on = on and (ns.unlocked or HasWeapon(swingType) or swingType == RANGED)
			local s = swings[swingType]
			if on and (not s or now >= s.start + s.duration) then
				swings[swingType] = { start = now, duration = Speed(swingType) }
			end
		else
			on = on and Active(swingType, now)
				and (zone == "both" or (zone == "melee") == (swingType ~= RANGED))
		end
		if on then
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
			y = y + db.height + GAP
			shown = shown + 1
			Paint(b, now)
			b:Show()
		else
			b:Hide()
		end
	end
	holder:SetShown(shown > 0)
end

-- /huntergod swinglog: each swing the game reports, in the chat, to see what it hands over
local logging = false
local function Describe(value)
	if ns.IsSecret(value) then return "secret" end
	return tostring(value)
end

-- A swing just went: the next one comes in this long
local function Swing(duration, swingType)
	if logging then
		ns.Print(format("PLAYER_SWING type=%s duration=%s combat=%s", Describe(swingType), Describe(duration),
			tostring(InCombatLockdown())))
	end
	if ns.IsSecret(duration) or ns.IsSecret(swingType) or not KEYS[swingType] then return end
	if type(duration) ~= "number" or duration <= 0 or duration ~= duration or duration == math.huge then return end
	swings[swingType] = { start = GetTime(), duration = duration }
	ns.UpdateSwing()
end
ns.SwingEvent = Swing -- for the tests

local function CheckRange(swingType)
	if not (C_SwingTimer and C_SwingTimer.IsTargetWithinSwingRange) then return end
	local ok, within = pcall(C_SwingTimer.IsTargetWithinSwingRange, swingType)
	-- Nil means the game couldn't tell: not out of range
	if ok and type(within) == "boolean" and not ns.IsSecret(within) then
		inRange[swingType] = within
	else
		inRange[swingType] = nil
	end
end

-- Where you stand for your target: "melee" in your weapon's reach, "ranged" beyond it, nil when
-- nothing says. The game's own check for the main hand first, then the addon's range reading
function Zone()
	local melee = inRange[MAIN]
	if melee ~= nil then return melee and "melee" or "ranged" end
	local state = ns.RangeState and UnitExists("target") and ns.RangeState("target")
	if state == "melee" then return "melee" end
	if state == "ranged" or state == "dead" or state == "out" then return "ranged" end
end
ns.SwingZone = Zone

-- Blizzard's own swing timers, through the game's setting: off while these do the job, back on
-- (if this turned them off) when you turn these off
local function Blizzard()
	if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
	if InCombatLockdown() then
		pending = true
		return
	end
	local current = C_CVar.GetCVar("showSwingTimer")
	if current == nil then return end
	if db.enabled and db.hideBlizzard and ns.IsHunter() then
		if current ~= "0" then
			db.restoreBlizzard = true
			pcall(C_CVar.SetCVar, "showSwingTimer", "0")
		end
	elseif db.restoreBlizzard then
		db.restoreBlizzard = nil
		pcall(C_CVar.SetCVar, "showSwingTimer", "1")
	end
end
ns.SwingBlizzard = Blizzard

-- /huntergod swing, and the options' button: the bars swinging for a few seconds
function ns.TestSwing()
	sampleUntil = GetTime() + TEST_SECONDS
	wipe(swings)
	ns.UpdateSwing()
	C_Timer.After(TEST_SECONDS + 0.1, function()
		wipe(swings)
		ns.UpdateSwing()
	end)
end
ns.commands.swing = ns.TestSwing
ns.commands.golpes = ns.TestSwing
ns.commands.swinglog = function()
	logging = not logging
	ns.Print(format("swing log %s; Blizzard's setting showSwingTimer = %s", logging and "on" or "off",
		tostring(C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("showSwingTimer"))))
end

-- For the tests
function ns.SwingState()
	return { holder = holder, bars = bars, swings = swings, inRange = inRange }
end

local events = CreateFrame("Frame")
-- Events this client may not have: registering one it doesn't know would stop the file here
local function Listen(event, unit)
	if unit then
		pcall(events.RegisterUnitEvent, events, event, unit)
	else
		pcall(events.RegisterEvent, events, event)
	end
end

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		db = ns.db.swing
		holder = CreateFrame("Frame", "HunterGodSwing", UIParent)
		holder:SetFrameStrata("MEDIUM")
		for _, swingType in ipairs(ORDER) do Bar(swingType) end
		holder:SetScript("OnUpdate", function()
			if Sampling() or next(swings) then ns.UpdateSwing() end
		end)
		holder:Hide()
		ns.Movable(holder, "swing", DEFAULT_POINT, L.SWING_NAME)
		table.insert(ns.refreshers, ns.StyleSwing)
		Listen("PLAYER_SWING")
		Listen("PLAYER_SWING_RANGE_UPDATE")
		Listen("WEAPON_SLOT_CHANGED")
		Listen("PLAYER_TARGET_CHANGED")
		Listen("PLAYER_EQUIPMENT_CHANGED")
		Listen("PLAYER_REGEN_ENABLED")
		Listen("UI_SCALE_CHANGED")
		Listen("DISPLAY_SIZE_CHANGED")
		if C_SwingTimer and C_SwingTimer.EnableRangeCheck then
			for _, swingType in ipairs(ORDER) do pcall(C_SwingTimer.EnableRangeCheck, swingType, true) end
		end
		ns.StyleSwing()
		Blizzard()
	elseif event == "PLAYER_SWING" then
		Swing(...)
	elseif event == "PLAYER_SWING_RANGE_UPDATE" then
		local swingType, within, checks = ...
		if ns.IsSecret(swingType) or ns.IsSecret(within) or ns.IsSecret(checks) or not KEYS[swingType] then return end
		if checks then inRange[swingType] = within and true or false else inRange[swingType] = nil end
		ns.UpdateSwing()
	elseif event == "PLAYER_TARGET_CHANGED" then
		for _, swingType in ipairs(ORDER) do CheckRange(swingType) end
		ns.UpdateSwing()
	elseif event == "WEAPON_SLOT_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
		-- Another weapon: its icon, and no swing left from the one before
		for _, swingType in ipairs(ORDER) do
			if not HasWeapon(swingType) then swings[swingType] = nil end
		end
		ns.StyleSwing()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pending then
			pending = nil
			Blizzard()
		end
	elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
		ns.StyleSwing()
	end
end)
