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
-- A hidden value that still carries what it hides, for the game's own setters to use
function Hidden(v) return { hidden = v } end
issecretvalue = function(v) return v == SECRET or (type(v) == "table" and v.hidden ~= nil) end

local mapNames = { [1411] = "Durotar", [1454] = "Orgrimmar", [2548] = "Riverglades", [1429] = "Elwynn Forest" }
SPELLS = { [75] = "Auto Shot", [2973] = "Raptor Strike", [2974] = "Wing Clip", [6991] = "Feed Pet",
  [13165] = "Aspect of the Hawk", [25296] = "Aspect of the Hawk", [13163] = "Aspect of the Monkey",
  [5118] = "Aspect of the Cheetah", [13159] = "Aspect of the Pack", [13161] = "Aspect of the Beast", [20043] = "Aspect of the Wild",
  [2649] = "Growl", [14921] = "Growl", [430] = "Drink", [433] = "Food", [19574] = "Bestial Wrath",
  [19506] = "Trueshot Aura", [20906] = "Trueshot Aura",
  [1317257] = "Strider Kick", [1310627] = "Predator's Edge", [1310532] = "Expose Prey",
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
-- Forever's way round the hidden health: the percentage through a curve, still hidden
UnitHealthPercent = function(u, predicted, curve)
  local x = (G.pet.realhp or 100) / (G.pet.maxhp or 100)
  return Hidden(curve and curve:Evaluate(x) or x) end
C_CurveUtil = { CreateCurve = function()
  local c = { points = {} }
  function c:SetType(t) self.type = t end
  function c:ClearPoints() self.points = {} end
  function c:AddPoint(x, y) table.insert(self.points, { x, y }) table.sort(self.points, function(a, b) return a[1] < b[1] end) end
  function c:Evaluate(x)
    local p = self.points
    if x <= p[1][1] then return p[1][2] end
    for i = 2, #p do
      if x <= p[i][1] then local a, b = p[i - 1], p[i] return a[2] + (x - a[1]) * (b[2] - a[2]) / (b[1] - a[1]) end
    end
    return p[#p][2]
  end
  return c end }
UnitIsUnit = function(a, b) if a == "pettargettarget" and b == "pet" then return G.mobOnPet end return false end
UnitExists = function(u) if u == "target" then return G.target ~= nil end if u == "pet" then return G.pet ~= nil end
  if u == "pettarget" then return G.petTarget end return true end
CustomAuraContainerAuraProcessingPolicy = { None = 0 }
UnitCanAttack = function() return G.target and G.target.hostile end
UnitIsDead = function() return false end
UnitAffectingCombat = function() return G.combat end
InCombatLockdown = function() return G.combat end
CheckInteractDistance = function(_, i) if G.secretRange or G.secretInteract then return SECRET end return G.dist <= (i == 3 and 8 or 28) end
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
UnitDetailedThreatSituation = function(a, b) if G.threat then return G.threat[1], G.threat[2], G.threat[3], G.threat[4] end end
NUM_PET_ACTION_SLOTS = 10
-- Forever gives the summoned pet's diet through the stable API (slot 0)
C_StableInfo = { GetStablePetFoodTypes = function(i) if G.pet and i == 0 then return G.pet.diet end end }
INVSLOT_AMMO, INVSLOT_RANGED, NUM_BAG_SLOTS = 0, 18, 4
GetInventoryItemID = function(_, slot) if slot == 18 then return G.ranged end if slot == 0 then return G.ammoID end
  if slot == 16 then return G.mainHand end if slot == 17 then return G.offHand end end
-- Swing timers: the weapons' icons and speeds, the range the game reports, and its own setting
ITEM_TEXTURES = { [16] = 135300, [17] = 135310, [18] = 135490 }
GetInventoryItemTexture = function(_, slot) if GetInventoryItemID(nil, slot) then return ITEM_TEXTURES[slot] end end
UnitAttackSpeed = function() return G.mhSpeed, G.ohSpeed end
UnitRangedDamage = function() return G.rangedSpeed end
SWING_RANGE, SWING_CHECKS = {}, {}
C_SwingTimer = { EnableRangeCheck = function(t, on) SWING_CHECKS[t] = on end,
  IsTargetWithinSwingRange = function(t) return SWING_RANGE[t] end }
CVARS = { showSwingTimer = "1" }
C_CVar = { GetCVar = function(n) return CVARS[n] end, SetCVar = function(n, v) CVARS[n] = v end }
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
    if spell == "Auto Shot" then return not G.autoBlocked and G.dist >= (G.autoMin or 8) and G.dist <= G.reach end
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
C_UnitAuras = { GetAuraDataByIndex = function(_, i) local name = G.auras[i] if not name then return end
    local t = G.auraTimes and G.auraTimes[name]
    return { name = name, expirationTime = t and t[1] or 0, duration = t and t[2] or 0,
      spellId = G.auraIDs and G.auraIDs[name] } end,
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
  elseif k == "SetWidth" then self.width = ... elseif k == "SetAlpha" then self.alpha = ...
  elseif k == "SetFormattedText" then
    local args = { ... }
    for i = 2, #args do if type(args[i]) == "table" then args[i] = args[i].hidden self.hiddenText = true end end
    self.text = format(unpack(args))
  elseif k == "SetFont" then self.font = { ... }
  elseif k == "SetFontObject" then local o = ... self.fontObject = o self.font = o and o.font self.color = nil
  elseif k == "GetTextColor" then if rawget(self, "color") then return unpack(self.color) end
  elseif k == "GetText" then return self.text
  elseif k == "AddMaskTexture" then self.maskTexture = ...
  elseif k == "SetVertexColor" then self.vertex = { ... }
  elseif k == "SetPoint" then self.points = rawget(self, "points") or {} table.insert(self.points, { ... })
  elseif k == "ClearAllPoints" then self.points = {}
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
  function f:SetAlpha(a) self.hiddenAlpha = type(a) == "table" self.alpha = self.hiddenAlpha and a.hidden or a end
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
  function f:SetScale(s) self.scale = s end
  function f:Play() self.playing = true end
  function f:Stop() self.playing = false end
  -- Forever's aura container: a slot whose button the addon dresses; the game plays what it's given
  if kind == "AuraContainer" then
    function f:AddAuraSlot(key, filter, opts)
      self.slot = { key = key, filter = filter, opts = opts }
      local button = CreateFrame("Button", nil, self)
      button.shownAnims, button.assignedAnims = {}, {}
      function button:AddAuraShownAnimation(g) table.insert(self.shownAnims, g) end
      function button:AddAuraAssignedAnimation(g) table.insert(self.assignedAnims, g) end
      function button:SetDurationText(text, o) self.durationText = { text = text, options = o } end
      self.button = button
      if opts.initializeFrame then opts.initializeFrame(button) end
    end
    function f:SetUnit(u) self.unit = u end
    function f:SetEnabled(on) self.enabled = on end
    function f:UpdateAllAuras() self.updates = (self.updates or 0) + 1 end
  end
  FRAMES = FRAMES or {} table.insert(FRAMES, f)
  if name then NAMED[name] = f end
  return f
end
-- Font objects: one per name, the last font set on it counts
FONT_OBJECTS = {}
function CreateFont(name)
  local f = { name = name }
  function f:SetFont(...) self.font = { ... } end
  function f:GetFont() return unpack(self.font) end
  FONT_OBJECTS[name] = f
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
-- Tracking: the minimap's list and the dungeon you're in
SPELLS[19883], SPELLS[1494], SPELLS[19884], SPELLS[19885] = "Track Humanoids", "Track Beasts", "Track Undead", "Track Hidden"
SPELLS[24293] = "Improved Tracking"
SPELLS[6150], SPELLS[1299448], SPELLS[415407] = "Quick Shots", "Quick Strikes", "Rapid Killing"
-- The game's countdown text: whole seconds rounded up
Enum.NumericRuleFormatRounding = { Up = 2 }
C_StringUtil = { CreateNumericRuleFormatter = function()
  return { SetBreakpoints = function(self, rules) self.rules = rules end }
end }
TRACKING = {}
C_Minimap = { GetNumTrackingTypes = function() return #TRACKING end, GetTrackingInfo = function(i) return TRACKING[i] end }
GetInstanceInfo = function() return "Dungeon", G.instance or "none", 1, "", 5, 0, false, G.instanceID or 36 end
-- On a flight, mounted
UnitOnTaxi = function() return G.taxi or false end
IsMounted = function() return G.mounted or false end
-- Talent reset: the trainer's options, the game's price dialog, the gold and the server's clock
GOSSIP_OPTIONS = {}
C_GossipInfo = { GetOptions = function() return GOSSIP_OPTIONS end, SelectOption = function() end }
GossipFrame = CreateFrame("Frame")
POPUPS = {}
StaticPopup_FindVisible = function(which) return POPUPS[which] end
GetMoney = function() return G.money or 0 end
GetServerTime = function() return G.server or 0 end
date = os.date
ConfirmTalentWipe = function() end
hooksecurefunc = function(a, b, c)
  local t, key, fn = _G, a, b
  if type(a) == "table" then t, key, fn = a, b, c end
  local orig = t[key]
  t[key] = function(...) local r = { orig(...) } fn(...) return unpack(r) end
end

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
check(n_trainers > 20 and all(t.m and 0 <= t.x <= 100 and 0 <= t.y <= 100 and t.side in ("A", "H", "B") and t.name
                              for t in trainers.values()), f"Data.lua: {n_trainers} hunter trainers with map, coordinates, side and name")
stables = ns.stableMasters
n_stables = len(list(stables.keys()))
check(n_stables > 30 and all(t.m and 0 <= t.x <= 100 and 0 <= t.y <= 100 and t.side in ("A", "H", "B") and t.name
                             for t in stables.values()), f"Data.lua: {n_stables} stable masters with map, coordinates, side and name")
aili = stables[43408]
check(aili is not None and aili.m == 2482 and aili.side == "B", "Aili Greenwillow, in Forever's Mount Hyjal, is there")
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
check(len(trainer_ids()) > 5 and "H" in tsides and tsides <= {"H", "B"},
      f"Horde: {len(trainer_ids())} hunter trainer pins, Horde or for both sides")
tip = tooltip(3171, "trainer")  # Thotar, Durotar
print("     trainer tooltip:", tip)
check(tip[0] == "Thotar" and tip[1] == ("Instructor de cazadores" if es else "Hunter trainer"), "trainer tooltip shows name and role")
G.FindPin(3171, "trainer").scripts.OnClick(G.FindPin(3171, "trainer"))
check(S.waypoint is not None and S.waypoint.m == 1411, "clicking a trainer pin sets a waypoint")
S.waypoint = None
ssides = {stables[i].side for i in pin_ids("stable")}
check(len(pin_ids("stable")) > 10 and "A" not in ssides, f"Horde: {len(pin_ids('stable'))} stable master pins, none Alliance-only")
check(9987 in pin_ids("stable") and 9978 not in pin_ids("stable"), "Shoja'my in Razor Hill yes, Wesley in Stormwind no")
stable_pin = G.FindPin(9987, "stable")
check(stable_pin.icon.tex == 883 and stable_pin.icon.maskTexture is not None,
      "stable masters: Call Pet's icon cut round")
tip = tooltip(9987, "stable")
print("     stable master tooltip:", tip)
check(tip[0] == "Shoja'my" and tip[1] == L.STABLE_MASTER, "stable master tooltip shows name and role")
stable_pin.scripts.OnClick(stable_pin)
check(S.waypoint is not None and S.waypoint.m == 1411, "clicking a stable master sets a waypoint")
S.waypoint = None

# Checkboxes on the world map
panel = G.Panel()
check(panel is not None and panel.shown and boxes() == {"arrows": True, "bullets": True, "trainers": True},
      "map checkboxes shown, all ticked")
check([b.key for b in panel.boxes.values()] == ["arrows", "bullets", "trainers", "stableMasters", "foodVendors"],
      "boxes in order: arrows, bullets, trainers, stable masters, pet food")
check(G.Box("stableMasters").checked, "stable masters ticked to start with")
check(len(pin_ids("food")) == 0, "no pet out: no pet food vendors")
check(panel.clamped and panel.level == 2100 and G.WorldMapFrame.hooks["OnShow"] is not None, f"panel above the topmost map pin level: {panel.level}")
G.Click("arrows")
check(not db.arrows and all(data[i].bullets for i in vendor_ids()) and len(trainer_ids()) > 0,
      "unticking arrows: only bullet vendors, trainers stay")
G.Click("trainers")
check(len(trainer_ids()) == 0 and G.CountMini() == len(vendor_ids()) + len(pin_ids("stable")),
      "unticking trainers removes them from both maps")
G.Click("stableMasters")
check(len(pin_ids("stable")) == 0 and not db.stableMasters and G.CountMini() == len(vendor_ids()),
      "unticking stable masters removes them from both maps")
G.Click("bullets")
check(G.CountWorld()[0] == 0, "nothing ticked: no pins")
out = slash("estado" if es else "status")
check(("ninguna munición" if es else "no ammo") in out[0], f"status with nothing ticked: {out[0]}")
G.Click("arrows"); G.Click("bullets"); G.Click("trainers"); G.Click("stableMasters")
check(boxes() == {"arrows": True, "bullets": True, "trainers": True} and len(trainer_ids()) > 0, "ticking everything back")
slash("instructores" if es else "trainers")
check(not G.Box("trainers").checked and len(trainer_ids()) == 0, "trainers command unticks the box")
slash("trainers")
check(G.Box("trainers").checked, "and ticks it again")
out = slash("establos" if es else "stables")
check(not G.Box("stableMasters").checked and len(pin_ids("stable")) == 0
      and (("establos no" if es else "stable masters off") in out[0]), f"stables command unticks the box: {out[0]}")
slash("stables")
check(G.Box("stableMasters").checked and len(pin_ids("stable")) > 10, "and ticks it again")

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

# Recording a vendor QuestieDB doesn't have: one in Riverglades sells level 10 arrows and bullets
S.npcGUID = "Creature-0-1-2-3-999001-0000ABCD"
S.npcName = "Pexi Quickshot"
S.playerMap, S.px, S.py = 2548, 0.7855, 0.5355
S.merchant = lua.table(159, 2512, 2515, 2516, 2519)
printed.clear()
G.Fire("MERCHANT_SHOW")
G.RunTimers()
learned = db.learned[999001]
check(learned is not None and learned.arrows and learned.bullets and learned.upTo == 25 and learned.m == 2548,
      f"records Pexi: {dict(learned) if learned else None}")
check(len(printed) == 1 and "Pexi" in printed[0], f"announces it once: {printed}")
check(999001 in vendor_ids(), "Pexi now on the map")

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
rspot = G.NAMED["HunterGodRangeSpot"]
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
db.range.unitLabel = True  # the checks below read "25-28 yd"; the number alone is checked on its own


def colour():
    return tuple(round(c, 2) for c in rng.text.color.values())


check(range_at(27) == f"25-28 {yd}" and colour()[:2] == (0.3, 1) and not rng.glow.shown,
      f"27 yd: in range, green: {rng.text.text}")
check(range_at(32) == f"30-35 {yd}" and colour()[:2] == (0.45, 0.8) and rng.glow.shown,
      f"32 yd: the last 5 yards of Auto Shot's 35, light blue and glowing: {rng.text.text}")
check(rng.glow.tex == ns.GLOW and ns.GLOW.endswith("glow.tga"), "the glow is the addon's own soft oval")
db.range.farGlow = False
check(range_at(32) == f"30-35 {yd}" and colour()[:2] == (0.3, 1) and not rng.glow.shown, "with that option off, green")
db.range.farGlow = True
check(range_at(37) == f"35-40 {yd}" and colour()[:2] == (0.6, 0.6) and not rng.glow.shown,
      "out of range is grey, not the edge")
check(range_at(9) == f"8-10 {yd}", f"9 yd: Auto Shot reaches from 8: {rng.text.text}")
check(range_at(3) == f"{L.RANGE.melee} " and colour()[:2] == (1, 0.82) and rng.text.font[2] == int(db.range.textSize * 0.7),
      f"3 yd: melee, yellow, in words (0 goes without saying): {rng.text.text}")
check(range_at(6) == f"{L.RANGE.dead} " and colour()[:2] == (1, 0.2) and rng.state.text == ""
      and rng.text.font[2] == int(db.range.textSize * 0.7),
      f"6 yd: dead zone, red, its name instead of the number, a little smaller: {rng.text.text} / {rng.text.font[2]}")
check(range_at(27) == f"25-28 {yd}" and rng.state.text == "" and rng.text.font[2] == db.range.textSize,
      f"only there: in melee the number again, at its size ({rng.text.text})")
db.range.deadLabel = False
check(range_at(6) == f"5-8 {yd}" and rng.state.text == "", "with that option off, just the number")
db.range.deadLabel = True
db.range.unitLabel = False
check(range_at(27) == "25-28 " and rng.unit.text == "", f"by default the number alone, without yd: {rng.text.text}")
db.range.unitLabel = True
check(range_at(38) == f"35-40 {yd}" and colour()[:2] == (0.6, 0.6), f"38 yd: out of range, grey: {rng.text.text}")
check(range_at(150) == f"100+ {yd}", f"150 yd: {rng.text.text}")
db.range.units = "meters"
check(range_at(27) == f"23-26 {L.METERS}", f"in metres: {rng.text.text}")
db.range.units = "yards"
check(range_at(27) == f"25-28 {yd}" and rng.state.text == "", "in range: the number alone, its colour says the rest")
G.Uncache(ns, 25)
G.Uncache(ns, 30)
check(range_at(27) == f"20-28 {yd}", f"items not loaded: those steps are skipped: {rng.text.text}")
S.uncached = lua.table()
S.lying[5] = True
check(range_at(32) == f"30-35 {yd}" and colour()[:2] == (0.45, 0.8),
      f"an item that wrongly says 'within 5 yd' can't contradict Auto Shot: {rng.text.text}")
S.lying = lua.table()
S.reach = 41
check(range_at(38) == f"35-40 {yd}" and colour()[:2] == (0.45, 0.8) and rng.glow.shown,
      f"Hawk Eye: 38 yd is still in range, and the edge of its 41: {rng.text.text}")
check(range_at(33) == f"30-35 {yd}" and colour()[:2] == (0.3, 1), f"with Hawk Eye 33 yd isn't the edge any more: {rng.text.text}")
S.reach = 39
check(range_at(36) == f"35-39 {yd}" and colour()[:2] == (0.45, 0.8), f"Hawk Eye 2/3, 39 yd: the edge from 35: {rng.text.text}")
S.reach = 35
out = slash("dr")
check(out == [L.PREFIX + L.DR_NO_API], "dr: a game without diminishing returns says so")
G.C_SpellDiminish = lua.eval("""{
  IsSystemSupported = function() return true end,
  GetAllSpellDiminishCategories = function(ruleset)
    if ruleset == 2 then return { { category = 4, name = "Incapacitate" } } end
    return {}
  end,
  ShouldTrackSpellDiminishCategory = function() return SECRET end,
}""")
G.Enum.SpellDiminishRuleset = lua.eval("{ None = 0, PvE = 1, PvP = 2 }")
G.C_CVar = lua.eval("{ GetCVar = function(name) return name == 'spellDiminishPVPEnemiesEnabled' and '1' or '0' end }")
out = slash("dr")
print("     dr report:", out)
check(len(out) == 4 and "Incapacitate (4, " + L.DR_SECRET + ")" in out[2] and L.DR_NONE in out[1] and out[3] == L.PREFIX + L.DR_ON,
      "dr: the system, the game's options, each ruleset's categories, and it starts logging")
before = S.now
S.now = 100.5
printed.clear()
G.Fire("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", "nameplate3",
       lua.eval("{ category = 4, startTime = 100, duration = 18, showCountdown = true, isImmune = false }"))
G.Fire("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", "nameplate3",
       lua.eval("{ category = SECRET, startTime = SECRET, duration = 18, showCountdown = true, isImmune = SECRET }"))
G.Fire("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", G.SECRET, G.SECRET)
print("     dr log:", list(printed))
check(len(printed) == 3 and "category=4 startTime=100 duration=18 showCountdown=true isImmune=false" in printed[0]
      and "100.5" in printed[0] and f"category={L.DR_SECRET} startTime={L.DR_SECRET} duration=18" in printed[1]
      and printed[2].count(L.DR_SECRET) == 2,
      "dr: each update in chat, with what is secret marked")
out = slash("dr")
G.Fire("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", "nameplate3", lua.eval("{ category = 4 }"))
check(out[-1] == L.PREFIX + L.DR_OFF and len(printed) == len(out), "dr again: stops logging")
S.now = before
G.C_SpellDiminish = None
out = slash("rango" if es else "range")
print("     range report:", out)
check(len(out) == 2 and L.RANGE.out in out[0] and "28:" in out[1], "range command: state, yards and each step")
S.secretRange = True
check(range_at(27) is None, "hidden values in combat: nothing shown")
S.secretRange = False
S.secretInteract = True
db.range.deadLabel = False  # these read the number the dead zone's name would cover
check(range_at(6) == f"5-10 {yd}" and colour()[:2] == (1, 0.2),
      f"too close for Auto Shot with the close check hidden in combat: dead zone, not out of range: {rng.text.text}")
check(range_at(38) == f"35-40 {yd}" and colour()[:2] == (0.6, 0.6), f"and really out of range is still out: {rng.text.text}")
check(range_at(20) == f"15-20 {yd}" and colour()[:2] == (0.3, 1), f"in range as before: {rng.text.text}")
S.secretInteract = False
# What the game answered in Forever: Auto Shot no, melee no, 8 no, 10 yes
S.autoMin = 10
check(range_at(9) == f"8-10 {yd}" and colour()[:2] == (1, 0.2),
      f"at 9 yd, past the 8 yard check but too close for Auto Shot: dead zone, not 35-40: {rng.text.text}")
check(range_at(12) == f"10-15 {yd}" and colour()[:2] == (0.3, 1), f"and at 12 yd it shoots again: {rng.text.text}")
db.range.deadLabel = True
S.autoMin = None
S.autoBlocked = True
check(range_at(18) == f"15-20 {yd}" and colour()[:2] == (0.6, 0.6),
      f"Auto Shot can't fire at 18 yd: grey, with the real distance, not 35-40: {rng.text.text}")
check(range_at(38) == f"35-40 {yd}", f"and far away is still 35-40: {rng.text.text}")
S.autoBlocked = False
S.target = None
check(range_at(27) is None, "no target: nothing shown")
S.target = lua.table(hostile=False)
check(range_at(27) is None, "friendly target: nothing shown")
S.target = lua.table(hostile=True)
S.plate = G.CreateFrame("Frame")
range_at(27)
check(G.Same(rng.point[2], S.plate) and rng.point[1] == "BOTTOM", "sits above the target's nameplate")
check(rng.point[4] == 0 and rng.point[5] == 2, "2 pixels above it")
db.range.plateGap = 12
range_at(27)
check(G.Same(rng.point[2], S.plate) and rng.point[5] == 12, "further from the nameplate when you ask")
db.range.plateSide = "bottom"
range_at(27)
check(rng.point[1] == "TOP" and rng.point[3] == "BOTTOM" and rng.point[5] == -12, "or under it")
plate_bar = G.CreateFrame("Frame")
S.plate.UnitFrame = lua.table(healthBar=plate_bar)
db.range.plateSide = "left"
range_at(27)
check(G.Same(rng.point[2], plate_bar) and rng.point[1] == "RIGHT" and rng.point[4] == -12 and rng.point[5] == 0,
      "or left of its health bar")
db.range.plateSide = "right"
range_at(27)
check(G.Same(rng.point[2], plate_bar) and rng.point[1] == "LEFT" and rng.point[4] == 12, "or right of it")
db.range.plateSide = "top"
db.range.plateGap = 2
range_at(27)
check(G.Same(rng.point[2], S.plate) and rng.point[5] == 2, "and back above it")
S.plate = None
range_at(27)
check(G.Same(rng.point[2], rspot), "no nameplate: on its spot, where you put it")
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
check(range_at(6) == f"{L.RANGE.dead} " and not melee.shown, "nor in the dead zone: the 5 yd item says no")
check(range_at(3) == f"{L.RANGE.melee} " and melee.shown, "at 3 yd it is melee")
S.meleeLies = False
range_at(27)

# Melee (Survival): known by its talents, and the range says something else
check(not ns.IsMelee(), "no melee talents: ranged")
printed.clear()
S.known[1317257] = True  # Strider Kick
G.Fire("SPELLS_CHANGED")
said = [p for p in printed if L.STYLE_NOW_MELEE in p]
check(ns.IsMelee() and len(said) == 1, f"Strider Kick learned: melee, and the chat says so: {printed}")
G.Fire("SPELLS_CHANGED")
check(len([p for p in printed if L.STYLE_NOW_MELEE in p]) == 1, "said only once")
S.combat = False
check(range_at(3) == f"{L.RANGE.hit} " and colour()[:2] == (0.3, 1) and rng.state.text == "" and not melee.shown,
      f"in melee green and no MELEE RANGE: where you want to be ({rng.state.text})")
check(range_at(27) == f"25-28 {yd}" and colour()[:2] == (1, 0.82) and rng.state.text == ""
      and not melee.shown, f"at range yellow, get closer; out of combat no warning ({rng.state.text})")
range_at(33)
check(not rng.glow.shown and colour()[:2] == (1, 0.82), "no max range glow in melee")
S.combat = True
blinked = False
for d in (3, 6, 27, 50):
    range_at(d)
    blinked = blinked or melee.shown
check(not blinked and colour()[:2] == (0.6, 0.6), "in combat, near or far: no blinking warning at all in melee")
check(range_at(6) == f"{L.RANGE.dead} " and colour()[:2] == (1, 0.2), "the dead zone still red")
S.combat = False
ns.SetUnlocked(True)
check(not melee.shown, "nor a sample of it to move")
ns.SetUnlocked(False)
out = slash("estilo" if es else "style")
check(len(out) == 1 and L.PLAYSTYLE.melee in out[0] and "Strider Kick" in out[0], f"/huntergod style: {out}")
db.playstyle = "ranged"
range_at(3)
check(not ns.IsMelee() and melee.shown and melee.text.text == L.MELEE_WARNING,
      "ranged chosen in the options: the talents don't matter, MELEE RANGE again")
out = slash("style")
check(len(out) == 1 and L.STYLE_CHOSEN in out[0], f"and the command says why: {out}")
db.playstyle = "auto"
S.combat = False
printed.clear()
S.known[1317257] = False
G.Fire("SPELLS_CHANGED")
said = [p for p in printed if L.STYLE_NOW_RANGED in p]
check(not ns.IsMelee() and len(said) == 1, f"talents reset: back to ranged: {printed}")
out = slash("style")
check(len(out) == 1 and L.PLAYSTYLE.ranged in out[0] and "Strider Kick" in out[0] and "Expose Prey" in out[0],
      f"and which talents it looked for: {out}")
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
saved_target, S.target = S.target, None
S.auras = lua.table("Power Word: Fortitude", "Aspect of the Cheetah")
G.Fire("UNIT_AURA", "player")
check(ns.CurrentAspect() == "cheetah" and not asp.shown, "reads Cheetah from your buffs; no warning out of combat")
S.secret = True  # in combat Forever hides the buffs
G.Fire("PLAYER_REGEN_DISABLED")
S.combat = True
G.Fire("UNIT_AURA", "player")
check(asp.shown and "Cheetah" in asp.text.text and not asp.icon.desat, f"Cheetah in combat: {asp.text.text}")
check(not asp.text.shown, "just the icon: no words under it")
db.aspect.text = True
ns.UpdateAspect()
check(asp.text.shown, "unless you ask for them")
db.aspect.text = False
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
# In melee (Survival) its own aspect
db.playstyle = "melee"
G.Fire("PLAYER_REGEN_DISABLED")
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 25296)  # Hawk
check(asp.shown and "Monkey" in asp.text.text, f"melee, before Beast is learned: Monkey ({asp.text.text})")
S.known[13161] = True
ns.UpdateAspect()
check(asp.shown and "Beast" in asp.text.text and asp.icon.desat, f"melee with Beast learned: Beast, not Hawk ({asp.text.text})")
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 13161)
check(ns.CurrentAspect() == "beast" and not asp.shown, "with Beast up, nothing to say")
db.aspect.melee = "hawk"
ns.UpdateAspect()
check(asp.shown and "Hawk" in asp.text.text, "the melee aspect is yours to choose")
db.aspect.melee = "beast"
db.playstyle = "auto"
ns.UpdateAspect()
check(asp.shown and "Hawk" in asp.text.text, "without melee talents, Hawk again")
G.Fire("PLAYER_REGEN_ENABLED")
S.known[13161] = False
# Before the pull: an enemy targeted out of combat, and a click puts the right aspect on
clickA = G.NAMED["HunterGodReminderClickaspect"]
S.auras = lua.table("Aspect of the Cheetah")
G.Fire("UNIT_AURA", "player")
check(not asp.shown and not clickA.shown, "Cheetah out of combat, no enemy targeted: nothing")
S.target = lua.table(hostile=True)
G.Fire("PLAYER_TARGET_CHANGED")
check(asp.shown and clickA.shown and clickA.attrs.type1 == "spell" and clickA.attrs.spell1 == "Aspect of the Hawk"
      and clickA.attrs.type is None, f"an enemy targeted in Cheetah: the reminder, and a click puts Hawk on: {clickA.attrs.spell1}")
db.playstyle = "melee"
S.known[13161] = True
ns.UpdateAspect()
check(clickA.attrs.spell1 == "Aspect of the Beast", f"Survival: Beast ({clickA.attrs.spell1})")
db.playstyle = "auto"
S.known[13161] = False
ns.UpdateAspect()
G.Fire("PLAYER_REGEN_DISABLED")
S.combat = True
ns.UpdateAspect()
check(asp.shown and not clickA.shown, "the fight starts: the warning stays, the click goes (the game won't have it)")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
check(asp.shown and clickA.shown, "after it, the click is back")
S.target = lua.table(hostile=False)
G.Fire("PLAYER_TARGET_CHANGED")
check(not asp.shown and not clickA.shown, "a friendly target: nothing")
# Missing out of combat: it shows with no target, but not travelling, on a flight or mounted
S.target = None
S.auras = lua.table()
G.Fire("UNIT_AURA", "player")
check(asp.shown and asp.icon.desat and clickA.shown and clickA.attrs.spell1 == "Aspect of the Hawk",
      "no aspect at all out of combat (you died, say): the reminder, to click")
S.auras = lua.table("Aspect of the Monkey")
G.Fire("UNIT_AURA", "player")
check(asp.shown, "Monkey when you use Hawk: there too")
S.auras = lua.table("Aspect of the Cheetah")
G.Fire("UNIT_AURA", "player")
check(not asp.shown, "travelling in Cheetah: fine out of combat")
S.auras = lua.table()
G.Fire("UNIT_AURA", "player")
S.mounted = True
G.Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
check(not asp.shown, "mounted: not now (casting would get you off)")
S.mounted = None
S.taxi = True
G.Fire("PLAYER_CONTROL_LOST")
check(not asp.shown, "on a flight: not now")
S.taxi = None
G.Fire("PLAYER_CONTROL_GAINED")
check(asp.shown, "landed: there")
db.aspect.missingAlways = False
ns.UpdateAspect()
check(not asp.shown, "with that option off, only in combat or before a pull")
db.aspect.missingAlways = True
S.auras = lua.table("Aspect of the Hawk")
G.Fire("UNIT_AURA", "player")
S.target = saved_target

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
containers = {c.unit: c for c in G.FRAMES.values() if c.kind == "AuraContainer" and c.unit != "player"}
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

# ---------------------------------------------------------------- Pins never float off the maps
world_pin = list(G.WORLD.keys())[0]
mini_pin = list(G.MINI.keys())[0]
map_pin = G.CreateFrame("Frame", None, G.WorldMapFrame)
world_pin.parent = map_pin
world_pin.shown = True
world_pin.scripts.OnShow(world_pin)
check(world_pin.shown, "a pin on the open world map shows")
G.WorldMapFrame.shown = False
world_pin.scripts.OnShow(world_pin)
check(not world_pin.shown, "with the world map closed it doesn't")
G.WorldMapFrame.shown = True
world_pin.parent = G.UIParent  # what HereBeDragons does when the map lets go of it
world_pin.shown = True
world_pin.scripts.OnShow(world_pin)
check(not world_pin.shown, "a pin let go of by the map, shown again: hidden, not floating over your character")
mini_pin.parent = G.Minimap
mini_pin.shown = True
G.WorldMapFrame.shown = False
mini_pin.scripts.OnShow(mini_pin)
check(mini_pin.shown, "a minimap pin shows with the world map closed")
G.WorldMapFrame.shown = True

# ---------------------------------------------------------------- Ammo
ammo = G.NAMED["HunterGodAmmo"]
S.ranged, S.ammoID, S.ammoCount = 2504, 2515, 3000
G.Fire("BAG_UPDATE_DELAYED")
check(not ammo.shown, "3000 arrows: nothing")
# After a loading screen the bags can read short for a moment
S.ammoCount = 12
printed.clear()
G.Fire("UNIT_INVENTORY_CHANGED", "player")
check(not ammo.shown and not printed, "a low count is not believed at once")
S.ammoCount = 3000
S.now = S.now + 2
G.RunTimers()
check(not ammo.shown and not printed, "the 3000 arrows read again a moment later: no warning, nothing in chat")
S.ammoCount = 734
G.Fire("BAG_UPDATE_DELAYED")
check(not ammo.shown, "really low: not yet")
S.now = S.now + 1
G.Fire("BAG_UPDATE_DELAYED")
check(not ammo.shown, "still waiting")
S.now = S.now + 1
G.RunTimers()
check(ammo.shown and ammo.text.text == 734, f"734 arrows two seconds later: low ammo shown ({ammo.text.text})")
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
S.now = S.now + 2
G.RunTimers()
check(ammo.shown and ammo.text.text == L.NO_AMMO, "bow without ammo: 'no ammo'")
db.lowAmmo.enabled = False
ns.UpdateAmmo()
check(not ammo.shown, "the warning turned off: nothing")
db.lowAmmo.enabled = True
ns.UpdateAmmo()
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
# Forever hides the pet's health: the game itself turns it into the warning's opacity and number
S.pet.hp, S.pet.realhp = G.SECRET, 30
ns.UpdatePetStatus()
check(hurt.shown and hurt.hiddenAlpha and hurt.alpha == 1 and hurt.text.hiddenText and hurt.text.text == L.PET_HEALTH % 30,
      f"hidden health, 30%: seen, with its number ({hurt.text.text})")
check(hurt.width == len((L.PET_HEALTH % 100).encode("utf-8")) * 6 + 44, "its width from a sample, not from the hidden text")
S.pet.realhp = 75
ns.UpdatePetStatus()
check(hurt.shown and hurt.alpha == 0, "hidden health, 75%: there but not seen")
S.pet.realhp = 60
ns.UpdatePetStatus()
check(hurt.alpha == 0, "right at the 60% line: not seen")
S.pet.realhp = 59
ns.UpdatePetStatus()
check(hurt.alpha == 1 and hurt.text.text == L.PET_HEALTH % 59, "just under it: seen")
db.petStatus.healthPct = 40
ns.UpdatePetStatus()
check(hurt.alpha == 0, "the line moved down to 40%: not seen")
db.petStatus.healthPct = 60
S.pet.hp, S.pet.realhp = 20, None
ns.UpdatePetStatus()
check(hurt.shown and not hurt.hiddenAlpha and hurt.alpha == 1 and hurt.text.text == L.PET_HEALTH % 20,
      "health readable again: the plain way, fully seen")
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

# ---------------------------------------------------------------- Trueshot Aura
ts = G.NAMED["HunterGodTrueshot"]
S.secret = False
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
S.auras = lua.table("Aspect of the Hawk")
G.Fire("UNIT_AURA", "player")
check(not ts.shown, "without the talent: no Trueshot Aura reminder")
S.known[20906] = True
G.Fire("SPELLS_CHANGED")
S.auraTimes = lua.table()
S.auraTimes["Trueshot Aura"] = lua.table(S.now + 600, 1800)
S.auras = lua.table("Aspect of the Hawk", "Trueshot Aura")
G.Fire("UNIT_AURA", "player")
check(not ts.shown, "10 minutes left: nothing yet")
S.now = S.now + 500
ns.UpdateTrueshot()
check(ts.shown and ts.text.text == "1:40" and not ts.icon.desat, f"under 2 minutes: the reminder, counting down ({ts.text.text})")
tsc = G.NAMED["HunterGodReminderClicktrueshot"]
check(tsc.shown and tsc.attrs.type1 == "spell" and tsc.attrs.spell1 == "Trueshot Aura", "and a click casts it")
S.secret = True  # in combat the buffs are hidden
G.Fire("PLAYER_REGEN_DISABLED")
S.combat = True
S.now = S.now + 30
G.Fire("UNIT_AURA", "player")
check(ts.shown and ts.text.text == "1:10", f"in combat it keeps counting from when it was seen ({ts.text.text})")
check(not tsc.shown, "in a fight it can't be clicked")
S.now = S.now + 80
ns.UpdateTrueshot()
check(ts.shown and ts.text.text == "" and ts.icon.desat, "run out: the icon in grey until you cast it")
G.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 20906)
check(not ts.shown, "cast it again, even in combat: gone for another 30 minutes")
S.now = S.now + 1700
ns.UpdateTrueshot()
check(ts.shown and ts.text.text == "1:40", f"and back near its end ({ts.text.text})")
S.secret = False
S.combat = False
S.auras = lua.table("Aspect of the Hawk")
G.Fire("PLAYER_REGEN_ENABLED")
check(ts.shown and ts.icon.desat and tsc.shown, "not on you after the fight (you died): grey reminder, to click")
db.aspect.trueshot = False
ns.UpdateTrueshot()
check(not ts.shown and not tsc.shown, "with its option off, nothing")
db.aspect.trueshot = True
S.auraTimes["Trueshot Aura"] = lua.table(0, 0)
S.auras = lua.table("Aspect of the Hawk", "Trueshot Aura")
G.Fire("UNIT_AURA", "player")
check(not ts.shown, "an aura with no end (until cancelled): nothing to remind")
S.now = S.now - 2310

# ---------------------------------------------------------------- Threat under the target's nameplate
thr = G.NAMED["HunterGodThreat"]
tspot = G.NAMED["HunterGodThreatSpot"]
S.target = lua.table(hostile=True)
S.pet = lua.table(level=48, name="Garra", familyID=20, diet=lua.table())
S.threat = lua.table(False, 0, 65, 85)
ns.UpdateThreat()
check(not thr.shown, "85% of the aggro: nothing yet")
S.threat = lua.table(False, 1, 71, 92.4)
S.plate = G.CreateFrame("Frame")
ns.UpdateThreat()
check(thr.shown and thr.text.text == L.THREAT % 92 and G.Same(thr.point[2], S.plate) and thr.point[1] == "TOP",
      f"92% of the pet's threat, as the game's tooltip says (not the scaled 71%): under the nameplate ({thr.text.text})")
db.range.plateSide = "bottom"
ns.UpdateThreat()
check(G.Same(thr.point[2], rng) and thr.point[1] == "TOP" and thr.point[5] == -2,
      "with the range under the nameplate, the warning goes under the range")
db.range.plateSide = "top"
ns.UpdateThreat()
check(G.Same(thr.point[2], S.plate), "and back under the nameplate")
S.threat = lua.table(False, 1, 74.6, 97)
ns.UpdateThreat()
check(thr.shown and thr.text.text == L.THREAT % 97, f"tooltip at 97% at range: it warns ({thr.text.text})")
S.threat = lua.table(False, 1, 69, 89.6)
ns.UpdateThreat()
check(thr.shown and thr.text.text == L.THREAT % 90, f"rounded like the tooltip: 89.6 is 90% ({thr.text.text})")
S.threat = lua.table(False, 1, 71, 92.4)
ns.UpdateThreat()
check(tuple(round(c, 2) for c in thr.text.color.values())[:2] == (1, 0.55), "in orange")
S.threat = lua.table(True, 3, 100, 100)
ns.UpdateThreat()
check(thr.shown and thr.text.text == L.THREAT_PULLED and tuple(round(c, 2) for c in thr.text.color.values())[:2] == (1, 0.15),
      f"you pulled it: {thr.text.text}, in red")
S.threat = lua.table(G.SECRET, G.SECRET, G.SECRET, G.SECRET)
ns.UpdateThreat()
check(not thr.shown, "threat hidden by the game: nothing")
S.threat = lua.table(True, 3, 100, 100)
S.pet = None
ns.UpdateThreat()
check(not thr.shown, "solo without a pet you always have the aggro: no warning")
S.group = True
ns.UpdateThreat()
check(thr.shown, "in a group it warns again")
S.group = False
S.pet = lua.table(level=48, name="Garra", familyID=20, diet=lua.table())
S.threat = lua.table(False, 0, 65, 85)
db.range.threatPct = 80
ns.UpdateThreat()
check(thr.shown and thr.text.text == L.THREAT % 85, "the line can be lowered to 80%")
db.range.threatPct = 90
S.plate = None
S.threat = lua.table(False, 1, 73, 95)
ns.UpdateThreat()
check(thr.shown and G.Same(thr.point[2], tspot), "no nameplate: on its spot, where you put it")
db.range.threat = False
ns.UpdateThreat()
check(not thr.shown, "turned off: nothing")
db.range.threat = True
S.threat = None
S.pet = None
ns.UpdateThreat()

# ---------------------------------------------------------------- Swing timers
G.C_CVar = lua.eval("{ GetCVar = function(n) return CVARS[n] end, SetCVar = function(n, v) CVARS[n] = v end }")
sw = ns.SwingState()
sholder, sbars = sw.holder, sw.bars
db.swing.byRange = False
check(G.CVARS.showSwingTimer == "0" and db.swing.restoreBlizzard, "Blizzard's swing timers off at login: these do the job")
check(G.SWING_CHECKS[0] and G.SWING_CHECKS[1] and G.SWING_CHECKS[2], "the game asked to report range for each weapon")
S.ranged, S.mainHand, S.offHand = 2504, None, None
G.Fire("PLAYER_EQUIPMENT_CHANGED", 18)
ns.UpdateSwing()
check(not sholder.shown, "no swing yet: no bars")
G.Fire("PLAYER_SWING", 2.8, 2)
rb = sbars[2]
check(sholder.shown and rb.shown and not sbars[0].shown and not sbars[1].shown, "Auto Shot: its bar, on its own")
check(rb.tag.tex == 135490 and rb.point[5] == 0, "at the top, with the bow's icon")
col = db.swing.colors.ranged
check(rb.flash.alpha > 0.5 and abs(rb.fill.color[1] - col.r * 0.45) < 1e-6 and rb.time.text == "2.8",
      f"it just went: a flash, the bar dim, 2.8 s to the next: {rb.time.text}")
check(abs(rb.windup.width - 180 * 0.5 / 2.8) < 1e-6 and rb.windup.shown, "the last half second marked")
S.now = S.now + 1.4
ns.UpdateSwing()
check(rb.flash.alpha == 0 and abs(rb.fill.width - 90) < 1e-6 and abs(rb.fill.color[1] - col.r * (0.45 + 0.55 * 0.25)) < 1e-6
      and rb.time.text == "1.4", f"halfway: half full and lighting up: {rb.fill.width}, {rb.time.text}")
S.now = S.now + 1.45
ns.UpdateSwing()
check(abs(rb.fill.color[1] - col.r) < 1e-6 and rb.fill.width == 180 and rb.time.text == "", "ready: full and at its brightest")
S.now = S.now + 1.85
ns.UpdateSwing()
check(rb.shown, "it stays a moment after the swing is done")
S.now = S.now + 0.2
ns.UpdateSwing()
check(not sholder.shown, "and goes once you stop shooting")
# Survival: two weapons, in melee
S.mainHand, S.offHand = 900, 901
G.Fire("PLAYER_EQUIPMENT_CHANGED", 16)
G.Fire("PLAYER_SWING", 2.6, 0)
G.Fire("PLAYER_SWING", 1.9, 1)
mb, ob = sbars[0], sbars[1]
check(mb.shown and ob.shown and not rb.shown and mb.point[5] == 0 and ob.point[5] == -(14 + 3),
      f"main and off hand stacked from the top: {mb.point[5]}, {ob.point[5]}")
check(mb.tag.tex == 135300 and ob.tag.tex == 135310 and not mb.windup.shown, "each with its weapon, no half-second mark")
G.Fire("PLAYER_SWING", 2.8, 2)
check(rb.point[5] == 0 and mb.point[5] == -17 and ob.point[5] == -34, "Auto Shot back: always on top")
# Only the bars for where you stand
db.swing.byRange = True
G.Fire("PLAYER_SWING_RANGE_UPDATE", 0, True, True)
check(not rb.shown and mb.shown and ob.shown and mb.point[5] == 0, "in melee range: the melee bars only, from the top")
G.Fire("PLAYER_SWING_RANGE_UPDATE", 0, False, True)
check(rb.shown and not mb.shown and not ob.shown and rb.point[5] == 0, "out of melee reach: Auto Shot's only")
G.Fire("PLAYER_SWING_RANGE_UPDATE", 0, False, False)
check(G.Same(ns.SwingZone(), None) or ns.SwingZone() in ("melee", "ranged"), "the game can't tell: the addon's own range reading, if any")
db.swing.byRange = False
G.Fire("PLAYER_SWING_RANGE_UPDATE", 0, True, True)
check(rb.shown and mb.shown, "with that option off: every bar you're using")
G.Fire("PLAYER_SWING_RANGE_UPDATE", 0, False, True)
ns.UpdateSwing()
check(mb.alpha == 0.55 and mb.fill.color[1] == 0.5 * (0.45 + 0.55 * 0) or mb.alpha == 0.55, "out of melee range: grey and faint")
G.Fire("PLAYER_SWING_RANGE_UPDATE", 0, True, True)
ns.UpdateSwing()
check(mb.alpha == 1, "back in range")
G.SWING_RANGE[0] = False
G.Fire("PLAYER_TARGET_CHANGED")
ns.UpdateSwing()
check(mb.alpha == 0.55, "a new target out of reach: grey straight away")
G.SWING_RANGE[0] = None
G.Fire("PLAYER_TARGET_CHANGED")
ns.UpdateSwing()
check(mb.alpha == 1, "the game can't tell: not taken as out of range")
out = slash("swinglog")
printed.clear()
G.Fire("PLAYER_SWING", G.SECRET, 0)
G.Fire("PLAYER_SWING", 2.6, G.SECRET)
check(mb.shown, "a hidden swing is left alone")
check(len(printed) == 2 and "duration=secret" in printed[0] and "type=secret" in printed[1], f"/huntergod swinglog says what came: {printed}")
slash("swinglog")
S.offHand = None
G.Fire("PLAYER_EQUIPMENT_CHANGED", 17)
check(not ob.shown, "the off hand taken off: its bar goes")
db.swing.main = False
ns.UpdateSwing()
check(not mb.shown and rb.shown, "the main hand bar can be turned off")
db.swing.main = True
db.swing.width, db.swing.height, db.swing.icon, db.swing.time = 240, 20, False, False
ns.StyleSwing()
check(rb.width == 240 and rb.height == 20 and not rb.tag.shown and not rb.time.shown and sholder.width == 240,
      "wider, taller, no icon and no seconds")
db.swing.width, db.swing.height, db.swing.icon, db.swing.time = 180, 14, True, True
ns.StyleSwing()
check(sholder.width == 197, f"back to 180 plus the icon: {sholder.width}")
S.now = S.now + 10
ns.UpdateSwing()
check(not sholder.shown, "all done: nothing")
out = slash("swing")
check(sholder.shown and rb.shown and mb.shown and not ob.shown, "/huntergod swing: the bars you'd see, swinging")
S.now = S.now + 7
G.RunTimers()
ns.UpdateSwing()
check(not sholder.shown, "and they go after a few seconds")
ns.SetUnlocked(True)
check(sholder.shown and rb.shown and mb.shown and ob.shown and sholder.mover.shown, "unlocked: every bar, to drag")
ns.SetUnlocked(False)
check(not sholder.shown, "locked: gone")
G.Fire("PLAYER_REGEN_DISABLED")
S.combat = True
db.swing.hideBlizzard = False
ns.SwingBlizzard()
check(G.CVARS.showSwingTimer == "0", "in a fight the game's setting waits")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
check(G.CVARS.showSwingTimer == "1" and not db.swing.restoreBlizzard, "and after it Blizzard's are back, as they were")
db.swing.hideBlizzard = True
ns.SwingBlizzard()
check(G.CVARS.showSwingTimer == "0", "hidden again")

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
scontrols = {c.setting: c for c in page["swing"].controls.values()}
check(all(scontrols.get(k) is not None for k in (L.OPT_SWING_ON, L.OPT_SWING_RANGED, L.OPT_SWING_MAIN, L.OPT_SWING_OFF,
      L.OPT_SWING_BLIZZARD, L.OPT_SWING_WIDTH, L.OPT_SWING_HEIGHT, L.OPT_SWING_WINDUP, L.OPT_SWING_TEST)),
      "a Swing timers tab: which bars, Blizzard's, size, the half second and a button to try them")
swidth = scontrols[L.OPT_SWING_WIDTH]
swidth.scripts.OnValueChanged(swidth, 260)
check(db.swing.width == 260 and sw.holder.width == 260 + 14 + 3 and sw.holder.shown, "wider, shown swinging as you change it")
swidth.scripts.OnValueChanged(swidth, 180)
sblizz = scontrols[L.OPT_SWING_BLIZZARD]
sblizz.checked = False
sblizz.scripts.OnClick(sblizz)
check(G.CVARS.showSwingTimer == "1", "unticked: Blizzard's swing timers back")
sblizz.checked = True
sblizz.scripts.OnClick(sblizz)
check(G.CVARS.showSwingTimer == "0", "ticked: off again")
S.now = S.now + 10
G.RunTimers()
ns.UpdateSwing()
arrows_box = page["map"].controls[1]
check(any(c.setting == L.STABLES_BOX for c in page["map"].controls.values()), "the options have a stable masters box")
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
far = next(c for c in page["range"].controls.values() if c.setting == L.RANGE.far)
check(far.number.text == "33" and far.glow.shown and not swatch.glow.shown,
      "the preview has the edge of your reach too, glowing")
check(any(c.setting == L.OPT_FAR for c in page["range"].controls.values()), "and its switch")
combat = page["aspects"]
check(any(c.setting == L.OPT_ASPECT_TEXT for c in combat.controls.values()), "the aspect warning's words have a switch")
check(any(c.setting == L.OPT_TRUESHOT % "Trueshot Aura" for c in combat.controls.values()), "and Trueshot Aura's reminder too")
side = next(c for c in page["range"].controls.values() if c.setting == L.OPT_PLATE_SIDE)
side.scripts.OnClick(side)
check(db.range.plateSide == "bottom" and side.text == L.PLATE_SIDE.bottom, f"side of the nameplate: {side.text}")
for _ in range(3):
    side.scripts.OnClick(side)
check(db.range.plateSide == "top", "round all four sides and back above")
gap = next(c for c in page["range"].controls.values() if c.setting == L.OPT_PLATE_GAP)
gap.scripts.OnValueChanged(gap, -6.2)
check(db.range.plateGap == -6, f"distance from the nameplate, closer than touching too: {db.range.plateGap}")
gap.scripts.OnValueChanged(gap, 2)
check(any(c.setting == L.OPT_THREAT_PCT for c in combat.controls.values())
      and any(c.setting == L.OPT_MELEE_ALPHA for c in combat.controls.values()),
      "the melee range and aggro warnings sit with the other combat warnings")
ns.ShowOptionsPage("aspects")
check(combat.shown and not page["range"].shown, "the menu goes to another page")
how = next(c for c in combat.controls.values() if c.setting == L.OPT_PLAYSTYLE)
check(how.text == L.PLAYSTYLE.auto, f"ranged or melee: by your talents to start with ({how.text})")
how.scripts.OnClick(how)
how.scripts.OnClick(how)
check(db.playstyle == "melee" and how.text == L.PLAYSTYLE.melee and ns.IsMelee(), f"or melee, by hand: {how.text}")
check(any(c.setting == L.OPT_PREFERRED_MELEE for c in combat.controls.values()), "with its own aspect")
ns.ShowOptionsPage("range")
closer = next(c for c in page["range"].controls.values() if c.setting == L.RANGE.approach)
check(closer.shown and closer.number.text == "28" and not swatch.shown and not far.shown,
      "in melee the preview has get closer instead of in range and max range")
how.scripts.OnClick(how)
check(db.playstyle == "auto" and how.text == L.PLAYSTYLE.auto, "and round to by your talents again")
ns.ShowOptionsPage("range")
check(swatch.shown and far.shown and not closer.shown, "the preview back as it was")
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
          for f in (rspot, G.NAMED["HunterGodReminders"], ammo, bar, growl, toast, melee, miss, sad, hurt, traps, wrath, tspot)),
      "each one with a big box to drag, even the food bar")
check(bar.mover.level > 1, "the box sits above the food buttons")
ts = G.NAMED["HunterGodTrueshot"]
trk = G.NAMED["HunterGodTracking"]
check(ts.shown and ts.text.text == "1:35" and trk.shown and not ts.mover and not trk.mover
      and asp.point[4] == -50 and ts.point[4] == 0 and trk.point[4] == 50 and G.NAMED["HunterGodReminders"].mover.shown,
      "the aspect, Trueshot and tracking samples side by side, dragged together as one row")
check(not rng.mover and not thr.mover and G.Same(rng.point[2], rspot) and G.Same(thr.point[2], tspot),
      "what you drag is the spot, never anchored to a nameplate, and the displays hang from it")
rspot.point = lua.table("TOPLEFT", G.UIParent, "TOPLEFT", 300, -200)
rspot.mover.scripts.OnDragStop(rspot.mover)
check(list(db.positions["range"].values()) == ["TOPLEFT", "TOPLEFT", 300, -200], "the new place is saved")
sad.point = lua.table("CENTER", G.UIParent, "CENTER", 10, 20)
sad.mover.scripts.OnDragStop(sad.mover)
tspot.point = lua.table("CENTER", G.UIParent, "CENTER", 50, -300)  # being dragged
ns.UpdateThreat()
ns.UpdateThreat()
check(tspot.point[4] == 50 and tspot.point[5] == -300 and G.Same(thr.point[2], tspot),
      "the aggro warning stays where you drag it, between updates")
tspot.mover.scripts.OnDragStop(tspot.mover)
check(list(db.positions["threat"].values()) == ["CENTER", "CENTER", 50, -300], "and its new place is saved")
check(abs(tspot.defaultPoint[4] - rspot.defaultPoint[4]) >= 44,
      f"its default place is clear of the range display's box ({tspot.defaultPoint[4]} vs {rspot.defaultPoint[4]})")
check(db.positions["happiness"] is not None, "NOT HAPPY moved off the portrait: it stays where you put it")
slash("lock")
check(not ns.unlocked and not asp.shown and not ammo.shown and not bar.shown and not growl.shown and not toast.shown
      and not melee.shown and not miss.shown and not sad.shown and not hurt.shown and not traps.shown and not wrath.shown
      and not thr.shown and not ts.shown
      and not rspot.mover.shown and not melee.mover.shown,
      "locking hides the samples")
check(list(rspot.point.values())[2:] == ["TOPLEFT", 300, -200] and list(tspot.point.values())[2:] == ["CENTER", 50, -300],
      "and both stay where you dragged them")
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

# ---------------------------------------------------------------- Talent reset price at the trainer
S["class"] = "HUNTER"
rs = ns.RespecState()
rnote, recs = rs.note, rs.records
DAY = 86400
T0 = 1795600000
S.server, S.money = T0, 500000
popup = G.CreateFrame("Frame")
TRAINER = lua.eval('{ { gossipOptionID = 101, name = "I am here for training." }, { gossipOptionID = 102, name = "I wish to unlearn my class or legacy talents." } }')
G.GOSSIP_OPTIONS = TRAINER
G.Fire("GOSSIP_SHOW")
check(rnote.shown and G.Same(rnote.anchor, G.GossipFrame) and rnote.point[1] == "TOPLEFT", "your class trainer: a note under its window")
check((L.RESPEC_UNKNOWN % "HunterGod") in rnote.body.text and rnote.title.text == L.RESPEC_TITLE, "no reset written down yet: it says so")
G.Fire("GOSSIP_CLOSED")
check(not rnote.shown, "it goes with the window")
G.GOSSIP_OPTIONS = lua.eval('{ { gossipOptionID = 201, name = "I wish to untrain my pet." }, { gossipOptionID = 202, name = "I am here for training." } }')
G.Fire("GOSSIP_SHOW")
check(not rnote.shown, "any other trainer: nothing")
# Asking for the reset: the trainer's price, and the note under the game's dialog
G.GOSSIP_OPTIONS = TRAINER
G.C_GossipInfo.SelectOption(102)
G.POPUPS.CONFIRM_TALENT_WIPE = popup
G.Fire("CONFIRM_TALENT_WIPE", 10000, 0)
G.RunTimers()
check(rnote.shown and G.Same(rnote.anchor, popup) and rnote.point[1] == "TOP", "the price dialog: the note under it")
check((L.RESPEC_ASKED % ("1 g", L.RESPEC_MINUTES % 1)) in rnote.body.text, f"what the trainer asked: {rnote.body.text}")
check(db.respec.options[102], "the option that led there is learnt")
# Not enough gold: the game says no, and nothing is written down
G.ConfirmTalentWipe()
S.now = S.now + 11
G.RunTimers()
G.Fire("PLAYER_MONEY")
check(not recs["0"].reset and not ns.RespecState().pending, "accepted but no gold went: not a reset")
# Paid
G.Fire("CONFIRM_TALENT_WIPE", 10000, 0)
G.RunTimers()
G.ConfirmTalentWipe()
S.money = 490000
G.Fire("PLAYER_MONEY")
r = recs["0"]
check(r.reset == T0 and r.paid == 10000 and r.cost is None, "paid: the reset written down, with its price")
popup.shown = False
rnote.scripts.OnUpdate(rnote, 0.3)
check(not rnote.shown, "the dialog gone: the note too")
# A day on, at the trainer: a step up, and back down in six days
S.server = T0 + DAY
G.GOSSIP_OPTIONS = lua.eval('{ { gossipOptionID = 102, name = "Ich möchte meine Fähigkeiten verlernen." } }')
G.Fire("GOSSIP_SHOW")
drop = T0 + 7 * DAY
when = L.RESPEC_ON % (L.RESPEC_WEEKDAYS[G.date("*t", drop).wday], G.date("%H:%M", drop))
body = rnote.body.text
check(rnote.shown, "an option it learnt, in another language: still your trainer")
check((L.RESPEC_LAST % (L.RESPEC_HOURS % 24, "1 g")) in body and (L.RESPEC_NOW_ABOUT % "5 g") in body
      and (L.RESPEC_DROPS % ("1 g", when, L.RESPEC_DAYS % 6)) in body, f"a day on: about 5 g, down to 1 g in six days: {body}")
S.server = T0 + 7 * DAY - 3600
G.Fire("GOSSIP_SHOW")
check((L.RESPEC_TODAY % G.date("%H:%M", drop)) in rnote.body.text or (L.RESPEC_TOMORROW % G.date("%H:%M", drop)) in rnote.body.text,
      "the day it drops: today (or tomorrow, past midnight)")


def price(paid, days, seen=None, cost=None):
    rec = lua.table(reset=T0, paid=paid * 10000)
    if seen is not None:
        rec.seen, rec.cost = T0 + seen * DAY, cost * 10000
    out = tuple(ns.RespecPrice(rec, T0 + days * DAY)) + (None, None)
    return out[0] / 10000, out[1], out[2], out[3] and out[3] / 10000


check(price(10, 1) == (15, None, T0 + 7 * DAY, 10), f"paid 10 g: 15 g that week, then 10 g: {price(10, 1)}")
check(price(10, 8) == (10, None, T0 + 14 * DAY, 5), "a week on: 10 g, then 5 g")
check(price(10, 15) == (5, None, T0 + 21 * DAY, 1), "two weeks: 5 g, then 1 g")
check(price(10, 22)[:3] == (1, None, None), "three weeks: 1 g, the lowest")
check(price(50, 1) == (50, None, T0 + 7 * DAY, 45) and price(1, 1)[0] == 5, "50 g at most; after the first, 5 g")
check(price(10, 3, 2, 20)[:2] == (20, True), "the trainer asked more than worked out: its price counts")
check(price(10, 8, 2, 20)[:2] == (15, None), "and a week later, a step under it")
# The legacy tree's reset, kept apart
G.Fire("CONFIRM_TALENT_WIPE", 100000, 1)
G.RunTimers()
G.Fire("GOSSIP_SHOW")
body = rnote.body.text
check(L.RESPEC_CLASS in body and L.RESPEC_LEGACY in body and body.index(L.RESPEC_CLASS) < body.index(L.RESPEC_LEGACY),
      "class talents and the legacy tree, each with its own price")
out = slash("talentos" if es else "respec")
check(any(L.RESPEC_TITLE in line for line in out) and any(L.RESPEC_LEGACY in line for line in out), "and in the chat")
db.respec.enabled = False
G.Fire("GOSSIP_CLOSED")
G.Fire("GOSSIP_SHOW")
check(not rnote.shown, "the option off: no note")
db.respec.enabled = True
S["class"] = "MAGE"
G.Fire("GOSSIP_SHOW")
check(not rnote.shown, "another class: not this addon's trainer")
S["class"] = "HUNTER"

# ---------------------------------------------------------------- Tracking in dungeons and raids
tb, tlist, trows = ns.TrackingButton()
G.TRACKING = lua.eval("""{
  { name = "Find Minerals", texture = 136025, active = true, type = "spell", subType = -1, spellID = 2580 },
  { name = "Track Beasts", texture = 132328, active = false, type = "spell", subType = 1, spellID = 1494 },
  { name = "Track Humanoids", texture = 135942, active = false, type = "spell", subType = 1, spellID = 19883 },
  { name = "Track Hidden", texture = 132320, active = false, type = "spell", subType = 1, spellID = 19885 },
  { name = "Flight Master", texture = 1, active = true, type = "other", subType = 2 },
}""")
T = G.TRACKING
S.known[24295] = True  # three points in Improved Tracking
S.instance = None
G.Fire("PLAYER_ENTERING_WORLD")
check(not tb.shown, "out in the world with minerals on: nothing, by default")
db.tracking.anywhere = True
ns.UpdateTracking()
check(tb.shown and tb.wrong == L.TRACK_WRONG % "Find Minerals", "out in the world too, if you want")
S.taxi = True
G.Fire("PLAYER_CONTROL_LOST")
check(not tb.shown, "not on a flight")
S.taxi = None
db.tracking.anywhere = False
G.Fire("PLAYER_CONTROL_GAINED")
check(not tb.shown, "back to dungeons and raids only")
S.instance, S.instanceID = "party", 36
G.Fire("PLAYER_ENTERING_WORLD")
check(tb.shown and tb.wrong == L.TRACK_WRONG % "Find Minerals" and not tb.text and tb.icon.tex == 135942,
      f"a dungeon with minerals on: the reminder says what's on: {tb.wrong}")
check(not tlist.shown, "the list starts closed")
tb.scripts.OnClick(tb, "LeftButton")
check(tlist.shown and trows[1].shown and trows[2].shown and len(trows) == 2,
      "a click: the list, one bar per creature tracking (Track Hidden left out)")
check(trows[1].attrs.type == "spell" and trows[1].attrs.spell == "Track Humanoids" and trows[2].attrs.spell == "Track Beasts"
      and trows[1].text.text == "Track Humanoids" and trows[1].icon.tex == 135942, "Humanoids first, then Beasts: icon and name on each bar")
tb.scripts.OnClick(tb, "LeftButton")
check(not tlist.shown, "another click closes it")
tb.scripts.OnClick(tb, "LeftButton")
trows[2].hooks.OnClick(trows[2], "LeftButton", True)
check(tlist.shown, "pressing a bar: the spell goes off")
trows[2].hooks.OnClick(trows[2], "LeftButton", False)
check(not tlist.shown, "letting go: the list closes")
T[1].active, T[2].active = False, True
G.Fire("MINIMAP_UPDATE_TRACKING")
check(not tb.shown and db.tracking.last == "Track Beasts", "Beasts on: gone, and Beasts is the one you use")
T[2].active, T[4].active = False, True
G.Fire("MINIMAP_UPDATE_TRACKING")
check(tb.shown and tb.wrong == L.TRACK_WRONG % "Track Hidden" and tb.icon.tex == 132328,
      "Track Hidden doesn't count: back, with Beasts' icon")
tb.scripts.OnClick(tb, "LeftButton")
check(abs(trows[2].text.color[1] - 1) < 1e-6 and abs(trows[1].text.color[1] - 0.93) < 1e-6, "the one you use in gold")
tb.scripts.OnClick(tb, "LeftButton")
T[4].active = False
G.Fire("MINIMAP_UPDATE_TRACKING")
check(tb.shown and tb.wrong == L.TRACK_NONE, "nothing on: says so")
# A fight: the reminder still follows, the list waits
S.combat = True
tb.scripts.OnClick(tb, "LeftButton")
check(not tlist.shown, "in a fight the list doesn't open")
T[3].active = True
G.Fire("MINIMAP_UPDATE_TRACKING")
check(not tb.shown, "Humanoids on in a fight: gone straight away")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
T[3].active = False
G.Fire("MINIMAP_UPDATE_TRACKING")
# Improved Tracking
S.known[24295] = None
G.Fire("MINIMAP_UPDATE_TRACKING")
check(not tb.shown, "no points in Improved Tracking: nothing")
db.tracking.onlyTalent = False
ns.UpdateTracking()
check(tb.shown, "unless you want it anyway")
db.tracking.onlyTalent = True
S.known[24297] = True
ns.UpdateTracking()
check(tb.shown, "five points: there")
# Right-click: not in this dungeon
tb.scripts.OnClick(tb, "RightButton")
check(not tb.shown, "right-click: hidden")
G.Fire("PLAYER_ENTERING_WORLD")
check(not tb.shown, "still hidden in the same dungeon")
S.instanceID = 48
G.Fire("PLAYER_ENTERING_WORLD")
check(tb.shown, "another dungeon: back")
S.instance = "raid"
G.Fire("PLAYER_ENTERING_WORLD")
check(tb.shown, "raids too")
S.instance = "pvp"
G.Fire("PLAYER_ENTERING_WORLD")
check(not tb.shown, "not in battlegrounds")
S.instance = "party"
db.tracking.enabled = False
ns.UpdateTracking()
check(not tb.shown, "the option off: nothing")
db.tracking.enabled = True
# Forever's own IDs: a hunter tracking by its kind, Track Hidden by its name
G.TRACKING = lua.eval("""{
  { name = "Find Herbs", texture = 1, active = true, type = "spell", subType = -1, spellID = 2383 },
  { name = "Track Hidden", texture = 2, active = false, type = "spell", subType = 1, spellID = 1999885 },
  { name = "Track Dragonkin", texture = 3, active = false, type = "spell", subType = 1, spellID = 1999879 },
}""")
ns.UpdateTracking()
tb.scripts.OnClick(tb, "LeftButton")
check(tb.shown and trows[1].attrs.spell == "Track Dragonkin" and not trows[2].shown, f"other IDs: still told apart: {trows[1].attrs.spell}")
tb.scripts.OnClick(tb, "LeftButton")
G.TRACKING = lua.eval('{ { name = "Find Herbs", texture = 1, active = true, type = "spell", subType = -1, spellID = 2383 } }')
ns.UpdateTracking()
check(not tb.shown, "no creature tracking learnt yet: nothing to remind")
out = slash("rastreos" if es else "trackinglist")
check(len(out) == 2 and "Improved Tracking" in out[0] and "Find Herbs" in out[1], f"/huntergod trackinglist: the talent and each tracking: {out}")
# Trying it anywhere
G.TRACKING = T
T[2].active = True
S.instance = None
G.Fire("PLAYER_ENTERING_WORLD")
check(not tb.shown, "out in the world: nothing")
slash("rastreo" if es else "tracking")
check(tb.shown and tb.wrong == L.TRACK_WRONG % "Track Beasts", "/huntergod tracking: there, with what you track now")
tb.scripts.OnClick(tb, "LeftButton")
check(tlist.shown and trows[1].shown and trows[2].shown, "and its list to try")
T[2].active, T[3].active = False, True
G.Fire("MINIMAP_UPDATE_TRACKING")
check(tb.wrong == L.TRACK_WRONG % "Track Humanoids" and abs(trows[1].text.color[1] - 1) < 1e-6, "the list and the text follow what you pick")
S.now = S.now + 21
G.RunTimers()
check(not tb.shown and not tlist.shown, "and it goes after a while")
ns.TestTracking()
tb.scripts.OnClick(tb, "RightButton")
check(not tb.shown, "a right-click ends the test")
T[3].active = False
db.tracking.anywhere = True
ns.UpdateTracking()
check(tb.shown, "out in the world with nothing on, if you want it there: there")
tb.scripts.OnClick(tb, "RightButton")
check(not tb.shown, "right-click: not in this zone")
ns.SetUnlocked(True)
check(tb.shown and tb.wrong == L.TRACK_NONE and G.NAMED["HunterGodReminders"].mover.shown, "unlocked: a sample, dragged with the row")
tb.scripts.OnClick(tb, "LeftButton")
check(not tlist.shown, "no list while dragging")
ns.SetUnlocked(False)
check(not tb.shown, "locked: gone")

# ---------------------------------------------------------------- The row of reminders
rgroup = G.NAMED["HunterGodReminders"]
asp, ts, tb = G.NAMED["HunterGodAspect"], G.NAMED["HunterGodTrueshot"], G.NAMED["HunterGodTracking"]
check(asp.width == 40 and ts.width == 40 and tb.width == 40, "the three icons the same size")
saved = (asp.shown, ts.shown, tb.shown)
asp.shown, ts.shown, tb.shown = False, False, True
ns.LayoutReminders()
check(tb.point[4] == 0 and G.Same(tb.point[2], rgroup), f"one: in the middle ({tb.point[4]})")
asp.shown = True
ns.LayoutReminders()
check(asp.point[4] == -25 and tb.point[4] == 25, f"two: side by side, centred ({asp.point[4]}, {tb.point[4]})")
ts.shown = True
ns.LayoutReminders()
check(asp.point[4] == -50 and ts.point[4] == 0 and tb.point[4] == 50 and rgroup.width == 140,
      f"three: aspect, Trueshot and tracking, centred ({asp.point[4]}, {ts.point[4]}, {tb.point[4]})")
asp.shown, ts.shown, tb.shown = saved
ns.LayoutReminders()
check(not G.NAMED["HunterGodTracking"].scripts.OnClick is None and tb.arrow.tex.endswith("arrow"), "the tracking icon has its arrow")

# ---------------------------------------------------------------- Procs: wind and a target around you
S.secret = False
S.combat = False
MEDIA = "Interface\\AddOns\\HunterGod\\media\\"


def pboxes():
    return [f for f in G.FRAMES.values() if f.kind == "AuraContainer" and f.unit == "player"]


def pwatched(b):
    return sorted(b.slot.opts.candidateFilters.includeSpellIDs.keys())


def files(art):
    return [e[1].tex for e in art.tinted.values()]


def tints(art):
    return [tuple(round(c, 2) for c in e[1].vertex.values()) for e in art.tinted.values()]


def spots(art):
    return {(e[1].points[1][4], e[1].points[1][5], e[2]) for e in art.placed.values()}


speed, kill = ns.ProcsState("speed"), ns.ProcsState("kill")
check(len(pboxes()) == 2 and all(b.slot.filter == "HELPFUL" and b.enabled for b in pboxes()),
      "an aura container for each proc, on your buffs, built at login")
check(pwatched(speed.container) == [6150, 1299448] and pwatched(kill.container) == [415407],
      f"Quick Shots and Quick Strikes, and Rapid Killing: {pwatched(speed.container)}, {pwatched(kill.container)}")
sb, kb = speed.container.button, kill.container.button
check(len(sb.shownAnims) == 3 and len(sb.assignedAnims) == 3,
      "the wind: two columns and their breath to loop, a gust for when it procs")
check(len(kb.shownAnims) == 2 and len(kb.assignedAnims) == 4, "the target: its turn and breath, and its landing")
wind, target = speed.dressed, kill.dressed
check(wind is not None and wind.ready and target is not None and target.ready, "the game takes them")
check(files(wind).count(MEDIA + "wind_glow") == 4 and files(wind).count(MEDIA + "wind_core") == 4,
      "two columns of wind, calm and burst")
check(files(target).count(MEDIA + "ring_core") == 2 and files(target).count(MEDIA + "ring_base") == 2,
      "a target on the ground, calm and burst")
check(wind.calm.alpha == 0.2 and wind.strike.alpha == 0.6, "the burst stronger, the calm fainter, both see-through")
check({(x * side, y) for x, y, side in spots(wind)} == {(140, 0)} and {side for _, _, side in spots(wind)} == {-1, 1},
      f"140 out from the middle on each side: {spots(wind)}")
check(spots(target) == {(0, -150, 0)}, f"the target in the middle, at your feet: {spots(target)}")
check(tints(wind)[0] == (0.67, 0.83, 0.45) and tints(wind)[2][0] > 0.85, f"the hunter's green, the cores nearly white: {tints(wind)[:3]}")
check(tints(target)[0] == (1, 0.38, 0.18), f"the target red: {tints(target)[0]}")
timer = sb.durationText
rules = timer and timer.options and timer.options.textFormatter.rules
check(timer is not None and G.Same(timer.text, wind.timer) and rules[2].format == "%d" and rules[2].rounding == 2,
      "the seconds it has left: the game writes them, whole and rounded up")
check(wind.timer.font[2] == 20 and target.timer.font[2] == 16 and wind.timer.shown and target.timer.shown,
      "the target's seconds a little smaller, inside it")
holder, place = speed.holder, speed.place
check(place.point[1] == "CENTER" and G.Same(place.point[2], G.UIParent) and place.point[5] == -20
      and G.Same(holder.point[2], place) and holder.scale == 0.4 and kill.holder.scale == 0.4,
      "around you: a bit under the middle, at 40%")
for saved, fresh, want in ((dict(size=60, alpha=85, calm=35), False, (40, 60, 20)),
                           (dict(size=80, alpha=85, calm=10), False, (80, 60, 10)),
                           (dict(size=60, alpha=85, calm=35, v=2), False, (60, 85, 35))):
    old = lua.table(procs=lua.table(size=saved["size"], alpha=saved["alpha"], calm=saved["calm"]), version=saved.get("v"))
    ns.MigrateSettings(old, fresh)
    got = (old.procs.size, old.procs.alpha, old.procs.calm)
    check(got == want and old.version == 2, f"settings from 1.5.0 {saved}: what was left as it came gets smaller and fainter {got}")
fresh_db = lua.table()
ns.MigrateSettings(fresh_db, True)
check(fresh_db.version == 2, "new settings start at the current version")
check(not speed.spot.shown, "the samples are hidden")

S.auras = lua.table("Quick Shots")
S.auraTimes = lua.table_from({"Quick Shots": lua.table(S.now + 10, 12)})
S.auraIDs = lua.table_from({"Quick Shots": 999001})
G.Fire("UNIT_AURA", "player")
new = ns.ProcsState("speed").container
check(not G.Same(new, speed.container) and pwatched(new) == [6150, 999001, 1299448] and not speed.container.enabled
      and not holder.shown, f"a Quick Shots with another number: a new container watches it too, the old one is off: {pwatched(new)}")
check(db.procs.learned[999001] == "speed" and G.Same(ns.ProcsState("kill").container, kill.container),
      "it's remembered as the wind's, and the target is left alone")
S.auras = lua.table("Quick Strikes")
S.auraTimes = lua.table_from({"Quick Strikes": lua.table(0, 0)})
S.auraIDs = lua.table_from({"Quick Strikes": 1299448})
G.Fire("UNIT_AURA", "player")
check(pwatched(ns.ProcsState("speed").container) == [6150, 999001] and db.procs.ignored[1299448],
      "one that never ends is a passive: left out")
built = len(pboxes())
S.combat = True
S.auras = lua.table("Rapid Killing")
S.auraTimes = lua.table_from({"Rapid Killing": lua.table(S.now + 15, 20)})
S.auraIDs = lua.table_from({"Rapid Killing": 999002})
G.Fire("UNIT_AURA", "player")
check(len(pboxes()) == built, "in combat it waits")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
check(len(pboxes()) == built + 1 and pwatched(ns.ProcsState("kill").container) == [415407, 999002],
      "and builds it when the fight is over")
S.secret = True
S.auraIDs = lua.table_from({"Rapid Killing": 999003})
G.Fire("UNIT_AURA", "player")
check(not db.procs.learned[999003], "with your buffs hidden it learns nothing")
S.secret = False
S.auras = lua.table("Aspect of the Hawk")
S.auraIDs = None
G.Fire("UNIT_AURA", "player")

speed, kill = ns.ProcsState("speed"), ns.ProcsState("kill")
out = slash("procs")
spot, ws, ks = speed.spot, speed.sample, kill.sample
check(spot.shown and speed.sampleFrame.shown and kill.sampleFrame.shown
      and all(g.playing for g in ws.shown.values()) and ws.assigned[1].playing and ks.assigned[1].playing,
      "trying them shows both samples, playing")
check(len(out) == 2 and "6150, 999001" in out[0] and "415407, 999002" in out[1], f"and says what each watches: {out}")
spot.scripts.OnUpdate(spot, 0.1)
first = (ws.timer.text, ks.timer.text)
S.now = S.now + 3
spot.scripts.OnUpdate(spot, 0.1)
check(first == ("12", "20") and (ws.timer.text, ks.timer.text) == ("9", "17"),
      f"the samples count down as the buffs would: {first}, {ws.timer.text}, {ks.timer.text}")
S.now = S.now + 5
G.RunTimers()
check(not spot.shown and not ws.shown[1].playing, "a few seconds later they're gone")
ns.TestProcs("kill")
check(spot.shown and kill.sampleFrame.shown and not speed.sampleFrame.shown, "each can be tried on its own")
S.now = S.now + 6
G.RunTimers()

db.positions.procs = lua.table("CENTER", "CENTER", 100, 40)
ns.ToggleOptions("procs")
pcontrols = {c.setting: c for c in page["procs"].controls.values()}
size = pcontrols[L.OPT_PROCS_SIZE]
size.scripts.OnValueChanged(size, 200)
holder, place = speed.holder, speed.place
check(db.procs.size == 200 and holder.scale == 2 and kill.holder.scale == 2 and spot.scale == 2 and place.width == 780,
      f"size: twice as big ({place.width})")
check(place.point[4] == 100 and place.point[5] == 40, "in the same place")
check(spot.shown, "changing it shows the samples a moment")
size.scripts.OnValueChanged(size, 100)
x, y = pcontrols[L.OPT_PROCS_X], pcontrols[L.OPT_PROCS_Y]
x.scripts.OnValueChanged(x, -120)
y.scripts.OnValueChanged(y, -60)
check(tuple(db.positions.procs.values()) == ("CENTER", "CENTER", -120, -60) and place.point[4] == -120 and place.point[5] == -60,
      f"left, right, up and down from the options: {tuple(db.positions.procs.values())}")
wind = speed.dressed
gap = pcontrols[L.OPT_PROCS_GAP]
gap.scripts.OnValueChanged(gap, 220)
check({x * side for x, _, side in spots(wind)} == {220} and place.width == 550, "and the space between the wind's sides")
check(spots(kill.dressed) == {(0, -150, 0)}, "the target stays in the middle")
calm, burst = pcontrols[L.OPT_PROCS_CALM], pcontrols[L.OPT_PROCS_ALPHA]
calm.scripts.OnValueChanged(calm, 15)
burst.scripts.OnValueChanged(burst, 100)
check(wind.calm.alpha == 0.15 and wind.strike.alpha == 1 and kill.dressed.calm.alpha == 0.15 and ws.calm.alpha == 0.15,
      "the burst's strength and the calm's, for both")
S.combat = True
gap.scripts.OnValueChanged(gap, 260)
check({x * side for x, _, side in spots(wind)} == {220} and {x * side for x, _, side in spots(ws)} == {260},
      "in a fight the game's drawing can't be touched, the sample can")
S.combat = False
G.Fire("PLAYER_REGEN_ENABLED")
check({x * side for x, _, side in spots(wind)} == {260}, "the fight over, it's fitted")
db.positions.procs = lua.table("BOTTOMLEFT", "BOTTOMLEFT", 700, 420)
place.GetCenter = lua.eval("function() return 700, 420 end")
saved_center = G.UIParent.GetCenter
G.UIParent.GetCenter = lua.eval("function() return 600, 400 end")
place.mover.hooks.OnDragStop()
check(tuple(db.positions.procs.values()) == ("CENTER", "CENTER", 100, 20), "dragged: kept as an offset from the middle")
G.UIParent.GetCenter = saved_center
switch = pcontrols[L.OPT_PROC_SPEED.replace("%s", ns.ProcName("speed"))]
check(ns.ProcName("speed") == "Quick Shots / Quick Strikes", f"the wind's section names both: {ns.ProcName('speed')}")
switch.checked = False
switch.scripts.OnClick(switch)
check(not db.procs.speed.enabled and not holder.shown and kill.holder.shown, "the wind switched off: the game shows nothing of it")
switch.checked = True
switch.scripts.OnClick(switch)
check(db.procs.speed.enabled and holder.shown, "and on again")
colours = [c for c in page["procs"].controls.values() if c.setting == L.OPT_PROC_COLOR]
check(len(colours) == 2, "a colour for each")
colours[0].scripts.OnClick(colours[0])
G.COLOR_INFO.swatchFunc()
check(tints(wind)[0] == (0, 0, 1) and tints(kill.dressed)[0] == (1, 0.38, 0.18), "the wind's colour is yours to pick")
G.COLOR_INFO.cancelFunc()
check(tints(wind)[0] == (0.67, 0.83, 0.45), "and back")
timer_on = pcontrols[L.OPT_PROCS_TIMER]
timer_on.checked = False
timer_on.scripts.OnClick(timer_on)
check(not wind.timer.shown and not kill.dressed.timer.shown and not ws.timer.shown, "the seconds can go")
timer_on.checked = True
timer_on.scripts.OnClick(timer_on)
check(wind.timer.shown, "and come back")
ns.SetUnlocked(True)
check(speed.sampleFrame.shown and kill.sampleFrame.shown and place.mover.shown, "unlocked: both samples, to drag")
ns.SetUnlocked(False)
S.now = S.now + 6
G.RunTimers()
check(not spot.shown, "locked again: gone")
win.Hide(win)

print()
print("FAILURES:" if fails else f"All good ({LOCALE}).", fails if fails else "")
sys.exit(1 if fails else 0)
