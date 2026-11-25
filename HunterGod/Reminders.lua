local _, ns = ...
local L = ns.L

-- The icon reminders above your character (aspect, Trueshot Aura, tracking) share one look and
-- one place: side by side, always centred on one point whether one, two or three show, and
-- dragged together. Some cast a spell on a click. The game doesn't let addons show, hide or move a
-- button that casts during a fight, so the icons are plain frames that come and go any time, and
-- the click is a secure button laid on top of them out of combat only
local SIZE, GAP = 40, 10
local DEFAULT_POINT = { "CENTER", "CENTER", 0, 260 } -- above Growl's reminder, clear of the character

local members = {} -- in order, left to right: { key, frame, spell, tooltip, x, click }
local fighting = false -- from the start of a fight: other modules' updates mustn't bring a button back
local group = CreateFrame("Frame", "HunterGodReminders", UIParent)
group:SetSize(SIZE, SIZE)
ns.REMINDER_SIZE = SIZE

-- They don't blink: still icons. What used to play their pulse finds it does nothing
local STILL = { Play = function() end, Stop = function() end, IsPlaying = function() return false end }

-- One pixel of the screen in a frame's own units. A line one UI unit wide is less than a pixel at
-- most UI scales, and the game drew it on some sides and not others (the bottom one went, in Forever)
local function OnePixel(frame)
	if not (PixelUtil and PixelUtil.GetPixelToUIUnitFactor) then return 1 end
	local scale = frame:GetEffectiveScale()
	if not scale or ns.IsSecret(scale) or scale <= 0 then return 1 end
	return PixelUtil.GetPixelToUIUnitFactor() / scale
end

local styled = {}

-- A black line one pixel wide around the outside, as FarmGod's window has: four strips, the top
-- and bottom ones a pixel longer each way to close the corners
local function Edges(frame)
	local px = OnePixel(frame)
	local top, bottom, left, right = unpack(frame.lines)
	top:ClearAllPoints()
	top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -px, 0)
	top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", px, 0)
	top:SetHeight(px)
	bottom:ClearAllPoints()
	bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -px, 0)
	bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", px, 0)
	bottom:SetHeight(px)
	left:ClearAllPoints()
	left:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
	left:SetWidth(px)
	right:ClearAllPoints()
	right:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(px)
end

-- The same size and the same thin black edge for every icon
function ns.StyleReminder(frame)
	frame:SetSize(SIZE, SIZE)
	frame.lines = {}
	for i = 1, 4 do
		frame.lines[i] = frame:CreateTexture(nil, "BORDER")
		frame.lines[i]:SetColorTexture(0, 0, 0, 1)
	end
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetAllPoints()
	frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	frame.pulse = STILL
	Edges(frame)
	styled[#styled + 1] = frame
end

local function Overlay_OnEnter(self)
	local m = self.member
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	if m.tooltip then m.tooltip(GameTooltip) end
	GameTooltip:AddLine(format(L.CLICK_CAST, self.spell or "?"), 0.4, 0.7, 1)
	GameTooltip:Show()
end

-- The secure buttons follow the icons, out of combat
local function Sync()
	if fighting or InCombatLockdown() then return end
	for _, m in ipairs(members) do
		local click = m.click
		if click then
			local spell = m.frame:IsShown() and not ns.unlocked and m.spell()
			if spell then
				if click.x ~= m.x then
					click:ClearAllPoints()
					click:SetPoint("CENTER", group, "CENTER", m.x, 0)
					click.x = m.x
				end
				if click:GetAttribute("spell1") ~= spell then click:SetAttribute("spell1", spell) end
				click.spell = spell
				click:Show()
			else
				click:Hide()
			end
		end
	end
end

-- Side by side, centred on the group's point
function ns.LayoutReminders()
	local shown = {}
	for _, m in ipairs(members) do
		if m.frame:IsShown() then shown[#shown + 1] = m end
	end
	local total = #shown * SIZE + max(#shown - 1, 0) * GAP
	local x = (SIZE - total) / 2
	for _, m in ipairs(shown) do
		if m.x ~= x then
			m.frame:ClearAllPoints()
			m.frame:SetPoint("CENTER", group, "CENTER", x, 0)
			m.x = x
		end
		x = x + SIZE + GAP
	end
	group:SetSize(max(total, SIZE), SIZE)
	Sync()
end

-- A reminder joins the row. spell: what a click casts while it shows (nil for none); tooltip: lines
-- above the click's. Without spell its frame takes its own clicks
function ns.AddReminder(key, frame, spell, tooltip)
	local m = { key = key, frame = frame, spell = spell, tooltip = tooltip }
	if spell then
		local click = CreateFrame("Button", "HunterGodReminderClick" .. key, UIParent, "SecureActionButtonTemplate")
		click:SetSize(SIZE, SIZE)
		click:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
		click:SetFrameLevel((frame:GetFrameLevel() or 1) + 5)
		click:RegisterForClicks("AnyUp", "AnyDown")
		-- Only the left button casts
		click:SetAttribute("type1", "spell")
		click:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		click:SetScript("OnEnter", Overlay_OnEnter)
		click:SetScript("OnLeave", GameTooltip_Hide)
		click:Hide()
		click.member = m
		m.click = click
	end
	members[#members + 1] = m
	frame:HookScript("OnShow", ns.LayoutReminders)
	frame:HookScript("OnHide", ns.LayoutReminders)
	return m
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
-- The screen's pixel changes with the UI scale and the window's size
pcall(events.RegisterEvent, events, "UI_SCALE_CHANGED")
pcall(events.RegisterEvent, events, "DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" or event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
		if event == "PLAYER_LOGIN" then ns.Movable(group, "reminders", DEFAULT_POINT, L.REMINDERS) end
		for _, frame in ipairs(styled) do Edges(frame) end
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- The last moment the game lets them go: no hidden button left to click in the fight
		fighting = true
		for _, m in ipairs(members) do
			if m.click then m.click:Hide() end
		end
		return
	elseif event == "PLAYER_REGEN_ENABLED" then
		fighting = false
	end
	ns.LayoutReminders()
end)

ns.RemindersState = function() return group, members end
