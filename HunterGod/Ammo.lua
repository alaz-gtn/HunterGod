local _, ns = ...
local L = ns.L

local AMMO_SLOT = INVSLOT_AMMO or 0
local RANGED_SLOT = INVSLOT_RANGED or 18
local PROJECTILE_CLASS = Enum.ItemClass and Enum.ItemClass.Projectile or 6
local SUBCLASS_ARROW, SUBCLASS_BULLET = 2, 3
local WEAPON_CLASS = Enum.ItemClass and Enum.ItemClass.Weapon or 2
-- Bows and crossbows shoot arrows, guns shoot bullets
local WEAPON_AMMO = { [2] = SUBCLASS_ARROW, [18] = SUBCLASS_ARROW, [3] = SUBCLASS_BULLET }

local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
local GetItemIconByID = C_Item and C_Item.GetItemIconByID or GetItemIcon

local db, frame
local warned = false

-- The kind of ammo the ranged weapon needs (arrow or bullet subclass), or nil
local function WeaponAmmo()
	local id = GetInventoryItemID("player", RANGED_SLOT)
	if not id then return end
	local classID, subclassID = select(6, GetItemInfoInstant(id))
	return classID == WEAPON_CLASS and WEAPON_AMMO[subclassID] or nil
end

-- How much of the equipped ammo is in your bags: count, item ID (nil when none is equipped)
function ns.AmmoCount()
	local id = GetInventoryItemID("player", AMMO_SLOT)
	if not id then return 0 end
	return GetInventoryItemCount("player", AMMO_SLOT) or 0, id
end

local function AmmoWord(subclass)
	return subclass == SUBCLASS_BULLET and L.BULLETS or L.ARROWS
end

function ns.UpdateAmmo()
	if not db.enabled or not ns.IsHunter() then
		frame:Hide()
		return
	end
	local needs = WeaponAmmo()
	local count, id = ns.AmmoCount()
	if ns.unlocked then
		needs, count = needs or SUBCLASS_ARROW, min(count, db.threshold - 1)
	end
	if not needs or count >= db.threshold then
		frame:Hide()
		warned = false
		return
	end
	frame.icon:SetTexture(id and GetItemIconByID(id) or "Interface\\Icons\\INV_Ammo_Arrow_02")
	frame.icon:SetDesaturated(count == 0)
	frame.text:SetText(count == 0 and L.NO_AMMO or count)
	if count < db.threshold / 4 then
		frame.text:SetTextColor(1, 0.2, 0.2)
	else
		frame.text:SetTextColor(1, 0.6, 0.1)
	end
	frame:Show()
	if not warned and not ns.unlocked then
		warned = true
		ns.Print(format(L.AMMO_LOW, count, AmmoWord(needs)))
	end
end

-- At a vendor: say so if they sell the ammo you are running out of
local function CheckMerchant()
	if not db.enabled or not db.merchant or not ns.IsHunter() then return end
	local needs = WeaponAmmo()
	local count = ns.AmmoCount()
	if not needs or count >= db.threshold then return end
	for i = 1, GetMerchantNumItems() do
		local itemID = GetMerchantItemID and GetMerchantItemID(i)
		if itemID then
			local classID, subclassID = select(6, GetItemInfoInstant(itemID))
			if classID == PROJECTILE_CLASS and subclassID == needs then
				ns.Print(format(L.AMMO_MERCHANT, AmmoWord(needs), count))
				return
			end
		end
	end
end

frame = CreateFrame("Frame", "HunterGodAmmo", UIParent)
frame:SetSize(36, 36)
frame:Hide()
local border = frame:CreateTexture(nil, "BORDER")
border:SetPoint("TOPLEFT", -1, 1)
border:SetPoint("BOTTOMRIGHT", 1, -1)
border:SetColorTexture(0, 0, 0, 0.9)
frame.icon = frame:CreateTexture(nil, "ARTWORK")
frame.icon:SetAllPoints()
frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
frame.text = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
frame.text:SetPoint("TOP", frame, "BOTTOM", 0, -3)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		db = ns.db.lowAmmo
		ns.Movable(frame, "ammo", { "CENTER", "CENTER", -160, -60 }, L.TAB_AMMO)
		table.insert(ns.refreshers, ns.UpdateAmmo)
		self:RegisterEvent("BAG_UPDATE_DELAYED")
		self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
		self:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
		self:RegisterEvent("MERCHANT_SHOW")
		ns.UpdateAmmo()
	elseif event == "MERCHANT_SHOW" then
		C_Timer.After(0.5, CheckMerchant)
	else
		ns.UpdateAmmo()
	end
end)
