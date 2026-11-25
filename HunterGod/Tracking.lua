local _, ns = ...
local L = ns.L

-- In dungeons and raids, a reminder when you aren't tracking creatures: after a while with herbs,
-- minerals or Track Hidden on it's easy to walk in without Humanoids or Beasts. The game's own
-- tracking list says which ones are a hunter's (the minimap menu groups them by that subType) and
-- which is on. A click on the reminder opens your creature trackings as bars, like MageGod's food
-- list, and a click on one tracks it; a right-click leaves that dungeon alone (Blackrock Depths has
-- its ore). The bars are secure buttons, so the list opens and changes out of combat
local HUNTER_TRACKING = 1 -- the subType of a hunter's tracking in the minimap's list
-- Humanoids, Beasts, Undead, Elementals, Demons, Giants and Dragonkin: the order of the list
ns.CREATURE_TRACKS = { 19883, 1494, 19884, 19880, 19878, 19882, 19879 }
local HIDDEN = 19885 -- Track Hidden: stealthed players, not what you fight in a dungeon
-- Improved Tracking's ranks (Survival). In Forever it raises your damage to the creature type you
-- track, which is what makes the tracking worth a reminder (wowhead.com/forever/spell=24293)
local IMPROVED_TRACKING = { 24293, 24294, 24295, 24296, 24297 }
local ROW, ROW_GAP, LIST_WIDTH = 22, 2, 150
local TEST_SECONDS = 20
local ACCENT = { 0.67, 0.83, 0.45 }
local TEXT = { 0.93, 0.93, 0.9 }
local GOLD = { 1, 0.82, 0 }

local db, button, list
local rows = {}
local creatureIDs, creatureNames, hiddenName = {}, {}, nil
local dismissed -- the dungeon you right-clicked it away in
local testUntil = 0 -- GetTime() until which it shows as a test, anywhere

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	return (GetSpellInfo(id))
end

local function SpellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
	return GetSpellTexture and GetSpellTexture(id)
end

local function LearnNames()
	for _, id in ipairs(ns.CREATURE_TRACKS) do
		creatureIDs[id] = true
		local name = SpellName(id)
		if name then creatureNames[name] = true end
	end
	hiddenName = SpellName(HIDDEN)
end

-- A creature tracking: one of the list, by ID or name (Forever may give them other IDs), or any
-- other hunter tracking the game has that isn't Track Hidden
local function IsCreature(info)
	local id = info.spellID
	if id and not ns.IsSecret(id) then
		if id == HIDDEN then return false end
		if creatureIDs[id] then return true end
	end
	if info.name == hiddenName then return false end
	if creatureNames[info.name] then return true end
	return info.type == "spell" and info.subType == HUNTER_TRACKING
end

-- Where a tracking goes in the list: the game's order of the creature types, the rest after
local function Rank(info)
	for i, id in ipairs(ns.CREATURE_TRACKS) do
		if info.spellID == id or info.name == SpellName(id) then return i end
	end
	return #ns.CREATURE_TRACKS + 1
end

-- What the minimap's tracking list says: the creature tracking on (if any), the other spells
-- tracking (herbs, minerals, hidden) and the creature trackings you have. Nil when it can't tell
function ns.ReadTracking()
	if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return end
	local count = C_Minimap.GetNumTrackingTypes()
	if type(count) ~= "number" or ns.IsSecret(count) then return end
	local state = { others = {}, creatures = {} }
	for i = 1, count do
		local info = C_Minimap.GetTrackingInfo(i)
		if info then
			if ns.IsSecret(info.active) or ns.IsSecret(info.name) or ns.IsSecret(info.subType) then return end
			local creature = IsCreature(info)
			if creature then state.creatures[#state.creatures + 1] = info end
			if info.active then
				if creature then
					state.active = info
				elseif info.type == "spell" then
					state.others[#state.others + 1] = info.name
				end
			end
		end
	end
	table.sort(state.creatures, function(a, b)
		local ra, rb = Rank(a), Rank(b)
		if ra ~= rb then return ra < rb end
		return a.name < b.name
	end)
	return state
end

-- The icon the reminder shows: the creature tracking you used last, else the first you have
local function Choice(state)
	for _, info in ipairs(state.creatures) do
		if info.name == db.last then return info end
	end
	return state.creatures[1]
end

-- Any point in Improved Tracking: one of its ranks, or its name in your spellbook if Forever gave
-- it another ID
function ns.HasImprovedTracking()
	for _, id in ipairs(IMPROVED_TRACKING) do
		local known
		if IsPlayerSpell then known = IsPlayerSpell(id) elseif IsSpellKnown then known = IsSpellKnown(id) end
		if known and not ns.IsSecret(known) then return true end
	end
	local name = SpellName(IMPROVED_TRACKING[1])
	if name and C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(name)
		if info and not ns.IsSecret(info) then return true end
	end
	return false
end

local function Dungeon()
	local inside, kind = IsInInstance()
	if not (inside and (kind == "party" or kind == "raid")) then return end
	local name, _, _, _, _, _, _, id = GetInstanceInfo()
	return id or name or true
end

-- Where it can show: any dungeon or raid, where you want your damage; out in the world only if you
-- ask (there herbs and ore are what you track), not on a flight nor in battlegrounds. What a
-- right-click leaves alone: that place
local function Where()
	local dungeon = Dungeon()
	if dungeon then return dungeon end
	if not db.anywhere or (UnitOnTaxi and UnitOnTaxi("player")) then return end
	local inside = IsInInstance()
	if inside then return end
	return "zone:" .. tostring(GetRealZoneText and GetRealZoneText() or "")
end

-- The list's bars: one per creature tracking, the one you use in gold. Out of combat only
local function Row(i)
	local b = rows[i]
	if b then return b end
	b = CreateFrame("Button", "HunterGodTrackingRow" .. i, list, "SecureActionButtonTemplate")
	b:RegisterForClicks("AnyUp", "AnyDown")
	b:SetAttribute("type", "spell")
	b.back = b:CreateTexture(nil, "BACKGROUND")
	b.back:SetAllPoints()
	b.back:SetColorTexture(0.03, 0.05, 0.02, 0.88)
	b.stripe = b:CreateTexture(nil, "BORDER")
	b.stripe:SetPoint("TOPLEFT")
	b.stripe:SetPoint("BOTTOMLEFT")
	b.stripe:SetWidth(2)
	b.stripe:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("LEFT", 6, 0)
	b.icon:SetSize(ROW - 6, ROW - 6)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.edge = b:CreateTexture(nil, "BORDER")
	b.edge:SetPoint("TOPLEFT", b.icon, -1, 1)
	b.edge:SetPoint("BOTTOMRIGHT", b.icon, 1, -1)
	b.edge:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.text:SetPoint("LEFT", b.icon, "RIGHT", 7, 0)
	b.text:SetShadowOffset(1, -1)
	b.text:SetShadowColor(0, 0, 0, 1)
	ns.UseFont(b.text, ns.THIN_FONT, 13, "")
	b:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
	-- Once you've picked one the list goes (the spell has gone off by then)
	b:HookScript("OnClick", function(_, _, down)
		if not down and not InCombatLockdown() then list:Hide() end
	end)
	rows[i] = b
	return b
end

local function FillList(state)
	local creatures = state and state.creatures or {}
	local on = state and state.active and state.active.name or db.last
	local width = LIST_WIDTH
	for i, info in ipairs(creatures) do
		local b = Row(i)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW + ROW_GAP))
		b:SetHeight(ROW)
		b.icon:SetTexture(info.texture)
		b.text:SetText(info.name)
		local color = info.name == on and GOLD or TEXT
		b.text:SetTextColor(color[1], color[2], color[3])
		if b:GetAttribute("spell") ~= info.name then b:SetAttribute("spell", info.name) end
		b.spell = info.name
		width = max(width, (b.text:GetStringWidth() or 0) + ROW + 24)
		b:Show()
	end
	for i = 1, #creatures do rows[i]:SetWidth(width) end
	for i = #creatures + 1, #rows do rows[i]:Hide() end
	list:SetSize(width, max(#creatures * (ROW + ROW_GAP) - ROW_GAP, 1))
	return #creatures
end

local function HideReminder()
	button.pulse:Stop()
	button:Hide()
	if not InCombatLockdown() then list:Hide() end
	ns.LayoutReminders()
end

function ns.UpdateTracking()
	if not button then return end
	local state = ns.ReadTracking()
	if state and state.active then db.last = state.active.name end
	local pick, wrong
	if ns.unlocked then
		-- A sample to drag
		local id = ns.CREATURE_TRACKS[1]
		pick = { texture = SpellIcon(id) or "Interface\\Icons\\Spell_Holy_PrayerOfHealing" }
		wrong = L.TRACK_NONE
	else
		local testing = GetTime() < testUntil
		local place = Where()
		if not testing and not (db.enabled and ns.IsHunter() and state and place and not state.active
			and #state.creatures > 0 and dismissed ~= place and (not db.onlyTalent or ns.HasImprovedTracking())) then
			return HideReminder()
		end
		pick = state and Choice(state)
			or { texture = SpellIcon(ns.CREATURE_TRACKS[1]) or "Interface\\Icons\\Spell_Holy_PrayerOfHealing" }
		if state and state.active then
			wrong = format(L.TRACK_WRONG, state.active.name) -- only while testing
		elseif state and #state.others > 0 then
			wrong = format(L.TRACK_WRONG, table.concat(state.others, ", "))
		else
			wrong = L.TRACK_NONE
		end
	end
	button.icon:SetTexture(pick.texture)
	-- No words on the icon: they're in its tooltip
	button.wrong = wrong
	button:Show()
	ns.LayoutReminders()
	if not button.pulse:IsPlaying() then button.pulse:Play() end
	-- An open list follows the tracking you put on
	if list:IsShown() and not InCombatLockdown() then FillList(state) end
end

local function ToggleList()
	if InCombatLockdown() or ns.unlocked then return end
	if list:IsShown() then
		list:Hide()
		return
	end
	if FillList(ns.ReadTracking()) == 0 then return end
	-- Where the icon is now, on the screen: anchored to the icon, the secure list would stop the
	-- row of reminders from moving in a fight
	list:ClearAllPoints()
	local right, top = button:GetRight(), button:GetTop()
	if right and top and not ns.IsSecret(right) then
		list:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right + 6, top)
	else
		list:SetPoint("TOPLEFT", button, "TOPRIGHT", 6, 0)
	end
	list:Show()
end

-- Shows it for a while anywhere, with your own trackings, to see it and try the list
function ns.TestTracking()
	testUntil = GetTime() + TEST_SECONDS
	ns.UpdateTracking()
	C_Timer.After(TEST_SECONDS + 0.1, ns.UpdateTracking)
end

local function OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:AddLine(self.wrong or L.TRACK_NONE)
	GameTooltip:AddLine(L.TRACK_CLICK, 0.4, 0.7, 1)
	GameTooltip:AddLine(L.TRACK_RIGHT, 0.6, 0.62, 0.58)
	GameTooltip:Show()
end

-- Left: the list. Right: not in this dungeon or zone (and the end of a test)
local function OnClick(self, mouse)
	if ns.unlocked then return end
	if mouse == "RightButton" then
		testUntil = 0
		dismissed = Where()
		GameTooltip_Hide()
		ns.UpdateTracking()
	else
		ToggleList()
	end
end

-- Every tracking the game lists, to check in the game what the addon reads
local function Report()
	ns.Print(format(L.TRACK_TALENT, SpellName(IMPROVED_TRACKING[1]) or "Improved Tracking",
		ns.HasImprovedTracking() and (YES or "yes") or (NO or "no")))
	if not (C_Minimap and C_Minimap.GetNumTrackingTypes) then
		ns.Print(L.TRACK_NO_API)
		return
	end
	for i = 1, C_Minimap.GetNumTrackingTypes() do
		local info = C_Minimap.GetTrackingInfo(i)
		if info then
			ns.Print(format("%d. %s: type %s, subType %s, spell %s, %s%s", i, tostring(info.name), tostring(info.type),
				tostring(info.subType), tostring(info.spellID), info.active and L.TRACK_ON or L.TRACK_OFF,
				IsCreature(info) and (" - " .. L.TRACK_CREATURE) or ""))
		end
	end
end
ns.commands.tracking = ns.TestTracking
ns.commands.rastreo = ns.TestTracking
ns.commands.trackinglist = Report
ns.commands.rastreos = Report

-- The reminder is a plain button, so it can come and go in a fight; only the list is secure
button = CreateFrame("Button", "HunterGodTracking", UIParent)
button:Hide()
ns.StyleReminder(button)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
-- A green arrow in the corner: a click opens the list beside it
button.arrow = button:CreateTexture(nil, "OVERLAY")
button.arrow:SetSize(16, 16)
button.arrow:SetPoint("BOTTOMRIGHT", -1, 1)
button.arrow:SetTexture("Interface\\AddOns\\HunterGod\\media\\arrow")
button.arrow:SetVertexColor(0.35, 1, 0.35)
button:SetScript("OnEnter", OnEnter)
button:SetScript("OnLeave", GameTooltip_Hide)
button:SetScript("OnClick", OnClick)
ns.AddReminder("tracking", button)

-- On the screen, not on the reminder: a secure child would lock the reminder in combat too
list = CreateFrame("Frame", "HunterGodTrackingList", UIParent)
list:SetSize(LIST_WIDTH, ROW)
list:SetFrameStrata("DIALOG")
list:Hide()

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		db = ns.db.tracking
		LearnNames()
		table.insert(ns.refreshers, ns.UpdateTracking)
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("SPELLS_CHANGED")
		-- An event the game doesn't have would stop the rest of the file
		pcall(self.RegisterEvent, self, "MINIMAP_UPDATE_TRACKING")
		pcall(self.RegisterEvent, self, "ZONE_CHANGED_NEW_AREA")
		pcall(self.RegisterEvent, self, "TRAIT_CONFIG_UPDATED") -- talents changed
		pcall(self.RegisterEvent, self, "PLAYER_CONTROL_LOST") -- a flight starts
		pcall(self.RegisterEvent, self, "PLAYER_CONTROL_GAINED")
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- The last moment the game lets the secure list go: it doesn't stay open in a fight
		list:Hide()
		return
	elseif event == "PLAYER_REGEN_ENABLED" then
		if not button:IsShown() then list:Hide() end
	elseif event == "SPELLS_CHANGED" then
		LearnNames()
	end
	ns.UpdateTracking()
end)

ns.TrackingButton = function() return button, list, rows end
