local _, ns = ...
local L = ns.L

local FEED_PET = 6991
local DRINK = 430 -- what drinks cast when used
local MAX_BUTTONS = 6
local SIZE = 30

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
	return (GetSpellInfo(id))
end
-- What GetPetFoodTypes says (English or Spanish) -> food types in PetFood.lua
local FOOD_WORDS = {
	{ 1, "meat", "carne" },
	{ 2, "fish", "pescado" },
	{ 3, "cheese", "queso" },
	{ 4, "bread", "pan" },
	{ 5, "fung", "hongo" },
	{ 6, "fruit", "fruta" },
}

local GetItemIconByID = C_Item and C_Item.GetItemIconByID or GetItemIcon
local GetNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots

local db, bar
local buttons = {}

local function SlotItem(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if info then return info.itemID, info.stackCount end
		return
	end
	local _, count, _, _, _, _, _, _, _, id = GetContainerItemInfo(bag, slot)
	return id, count
end

-- A hunter's pet is out (and alive)
-- The round font of the range display, over the game's in case it can't load
local function FancyFont(fontString, size, flags)
	local gameFont = GameFontNormal:GetFont()
	for _, font in ipairs({ gameFont, ns.FONTS and ns.FONTS[ns.db.range.font] or gameFont }) do
		fontString:SetFont(font, size, flags)
	end
end

local function HasPet()
	local dead = UnitIsDead("pet")
	if ns.IsSecret(dead) then dead = false end
	return ns.IsHunter() and UnitExists("pet") and not dead
end

-- What each pet family eats in Classic, by family ID, for when the game doesn't list it
local FAMILY_DIETS = {
	[1] = { 1 }, -- Wolf
	[2] = { 1, 2 }, -- Cat
	[3] = { 1 }, -- Spider
	[4] = { 1, 2, 3, 4, 5, 6 }, -- Bear
	[5] = { 1, 2, 3, 4, 5, 6 }, -- Boar
	[6] = { 1, 2 }, -- Crocolisk
	[7] = { 1, 2 }, -- Carrion Bird
	[8] = { 2, 4, 5, 6 }, -- Crab
	[9] = { 5, 6 }, -- Gorilla
	[11] = { 1 }, -- Raptor
	[12] = { 3, 5, 6 }, -- Tallstrider
	[20] = { 1 }, -- Scorpid
	[21] = { 2, 5, 6 }, -- Turtle
	[24] = { 5, 6 }, -- Bat
	[25] = { 1, 6 }, -- Hyena
	[26] = { 1 }, -- Owl
	[27] = { 2, 3, 4 }, -- Wind Serpent
}
-- The same by family name, for clients that only give the name (English and Spanish)
local FAMILY_NAMES = {
	wolf = 1, lobo = 1, cat = 2, felino = 2, spider = 3, ["araña"] = 3, bear = 4, oso = 4,
	boar = 5, ["jabalí"] = 5, crocolisk = 6, crocolisco = 6, ["carrion bird"] = 7, ["ave carroñera"] = 7,
	crab = 8, cangrejo = 8, gorilla = 9, gorila = 9, raptor = 11, tallstrider = 12, zancaalta = 12,
	scorpid = 20, ["escórpido"] = 20, turtle = 21, tortuga = 21, bat = 24, ["murciélago"] = 24,
	hyena = 25, hiena = 25, owl = 26, ["búho"] = 26, ["wind serpent"] = 27, ["serpiente alada"] = 27,
}

local function FamilyID()
	local name, id = UnitCreatureFamily("pet")
	if ns.IsSecret(name) or ns.IsSecret(id) then return end
	if type(id) == "number" then return id, name end
	return type(name) == "string" and FAMILY_NAMES[strlower(name)] or nil, name
end

-- Names of the food types the summoned pet eats. Forever has the stable API (slot 0 is
-- the pet you have out); older clients have the other two.
local function DietNames()
	local names
	if C_StableInfo and C_StableInfo.GetStablePetFoodTypes then
		names = C_StableInfo.GetStablePetFoodTypes(0)
	end
	if (type(names) ~= "table" or #names == 0) and GetStablePetFoodTypes then
		names = { GetStablePetFoodTypes(0) }
	end
	if (type(names) ~= "table" or #names == 0) and GetPetFoodTypes then
		names = { GetPetFoodTypes() }
	end
	return type(names) == "table" and names or {}
end

-- Food types the pet eats and where that came from ("game" or "family"), or nil
local function Diet()
	local diet
	for _, name in ipairs(DietNames()) do
		if type(name) == "string" and not ns.IsSecret(name) then
			local lower = strlower(name)
			for _, w in ipairs(FOOD_WORDS) do
				if lower:find(w[2], 1, true) or lower:find(w[3], 1, true) then
					diet = diet or {}
					diet[w[1]] = true
				end
			end
		end
	end
	if diet then return diet, "game" end
	local family = FAMILY_DIETS[FamilyID() or 0]
	if not family then return end
	diet = {}
	for _, foodType in ipairs(family) do diet[foodType] = true end
	return diet, "family"
end

-- How much a food pleases the pet: full up to 5 levels below the pet, less further down.
-- Forever lets a pet eat food far below it (a level 48 pet eats level 25 meat, which
-- Classic refuses past 14 levels), so only food 30 or more levels below is left out.
local TOO_LOW = 30

function ns.FoodBenefit(itemLevel, petLevel)
	local below = petLevel - itemLevel
	if below <= 5 then return 3 end
	if below <= 10 then return 2 end
	if below < TOO_LOW then return 1 end
	return 0
end

local function Benefit(food, petLevel)
	return ns.FoodBenefit(food.l, petLevel)
end

-- What the summoned pet eats and its level, or nil when there's no pet out or the
-- game doesn't say
function ns.PetDiet()
	if not HasPet() then return end
	local level = UnitLevel("pet")
	if not level or ns.IsSecret(level) or level <= 0 then return end
	local diet = Diet()
	if diet then return diet, level end
end

-- The food in your bags that the summoned pet eats, best first:
-- { id, count, bag, slot, benefit }, total. Nil when there's no pet or its diet is unknown.
function ns.PetFoods()
	local diet, level = ns.PetDiet()
	if not diet then return end
	local byID, list, total = {}, {}, 0
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, GetNumSlots(bag) or 0 do
			local id, count = SlotItem(bag, slot)
			local food = id and ns.petFoods[id]
			if food and diet[food.t] then
				local benefit = Benefit(food, level)
				if benefit > 0 then
					local entry = byID[id]
					if not entry then
						entry = { id = id, count = 0, bag = bag, slot = slot, benefit = benefit, level = food.l }
						byID[id] = entry
						list[#list + 1] = entry
					end
					entry.count = entry.count + (count or 1)
					total = total + (count or 1)
				end
			end
		end
	end
	-- The food that pleases it most first, and of that the lowest level, to keep the better one
	table.sort(list, function(a, b)
		if a.benefit ~= b.benefit then return a.benefit > b.benefit end
		if a.level ~= b.level then return a.level < b.level end
		return a.id < b.id
	end)
	return list, total
end

-- /huntergod mascota: what the addon knows about the pet you have out
local function PetInfo()
	if not HasPet() then
		ns.Print(L.PET_INFO_NONE)
		return
	end
	local _, family = FamilyID()
	local diet, source = Diet()
	local eats = {}
	for foodType in pairs(diet or {}) do eats[#eats + 1] = foodType end
	table.sort(eats)
	for i, foodType in ipairs(eats) do eats[i] = L.FOOD_TYPES[foodType] end
	local level = UnitLevel("pet")
	ns.Print(format(L.PET_INFO, tostring(family or "?"), ns.IsSecret(level) and 0 or level or 0,
		#eats > 0 and table.concat(eats, ", ") or L.PET_DIET_UNKNOWN, source and L.DIET_FROM[source] or "-"))
	local _, total = ns.PetFoods()
	ns.Print(format(L.PET_INFO_FOOD, total or 0, ns.FoodVendorsShown and ns.FoodVendorsShown() or 0))

	-- Every food in the bags and what the addon makes of it
	local counts, order = {}, {}
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, GetNumSlots(bag) or 0 do
			local id, count = SlotItem(bag, slot)
			if id then
				if not counts[id] then order[#order + 1] = id end
				counts[id] = (counts[id] or 0) + (count or 1)
			end
		end
	end
	local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
	local getSpell = C_Item and C_Item.GetItemSpell or GetItemSpell
	local drinkSpell = SpellName(DRINK)
	for _, id in ipairs(order) do
		local name, link, _, _, _, _, _, _, _, _, _, classID, subclassID = getInfo(id)
		local food = ns.petFoods[id]
		if food then
			local verdict = L.FOOD_EATS
			if not (diet and diet[food.t]) then
				verdict = L.FOOD_NOT_DIET
			elseif type(level) == "number" and not ns.IsSecret(level) and ns.FoodBenefit(food.l, level) == 0 then
				verdict = L.FOOD_TOO_LOW
			end
			ns.Print(format(L.FOOD_LINE, link or name or id, counts[id], L.FOOD_TYPES[food.t], food.l, verdict))
		elseif (classID == 0 and subclassID == 5) or (classID == 7 and subclassID == 8) then
			-- Food or cooking meat the addon has no record of; drinks share the class with
			-- food, but using them casts Drink
			local use = getSpell and getSpell(id)
			if not (drinkSpell and use == drinkSpell) then
				ns.Print(format(L.FOOD_UNKNOWN, link or name or id, counts[id]))
			end
		end
	end
end
ns.commands.pet = PetInfo
ns.commands.mascota = PetInfo

-- The food buttons are secure (a click casts Feed Pet), so they only change out of
-- combat; leaving combat updates them
function ns.UpdatePetFood()
	if InCombatLockdown() then return end
	local list, total
	if db.enabled and db.bar and ns.IsHunter() then
		list, total = ns.PetFoods()
		-- While the displays are unlocked an empty bar stands in, to be dragged
		if not list and ns.unlocked then list, total = {}, 0 end
	end
	if not list then
		bar:Hide()
		return
	end
	local feed = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(FEED_PET) or GetSpellInfo(FEED_PET)
	local shown = 0
	for i, button in ipairs(buttons) do
		local food = list[i]
		if food and feed then
			button.icon:SetTexture(GetItemIconByID(food.id))
			button.icon:SetVertexColor(1, 1, food.benefit == 3 and 1 or 0.5)
			button.count:SetText(food.count)
			button.food = food
			button:SetAttribute("macrotext", format("/cast %s\n/use %d %d", feed, food.bag, food.slot))
			button:Show()
			shown = i
		else
			button.food = nil
			button:Hide()
		end
	end
	if total == 0 then
		bar.title:SetText(L.PET_NO_FOOD)
		bar.title:SetTextColor(1, 0.2, 0.2)
	elseif total < db.low then
		bar.title:SetText(format(L.PET_LOW, total))
		bar.title:SetTextColor(1, 0.6, 0.1)
	else
		bar.title:SetText(L.PET_FOOD)
		bar.title:SetTextColor(1, 0.82, 0)
	end
	bar:SetWidth(max(shown, 1) * (SIZE + 2))
	bar:Show()
end

local function Food_OnEnter(self)
	if not self.food then return end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetBagItem(self.food.bag, self.food.slot)
	if self.food.benefit < 3 then
		GameTooltip:AddLine(L.PET_LOW_LEVEL_FOOD, 1, 0.6, 0.1)
	end
	GameTooltip:AddLine(L.PET_FEED_TIP, 0.4, 0.7, 1)
	GameTooltip:Show()
end

-- At a vendor: if you are short of food, say which of theirs the pet eats
local function CheckMerchant()
	if not (db.enabled and db.merchant and ns.IsHunter()) then return end
	local list, total = ns.PetFoods()
	if not list or total >= db.low then return end
	local diet, level = Diet(), UnitLevel("pet")
	local links = {}
	for i = 1, GetMerchantNumItems() do
		local id = GetMerchantItemID and GetMerchantItemID(i)
		local food = id and ns.petFoods[id]
		if food and diet[food.t] and Benefit(food, level) > 0 then
			links[#links + 1] = GetMerchantItemLink(i) or tostring(id)
			if #links == 3 then break end
		end
	end
	if #links > 0 then
		ns.Print(format(L.PET_MERCHANT, table.concat(links, ", ")))
	end
end

bar = CreateFrame("Frame", "HunterGodPetFood", UIParent)
bar:SetSize(SIZE, SIZE)
bar:Hide()
bar.title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
bar.title:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 3)
for i = 1, MAX_BUTTONS do
	local button = CreateFrame("Button", "HunterGodPetFood" .. i, bar, "SecureActionButtonTemplate")
	button:SetSize(SIZE, SIZE)
	button:SetPoint("LEFT", (i - 1) * (SIZE + 2), 0)
	button:RegisterForClicks("AnyUp", "AnyDown")
	button:SetAttribute("type", "macro")
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	button.count:SetPoint("BOTTOMRIGHT", -1, 2)
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetScript("OnEnter", Food_OnEnter)
	button:SetScript("OnLeave", GameTooltip_Hide)
	button:Hide()
	buttons[i] = button
end

-- Growl on autocast takes the aggro off the tank: a reminder in dungeons and raids
local GROWL = 2649
local growlDB, growlFrame
local growlWarned = false

-- true / false, or nil when the pet bar doesn't say
function ns.GrowlOnAutocast()
	local growl = SpellName(GROWL)
	for i = 1, NUM_PET_ACTION_SLOTS or 10 do
		local name, _, isToken, _, _, autoCast, spellID = GetPetActionInfo(i)
		if ns.IsSecret(name) or ns.IsSecret(spellID) then return nil end
		if not isToken and growl and (name == growl or (spellID and SpellName(spellID) == growl)) then
			if ns.IsSecret(autoCast) then return nil end
			return autoCast and true or false
		end
	end
	return false
end

local function GrowlMatters()
	local inInstance, kind = IsInInstance()
	if inInstance and (kind == "party" or kind == "raid") then return true end
	return growlDB.groups and IsInGroup() or false
end

function ns.UpdateGrowl()
	local warn = ns.unlocked
	if not warn and growlDB.enabled and ns.IsHunter() and HasPet() and GrowlMatters() then
		warn = ns.GrowlOnAutocast()
	end
	if not warn then
		growlFrame:Hide()
		growlWarned = false
		return
	end
	growlFrame.text:SetText(format(L.GROWL_ON, SpellName(GROWL) or "Growl"))
	growlFrame:Show()
	if not growlFrame.pulse:IsPlaying() then growlFrame.pulse:Play() end
	if not growlWarned and not ns.unlocked then
		growlWarned = true
		ns.Print(format(L.GROWL_MSG, SpellName(GROWL) or "Growl"))
	end
end

growlFrame = CreateFrame("Frame", "HunterGodGrowl", UIParent)
growlFrame:SetSize(36, 36)
growlFrame:Hide()
local growlBorder = growlFrame:CreateTexture(nil, "BORDER")
growlBorder:SetPoint("TOPLEFT", -2, 2)
growlBorder:SetPoint("BOTTOMRIGHT", 2, -2)
growlBorder:SetColorTexture(0.9, 0.1, 0.1, 0.9)
growlFrame.icon = growlFrame:CreateTexture(nil, "ARTWORK")
growlFrame.icon:SetAllPoints()
growlFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
growlFrame.text = growlFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
growlFrame.text:SetPoint("TOP", growlFrame, "BOTTOM", 0, -4)
growlFrame.text:SetTextColor(1, 0.3, 0.2)
growlFrame.pulse = growlFrame:CreateAnimationGroup()
growlFrame.pulse:SetLooping("BOUNCE")
local growlFade = growlFrame.pulse:CreateAnimation("Alpha")
growlFade:SetFromAlpha(1)
growlFade:SetToAlpha(0.45)
growlFade:SetDuration(0.6)

-- "Growl Miss" floating up when Growl doesn't pull the mob onto the pet. Forever keeps the
-- combat log from addons, so a miss is read from the mob: a moment after Growl it still
-- isn't attacking the pet (resisted, or not enough threat: either way it didn't work).
-- A mob that Growl pulls turns within a server tick, so the check comes early, while it's
-- still on its way to you; if it turns to the pet after all, the miss goes away.
local GROWL_CHECK = 0.4 -- s after Growl
local growlMiss

function ns.GrowlMissText()
	growlMiss.text:SetText(format(L.GROWL_MISS, SpellName(GROWL) or "Growl"))
	growlMiss:SetSize(max(growlMiss.text:GetStringWidth() + 8, 60), 34)
end

local function ShowGrowlMiss()
	ns.GrowlMissText()
	FancyFont(growlMiss.text, 24, "THICKOUTLINE")
	growlMiss.float:Stop()
	growlMiss:SetAlpha(1)
	growlMiss:Show()
	growlMiss.float:Play()
	growlMiss.watch = true
end

-- true or false, or nil when there's no mob or the game hides who it attacks
local function MobOnPet()
	if not (HasPet() and UnitExists("pettarget")) then return end
	local onPet = UnitIsUnit("pettargettarget", "pet")
	if ns.IsSecret(onPet) then return end
	return onPet
end

local function CheckGrowlLanded()
	if growlDB.miss and MobOnPet() == false then ShowGrowlMiss() end
end

function ns.UpdateGrowlMiss()
	growlMiss.watch = false
	if ns.unlocked and growlDB.miss then
		ns.GrowlMissText()
		FancyFont(growlMiss.text, 24, "THICKOUTLINE")
		growlMiss.float:Stop()
		growlMiss:SetAlpha(1)
		growlMiss:Show()
	else
		growlMiss:Hide()
	end
end

growlMiss = CreateFrame("Frame", "HunterGodGrowlMiss", UIParent)
growlMiss:SetSize(160, 34)
growlMiss:Hide()
growlMiss.text = growlMiss:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
growlMiss.text:SetPoint("CENTER")
growlMiss.text:SetTextColor(1, 0.3, 0.15)
-- Up and away, like the game's combat text
growlMiss.float = growlMiss:CreateAnimationGroup()
local rise = growlMiss.float:CreateAnimation("Translation")
rise:SetOffset(0, 60)
rise:SetDuration(1.6)
local fadeAway = growlMiss.float:CreateAnimation("Alpha")
fadeAway:SetFromAlpha(1)
fadeAway:SetToAlpha(0)
fadeAway:SetStartDelay(0.6)
fadeAway:SetDuration(1)
growlMiss.float:SetScript("OnFinished", function() growlMiss:Hide() end)
-- Slow to turn: the mob came onto the pet after all, so it wasn't a miss
growlMiss:SetScript("OnUpdate", function(self)
	if self.watch and MobOnPet() then
		self.watch = false
		self.float:Stop()
		self:Hide()
	end
end)

local growlEvents = CreateFrame("Frame")
growlEvents:RegisterEvent("PLAYER_LOGIN")
growlEvents:SetScript("OnEvent", function(self, event, unit, _, spellID)
	if event == "PLAYER_LOGIN" then
		growlDB = ns.db.growl
		growlFrame.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(GROWL) or GetSpellTexture(GROWL))
		ns.Movable(growlFrame, "growl", { "CENTER", "CENTER", 0, 200 }, SpellName(GROWL) or "Growl")
		ns.Movable(growlMiss, "growlMiss", { "CENTER", "CENTER", 0, 90 }, format(L.GROWL_MISS, SpellName(GROWL) or "Growl"))
		table.insert(ns.refreshers, ns.UpdateGrowl)
		table.insert(ns.refreshers, ns.UpdateGrowlMiss)
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		self:RegisterEvent("GROUP_ROSTER_UPDATE")
		self:RegisterEvent("PET_BAR_UPDATE")
		self:RegisterUnitEvent("UNIT_PET", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "pet")
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if unit == "pet" and not ns.IsSecret(spellID) and spellID and SpellName(spellID) == SpellName(GROWL) then
			C_Timer.After(GROWL_CHECK, CheckGrowlLanded)
		end
		return
	end
	-- The pet bar fills in a moment after the pet appears
	C_Timer.After(0.5, ns.UpdateGrowl)
end)

-- A toast at the top of the screen when the pet levels up or earns training points
local LEVEL_UP_SOUND = 888 -- the player's level up sound
local TOAST_TIME = 5
local toastDB, toast
local petLevel, petName, petPoints -- what the pet had, to tell what's new
local toastToken = 0

-- Training points left to spend, or nil
local function FreePoints()
	if not GetPetTrainingPoints then return end
	local total, spent = GetPetTrainingPoints()
	if type(total) ~= "number" or ns.IsSecret(total) or ns.IsSecret(spent) then return end
	return total - (spent or 0)
end


local function HideToast()
	toast.fadeOut:Play()
end

-- kind: "level" (value = the new level) or "points" (value = the points gained)
local function Toast(kind, value)
	local now = GetTime()
	-- Points that come with a level up go on the same toast
	local fresh = not (toast:IsShown() and toast.shownAt and now - toast.shownAt < 2)
	if fresh then
		toast.title:SetText("")
		toast.sub:SetText("")
		toast.shownAt = now
	end
	if kind == "level" then
		toast.title:SetText(format(L.PET_LEVEL_TOAST, value))
	else
		if toast.title:GetText() == "" or toast.title:GetText() == nil then toast.title:SetText(L.PET_TP_TITLE) end
		toast.sub:SetText(format(L.PET_TP_TOAST, value, FreePoints() or value))
	end
	toast.name:SetText(petName or UnitName("pet") or "")
	if SetPortraitTexture then SetPortraitTexture(toast.portrait, "pet") end
	FancyFont(toast.title, 28, "THICKOUTLINE")
	FancyFont(toast.sub, 14, "OUTLINE")
	if fresh then
		toast.active = true
		toast.fadeOut:Stop()
		toast:SetAlpha(0)
		toast:Show()
		toast.fadeIn:Play()
		toast.spin:Play()
		if toastDB.sound then pcall(PlaySound, LEVEL_UP_SOUND) end
	end
	toastToken = toastToken + 1
	local token = toastToken
	C_Timer.After(TOAST_TIME, function() if token == toastToken then HideToast() end end)
end

-- Compares the pet with what it had: a new level or more points to spend
local function CheckPetProgress(newPet)
	if not ns.IsHunter() or not HasPet() then
		petLevel, petName, petPoints = nil, nil, nil
		return
	end
	local level, name, points = UnitLevel("pet"), UnitName("pet"), FreePoints()
	if ns.IsSecret(level) then level = nil end
	if ns.IsSecret(name) then name = nil end
	-- Another pet (or the first look at this one): just remember it
	if newPet or name ~= petName or not petLevel then
		petLevel, petName, petPoints = level, name, points
		return
	end
	if level and level > petLevel then
		if toastDB.level then
			Toast("level", level)
			ns.Print(format(L.PET_LEVEL_MSG, name or "?", level))
		end
		petLevel = level
	end
	if points and petPoints and points > petPoints and toastDB.training then
		Toast("points", points - petPoints)
		ns.Print(format(L.PET_TP_MSG, name or "?", points - petPoints, points))
	end
	if points then petPoints = points end
end

function ns.UpdatePetToast()
	if ns.unlocked then
		toast.fadeOut:Stop()
		toast.title:SetText(format(L.PET_LEVEL_TOAST, 60))
		toast.sub:SetText(format(L.PET_TP_TOAST, 15, 120))
		toast.name:SetText(L.PET_TOAST_NAME)
		FancyFont(toast.title, 28, "THICKOUTLINE")
		FancyFont(toast.sub, 14, "OUTLINE")
		toast:SetAlpha(1)
		toast:Show()
		toast.active = false -- the sample replaces any real toast
	elseif not toast.active then
		toast:Hide()
	end
end

toast = CreateFrame("Frame", "HunterGodPetToast", UIParent)
toast:SetSize(330, 84)
toast:SetFrameStrata("HIGH")
toast:Hide()
local toastBg = toast:CreateTexture(nil, "BACKGROUND")
toastBg:SetAllPoints()
toastBg:SetColorTexture(0, 0, 0, 0.6)
for _, edge in ipairs({ "TOP", "BOTTOM" }) do
	local line = toast:CreateTexture(nil, "BORDER")
	line:SetHeight(2)
	line:SetPoint(edge .. "LEFT")
	line:SetPoint(edge .. "RIGHT")
	line:SetColorTexture(1, 0.82, 0, 0.9)
end
-- A golden star turning behind the pet's portrait
toast.star = toast:CreateTexture(nil, "BORDER")
toast.star:SetSize(118, 118)
toast.star:SetPoint("CENTER", toast, "LEFT", 44, 0)
toast.star:SetTexture("Interface\\Cooldown\\star4")
toast.star:SetBlendMode("ADD")
toast.star:SetVertexColor(1, 0.8, 0.2, 0.8)
toast.spin = toast.star:CreateAnimationGroup()
toast.spin:SetLooping("REPEAT")
local turn = toast.spin:CreateAnimation("Rotation")
turn:SetDegrees(-360)
turn:SetDuration(6)
toast.portrait = toast:CreateTexture(nil, "ARTWORK")
toast.portrait:SetSize(58, 58)
toast.portrait:SetPoint("CENTER", toast, "LEFT", 44, 0)
-- Cut round with a clamped mask: the SetMask shortcut repeats it, and Forever draws stripes
if toast.CreateMaskTexture then
	local round = toast:CreateMaskTexture()
	round:SetAllPoints(toast.portrait)
	round:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	toast.portrait:AddMaskTexture(round)
end
toast.name = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
toast.name:SetPoint("TOPLEFT", 86, -8)
toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
toast.title:SetPoint("LEFT", 86, 2)
toast.title:SetTextColor(1, 0.85, 0.2)
toast.sub = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
toast.sub:SetPoint("BOTTOMLEFT", 86, 8)
toast.fadeIn = toast:CreateAnimationGroup()
local appear = toast.fadeIn:CreateAnimation("Alpha")
appear:SetFromAlpha(0)
appear:SetToAlpha(1)
appear:SetDuration(0.3)
toast.fadeIn:SetScript("OnFinished", function() toast:SetAlpha(1) end)
toast.fadeOut = toast:CreateAnimationGroup()
local vanish = toast.fadeOut:CreateAnimation("Alpha")
vanish:SetFromAlpha(1)
vanish:SetToAlpha(0)
vanish:SetDuration(0.8)
toast.fadeOut:SetScript("OnFinished", function()
	toast.active = false
	toast:Hide()
	toast.spin:Stop()
end)

local toastEvents = CreateFrame("Frame")
toastEvents:RegisterEvent("PLAYER_LOGIN")
toastEvents:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		toastDB = ns.db.petToast
		ns.Movable(toast, "petToast", { "TOP", "TOP", 0, -140 }, L.PET_TOAST_NAME)
		table.insert(ns.refreshers, ns.UpdatePetToast)
		self:RegisterUnitEvent("UNIT_PET", "player")
		self:RegisterUnitEvent("UNIT_LEVEL", "pet")
		self:RegisterEvent("PET_BAR_UPDATE")
		-- Not every client has these: they are only listened to where they exist
		pcall(self.RegisterEvent, self, "UNIT_PET_TRAINING_POINTS")
		pcall(self.RegisterEvent, self, "PET_UI_UPDATE")
		C_Timer.After(1, function() CheckPetProgress(true) end)
	elseif event == "UNIT_PET" then
		-- The new pet's details arrive a moment later
		C_Timer.After(1, function() CheckPetProgress(true) end)
	else
		CheckPetProgress(false)
	end
end)

-- NOT HAPPY over the pet's portrait, and a call to heal the pet when its health drops
local HAPPY = 3 -- GetPetHappiness: 1 unhappy, 2 content, 3 happy
local MEND_PET = 136
local statusDB, unhappy, hurt

local function Blink(frame, on)
	if on then
		if not frame:IsShown() then
			frame:Show()
			frame.blink:Play()
		end
	elseif frame:IsShown() then
		frame.blink:Stop()
		frame:Hide()
	end
end

-- Over the portrait of the game's pet frame, while there is one to sit on
local function PlaceOverPortrait(self)
	local portrait = PetPortrait or (PetFrame and PetFrame.portrait)
	self:ClearAllPoints()
	if portrait and PetFrame and PetFrame:IsVisible() then
		self:SetPoint("BOTTOM", portrait, "TOP", 0, 4)
	else
		local p = self.defaultPoint
		self:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	end
end

function ns.UpdatePetStatus()
	local pet = ns.IsHunter() and HasPet()
	if not ns.db.positions.happiness then PlaceOverPortrait(unhappy) end
	local sad = ns.unlocked and statusDB.happy
	if not sad and pet and statusDB.happy and GetPetHappiness then
		local happiness = GetPetHappiness()
		sad = type(happiness) == "number" and not ns.IsSecret(happiness) and happiness < HAPPY
	end
	Blink(unhappy, sad)

	local percent
	if ns.unlocked and statusDB.health then
		percent = 25
	elseif pet and statusDB.health then
		local health, maxHealth = UnitHealth("pet"), UnitHealthMax("pet")
		-- Forever may hide the pet's health in combat: then there's nothing to say
		if not ns.IsSecret(health) and not ns.IsSecret(maxHealth) and maxHealth and maxHealth > 0 then
			percent = floor(health / maxHealth * 100 + 0.5)
			if percent >= statusDB.healthPct then percent = nil end
		end
	end
	if percent then
		hurt.text:SetText(format(L.PET_HEALTH, percent))
		FancyFont(hurt.text, 24, "THICKOUTLINE")
		hurt:SetWidth(hurt.text:GetStringWidth() + 44)
	end
	Blink(hurt, percent ~= nil)
end

local function BlinkGroup(frame, low, duration)
	frame.blink = frame:CreateAnimationGroup()
	frame.blink:SetLooping("BOUNCE")
	local fade = frame.blink:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(low)
	fade:SetDuration(duration)
end

unhappy = CreateFrame("Frame", "HunterGodNotHappy", UIParent)
unhappy:SetSize(100, 18)
unhappy:Hide()
unhappy.text = unhappy:CreateFontString(nil, "OVERLAY", "GameFontNormal")
unhappy.text:SetPoint("CENTER")
unhappy.text:SetTextColor(1, 0.12, 0.12)
unhappy.placeDefault = PlaceOverPortrait
BlinkGroup(unhappy, 0.2, 0.5)

hurt = CreateFrame("Frame", "HunterGodPetHealth", UIParent)
hurt:SetSize(220, 36)
hurt:Hide()
hurt.icon = hurt:CreateTexture(nil, "ARTWORK")
hurt.icon:SetSize(32, 32)
hurt.icon:SetPoint("LEFT")
hurt.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
hurt.text = hurt:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
hurt.text:SetPoint("LEFT", hurt.icon, "RIGHT", 8, 0)
hurt.text:SetTextColor(1, 0.4, 0.1)
BlinkGroup(hurt, 0.45, 0.6)

local statusEvents = CreateFrame("Frame")
statusEvents:RegisterEvent("PLAYER_LOGIN")
statusEvents:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		statusDB = ns.db.petStatus
		unhappy.text:SetText(L.NOT_HAPPY)
		FancyFont(unhappy.text, 14, "OUTLINE")
		unhappy:SetWidth(unhappy.text:GetStringWidth() + 8)
		hurt.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(MEND_PET) or GetSpellTexture(MEND_PET))
		ns.Movable(unhappy, "happiness", { "CENTER", "CENTER", -260, -120 }, L.NOT_HAPPY)
		ns.Movable(hurt, "petHealth", { "CENTER", "CENTER", 0, 30 }, L.PET_HEALTH_NAME)
		table.insert(ns.refreshers, ns.UpdatePetStatus)
		self:RegisterUnitEvent("UNIT_HEALTH", "pet")
		self:RegisterUnitEvent("UNIT_MAXHEALTH", "pet")
		self:RegisterUnitEvent("UNIT_PET", "player")
		pcall(self.RegisterEvent, self, "UNIT_HAPPINESS")
		pcall(self.RegisterEvent, self, "PET_UI_UPDATE")
		-- Not every client says when happiness changes: a look every second as well
		C_Timer.NewTicker(1, ns.UpdatePetStatus)
	end
	ns.UpdatePetStatus()
end)

-- Bestial Wrath on the pet's portrait, with the seconds it has left. Forever hides the
-- pet's buffs in combat, so the time runs from your cast (its real duration when the game
-- shows the buff)
local BESTIAL_WRATH = 19574
local WRATH_TIME = 18
local wrath
local wrathEnds = 0

-- On the lower right corner of the game's pet portrait while there is one
local function PlaceOnPortrait(self)
	local portrait = PetPortrait or (PetFrame and PetFrame.portrait)
	self:ClearAllPoints()
	if portrait and PetFrame and PetFrame:IsVisible() then
		self:SetPoint("CENTER", portrait, "BOTTOMRIGHT", -6, 8)
	else
		local p = self.defaultPoint
		self:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	end
end

local function WrathDuration()
	local name = SpellName(BESTIAL_WRATH)
	local aura = name and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
		and C_UnitAuras.GetAuraDataBySpellName("pet", name, "HELPFUL")
	if type(aura) == "table" and not ns.IsSecret(aura.expirationTime) and aura.expirationTime
		and aura.expirationTime > GetTime() then
		return aura.expirationTime - GetTime()
	end
	return WRATH_TIME
end

local function WrathTick()
	local left = wrathEnds - GetTime()
	if left <= 0 or not HasPet() then
		wrath:Hide()
		return
	end
	wrath.time:SetText(ceil(left))
end

local function StartWrath()
	local duration = WrathDuration()
	wrathEnds = GetTime() + duration
	if not ns.db.positions.bestialWrath then PlaceOnPortrait(wrath) end
	wrath.cooldown:SetCooldown(GetTime(), duration)
	wrath:Show()
	WrathTick()
end

function ns.UpdateWrath()
	if ns.unlocked and statusDB.wrath then
		wrath.time:SetText(WRATH_TIME)
		wrath:Show()
	elseif wrathEnds <= GetTime() or not statusDB.wrath then
		wrath:Hide()
	end
end

wrath = CreateFrame("Frame", "HunterGodBestialWrath", UIParent)
wrath:SetSize(26, 26)
wrath:SetFrameStrata("HIGH")
wrath:Hide()
wrath.icon = wrath:CreateTexture(nil, "ARTWORK")
wrath.icon:SetAllPoints()
wrath.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
wrath.cooldown = CreateFrame("Cooldown", nil, wrath, "CooldownFrameTemplate")
wrath.cooldown:SetAllPoints()
if wrath.cooldown.SetHideCountdownNumbers then wrath.cooldown:SetHideCountdownNumbers(true) end
wrath.time = wrath.cooldown:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
wrath.time:SetPoint("CENTER", 0, 0)
wrath.time:SetTextColor(1, 0.85, 0.2)
wrath.placeDefault = PlaceOnPortrait
local wrathElapsed = 0
wrath:SetScript("OnUpdate", function(_, dt)
	wrathElapsed = wrathElapsed + dt
	if wrathElapsed < 0.1 or ns.unlocked then return end
	wrathElapsed = 0
	WrathTick()
end)

local wrathEvents = CreateFrame("Frame")
wrathEvents:RegisterEvent("PLAYER_LOGIN")
wrathEvents:SetScript("OnEvent", function(self, event, unit, _, spellID)
	if event == "PLAYER_LOGIN" then
		wrath.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(BESTIAL_WRATH) or GetSpellTexture(BESTIAL_WRATH))
		FancyFont(wrath.time, 16, "THICKOUTLINE")
		ns.Movable(wrath, "bestialWrath", { "CENTER", "CENTER", -260, -150 }, SpellName(BESTIAL_WRATH) or "Bestial Wrath")
		table.insert(ns.refreshers, ns.UpdateWrath)
		self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		self:RegisterUnitEvent("UNIT_PET", "player")
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if unit == "player" and not ns.IsSecret(spellID) and statusDB.wrath and HasPet()
			and spellID and SpellName(spellID) == SpellName(BESTIAL_WRATH) then
			-- The buff is on the pet a moment after the cast
			C_Timer.After(0.1, StartWrath)
		end
	elseif event == "UNIT_PET" then
		WrathTick()
	end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		db = ns.db.petFood
		ns.Movable(bar, "petFood", { "CENTER", "CENTER", 160, -60 }, L.TAB_PET)
		table.insert(ns.refreshers, ns.UpdatePetFood)
		self:RegisterEvent("BAG_UPDATE_DELAYED")
		self:RegisterUnitEvent("UNIT_PET", "player")
		self:RegisterUnitEvent("UNIT_LEVEL", "pet")
		self:RegisterEvent("PET_BAR_UPDATE")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("MERCHANT_SHOW")
		ns.UpdatePetFood()
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- The last moment the secure bar can still be hidden before combat
		if db.hideInCombat then bar:Hide() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		ns.UpdatePetFood()
	elseif event == "MERCHANT_SHOW" then
		C_Timer.After(0.5, CheckMerchant)
	else
		ns.UpdatePetFood()
	end
end)
