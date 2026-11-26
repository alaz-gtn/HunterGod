local addonName, ns = ...
local L = ns.L

-- When the price of resetting your talents goes back down: a note under your class trainer's
-- window and beside the trainer's price. The game doesn't say: addons see the price only when you
-- ask the trainer for the reset (CONFIRM_TALENT_WIPE), and never when you last paid for one.
-- Players report it going up a step with each reset (1, 5, 10, then 5 g more each time up to
-- 50 g) and down a step for each week since the last one, to 1 g (dtgre and LFCarry, Nov 2026;
-- Blizzard hasn't published it). So the addon writes down each reset you pay for and each price
-- the trainer asks, and counts the weeks from there. The same file serves the whole family: the
-- class comes from the addon's name (PriestGod: PRIEST) and the colour from its Init.lua
local CLASS = strupper((addonName:gsub("God$", "")))
local ACCENT = ns.ACCENT or ({ MageGod = { 0.25, 0.78, 0.92 }, HunterGod = { 0.67, 0.83, 0.45 } })[addonName]
	or { 1, 0.82, 0 }
local GOLD = 10000
local TIERS = { 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50 } -- in gold
local WEEK = 7 * 24 * 3600
local PAY_WAIT = 10 -- s for the gold to go once you accept
local WIDTH = 300
local CLASS_KIND = "0" -- the game's kind of reset for class talents; any other is the legacy tree

local records -- this character's, by kind: { reset, paid, seen, cost }, times from the server's clock
local asked -- the last price the trainer asked: { kind, cost }
local pending -- a reset you accepted, until its gold goes
local lastOption -- the trainer's option you chose last: { id, at }

local function Now()
	return GetServerTime and GetServerTime() or time()
end

-- The step a price is at (0 below the first) and the price some steps up or down from it
local function StepOf(copper)
	local step = 0
	for i, gold in ipairs(TIERS) do
		if copper >= gold * GOLD then step = i end
	end
	return step
end

local function Step(copper, steps)
	return TIERS[max(1, min(#TIERS, StepOf(copper) + steps))] * GOLD
end

-- The price now and whether it's the one the trainer asked, then when it next drops and to what
function ns.RespecPrice(rec, now)
	local weeks = floor((now - rec.reset) / WEEK)
	local cost, exact
	if rec.seen and rec.seen >= rec.reset then
		local since = weeks - floor((rec.seen - rec.reset) / WEEK)
		if since > 0 then cost = Step(rec.cost, -since) else cost, exact = rec.cost, true end
	else
		cost = Step(rec.paid, 1 - weeks)
	end
	if cost <= TIERS[1] * GOLD then return cost, exact end
	return cost, exact, rec.reset + (weeks + 1) * WEEK, Step(cost, -1)
end

local function Money(copper)
	local coins = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString or GetCoinTextureString
	if coins then return coins(copper) end
	return format("%g g", copper / GOLD)
end

local function Span(seconds)
	if seconds < 3600 then return format(L.RESPEC_MINUTES, max(1, floor(seconds / 60))) end
	if seconds < 48 * 3600 then return format(L.RESPEC_HOURS, floor(seconds / 3600)) end
	return format(L.RESPEC_DAYS, floor(seconds / 86400))
end

-- A moment in the next week: today, tomorrow or the day's name, and the time, on your clock
local function When(t, now)
	local day, today, tomorrow = date("*t", t), date("*t", now), date("*t", now + 86400)
	local clock = date("%H:%M", t)
	if day.yday == today.yday and day.year == today.year then return format(L.RESPEC_TODAY, clock) end
	if day.yday == tomorrow.yday and day.year == tomorrow.year then return format(L.RESPEC_TOMORROW, clock) end
	return format(L.RESPEC_ON, L.RESPEC_WEEKDAYS[day.wday], clock)
end

local function Lines(rec, now, out)
	if not (rec and rec.reset) then
		if rec and rec.cost and rec.seen then
			out[#out + 1] = format(L.RESPEC_ASKED, Money(rec.cost), Span(now - rec.seen))
		end
		out[#out + 1] = format(L.RESPEC_UNKNOWN, addonName)
		return
	end
	out[#out + 1] = format(L.RESPEC_LAST, Span(now - rec.reset), Money(rec.paid))
	local cost, exact, at, lower = ns.RespecPrice(rec, now)
	out[#out + 1] = format(exact and L.RESPEC_NOW or L.RESPEC_NOW_ABOUT, Money(cost))
	if at then
		out[#out + 1] = format(L.RESPEC_DROPS, Money(lower), When(at, now), Span(at - now))
	else
		out[#out + 1] = L.RESPEC_LOWEST
	end
end

-- What the note says: each kind of reset the addon knows of, class talents first
local function Report(onlyKind)
	local now, out, kinds = Now(), {}, {}
	if onlyKind then
		kinds[1] = onlyKind
	else
		for kind in pairs(records) do kinds[#kinds + 1] = kind end
		table.sort(kinds)
		if #kinds == 0 then kinds[1] = CLASS_KIND end
	end
	for _, kind in ipairs(kinds) do
		if #kinds > 1 then
			out[#out + 1] = format("|cffffd200%s|r", kind == CLASS_KIND and L.RESPEC_CLASS or L.RESPEC_LEGACY)
		end
		Lines(records[kind], now, out)
	end
	return out
end

-- The note: dark, with the addon's colour along the top, like its other windows
local note = CreateFrame("Frame", addonName .. "Respec", UIParent)
note:SetSize(WIDTH, 60)
note:SetFrameStrata("DIALOG")
note:Hide()
local function Rect(layer, r, g, b, a, sub)
	local t = note:CreateTexture(nil, layer, nil, sub)
	t:SetColorTexture(r, g, b, a)
	return t
end
local noteEdge = Rect("BACKGROUND", 0, 0, 0, 0.9, -8)
noteEdge:SetPoint("TOPLEFT", -1, 1)
noteEdge:SetPoint("BOTTOMRIGHT", 1, -1)
Rect("BACKGROUND", 0.07, 0.075, 0.068, 0.95, -7):SetAllPoints()
local noteLine = Rect("ARTWORK", ACCENT[1], ACCENT[2], ACCENT[3], 0.7)
noteLine:SetPoint("TOPLEFT")
noteLine:SetPoint("TOPRIGHT")
noteLine:SetHeight(1)
local noteLogo = note:CreateTexture(nil, "ARTWORK")
noteLogo:SetSize(16, 16)
noteLogo:SetPoint("TOPLEFT", 8, -7)
noteLogo:SetTexture("Interface\\AddOns\\" .. addonName .. "\\media\\icon")
note.title = note:CreateFontString(nil, "OVERLAY", "GameFontNormal")
note.title:SetPoint("LEFT", noteLogo, "RIGHT", 6, 0)
note.title:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
note.body = note:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
note.body:SetPoint("TOPLEFT", 10, -30)
note.body:SetWidth(WIDTH - 20)
note.body:SetJustifyH("LEFT")
note.body:SetSpacing(3)

-- Under the trainer's window ("left": lined up with it) or the price dialog (centred under it)
local function ShowNote(anchor, how, onlyKind)
	local lines = Report(onlyKind)
	note.title:SetText(L.RESPEC_TITLE)
	note.body:SetText(table.concat(lines, "\n"))
	local h = note.body:GetStringHeight()
	if type(h) ~= "number" or ns.IsSecret(h) then h = #lines * 15 end
	note:SetHeight(h + 40)
	note:ClearAllPoints()
	if how == "left" then
		note:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
	else
		note:SetPoint("TOP", anchor, "BOTTOM", 0, -6)
	end
	note.anchor = anchor
	note:Show()
end

-- It goes with what it hangs from
local since = 0
note:SetScript("OnUpdate", function(self, dt)
	since = since + dt
	if since < 0.2 then return end
	since = 0
	if not (self.anchor and self.anchor:IsShown()) then self:Hide() end
end)

-- Your class trainer: an option about talents, in whatever language the game speaks, or one the
-- addon saw lead to the reset before
local function IsTalentMaster()
	if not (C_GossipInfo and C_GossipInfo.GetOptions) then return false end
	local learned = ns.db.respec.options
	for _, option in ipairs(C_GossipInfo.GetOptions() or {}) do
		local id, name = option.gossipOptionID, option.name
		if id and not ns.IsSecret(id) and learned[id] then return true end
		if type(name) == "string" and not ns.IsSecret(name) and strlower(name):find("talent", 1, true) then return true end
	end
	return false
end

local function Paid()
	local rec = records[pending.kind] or {}
	records[pending.kind] = rec
	rec.reset, rec.paid, rec.seen, rec.cost = Now(), pending.cost, nil, nil
	pending = nil
end

-- You accepted the price: it counts once the gold goes, as the game may still say no. A free
-- reset isn't one the price counts
local function Accepted()
	if not (asked and records) or asked.cost <= 0 then return end
	local money = GetMoney()
	if ns.IsSecret(money) then return end
	local mine = { kind = asked.kind, cost = asked.cost, money = money, at = GetTime() }
	pending = mine
	C_Timer.After(PAY_WAIT, function()
		if pending == mine then pending = nil end
	end)
end

local function Chose(id)
	lastOption = { id = id, at = GetTime() }
end

local function Tell()
	if not records then return end
	ns.Print(L.RESPEC_TITLE)
	for _, line in ipairs(Report()) do print("  " .. line) end
end
ns.commands.respec = Tell
ns.commands.talentos = Tell

local hooked = false
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
-- An event the game doesn't have would stop the rest of the file
for _, event in ipairs({ "GOSSIP_SHOW", "GOSSIP_CLOSED", "CONFIRM_TALENT_WIPE", "PLAYER_MONEY" }) do
	pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... ~= addonName then return end
		local saved = addonName .. "CharDB"
		_G[saved] = _G[saved] or {}
		_G[saved].respec = _G[saved].respec or {}
		records = _G[saved].respec
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		if hooked or not hooksecurefunc then return end
		hooked = true
		if ConfirmTalentWipe then hooksecurefunc("ConfirmTalentWipe", Accepted) end
		if C_GossipInfo and C_GossipInfo.SelectOption then hooksecurefunc(C_GossipInfo, "SelectOption", Chose) end
	elseif not (records and ns.db) or select(2, UnitClass("player")) ~= CLASS then
		return
	elseif event == "GOSSIP_SHOW" then
		if ns.db.respec.enabled and GossipFrame and IsTalentMaster() then ShowNote(GossipFrame, "left") end
	elseif event == "GOSSIP_CLOSED" then
		if note.anchor == GossipFrame then note:Hide() end
	elseif event == "CONFIRM_TALENT_WIPE" then
		local cost, kind = ...
		if type(cost) ~= "number" or ns.IsSecret(cost) or ns.IsSecret(kind) then return end
		kind = tostring(kind or 0)
		local rec = records[kind] or {}
		records[kind] = rec
		rec.seen, rec.cost = Now(), cost
		asked = { kind = kind, cost = cost }
		-- The option that led here marks a trainer from now on, whatever it says
		if lastOption and GetTime() - lastOption.at < 5 and not ns.IsSecret(lastOption.id) then
			ns.db.respec.options[lastOption.id] = true
		end
		if not ns.db.respec.enabled then return end
		-- The game's dialog opens on this same event: once it's there, under it
		C_Timer.After(0, function()
			local dialog = StaticPopup_FindVisible and StaticPopup_FindVisible("CONFIRM_TALENT_WIPE")
			if dialog then ShowNote(dialog, "centre", kind) end
		end)
	elseif event == "PLAYER_MONEY" then
		local money = GetMoney()
		if pending and not ns.IsSecret(money) and money <= pending.money - pending.cost then Paid() end
	end
end)

ns.RespecState = function() return { note = note, records = records, pending = pending } end
