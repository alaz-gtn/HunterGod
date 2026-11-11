"""Loads the addon against a mocked WoW API (LuaJIT = Lua 5.1) and checks its behaviour.

Usage: python -I test_addon.py <HunterGod folder> [enUS|esES]
Needs: pip install lupa
"""
import re
import sys
from pathlib import Path

from lupa.luajit21 import LuaRuntime

ADDON = Path(sys.argv[1])
LOCALE = sys.argv[2] if len(sys.argv) > 2 else "enUS"
lua = LuaRuntime(unpack_returned_tuples=True)

printed = []
lua.globals().py_print = lambda *a: printed.append(" ".join(str(x) for x in a))
lua.globals().LOCALE = LOCALE

lua.execute(r'''
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring((select(i, ...))) end py_print(table.concat(t, " ")) end
format = string.format; strlower = string.lower; max = math.max; min = math.min; abs = math.abs; floor = math.floor; ceil = math.ceil
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strsplit = function(sep, s) local out = {} for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%-", "%%-")) do out[#out+1] = part end return unpack(out) end
GetLocale = function() return LOCALE end
-- A value the game hides from addons
SECRET = {}
issecretvalue = function(v) return v == SECRET end

local mapNames = { [1411] = "Durotar", [1454] = "Orgrimmar", [2548] = "Riverglades", [1429] = "Elwynn Forest" }
SPELLS = { [75] = "Auto Shot", [2973] = "Raptor Strike", [2974] = "Wing Clip", [6991] = "Feed Pet",
  [13165] = "Aspect of the Hawk", [25296] = "Aspect of the Hawk", [13163] = "Aspect of the Monkey",
  [5118] = "Aspect of the Cheetah", [13159] = "Aspect of the Pack", [13161] = "Aspect of the Beast", [20043] = "Aspect of the Wild",
  [2649] = "Growl", [14921] = "Growl", [430] = "Drink", [433] = "Food", [19574] = "Bestial Wrath",
  [1499] = "Freezing Trap", [14311] = "Freezing Trap", [13795] = "Immolation Trap", [13809] = "Frost Trap", [13813] = "Explosive Trap" }

-- Game state the tests change
G = { class = "HUNTER", faction = "Horde", level = 30, ranged = nil, npcGUID = nil, npcName = nil, npcFaction = nil,
      merchant = {}, playerMap = 1411, px = 0.5, py = 0.5, timers = {}, waypoint = nil,
      combat = false, target = nil, dist = 27, secretRange = false, uncached = {}, lying = {}, reach = 35, plate = nil, known = { [13165] = true, [13163] = true, [5118] = true },
      auras = {}, secret = false, ammoID = nil, ammoCount = 0, pet = nil, bags = {}, cursor = { 0, 100 },
      petActions = {}, instance = nil, group = false, now = 100, speed = {} }

UnitClass = function() return "Hunter", G.class end
UnitFactionGroup = function(u) if u == "npc" then return G.npcFaction end return G.faction end
UnitLevel = function(u) if u == "pet" then return G.pet and G.pet.level end return G.level end
UnitGUID = function() return G.npcGUID end
UnitName = function(u) if u == "pet" then return G.pet and G.pet.name end return G.npcName end
GetPetTrainingPoints = function() if G.pet and G.pet.tp then return G.pet.tp, G.pet.spent or 0 end end
SetPortraitTexture = function() end
GetPetHappiness = function() if G.pet then return G.pet.happy or 3 end end
UnitHealth = function(u) if u == "pet" and G.pet then return G.pet.hp or 100 end return 100 end
UnitHealthMax = function(u) if u == "pet" and G.pet then return G.pet.maxhp or 100 end return 100 end
UnitIsUnit = function(a, b) if a == "pettargettarget" and b == "pet" then return G.mobOnPet end return false end
UnitExists = function(u) if u == "target" then return G.target ~= nil end if u == "pet" then return G.pet ~= nil end
  if u == "pettarget" then return G.petTarget end return true end
CustomAuraContainerAuraProcessingPolicy = { None = 0 }
UnitCanAttack = function() return G.target and G.target.hostile end
UnitIsDead = function() return false end
UnitAffectingCombat = function() return G.combat end
InCombatLockdown = function() return G.combat end
CheckInteractDistance = function(_, i) if G.secretRange then return SECRET end return G.dist <= (i == 3 and 8 or 28) end
UnitRace = function() return "Orc", "Orc" end
GetTime = function() return G.now end
-- An old version of the addon still installed next to this one
C_AddOns = { IsAddOnLoaded = function(name) return name == "AmmoVendorMap" end }
GetUnitSpeed = function(u) return G.speed[u] or 0 end
IsPlayerSpell = function(id) return G.known[id] or false end
HasPetUI = function() return G.pet ~= nil, G.pet ~= nil end
UnitCreatureFamily = function() if G.pet then return G.pet.familyName, G.pet.familyID end end
GetPetActionInfo = function(i) local a = G.petActions[i] if a then return unpack(a, 1, 7) end end
IsInInstance = function() return G.instance ~= nil, G.instance or "none" end
IsInGroup = function() return G.group end
-- Your threat on the target: tanking, status, % of what pulls aggro
UnitDetailedThreatSituation = function(a, b) if G.threat then return G.threat[1], G.threat[2], G.threat[3] end end
NUM_PET_ACTION_SLOTS = 10
-- Forever gives the summoned pet's diet through the stable API (slot 0)
C_StableInfo = { GetStablePetFoodTypes = function(i) if G.pet and i == 0 then return G.pet.diet end end }
INVSLOT_AMMO, INVSLOT_RANGED, NUM_BAG_SLOTS = 0, 18, 4
GetInventoryItemID = function(_, slot) if slot == 18 then return G.ranged end if slot == 0 then return G.ammoID end end
GetInventoryItemCount = function(_, slot) if slot == 0 and G.ammoID then return G.ammoCount end return 0 end
GetMerchantNumItems = function() return #G.merchant end
GetMerchantItemID = function(i) return G.merchant[i] end
GetMerchantItemLink = function(i) return "[item " .. G.merchant[i] .. "]" end

-- Items: class, subclass, required level
local items = {
  [2512] = {6, 2, 1}, [2515] = {6, 2, 10}, [3030] = {6, 2, 25}, [11285] = {6, 2, 40},
  [2516] = {6, 3, 1}, [2519] = {6, 3, 10}, [3033] = {6, 3, 25}, [11284] = {6, 3, 40},
  [159] = {0, 5, 1}, [4540] = {0, 5, 5}, [99999] = {0, 5, 1},  -- water, bread and a food the addon has no record of
  [2504] = {2, 2, 1}, [2508] = {2, 3, 1},         -- bow and gun
}
Enum = { ItemClass = { Projectile = 6, Weapon = 2 } }
C_Item = {
  GetItemInfoInstant = function(id) local it = items[id] if it then return id, "t", "s", "", 0, it[1], it[2] end return id, "t", "s", "", 0, 0, 0 end,
  GetItemInfo = function(id) local it = items[id] if it then return "item" .. id, "[item " .. id .. "]", 1, 1, it[3], "", "", 20, "", 0, 0, it[1], it[2] end if ITEM_YARDS[id] then return "range item" end end,
  IsItemDataCachedByID = function(id) return not G.uncached[id] end,
  -- What using an item casts: water drinks, the unknown food eats
  GetItemSpell = function(id) if id == 159 then return "Drink", 430 end if id == 99999 then return "Food", 433 end end,
  GetItemIconByID = function(id) return id * 10 end,
  IsItemInRange = function(id)
    if G.secretRange then return SECRET end
    if G.uncached[id] or not ITEM_YARDS[id] then return nil end
    if G.lying[ITEM_YARDS[id]] then return true end -- an item that answers wrong
    return G.dist <= ITEM_YARDS[id]
  end,
  RequestLoadItemDataByID = function() end,
}
ITEM_YARDS = {}
function BuildItemYards(ns) for _, step in ipairs(ns.RANGE_ITEMS) do for _, id in ipairs(step[2]) do ITEM_YARDS[id] = step[1] end end end
function Uncache(ns, yards) for _, step in ipairs(ns.RANGE_ITEMS) do if step[1] == yards then for _, id in ipairs(step[2]) do G.uncached[id] = true end end end end
C_Spell = {
  IsSpellInRange = function(spell)
    if G.secretRange then return SECRET end
    if spell == "Auto Shot" then return G.dist >= 8 and G.dist <= G.reach end
    if spell == "Raptor Strike" or spell == "Wing Clip" then return G.meleeLies or G.dist <= 5 end
  end,
  GetSpellInfo = function(spell) if spell == "Auto Shot" then return { name = spell, minRange = 8, maxRange = G.reach } end end,
  GetSpellName = function(id) return SPELLS[id] end,
  GetSpellTexture = function(id) return id end,
  GetSpellCooldown = function(id)
    if G.secretCooldown then return { startTime = SECRET, duration = SECRET } end
    if SPELLS[id] and SPELLS[id]:find("Trap") then return { startTime = G.now, duration = 15 } end
    return { startTime = 0, duration = 0 }
  end,
}
C_UnitAuras = { GetAuraDataByIndex = function(_, i) local name = G.auras[i] if name then return { name = name } end end,
  GetAuraDataBySpellName = function() return G.wrathAura end }
C_Secrets = { ShouldAurasBeSecret = function() return G.secret end }
C_NamePlate = { GetNamePlateForUnit = function() return G.plate end }
C_Container = {
  GetContainerNumSlots = function(bag) return G.bags[bag] and #G.bags[bag] or 0 end,
  GetContainerItemInfo = function(bag, slot) local it = G.bags[bag] and G.bags[bag][slot] if it then return { itemID = it[1], stackCount = it[2] } end end,
}
C_Map = {
  GetMapInfo = function(m) return mapNames[m] and { name = mapNames[m] } end,
  GetBestMapForUnit = function() return G.playerMap end,
  GetPlayerMapPosition = function() return { GetXY = function() return G.px, G.py end } end,
  CanSetUserWaypointOnMap = function() return true end,
  SetUserWaypoint = function(p) G.waypoint = p end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m = m, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
-- The game knows Spanish names for a couple of NPCs
C_TooltipInfo = { GetHyperlink = function(link)
  local id = tonumber(link:match("Creature%-0%-0%-0%-0%-(%d+)"))
  local es = { [3313] = "Trak'gen (es)" }
  if es[id] then return { lines = { { leftText = es[id] } } } end
end }
C_Timer = { After = function(t, f) table.insert(G.timers, f) G.lastDelay = t end, NewTicker = function() return { Cancel = function() end } end }
function RunTimers() local t = G.timers G.timers = {} for _, f in ipairs(t) do f() end end
GetCursorPosition = function() return G.cursor[1], G.cursor[2] end

-- Frames and textures: the methods the tests look at keep their state, the rest do nothing
local function Texture() local t = { shown = true } setmetatable(t, { __index = function(_, k) return function(self, ...)
  if k == "SetShown" then self.shown = (...) and true or false
  elseif k == "Hide" then self.shown = false elseif k == "Show" then self.shown = true
  elseif k == "IsShown" then return self.shown
  elseif k == "SetTexture" then self.tex = ... elseif k == "SetDesaturated" then self.desat = ...
  elseif k == "SetColorTexture" or k == "SetTextColor" then self.color = { ... }
  elseif k == "SetText" then self.text = ... elseif k == "GetStringWidth" then return #tostring(self.text or "") * 6
  elseif k == "SetFont" then self.font = { ... }
  elseif k == "GetText" then return self.text
  elseif k == "AddMaskTexture" then self.maskTexture = ...
  elseif k == "CreateAnimationGroup" then return CreateFrame("Frame") end
end end }) return t end
NAMED = {}
function CreateFrame(kind, name, parent, template)
  local f = { scripts = {}, events = {}, kind = kind, parent = parent, template = template, shown = true, attrs = {}, width = 100 }
  -- Unknown methods (capitalized) do nothing; unknown fields stay nil
  setmetatable(f, { __index = function(_, k)
    if k:match("^Create") then return function() return CreateFrame("Frame") end end
    if k:match("^%u") then return function() end end
  end })
  function f:SetScript(n, fn) self.scripts[n] = fn end
  function f:GetScript(n) return self.scripts[n] end
  function f:RegisterEvent(e) self.events[e] = true end
  function f:RegisterUnitEvent(e) self.events[e] = true end
  function f:UnregisterEvent(e) self.events[e] = nil end
  function f:CreateTexture() return Texture() end
  function f:CreateFontString() return Texture() end
  function f:SetAlpha(a) self.alpha = a end
  function f:SetShown(v) self.shown = v and true or false end
  function f:Hide() self.shown = false end function f:Show() self.shown = true end
  function f:IsShown() return self.shown end
  function f:IsVisible() return self.shown end
  function f:SetChecked(v) self.checked = v and true or false end
  function f:GetChecked() return self.checked end
  function f:GetFrameLevel() return 1 end
  function f:SetFrameLevel(l) self.level = l end
  function f:GetParent() return self.parent end
  function f:HookScript(n, fn) self.hooks = self.hooks or {} self.hooks[n] = fn end
  function f:SetPoint(...) self.point = { ... } end
  function f:GetPoint() local p = self.point return p[1], p[2], p[3], p[4], p[5] end
  function f:SetSize(w, h) self.width, self.height = w, h end
  function f:SetWidth(w) self.width = w end
  function f:GetWidth() return self.width end
  function f:GetCenter() return 0, 0 end
  function f:GetEffectiveScale() return 1 end
  function f:SetText(t) self.text = t end
  function f:GetText() return self.text end
  function f:SetAttribute(k, v) self.attrs[k] = v end
  function f:SetValue(v) self.value = v end
  function f:EnableMouse(on) self.mouse = on end
  function f:SetClampedToScreen(on) self.clamped = on end
  function f:SetParent(p) self.parent = p end
  function f:SetTexture(...) self.texArgs = { ... } end
  if kind == "AuraContainer" then
    function f:AddAuraSlot(key, filter, opts) self.slot = { key = key, filter = filter, opts = opts } end
    function f:SetUnit(u) self.unit = u end
    function f:SetEnabled(on) self.enabled = on end
    function f:UpdateAllAuras() self.updates = (self.updates or 0) + 1 end
  end
  FRAMES = FRAMES or {} table.insert(FRAMES, f)
  if name then NAMED[name] = f end
  return f
end
UIParent = CreateFrame("Frame")
PetFrame = CreateFrame("Frame")
PetPortrait = CreateFrame("Frame")
Minimap = CreateFrame("Frame")
Minimap.width = 140
GameFontNormal = { GetFont = function() return "font" end }
BackdropTemplateMixin = {}
UISpecialFrames = {}
ColorPickerFrame = { SetupColorPickerAndShow = function(self, info) COLOR_INFO = info end, GetColorRGB = function() return 0, 0, 1 end }
WorldMapFrame = CreateFrame("Frame")
WorldMapFrame.ScrollContainer = CreateFrame("Frame")
-- Like Forever's map: pin levels go up to about 2000
WorldMapFrame.GetPinFrameLevelsManager = function() return { GetValidFrameLevel = function(_, t, i) if t == "PIN_FRAME_LEVEL_TOPMOST" then return 1000 + i end end } end
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 1, IG_MAINMENU_OPTION_CHECKBOX_OFF = 2 }
SOUNDS = {}
PlaySound = function(id) table.insert(SOUNDS, id) end
-- The checkboxes on the world map: the panel is the frame parented to the map
function Panel() for _, f in ipairs(FRAMES) do if f.parent == WorldMapFrame.ScrollContainer then return f end end end
function Box(key) for _, b in ipairs(Panel().boxes) do if b.key == key then return b end end end
function Click(key) local b = Box(key) b.checked = not b.checked b.scripts.OnClick(b) end
TOOLTIP = {}
GameTooltip = { SetOwner = function() TOOLTIP = {} end, AddLine = function(_, s) table.insert(TOOLTIP, s) end, Show = function() end, SetBagItem = function() end }
GameTooltip_Hide = function() end
SlashCmdList = {}

-- Mocked HereBeDragons: records the pins per map
HBD_PINS_WORLDMAP_SHOW_PARENT, HBD_PINS_WORLDMAP_SHOW_CONTINENT = 1, 2
WORLD, MINI = {}, {}
local pins = {
  RemoveAllWorldMapIcons = function() WORLD = {} end,
  RemoveAllMinimapIcons = function() MINI = {} end,
  AddWorldMapIconMap = function(_, ref, icon, m, x, y, flag)
    assert(type(m) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1, "coords out of range")
    WORLD[icon] = { m = m, x = x, y = y, flag = flag } return true end,
  AddMinimapIconMap = function(_, ref, icon, m, x, y) MINI[icon] = { m = m } return true end,
}
local hbd = {
  GetPlayerZonePosition = function() return G.px, G.py, G.playerMap end,
  GetZoneDistance = function(_, m1, x1, y1, m2, x2, y2) if m1 ~= m2 then return nil end return math.sqrt((x1-x2)^2 + (y1-y2)^2) * 1000 end,
}
LibStub = function(name) if name == "HereBeDragons-2.0" then return hbd end return pins end

function CountWorld() local n, maps = 0, {} for icon, d in pairs(WORLD) do n = n + 1 maps[d.m] = (maps[d.m] or 0) + 1 end return n, maps end
function CountMini() local n = 0 for _ in pairs(MINI) do n = n + 1 end return n end
function FindPin(id, kind) for icon in pairs(WORLD) do if icon.id == id and icon.kind == (kind or "vendor") then return icon end end end
-- Python proxies of the same Lua table are not equal: compare in Lua
function Same(a, b) return rawequal(a, b) end
function Fire(event, ...) for _, f in ipairs(FRAMES) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end end end
''')

load = lua.eval('function(src, name) return assert(loadstring(src, "@" .. name)) end')
ns = lua.table()
toc = Path(ADDON, "HunterGod.toc").read_text(encoding="utf-8")
for fname in re.findall(r"^(\w+\.lua)$", toc, re.M):
    load(Path(ADDON, fname).read_text(encoding="utf-8"), fname)("HunterGod", ns)

G = lua.globals()
S = G.G  # the game state
G.BuildItemYards(ns)
L = ns.L
es = LOCALE in ("esES", "esMX")
fails = []


def check(cond, msg):
    print(("OK   " if cond else "FAIL ") + msg)
    if not cond:
        fails.append(msg)


def slash(arg):
    printed.clear()
    G.SlashCmdList.HUNTERGOD(arg)
    return list(printed)


def pin_ids(kind):
    return {icon.id for icon in G.WORLD.keys() if icon.kind == kind}


def vendor_ids():
    return pin_ids("vendor")


def trainer_ids():
    return pin_ids("trainer")


def tooltip(npc_id, kind="vendor"):
    pin = G.FindPin(npc_id, kind)
    pin.scripts.OnEnter(pin)
    return list(G.TOOLTIP.values())


def boxes():
    return {key: bool(G.Box(key).checked) for key in ("arrows", "bullets", "trainers")}


def bags(*slots):
    """bags((itemID, count), ...) puts the stacks in the backpack"""
    S.bags = lua.table_from({0: lua.table_from([lua.table(i, c) for i, c in slots])}) if slots else lua.table()


data = ns.vendors
n_static = len(list(data.keys()))
check(n_static > 100, f"Data.lua: {n_static} vendors")
check(all(v.m and 0 <= v.x <= 100 and 0 <= v.y <= 100 and v.side in ("A", "H", "B") and (v.arrows or v.bullets) and v.name
          for v in data.values()), "every vendor has map, coordinates, side, ammo type and name")
trainers = ns.trainers
n_trainers = len(list(trainers.keys()))
check(n_trainers > 20 and all(t.m and 0 <= t.x <= 100 and 0 <= t.y <= 100 and t.side in ("A", "H") and t.name
                              for t in trainers.values()), f"Data.lua: {n_trainers} hunter trainers with map, coordinates, side and name")
foods = ns.petFoods
check(len(list(foods.keys())) > 150 and all(1 <= f.t <= 6 and f.l >= 0 for f in foods.values()),
      f"PetFood.lua: {len(list(foods.keys()))} foods with type and level")

# Login: level 30 Horde hunter
S.ammoID, S.ammoCount = 2515, 5000
printed.clear()
G.Fire("ADDON_LOADED", "HunterGod")
G.Fire("PLAYER_LOGIN")
check(sum("AmmoVendorMap" in p for p in printed) == 1, f"warns once that the old AmmoVendorMap is also installed: {printed}")
db = G.HunterGodDB
n, maps = G.CountWorld()
sides = {data[i].side for i in vendor_ids()}
check(n > 0 and "A" not in sides, f"Horde: {n} world map pins, none Alliance-only")
check(G.CountMini() == n, "same pins on the minimap")
check(all(d.flag == 2 for d in G.WORLD.values()), "pins also on the continent map")
some = next(icon for icon in G.WORLD.keys() if icon.kind == "vendor")
check(some.icon.maskTexture is not None and some.border is None
      and list(some.icon.maskTexture.texArgs.values())
      == ["Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"],
      "vendor pins: round with a clamped mask (no stripes), with no black square behind")
tsides = {trainers[i].side for i in trainer_ids()}
check(len(trainer_ids()) > 5 and tsides == {"H"}, f"Horde: {len(trainer_ids())} hunter trainer pins, all Horde")
tip = tooltip(3171, "trainer")  # Thotar, Durotar
print("     trainer tooltip:", tip)
check(tip[0] == "Thotar" and tip[1] == ("Instructor de cazadores" if es else "Hunter trainer"), "trainer tooltip shows name and role")
G.FindPin(3171, "trainer").scripts.OnClick(G.FindPin(3171, "trainer"))
check(S.waypoint is not None and S.waypoint.m == 1411, "clicking a trainer pin sets a waypoint")
S.waypoint = None

# Checkboxes on the world map
panel = G.Panel()
check(panel is not None and panel.shown and boxes() == {"arrows": True, "bullets": True, "trainers": True},
      "map checkboxes shown, all ticked")
check([b.key for b in panel.boxes.values()] == ["arrows", "bullets", "trainers", "foodVendors"],
      "boxes in order: arrows, bullets, trainers, pet food")
check(len(pin_ids("food")) == 0, "no pet out: no pet food vendors")
check(panel.clamped and panel.level == 2100 and G.WorldMapFrame.hooks["OnShow"] is not None, f"panel above the topmost map pin level: {panel.level}")
G.Click("arrows")
check(not db.arrows and all(data[i].bullets for i in vendor_ids()) and len(trainer_ids()) > 0,
      "unticking arrows: only bullet vendors, trainers stay")
G.Click("trainers")
check(len(trainer_ids()) == 0 and G.CountMini() == len(vendor_ids()), "unticking trainers removes them from both maps")
G.Click("bullets")
check(G.CountWorld()[0] == 0, "nothing ticked: no pins")
out = slash("estado" if es else "status")
check(("ninguna munición" if es else "no ammo") in out[0], f"status with nothing ticked: {out[0]}")
G.Click("arrows"); G.Click("bullets"); G.Click("trainers")
check(boxes() == {"arrows": True, "bullets": True, "trainers": True} and len(trainer_ids()) > 0, "ticking everything back")
slash("instructores" if es else "trainers")
check(not G.Box("trainers").checked and len(trainer_ids()) == 0, "trainers command unticks the box")
slash("trainers")
check(G.Box("trainers").checked, "and ticks it again")

# Low level vendor tooltip (Durotar, useful up to 10)
low = next(i for i in vendor_ids() if data[i].m == 1411 and data[i].upTo == 10)
tip = tooltip(low)
print("     tooltip:", tip)
sells = "Vende" if es else "Sells"
check(tip[0] == data[low].name and tip[1].startswith(sells) and any("10" in t for t in tip), "tooltip shows name, what it sells and level")
check(G.FindPin(low).alpha < 1 and G.FindPin(low).icon.desat, "outgrown vendor is greyed out")
top = next(i for i in vendor_ids() if data[i].m == 1454 and not data[i].upTo)
check(G.FindPin(top).alpha == 1, "Orgrimmar vendor without cap is shown normally")

# Names: English client uses the bundled one, Spanish asks the game
name = tooltip(3313)[0]
check(name == ("Trak'gen (es)" if es else "Trak'gen"), f"Trak'gen name in {LOCALE}: {name}")

# Ammo filters, with English and Spanish words
slash("balas" if es else "bullets")
check(all(data[i].bullets for i in vendor_ids()), "bullets only")
check(boxes()["bullets"] and not boxes()["arrows"], "bullets command updates the boxes")
S.ranged = 2504  # bow
slash("weapon")
check(all(data[i].arrows for i in vendor_ids()) and boxes()["arrows"] and not boxes()["bullets"], "weapon with a bow: arrows box only")
S.ranged = 2508
slash("arma")
check(all(data[i].bullets for i in vendor_ids()) and boxes()["bullets"] and not boxes()["arrows"], "weapon with a gun: bullets box only")
slash("ambas")
slash("faction")
check("A" in {data[i].side for i in vendor_ids()}, "faction toggle: Alliance vendors appear")
slash("faccion")
slash("minimapa" if es else "minimap")
check(G.CountMini() == 0, "minimap toggle removes minimap pins")
out = slash("minimap")
check(any(("minimapa sí" if es else "minimap on") in o for o in out), f"status line in {LOCALE}: {out[0]}")

# Nearest: none useful at 30 in Durotar, one at level 5
out = slash("nearest")
check(S.waypoint is None and len(out) == 1, f"nearest at level 30 in Durotar: {out}")
S.level = 5
G.Fire("PLAYER_LEVEL_UP", 5)
G.RunTimers()
out = slash("cerca")
check(S.waypoint is not None and S.waypoint.m == 1411, f"nearest at level 5: {out}")
S.level = 30

# Recording a new vendor: Fizzix Boomshot in Riverglades sells level 10 arrows and bullets
S.npcGUID = "Creature-0-1-2-3-260566-0000ABCD"
S.npcName = "Fizzix Boomshot"
S.playerMap, S.px, S.py = 2548, 0.7855, 0.5355
S.merchant = lua.table(159, 2512, 2515, 2516, 2519)
printed.clear()
G.Fire("MERCHANT_SHOW")
G.RunTimers()
learned = db.learned[260566]
check(learned is not None and learned.arrows and learned.bullets and learned.upTo == 25 and learned.m == 2548,
      f"records Fizzix: {dict(learned) if learned else None}")
check(len(printed) == 1 and "Fizzix" in printed[0], f"announces it once: {printed}")
check(260566 in vendor_ids(), "Fizzix now on the map")

# A listed vendor that turns out not to sell ammo is removed
S.npcGUID = f"Creature-0-1-2-3-{low}-0000ABCD"
S.npcName = "Someone"
S.playerMap = 1411
S.merchant = lua.table(159, 4540)
printed.clear()
G.Fire("MERCHANT_SHOW")
G.RunTimers()
check(low not in vendor_ids() and db.notAmmo[low], f"vendor without ammo removed: {printed}")

# ---------------------------------------------------------------- Range
rng = G.NAMED["HunterGodRange"]
S.target = lua.table(hostile=True)
yd = L.YARDS


def range_at(dist):
    S.dist = dist
    ns.UpdateRange()
    return f"{rng.text.text} {rng.unit.text}" if rng.shown else None


def number_at(dist):
    S.dist = dist
    ns.UpdateRange()
    return rng.text.text if rng.shown else None


db.range.display = "bracket"


def colour():
    return tuple(round(c, 2) for c in rng.text.color.values())


check(range_at(27) == f"25-28 {yd}" and colour()[:2] == (0.3, 1), f"27 yd: in range, green: {rng.text.text}")
check(range_at(32) == f"30-35 {yd}", f"32 yd: {rng.text.text}")
check(range_at(9) == f"8-10 {yd}", f"9 yd: Auto Shot reaches from 8: {rng.text.text}")
check(range_at(3) == f"0-5 {yd}" and colour()[:2] == (1, 0.82), f"3 yd: melee, yellow: {rng.text.text}")
check(range_at(6) == f"5-8 {yd}" and colour()[:2] == (1, 0.2), f"6 yd: dead zone, red: {rng.text.text}")
check(range_at(38) == f"35-40 {yd}" and colour()[:2] == (0.6, 0.6), f"38 yd: out of range, grey: {rng.text.text}")
check(range_at(150) == f"100+ {yd}", f"150 yd: {rng.text.text}")
db.range.units = "meters"
check(range_at(27) == f"23-26 {L.METERS}", f"in metres: {rng.text.text}")
db.range.units = "yards"
db.range.showState = True
check(range_at(27) == f"25-28 {yd}" and rng.state.text == L.RANGE.ranged, f"with the state too: {rng.state.text}")
db.range.showState = False
G.Uncache(ns, 25)
G.Uncache(ns, 30)
check(range_at(27) == f"20-28 {yd}", f"items not loaded: those steps are skipped: {rng.text.text}")
S.uncached = lua.table()
S.lying[5] = True
check(range_at(32) == f"30-35 {yd}" and colour()[:2] == (0.3, 1),
      f"an item that wrongly says 'within 5 yd' can't contradict Auto Shot: {rng.text.text}")
S.lying = lua.table()
S.reach = 41
check(range_at(38) == f"35-40 {yd}" and colour()[:2] == (0.3, 1), f"Hawk Eye: 38 yd is still in range: {rng.text.text}")
S.reach = 35
out = slash("rango" if es else "range")
print("     range report:", out)
check(len(out) == 2 and L.RANGE.out in out[0] and "28:" in out[1], "range command: state, yards and each step")
S.secretRange = True
check(range_at(27) is None, "hidden values in combat: nothing shown")
S.secretRange = False
S.target = None
check(range_at(27) is None, "no target: nothing shown")
S.target = lua.table(hostile=False)
check(range_at(27) is None, "friendly target: nothing shown")
S.target = lua.table(hostile=True)
S.plate = G.CreateFrame("Frame")
range_at(27)
check(G.Same(rng.point[2], S.plate) and rng.point[1] == "BOTTOM", "sits above the target's nameplate")
S.plate = None
range_at(27)
check(G.Same(rng.point[2], G.UIParent), "no nameplate: where you put it")
db.range.style = "icon"
ns.StyleRange()
range_at(27)
check(not rng.text.shown and rng.icon.shown and tuple(rng.icon.color.values())[:2] == (0.3, 1), "icon style: a coloured square")
db.range.style = "text"
ns.StyleRange()
db.range.onlyCombat = True
check(range_at(27) is None, "only in combat: hidden out of combat")
S.combat = True
check(range_at(27) == f"25-28 {yd}", "only in combat: shown in combat")
S.combat = False
db.range.onlyCombat = False

# The blinking MELEE RANGE warning
melee = G.NAMED["HunterGodMelee"]
range_at(3)
check(melee.shown and melee.text.text == L.MELEE_WARNING and abs(melee.alpha - 0.5) < 0.01
      and tuple(round(c, 2) for c in melee.text.color.values())[:2] == (1, 0.12),
      f"in melee: red {melee.text.text} at 50%")
db.range.meleeAlpha = 30
ns.StyleRange()
check(abs(melee.alpha - 0.3) < 0.01, "its opacity can be lowered")
db.range.meleeAlpha = 50
ns.StyleRange()
range_at(27)
check(not melee.shown, "out of melee: gone")
db.range.enabled = False
range_at(3)
check(melee.shown and not rng.shown, "it works with the range number turned off")
db.range.enabled = True
db.range.meleeWarning = False
range_at(3)
check(not melee.shown, "and can be turned off")
db.range.meleeWarning = True
S.target = None
range_at(3)
check(not melee.shown, "no target: no warning")
S.target = lua.table(hostile=True)
# On Forever the melee spells can say "in range" from anywhere
S.meleeLies = True
check(range_at(38) == f"35-40 {yd}" and not melee.shown and colour()[:2] == (0.6, 0.6),
      f"melee spells saying 'in range' at 38 yd: still out of range, no MELEE RANGE ({rng.text.text})")
check(range_at(6) == f"5-8 {yd}" and not melee.shown, "nor in the dead zone: the 5 yd item says no")
check(range_at(3) == f"0-5 {yd}" and melee.shown, "at 3 yd it is melee")
S.meleeLies = False
range_at(27)

# One number, like GoodRange: exact at each crossing, carried at the closing rate in between
db.range.display = "number"
S.speed = lua.table(player=0, target=0)
G.Fire("PLAYER_TARGET_CHANGED")
check(number_at(32) == "33" and rng.unit.text == yd, f"standing at 32 yd: the middle of 30-35 ({rng.text.text})")
G.Fire("PLAYER_TARGET_CHANGED")
S.speed.player = 7
dist, worst, crossed = 26.0, 0.0, 0
for _ in range(60):  # walking away at 7 yd/s, a check every 0.05 s
    S.now += 0.05
    dist += 0.35
    shown = int(number_at(dist))
    if dist > 30.5:
        worst = max(worst, abs(shown - dist))
check(worst <= 1.0, f"walking from 26 to 47 yd the number stays within a yard of the truth (worst {worst:.2f})")
S.speed.player = 0
before = number_at(38)
S.now += 2
check(number_at(38) == before, f"both standing still: the number holds ({before})")
G.Fire("PLAYER_TARGET_CHANGED")
check(number_at(27) == "27" and number_at(150) == "100+", f"a new target starts again; past the last check: {rng.text.text}")
db.range.units = "meters"
check(number_at(32) in ("29", "30"), f"in metres: {rng.text.text}")
db.range.units = "yards"
ns.StyleRange()
check("FredokaOne" in rng.text.font[1] and rng.text.font[3] == "THICKOUTLINE" and rng.text.font[2] == db.range.textSize,
      f"Fredoka with a thick black outline: {list(rng.text.font.values())}")
db.range.font = "changa"
ns.StyleRange()
check("Changa-Bold" in rng.text.font[1], "or Changa, like GoodRange")
db.range.font = "game"
ns.StyleRange()
check(rng.text.font[1] == "font", "or the game's font")
db.range.font = "fredoka"
ns.StyleRange()

# ---------------------------------------------------------------- Aspects
asp = G.NAMED["HunterGodAspect"]
S.auras = lua.table("Power Word: Fortitude", "Aspect of the Cheetah")
G.Fire("UNIT_AURA", "player")
check(ns.CurrentAspect() == "cheetah" and not asp.shown, "reads Cheetah from your buffs; no warning out of combat")
S.secret = True  # in combat Forever hides the buffs
G.Fire("PLAYER_REGEN_DISABLED")
S.combat = True
G.Fire("UNIT_AURA", "player")
check(asp.shown and "Cheetah" in asp.text.text and not asp.icon.desat, f"Cheetah in combat: {asp.text.text}")
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 25296)  # Hawk, top rank
check(ns.CurrentAspect() == "hawk" and not asp.shown, "casting Hawk in combat clears the warning")
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 13163)
check(asp.shown and "Hawk" in asp.text.text and asp.icon.desat, f"Monkey when Hawk is your aspect: {asp.text.text}")
S.known[13165] = False  # below level 10
ns.UpdateAspect()
check(not asp.shown, "without Hawk yet, Monkey is fine")
S.known[13165] = True
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", G.SECRET)
check(ns.CurrentAspect() == "monkey", "a hidden spell doesn't change anything")
db.aspect.preferred = "any"
ns.UpdateAspect()
check(not asp.shown, "'any aspect': Monkey is fine")
db.aspect.preferred = "hawk"
S.secret, S.combat = False, False
S.auras = lua.table("Aspect of the Hawk")
G.Fire("PLAYER_REGEN_ENABLED")
check(ns.CurrentAspect() == "hawk" and not asp.shown, "after combat the buffs are read again")
S.auras = lua.table()
G.Fire("UNIT_AURA", "player")
G.Fire("PLAYER_REGEN_DISABLED")
check(asp.shown and asp.icon.desat, "no aspect at all in combat: warns")
G.Fire("PLAYER_REGEN_ENABLED")

# ---------------------------------------------------------------- Traps ready
traps = G.NAMED["HunterGodTraps"]
G.Fire("PLAYER_REGEN_DISABLED")
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 14311)
G.RunTimers()
check(not traps.shown, "right after laying a trap in combat: nothing yet")
G.RunTimers()
check(traps.shown and traps.text.text == L.TRAPS_READY and traps.icon.tex == 14311, f"when its cooldown ends: {traps.text.text}")
G.RunTimers()
check(not traps.shown, "and it goes after a few seconds")
G.Fire("PLAYER_REGEN_ENABLED")
S.now += 2
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 13795)  # after Feign Death: out of combat for a moment
G.RunTimers()
G.RunTimers()
check(traps.shown and traps.icon.tex == 13795, "a trap laid right after Feign Death counts too")
G.RunTimers()
S.now += 60
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 1499)  # before the pull
G.RunTimers()
G.RunTimers()
check(not traps.shown, "a trap laid outside a fight: nothing")
G.Fire("PLAYER_REGEN_DISABLED")
S.secretCooldown = True
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 13809)
G.RunTimers()
G.RunTimers()
check(traps.shown, "with the cooldown hidden by the game it waits the trap's own 15 s")
G.RunTimers()
S.secretCooldown = False
db.traps.enabled = False
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 13813)
G.RunTimers()
G.RunTimers()
check(not traps.shown, "turned off: nothing")
db.traps.enabled = True
G.Fire("PLAYER_REGEN_ENABLED")
S.now += 60

# ---------------------------------------------------------------- Freezing Trap time left
containers = {c.unit: c for c in G.FRAMES.values() if c.kind == "AuraContainer"}
c3 = containers.get("nameplate3")
check(len(containers) == 40 and c3 is not None and c3.enabled and c3.slot.filter == "HARMFUL",
      f"an aura container on each nameplate token: {len(containers)}")
ids = c3.slot.opts.candidateFilters.includeSpellIDs
check(ids[3355] and ids[14309] and ids[1324502] and not ids[1499], "it shows only the Freezing Trap auras, Forever's too")
button = G.CreateFrame("Button")
button.SetIcon = lua.eval("function(self, t) self.iconSet = t end")
button.SetDurationCooldown = lua.eval("function(self, c) self.cooldownSet = c end")
c3.slot.opts.initializeFrame(button)
check(button.iconSet is not None and button.cooldownSet is not None, "the game gets an icon and a countdown to draw it with")
S.plate = G.CreateFrame("Frame")
bar = G.CreateFrame("Frame")
S.plate.UnitFrame = lua.table(healthBar=bar)
holder = c3.parent
G.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
check(holder.shown and G.Same(holder.parent, S.plate) and G.Same(holder.point[2], bar) and holder.point[1] == "RIGHT",
      "beside the mob's health bar")
check((c3.updates or 0) >= 1, "and it reads the new mob's auras")
c5 = containers["nameplate5"]
c5.parent.IsProtected = lua.eval("function() return true end")
S.combat = True
G.Fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
check(not G.Same(c5.parent.parent, S.plate), "a protected frame isn't moved in combat")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
check(G.Same(c5.parent.parent, S.plate) and c5.parent.shown, "it goes to its plate when the fight ends")
c5.parent.IsProtected = None
db.traps.freeze = False
ns.UpdateFreeze()
check(not holder.shown and not c5.parent.shown, "turned off: nothing")
db.traps.freeze = True
ns.UpdateFreeze()
check(holder.shown, "turned on again")
S.plate = None
ns.UpdateFreeze()
check(not holder.shown, "no nameplate: nothing")

# ---------------------------------------------------------------- Ammo
ammo = G.NAMED["HunterGodAmmo"]
S.ranged, S.ammoID, S.ammoCount = 2504, 2515, 734
printed.clear()
G.Fire("BAG_UPDATE_DELAYED")
check(ammo.shown and ammo.text.text == 734, f"734 arrows: low ammo shown ({ammo.text.text})")
check(len(printed) == 1 and "734" in printed[0], f"says it once in chat: {printed}")
G.Fire("BAG_UPDATE_DELAYED")
check(len(printed) == 1, "and not again")
S.merchant = lua.table(159, 2515)
printed.clear()
G.Fire("MERCHANT_SHOW")
G.RunTimers()
check(any("734" in p for p in printed), f"a vendor with arrows reminds you: {printed}")
S.ammoCount = 1500
G.Fire("BAG_UPDATE_DELAYED")
check(not ammo.shown, "1500 arrows: nothing")
S.ammoID = None
G.Fire("PLAYER_EQUIPMENT_CHANGED", 0)
check(ammo.shown and ammo.text.text == L.NO_AMMO, "bow without ammo: 'no ammo'")
S.ranged = None
G.Fire("PLAYER_EQUIPMENT_CHANGED", 18)
check(not ammo.shown, "no ranged weapon: nothing")
S.ranged, S.ammoID, S.ammoCount = 2504, 2515, 734
db.lowAmmo.threshold = 500
ns.UpdateAmmo()
check(not ammo.shown, "threshold 500: 734 is enough")
db.lowAmmo.threshold = 1000
S.ammoCount = 5000
ns.UpdateAmmo()

# ---------------------------------------------------------------- Pet food
bar = G.NAMED["HunterGodPetFood"]
food_by = {}
for fid, f in foods.items():
    food_by.setdefault((f.t, f.l), fid)
meat30 = next(food_by[(1, l)] for l in range(25, 46) if (1, l) in food_by)
fish18 = next(food_by[(2, l)] for l in range(17, 22) if (2, l) in food_by)
meat5 = next(food_by[(1, l)] for l in range(1, 10) if (1, l) in food_by)
bread30 = next(food_by[(4, l)] for l in range(25, 40) if (4, l) in food_by)
S.pet = lua.table(level=35, diet=lua.table("Carne", "Pescado") if es else lua.table("Meat", "Fish"))
bags((meat5, 20), (fish18, 4), (bread30, 10), (meat30, 3), (meat30, 2))
G.Fire("UNIT_PET", "player")
G.RunTimers()
fv = ns.foodVendors
food_ids = pin_ids("food")
check(len(list(fv.keys())) > 100, f"Data.lua: {len(list(fv.keys()))} pet food vendors")
check(len(food_ids) > 10 and all(fv[i].side in ("H", "B") for i in food_ids), f"pet out: {len(food_ids)} food vendors, none Alliance-only")
check(all(any(t in (1, 2) and lvl >= 16 for t, lvl in fv[i].food.items()) for i in food_ids),
      "each sells meat or fish the level 30 pet still eats")
check(3881 in food_ids and 3158 not in food_ids, "Grimtak's meat yes, Duokna's bread no")
food_pin = G.FindPin(3881, "food")
check(food_pin.icon.tex == 2287 * 10 and food_pin.icon.maskTexture is not None,
      "food vendors: Haunch of Meat cut round, like the ammo pins")
tip = tooltip(3881, "food")
print("     food vendor tooltip:", tip)
check(tip[1] == L.FOOD_VENDOR and L.FOOD_SELLS % (L.FOOD_TYPES[1], 55) in tip, "tooltip says what it sells for your pet")
G.Click("foodVendors")
check(len(pin_ids("food")) == 0 and not db.foodVendors, "unticking pet food on the map hides them")
G.Click("foodVendors")
slash("comida" if es else "food")
check(len(pin_ids("food")) == 0, "food command hides them too")
slash("food")
check(len(pin_ids("food")) > 10, "and shows them again")
lst, total = ns.PetFoods()
ids = [e.id for e in lst.values()]
check(ids == [meat30, fish18] and total == 9, f"eats meat and fish, not bread or food 30 levels below: {ids}, {total}")
b1 = G.NAMED["HunterGodPetFood1"]
check(bar.shown and b1.shown and b1.count.text == 5 and b1.attrs["macrotext"] == "/cast Feed Pet\n/use 0 4",
      f"bar: best food first, click casts Feed Pet on it: {b1.attrs['macrotext']!r}")
check(not G.NAMED["HunterGodPetFood3"].shown, "only the foods it eats get a button")
check(bar.title.text == L.PET_LOW % 9, f"9 pieces, below 10: {bar.title.text}")
bags()
G.Fire("BAG_UPDATE_DELAYED")
check(bar.title.text == L.PET_NO_FOOD and not b1.shown, "no food: says so")
S.merchant = lua.table(159, meat30, bread30)
printed.clear()
G.Fire("MERCHANT_SHOW")
G.RunTimers()
check(any(f"[item {meat30}]" in p and f"[item {bread30}]" not in p for p in printed), f"a vendor with its food tells you: {printed}")
S.pet.diet = lua.table("Carne") if es else lua.table("Meat")
bags((bread30, 12), (meat30, 12))
G.Fire("BAG_UPDATE_DELAYED")
check(b1.shown and b1.food.id == meat30 and not G.NAMED["HunterGodPetFood2"].shown and bar.title.text == L.PET_FOOD,
      "a pet that only eats meat: the bread isn't shown")
S.pet.diet = lua.table()
G.Fire("BAG_UPDATE_DELAYED")
check(not bar.shown and ns.PetFoods() is None, "when the game doesn't say what it eats: nothing")
S.pet.diet = lua.table("Meat")
G.Fire("BAG_UPDATE_DELAYED")
G.Fire("PLAYER_REGEN_DISABLED")
S.combat = True
check(not bar.shown, "hidden as combat starts")
bags()
G.Fire("BAG_UPDATE_DELAYED")
check(b1.shown, "nothing secure changes in combat")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
check(bar.shown and not b1.shown, "updated after combat")
S.pet = None
G.Fire("UNIT_PET", "player")
check(not bar.shown and ns.PetFoods() is None, "no pet: no bar")
G.RunTimers()
check(len(pin_ids("food")) == 0, "no pet: no food vendors on the map")

# ---------------------------------------------------------------- Growl in groups
growl = G.NAMED["HunterGodGrowl"]
S.pet = lua.table(level=30, diet=lua.table("Meat"))
S.petActions = lua.table_from({4: lua.table("Growl", 1, False, False, True, True, 14921)})
printed.clear()
G.Fire("PET_BAR_UPDATE")
G.RunTimers()
check(not growl.shown and not any("Growl" in p for p in printed), "Growl on autocast in the open world: nothing")
S.instance = "party"
G.Fire("PLAYER_ENTERING_WORLD")
G.RunTimers()
check(growl.shown and "Growl" in growl.text.text, f"in a dungeon: warns ({growl.text.text})")
check(len([p for p in printed if "Growl" in p]) == 1, f"and says it once in chat: {printed}")
G.Fire("PET_BAR_UPDATE")
G.RunTimers()
check(len([p for p in printed if "Growl" in p]) == 1, "not again on every pet bar update")
S.petActions[4][6] = False
G.Fire("PET_BAR_UPDATE")
G.RunTimers()
check(not growl.shown, "autocast turned off: the warning goes")
S.petActions[4][6] = True
S.instance = "raid"
G.Fire("ZONE_CHANGED_NEW_AREA")
G.RunTimers()
check(growl.shown, "in a raid too")
S.instance, S.group = None, True
G.Fire("GROUP_ROSTER_UPDATE")
G.RunTimers()
check(not growl.shown, "in a group outside instances: off by default")
db.growl.groups = True
ns.UpdateGrowl()
check(growl.shown, "unless you ask for it")
db.growl.groups = False
S.group = False
S.instance = "party"
S.pet = None
G.Fire("UNIT_PET", "player")
G.RunTimers()
check(not growl.shown, "no pet: nothing")
S.instance = None
S.petActions = lua.table()
S.merchant = lua.table(meat30)
printed.clear()
G.Fire("MERCHANT_SHOW")
G.RunTimers()
check(not any("[item" in p for p in printed), f"no pet: no food reminders at vendors: {printed}")

# ---------------------------------------------------------------- Diet from the pet's family
# Forever may not list the diet: then it comes from the family (a wolf only eats meat)
S.pet = lua.table(level=45, diet=lua.table(), familyName="Wolf", familyID=1)
G.Fire("UNIT_PET", "player")
G.RunTimers()
food_ids = pin_ids("food")
check(8125 in food_ids, "Dirge Quikcleave (Gadgetzan butcher) is on the map for a level 45 wolf")
check(all(1 in fv[i].food for i in food_ids), "every food vendor shown sells meat")
out = slash("mascota" if es else "pet")
print("     pet info:", out)
check(len(out) == 2 and "Wolf" in out[0] and "45" in out[0] and L.FOOD_TYPES[1] in out[0] and L.DIET_FROM.family in out[0],
      "pet command: family, level, diet and where the diet came from")
check(f" {len(food_ids)} " in out[1], "and how many food vendors are on the map")
# Each food in the bags, and why the bar shows it or not
S.pet.level = 48
bags((8952, 18), (3770, 19), (117, 2), (4536, 5), (99999, 3), (159, 4))
out = slash("pet")
print("     bag foods:", out[2:])
verdicts = {line.split("|r", 1)[1].split(":")[0].strip(): line for line in out[2:]}
check(len(out) == 7 and not any("[item 159]" in line for line in out), "one line per food, and none for the water")
check(L.FOOD_EATS in verdicts["8952 x18"] and L.FOOD_EATS in verdicts["3770 x19"] and L.FOOD_TOO_LOW in verdicts["117 x2"]
      and L.FOOD_NOT_DIET in verdicts["4536 x5"] and L.FOOD_UNKNOWN.split(": ")[1] in verdicts["[item 99999] x3"],
      "level 48 pet: Roasted Quail and Mutton Chop eaten, Tough Jerky too low; an apple not for a wolf; an unknown food flagged")
bags()
S.pet = lua.table(level=45, diet=lua.table(), familyName="Raptor")
G.Fire("UNIT_PET", "player")
G.RunTimers()
check(8125 in pin_ids("food"), "a client that only gives the family name: Raptor eats meat")
S.pet = lua.table(level=45, diet=lua.table(), familyName="Moth", familyID=999)
G.Fire("UNIT_PET", "player")
G.RunTimers()
check(len(pin_ids("food")) == 0, "a family it doesn't know and no diet from the game: nothing")
S.pet.familyID = 1
G.Fire("PET_BAR_UPDATE")
G.Fire("PET_BAR_UPDATE")
G.RunTimers()
check(8125 in pin_ids("food"), "the pet's details arrive later: the pet bar update brings the vendors")
S.pet = lua.table(level=45, diet=lua.table("Fish"), familyName="Wolf", familyID=1)
G.Fire("UNIT_PET", "player")
G.RunTimers()
check(8125 not in pin_ids("food") and 8137 in pin_ids("food"), "when the game lists the diet, it wins over the family")
S.pet = None
G.Fire("UNIT_PET", "player")
G.RunTimers()
out = slash("pet")
check(len(out) == 1 and out[0].endswith(L.PET_INFO_NONE), f"pet command with no pet: {out}")

# ---------------------------------------------------------------- Pet level ups and training points
toast = G.NAMED["HunterGodPetToast"]
S.pet = lua.table(level=45, name="Lobito", familyID=1, diet=lua.table(), tp=100, spent=20)
G.Fire("UNIT_PET", "player")
G.RunTimers()
check(not toast.shown, "summoning a pet: no toast")
S.pet.level, S.pet.tp = 46, 115
printed.clear()
G.SOUNDS = lua.table()
G.Fire("UNIT_LEVEL", "pet")
check(toast.shown and toast.title.text == L.PET_LEVEL_TOAST % 46 and toast.sub.text == L.PET_TP_TOAST % (15, 95),
      f"level up: one toast with the level and the new points ({toast.title.text} / {toast.sub.text})")
check(toast.name.text == "Lobito" and "FredokaOne" in toast.title.font[1] and toast.title.font[3] == "THICKOUTLINE",
      "with the pet's name and the round font")
check(any("Lobito" in p and "46" in p for p in printed) and any("15" in p and "95" in p for p in printed),
      f"and both in chat: {printed}")
check(list(G.SOUNDS.values()) == [888], f"one level up sound: {list(G.SOUNDS.values())}")
G.RunTimers()
toast.fadeOut.scripts.OnFinished(toast.fadeOut)
check(not toast.shown, "it goes after a few seconds")
S.now += 10
S.pet.tp = 125
G.Fire("UNIT_PET_TRAINING_POINTS", "pet")
check(toast.shown and toast.title.text == L.PET_TP_TITLE and toast.sub.text == L.PET_TP_TOAST % (10, 105),
      f"points on their own (loyalty): {toast.title.text} / {toast.sub.text}")
G.RunTimers()
toast.fadeOut.scripts.OnFinished(toast.fadeOut)
S.pet = lua.table(level=20, name="Garra", familyID=2, diet=lua.table(), tp=40, spent=0)
G.Fire("UNIT_PET", "player")
G.RunTimers()
check(not toast.shown, "another pet with a different level: no toast")
db.petToast.level, db.petToast.training = False, False
S.pet.level, S.pet.tp = 21, 45
printed.clear()
G.Fire("UNIT_LEVEL", "pet")
check(not toast.shown and not printed, "turned off in the options: nothing")
db.petToast.level, db.petToast.training = True, True
S.pet = None
G.Fire("UNIT_PET", "player")
G.RunTimers()

# ---------------------------------------------------------------- Growl Miss
miss = G.NAMED["HunterGodGrowlMiss"]
S.pet = lua.table(level=45, name="Lobito", familyID=1, diet=lua.table())
S.petTarget, S.mobOnPet = True, False
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "pet", "cast", 14921)
check(S.lastDelay <= 0.5, f"checked {S.lastDelay} s after Growl, before the mob reaches you")
G.RunTimers()
check(miss.shown and miss.text.text == L.GROWL_MISS % "Growl" and miss.text.font[3] == "THICKOUTLINE",
      f"the mob isn't on the pet after Growl: {miss.text.text}")
miss.scripts.OnUpdate(miss, 0.05)
check(miss.shown, "the mob still isn't on the pet: it stays")
miss.float.scripts.OnFinished(miss.float)
check(not miss.shown, "it floats away")
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "pet", "cast", 14921)
G.RunTimers()
S.mobOnPet = True
miss.scripts.OnUpdate(miss, 0.05)
check(not miss.shown, "the mob turns to the pet a little late: the miss goes away")
S.mobOnPet = True
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "pet", "cast", 14921)
G.RunTimers()
check(not miss.shown, "the mob turned to the pet: nothing")
S.mobOnPet = G.SECRET
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "pet", "cast", 14921)
G.RunTimers()
check(not miss.shown, "the game hides who the mob attacks: nothing")
S.mobOnPet = False
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "pet", "cast", 2649 + 1)  # any other pet spell
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 14921)
G.RunTimers()
check(not miss.shown, "other spells, or yours: nothing")
db.growl.miss = False
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "pet", "cast", 14921)
G.RunTimers()
check(not miss.shown, "turned off: nothing")
db.growl.miss = True
S.petTarget = False

# ---------------------------------------------------------------- Happiness and health
sad = G.NAMED["HunterGodNotHappy"]
hurt = G.NAMED["HunterGodPetHealth"]
ns.UpdatePetStatus()
check(not sad.shown and not hurt.shown, "a happy pet at full health: nothing")
S.pet.happy = 2
ns.UpdatePetStatus()
check(sad.shown and sad.text.text == L.NOT_HAPPY and G.Same(sad.point[2], G.PetPortrait) and sad.point[1] == "BOTTOM",
      f"content, not happy: {sad.text.text} over the pet's portrait")
S.pet.happy = 1
G.PetFrame.shown = False
ns.UpdatePetStatus()
check(sad.shown and G.Same(sad.point[2], G.UIParent), "unhappy, and no pet frame: it stays on the screen")
G.PetFrame.shown = True
S.pet.happy = 3
S.pet.hp = 30
G.Fire("UNIT_HEALTH", "pet")
check(not sad.shown and hurt.shown and hurt.text.text == L.PET_HEALTH % 30, f"30% health: {hurt.text.text}")
S.pet.hp = 55
G.Fire("UNIT_HEALTH", "pet")
check(not hurt.shown, "55%: above the 40% line")
db.petStatus.healthPct = 60
ns.UpdatePetStatus()
check(hurt.shown and hurt.text.text == L.PET_HEALTH % 55, "the line can be raised")
S.pet.hp = G.SECRET
ns.UpdatePetStatus()
check(not hurt.shown, "health hidden by the game: nothing")
S.pet.hp, S.pet.happy = 20, 1
db.petStatus.happy, db.petStatus.health = False, False
ns.UpdatePetStatus()
check(not sad.shown and not hurt.shown, "both can be turned off")
db.petStatus.happy, db.petStatus.health, db.petStatus.healthPct = True, True, 40
S.pet = None
G.Fire("UNIT_PET", "player")
G.RunTimers()
check(not sad.shown and not hurt.shown, "no pet: nothing")

# ---------------------------------------------------------------- Bestial Wrath on the pet portrait
wrath = G.NAMED["HunterGodBestialWrath"]
S.pet = lua.table(level=48, name="Garra", familyID=20, diet=lua.table())
G.Fire("UNIT_PET", "player")
G.RunTimers()
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 19574)
G.RunTimers()
check(wrath.shown and wrath.time.text == 18 and G.Same(wrath.point[2], G.PetPortrait),
      f"Bestial Wrath: on the pet's portrait with 18 s ({wrath.time.text})")
S.now += 10.2
wrath.scripts.OnUpdate(wrath, 0.2)
check(wrath.time.text == 8, f"counting down: {wrath.time.text}")
S.now += 8
wrath.scripts.OnUpdate(wrath, 0.2)
check(not wrath.shown, "gone when it ends")
S.wrathAura = lua.table(expirationTime=S.now + 20)
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 19574)
G.RunTimers()
check(wrath.shown and wrath.time.text == 20, f"the buff's real time when the game shows it: {wrath.time.text}")
S.wrathAura = lua.table(expirationTime=G.SECRET)
S.now += 30
wrath.scripts.OnUpdate(wrath, 0.2)
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 19574)
G.RunTimers()
check(wrath.time.text == 18, "hidden by the game in combat: 18 s from the cast")
S.pet = None
wrath.scripts.OnUpdate(wrath, 0.2)
check(not wrath.shown, "pet dismissed: gone")
S.pet = lua.table(level=48, name="Garra", familyID=20, diet=lua.table())
db.petStatus.wrath = False
S.now += 30
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 19574)
G.RunTimers()
check(not wrath.shown, "turned off: nothing")
db.petStatus.wrath = True
S.wrathAura = None
S.pet = None
G.Fire("UNIT_PET", "player")
G.RunTimers()

# ---------------------------------------------------------------- Threat under the target's nameplate
thr = G.NAMED["HunterGodThreat"]
S.target = lua.table(hostile=True)
S.pet = lua.table(level=48, name="Garra", familyID=20, diet=lua.table())
S.threat = lua.table(False, 0, 85)
ns.UpdateThreat()
check(not thr.shown, "85% of the aggro: nothing yet")
S.threat = lua.table(False, 1, 92.4)
S.plate = G.CreateFrame("Frame")
ns.UpdateThreat()
check(thr.shown and thr.text.text == L.THREAT % 92 and G.Same(thr.point[2], S.plate) and thr.point[1] == "TOP",
      f"92%: under the target's nameplate ({thr.text.text})")
check(tuple(round(c, 2) for c in thr.text.color.values())[:2] == (1, 0.55), "in orange")
S.threat = lua.table(True, 3, 100)
ns.UpdateThreat()
check(thr.shown and thr.text.text == L.THREAT_PULLED and tuple(round(c, 2) for c in thr.text.color.values())[:2] == (1, 0.15),
      f"you pulled it: {thr.text.text}, in red")
S.threat = lua.table(G.SECRET, G.SECRET, G.SECRET)
ns.UpdateThreat()
check(not thr.shown, "threat hidden by the game: nothing")
S.threat = lua.table(True, 3, 100)
S.pet = None
ns.UpdateThreat()
check(not thr.shown, "solo without a pet you always have the aggro: no warning")
S.group = True
ns.UpdateThreat()
check(thr.shown, "in a group it warns again")
S.group = False
S.pet = lua.table(level=48, name="Garra", familyID=20, diet=lua.table())
S.threat = lua.table(False, 0, 85)
db.range.threatPct = 80
ns.UpdateThreat()
check(thr.shown and thr.text.text == L.THREAT % 85, "the line can be lowered to 80%")
db.range.threatPct = 90
S.plate = None
S.threat = lua.table(False, 1, 95)
ns.UpdateThreat()
check(thr.shown and G.Same(thr.point[2], G.UIParent), "no nameplate: where you put it")
db.range.threat = False
ns.UpdateThreat()
check(not thr.shown, "turned off: nothing")
db.range.threat = True
S.threat = None
S.pet = None
ns.UpdateThreat()

# ---------------------------------------------------------------- Minimap button and options
button = G.NAMED["HunterGodMinimapButton"]
check(button.shown and G.Same(button.point[2], G.Minimap), "minimap button on the minimap")
S.cursor = lua.table(0, 100)
button.scripts.OnDragStart(button)
button.scripts.OnUpdate(button)
check(abs(db.minimapButton.angle - 90) < 0.01, f"dragging moves it round the edge: {db.minimapButton.angle}")
button.scripts.OnClick(button, "LeftButton")
window = G.NAMED["HunterGodOptions"]
check(window is not None and window.shown, "left click opens the options")
win, pages = ns.OptionsWindow()
page = {p.key: p for p in pages.values()}
check(page["map"].shown and not page["range"].shown, "the map page first")
arrows_box = page["map"].controls[1]
arrows_box.checked = False
arrows_box.scripts.OnClick(arrows_box)
check(not db.arrows and all((db.learned[i] or data[i]).bullets for i in vendor_ids()), "the options' arrows box filters the map")
arrows_box.checked = True
arrows_box.scripts.OnClick(arrows_box)
ns.ShowOptionsPage("range")
style = next(c for c in page["range"].controls.values() if c.setting == L.OPT_STYLE)
check(style.text == L.STYLE.text, f"style button shows the setting: {style.text}")
style.scripts.OnClick(style)
check(db.range.style == "icon" and style.text == L.STYLE.icon, "clicking it goes to the next style")
units = next(c for c in page["range"].controls.values() if c.setting == L.OPT_UNITS)
check(units.text == L.UNITS.yards, f"units button starts in yards: {units.text}")
units.scripts.OnClick(units)
check(db.range.units == "meters" and units.text == L.UNITS.meters and rng.unit.text == L.METERS,
      f"one click: metres, and the display changes: {rng.unit.text}")
out = slash("yardas" if es else "yards")
check(db.range.units == "yards" and rng.unit.text == yd and len(out) == 1, f"yards command: {out}")
out = slash("metros" if es else "meters")
check(db.range.units == "meters" and L.UNITS.meters.lower() in out[0], f"meters command: {out}")
slash("yards")
size = next(c for c in page["range"].controls.values() if c.setting == L.OPT_SIZE)
size.scripts.OnValueChanged(size, 21.4)
check(db.range.textSize == 21, f"size slider: {db.range.textSize}")
swatch = next(c for c in page["range"].controls.values() if c.setting == L.RANGE.ranged)
swatch.scripts.OnClick(swatch)
G.COLOR_INFO.swatchFunc()
check((db.range.colors.ranged.r, db.range.colors.ranged.b) == (0, 1), "colour picker sets the in-range colour")
G.COLOR_INFO.cancelFunc()
check(db.range.colors.ranged.g == 1, "cancel puts it back")
check(swatch.number.text == "28" and swatch.unit.text == yd and swatch.number.font[3] == "THICKOUTLINE",
      f"the preview shows the range as it will look: {swatch.number.text} {swatch.unit.text}")
display = next(c for c in page["range"].controls.values() if c.setting == L.OPT_DISPLAY)
display.scripts.OnClick(display)
check(db.range.display == "bracket" and swatch.number.text == "25-30", f"the preview follows the settings: {swatch.number.text}")
display.scripts.OnClick(display)
check(db.range.display == "number", "and back to the number")
combat = page["aspects"]
check(any(c.setting == L.OPT_THREAT_PCT for c in combat.controls.values())
      and any(c.setting == L.OPT_MELEE_ALPHA for c in combat.controls.values()),
      "the melee range and aggro warnings sit with the other combat warnings")
ns.ShowOptionsPage("aspects")
check(combat.shown and not page["range"].shown, "the menu goes to another page")
ns.ShowOptionsPage("range")
ns.ShowOptionsPage("pet")
low_slider = next(c for c in page["pet"].controls.values() if c.setting == L.OPT_PET_LOW)
low_slider.scripts.OnValueChanged(low_slider, 25)
check(db.petFood.low == 25, "pet food warning slider")
slash("")
check(not window.shown, "/huntergod closes it again")

# Unlocking the displays to move them
button.scripts.OnClick(button, "RightButton")
check(ns.unlocked, "right click unlocks")
check(rng.shown and rng.text.text == "32" and asp.shown and ammo.shown and bar.shown and growl.shown and toast.shown
      and melee.shown and miss.shown and sad.shown and hurt.shown and traps.shown and wrath.shown and thr.shown,
      "all displays show a sample")
check(all(f.mover.shown and f.mover.width >= 140 and f.mover.height >= 44
          for f in (rng, asp, ammo, bar, growl, toast, melee, miss, sad, hurt, traps, wrath, thr)),
      "each one with a big box to drag, even the food bar")
check(bar.mover.level > 1, "the box sits above the food buttons")
rng.point = lua.table("TOPLEFT", G.UIParent, "TOPLEFT", 300, -200)
rng.mover.scripts.OnDragStop(rng.mover)
check(list(db.positions["range"].values()) == ["TOPLEFT", "TOPLEFT", 300, -200], "the new place is saved")
sad.point = lua.table("CENTER", G.UIParent, "CENTER", 10, 20)
sad.mover.scripts.OnDragStop(sad.mover)
check(db.positions["happiness"] is not None, "NOT HAPPY moved off the portrait: it stays where you put it")
slash("lock")
check(not ns.unlocked and not asp.shown and not ammo.shown and not bar.shown and not growl.shown and not toast.shown
      and not melee.shown and not miss.shown and not sad.shown and not hurt.shown and not traps.shown and not wrath.shown
      and not thr.shown
      and not rng.mover.shown and not melee.mover.shown,
      "locking hides the samples")
S.combat = True
out = slash("unlock")
check(not ns.unlocked and len(out) == 1, "can't unlock in combat")
S.combat = False
slash("boton" if es else "button")
check(not button.shown and db.minimapButton.hide, "button command hides the minimap button")
slash("button")

# Other classes: nothing unless asked for
S["class"] = "MAGE"
slash("both")
ns.RefreshAll()
check(G.CountWorld()[0] == 0 and not G.Panel().shown, "nothing on the map for a mage, not even the checkboxes")
check(not rng.shown and not asp.shown and not ammo.shown and not bar.shown, "and no hunter displays")
slash("class")
check(G.CountWorld()[0] > 0 and G.Panel().shown, "class toggle: map shown for any class")

print()
print("FAILURES:" if fails else f"All good ({LOCALE}).", fails if fails else "")
sys.exit(1 if fails else 0)
