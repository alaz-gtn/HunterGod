local addonName, ns = ...

-- In a dungeon or raid, a small row with the buffs your group could give you and you don't have:
-- Arcane Intellect with a mage in the group, Fortitude with a priest, Mark of the Wild with a druid,
-- a blessing with a paladin (one per paladin: they don't stack from the same one). Your own class's
-- buffs are left out: your addon reminds you of those already. A click asks for it in the group
-- chat ("Missing Arcane Intellect"); the paladin's opens the blessings to pick which one to ask for.
-- Out of combat only (the game hides other buffs in a fight, and that's when buffs are given).
-- The same file in every ...God addon: only the addon of your character's class draws it
local CLASS_OF = { HunterGod = "HUNTER", MageGod = "MAGE", WarriorGod = "WARRIOR", PaladinGod = "PALADIN",
	RogueGod = "ROGUE", PriestGod = "PRIEST", ShamanGod = "SHAMAN", WarlockGod = "WARLOCK", DruidGod = "DRUID" }
local NO_MANA = { WARRIOR = true, ROGUE = true }
local SIZE = 22
local GAP = 3
local QUIET = 10 -- seconds before the same buff can be asked for again
local DEFAULT_POINT = { "TOP", "TOP", 0, -140 }

-- Who gives what: the spell ids of every rank, and of the group version, which count the same
local GIVERS = {
	{ key = "intellect", class = "MAGE", mana = true, ids = { 1459, 1460, 1461, 10156, 10157, 23028 } },
	{ key = "fortitude", class = "PRIEST", ids = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 } },
	{ key = "mark", class = "DRUID", ids = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850 } },
	{ key = "blessing", class = "PALADIN", blessing = true },
}
-- The blessings, each with its greater version; the first is the one to ask for until you pick another
local BLESSINGS = {
	{ key = "wisdom", ids = { 19742, 25894 }, mana = true },
	{ key = "might", ids = { 19740, 25782 } },
	{ key = "kings", ids = { 20217, 25898 } },
	{ key = "salvation", ids = { 1038, 25895 } },
	{ key = "light", ids = { 19977, 25890 } },
	{ key = "sanctuary", ids = { 20911, 25899 } },
}

local T = {
	NAME = "Missing buffs",
	ASK = "Missing %s",
	NONE = "%s: not on you",
	CLICK = "Click: ask for it in the group chat",
	PICK = "Click: pick the blessing to ask for",
	OPT = "In a dungeon or raid, show the buffs my group can give me and I lack (a click asks for them)",
	OPT_ANYWHERE = "Also outside dungeons and raids",
}
if GetLocale() == "esES" or GetLocale() == "esMX" then
	T.NAME = "Bufos que te faltan"
	T.ASK = "Me falta %s"
	T.NONE = "%s: no lo llevas"
	T.CLICK = "Clic: pedirlo en el chat del grupo"
	T.PICK = "Clic: elegir la bendición que pedir"
	T.OPT = "En mazmorras y bandas, mostrar los bufos que mi grupo me puede dar y no llevo (un clic los pide)"
	T.OPT_ANYWHERE = "También fuera de mazmorras y bandas"
end
ns.GROUP_NEEDS_TEXT = T

local db, bar, menu
local buttons = {}
local asked = {} -- key = when it was last asked for

local function IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	return (GetSpellInfo(id))
end

local function SpellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
	return GetSpellTexture and GetSpellTexture(id)
end

local function Mine()
	local _, class = UnitClass("player")
	return class ~= nil and class == CLASS_OF[addonName]
end

-- The classes in your group (without you): class = how many
local function GroupClasses()
	local count = {}
	local raid = IsInRaid and IsInRaid()
	local n = raid and 40 or 4
	for i = 1, n do
		local unit = (raid and "raid" or "party") .. i
		if UnitExists(unit) and not UnitIsUnit(unit, "player") then
			local _, class = UnitClass(unit)
			if class and not IsSecret(class) then count[class] = (count[class] or 0) + 1 end
		end
	end
	return count
end

-- The names of your buffs, or nil when the game hides them
local function MyBuffs()
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
	local names = {}
	for i = 1, 40 do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if not aura then break end
		if IsSecret(aura) or IsSecret(aura.name) then return end
		names[aura.name] = true
	end
	return names
end

local function Has(names, ids)
	for _, id in ipairs(ids) do
		local name = SpellName(id)
		if name and names[name] then return true end
	end
	return false
end

local function Blessing(key)
	for _, b in ipairs(BLESSINGS) do
		if b.key == key then return b end
	end
	return BLESSINGS[1]
end

-- What you lack: { key, icon, name, blessing }
local function Missing()
	local list = {}
	local _, me = UnitClass("player")
	local names = MyBuffs()
	if not names then return list end
	local classes = GroupClasses()
	for _, g in ipairs(GIVERS) do
		local givers = classes[g.class] or 0
		if givers > 0 and g.class ~= me and not (g.mana and NO_MANA[me]) then
			if g.blessing then
				-- One blessing per paladin: lacking as long as you carry fewer than there are paladins
				local carried = 0
				for _, b in ipairs(BLESSINGS) do
					if Has(names, b.ids) then carried = carried + 1 end
				end
				if carried < givers then
					local b = Blessing(db.blessing)
					list[#list + 1] = { key = g.key, icon = SpellIcon(b.ids[1]), name = SpellName(b.ids[1]) or b.key, blessing = true }
				end
			elseif not Has(names, g.ids) then
				list[#list + 1] = { key = g.key, icon = SpellIcon(g.ids[1]), name = SpellName(g.ids[1]) or g.key }
			end
		end
	end
	return list
end
ns.MissingGroupBuffs = Missing -- for the tests

local function Channel()
	if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
		and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
		return "INSTANCE_CHAT"
	end
	return IsInRaid and IsInRaid() and "RAID" or "PARTY"
end

local function Ask(key, name)
	local now = GetTime()
	if asked[key] and now - asked[key] < QUIET then return end
	asked[key] = now
	SendChatMessage(format(T.ASK, name), Channel())
end

local function Button_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:AddLine(format(T.NONE, self.entry.name), 1, 1, 1)
	GameTooltip:AddLine(self.entry.blessing and T.PICK or T.CLICK, 0.4, 0.7, 1)
	GameTooltip:Show()
end

local function OpenMenu(owner)
	if menu:IsShown() and menu.owner == owner then menu:Hide() return end
	menu.owner = owner
	menu:ClearAllPoints()
	menu:SetPoint("TOP", owner, "BOTTOM", 0, -4)
	local _, me = UnitClass("player")
	local shown = 0
	for i, b in ipairs(BLESSINGS) do
		local row = menu.rows[i]
		local usable = not (b.mana and NO_MANA[me])
		row:SetShown(usable)
		if usable then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 6, -6 - shown * (SIZE + 2))
			shown = shown + 1
		end
	end
	menu:SetHeight(12 + shown * (SIZE + 2) - 2)
	menu:Show()
end

local function Button_OnClick(self)
	if self.entry.blessing then
		OpenMenu(self)
	else
		Ask(self.entry.key, self.entry.name)
	end
end

local function NewButton(i)
	local b = CreateFrame("Button", nil, bar)
	b:SetSize(SIZE, SIZE)
	b:SetPoint("LEFT", (i - 1) * (SIZE + GAP), 0)
	b.edge = b:CreateTexture(nil, "BACKGROUND")
	b.edge:SetAllPoints()
	b.edge:SetColorTexture(0, 0, 0, 1)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b:SetScript("OnEnter", Button_OnEnter)
	b:SetScript("OnLeave", GameTooltip_Hide)
	b:SetScript("OnClick", Button_OnClick)
	buttons[i] = b
	return b
end

local function CreateMenu()
	menu = CreateFrame("Frame", nil, bar)
	menu:SetFrameStrata("DIALOG")
	menu:SetWidth(190)
	menu.bg = menu:CreateTexture(nil, "BACKGROUND")
	menu.bg:SetAllPoints()
	menu.bg:SetColorTexture(0.05, 0.05, 0.07, 0.92)
	menu.rows = {}
	for i, b in ipairs(BLESSINGS) do
		local row = CreateFrame("Button", nil, menu)
		row:SetSize(178, SIZE)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(SIZE - 2, SIZE - 2)
		row.icon:SetPoint("LEFT")
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.icon:SetTexture(SpellIcon(b.ids[1]))
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
		row.text:SetText(SpellName(b.ids[1]) or b.key)
		row.hl = row:CreateTexture(nil, "HIGHLIGHT")
		row.hl:SetAllPoints()
		row.hl:SetColorTexture(1, 1, 1, 0.12)
		row:SetScript("OnClick", function()
			db.blessing = b.key
			menu:Hide()
			Ask("blessing", SpellName(b.ids[1]) or b.key)
			ns.UpdateGroupNeeds()
		end)
		menu.rows[i] = row
	end
	menu:Hide()
end

local function Where()
	local inside, kind = IsInInstance()
	return inside and (kind == "party" or kind == "raid")
end

function ns.UpdateGroupNeeds()
	if not bar then return end
	local list = {}
	if ns.unlocked then
		if db.enabled and Mine() then
			-- A sample to drag: every buff there is
			for _, g in ipairs(GIVERS) do
				local id = g.ids and g.ids[1] or BLESSINGS[1].ids[1]
				list[#list + 1] = { key = g.key, icon = SpellIcon(id), name = SpellName(id) or g.key, blessing = g.blessing }
			end
		end
	elseif db.enabled and Mine() and IsInGroup and IsInGroup() and (db.anywhere or Where())
		and not (InCombatLockdown and InCombatLockdown()) then
		local dead = UnitIsDeadOrGhost("player")
		if IsSecret(dead) or not dead then list = Missing() end
	end
	for i, entry in ipairs(list) do
		local b = buttons[i] or NewButton(i)
		b.entry = entry
		b.icon:SetTexture(entry.icon)
		b:Show()
	end
	for i = #list + 1, #buttons do buttons[i]:Hide() end
	bar:SetSize(max(#list, 1) * (SIZE + GAP) - GAP, SIZE)
	bar:SetShown(#list > 0)
	if #list == 0 and menu then menu:Hide() end
end

-- For the tests
function ns.GroupNeedsState() return { bar = bar, buttons = buttons, menu = menu } end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, unit)
	if event == "PLAYER_LOGIN" then
		db = ns.db.groupNeeds
		bar = CreateFrame("Frame", addonName .. "GroupNeeds", UIParent)
		bar:SetSize(SIZE, SIZE)
		bar:SetFrameStrata("MEDIUM")
		bar:Hide()
		CreateMenu()
		if ns.Movable then ns.Movable(bar, "groupNeeds", DEFAULT_POINT, T.NAME) end
		if ns.refreshers then table.insert(ns.refreshers, ns.UpdateGroupNeeds) end
		for _, e in ipairs({ "UNIT_AURA", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
			"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
			pcall(self.RegisterEvent, self, e) -- an event the game doesn't have would stop the file
		end
	elseif event == "UNIT_AURA" and unit ~= "player" then
		return
	end
	ns.UpdateGroupNeeds()
end)
