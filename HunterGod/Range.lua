local _, ns = ...
local L = ns.L

-- The state comes from your own spells: Raptor Strike and Wing Clip reach melee range,
-- Auto Shot fires from 8 yards to your bow's reach, and in between is the dead zone.
-- The yards come from range steps inside that state, so the two never disagree.
local AUTO_SHOT, RAPTOR_STRIKE, WING_CLIP = 75, 2973, 2974
local MELEE, AUTO_SHOT_MIN, AUTO_SHOT_REACH = 5, 8, 35
local YARD = 0.9144

-- Items whose use range measures the distance to an enemy, by yards. From the
-- Classic lists of LibRangeCheck-3.0 (MIT); several per step in case one isn't cached.
ns.RANGE_ITEMS = {
	{ 5, { 8149, 15826, 16308, 17117, 22259, 22432 } },
	{ 10, { 9606, 9618, 9619, 9620, 9621, 10699, 17626, 17689 } },
	{ 15, { 4559 } },
	{ 20, { 1191, 2012, 4388, 10645, 13892, 17757, 18209, 22048 } },
	{ 25, { 13289 } },
	{ 30, { 835, 1404, 1434, 4479, 4480, 4481, 4941, 5079, 9328, 17202, 20084, 21038 } },
	{ 35, { 1399, 1402, 18904, 1258, 8688 } },
	{ 40, { 4945, 8348 } },
	{ 100, { 5418, 17162, 23715, 23718, 23719, 23721, 23722 } },
}
-- Interact distances in yards on Forever (as GoodRange measures them): 3 is the close
-- one, 4 the long one; Tauren and Undead are a little shorter
local INTERACT = { [3] = 8, [4] = 28 }
local INTERACT_RACE = { Tauren = { [3] = 6, [4] = 25 }, Scourge = { [3] = 7, [4] = 27 } }

local db, frame, melee, plate
local elapsed = 0
local names = {} -- your spells by name: the game answers for the rank you know
local steps = {} -- { yards, item or interact }, ascending
local stepsMissing = false

-- true / false, or nil when the game doesn't say
local function Answer(v)
	if ns.IsSecret(v) then return nil end
	if v == true or v == 1 then return true end
	if v == false or v == 0 then return false end
end

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	return (GetSpellInfo(id))
end

local function InRange(spell, unit)
	if not spell then return end
	if C_Spell and C_Spell.IsSpellInRange then
		return Answer(C_Spell.IsSpellInRange(spell, unit))
	end
	return Answer(IsSpellInRange(spell, unit))
end

-- Only items the game has loaded give real answers
local function ItemReady(id)
	local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
	if C_Item and C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(id) then return false end
	return getInfo(id) ~= nil
end

local function BuildSteps()
	wipe(steps)
	stepsMissing = false
	for _, step in ipairs(ns.RANGE_ITEMS) do
		local found
		for _, id in ipairs(step[2]) do
			if ItemReady(id) then
				found = id
				break
			end
			if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
		end
		if found then
			steps[#steps + 1] = { step[1], item = found }
		else
			stepsMissing = true
		end
	end
	local race = select(2, UnitRace("player"))
	for index, yards in pairs(INTERACT_RACE[race] or INTERACT) do
		steps[#steps + 1] = { yards, interact = index }
	end
	table.sort(steps, function(a, b) return a[1] < b[1] end)
	-- Items that weren't loaded yet are tried again in a while
	if stepsMissing then C_Timer.After(5, BuildSteps) end
end

local function CheckStep(step, unit)
	if step.item then
		local check = C_Item and C_Item.IsItemInRange or IsItemInRange
		return Answer(check(step.item, unit))
	end
	return Answer(CheckInteractDistance(unit, step.interact))
end

local function LearnNames()
	names.autoShot = SpellName(AUTO_SHOT)
	names.raptorStrike = SpellName(RAPTOR_STRIKE)
	names.wingClip = SpellName(WING_CLIP)
end

-- How far Auto Shot reaches (Hawk Eye adds to it)
local function AutoShotReach()
	local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(names.autoShot or AUTO_SHOT)
	local reach = type(info) == "table" and info.maxRange
	if type(reach) == "number" and not ns.IsSecret(reach) and reach > AUTO_SHOT_MIN then return reach end
	return AUTO_SHOT_REACH
end

local function StepAt(field, value)
	for _, step in ipairs(steps) do
		if step[field] == value then return step end
	end
end

-- Within the close interact distance (about 8 yards), or nil when the game doesn't say
local function Close(unit)
	local step = StepAt("interact", 3)
	if step then return CheckStep(step, unit) end
end

-- On Forever the melee spells can say "in range" from anywhere, so they only count when
-- the target is close; the 5 yard item, when the game has it loaded, is trusted first
local function Melee(unit, close)
	if close == false then return false end
	local item = StepAt(1, MELEE)
	local melee = item and item.item and CheckStep(item, unit)
	if melee ~= nil then return melee end
	if close == nil then return nil end
	melee = InRange(names.wingClip, unit)
	if melee == nil then melee = InRange(names.raptorStrike, unit) end
	return melee
end

-- ranged | melee | dead | out, or nil when the game doesn't say
function ns.RangeState(unit)
	local ranged = InRange(names.autoShot, unit)
	if ranged then return "ranged" end
	local close = Close(unit)
	local melee = Melee(unit, close)
	if melee then return "melee" end
	if close then return "dead" end
	if ranged == nil and melee == nil and close == nil then return nil end
	return "out"
end

-- The distance to the unit in yards for its state: low, high (high is nil past the last step)
function ns.RangeDistance(unit, state)
	if state == "melee" then return 0, MELEE end
	if state == "dead" then return MELEE, AUTO_SHOT_MIN end
	local reach = AutoShotReach()
	local low, high = reach, nil
	if state == "ranged" then low, high = AUTO_SHOT_MIN, reach end
	for _, step in ipairs(steps) do
		local yards = step[1]
		if yards > low and (not high or yards < high) then
			local v = CheckStep(step, unit)
			if v then
				high = yards
				break
			elseif v == false then
				low = yards
			end
		end
	end
	return low, high
end

-- /huntergod rango: what each check says about your target
local function RangeReport()
	if not UnitExists("target") then
		ns.Print(L.RANGE_NO_TARGET)
		return
	end
	local function Say(v)
		if v == nil then return "?" end
		return v and L.RANGE_YES or L.RANGE_NO
	end
	local state = ns.RangeState("target")
	local low, high = ns.RangeDistance("target", state)
	ns.Print(format(L.RANGE_REPORT, state and L.RANGE[state] or "?", low, high or 0, AutoShotReach(),
		Say(InRange(names.autoShot, "target")), Say(Melee("target", Close("target")))))
	local parts = {}
	for _, step in ipairs(steps) do
		parts[#parts + 1] = format("%d:%s", step[1], Say(CheckStep(step, "target")))
	end
	ns.Print(L.RANGE_STEPS .. table.concat(parts, "  ") .. (stepsMissing and ("  " .. L.RANGE_LOADING) or ""))
end
ns.commands.range = RangeReport
ns.commands.rango = RangeReport

-- One number from the range steps. Each time the target crosses a step, its distance is
-- known exactly; between crossings it keeps moving at the rate of the last two, and holds
-- still while neither of you moves. (The same idea as GoodRange's estimate.)
local estimate = {}
local RATE_WINDOW = 10 -- s; an older crossing is too stale to give a rate

local function Moving()
	local mine, theirs = GetUnitSpeed("player"), GetUnitSpeed("target")
	if mine == nil or theirs == nil or ns.IsSecret(mine) or ns.IsSecret(theirs) then return true end
	return mine > 0 or theirs > 0
end

function ns.EstimateDistance(now, low, high)
	local e = estimate
	if not high then
		wipe(e) -- past the last step there is nothing to measure
		return nil
	end
	if e.low and (low ~= e.low or high ~= e.high) then
		-- Which step was crossed: the near edge of the new range going away, its far edge coming closer
		local edge
		if low >= e.high then
			edge = low
		elseif high <= e.low then
			edge = high
		end
		if edge then
			if e.edge and e.edge ~= edge and now - e.edgeT < RATE_WINDOW then
				e.rate = (edge - e.edge) / (now - e.edgeT)
			else
				e.rate = nil
			end
			e.edge, e.edgeT = edge, now
			e.value = edge
		else
			wipe(e) -- the steps themselves changed: start again
		end
	end
	if not e.value then
		e.value = (low + high) / 2
	elseif e.rate and e.valueT and Moving() then
		e.value = e.value + e.rate * (now - e.valueT)
	end
	e.low, e.high, e.valueT = low, high, now
	e.value = min(max(e.value, low), high)
	return e.value
end

local FONTS = {
	fredoka = "Interface\\AddOns\\HunterGod\\media\\FredokaOne-Regular.ttf",
	changa = "Interface\\AddOns\\HunterGod\\media\\Changa-Bold.ttf",
}
ns.FONTS = FONTS

local function TargetPlate()
	if db.anchor ~= "plate" or ns.unlocked or not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
	return C_NamePlate.GetNamePlateForUnit("target")
end

local function Anchor(newPlate)
	plate = newPlate
	if plate then
		frame:ClearAllPoints()
		frame:SetPoint("BOTTOM", plate, "TOP", 0, 2)
	else
		ns.PlaceFrame(frame)
	end
end

-- The number on the display: the estimate, or the range between two checks
function ns.RangeNumber(low, high, value)
	local scale = db.units == "meters" and YARD or 1
	if db.display == "number" and value then
		return tostring(floor(value * scale + 0.5))
	elseif high then
		return format("%d-%d", floor(low * scale + 0.5), floor(high * scale + 0.5))
	end
	return format("%d+", floor(low * scale + 0.5))
end

local function Show(state, low, high, value)
	local c = db.colors[state]
	frame.text:SetText(ns.RangeNumber(low, high, value))
	frame.unit:SetText(db.units == "meters" and L.METERS or L.YARDS)
	frame.state:SetText(db.showState and L.RANGE[state] or "")
	for _, part in ipairs({ frame.text, frame.unit, frame.state }) do
		part:SetTextColor(c.r, c.g, c.b)
	end
	frame.icon:SetColorTexture(c.r, c.g, c.b)
	local text, icon = db.style ~= "icon", db.style ~= "text"
	local width = (icon and db.textSize * 0.7 or 0) + (icon and text and 6 or 0)
		+ (text and frame.text:GetStringWidth() + 3 + frame.unit:GetStringWidth() or 0)
	frame:SetSize(max(width, 16), db.textSize + 4)
	frame:Show()
end

function ns.StyleRange()
	local text, icon = db.style ~= "icon", db.style ~= "text"
	-- The game's font first: if the bundled one can't load (the game wasn't restarted after
	-- installing), the text keeps that one instead of losing its font
	local gameFont = GameFontNormal:GetFont()
	local unitSize, stateSize = max(floor(db.textSize * 0.5), 8), max(floor(db.textSize * 0.45), 8)
	for _, font in ipairs({ gameFont, FONTS[db.font] or gameFont }) do
		-- A thick black outline keeps the number readable on any ground
		frame.text:SetFont(font, db.textSize, "THICKOUTLINE")
		frame.unit:SetFont(font, unitSize, "OUTLINE")
		frame.state:SetFont(font, stateSize, "OUTLINE")
		melee.text:SetFont(font, 34, "THICKOUTLINE")
	end
	melee:SetSize(max(melee.text:GetStringWidth() + 8, 60), 40)
	-- Blinks between the opacity you choose and a fifth of it
	local alpha = db.meleeAlpha / 100
	melee:SetAlpha(alpha)
	melee.fade:SetFromAlpha(alpha)
	melee.fade:SetToAlpha(alpha * 0.2)
	frame.icon:SetSize(db.textSize * 0.7, db.textSize * 0.7)
	frame.text:SetShown(text)
	frame.unit:SetShown(text)
	frame.state:SetShown(text)
	frame.icon:SetShown(icon)
	frame.iconBorder:SetShown(icon)
	frame.icon:ClearAllPoints()
	frame.text:ClearAllPoints()
	if icon then
		frame.icon:SetPoint("LEFT", 1, 0)
		frame.text:SetPoint("LEFT", frame.icon, "RIGHT", 6, 0)
	else
		frame.text:SetPoint("LEFT", 0, 0)
	end
	frame.unit:ClearAllPoints()
	frame.unit:SetPoint("BOTTOMLEFT", frame.text, "BOTTOMRIGHT", 3, db.textSize * 0.08)
	frame.state:ClearAllPoints()
	frame.state:SetPoint("TOP", frame, "BOTTOM", 0, -1)
	if ns.StyleThreat then ns.StyleThreat() end
end

-- The blinking MELEE RANGE warning, on its own switch
local function MeleeWarning(on)
	if on and db.meleeWarning then
		if not melee:IsShown() then
			melee:Show()
			melee.blink:Play()
		end
	elseif melee:IsShown() then
		melee.blink:Stop()
		melee:Hide()
	end
end

function ns.UpdateRange()
	if not (db.enabled or db.meleeWarning) or not ns.IsHunter() then
		frame:Hide()
		MeleeWarning(false)
		return
	end
	local newPlate = TargetPlate()
	if newPlate ~= plate then Anchor(newPlate) end
	if ns.unlocked then
		-- Samples to drag around
		if db.enabled then Show("ranged", 30, 35, 32) else frame:Hide() end
		MeleeWarning(true)
		return
	end
	local hostile, dead = UnitCanAttack("player", "target"), UnitIsDead("target")
	if ns.IsSecret(hostile) then hostile = true end
	if ns.IsSecret(dead) then dead = false end
	if not UnitExists("target") or not hostile or dead or (db.onlyCombat and not UnitAffectingCombat("player")) then
		frame:Hide()
		MeleeWarning(false)
		return
	end
	local state = ns.RangeState("target")
	if state and db.enabled then
		local low, high = ns.RangeDistance("target", state)
		Show(state, low, high, ns.EstimateDistance(GetTime(), low, high))
	else
		frame:Hide()
	end
	MeleeWarning(state == "melee")
end

local function UnitsCommand(word)
	db.units = (word == "yards" or word == "yardas") and "yards" or "meters"
	ns.UpdateRange()
	ns.Print(format(L.UNITS_SET, strlower(L.UNITS[db.units])))
end
for _, word in ipairs({ "meters", "metres", "metros", "yards", "yardas" }) do
	ns.commands[word] = UnitsCommand
end

frame = CreateFrame("Frame", "HunterGodRange", UIParent)
frame:SetSize(80, 18)
frame:Hide()
frame.iconBorder = frame:CreateTexture(nil, "BORDER")
frame.icon = frame:CreateTexture(nil, "ARTWORK")
frame.iconBorder:SetPoint("TOPLEFT", frame.icon, -1, 1)
frame.iconBorder:SetPoint("BOTTOMRIGHT", frame.icon, 1, -1)
frame.iconBorder:SetColorTexture(0, 0, 0, 0.9)
frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.unit = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.state = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

melee = CreateFrame("Frame", "HunterGodMelee", UIParent)
melee:SetSize(220, 40)
melee:Hide()
melee.text = melee:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
melee.text:SetPoint("CENTER")
melee.text:SetText(L.MELEE_WARNING)
melee.text:SetTextColor(1, 0.12, 0.12)
melee.blink = melee:CreateAnimationGroup()
melee.blink:SetLooping("BOUNCE")
melee.fade = melee.blink:CreateAnimation("Alpha")
melee.fade:SetDuration(0.4)

-- Your threat on the target, under its nameplate, before you pull it off your pet
local threat = CreateFrame("Frame", "HunterGodThreat", UIParent)
threat:SetSize(120, 20)
threat:Hide()
threat.text = threat:CreateFontString(nil, "OVERLAY", "GameFontNormal")
threat.text:SetPoint("CENTER")
threat.blink = threat:CreateAnimationGroup()
threat.blink:SetLooping("BOUNCE")
local threatFade = threat.blink:CreateAnimation("Alpha")
threatFade:SetFromAlpha(1)
threatFade:SetToAlpha(0.3)
threatFade:SetDuration(0.35)

function ns.StyleThreat()
	for _, font in ipairs({ GameFontNormal:GetFont(), FONTS[db.font] or GameFontNormal:GetFont() }) do
		threat.text:SetFont(font, 16, "THICKOUTLINE")
	end
end

-- Do you have the target's aggro, and your threat as the game's tooltip and target frame show
-- it: next to the threat of whoever has the aggro (the pet), rounded. Not the scaled figure,
-- next to what pulls it: at range you pull at 130%, so that one read lower than the tooltip
local function ThreatOnTarget()
	local ok, tanking, _, _, raw = pcall(UnitDetailedThreatSituation, "player", "target")
	if not ok or ns.IsSecret(tanking) or ns.IsSecret(raw) then return end
	return tanking, type(raw) == "number" and floor(raw + 0.5) or nil
end

function ns.UpdateThreat()
	local text, pulled
	if db.threat and ns.IsHunter() then
		if ns.unlocked then
			text = format(L.THREAT, 95)
		elseif UnitExists("target") and (UnitExists("pet") or IsInGroup()) then
			-- Solo without a pet you always have the aggro: nothing to warn about then
			local tanking, percent = ThreatOnTarget()
			if tanking then
				text, pulled = L.THREAT_PULLED, true
			elseif percent and percent >= db.threatPct then
				text = format(L.THREAT, percent)
			end
		end
	end
	if not text then
		threat.blink:Stop()
		threat:Hide()
		threat.anchor = nil -- placed again when it shows
		return
	end
	-- Placed only when where it hangs changes: placing it on every update undid a drag
	local plate = not ns.unlocked and C_NamePlate and C_NamePlate.GetNamePlateForUnit
		and C_NamePlate.GetNamePlateForUnit("target")
	if threat.anchor ~= (plate or "free") then
		threat.anchor = plate or "free"
		if plate then
			threat:ClearAllPoints()
			threat:SetPoint("TOP", plate, "BOTTOM", 0, -2)
		else
			ns.PlaceFrame(threat)
		end
	end
	threat.text:SetText(text)
	if pulled then
		threat.text:SetTextColor(1, 0.15, 0.15)
		if not threat.blink:IsPlaying() then threat.blink:Play() end
	else
		threat.text:SetTextColor(1, 0.55, 0.1)
		threat.blink:Stop()
	end
	threat:SetWidth(threat.text:GetStringWidth() + 8)
	threat:Show()
end

-- A small driver that keeps running while the display is hidden
local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self, event)
	if event == "SPELLS_CHANGED" then
		LearnNames()
		return
	elseif event == "PLAYER_TARGET_CHANGED" then
		wipe(estimate) -- a new target starts a new estimate
		return
	end
	db = ns.db.range
	LearnNames()
	BuildSteps()
	self:RegisterEvent("SPELLS_CHANGED")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	ns.Movable(frame, "range", { "CENTER", "CENTER", 0, -140 }, L.TAB_RANGE)
	ns.Movable(melee, "melee", { "CENTER", "CENTER", 0, 60 }, L.MELEE_WARNING)
	ns.Movable(threat, "threat", { "CENTER", "CENTER", 0, -200 }, L.THREAT_NAME) -- clear of the range's box
	ns.StyleRange()
	table.insert(ns.refreshers, function()
		Anchor(TargetPlate())
		ns.StyleRange()
		ns.UpdateRange()
		ns.UpdateThreat()
	end)
	local threatElapsed = 0
	driver:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		threatElapsed = threatElapsed + dt
		if threatElapsed >= 0.2 then
			threatElapsed = 0
			ns.UpdateThreat()
		end
		if elapsed < 0.05 then return end
		elapsed = 0
		ns.UpdateRange()
	end)
end)
