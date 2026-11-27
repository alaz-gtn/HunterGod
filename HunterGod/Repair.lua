local addonName, ns = ...

-- Your gear wearing out and your bags filling up: a reminder when the worst piece you wear is
-- under 25% (you choose the line), or when you have 2 free slots or fewer; and, at a merchant who
-- repairs, a line in the chat with how worn your gear is, or (an option) it repairs everything with your
-- money and says what it cost. Out of combat only.
-- The same file in every ...God addon: each one shows ns.RepairReminders() in its own list and sets
-- ns.RepairChanged to hear when that may have changed
local SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 } -- the ones that wear out
local REPAIR_ICON = "Interface\\Icons\\Trade_BlackSmithing"
local BAG_ICON = "Interface\\Icons\\INV_Misc_Bag_08"

local T = {
	WORN = "Gear at %d%%",
	BAGS = "Bags: %d free",
	BAGS_FULL = "Bags full",
	VENDOR = "This vendor repairs: your gear is at %d%%.",
	REPAIRED = "Repaired for %s.",
	SHORT = "Not enough money to repair: it costs %s.",
	OPT_AUTO = "Repair everything at a merchant who repairs",
}
if GetLocale() == "esES" or GetLocale() == "esMX" then
	T.WORN = "Equipo al %d%%"
	T.BAGS = "Bolsas: %d huecos"
	T.BAGS_FULL = "Bolsas llenas"
	T.VENDOR = "Este vendedor repara: tu equipo está al %d%%."
	T.REPAIRED = "Reparado por %s."
	T.SHORT = "No llevas dinero para reparar: cuesta %s."
	T.OPT_AUTO = "Reparar todo al hablar con un vendedor que repara"
end
ns.REPAIR_TEXT = T

local cache

-- Each addon only does it on its own class: with all of them on, only one pays
local CLASS_OF = { HunterGod = "HUNTER", MageGod = "MAGE", WarriorGod = "WARRIOR", PaladinGod = "PALADIN",
	RogueGod = "ROGUE", PriestGod = "PRIEST", ShamanGod = "SHAMAN", WarlockGod = "WARLOCK", DruidGod = "DRUID" }
local function Mine()
	local _, class = UnitClass("player")
	return class ~= nil and class == CLASS_OF[addonName]
end

-- Money as the game writes it, with its coins
local function Money(copper)
	if GetCoinTextureString then return GetCoinTextureString(copper) end
	return format("%dg %ds %dc", floor(copper / 10000), floor(copper / 100) % 100, copper % 100)
end

local function IsSecret(value)
	return issecretvalue and issecretvalue(value) or false
end

-- The worst piece you wear, in %, or nil when nothing wears out
local function Worst()
	if not GetInventoryItemDurability then return end
	local worst
	for _, slot in ipairs(SLOTS) do
		local now, top = GetInventoryItemDurability(slot)
		if type(now) == "number" and type(top) == "number" and not IsSecret(now) and not IsSecret(top) and top > 0 then
			local pct = floor(now / top * 100 + 0.5)
			if not worst or pct < worst then worst = pct end
		end
	end
	return worst
end
ns.WorstDurability = Worst

-- Free slots in your normal bags (not a quiver, ammo pouch or soul bag)
local function FreeSlots()
	local get = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
	if not get then return end
	local free = 0
	for bag = 0, 4 do
		local n, kind = get(bag)
		if type(n) == "number" and not IsSecret(n) and (kind == nil or kind == 0) then free = free + n end
	end
	return free
end

local function Work()
	local list = {}
	local db = ns.db and ns.db.repair
	if not (db and db.enabled) or (InCombatLockdown and InCombatLockdown()) then return list end
	local worst = Worst()
	if worst and worst < db.low then
		list[#list + 1] = { key = "repair", icon = REPAIR_ICON, text = format(T.WORN, worst) }
	end
	local free = FreeSlots()
	if free and free <= db.bags then
		list[#list + 1] = { key = "bags", icon = BAG_ICON, text = free == 0 and T.BAGS_FULL or format(T.BAGS, free) }
	end
	return list
end

-- What to remind you of: { key, icon, text }
function ns.RepairReminders()
	if not cache then cache = Work() end
	return cache
end

function ns.RefreshRepair()
	cache = nil
	if ns.db and ns.RepairChanged then ns.RepairChanged() end
end

-- Repairs everything when it can: true when it did (or said why not)
local function AutoRepair()
	if not (CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost and RepairAllItems) then return end
	local cost, needed = GetRepairAllCost()
	if IsSecret(cost) or type(cost) ~= "number" or cost <= 0 or needed == false then return end
	local money = GetMoney and GetMoney()
	if type(money) == "number" and not IsSecret(money) and money < cost then
		if ns.Print then ns.Print(format(T.SHORT, Money(cost))) end
		return true
	end
	RepairAllItems()
	if ns.Print then ns.Print(format(T.REPAIRED, Money(cost))) end
	return true
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "UPDATE_INVENTORY_DURABILITY", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED",
	"PLAYER_REGEN_DISABLED", "MERCHANT_SHOW" }) do
	pcall(events.RegisterEvent, events, event) -- an event the game doesn't have would stop the file
end
events:SetScript("OnEvent", function(_, event)
	if event == "MERCHANT_SHOW" then
		local db = ns.db and ns.db.repair
		local worst = Worst()
		if db and db.auto and Mine() and AutoRepair() then return end
		if db and db.enabled and worst and worst < 100 and CanMerchantRepair and CanMerchantRepair() and ns.Print then
			ns.Print(format(T.VENDOR, worst))
		end
		return
	end
	ns.RefreshRepair()
end)
