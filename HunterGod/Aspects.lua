local _, ns = ...
local L = ns.L

-- First rank of each aspect: the spell name matches every rank
ns.ASPECTS = {
	hawk = 13165,
	monkey = 13163,
	cheetah = 5118,
	pack = 13159,
	beast = 13161,
	wild = 20043,
}
-- Aspects that get you dazed when something hits you
local TRAVEL = { cheetah = true, pack = true }

local db, frame
local byName = {}
local current -- the active aspect: a key from ns.ASPECTS, false for none, nil when unknown
local inCombat = false

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	return (GetSpellInfo(id))
end

local function SpellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
	return GetSpellTexture(id)
end

local function Knows(id)
	if IsPlayerSpell then return IsPlayerSpell(id) end
	return IsSpellKnown(id)
end

function ns.AspectName(key)
	return SpellName(ns.ASPECTS[key]) or key
end

local function LearnNames()
	wipe(byName)
	for key, id in pairs(ns.ASPECTS) do
		local name = SpellName(id)
		if name then byName[name] = key end
	end
end

-- Reads the active aspect from your buffs. In combat Forever hides them: then the
-- aspect is followed through the ones you cast.
local function Scan()
	if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return end
	local found = false
	for i = 1, 40 do
		local name
		if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
			local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
			if not aura or ns.IsSecret(aura) then
				if aura then return end
				break
			end
			name = aura.name
		else
			name = UnitBuff("player", i)
			if not name then break end
		end
		if ns.IsSecret(name) then return end
		if byName[name] then
			found = byName[name]
			break
		end
	end
	current = found
end

-- The aspect to warn about when it's missing, or nil
local function Wanted()
	if db.preferred == "any" then return "any" end
	if Knows(ns.ASPECTS[db.preferred]) then return db.preferred end
	-- Below level 10 there is no Hawk yet
	if db.preferred == "hawk" and Knows(ns.ASPECTS.monkey) then return "monkey" end
end

local function Warn(key, text, missing)
	frame.icon:SetTexture(SpellIcon(ns.ASPECTS[key]))
	frame.icon:SetDesaturated(missing or false)
	-- The icon says it alone: the words underneath only if you want them
	frame.text:SetText(text)
	frame.text:SetShown(db.text)
	frame:Show()
	if not frame.pulse:IsPlaying() then frame.pulse:Play() end
end

function ns.UpdateAspect()
	if not db.enabled or not ns.IsHunter() then
		frame:Hide()
		return
	end
	if ns.unlocked then
		Warn("cheetah", format(L.ASPECT_TRAVEL, ns.AspectName("cheetah")))
		return
	end
	if not inCombat then
		frame:Hide()
		return
	end
	if current and TRAVEL[current] and db.travel then
		Warn(current, format(L.ASPECT_TRAVEL, ns.AspectName(current)))
		return
	end
	local want = db.missing and current ~= nil and Wanted()
	if want == "any" and current == false then
		Warn("hawk", L.ASPECT_NONE, true)
		return
	end
	if want and want ~= "any" and current ~= want then
		Warn(want, format(L.ASPECT_MISSING, ns.AspectName(want)), true)
		return
	end
	frame:Hide()
end

-- For the tests: what the addon thinks is active
function ns.CurrentAspect()
	return current
end

frame = CreateFrame("Frame", "HunterGodAspect", UIParent)
frame:SetSize(40, 40)
frame:Hide()
local border = frame:CreateTexture(nil, "BORDER")
border:SetPoint("TOPLEFT", -2, 2)
border:SetPoint("BOTTOMRIGHT", 2, -2)
border:SetColorTexture(0.9, 0.1, 0.1, 0.9)
frame.icon = frame:CreateTexture(nil, "ARTWORK")
frame.icon:SetAllPoints()
frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.text:SetPoint("TOP", frame, "BOTTOM", 0, -4)
frame.text:SetTextColor(1, 0.3, 0.2)
frame.pulse = frame:CreateAnimationGroup()
frame.pulse:SetLooping("BOUNCE")
local fade = frame.pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.45)
fade:SetDuration(0.6)

-- Trueshot Aura lasts 30 minutes: a reminder in its last two, and once it's gone. Forever hides
-- your buffs in combat, so its end comes from when you last saw it on you or cast it
local TRUESHOT = { 19506, 20905, 20906 } -- its ranks
local TRUESHOT_WARN = 120 -- s left when the reminder shows
local trueshot
local trueshotName
local trueshotTime = 1800 -- how long it lasts, as the game said last time
local trueshotEnds -- GetTime() when it runs out, false when it's not on you, nil while unknown
local trueshotKnown = false

local function LearnTrueshot()
	trueshotName = SpellName(TRUESHOT[1])
	trueshotKnown = false
	for _, id in ipairs(TRUESHOT) do
		if Knows(id) then trueshotKnown = true end
	end
	-- Forever may give it other ids: the spellbook answers for its name
	if not trueshotKnown and trueshotName and C_Spell and C_Spell.GetSpellInfo then
		trueshotKnown = C_Spell.GetSpellInfo(trueshotName) ~= nil
	end
end

local function ScanTrueshot()
	if not trueshotName or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
	if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return end
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if not aura then break end
		if ns.IsSecret(aura) or ns.IsSecret(aura.name) then return end
		if aura.name == trueshotName then
			local ends, duration = aura.expirationTime, aura.duration
			if ns.IsSecret(ends) then return end
			if type(duration) == "number" and not ns.IsSecret(duration) and duration > 0 then trueshotTime = duration end
			-- No end: it lasts until you cancel it, nothing to remind
			trueshotEnds = type(ends) == "number" and ends > 0 and ends or math.huge
			return
		end
	end
	trueshotEnds = false
end

function ns.UpdateTrueshot()
	local left
	if ns.unlocked then
		if db.trueshot then left = 95 end -- a sample to drag
	elseif db.trueshot and ns.IsHunter() and trueshotKnown and trueshotEnds ~= nil
		and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then
		left = trueshotEnds and max(trueshotEnds - GetTime(), 0) or 0
		if left > TRUESHOT_WARN then left = nil end
	end
	if not left then
		trueshot.pulse:Stop()
		trueshot:Hide()
		return
	end
	-- Grey once it's gone
	trueshot.icon:SetDesaturated(left == 0)
	trueshot.text:SetText(left > 0 and format("%d:%02d", floor(left / 60), floor(left % 60)) or "")
	trueshot:Show()
	if not trueshot.pulse:IsPlaying() then trueshot.pulse:Play() end
end

trueshot = CreateFrame("Frame", "HunterGodTrueshot", UIParent)
trueshot:SetSize(36, 36)
trueshot:Hide()
local trueshotBorder = trueshot:CreateTexture(nil, "BORDER")
trueshotBorder:SetPoint("TOPLEFT", -2, 2)
trueshotBorder:SetPoint("BOTTOMRIGHT", 2, -2)
trueshotBorder:SetColorTexture(1, 0.75, 0.1, 0.9)
trueshot.icon = trueshot:CreateTexture(nil, "ARTWORK")
trueshot.icon:SetAllPoints()
trueshot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
trueshot.text = trueshot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
trueshot.text:SetPoint("TOP", trueshot, "BOTTOM", 0, -3)
trueshot.text:SetTextColor(1, 0.82, 0.2)
trueshot.pulse = trueshot:CreateAnimationGroup()
trueshot.pulse:SetLooping("BOUNCE")
local trueshotFade = trueshot.pulse:CreateAnimation("Alpha")
trueshotFade:SetFromAlpha(1)
trueshotFade:SetToAlpha(0.5)
trueshotFade:SetDuration(0.8)

-- TRAPS READY when the traps are back after one was used in a fight. Traps share their
-- cooldown; laying one after Feign Death (out of combat for a moment) still counts.
local TRAPS = { 1499, 13795, 13809, 13813 } -- Freezing, Immolation, Frost and Explosive Trap
local FIGHT_GRACE = 10 -- s after combat that still counts as the fight
local TRAP_COOLDOWN = 15
local SHOW_TIME = 3
local trapsDB, traps
local trapNames = {}
local lastCombat = -math.huge
local trapToken = 0

local function LearnTrapNames()
	wipe(trapNames)
	for _, id in ipairs(TRAPS) do
		local name = SpellName(id)
		if name then trapNames[name] = true end
	end
end

-- Seconds until the trap is ready again. Forever may hide cooldowns in combat: then the
-- spell's own cooldown is used
local function TrapCooldown(spellID)
	local cd = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID)
	if type(cd) == "table" and not ns.IsSecret(cd.startTime) and not ns.IsSecret(cd.duration)
		and cd.duration and cd.duration > 1.5 then
		return max(cd.startTime + cd.duration - GetTime(), 0)
	end
	local base = GetSpellBaseCooldown and GetSpellBaseCooldown(spellID)
	if type(base) == "number" and not ns.IsSecret(base) and base > 0 then return base / 1000 end
	return TRAP_COOLDOWN
end

local function ShowTrapsReady(spellID)
	traps.icon:SetTexture(SpellIcon(spellID))
	traps.showing = true
	traps:Show()
	traps.pulse:Play()
	trapToken = trapToken + 1
	local token = trapToken
	C_Timer.After(SHOW_TIME, function()
		if token ~= trapToken then return end
		traps.showing = false
		if not ns.unlocked then
			traps.pulse:Stop()
			traps:Hide()
		end
	end)
end

local function TrapUsed(spellID)
	if not trapsDB.enabled or not (inCombat or GetTime() - lastCombat < FIGHT_GRACE) then return end
	-- The cooldown starts a moment after the cast
	C_Timer.After(0.1, function()
		C_Timer.After(TrapCooldown(spellID), function() ShowTrapsReady(spellID) end)
	end)
end

function ns.UpdateTraps()
	if ns.unlocked and trapsDB.enabled then
		traps.icon:SetTexture(SpellIcon(TRAPS[1]))
		traps:Show()
	elseif not traps.showing or not trapsDB.enabled then
		traps.pulse:Stop()
		traps:Hide()
	end
end

traps = CreateFrame("Frame", "HunterGodTraps", UIParent)
traps:SetSize(200, 36)
traps:Hide()
traps.icon = traps:CreateTexture(nil, "ARTWORK")
traps.icon:SetSize(32, 32)
traps.icon:SetPoint("LEFT")
traps.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
traps.text = traps:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
traps.text:SetPoint("LEFT", traps.icon, "RIGHT", 8, 0)
traps.text:SetTextColor(0.35, 1, 0.35)
traps.pulse = traps:CreateAnimationGroup()
traps.pulse:SetLooping("BOUNCE")
local glow = traps.pulse:CreateAnimation("Alpha")
glow:SetFromAlpha(1)
glow:SetToAlpha(0.5)
glow:SetDuration(0.35)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit, _, spellID)
	if event == "PLAYER_LOGIN" then
		db = ns.db.aspect
		trapsDB = ns.db.traps
		ns.Movable(frame, "aspect", { "CENTER", "CENTER", 0, 120 }, L.TAB_ASPECTS)
		traps.text:SetText(L.TRAPS_READY)
		for _, font in ipairs({ GameFontNormal:GetFont(), ns.FONTS and ns.FONTS[ns.db.range.font] }) do
			traps.text:SetFont(font, 24, "THICKOUTLINE")
		end
		traps:SetWidth(traps.text:GetStringWidth() + 44)
		ns.Movable(traps, "traps", { "CENTER", "CENTER", 0, -40 }, L.TRAPS_READY)
		LearnTrueshot()
		trueshot.icon:SetTexture(SpellIcon(TRUESHOT[1]))
		for _, font in ipairs({ GameFontNormal:GetFont(), ns.FONTS and ns.FONTS[ns.db.range.font] }) do
			trueshot.text:SetFont(font, 16, "THICKOUTLINE")
		end
		ns.Movable(trueshot, "trueshot", { "CENTER", "CENTER", 160, 120 }, trueshotName or L.TRUESHOT)
		table.insert(ns.refreshers, ns.UpdateTrueshot)
		-- Its countdown ticks on its own
		local clock = CreateFrame("Frame")
		local since = 0
		clock:SetScript("OnUpdate", function(_, dt)
			since = since + dt
			if since < 0.25 then return end
			since = 0
			ns.UpdateTrueshot()
		end)
		table.insert(ns.refreshers, ns.UpdateAspect)
		table.insert(ns.refreshers, ns.UpdateTraps)
		LearnNames()
		LearnTrapNames()
		Scan()
		ScanTrueshot()
		self:RegisterUnitEvent("UNIT_AURA", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("SPELLS_CHANGED")
		ns.UpdateAspect()
	elseif event == "UNIT_AURA" then
		Scan()
		ScanTrueshot()
		ns.UpdateAspect()
		ns.UpdateTrueshot()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if unit ~= "player" or ns.IsSecret(spellID) then return end
		local name = spellID and SpellName(spellID)
		if name and byName[name] then
			current = byName[name]
			ns.UpdateAspect()
		elseif name and trapNames[name] then
			TrapUsed(spellID)
		elseif name and name == trueshotName then
			trueshotKnown = true
			trueshotEnds = GetTime() + trueshotTime
			ns.UpdateTrueshot()
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
		ns.UpdateAspect()
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		lastCombat = GetTime()
		Scan()
		ScanTrueshot()
		ns.UpdateAspect()
		ns.UpdateTrueshot()
	elseif event == "SPELLS_CHANGED" then
		LearnNames()
		LearnTrapNames()
		LearnTrueshot()
	end
end)

-- How long the mob in your Freezing Trap stays frozen, beside its nameplate. Forever keeps
-- auras from addons in combat, so the game draws this one itself, as ForeverAuras does: an
-- aura container on each nameplate token shows that debuff alone, with its icon and countdown
local FREEZE = { 3355, 14308, 14309, 27753, 1285994, 1288849, 1288851, 1288852, 1294351,
	1294353, 1294444, 1324500, 1324501, 1324502 } -- every Freezing Trap aura in Forever's spells
local PLATES = 40 -- nameplate1 to nameplate40
local freezeSlots = {} -- by nameplate number: { holder, container, plate }

-- Next to the plate's health bar, not its wider click area
local function PlateBar(plate)
	local unitFrame = plate.UnitFrame
	local bar = unitFrame and (unitFrame.healthBar
		or unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar)
	return bar or plate
end
ns.PlateBar = PlateBar

local function PlaceFreeze(unit)
	local slot = freezeSlots[tonumber(unit:match("^nameplate(%d+)$") or "")]
	if not slot then return end
	local holder = slot.holder
	-- A frame the game protects can't be moved in combat: it waits for the end of the fight
	if InCombatLockdown() and holder:IsProtected() then
		slot.pending = true
		return
	end
	local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit(unit)
	if not (trapsDB.freeze and plate) or plate:IsForbidden() then
		holder:Hide()
		return
	end
	if slot.plate ~= plate then
		holder:SetParent(plate)
		holder:ClearAllPoints()
		if pcall(holder.SetPoint, holder, "RIGHT", PlateBar(plate), "LEFT", -6, 0) then slot.plate = plate end
	end
	holder:Show()
	-- The token may name another mob now
	pcall(slot.container.UpdateAllAuras, slot.container)
end

local function StyleFreeze(button, container)
	button:SetAllPoints(container)
	button:EnableMouse(false)
	local edge = button:CreateTexture(nil, "BACKGROUND")
	edge:SetPoint("TOPLEFT", -2, 2)
	edge:SetPoint("BOTTOMRIGHT", 2, -2)
	edge:SetColorTexture(0.45, 0.8, 1, 0.9)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(button)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button:SetIcon(icon)
	-- The game counts down a time the addon can't read
	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetAllPoints(button)
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetHideCountdownNumbers(false)
	cooldown:SetUseAuraDisplayTime(true)
	if cooldown.SetMinimumCountdownDuration then cooldown:SetMinimumCountdownDuration(0) end
	button:SetDurationCooldown(cooldown)
	local numbers = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
	if numbers then
		for _, font in ipairs({ GameFontNormal:GetFont(), ns.FONTS and ns.FONTS[ns.db.range.font] }) do
			numbers:SetFont(font, 15, "THICKOUTLINE")
		end
		numbers:ClearAllPoints()
		numbers:SetPoint("CENTER", button, "CENTER", 0, 0)
		numbers:SetTextColor(0.8, 0.95, 1)
	end
end

-- Built out of combat; a build the game refuses is tried again when the fight ends
local function BuildFreeze()
	if InCombatLockdown() or not (CustomAuraContainerAuraProcessingPolicy and C_UnitAuras) then return end
	local spells = {}
	for _, id in ipairs(FREEZE) do spells[id] = true end
	for i = #freezeSlots + 1, PLATES do
		local holder = CreateFrame("Frame", nil, UIParent)
		holder:SetSize(28, 28)
		holder:Hide()
		local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
		if not ok or not container then return end
		container:SetAllPoints(holder)
		container:SetEnabled(false)
		container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
		if not pcall(container.AddAuraSlot, container, "HunterGodFreeze", "HARMFUL", {
			candidateFilters = { includeSpellIDs = spells },
			initializeFrame = function(button) StyleFreeze(button, container) end,
		}) then
			return
		end
		container:SetUnit("nameplate" .. i)
		container:SetEnabled(true)
		freezeSlots[i] = { holder = holder, container = container }
		PlaceFreeze("nameplate" .. i)
	end
end

function ns.UpdateFreeze()
	for i in pairs(freezeSlots) do PlaceFreeze("nameplate" .. i) end
end

local freezeEvents = CreateFrame("Frame")
freezeEvents:RegisterEvent("PLAYER_LOGIN")
freezeEvents:SetScript("OnEvent", function(self, event, unit)
	if event == "PLAYER_LOGIN" then
		self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		BuildFreeze()
	elseif event == "PLAYER_REGEN_ENABLED" then
		BuildFreeze()
		for i, slot in pairs(freezeSlots) do
			if slot.pending then
				slot.pending = nil
				PlaceFreeze("nameplate" .. i)
			end
		end
	elseif event == "NAME_PLATE_UNIT_ADDED" and not ns.IsSecret(unit) then
		PlaceFreeze(unit)
	end
end)

-- /huntergod dr: logs what the game says about diminishing returns. Forever keeps its own, for
-- PvP, and sends it to addons; this shows what of it an addon can read in combat
local DR_EVENT = "UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED"
local DR_FIELDS = { "category", "startTime", "duration", "showCountdown", "isImmune" }
local drLog

local function Shown(value)
	if ns.IsSecret(value) then return L.DR_SECRET end
	if type(value) == "number" and value % 1 ~= 0 then return format("%.1f", value) end
	return tostring(value)
end

local function LogDR(_, _, unit, info)
	local parts = {}
	if ns.IsSecret(info) then
		parts[1] = L.DR_SECRET
	else
		for _, key in ipairs(DR_FIELDS) do
			local ok, value = pcall(function() return info[key] end)
			parts[#parts + 1] = key .. "=" .. (ok and Shown(value) or L.DR_SECRET)
		end
	end
	local name = not ns.IsSecret(unit) and select(2, pcall(UnitName, unit))
	ns.Print(format(L.DR_EVENT, Shown(unit), Shown(name or "?"), Shown(GetTime()), table.concat(parts, " ")))
end

local function DRCategories(api, ruleset)
	local value = Enum.SpellDiminishRuleset and Enum.SpellDiminishRuleset[ruleset]
	local ok, list = pcall(api.GetAllSpellDiminishCategories, value)
	local names = {}
	for _, info in ipairs(ok and type(list) == "table" and list or {}) do
		local tracked = select(2, pcall(api.ShouldTrackSpellDiminishCategory, info.category, value))
		names[#names + 1] = format("%s (%s, %s)", Shown(info.name), Shown(info.category), Shown(tracked))
	end
	return #names > 0 and table.concat(names, ", ") or L.DR_NONE
end

local function DRReport()
	local api = C_SpellDiminish
	if not api then
		ns.Print(L.DR_NO_API)
		return
	end
	local function CVar(name)
		local ok, value = pcall(C_CVar.GetCVar, name)
		return ok and value ~= nil and Shown(value) or "?"
	end
	ns.Print(format(L.DR_STATUS, Shown(api.IsSystemSupported and api.IsSystemSupported()),
		CVar("spellDiminishPVPEnemiesEnabled"), CVar("spellDiminishPVPOnlyTriggerableByMe")))
	if _G.SPELL_DIMINISH_PVP_ENABLE_SETTING_LABEL then
		ns.Print(format(L.DR_OPTION, _G.SPELL_DIMINISH_PVP_ENABLE_SETTING_LABEL))
	end
	ns.Print(format(L.DR_RULESET, "PvE", DRCategories(api, "PvE")))
	ns.Print(format(L.DR_RULESET, "PvP", DRCategories(api, "PvP")))
	if not drLog then
		drLog = CreateFrame("Frame")
		drLog:SetScript("OnEvent", LogDR)
	end
	drLog.on = not drLog.on
	if not drLog.on then
		drLog:UnregisterEvent(DR_EVENT)
		ns.Print(L.DR_OFF)
	elseif pcall(drLog.RegisterEvent, drLog, DR_EVENT) then
		ns.Print(L.DR_ON)
	else
		drLog.on = false
		ns.Print(L.DR_NO_EVENT)
	end
end
ns.commands.dr = DRReport
