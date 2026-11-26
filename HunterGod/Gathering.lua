local _, ns = ...

-- Herbalists and miners: a reminder when neither Find Herbs nor Find Minerals is on out in the
-- world. It shows the one you had on last (or the first you know) and a click out of combat puts
-- it on. Only one tracking runs at a time in Classic, so either of the two counts. Not in dungeons,
-- raids or battlegrounds, nor on a flight: there you track what you fight, or nothing.
-- The same file in every ...God addon: each one shows the reminder in its own row, asks
-- ns.GatherReminder() what to show and sets ns.GatherChanged to hear when that may have changed
local GATHER = {
	{ key = "herbs", spell = 2383 }, -- Find Herbs (Herbalism)
	{ key = "minerals", spell = 2580 }, -- Find Minerals (Mining)
}
ns.GATHER = GATHER

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

-- Do you know it: by its ID, or by its name in your spellbook if Forever gave it another
local function Knows(id)
	local known
	if IsPlayerSpell then known = IsPlayerSpell(id) elseif IsSpellKnown then known = IsSpellKnown(id) end
	if known and not IsSecret(known) then return true end
	local name = SpellName(id)
	if name and C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(name)
		return type(info) == "table" and not IsSecret(info)
	end
	return false
end

-- Which of the two the minimap's tracking list has on: its key, false for neither, nil when the
-- game doesn't say. The list only holds what you can track, so a gathering tracking in it is one
-- you know (have[key])
local function ReadList(have)
	if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return end
	local count = C_Minimap.GetNumTrackingTypes()
	if type(count) ~= "number" or IsSecret(count) then return end
	local on = false
	for i = 1, count do
		local info = C_Minimap.GetTrackingInfo(i)
		if type(info) == "table" then
			if IsSecret(info.name) or IsSecret(info.active) or IsSecret(info.spellID) then return end
			for _, g in ipairs(GATHER) do
				if (info.spellID and info.spellID == g.spell) or (info.name and info.name == SpellName(g.spell)) then
					have[g.key] = true
					if info.active then on = g.key end
				end
			end
		end
	end
	return on
end

-- Out in the world: in no instance of any kind (dungeon, raid, battleground, arena) nor on a flight
local function OutInTheWorld()
	local flying = UnitOnTaxi and UnitOnTaxi("player")
	if flying and not IsSecret(flying) then return false end
	local inside = IsInInstance()
	if IsSecret(inside) then return false end
	return not inside
end

-- What to remind you of now: { key, spell = its name for a click, icon } or nil. It writes down
-- the one you have on, so the reminder brings back the one you used last
function ns.GatherReminder()
	local db = ns.db and ns.db.gather
	if not (db and db.enabled) then return end
	local have = {}
	for _, g in ipairs(GATHER) do
		if Knows(g.spell) then have[g.key] = true end
	end
	local on = ReadList(have)
	if on then
		db.last = on
		return
	end
	if on == nil or not OutInTheWorld() then return end
	-- The addon may have its own reason to leave it alone (HunterGod: you track creatures out here)
	if ns.GatherBlocked and ns.GatherBlocked() then return end
	local pick
	for _, g in ipairs(GATHER) do
		if have[g.key] and (not pick or g.key == db.last) then pick = g end
	end
	if not pick then return end
	local name = SpellName(pick.spell)
	return { key = pick.key, spell = name, name = name, icon = SpellIcon(pick.spell) }
end

-- The tracking changes, or you go in or out of an instance: the addon looks again
local events = CreateFrame("Frame")
for _, event in ipairs({ "MINIMAP_UPDATE_TRACKING", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
	pcall(events.RegisterEvent, events, event) -- an event the game doesn't have would stop the file
end
events:SetScript("OnEvent", function()
	if ns.db and ns.GatherChanged then ns.GatherChanged() end
end)
