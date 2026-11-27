local addonName, ns = ...
local L = ns.L

-- A dark window with a menu down the side, in the hunter's class colour. Square pieces
-- only: Forever's client draws icons cut round with a mask as stripes
local WIDTH, HEIGHT = 660, 560
local SIDE = 170 -- the menu
local TOP = 60 -- the title bar
local PAGE_WIDTH = WIDTH - SIDE - 40
local ACCENT = { 0.67, 0.83, 0.45 }
local TEXT = { 0.93, 0.93, 0.9 }
local MUTED = { 0.6, 0.62, 0.58 }
local window, scroll, scrollBar
local tabs, pages = {}, {}

local function SpellName(id)
	return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or GetSpellInfo and GetSpellInfo(id)
end

local function SpellIcon(id, fallback)
	return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
		or GetSpellTexture and GetSpellTexture(id) or fallback
end

-- Drawing pieces

local function Rect(parent, layer, r, g, b, a, sublevel)
	local t = parent:CreateTexture(nil, layer, nil, sublevel)
	t:SetColorTexture(r, g, b, a or 1)
	return t
end

-- A white block, to tint with SetVertexColor
local function Block(parent, layer, width, height)
	local t = Rect(parent, layer, 1, 1, 1)
	t:SetSize(width, height)
	return t
end

local function Icon(parent, size, texture, coords)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetSize(size, size)
	t:SetTexture(texture)
	t:SetTexCoord(unpack(coords or { 0.08, 0.92, 0.08, 0.92 }))
	return t
end

-- The addon's round font, over the game's in case it can't load
local function Fancy(fs, size, flags)
	ns.UseFont(fs, ns.FONTS.fredoka, size, flags)
end

local function Text(parent, template, color)
	local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
	fs:SetTextColor(unpack(color or TEXT))
	fs:SetJustifyH("LEFT")
	return fs
end

-- A faint light behind a button while the mouse is on it
local function Highlight(button, alpha)
	local hl = button:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, alpha or 0.04)
end

-- An on/off switch for a CheckButton; returns the function that draws it
local function Switch(button, width, height)
	local track = Block(button, "ARTWORK", width, height)
	local knob = Block(button, "OVERLAY", height - 4, height - 4)
	local function Paint()
		local on = button:GetChecked()
		if on then track:SetVertexColor(unpack(ACCENT)) else track:SetVertexColor(0.24, 0.26, 0.23) end
		local shade = on and 1 or 0.7
		knob:SetVertexColor(shade, shade, shade)
		knob:ClearAllPoints()
		knob:SetPoint(on and "RIGHT" or "LEFT", track, on and "RIGHT" or "LEFT", on and -2 or 2, 0)
	end
	return track, Paint
end

local function Click()
	if SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
end

-- Controls: each one is a row of the page and knows how to read its setting back (Refresh)

-- A row with its text on the left, as tall as the text needs
local function Row(page, y, kind, text, textWidth, minHeight)
	local row = CreateFrame(kind, nil, page)
	local label = Text(row)
	label:SetPoint("LEFT", 10, 0)
	label:SetWidth(textWidth)
	label:SetText(text)
	local height = max(minHeight or 30, ceil(label:GetStringHeight() or 0) + 14)
	row:SetSize(PAGE_WIDTH, height)
	row:SetPoint("TOPLEFT", 0, y)
	row.label = label
	return row, y - height
end

local function Section(page, y, text)
	local title = page:CreateFontString(nil, "ARTWORK")
	Fancy(title, 14)
	title:SetTextColor(unpack(ACCENT))
	title:SetPoint("TOPLEFT", 10, y - 12)
	title:SetText(text)
	local line = Rect(page, "ARTWORK", ACCENT[1], ACCENT[2], ACCENT[3], 0.25)
	line:SetHeight(1)
	line:SetPoint("LEFT", title, "RIGHT", 10, 0)
	line:SetPoint("RIGHT", page, "RIGHT", -10, 0)
	return y - 36
end

local function Check(page, y, text, get, set, icon, coords)
	local row
	row, y = Row(page, y, "CheckButton", text, PAGE_WIDTH - (icon and 92 or 66))
	Highlight(row)
	if icon then
		local picture = Icon(row, 18, icon, coords)
		picture:SetPoint("LEFT", 10, 0)
		row.label:SetPoint("LEFT", 36, 0)
	end
	local switch, Paint = Switch(row, 34, 18)
	switch:SetPoint("RIGHT", -10, 0)
	row:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		Paint()
		Click()
	end)
	row.Refresh = function()
		row:SetChecked(get())
		Paint()
	end
	row.setting = text
	table.insert(page.controls, row)
	return y
end

local function Slider(page, y, text, low, high, step, get, set)
	local row
	row, y = Row(page, y, "Frame", text, PAGE_WIDTH - 236)
	local value = Text(row, "GameFontHighlight", ACCENT)
	value:SetPoint("RIGHT", -10, 0)
	value:SetWidth(40)
	value:SetJustifyH("RIGHT")
	local slider = CreateFrame("Slider", nil, row)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(150, 18)
	slider:SetPoint("RIGHT", -58, 0)
	slider:EnableMouse(true)
	local track = Rect(slider, "BACKGROUND", 0.24, 0.26, 0.23)
	track:SetSize(150, 4)
	track:SetPoint("CENTER")
	local thumb = Block(slider, "OVERLAY", 10, 16)
	slider:SetThumbTexture(thumb)
	local fill = Rect(slider, "ARTWORK", unpack(ACCENT))
	fill:SetHeight(4)
	fill:SetPoint("LEFT")
	fill:SetPoint("RIGHT", thumb, "CENTER")
	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(step)
	if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
	slider:SetScript("OnValueChanged", function(self, v)
		v = floor(v / step + 0.5) * step
		value:SetText(v)
		if not self.loading then set(v) end
	end)
	slider.Refresh = function()
		slider.loading = true
		slider:SetValue(get())
		value:SetText(get())
		slider.loading = false
	end
	slider.setting = text
	table.insert(page.controls, slider)
	return y
end

-- One of a few values, with arrows to go through them: { { value, text, font =, icon = }, ... }
local function Choice(page, y, text, choices, get, set)
	local row
	row, y = Row(page, y, "Frame", text, PAGE_WIDTH - 280, 34)
	local box = CreateFrame("Button", nil, row)
	box:SetSize(250, 26)
	box:SetPoint("RIGHT", -10, 0)
	Rect(box, "BACKGROUND", 1, 1, 1, 0.06):SetAllPoints()
	Highlight(box)
	local value = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	value:SetPoint("LEFT", 26, 0)
	value:SetPoint("RIGHT", -26, 0)
	value:SetWordWrap(false)
	box:SetFontString(value)
	local picture = Icon(box, 16)
	local function Pick(step)
		local at = 1
		for i, c in ipairs(choices) do
			if c[1] == get() then at = i end
		end
		set(choices[(at - 1 + step) % #choices + 1][1])
		box.Refresh()
		Click()
	end
	box:SetScript("OnClick", function() Pick(1) end)
	for _, side in ipairs({ { "LEFT", "<", -1 }, { "RIGHT", ">", 1 } }) do
		local arrow = CreateFrame("Button", nil, box)
		arrow:SetSize(26, 26)
		arrow:SetPoint(side[1])
		local glyph = arrow:CreateFontString(nil, "ARTWORK")
		Fancy(glyph, 15)
		glyph:SetPoint("CENTER")
		glyph:SetText(side[2])
		glyph:SetTextColor(unpack(MUTED))
		arrow:SetScript("OnEnter", function() glyph:SetTextColor(unpack(ACCENT)) end)
		arrow:SetScript("OnLeave", function() glyph:SetTextColor(unpack(MUTED)) end)
		arrow:SetScript("OnClick", function() Pick(side[3]) end)
	end
	box.Refresh = function()
		for _, c in ipairs(choices) do
			if c[1] == get() then
				-- A font choice is written in that font
				ns.UseFont(value, c.font, c.font and 14 or 13)
				box:SetText(c[2])
				picture:SetShown(c.icon ~= nil)
				if c.icon then
					picture:SetTexture(c.icon)
					picture:ClearAllPoints()
					picture:SetPoint("RIGHT", value, "CENTER", -floor((value:GetStringWidth() or 0) / 2) - 5, 0)
				end
			end
		end
	end
	box.setting = text
	table.insert(page.controls, box)
	return y
end

local function PickColor(color, changed)
	local old = { r = color.r, g = color.g, b = color.b }
	local function apply()
		color.r, color.g, color.b = ColorPickerFrame:GetColorRGB()
		changed()
	end
	local function cancel()
		color.r, color.g, color.b = old.r, old.g, old.b
		changed()
	end
	if ColorPickerFrame.SetupColorPickerAndShow then
		ColorPickerFrame:SetupColorPickerAndShow({ r = color.r, g = color.g, b = color.b, swatchFunc = apply, cancelFunc = cancel })
	else
		ColorPickerFrame.hasOpacity = false
		ColorPickerFrame.func, ColorPickerFrame.cancelFunc = apply, cancel
		ColorPickerFrame:SetColorRGB(color.r, color.g, color.b)
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
	end
end

-- A row with a square of colour on the right: click it to pick another
local function Swatch(page, y, text, color, changed)
	local row
	row, y = Row(page, y, "Button", text, PAGE_WIDTH - 66)
	Highlight(row)
	local edge = Rect(row, "ARTWORK", 0, 0, 0, 1)
	edge:SetSize(36, 20)
	edge:SetPoint("RIGHT", -10, 0)
	local square = Rect(row, "OVERLAY", color.r, color.g, color.b, 1)
	square:SetSize(34, 18)
	square:SetPoint("CENTER", edge)
	row.Refresh = function() square:SetColorTexture(color.r, color.g, color.b, 1) end
	row:SetScript("OnClick", function()
		Click()
		PickColor(color, function()
			changed()
			row.Refresh()
		end)
	end)
	row.setting = text
	table.insert(page.controls, row)
	return y
end

-- A row that does something when you click it, its word on the right
local function Action(page, y, text, word, run)
	local row
	row, y = Row(page, y, "Button", text, PAGE_WIDTH - 130)
	Highlight(row)
	local label = Text(row, "GameFontHighlight", ACCENT)
	label:SetPoint("RIGHT", -10, 0)
	label:SetJustifyH("RIGHT")
	label:SetText(word)
	row:SetScript("OnClick", function()
		Click()
		run()
	end)
	row.Refresh = function() end
	row.setting = text
	table.insert(page.controls, row)
	return y
end

-- The range display as it will look, one sample per state: click one to change its colour.
-- In melee (Survival) the row has its own states: no max range, and getting closer instead of in range
local SAMPLES = { melee = { 0, 5, 3 }, hit = { 0, 5, 3 }, dead = { 5, 8, 7 }, ranged = { 25, 30, 28 },
	approach = { 25, 30, 28 }, far = { 30, 35, 33 }, out = { 41, nil, 43 } }
local SAMPLE_ORDER = { "melee", "hit", "dead", "ranged", "approach", "far", "out" }
local SAMPLE_ROWS = { ranged = { "melee", "dead", "ranged", "far", "out" }, melee = { "hit", "dead", "approach", "out" } }

local function Preview(page, y, changed)
	local range = ns.db.range
	local card = CreateFrame("Frame", nil, page)
	card:SetSize(PAGE_WIDTH - 20, 96)
	card:SetPoint("TOPLEFT", 10, y - 4)
	Rect(card, "BACKGROUND", 0, 0, 0, 0.35):SetAllPoints()
	local hint = Text(card, "GameFontHighlightSmall", MUTED)
	hint:SetPoint("BOTTOM", 0, 6)
	hint:SetText(L.PREVIEW_HINT)
	for _, state in ipairs(SAMPLE_ORDER) do
		local s = SAMPLES[state]
		local sample = CreateFrame("Button", nil, card)
		Highlight(sample, 0.06)
		local glow = sample:CreateTexture(nil, "BACKGROUND")
		local glowReady = glow:SetTexture(ns.GLOW) ~= false
		glow:SetBlendMode("ADD")
		glow:SetPoint("CENTER", sample, "CENTER", 0, 8)
		local square = sample:CreateTexture(nil, "ARTWORK")
		local number = sample:CreateFontString(nil, "ARTWORK")
		local unit = sample:CreateFontString(nil, "ARTWORK")
		local caption = Text(sample, "GameFontHighlightSmall", MUTED)
		caption:SetPoint("BOTTOM", 0, 4)
		caption:SetText(L.RANGE[state])
		sample.number, sample.unit, sample.glow = number, unit, glow
		sample.Refresh = function()
			local row, place = SAMPLE_ROWS[ns.IsMelee() and "melee" or "ranged"], nil
			for i, key in ipairs(row) do
				if key == state then place = i end
			end
			sample:SetShown(place ~= nil)
			if not place then return end
			local cell = (PAGE_WIDTH - 20) / #row
			sample:SetSize(cell - 8, 70)
			sample:ClearAllPoints()
			sample:SetPoint("TOPLEFT", (place - 1) * cell + 4, -4)
			local c = range.colors[state]
			local size = min(range.textSize, 22)
			local font = ns.FONTS[range.font]
			ns.UseFont(number, font, size, "THICKOUTLINE")
			ns.UseFont(unit, font, max(floor(size * 0.5), 8), "OUTLINE")
			-- Like the real one: the dead zone's name instead of its number, and yd or m only if you want
			local words = range.deadLabel and (state == "melee" or state == "hit" or state == "dead")
			ns.UseFont(number, font, words and max(floor(size * 0.7), 10) or size, "THICKOUTLINE")
			number:SetText(words and L.RANGE[state] or ns.RangeNumber(s[1], s[2], s[3]))
			local unitShown = range.unitLabel and not words
			unit:SetText(unitShown and (range.units == "meters" and L.METERS or L.YARDS) or "")
			number:SetTextColor(c.r, c.g, c.b)
			unit:SetTextColor(c.r, c.g, c.b)
			square:SetColorTexture(c.r, c.g, c.b)
			-- Text, a colour square or both, centred together
			local showText, showSquare = range.style ~= "icon", range.style ~= "text"
			number:SetShown(showText)
			unit:SetShown(showText)
			square:SetShown(showSquare)
			local side = floor(size * 0.7)
			local width = (showSquare and side or 0) + (showSquare and showText and 6 or 0)
				+ (showText and (number:GetStringWidth() or 0) + (unitShown and 3 + (unit:GetStringWidth() or 0) or 0) or 0)
			local x = -width / 2
			square:SetSize(side, side)
			square:ClearAllPoints()
			square:SetPoint("LEFT", sample, "CENTER", x, 8)
			if showSquare then x = x + side + 6 end
			number:ClearAllPoints()
			number:SetPoint("LEFT", sample, "CENTER", x, 8)
			unit:ClearAllPoints()
			unit:SetPoint("BOTTOMLEFT", number, "BOTTOMRIGHT", 3, 2)
			glow:SetShown(state == "far" and range.farGlow and glowReady)
			glow:SetVertexColor(c.r, c.g, c.b, 0.7)
			glow:SetSize(width + size * 2, size * 2.4)
		end
		sample:SetScript("OnClick", function() PickColor(range.colors[state], changed) end)
		sample.setting = L.RANGE[state]
		table.insert(page.controls, sample)
	end
	return y - 108
end

-- Pages and the menu

local function UpdateScrollBar()
	local range, height = scroll:GetVerticalScrollRange() or 0, scroll:GetHeight() or 0
	if range < 1 or height < 1 then
		scrollBar:Hide()
		return
	end
	local thumb = max(height * height / (height + range), 30)
	scrollBar.thumb:SetHeight(thumb)
	scrollBar.thumb:ClearAllPoints()
	scrollBar.thumb:SetPoint("TOP", 0, -(scroll:GetVerticalScroll() or 0) / range * (height - thumb))
	scrollBar:Show()
end

local function NewPage(key, title, icon, coords)
	local page = CreateFrame("Frame", nil, scroll)
	page:SetSize(PAGE_WIDTH, 10)
	page:Hide()
	page.controls = {}
	page.key = key
	pages[#pages + 1] = page
	local tab = CreateFrame("Button", nil, window)
	tab:SetSize(SIDE, 38)
	tab:SetPoint("TOPLEFT", 0, -TOP - 12 - (#pages - 1) * 40)
	Highlight(tab)
	tab.selected = Rect(tab, "BACKGROUND", ACCENT[1], ACCENT[2], ACCENT[3], 0.12)
	tab.selected:SetAllPoints()
	tab.bar = Rect(tab, "ARTWORK", unpack(ACCENT))
	tab.bar:SetPoint("TOPLEFT")
	tab.bar:SetPoint("BOTTOMLEFT")
	tab.bar:SetWidth(3)
	tab.icon = Icon(tab, 22, icon, coords)
	tab.icon:SetPoint("LEFT", 18, 0)
	tab.label = tab:CreateFontString(nil, "ARTWORK")
	Fancy(tab.label, 15)
	tab.label:SetPoint("LEFT", tab.icon, "RIGHT", 10, 0)
	tab.label:SetText(title)
	tab:SetScript("OnClick", function()
		ns.ShowOptionsPage(key)
		Click()
	end)
	tab.key = key
	tabs[#tabs + 1] = tab
	return page, -4
end

-- The page is as tall as what's on it, so the window scrolls when it doesn't fit
local function Done(page, y)
	page:SetHeight(-y + 12)
end

function ns.ShowOptionsPage(key)
	for i, page in ipairs(pages) do
		local on = page.key == key
		local tab = tabs[i]
		page:SetShown(on)
		tab.selected:SetShown(on)
		tab.bar:SetShown(on)
		tab.label:SetTextColor(unpack(on and TEXT or MUTED))
		if on then
			scroll:SetScrollChild(page)
			scroll:SetVerticalScroll(0)
			for _, control in ipairs(page.controls) do control.Refresh() end
		end
	end
	window.page = key
	UpdateScrollBar()
end

local function RefreshPage(key)
	for _, page in ipairs(pages) do
		if page.key == key and page:IsShown() then
			for _, control in ipairs(page.controls) do control.Refresh() end
		end
	end
end
ns.RefreshOptionsPage = RefreshPage

local function BuildWindow()
	window = CreateFrame("Frame", "HunterGodOptions", UIParent)
	window:SetSize(WIDTH, HEIGHT)
	window:SetPoint("CENTER")
	window:SetFrameStrata("HIGH")
	window:SetToplevel(true)
	window:EnableMouse(true)
	window:SetMovable(true)
	window:SetClampedToScreen(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", window.StopMovingOrSizing)
	table.insert(UISpecialFrames, "HunterGodOptions") -- Escape closes it

	local edge = Rect(window, "BACKGROUND", 0, 0, 0, 0.9, -8)
	edge:SetPoint("TOPLEFT", -1, 1)
	edge:SetPoint("BOTTOMRIGHT", 1, -1)
	Rect(window, "BACKGROUND", 0.07, 0.075, 0.068, 0.97, -7):SetAllPoints()
	local side = Rect(window, "BACKGROUND", 0.045, 0.05, 0.043, 0.98, -6)
	side:SetPoint("TOPLEFT")
	side:SetPoint("BOTTOMLEFT")
	side:SetWidth(SIDE)
	local head = Rect(window, "BACKGROUND", 0.045, 0.05, 0.043, 0.98, -6)
	head:SetPoint("TOPLEFT")
	head:SetPoint("TOPRIGHT")
	head:SetHeight(TOP)
	local headLine = Rect(window, "ARTWORK", ACCENT[1], ACCENT[2], ACCENT[3], 0.5)
	headLine:SetPoint("TOPLEFT", 0, -TOP)
	headLine:SetPoint("TOPRIGHT", 0, -TOP)
	headLine:SetHeight(1)
	local sideLine = Rect(window, "ARTWORK", 1, 1, 1, 0.06)
	sideLine:SetPoint("TOPLEFT", SIDE, -TOP - 1)
	sideLine:SetPoint("BOTTOMLEFT", SIDE, 0)
	sideLine:SetWidth(1)

	local logo = window:CreateTexture(nil, "ARTWORK")
	logo:SetSize(38, 38)
	logo:SetPoint("TOPLEFT", 16, -11)
	logo:SetTexture("Interface\\AddOns\\HunterGod\\media\\icon")
	local title = window:CreateFontString(nil, "ARTWORK")
	Fancy(title, 22)
	title:SetTextColor(unpack(TEXT))
	title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -1)
	title:SetText("HunterGod")
	local GetMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
	local version = GetMetadata and GetMetadata(addonName, "Version")
	local subtitle = Text(window, "GameFontHighlightSmall", MUTED)
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -2)
	subtitle:SetText(version and L.SUBTITLE .. "  ·  v" .. version or L.SUBTITLE)

	local close = CreateFrame("Button", nil, window)
	close:SetSize(32, 32)
	close:SetPoint("TOPRIGHT", -12, -14)
	Highlight(close, 0.08)
	local cross = close:CreateFontString(nil, "ARTWORK")
	cross:SetFont(GameFontNormal:GetFont(), 22, "")
	cross:SetPoint("CENTER", 0, 1)
	cross:SetText("×")
	cross:SetTextColor(unpack(MUTED))
	close:SetScript("OnEnter", function() cross:SetTextColor(1, 0.4, 0.35) end)
	close:SetScript("OnLeave", function() cross:SetTextColor(unpack(MUTED)) end)
	close:SetScript("OnClick", function() window:Hide() end)

	scroll = CreateFrame("ScrollFrame", nil, window)
	scroll:SetPoint("TOPLEFT", SIDE + 16, -TOP - 8)
	scroll:SetPoint("BOTTOMRIGHT", -24, 10)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange() or 0
		self:SetVerticalScroll(min(max((self:GetVerticalScroll() or 0) - delta * 40, 0), range))
		UpdateScrollBar()
	end)
	scroll:SetScript("OnScrollRangeChanged", UpdateScrollBar)
	scrollBar = CreateFrame("Frame", nil, window)
	scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 10, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 10, 0)
	scrollBar:SetWidth(4)
	Rect(scrollBar, "BACKGROUND", 1, 1, 1, 0.06):SetAllPoints()
	scrollBar.thumb = Rect(scrollBar, "ARTWORK", ACCENT[1], ACCENT[2], ACCENT[3], 0.6)
	scrollBar.thumb:SetWidth(4)
	scrollBar:Hide()
end

local function Build()
	local db = ns.db
	BuildWindow()

	-- World map
	local icons = ns.icons
	local page, y = NewPage("map", L.TAB_MAP, "Interface\\Icons\\INV_Misc_Map_01")
	local function MapCheck(text, key, icon, coords)
		y = Check(page, y, text, function() return db[key] end, function(v) db[key] = v ns.RefreshMap() end, icon, coords)
	end
	y = Section(page, y, L.SEC_PINS)
	MapCheck(L.ARROWS_BOX, "arrows", icons.arrows)
	MapCheck(L.BULLETS_BOX, "bullets", icons.bullets)
	MapCheck(L.TRAINERS_BOX, "trainers", ns.HUNTER_ICON, ns.HUNTER_COORDS)
	MapCheck(L.STABLES_BOX, "stableMasters", icons.stableMasters)
	MapCheck(L.OPT_FOOD_VENDORS, "foodVendors", icons.foodVendors)
	y = Section(page, y, L.SEC_WHICH)
	MapCheck(L.OPT_OTHER_FACTION, "allFactions")
	MapCheck(L.OPT_ONLY_HUNTER, "onlyHunter")
	MapCheck(L.OPT_MINIMAP_PINS, "minimap")
	MapCheck(L.OPT_CONTINENT, "continent")
	y = Section(page, y, L.SEC_RESPEC)
	y = Check(page, y, L.OPT_RESPEC, function() return db.respec.enabled end, function(v) db.respec.enabled = v end,
		"Interface\\Icons\\INV_Misc_Coin_01")
	local respecHint = Text(page, "GameFontHighlightSmall", MUTED)
	respecHint:SetPoint("TOPLEFT", 10, y - 6)
	respecHint:SetWidth(PAGE_WIDTH - 20)
	respecHint:SetText(L.RESPEC_HINT)
	Done(page, y - 56)

	-- Range
	local range = db.range
	local function RangeChanged()
		ns.StyleRange()
		ns.UpdateRange()
		RefreshPage("range") -- the preview follows
	end
	page, y = NewPage("range", L.TAB_RANGE, SpellIcon(75, "Interface\\Icons\\INV_Weapon_Bow_02"))
	y = Preview(page, y, RangeChanged)
	y = Section(page, y, L.SEC_DISTANCE)
	y = Check(page, y, L.OPT_RANGE_ON, function() return range.enabled end, function(v) range.enabled = v RangeChanged() end)
	-- Where it goes, right under the switch: "your target" in the switch isn't where it shows
	y = Choice(page, y, L.OPT_POSITION, { { "plate", L.POSITION.plate }, { "free", L.POSITION.free } },
		function() return range.anchor end, function(v) range.anchor = v RangeChanged() end)
	y = Choice(page, y, L.OPT_PLATE_SIDE, {
		{ "top", L.PLATE_SIDE.top }, { "bottom", L.PLATE_SIDE.bottom },
		{ "left", L.PLATE_SIDE.left }, { "right", L.PLATE_SIDE.right },
	}, function() return range.plateSide end, function(v) range.plateSide = v RangeChanged() end)
	y = Slider(page, y, L.OPT_PLATE_GAP, -20, 60, 1, function() return range.plateGap end,
		function(v) range.plateGap = v RangeChanged() end)
	y = Check(page, y, L.OPT_ONLY_COMBAT, function() return range.onlyCombat end, function(v) range.onlyCombat = v RangeChanged() end)
	y = Check(page, y, format(L.OPT_DEAD_LABEL, L.RANGE.melee, L.RANGE.dead), function() return range.deadLabel end,
		function(v) range.deadLabel = v RangeChanged() end)
	y = Check(page, y, L.OPT_UNIT_LABEL, function() return range.unitLabel end, function(v) range.unitLabel = v RangeChanged() end)
	y = Check(page, y, L.OPT_FAR, function() return range.farGlow end, function(v) range.farGlow = v RangeChanged() end)
	y = Section(page, y, L.SEC_LOOK)
	y = Choice(page, y, L.OPT_DISPLAY, { { "number", L.DISPLAY.number }, { "bracket", L.DISPLAY.bracket } },
		function() return range.display end, function(v) range.display = v RangeChanged() end)
	y = Choice(page, y, L.OPT_UNITS, { { "yards", L.UNITS.yards }, { "meters", L.UNITS.meters } },
		function() return range.units end, function(v) range.units = v RangeChanged() end)
	y = Choice(page, y, L.OPT_FONT, {
		{ "fredoka", L.FONTS.fredoka, font = ns.FONTS.fredoka },
		{ "changa", L.FONTS.changa, font = ns.FONTS.changa },
		{ "game", L.FONTS.game },
	}, function() return range.font end, function(v) range.font = v RangeChanged() end)
	y = Choice(page, y, L.OPT_STYLE, { { "text", L.STYLE.text }, { "icon", L.STYLE.icon }, { "both", L.STYLE.both } },
		function() return range.style end, function(v) range.style = v RangeChanged() end)
	y = Slider(page, y, L.OPT_SIZE, 12, 48, 1, function() return range.textSize end, function(v) range.textSize = v RangeChanged() end)
	Done(page, y)

	-- Combat: aspects, traps, melee range and aggro
	local aspect = db.aspect
	page, y = NewPage("aspects", L.TAB_COMBAT, SpellIcon(ns.ASPECTS.hawk, "Interface\\Icons\\Spell_Nature_RavenForm"))
	y = Section(page, y, L.SEC_PLAYSTYLE)
	y = Choice(page, y, L.OPT_PLAYSTYLE, {
		{ "auto", L.PLAYSTYLE.auto }, { "ranged", L.PLAYSTYLE.ranged }, { "melee", L.PLAYSTYLE.melee },
	}, function() return db.playstyle end, function(v) db.playstyle = v ns.RefreshAll() end)
	y = Section(page, y, L.TAB_ASPECTS)
	y = Check(page, y, L.OPT_ASPECT_ON, function() return aspect.enabled end, function(v) aspect.enabled = v ns.UpdateAspect() end)
	y = Check(page, y, L.OPT_TRAVEL, function() return aspect.travel end, function(v) aspect.travel = v ns.UpdateAspect() end)
	y = Check(page, y, L.OPT_MISSING, function() return aspect.missing end, function(v) aspect.missing = v ns.UpdateAspect() end)
	y = Check(page, y, L.OPT_MISSING_ALWAYS, function() return aspect.missingAlways end,
		function(v) aspect.missingAlways = v ns.UpdateAspect() end)
	local aspects = {}
	for _, key in ipairs({ "hawk", "monkey", "wild" }) do
		aspects[#aspects + 1] = { key, ns.AspectName(key), icon = SpellIcon(ns.ASPECTS[key]) }
	end
	aspects[#aspects + 1] = { "any", L.ANY_ASPECT }
	y = Choice(page, y, L.OPT_PREFERRED, aspects, function() return aspect.preferred end,
		function(v) aspect.preferred = v ns.UpdateAspect() end)
	local meleeAspects = {}
	for _, key in ipairs({ "beast", "monkey", "hawk", "wild" }) do
		meleeAspects[#meleeAspects + 1] = { key, ns.AspectName(key), icon = SpellIcon(ns.ASPECTS[key]) }
	end
	meleeAspects[#meleeAspects + 1] = { "any", L.ANY_ASPECT }
	y = Choice(page, y, L.OPT_PREFERRED_MELEE, meleeAspects, function() return aspect.melee end,
		function(v) aspect.melee = v ns.UpdateAspect() end)
	y = Check(page, y, L.OPT_ASPECT_TEXT, function() return aspect.text end, function(v) aspect.text = v ns.UpdateAspect() end)
	y = Check(page, y, format(L.OPT_TRUESHOT, SpellName(19506) or L.TRUESHOT), function() return aspect.trueshot end,
		function(v) aspect.trueshot = v ns.UpdateTrueshot() end, SpellIcon(19506))
	local trapOptions = db.traps
	y = Section(page, y, L.SEC_TRAPS)
	y = Check(page, y, L.OPT_TRAPS, function() return trapOptions.enabled end, function(v) trapOptions.enabled = v ns.UpdateTraps() end)
	y = Check(page, y, format(L.OPT_FREEZE, SpellName(1499) or "Freezing Trap"), function() return trapOptions.freeze end,
		function(v) trapOptions.freeze = v ns.UpdateFreeze() end)
	y = Section(page, y, L.SEC_TRACKING)
	y = Check(page, y, L.OPT_TRACKING, function() return db.tracking.enabled end,
		function(v) db.tracking.enabled = v ns.UpdateTracking() end, SpellIcon(19883, "Interface\\Icons\\Spell_Holy_PrayerOfHealing"))
	y = Check(page, y, format(L.OPT_TRACKING_TALENT, SpellName(24293) or "Improved Tracking"), function() return db.tracking.onlyTalent end,
		function(v) db.tracking.onlyTalent = v ns.UpdateTracking() end, SpellIcon(24293))
	y = Check(page, y, L.OPT_TRACKING_WORLD, function() return db.tracking.anywhere end,
		function(v) db.tracking.anywhere = v ns.UpdateTracking() ns.UpdateGather() end)
	y = Check(page, y, format(L.OPT_GATHER, SpellName(2383) or "Find Herbs", SpellName(2580) or "Find Minerals"),
		function() return db.gather.enabled end, function(v) db.gather.enabled = v ns.UpdateGather() end,
		SpellIcon(2580, "Interface\\Icons\\Spell_Nature_Earthquake"))
	y = Action(page, y, L.OPT_TRACKING_TEST, L.TRY, ns.TestTracking)
	local trackingHint = Text(page, "GameFontHighlightSmall", MUTED)
	trackingHint:SetPoint("TOPLEFT", 10, y - 6)
	trackingHint:SetWidth(PAGE_WIDTH - 20)
	trackingHint:SetText(L.TRACKING_HINT)
	y = y - 44
	y = Section(page, y, L.SEC_MELEE)
	y = Check(page, y, L.OPT_MELEE_WARNING, function() return range.meleeWarning end, function(v) range.meleeWarning = v RangeChanged() end)
	y = Slider(page, y, L.OPT_MELEE_ALPHA, 10, 100, 5, function() return range.meleeAlpha end, function(v) range.meleeAlpha = v RangeChanged() end)
	y = Section(page, y, L.SEC_THREAT)
	y = Check(page, y, L.OPT_THREAT, function() return range.threat end, function(v) range.threat = v ns.UpdateThreat() end)
	y = Slider(page, y, L.OPT_THREAT_PCT, 50, 100, 5, function() return range.threatPct end, function(v) range.threatPct = v ns.UpdateThreat() end)
	Done(page, y)

	-- Procs: wind with Quick Shots and Quick Strikes, a target at your feet with Rapid Killing. Each
	-- change shows the sample a moment
	local procs = db.procs
	local function ProcsChanged(key)
		ns.StyleProcs()
		ns.PeekProcs(key)
	end
	page, y = NewPage("procs", L.TAB_PROCS, SpellIcon(6150, "Interface\\Icons\\Ability_Warrior_InnerRage"))
	for _, key in ipairs({ "speed", "kill" }) do
		local proc, name = procs[key], ns.ProcName(key)
		y = Section(page, y, name)
		y = Check(page, y, format(key == "speed" and L.OPT_PROC_SPEED or L.OPT_PROC_KILL, name),
			function() return proc.enabled end,
			function(v)
				proc.enabled = v
				ns.StyleProcs()
				if v then ns.PeekProcs(key) end
			end, SpellIcon(ns.PROC_SPELLS[key][1]))
		y = Swatch(page, y, L.OPT_PROC_COLOR, proc.color, function() ProcsChanged(key) end)
		y = Action(page, y, L.OPT_PROC_TEST, L.TRY, function() ns.TestProcs(key) end)
	end
	y = Section(page, y, L.SEC_LOOK)
	y = Slider(page, y, L.OPT_PROCS_SIZE, 20, 200, 5, function() return procs.size end,
		function(v) ns.SetProcsSize(v) ns.PeekProcs() end)
	y = Slider(page, y, L.OPT_PROCS_X, -600, 600, 5, function() return (ns.ProcsOffset()) end,
		function(v) ns.MoveProcs(v, select(2, ns.ProcsOffset())) ns.PeekProcs() end)
	y = Slider(page, y, L.OPT_PROCS_Y, -400, 400, 5, function() return select(2, ns.ProcsOffset()) end,
		function(v) ns.MoveProcs((ns.ProcsOffset()), v) ns.PeekProcs() end)
	y = Slider(page, y, L.OPT_PROCS_GAP, 60, 400, 5, function() return procs.gap end,
		function(v) procs.gap = v ProcsChanged("speed") end)
	y = Slider(page, y, L.OPT_PROCS_ALPHA, 10, 100, 5, function() return procs.alpha end,
		function(v) procs.alpha = v ProcsChanged() end)
	y = Slider(page, y, L.OPT_PROCS_CALM, 0, 100, 5, function() return procs.calm end,
		function(v) procs.calm = v ProcsChanged() end)
	y = Check(page, y, L.OPT_PROCS_TIMER, function() return procs.timer end,
		function(v) procs.timer = v ProcsChanged() end)
	y = Slider(page, y, L.OPT_PROCS_TIMER_SIZE, 12, 40, 1, function() return procs.timerSize end,
		function(v) procs.timerSize = v ProcsChanged() end)
	local procsHint = Text(page, "GameFontHighlightSmall", MUTED)
	procsHint:SetPoint("TOPLEFT", 10, y - 6)
	procsHint:SetWidth(PAGE_WIDTH - 20)
	procsHint:SetText(L.PROCS_HINT)
	Done(page, y - 16 - ceil(procsHint:GetStringHeight() or 60))

	-- Swing timers
	local swing = db.swing
	local function SwingChanged()
		ns.StyleSwing()
		ns.TestSwing()
	end
	page, y = NewPage("swing", L.TAB_SWING, "Interface\\Icons\\INV_Misc_PocketWatch_01")
	y = Section(page, y, L.SEC_SWING)
	y = Check(page, y, L.OPT_SWING_ON, function() return swing.enabled end,
		function(v) swing.enabled = v ns.SwingBlizzard() ns.UpdateSwing() end)
	y = Check(page, y, L.OPT_SWING_RANGED, function() return swing.ranged end, function(v) swing.ranged = v SwingChanged() end,
		SpellIcon(75, "Interface\\Icons\\INV_Weapon_Bow_02"))
	y = Check(page, y, L.OPT_SWING_MAIN, function() return swing.main end, function(v) swing.main = v SwingChanged() end,
		"Interface\\Icons\\INV_Sword_04")
	y = Check(page, y, L.OPT_SWING_OFF, function() return swing.off end, function(v) swing.off = v SwingChanged() end,
		"Interface\\Icons\\INV_Weapon_ShortBlade_05")
	y = Check(page, y, L.OPT_SWING_BY_RANGE, function() return swing.byRange end,
		function(v) swing.byRange = v ns.UpdateSwing() end)
	y = Check(page, y, L.OPT_SWING_BLIZZARD, function() return swing.hideBlizzard end,
		function(v) swing.hideBlizzard = v ns.SwingBlizzard() end)
	y = Section(page, y, L.SEC_LOOK)
	y = Slider(page, y, L.OPT_SWING_WIDTH, 80, 400, 5, function() return swing.width end, function(v) swing.width = v SwingChanged() end)
	y = Slider(page, y, L.OPT_SWING_HEIGHT, 6, 30, 1, function() return swing.height end, function(v) swing.height = v SwingChanged() end)
	y = Check(page, y, L.OPT_SWING_TIME, function() return swing.time end, function(v) swing.time = v SwingChanged() end)
	y = Check(page, y, L.OPT_SWING_ICON, function() return swing.icon end, function(v) swing.icon = v SwingChanged() end)
	y = Check(page, y, L.OPT_SWING_WINDUP, function() return swing.windup end, function(v) swing.windup = v SwingChanged() end)
	y = Swatch(page, y, format(L.OPT_SWING_COLOR, L.OPT_SWING_RANGED), swing.colors.ranged, SwingChanged)
	y = Swatch(page, y, format(L.OPT_SWING_COLOR, L.OPT_SWING_MAIN), swing.colors.main, SwingChanged)
	y = Swatch(page, y, format(L.OPT_SWING_COLOR, L.OPT_SWING_OFF), swing.colors.off, SwingChanged)
	y = Action(page, y, L.OPT_SWING_TEST, L.TRY, ns.TestSwing)
	local swingHint = Text(page, "GameFontHighlightSmall", MUTED)
	swingHint:SetPoint("TOPLEFT", 10, y - 6)
	swingHint:SetWidth(PAGE_WIDTH - 20)
	swingHint:SetText(L.SWING_HINT)
	Done(page, y - 70)

	-- Ammo
	local ammo = db.lowAmmo
	page, y = NewPage("ammo", L.TAB_AMMO, icons.arrows)
	y = Section(page, y, L.SEC_AMMO)
	y = Check(page, y, L.OPT_AMMO_ON, function() return ammo.enabled end, function(v) ammo.enabled = v ns.UpdateAmmo() end)
	y = Slider(page, y, L.OPT_THRESHOLD, 100, 4000, 100, function() return ammo.threshold end, function(v) ammo.threshold = v ns.UpdateAmmo() end)
	y = Check(page, y, L.OPT_MERCHANT, function() return ammo.merchant end, function(v) ammo.merchant = v end)
	y = Check(page, y, ns.REPAIR_TEXT.OPT_AUTO, function() return db.repair.auto end, function(v) db.repair.auto = v end,
		"Interface\\Icons\\INV_Misc_Coin_02")
	y = Check(page, y, ns.GROUP_NEEDS_TEXT.OPT, function() return db.groupNeeds.enabled end,
		function(v) db.groupNeeds.enabled = v ns.UpdateGroupNeeds() end)
	y = Check(page, y, ns.GROUP_NEEDS_TEXT.OPT_ANYWHERE, function() return db.groupNeeds.anywhere end,
		function(v) db.groupNeeds.anywhere = v ns.UpdateGroupNeeds() end)
	Done(page, y)

	-- Pet
	local pet = db.petFood
	local BEAST = "Interface\\Icons\\Ability_Hunter_BeastTaming"
	page, y = NewPage("pet", L.TAB_PET, BEAST)
	local petTab = tabs[#tabs]
	y = Section(page, y, L.SEC_FOOD)
	y = Check(page, y, L.OPT_PET_ON, function() return pet.enabled end, function(v) pet.enabled = v ns.UpdatePetFood() end)
	y = Check(page, y, L.OPT_PET_BAR, function() return pet.bar end, function(v) pet.bar = v ns.UpdatePetFood() end)
	y = Check(page, y, L.OPT_HIDE_COMBAT, function() return pet.hideInCombat end, function(v) pet.hideInCombat = v end)
	y = Slider(page, y, L.OPT_PET_LOW, 0, 40, 1, function() return pet.low end, function(v) pet.low = v ns.UpdatePetFood() end)
	y = Check(page, y, L.OPT_MERCHANT, function() return pet.merchant end, function(v) pet.merchant = v end)
	local growl = db.growl
	y = Section(page, y, SpellName(2649) or "Growl")
	y = Check(page, y, L.OPT_GROWL, function() return growl.enabled end, function(v) growl.enabled = v ns.UpdateGrowl() end)
	y = Check(page, y, L.OPT_GROWL_GROUPS, function() return growl.groups end, function(v) growl.groups = v ns.UpdateGrowl() end)
	y = Check(page, y, L.OPT_GROWL_MISS, function() return growl.miss end, function(v) growl.miss = v end)
	local status = db.petStatus
	y = Section(page, y, L.SEC_PET_STATUS)
	y = Check(page, y, L.OPT_NOT_HAPPY, function() return status.happy end, function(v) status.happy = v ns.UpdatePetStatus() end)
	y = Check(page, y, L.OPT_PET_HEALTH, function() return status.health end, function(v) status.health = v ns.UpdatePetStatus() end)
	y = Slider(page, y, L.OPT_PET_HEALTH_PCT, 10, 90, 5, function() return status.healthPct end, function(v) status.healthPct = v ns.UpdatePetStatus() end)
	y = Check(page, y, format(L.OPT_WRATH, SpellName(19574) or "Bestial Wrath"), function() return status.wrath end,
		function(v) status.wrath = v ns.UpdateWrath() end)
	local petToast = db.petToast
	y = Section(page, y, L.SEC_PET_TOAST)
	y = Check(page, y, L.OPT_PET_LEVEL, function() return petToast.level end, function(v) petToast.level = v end)
	y = Check(page, y, L.OPT_PET_TP, function() return petToast.training end, function(v) petToast.training = v end)
	y = Check(page, y, L.OPT_PET_SOUND, function() return petToast.sound end, function(v) petToast.sound = v end)
	Done(page, y)

	-- At the foot of the menu: moving the displays and the minimap button
	local unlock = CreateFrame("Button", nil, window)
	unlock:SetSize(SIDE - 28, 30)
	unlock:SetPoint("BOTTOMLEFT", 14, 46)
	Rect(unlock, "BACKGROUND", ACCENT[1], ACCENT[2], ACCENT[3], 0.14):SetAllPoints()
	Highlight(unlock, 0.08)
	local unlockText = unlock:CreateFontString(nil, "ARTWORK")
	Fancy(unlockText, 13)
	unlockText:SetTextColor(unpack(ACCENT))
	unlock:SetFontString(unlockText)
	unlock:SetScript("OnClick", function()
		ns.SetUnlocked(not ns.unlocked)
		unlock:SetText(ns.unlocked and L.LOCK or L.UNLOCK)
	end)
	window.unlockButton = unlock
	local minimap = CreateFrame("CheckButton", nil, window)
	minimap:SetSize(SIDE - 20, 26)
	minimap:SetPoint("BOTTOMLEFT", 10, 12)
	Highlight(minimap)
	local switch, Paint = Switch(minimap, 28, 16)
	switch:SetPoint("LEFT", 4, 0)
	local minimapLabel = Text(minimap, "GameFontHighlightSmall", MUTED)
	minimapLabel:SetPoint("LEFT", switch, "RIGHT", 8, 0)
	minimapLabel:SetPoint("RIGHT", -4, 0)
	minimapLabel:SetText(L.OPT_MINIMAP_BUTTON)
	minimap:SetScript("OnClick", function(self)
		db.minimapButton.hide = not self:GetChecked()
		ns.UpdateMinimapButton()
		Paint()
		Click()
	end)
	window.minimapCheck = minimap
	window:SetScript("OnShow", function()
		minimap:SetChecked(not db.minimapButton.hide)
		Paint()
		unlock:SetText(ns.unlocked and L.LOCK or L.UNLOCK)
		-- The pet page shows your pet's face when it's out
		if UnitExists("pet") and SetPortraitTexture then
			SetPortraitTexture(petTab.icon, "pet")
			petTab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		else
			petTab.icon:SetTexture(BEAST)
		end
	end)
	window:Hide()
end

function ns.ToggleOptions(key)
	if not window then Build() end
	if window:IsShown() and not key then
		window:Hide()
		return
	end
	window:Show()
	ns.ShowOptionsPage(key or window.page or "map")
end

-- For the tests
function ns.OptionsWindow()
	return window, pages
end

ns.commands.options = function() ns.ToggleOptions() end
ns.commands.opciones = ns.commands.options
ns.commands.config = ns.commands.options
