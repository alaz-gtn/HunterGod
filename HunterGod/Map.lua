local addonName, ns = ...
local L = ns.L

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

-- Items whose icons the pins use: Rough Arrow, Light Shot and Haunch of Meat
local ROUGH_ARROW, LIGHT_SHOT, HAUNCH_OF_MEAT = 2512, 2516, 2287
local PROJECTILE_CLASS = Enum.ItemClass and Enum.ItemClass.Projectile or 6
local SUBCLASS_ARROW, SUBCLASS_BULLET = 2, 3
local WEAPON_CLASS = Enum.ItemClass and Enum.ItemClass.Weapon or 2
local WEAPON_BOW, WEAPON_GUN, WEAPON_CROSSBOW = 2, 3, 18
local RANGED_SLOT = INVSLOT_RANGED or 18
-- Levels at which each ammo tier above the basic one becomes available
local AMMO_TIERS = { 10, 25, 40 }
-- Round hunter crest for the trainer pins
local HUNTER_ICON = "Interface\\TargetingFrame\\UI-Classes-Circles"
local HUNTER_COORDS = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS.HUNTER or { 0, 0.25, 0.25, 0.5 }

ns.HUNTER_ICON, ns.HUNTER_COORDS = HUNTER_ICON, HUNTER_COORDS
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local GetItemIconByID = C_Item and C_Item.GetItemIconByID or GetItemIcon
local englishClient = GetLocale() == "enUS" or GetLocale() == "enGB"

-- Slash command words in English and Spanish
local AMMO_WORDS = {
	both = "both", ambas = "both",
	arrows = "arrows", flechas = "arrows",
	bullets = "bullets", balas = "bullets",
	weapon = "weapon", arma = "weapon",
}
local TOGGLE_WORDS = {
	trainers = "trainers", instructores = "trainers",
	food = "foodVendors", comida = "foodVendors",
	faction = "allFactions", faccion = "allFactions", ["facción"] = "allFactions",
	minimap = "minimap", minimapa = "minimap",
	continent = "continent", continente = "continent",
	class = "onlyHunter", clase = "onlyHunter",
}
local NEAREST_WORDS = { nearest = true, cerca = true }

local db
local playerSide
local vendors = {} -- bundled data plus what was recorded in game
local worldPins, minimapPins = {}, {}
local trainerWorldPins, trainerMinimapPins = {}, {}
local foodWorldPins, foodMinimapPins = {}, {}
local foodShown = 0 -- pet food vendors on the map right now
local icons = {}
local filterPanel
local Print = ns.Print
ns.icons = icons

local function SideOf(faction)
	if faction == "Alliance" then return "A" end
	if faction == "Horde" then return "H" end
	return "B"
end

local function ZoneName(mapID)
	local info = C_Map.GetMapInfo(mapID)
	return info and info.name or format(L.MAP, mapID)
end

local function LookupName(id)
	if db.names[id] then return db.names[id] end
	if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return end
	local data = C_TooltipInfo.GetHyperlink("unit:Creature-0-0-0-0-" .. id .. "-0")
	local line = data and data.lines and data.lines[1]
	local name = line and line.leftText
	if name and name ~= "" and not (issecretvalue and issecretvalue(name)) then
		db.names[id] = name
		return name
	end
end

-- The bundled names are English: other clients ask the game for the localized one
local function NpcName(id, v)
	if v.learned or englishClient then
		return v.name or LookupName(id) or L.VENDOR
	end
	return LookupName(id) or v.name or L.VENDOR
end

local function RebuildVendors()
	wipe(vendors)
	for id, v in pairs(ns.vendors) do
		if not db.notAmmo[id] then
			vendors[id] = v
		end
	end
	-- What was seen in game wins over the bundled data
	for id, v in pairs(db.learned) do
		vendors[id] = v
	end
end

-- Picks the ammo for the equipped ranged weapon, or both if there is none
local function MatchWeapon()
	local itemID = GetInventoryItemID("player", RANGED_SLOT)
	local classID, subclassID
	if itemID then
		classID, subclassID = select(6, GetItemInfoInstant(itemID))
	end
	if classID == WEAPON_CLASS and subclassID == WEAPON_GUN then
		db.arrows, db.bullets = false, true
	elseif classID == WEAPON_CLASS and (subclassID == WEAPON_BOW or subclassID == WEAPON_CROSSBOW) then
		db.arrows, db.bullets = true, false
	else
		db.arrows, db.bullets = true, true
	end
end

local function OnMySide(v)
	return db.allFactions or v.side == "B" or v.side == playerSide
end

local function IsShown(v)
	return OnMySide(v) and ((db.arrows and v.arrows) or (db.bullets and v.bullets))
end

-- Only sells ammo below your level
local function IsOutgrown(v)
	return v.upTo and UnitLevel("player") >= v.upTo
end

-- Where each kind of pin gets its NPCs from
local function Source(kind)
	if kind == "trainer" then return ns.trainers end
	if kind == "food" then return ns.foodVendors end
	return vendors
end

-- Food types a vendor sells that the summoned pet eats, at a level that still pleases it
local function FoodForPet(v, diet, petLevel)
	local types
	for foodType, level in pairs(v.food) do
		if diet[foodType] and ns.FoodBenefit(level, petLevel) > 0 then
			types = types or {}
			types[#types + 1] = foodType
		end
	end
	if types then table.sort(types) end
	return types
end

local function SetWaypoint(id, kind)
	local v = Source(kind)[id]
	if not v then return end
	local name = NpcName(id, v)
	if TomTom and TomTom.AddWaypoint then
		TomTom:AddWaypoint(v.m, v.x / 100, v.y / 100, { title = name, from = addonName })
	elseif C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(v.m) and UiMapPoint then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(v.m, v.x / 100, v.y / 100))
		if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
			C_SuperTrack.SetSuperTrackedUserWaypoint(true)
		end
	else
		Print(L.NO_WAYPOINT)
		return
	end
	Print(format(L.WAYPOINT, name, ZoneName(v.m), v.x, v.y))
end

local function Pin_OnEnter(self)
	local v = Source(self.kind)[self.id]
	if not v then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(NpcName(self.id, v), 1, 1, 1)
	if self.kind == "trainer" then
		GameTooltip:AddLine(L.HUNTER_TRAINER, 0.67, 0.83, 0.45)
	elseif self.kind == "food" then
		GameTooltip:AddLine(L.FOOD_VENDOR, 0.67, 0.83, 0.45)
		local diet, petLevel = ns.PetDiet()
		for _, foodType in ipairs(diet and FoodForPet(v, diet, petLevel) or {}) do
			GameTooltip:AddLine(format(L.FOOD_SELLS, L.FOOD_TYPES[foodType], v.food[foodType]), 0.8, 0.8, 0.8)
		end
	elseif v.arrows and v.bullets then
		GameTooltip:AddLine(L.SELLS_BOTH, 0.67, 0.83, 0.45)
	elseif v.arrows then
		GameTooltip:AddLine(L.SELLS_ARROWS, 0.67, 0.83, 0.45)
	else
		GameTooltip:AddLine(L.SELLS_BULLETS, 0.67, 0.83, 0.45)
	end
	if v.upTo then
		if IsOutgrown(v) then
			GameTooltip:AddLine(format(L.OUTGROWN, v.upTo), 1, 0.5, 0.25)
		else
			GameTooltip:AddLine(format(L.USEFUL_UNTIL, v.upTo), 0.8, 0.8, 0.8)
		end
	end
	if v.side ~= "B" and v.side ~= playerSide then
		GameTooltip:AddLine(v.side == "A" and L.ALLIANCE_ONLY or L.HORDE_ONLY, 1, 0.25, 0.25)
	end
	GameTooltip:AddLine(format("%s  %.1f, %.1f", ZoneName(v.m), v.x, v.y), 0.6, 0.6, 0.6)
	if v.learned then
		GameTooltip:AddLine(L.LEARNED, 0.25, 1, 0.25)
	end
	GameTooltip:AddLine(L.CLICK, 0.4, 0.7, 1)
	GameTooltip:Show()
end

local function Pin_OnClick(self)
	SetWaypoint(self.id, self.kind)
end

-- Item icons are square pictures with their own background: cut round, with no frame,
-- they sit on the map like the game's own icons. The mask is clamped to its own size:
-- the SetMask shortcut repeats it, and Forever draws that as stripes
local function Round(owner, texture)
	if not owner.CreateMaskTexture then return end
	local mask = owner:CreateMaskTexture()
	mask:SetAllPoints(texture)
	mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	texture:AddMaskTexture(mask)
end

local function CreatePin(id, size, kind)
	local pin = CreateFrame("Button")
	pin:SetSize(size, size)
	pin:Hide()
	pin.id = id
	pin.kind = kind or "vendor"
	pin.icon = pin:CreateTexture(nil, "ARTWORK")
	pin.icon:SetAllPoints()
	pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	-- A vendor that sells both gets a small bullet in the corner
	pin.badge = pin:CreateTexture(nil, "OVERLAY")
	pin.badge:SetSize(size * 0.6, size * 0.6)
	pin.badge:SetPoint("CENTER", pin, "BOTTOMRIGHT", -1, 1)
	pin.badge:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if pin.kind == "vendor" then
		Round(pin, pin.icon)
		Round(pin, pin.badge)
	end
	pin:SetScript("OnEnter", Pin_OnEnter)
	pin:SetScript("OnLeave", GameTooltip_Hide)
	pin:SetScript("OnClick", Pin_OnClick)
	return pin
end

local function CreateFoodPin(id, size)
	local pin = CreatePin(id, size, "food")
	pin.badge:Hide()
	pin.icon:SetTexture(icons.foodVendors)
	Round(pin, pin.icon)
	return pin
end

local function CreateTrainerPin(id, size)
	local pin = CreatePin(id, size, "trainer")
	pin.badge:Hide()
	pin.icon:SetTexture(HUNTER_ICON)
	pin.icon:SetTexCoord(unpack(HUNTER_COORDS))
	return pin
end

local function StylePin(pin, v)
	local arrows = v.arrows and db.arrows
	local bullets = v.bullets and db.bullets
	pin.icon:SetTexture(arrows and icons.arrows or icons.bullets)
	pin.badge:SetTexture(icons.bullets)
	pin.badge:SetShown(arrows and bullets)
	local outgrown = IsOutgrown(v) and true or false
	pin.icon:SetDesaturated(outgrown)
	pin.badge:SetDesaturated(outgrown)
	pin:SetAlpha(outgrown and 0.55 or 1)
end

local function UpdateFilterPanel(active)
	if not filterPanel then return end
	filterPanel:SetShown(active)
	for _, box in ipairs(filterPanel.boxes) do
		box:SetChecked(db[box.key])
	end
end

local function Refresh()
	HBDPins:RemoveAllWorldMapIcons(addonName)
	HBDPins:RemoveAllMinimapIcons(addonName)
	local active = not (db.onlyHunter and select(2, UnitClass("player")) ~= "HUNTER")
	UpdateFilterPanel(active)
	if not active then return end

	local showFlag = db.continent and HBD_PINS_WORLDMAP_SHOW_CONTINENT or HBD_PINS_WORLDMAP_SHOW_PARENT
	for id, v in pairs(vendors) do
		if IsShown(v) then
			local pin = worldPins[id] or CreatePin(id, 16)
			worldPins[id] = pin
			StylePin(pin, v)
			HBDPins:AddWorldMapIconMap(addonName, pin, v.m, v.x / 100, v.y / 100, showFlag)
			if db.minimap then
				local mini = minimapPins[id] or CreatePin(id, 12)
				minimapPins[id] = mini
				StylePin(mini, v)
				HBDPins:AddMinimapIconMap(addonName, mini, v.m, v.x / 100, v.y / 100, true, false)
			end
		end
	end
	for id, t in pairs(db.trainers and ns.trainers or {}) do
		if OnMySide(t) then
			local pin = trainerWorldPins[id] or CreateTrainerPin(id, 18)
			trainerWorldPins[id] = pin
			HBDPins:AddWorldMapIconMap(addonName, pin, t.m, t.x / 100, t.y / 100, showFlag)
			if db.minimap then
				local mini = trainerMinimapPins[id] or CreateTrainerPin(id, 14)
				trainerMinimapPins[id] = mini
				HBDPins:AddMinimapIconMap(addonName, mini, t.m, t.x / 100, t.y / 100, true, false)
			end
		end
	end
	-- Only the vendors with food the summoned pet eats; with no pet out, none
	foodShown = 0
	local diet, petLevel = ns.PetDiet()
	if not (db.foodVendors and diet) then return end
	for id, v in pairs(ns.foodVendors) do
		if OnMySide(v) and FoodForPet(v, diet, petLevel) then
			foodShown = foodShown + 1
			local pin = foodWorldPins[id] or CreateFoodPin(id, 16)
			foodWorldPins[id] = pin
			HBDPins:AddWorldMapIconMap(addonName, pin, v.m, v.x / 100, v.y / 100, showFlag)
			if db.minimap then
				local mini = foodMinimapPins[id] or CreateFoodPin(id, 12)
				foodMinimapPins[id] = mini
				HBDPins:AddMinimapIconMap(addonName, mini, v.m, v.x / 100, v.y / 100, true, false)
			end
		end
	end
end

-- Checkboxes in the bottom left corner of the world map. In Forever the top left one
-- holds Blizzard's map pin button and the buttons other addons stack under it.
local FILTERS = {
	{ key = "arrows", label = "ARROWS_BOX" },
	{ key = "bullets", label = "BULLETS_BOX" },
	{ key = "trainers", label = "TRAINERS_BOX" },
	{ key = "foodVendors", label = "FOOD_BOX" },
}
local ROW = 18

local function FilterBox_OnClick(self)
	db[self.key] = self:GetChecked() and true or false
	if SOUNDKIT then
		PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	end
	Refresh()
end

-- The map gives its pins (and the map art) absolute frame levels, up to its topmost
-- pin level: the panel goes above all of them
local function RaiseFilterPanel()
	local level = filterPanel:GetParent():GetFrameLevel() + 1000
	local manager = WorldMapFrame.GetPinFrameLevelsManager and WorldMapFrame:GetPinFrameLevelsManager()
	if manager and manager.GetValidFrameLevel then
		local ok, top = pcall(manager.GetValidFrameLevel, manager, "PIN_FRAME_LEVEL_TOPMOST", 1000)
		if ok and type(top) == "number" then
			level = max(level, top + 100)
		end
	end
	filterPanel:SetFrameLevel(min(level, 9000))
end

local function CreateFilterPanel()
	local map = WorldMapFrame and (WorldMapFrame.ScrollContainer or WorldMapFrame)
	if not map then return end
	local panel = CreateFrame("Frame", nil, map)
	panel:SetPoint("BOTTOMLEFT", map, "BOTTOMLEFT", 4, 4)
	-- A map bigger than the screen would leave its bottom rows out of sight
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	local bg = panel:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.6)

	panel.boxes = {}
	local width = 0
	for i, f in ipairs(FILTERS) do
		local box = CreateFrame("CheckButton", nil, panel)
		box:SetSize(ROW + 2, ROW + 2)
		box:SetPoint("TOPLEFT", 2, -1 - (i - 1) * ROW)
		box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
		box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
		box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
		box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
		box.key = f.key
		box:SetScript("OnClick", FilterBox_OnClick)

		local icon = box:CreateTexture(nil, "ARTWORK")
		icon:SetSize(14, 14)
		icon:SetPoint("LEFT", box, "RIGHT", 0, 0)
		if f.key == "trainers" then
			icon:SetTexture(HUNTER_ICON)
			icon:SetTexCoord(unpack(HUNTER_COORDS))
		else
			icon:SetTexture(icons[f.key])
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		local label = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
		label:SetText(L[f.label])
		-- Clicking the icon or the label toggles the box too
		local extra = 14 + 4 + ceil(label:GetStringWidth())
		box:SetHitRectInsets(0, -extra, 0, 0)
		width = max(width, ROW + 2 + extra)
		panel.boxes[i] = box
	end
	panel:SetSize(width + 8, #FILTERS * ROW + 4)
	filterPanel = panel
	RaiseFilterPanel()
	-- Other addons can add pin levels later on
	WorldMapFrame:HookScript("OnShow", RaiseFilterPanel)
end

local function Nearest()
	local px, py, pMap = HBD:GetPlayerZonePosition()
	if not px then return end
	local bestID, bestDist
	for id, v in pairs(vendors) do
		if IsShown(v) and not IsOutgrown(v) then
			local dist = HBD:GetZoneDistance(pMap, px, py, v.m, v.x / 100, v.y / 100)
			if dist and (not bestDist or dist < bestDist) then
				bestID, bestDist = id, dist
			end
		end
	end
	return bestID
end

-- When a merchant opens: if it sells ammo it is recorded (or corrected), and if a
-- listed vendor turns out not to sell any it is removed from the map
local function ScanMerchant()
	local guid = UnitGUID("npc")
	if not guid then return end
	local unitType, _, _, _, _, npcID = strsplit("-", guid)
	npcID = tonumber(npcID)
	if unitType ~= "Creature" or not npcID then return end
	local count = GetMerchantNumItems()
	if not count or count == 0 then return end

	local arrows, bullets, allKnown, levelKnown, best = false, false, true, true, 0
	for i = 1, count do
		local itemID = GetMerchantItemID and GetMerchantItemID(i)
		if not itemID then
			local link = GetMerchantItemLink(i)
			itemID = link and tonumber(link:match("item:(%d+)"))
		end
		if itemID then
			local _, _, _, _, _, classID, subclassID = GetItemInfoInstant(itemID)
			if classID == PROJECTILE_CLASS then
				if subclassID == SUBCLASS_ARROW then
					arrows = true
				elseif subclassID == SUBCLASS_BULLET then
					bullets = true
				end
				local minLevel = select(5, GetItemInfo(itemID))
				if minLevel then
					best = max(best, minLevel)
				else
					levelKnown = false
				end
			end
		else
			allKnown = false
		end
	end

	local old = vendors[npcID]
	local name = UnitName("npc")
	if not arrows and not bullets then
		if old and allKnown then
			db.learned[npcID] = nil
			db.notAmmo[npcID] = true
			RebuildVendors()
			Refresh()
			Print(format(L.NOT_AMMO, name or NpcName(npcID, old)))
		end
		return
	end

	local mapID = C_Map.GetBestMapForUnit("player")
	local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
	if not pos then return end
	local x, y = pos:GetXY()
	if not x or (x == 0 and y == 0) then return end

	local bundled = ns.vendors[npcID]
	local upTo
	if levelKnown then
		for _, tier in ipairs(AMMO_TIERS) do
			if tier > best then
				upTo = tier
				break
			end
		end
	else
		upTo = old and old.upTo
	end
	local entry = {
		m = mapID,
		x = floor(x * 10000 + 0.5) / 100,
		y = floor(y * 10000 + 0.5) / 100,
		side = bundled and bundled.side or SideOf(UnitFactionGroup("npc")),
		arrows = arrows or nil,
		bullets = bullets or nil,
		upTo = upTo,
		name = name,
		learned = true,
	}
	db.learned[npcID] = entry
	db.notAmmo[npcID] = nil

	local changed = not old or old.m ~= entry.m or old.arrows ~= entry.arrows or old.bullets ~= entry.bullets
		or old.upTo ~= entry.upTo or abs(old.x - entry.x) + abs(old.y - entry.y) > 1
	RebuildVendors()
	if changed then
		Refresh()
	end
	if not old then
		local what = arrows and bullets and L.BOTH or arrows and L.ARROWS or L.BULLETS
		Print(format(L.NEW_VENDOR, name or "?", what, ZoneName(mapID), entry.x, entry.y))
	end
end

local function PrintStatus()
	local learned = 0
	for _ in pairs(db.learned) do learned = learned + 1 end
	local ammo = db.arrows and db.bullets and "both" or db.arrows and "arrows" or db.bullets and "bullets" or "none"
	Print(format(L.STATUS,
		L.MODE[ammo],
		db.trainers and L.YES or L.NO,
		db.allFactions and L.ALL_FACTIONS or L.OWN_FACTION,
		db.minimap and L.YES or L.NO,
		db.continent and L.YES or L.NO,
		db.onlyHunter and L.HUNTERS_ONLY or L.ANY_CLASS,
		learned))
end

ns.RefreshMap = function() Refresh() end
table.insert(ns.refreshers, ns.RefreshMap)

local function AmmoCommand(word)
	local ammo = AMMO_WORDS[word]
	if ammo == "weapon" then
		MatchWeapon()
	else
		db.arrows = ammo ~= "bullets"
		db.bullets = ammo ~= "arrows"
	end
	Refresh()
	PrintStatus()
end

local function ToggleCommand(word)
	local key = TOGGLE_WORDS[word]
	db[key] = not db[key]
	Refresh()
	PrintStatus()
end

local function NearestCommand()
	local id = Nearest()
	if id then
		SetWaypoint(id)
	else
		Print(L.NONE_NEAR)
	end
end

for word in pairs(AMMO_WORDS) do ns.commands[word] = AmmoCommand end
for word in pairs(TOGGLE_WORDS) do ns.commands[word] = ToggleCommand end
for word in pairs(NEAREST_WORDS) do ns.commands[word] = NearestCommand end
ns.commands.status = PrintStatus
ns.commands.estado = PrintStatus

function ns.FoodVendorsShown()
	return foodShown
end

-- The pet's details (and with them its diet) arrive a moment after it appears, and
-- the pet bar updates often: one refresh for a burst of events
local refreshQueued = false
local function RefreshSoon()
	if refreshQueued then return end
	refreshQueued = true
	C_Timer.After(0.5, function()
		refreshQueued = false
		Refresh()
	end)
end

local merchantScans = 0
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		db = ns.db
		playerSide = SideOf(UnitFactionGroup("player"))
		icons.arrows = GetItemIconByID(ROUGH_ARROW) or "Interface\\Icons\\INV_Ammo_Arrow_02"
		icons.bullets = GetItemIconByID(LIGHT_SHOT) or "Interface\\Icons\\INV_Ammo_Bullet_02"
		-- Not the minimap's food tracking icon: Forever's client draws it as stripes
		icons.foodVendors = GetItemIconByID(HAUNCH_OF_MEAT) or "Interface\\Icons\\INV_Misc_Food_14"
		RebuildVendors()
		CreateFilterPanel()
		Refresh()
		-- Earlier versions of this addon draw their own pins, which these boxes can't hide
		local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
		for _, old in ipairs(loaded and { "AmmoVendorMap", "VendedoresMunicion" } or {}) do
			if loaded(old) then Print(format(L.OLD_ADDON, old)) end
		end
		self:RegisterEvent("PLAYER_LEVEL_UP")
		self:RegisterEvent("MERCHANT_SHOW")
		self:RegisterUnitEvent("UNIT_PET", "player")
		self:RegisterUnitEvent("UNIT_LEVEL", "pet")
		self:RegisterEvent("PET_BAR_UPDATE")
	elseif event == "PLAYER_LEVEL_UP" then
		-- UnitLevel takes a moment to report the new level
		C_Timer.After(1, Refresh)
	elseif event == "UNIT_PET" or event == "UNIT_LEVEL" or event == "PET_BAR_UPDATE" then
		-- The food vendors depend on the pet you have out
		RefreshSoon()
	elseif event == "MERCHANT_SHOW" then
		-- Two passes: by the second one every item's level is cached
		merchantScans = merchantScans + 1
		local scan = merchantScans
		C_Timer.After(0.3, function() if scan == merchantScans then ScanMerchant() end end)
		C_Timer.After(1.5, function() if scan == merchantScans then ScanMerchant() end end)
	end
end)
