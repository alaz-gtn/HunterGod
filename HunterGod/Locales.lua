local _, ns = ...

local L = {
	PREFIX = "|cffabd473HunterGod:|r ",
	-- World map
	VENDOR = "Ammo vendor",
	MAP = "map %d",
	SELLS_BOTH = "Sells arrows and bullets",
	SELLS_ARROWS = "Sells arrows",
	SELLS_BULLETS = "Sells bullets",
	HUNTER_TRAINER = "Hunter trainer",
	STABLE_MASTER = "Stable master",
	ARROWS_BOX = "Arrows",
	BULLETS_BOX = "Bullets",
	TRAINERS_BOX = "Hunter trainers",
	STABLES_BOX = "Stable masters",
	FOOD_BOX = "Pet food",
	FOOD_VENDOR = "Sells food your pet eats",
	FOOD_SELLS = "%s up to level %d",
	FOOD_TYPES = { "Meat", "Fish", "Cheese", "Bread", "Fungus", "Fruit" },
	OUTGROWN = "Basic ammo only: useful up to level %d",
	USEFUL_UNTIL = "Ammo useful up to level %d",
	ALLIANCE_ONLY = "Alliance only",
	HORDE_ONLY = "Horde only",
	LEARNED = "Recorded by you",
	CLICK = "Click: set waypoint",
	NO_WAYPOINT = "can't set a waypoint on that map.",
	WAYPOINT = "waypoint set to %s (%s %.1f, %.1f).",
	NOT_AMMO = "%s doesn't sell ammo: removed from the map.",
	NEW_VENDOR = "new vendor recorded: %s (%s), %s %.1f, %.1f.",
	NONE_NEAR = "no useful vendor on this continent.",
	OLD_ADDON = "the old version %s is also installed and draws its own pins on the map: delete its folder from AddOns.",
	BOTH = "arrows and bullets",
	ARROWS = "arrows",
	BULLETS = "bullets",
	MODE = {
		both = "arrows and bullets",
		arrows = "arrows only",
		bullets = "bullets only",
		none = "no ammo",
	},
	STATUS = "showing %s; hunter trainers %s; stable masters %s; %s; minimap %s; continent map %s; %s. Vendors recorded by you: %d.",
	ALL_FACTIONS = "all factions",
	OWN_FACTION = "your faction only",
	YES = "on",
	NO = "off",
	HUNTERS_ONLY = "hunters only",
	ANY_CLASS = "any class",
	-- Range
	RANGE = {
		ranged = "In range",
		far = "Max range",
		melee = "Melee",
		dead = "Dead zone",
		out = "Out of range",
		hit = "Melee",
		approach = "Get closer",
	},
	YARDS = "yd",
	METERS = "m",
	-- Aspects
	ASPECT_TRAVEL = "%s in combat!",
	ASPECT_MISSING = "No %s",
	ASPECT_NONE = "No aspect",
	ANY_ASPECT = "Any aspect",
	-- Ranged or melee (Survival)
	SEC_PLAYSTYLE = "How you fight",
	OPT_PLAYSTYLE = "Ranged or melee",
	PLAYSTYLE = { auto = "By your talents", ranged = "Ranged", melee = "Melee (Survival)" },
	STYLE_NOW_MELEE = "melee talents: melee mode (your melee aspect, green in melee, no blinking warnings).",
	STYLE_NOW_RANGED = "no melee talents: back to ranged mode.",
	STYLE_REPORT = "style: %s, %s.",
	STYLE_CHOSEN = "chosen in the options",
	STYLE_FOUND = "by your talents: you know %s",
	STYLE_NONE = "by your talents: you know none of %s",
	OPT_PREFERRED_MELEE = "Your aspect in melee",
	-- Ammo
	NO_AMMO = "No ammo",
	AMMO_LOW = "only %d %s left: time to buy more.",
	AMMO_MERCHANT = "this vendor sells %s and you only have %d.",
	-- Pet food
	PET_FOOD = "Pet food",
	PET_NO_FOOD = "No food for your pet",
	PET_LOW = "Little food for your pet: %d",
	PET_LOW_LEVEL_FOOD = "Low level for your pet: it pleases it less",
	PET_FEED_TIP = "Click: feed your pet",
	PET_MERCHANT = "food for your pet here: %s.",
	PET_INFO_NONE = "you don't have a pet out.",
	PET_INFO = "pet: %s, level %d. Eats: %s (%s).",
	PET_DIET_UNKNOWN = "unknown",
	DIET_FROM = { game = "the game says so", family = "worked out from its family" },
	PET_INFO_FOOD = "%d pieces of its food in your bags; %d vendors with its food on the map.",
	FOOD_LINE = "  %s x%d: %s, level %d - %s",
	FOOD_EATS = "it eats it",
	FOOD_TOO_LOW = "too low level for your pet",
	FOOD_NOT_DIET = "not in its diet",
	FOOD_UNKNOWN = "  %s x%d: food the addon doesn't know",
	-- Growl in groups
	GROWL_ON = "%s on autocast!",
	GROWL_MSG = "%s is on autocast: right-click it on the pet bar so your pet doesn't take the aggro off the tank.",
	OPT_GROWL = "Warn if Growl is on autocast in dungeons and raids",
	OPT_GROWL_GROUPS = "Also in any group",
	GROWL_MISS = "%s Miss",
	OPT_GROWL_MISS = "Growl Miss when Growl doesn't pull the mob onto your pet",
	-- Happiness and health
	NOT_HAPPY = "NOT HAPPY",
	PET_HEALTH = "HEAL YOUR PET! %d%%",
	PET_HEALTH_NAME = "Pet health",
	OPT_NOT_HAPPY = "NOT HAPPY over the pet's portrait when it isn't happy",
	OPT_PET_HEALTH = "Tell me to heal my pet when its health drops",
	OPT_PET_HEALTH_PCT = "Below (% health)",
	OPT_WRATH = "%s on the pet's portrait, with its time left",
	-- Pet level ups and training points
	PET_TOAST_NAME = "Pet level up",
	PET_LEVEL_TOAST = "Level %d!",
	PET_TP_TITLE = "Training points!",
	PET_TP_TOAST = "+%d training points · %d to spend",
	PET_LEVEL_MSG = "%s reached level %d!",
	PET_TP_MSG = "%s earned %d training points: %d to spend.",
	OPT_PET_LEVEL = "Celebrate when your pet levels up",
	OPT_PET_TP = "Tell me when it earns training points",
	OPT_PET_SOUND = "With sound",
	-- Moving the displays
	UNLOCK = "Unlock to move",
	LOCK = "Lock",
	UNLOCKED = "displays unlocked: drag them where you want, then lock them (right-click the minimap button).",
	LOCKED = "displays locked.",
	NOT_IN_COMBAT = "can't do that in combat.",
	-- Minimap button
	TIP_AMMO = "Ammo: %d",
	TIP_PET_FOOD = "Pet food: %d",
	TIP_LEFT = "Left-click: options",
	TIP_RIGHT_UNLOCK = "Right-click: unlock the displays to move them",
	TIP_RIGHT_LOCK = "Right-click: lock the displays",
	TIP_DRAG = "Drag: move this button",
	-- Options
	TAB_MAP = "Map",
	TAB_RANGE = "Range",
	TAB_ASPECTS = "Aspects",
	TAB_COMBAT = "Combat",
	SUBTITLE = "Quality of life for hunters",
	SEC_PINS = "Pins",
	SEC_WHICH = "Where and which",
	SEC_DISTANCE = "When and what",
	SEC_LOOK = "Look",
	SEC_TRAPS = "Traps",
	SEC_MELEE = "Melee range",
	SEC_THREAT = "Aggro",
	SEC_AMMO = "Low ammo",
	SEC_FOOD = "Food",
	SEC_PET_STATUS = "Health and happiness",
	SEC_PET_TOAST = "Level ups",
	PREVIEW_HINT = "Click a sample to change its colour",
	TRAPS_READY = "TRAPS READY",
	-- Tracking in dungeons and raids
	SEC_TRACKING = "Tracking",
	OPT_TRACKING = "In dungeons and raids, remind me when I'm not tracking creatures",
	OPT_TRACKING_WORLD = "Out in the world too",
	TRACKING_HINT = "With herbs, minerals, Track Hidden or nothing on, it shows until you track a creature type. Click it for the list of your creature trackings and pick one; right-click leaves that dungeon or zone alone.",
	OPT_TRACKING_TALENT = "Only with points in %s",
	OPT_TRACKING_TEST = "See how it looks in a dungeon",
	TRACK_TALENT = "%s: %s",
	TRACK_TITLE = "Tracking",
	TRACK_WRONG = "Tracking %s",
	TRACK_NONE = "Not tracking creatures",
	TRACK_CLICK = "Click: choose a tracking",
	TRACK_RIGHT = "Right-click: not here (this dungeon or zone)",
	TRACK_NO_API = "the game doesn't list its tracking to addons here.",
	TRACK_ON = "on",
	TRACK_OFF = "off",
	TRACK_CREATURE = "creatures",
	OPT_TRAPS = "TRAPS READY when your traps are back after using one in a fight",
	OPT_FREEZE = "Time left in your %s, beside the frozen mob's nameplate",
	TRUESHOT = "Trueshot Aura",
	OPT_TRUESHOT = "Remind me of %s in its last 2 minutes",
	OPT_MELEE_ALPHA = "MELEE RANGE opacity (%)",
	THREAT = "AGGRO %d%%",
	THREAT_PULLED = "YOU HAVE AGGRO!",
	THREAT_NAME = "Threat",
	OPT_THREAT = "Warn under the target's nameplate before you pull aggro off your pet",
	OPT_THREAT_PCT = "Warn from (% of aggro)",
	TAB_AMMO = "Ammo",
	TAB_PET = "Pet",
	TAB_SWING = "Swing timers",
	TAB_PROCS = "Procs",
	PROCS_NAME = "Procs",
	PROCS_WATCHING = "%s: watching spells %s.",
	PROCS_NOT_READY = "%s isn't set up yet: the addon builds it out of combat.",
	PROCS_REFUSED = "the game didn't take the animations for %s, so they won't show.",
	OPT_PROC_SPEED = "Wind up both sides of you with %s",
	OPT_PROC_KILL = "A target turning at your feet with %s",
	OPT_PROC_COLOR = "Colour",
	OPT_PROC_TEST = "See how it looks",
	OPT_PROCS_SIZE = "Size (%)",
	OPT_PROCS_X = "Left or right",
	OPT_PROCS_Y = "Down or up",
	OPT_PROCS_GAP = "Space between the two sides of the wind",
	OPT_PROCS_ALPHA = "Strength as it procs (%)",
	OPT_PROCS_CALM = "Strength afterwards, while it lasts (%)",
	OPT_PROCS_TIMER = "The seconds they have left",
	OPT_PROCS_TIMER_SIZE = "Size of the number",
	PROCS_HINT = "Quick Shots and Quick Strikes come from Deadly Aspects: 30% faster shots or swings for 12 seconds. Rapid Killing makes your next Shot deal 20% more. A burst as each procs, then a calmer version while it lasts. The game itself shows them, so they work in combat too; changes made in a fight wait until it's over. You can also drag them with Move displays.",
	-- Talent reset price, under the class trainer's window
	SEC_RESPEC = "Class trainer",
	OPT_RESPEC = "When the talent reset price drops, under your trainer's window",
	RESPEC_HINT = "Blizzard doesn't publish it: players report a step up with each reset (1, 5, 10, then 5 g more up to 50 g) and a step down for each week since the last one. The price the trainer asks is the real one.",
	RESPEC_TITLE = "Talent reset",
	RESPEC_CLASS = "Class talents",
	RESPEC_LEGACY = "Legacy talents",
	RESPEC_LAST = "Last one %s ago, for %s",
	RESPEC_NOW = "Now: %s",
	RESPEC_NOW_ABOUT = "Now: about %s",
	RESPEC_DROPS = "Drops to %s %s (in %s)",
	RESPEC_LOWEST = "It's at its lowest",
	RESPEC_ASKED = "The trainer asked %s, %s ago",
	RESPEC_UNKNOWN = "%s doesn't know when you last reset yet: it writes it down the next time you pay for one.",
	RESPEC_TODAY = "today at %s",
	RESPEC_TOMORROW = "tomorrow at %s",
	RESPEC_ON = "on %s at %s",
	RESPEC_WEEKDAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" },
	RESPEC_MINUTES = "%d min",
	RESPEC_HOURS = "%d h",
	RESPEC_DAYS = "%d days",
	SWING_NAME = "Swing timers",
	SEC_SWING = "A bar for each weapon",
	OPT_SWING_ON = "Swing timer bars",
	OPT_SWING_RANGED = "Auto Shot",
	OPT_SWING_MAIN = "Main hand",
	OPT_SWING_OFF = "Off hand",
	OPT_SWING_BLIZZARD = "Hide Blizzard's swing timers",
	OPT_SWING_BY_RANGE = "Only the bars for where you are: the melee ones in melee range, Auto Shot further away",
	OPT_SWING_WIDTH = "Width",
	OPT_SWING_HEIGHT = "Height",
	OPT_SWING_TIME = "Seconds to the next swing",
	OPT_SWING_ICON = "The weapon's icon on the left",
	OPT_SWING_WINDUP = "Mark Auto Shot's last half second (moving holds the shot back)",
	OPT_SWING_COLOR = "Colour: %s",
	OPT_SWING_TEST = "See them swing",
	TRY = "Try it",
	SWING_HINT = "Each bar starts dim, lights up as the swing comes and flashes when it goes. It shows while you attack with that weapon and goes a moment after you stop. Forever tells the game each swing, in combat too. Drag them with Move displays.",
	OPT_FOOD_VENDORS = "Vendors with food for the pet you have out",
	OPT_OTHER_FACTION = "Show the other faction's too",
	OPT_MINIMAP_PINS = "Pins on the minimap",
	OPT_CONTINENT = "Pins on the continent map",
	OPT_ONLY_HUNTER = "Only on hunters",
	OPT_RANGE_ON = "Show how far away your target is",
	MELEE_WARNING = "MELEE RANGE",
	OPT_MELEE_WARNING = "Blinking MELEE RANGE warning when you're in melee (ranged)",
	OPT_ONLY_COMBAT = "Only in combat",
	OPT_DISPLAY = "Show",
	DISPLAY = { number = "A number (estimated)", bracket = "The range between checks" },
	OPT_FONT = "Font",
	FONTS = { fredoka = "Fredoka (round)", changa = "Changa (like GoodRange)", game = "The game's" },
	OPT_UNITS = "Distance in",
	UNITS = { yards = "Yards", meters = "Metres" },
	UNITS_SET = "distance in %s.",
	RANGE_NO_TARGET = "you have no target.",
	DR_NO_API = "this game has no diminishing returns for addons.",
	DR_STATUS = "diminishing returns: system %s; the game's PvP option %s, only the ones you cause %s.",
	DR_OPTION = "(the game's option is \"%s\", in Options, Gameplay)",
	DR_RULESET = "%s categories (name, number, tracked): %s",
	DR_NONE = "none",
	DR_ON = "logging diminishing returns: freeze someone and what the game sends shows up here. /huntergod dr again to stop.",
	DR_OFF = "stopped logging diminishing returns.",
	DR_NO_EVENT = "the game doesn't send diminishing returns to addons.",
	DR_EVENT = "DR %s (%s) at %s: %s",
	DR_SECRET = "secret",
	RANGE_REPORT = "target: %s, %d-%d yd (Auto Shot reaches %d yd). Auto Shot in range: %s; melee: %s.",
	RANGE_STEPS = "steps (yd:in range?): ",
	RANGE_LOADING = "(some items still loading)",
	RANGE_YES = "yes",
	RANGE_NO = "no",
	OPT_DEAD_LABEL = "Write \"%s\" and \"%s\" instead of the number",
	OPT_UNIT_LABEL = "Show yd or m after the number",
	REMINDERS = "Reminders",
	CLICK_CAST = "Click: %s",
	OPT_FAR = "Light blue and glowing in the last 5 yards of your reach",
	OPT_STYLE = "Style",
	STYLE = { text = "Text", icon = "Colour square", both = "Square and text" },
	OPT_POSITION = "Position",
	POSITION = { plate = "On the target's nameplate", free = "Where I put it" },
	OPT_PLATE_SIDE = "Side of the nameplate",
	PLATE_SIDE = { top = "Above", bottom = "Below", left = "Left", right = "Right" },
	OPT_PLATE_GAP = "Distance from the nameplate",
	OPT_SIZE = "Size",
	OPT_ASPECT_ON = "Aspect warnings in combat",
	OPT_TRAVEL = "Warn about Cheetah or Pack",
	OPT_MISSING = "Warn when your aspect is missing",
	OPT_MISSING_ALWAYS = "Out of combat too (not while travelling in Cheetah or the Pack, on a flight or mounted)",
	OPT_ASPECT_TEXT = "Write the warning under the icon",
	OPT_PREFERRED = "Your aspect at range",
	OPT_AMMO_ON = "Low ammo warning",
	OPT_THRESHOLD = "Warn below",
	OPT_MERCHANT = "Remind me at vendors",
	OPT_PET_ON = "Pet food",
	OPT_PET_BAR = "Show the food your pet eats",
	OPT_HIDE_COMBAT = "Hide it in combat",
	OPT_PET_LOW = "Warn below",
	OPT_MINIMAP_BUTTON = "Minimap button",
	HELP = {
		"  /huntergod  - options (or click the minimap button)",
		"  /huntergod unlock | lock  - move the displays",
		"  /huntergod meters | yards  - the range in metres or yards",
		"  /huntergod pet  - what the addon knows about your pet",
		"  /huntergod range  - what each range check says about your target",
		"  /huntergod dr  - log what the game says about diminishing returns",
		"  /huntergod style  - ranged or melee, and why",
		"  /huntergod swing  - try the swing timer bars",
		"  /huntergod respec  - when the talent reset price drops",
		"  /huntergod tracking  - try the tracking reminder",
		"  /huntergod trackinglist  - the tracking the game lists, and which count as creatures",
		"  /huntergod procs  - try the proc animations, and what each watches",
		"  /ammo arrows | bullets | both | weapon  - which ammo the map shows",
		"  /ammo nearest  - waypoint to the nearest useful vendor",
		"  /ammo trainers | stables | food | faction | minimap | continent | class | button  - toggle each option",
		"  /ammo status  - what the map shows",
	},
}

if GetLocale() == "esES" or GetLocale() == "esMX" then
	L.VENDOR = "Vendedor de munición"
	L.MAP = "mapa %d"
	L.SELLS_BOTH = "Vende flechas y balas"
	L.SELLS_ARROWS = "Vende flechas"
	L.SELLS_BULLETS = "Vende balas"
	L.HUNTER_TRAINER = "Instructor de cazadores"
	L.STABLE_MASTER = "Maestro de establos"
	L.ARROWS_BOX = "Flechas"
	L.BULLETS_BOX = "Balas"
	L.TRAINERS_BOX = "Instructores"
	L.STABLES_BOX = "Establos"
	L.FOOD_BOX = "Comida de mascota"
	L.FOOD_VENDOR = "Vende comida que come tu mascota"
	L.FOOD_SELLS = "%s hasta nivel %d"
	L.FOOD_TYPES = { "Carne", "Pescado", "Queso", "Pan", "Hongos", "Fruta" }
	L.OUTGROWN = "Solo munición básica: útil hasta nivel %d"
	L.USEFUL_UNTIL = "Munición útil hasta nivel %d"
	L.ALLIANCE_ONLY = "Solo Alianza"
	L.HORDE_ONLY = "Solo Horda"
	L.LEARNED = "Apuntado por ti"
	L.CLICK = "Clic: marcar ruta"
	L.NO_WAYPOINT = "en ese mapa no se puede poner marca de ruta."
	L.WAYPOINT = "ruta marcada a %s (%s %.1f, %.1f)."
	L.NOT_AMMO = "%s no vende munición: lo quito del mapa."
	L.NEW_VENDOR = "nuevo vendedor apuntado: %s (%s), %s %.1f, %.1f."
	L.NONE_NEAR = "no hay ningún vendedor útil en este continente."
	L.OLD_ADDON = "también tienes instalada la versión antigua %s, que pone sus propios pines en el mapa: borra su carpeta de AddOns."
	L.BOTH = "flechas y balas"
	L.ARROWS = "flechas"
	L.BULLETS = "balas"
	L.MODE = {
		both = "flechas y balas",
		arrows = "solo flechas",
		bullets = "solo balas",
		none = "ninguna munición",
	}
	L.STATUS = "mostrando %s; instructores %s; establos %s; %s; minimapa %s; mapa del continente %s; %s. Vendedores apuntados por ti: %d."
	L.ALL_FACTIONS = "todas las facciones"
	L.OWN_FACTION = "solo tu facción"
	L.YES = "sí"
	L.NO = "no"
	L.HUNTERS_ONLY = "solo con cazadores"
	L.ANY_CLASS = "con cualquier clase"
	L.RANGE = {
		ranged = "A distancia",
		far = "Al límite",
		melee = "Cuerpo a cuerpo",
		dead = "Zona muerta",
		out = "Fuera de alcance",
		hit = "Cuerpo a cuerpo",
		approach = "Acércate",
	}
	L.ASPECT_TRAVEL = "¡%s en combate!"
	L.ASPECT_MISSING = "Sin %s"
	L.ASPECT_NONE = "Sin aspecto"
	L.ANY_ASPECT = "Cualquier aspecto"
	L.SEC_PLAYSTYLE = "Cómo luchas"
	L.OPT_PLAYSTYLE = "A distancia o cuerpo a cuerpo"
	L.PLAYSTYLE = { auto = "Según tus talentos", ranged = "A distancia", melee = "Cuerpo a cuerpo (Supervivencia)" }
	L.STYLE_NOW_MELEE = "talentos de cuerpo a cuerpo: modo melee (tu aspecto de melee, verde a melee y sin avisos parpadeantes)."
	L.STYLE_NOW_RANGED = "sin talentos de cuerpo a cuerpo: vuelves al modo a distancia."
	L.STYLE_REPORT = "estilo: %s, %s."
	L.STYLE_CHOSEN = "elegido en las opciones"
	L.STYLE_FOUND = "por tus talentos: conoces %s"
	L.STYLE_NONE = "por tus talentos: no conoces ninguno de %s"
	L.OPT_PREFERRED_MELEE = "Tu aspecto en cuerpo a cuerpo"
	L.NO_AMMO = "Sin munición"
	L.AMMO_LOW = "solo te quedan %d %s: toca comprar más."
	L.AMMO_MERCHANT = "este vendedor tiene %s y solo te quedan %d."
	L.PET_FOOD = "Comida de la mascota"
	L.PET_NO_FOOD = "No tienes comida para tu mascota"
	L.PET_LOW = "Poca comida para tu mascota: %d"
	L.PET_LOW_LEVEL_FOOD = "De nivel bajo para tu mascota: le gusta menos"
	L.PET_FEED_TIP = "Clic: dar de comer a tu mascota"
	L.PET_MERCHANT = "aquí hay comida para tu mascota: %s."
	L.PET_INFO_NONE = "no tienes ninguna mascota fuera."
	L.PET_INFO = "mascota: %s, nivel %d. Come: %s (%s)."
	L.PET_DIET_UNKNOWN = "no se sabe"
	L.DIET_FROM = { game = "lo dice el juego", family = "deducido por su familia" }
	L.PET_INFO_FOOD = "%d piezas de su comida en tus bolsas; %d vendedores con su comida en el mapa."
	L.FOOD_LINE = "  %s x%d: %s, nivel %d - %s"
	L.FOOD_EATS = "se la come"
	L.FOOD_TOO_LOW = "nivel demasiado bajo para tu mascota"
	L.FOOD_NOT_DIET = "no la come"
	L.FOOD_UNKNOWN = "  %s x%d: comida que el addon no conoce"
	L.GROWL_ON = "¡%s en automático!"
	L.GROWL_MSG = "%s está en automático: haz clic derecho sobre él en la barra de la mascota para que no le quite el aggro al tanque."
	L.OPT_GROWL = "Avisar si Gruñido está en automático en mazmorras y bandas"
	L.OPT_GROWL_GROUPS = "También en cualquier grupo"
	L.GROWL_MISS = "¡%s falla!"
	L.OPT_GROWL_MISS = "«Gruñido falla» cuando Gruñido no le atrae el bicho a tu mascota"
	L.NOT_HAPPY = "NO ESTÁ CONTENTA"
	L.PET_HEALTH = "¡CURA A TU MASCOTA! %d%%"
	L.PET_HEALTH_NAME = "Vida de la mascota"
	L.OPT_NOT_HAPPY = "NO ESTÁ CONTENTA encima del retrato si tu mascota no está contenta"
	L.OPT_PET_HEALTH = "Avisarme de curar a la mascota cuando le baje la vida"
	L.OPT_PET_HEALTH_PCT = "Por debajo de (% de vida)"
	L.OPT_WRATH = "%s en el retrato de la mascota, con su tiempo"
	L.PET_TOAST_NAME = "Subida de nivel de la mascota"
	L.PET_LEVEL_TOAST = "¡Nivel %d!"
	L.PET_TP_TITLE = "¡Puntos de entrenamiento!"
	L.PET_TP_TOAST = "+%d puntos de entrenamiento · %d para gastar"
	L.PET_LEVEL_MSG = "¡%s ha subido a nivel %d!"
	L.PET_TP_MSG = "%s ha ganado %d puntos de entrenamiento: tienes %d para gastar."
	L.OPT_PET_LEVEL = "Celebrarlo cuando tu mascota sube de nivel"
	L.OPT_PET_TP = "Avisarme cuando gane puntos de entrenamiento"
	L.OPT_PET_SOUND = "Con sonido"
	L.UNLOCK = "Desbloquear para mover"
	L.LOCK = "Bloquear"
	L.UNLOCKED = "avisos desbloqueados: arrástralos donde quieras y luego bloquéalos (clic derecho en el botón del minimapa)."
	L.LOCKED = "avisos bloqueados."
	L.NOT_IN_COMBAT = "no se puede en combate."
	L.TIP_AMMO = "Munición: %d"
	L.TIP_PET_FOOD = "Comida de la mascota: %d"
	L.TIP_LEFT = "Clic izquierdo: opciones"
	L.TIP_RIGHT_UNLOCK = "Clic derecho: desbloquear los avisos para moverlos"
	L.TIP_RIGHT_LOCK = "Clic derecho: bloquear los avisos"
	L.TIP_DRAG = "Arrastrar: mover este botón"
	L.TAB_MAP = "Mapa"
	L.TAB_RANGE = "Distancia"
	L.TAB_ASPECTS = "Aspectos"
	L.TAB_COMBAT = "Combate"
	L.SUBTITLE = "Calidad de vida para cazadores"
	L.SEC_PINS = "Marcas"
	L.SEC_WHICH = "Dónde y cuáles"
	L.SEC_DISTANCE = "Cuándo y qué"
	L.SEC_LOOK = "Cómo se ve"
	L.SEC_TRAPS = "Trampas"
	L.SEC_MELEE = "Cuerpo a cuerpo"
	L.SEC_THREAT = "Agro"
	L.SEC_AMMO = "Poca munición"
	L.SEC_FOOD = "Comida"
	L.SEC_PET_STATUS = "Vida y felicidad"
	L.SEC_PET_TOAST = "Subidas de nivel"
	L.PREVIEW_HINT = "Haz clic en una muestra para cambiar su color"
	L.TRAPS_READY = "TRAMPAS LISTAS"
	L.SEC_TRACKING = "Rastreo"
	L.OPT_TRACKING = "En mazmorras y bandas, avisarme si no rastreo criaturas"
	L.OPT_TRACKING_WORLD = "También en el mundo abierto"
	L.TRACKING_HINT = "Con hierbas, minerales, Rastrear ocultos o nada puesto, sale hasta que rastreas un tipo de criatura. Haz clic para ver tus rastreos de criaturas y elegir uno; con clic derecho deja en paz esa mazmorra o zona."
	L.OPT_TRACKING_TALENT = "Solo con puntos en %s"
	L.OPT_TRACKING_TEST = "Ver cómo sale en una mazmorra"
	L.TRACK_TALENT = "%s: %s"
	L.TRACK_TITLE = "Rastreo"
	L.TRACK_WRONG = "Rastreando %s"
	L.TRACK_NONE = "Sin rastrear criaturas"
	L.TRACK_CLICK = "Clic: elegir rastreo"
	L.TRACK_RIGHT = "Clic derecho: aquí no (esta mazmorra o zona)"
	L.TRACK_NO_API = "el juego no da a los addons la lista de rastreos."
	L.TRACK_ON = "activo"
	L.TRACK_OFF = "apagado"
	L.TRACK_CREATURE = "criaturas"
	L.OPT_TRAPS = "TRAMPAS LISTAS cuando vuelvan tus trampas tras usar una en pelea"
	L.OPT_FREEZE = "Lo que le queda a tu %s, junto a la placa del bicho congelado"
	L.TRUESHOT = "Aura de disparo certero"
	L.OPT_TRUESHOT = "Recordarme %s en sus 2 últimos minutos"
	L.OPT_MELEE_ALPHA = "Opacidad de CUERPO A CUERPO (%)"
	L.THREAT = "AGRO %d%%"
	L.THREAT_PULLED = "¡TIENES EL AGRO!"
	L.THREAT_NAME = "Amenaza"
	L.OPT_THREAT = "Avisar bajo la placa del objetivo antes de quitarle el agro a tu mascota"
	L.OPT_THREAT_PCT = "Avisar desde (% del agro)"
	L.TAB_AMMO = "Munición"
	L.TAB_PET = "Mascota"
	L.TAB_SWING = "Golpes"
	L.TAB_PROCS = "Procs"
	L.PROCS_NAME = "Procs"
	L.PROCS_WATCHING = "%s: vigilando los hechizos %s."
	L.PROCS_NOT_READY = "%s aún no está montado: el addon lo monta fuera de combate."
	L.PROCS_REFUSED = "el juego no aceptó las animaciones de %s, así que no saldrán."
	L.OPT_PROC_SPEED = "Viento a ambos lados con %s"
	L.OPT_PROC_KILL = "Una mira girando a tus pies con %s"
	L.OPT_PROC_COLOR = "Color"
	L.OPT_PROC_TEST = "Ver cómo queda"
	L.OPT_PROCS_SIZE = "Tamaño (%)"
	L.OPT_PROCS_X = "Izquierda o derecha"
	L.OPT_PROCS_Y = "Abajo o arriba"
	L.OPT_PROCS_GAP = "Separación entre los dos lados del viento"
	L.OPT_PROCS_ALPHA = "Intensidad al salir (%)"
	L.OPT_PROCS_CALM = "Intensidad después, mientras dura (%)"
	L.OPT_PROCS_TIMER = "Los segundos que les quedan"
	L.OPT_PROCS_TIMER_SIZE = "Tamaño del número"
	L.PROCS_HINT = "Quick Shots y Quick Strikes salen de Deadly Aspects: disparas o golpeas un 30 % más rápido durante 12 segundos. Rapid Killing hace que tu próximo disparo haga un 20 % más. Un estallido al salir cada uno y después una versión más tranquila mientras dura. Los muestra el propio juego, así que también salen en combate; lo que cambies en una pelea se aplica al acabar. También puedes arrastrarlos con Mover avisos."
	L.SEC_RESPEC = "Instructor de clase"
	L.OPT_RESPEC = "Cuándo baja el precio de reiniciar talentos, bajo la ventana del instructor"
	L.RESPEC_HINT = "Blizzard no lo publica: los jugadores cuentan que sube un escalón con cada reinicio (1, 5, 10 y luego 5 g más hasta 50 g) y baja uno por cada semana desde el último. El precio que pide el instructor es el real."
	L.RESPEC_TITLE = "Reinicio de talentos"
	L.RESPEC_CLASS = "Talentos de clase"
	L.RESPEC_LEGACY = "Talentos de legado"
	L.RESPEC_LAST = "El último, hace %s, por %s"
	L.RESPEC_NOW = "Ahora: %s"
	L.RESPEC_NOW_ABOUT = "Ahora: unos %s"
	L.RESPEC_DROPS = "Baja a %s %s (en %s)"
	L.RESPEC_LOWEST = "Ya está en lo más bajo"
	L.RESPEC_ASKED = "El instructor te pidió %s hace %s"
	L.RESPEC_UNKNOWN = "%s aún no sabe cuándo reiniciaste por última vez: lo apunta la próxima vez que pagues uno."
	L.RESPEC_TODAY = "hoy a las %s"
	L.RESPEC_TOMORROW = "mañana a las %s"
	L.RESPEC_ON = "el %s a las %s"
	L.RESPEC_WEEKDAYS = { "domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado" }
	L.RESPEC_MINUTES = "%d min"
	L.RESPEC_HOURS = "%d h"
	L.RESPEC_DAYS = "%d días"
	L.SWING_NAME = "Barras de golpe"
	L.SEC_SWING = "Una barra por arma"
	L.OPT_SWING_ON = "Barras de golpe"
	L.OPT_SWING_RANGED = "Disparo automático"
	L.OPT_SWING_MAIN = "Mano derecha"
	L.OPT_SWING_OFF = "Mano izquierda"
	L.OPT_SWING_BLIZZARD = "Ocultar las barras de golpe de Blizzard"
	L.OPT_SWING_BY_RANGE = "Solo las barras de donde estás: las de cuerpo a cuerpo a melee, la del Disparo automático más lejos"
	L.OPT_SWING_WIDTH = "Ancho"
	L.OPT_SWING_HEIGHT = "Alto"
	L.OPT_SWING_TIME = "Segundos hasta el siguiente golpe"
	L.OPT_SWING_ICON = "El icono del arma a la izquierda"
	L.OPT_SWING_WINDUP = "Marcar el último medio segundo del Disparo automático (moverte retrasa el tiro)"
	L.OPT_SWING_COLOR = "Color: %s"
	L.OPT_SWING_TEST = "Verlas golpear"
	L.TRY = "Probar"
	L.SWING_HINT = "Cada barra empieza apagada, se enciende según llega el golpe y da un destello al salir. Sale mientras atacas con esa arma y se va un momento después de parar. Forever le dice al juego cada golpe, también en combate. Arrástralas con Mover avisos."
	L.OPT_FOOD_VENDORS = "Vendedores con comida para la mascota que llevas"
	L.OPT_OTHER_FACTION = "Mostrar también los de la otra facción"
	L.OPT_MINIMAP_PINS = "Pines en el minimapa"
	L.OPT_CONTINENT = "Pines en el mapa del continente"
	L.OPT_ONLY_HUNTER = "Solo con cazadores"
	L.OPT_RANGE_ON = "Mostrar a qué distancia está tu objetivo"
	L.MELEE_WARNING = "CUERPO A CUERPO"
	L.OPT_MELEE_WARNING = "Aviso parpadeante de CUERPO A CUERPO cuando estás a melee (a distancia)"
	L.OPT_ONLY_COMBAT = "Solo en combate"
	L.OPT_DISPLAY = "Mostrar"
	L.DISPLAY = { number = "Un número (estimado)", bracket = "El tramo entre medidas" }
	L.OPT_FONT = "Letra"
	L.FONTS = { fredoka = "Fredoka (redondeada)", changa = "Changa (como GoodRange)", game = "La del juego" }
	L.OPT_UNITS = "Distancia en"
	L.UNITS = { yards = "Yardas", meters = "Metros" }
	L.UNITS_SET = "distancia en %s."
	L.RANGE_NO_TARGET = "no tienes objetivo."
	L.DR_NO_API = "este juego no da los rendimientos decrecientes a los addons."
	L.DR_STATUS = "rendimientos decrecientes: sistema %s; la opción JcJ del juego %s, solo los que causas tú %s."
	L.DR_OPTION = "(la opción del juego es \"%s\", en Opciones, Juego)"
	L.DR_RULESET = "categorías %s (nombre, número, seguida): %s"
	L.DR_NONE = "ninguna"
	L.DR_ON = "apuntando los rendimientos decrecientes: congela a alguien y aquí sale lo que manda el juego. /huntergod dr otra vez para parar."
	L.DR_OFF = "ya no apunto los rendimientos decrecientes."
	L.DR_NO_EVENT = "el juego no manda los rendimientos decrecientes a los addons."
	L.DR_EVENT = "DR %s (%s) a los %s: %s"
	L.DR_SECRET = "secreto"
	L.RANGE_REPORT = "objetivo: %s, %d-%d yd (Disparo automático llega a %d yd). Disparo automático a rango: %s; cuerpo a cuerpo: %s."
	L.RANGE_STEPS = "pasos (yd:¿a rango?): "
	L.RANGE_LOADING = "(aún cargando algunos objetos)"
	L.RANGE_YES = "sí"
	L.RANGE_NO = "no"
	L.OPT_DEAD_LABEL = "«%s» y «%s» en lugar del número"
	L.OPT_UNIT_LABEL = "Poner yd o m detrás del número"
	L.REMINDERS = "Avisos"
	L.CLICK_CAST = "Clic: %s"
	L.OPT_FAR = "Azul claro y con brillo en las últimas 5 yardas de tu alcance"
	L.OPT_STYLE = "Estilo"
	L.STYLE = { text = "Texto", icon = "Cuadrado de color", both = "Cuadrado y texto" }
	L.OPT_POSITION = "Posición"
	L.POSITION = { plate = "En la placa del objetivo", free = "Donde yo lo ponga" }
	L.OPT_PLATE_SIDE = "Lado de la placa"
	L.PLATE_SIDE = { top = "Encima", bottom = "Debajo", left = "A la izquierda", right = "A la derecha" }
	L.OPT_PLATE_GAP = "Separación de la placa"
	L.OPT_SIZE = "Tamaño"
	L.OPT_ASPECT_ON = "Avisos de aspecto en combate"
	L.OPT_TRAVEL = "Avisar de Guepardo o Manada"
	L.OPT_MISSING = "Avisar si te falta tu aspecto"
	L.OPT_MISSING_ALWAYS = "También fuera de combate (no viajando con Guepardo o Manada, en vuelo ni montado)"
	L.OPT_ASPECT_TEXT = "Escribir el aviso debajo del icono"
	L.OPT_PREFERRED = "Tu aspecto a distancia"
	L.OPT_AMMO_ON = "Aviso de poca munición"
	L.OPT_THRESHOLD = "Avisar por debajo de"
	L.OPT_MERCHANT = "Recordármelo en los vendedores"
	L.OPT_PET_ON = "Comida de la mascota"
	L.OPT_PET_BAR = "Mostrar la comida que come tu mascota"
	L.OPT_HIDE_COMBAT = "Ocultarla en combate"
	L.OPT_PET_LOW = "Avisar por debajo de"
	L.OPT_MINIMAP_BUTTON = "Botón en el minimapa"
	L.HELP = {
		"  /huntergod  - opciones (o clic en el botón del minimapa)",
		"  /huntergod desbloquear | bloquear  - mover los avisos",
		"  /huntergod metros | yardas  - la distancia en metros o en yardas",
		"  /huntergod mascota  - lo que el addon sabe de tu mascota",
		"  /huntergod rango  - qué dice cada comprobación de distancia de tu objetivo",
		"  /huntergod dr  - apuntar lo que dice el juego de los rendimientos decrecientes",
		"  /huntergod estilo  - a distancia o cuerpo a cuerpo, y por qué",
		"  /huntergod golpes  - probar las barras de golpe",
		"  /huntergod talentos  - cuándo baja el precio de reiniciar talentos",
		"  /huntergod rastreo  - probar el aviso de rastreo",
		"  /huntergod rastreos  - los rastreos que da el juego y cuáles cuentan como criaturas",
		"  /huntergod procs  - probar las animaciones de los procs y ver qué vigila cada una",
		"  /municion flechas | balas | ambas | arma  - qué munición marca el mapa",
		"  /municion cerca  - ruta al vendedor útil más cercano",
		"  /municion instructores | establos | comida | faccion | minimapa | continente | clase | boton  - activar o quitar cada opción",
		"  /municion estado  - qué muestra el mapa",
	}
end

ns.L = L
