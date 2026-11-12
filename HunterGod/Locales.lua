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
	ARROWS_BOX = "Arrows",
	BULLETS_BOX = "Bullets",
	TRAINERS_BOX = "Hunter trainers",
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
	STATUS = "showing %s; hunter trainers %s; %s; minimap %s; continent map %s; %s. Vendors recorded by you: %d.",
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
	},
	YARDS = "yd",
	METERS = "m",
	-- Aspects
	ASPECT_TRAVEL = "%s in combat!",
	ASPECT_MISSING = "No %s",
	ASPECT_NONE = "No aspect",
	ANY_ASPECT = "Any aspect",
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
	OPT_TRAPS = "TRAPS READY when your traps are back after using one in a fight",
	OPT_FREEZE = "Time left in your %s, beside the frozen mob's nameplate",
	OPT_MELEE_ALPHA = "MELEE RANGE opacity (%)",
	THREAT = "AGGRO %d%%",
	THREAT_PULLED = "YOU HAVE AGGRO!",
	THREAT_NAME = "Threat",
	OPT_THREAT = "Warn under the target's nameplate before you pull aggro off your pet",
	OPT_THREAT_PCT = "Warn from (% of aggro)",
	TAB_AMMO = "Ammo",
	TAB_PET = "Pet",
	OPT_FOOD_VENDORS = "Vendors with food for the pet you have out",
	OPT_OTHER_FACTION = "Show the other faction's too",
	OPT_MINIMAP_PINS = "Pins on the minimap",
	OPT_CONTINENT = "Pins on the continent map",
	OPT_ONLY_HUNTER = "Only on hunters",
	OPT_RANGE_ON = "Show the range to your target",
	MELEE_WARNING = "MELEE RANGE",
	OPT_MELEE_WARNING = "Blinking MELEE RANGE warning when you're in melee",
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
	OPT_SHOW_STATE = "Also write the state (in range, dead zone...)",
	OPT_FAR = "Light blue and glowing in the last 5 yards of your reach",
	OPT_STYLE = "Style",
	STYLE = { text = "Text", icon = "Colour square", both = "Square and text" },
	OPT_POSITION = "Position",
	POSITION = { plate = "Above the target's nameplate", free = "Where I put it" },
	OPT_SIZE = "Size",
	OPT_ASPECT_ON = "Aspect warnings in combat",
	OPT_TRAVEL = "Warn about Cheetah or Pack",
	OPT_MISSING = "Warn when your aspect is missing",
	OPT_ASPECT_TEXT = "Write the warning under the icon",
	OPT_PREFERRED = "Your combat aspect",
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
		"  /ammo arrows | bullets | both | weapon  - which ammo the map shows",
		"  /ammo nearest  - waypoint to the nearest useful vendor",
		"  /ammo trainers | food | faction | minimap | continent | class | button  - toggle each option",
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
	L.ARROWS_BOX = "Flechas"
	L.BULLETS_BOX = "Balas"
	L.TRAINERS_BOX = "Instructores"
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
	L.STATUS = "mostrando %s; instructores %s; %s; minimapa %s; mapa del continente %s; %s. Vendedores apuntados por ti: %d."
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
	}
	L.ASPECT_TRAVEL = "¡%s en combate!"
	L.ASPECT_MISSING = "Sin %s"
	L.ASPECT_NONE = "Sin aspecto"
	L.ANY_ASPECT = "Cualquier aspecto"
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
	L.OPT_TRAPS = "TRAMPAS LISTAS cuando vuelvan tus trampas tras usar una en pelea"
	L.OPT_FREEZE = "Lo que le queda a tu %s, junto a la placa del bicho congelado"
	L.OPT_MELEE_ALPHA = "Opacidad de CUERPO A CUERPO (%)"
	L.THREAT = "AGRO %d%%"
	L.THREAT_PULLED = "¡TIENES EL AGRO!"
	L.THREAT_NAME = "Amenaza"
	L.OPT_THREAT = "Avisar bajo la placa del objetivo antes de quitarle el agro a tu mascota"
	L.OPT_THREAT_PCT = "Avisar desde (% del agro)"
	L.TAB_AMMO = "Munición"
	L.TAB_PET = "Mascota"
	L.OPT_FOOD_VENDORS = "Vendedores con comida para la mascota que llevas"
	L.OPT_OTHER_FACTION = "Mostrar también los de la otra facción"
	L.OPT_MINIMAP_PINS = "Pines en el minimapa"
	L.OPT_CONTINENT = "Pines en el mapa del continente"
	L.OPT_ONLY_HUNTER = "Solo con cazadores"
	L.OPT_RANGE_ON = "Mostrar la distancia a tu objetivo"
	L.MELEE_WARNING = "CUERPO A CUERPO"
	L.OPT_MELEE_WARNING = "Aviso parpadeante de CUERPO A CUERPO cuando estás a melee"
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
	L.OPT_SHOW_STATE = "Escribir también el estado (a distancia, zona muerta...)"
	L.OPT_FAR = "Azul claro y con brillo en las últimas 5 yardas de tu alcance"
	L.OPT_STYLE = "Estilo"
	L.STYLE = { text = "Texto", icon = "Cuadrado de color", both = "Cuadrado y texto" }
	L.OPT_POSITION = "Posición"
	L.POSITION = { plate = "Encima de la placa del objetivo", free = "Donde yo lo ponga" }
	L.OPT_SIZE = "Tamaño"
	L.OPT_ASPECT_ON = "Avisos de aspecto en combate"
	L.OPT_TRAVEL = "Avisar de Guepardo o Manada"
	L.OPT_MISSING = "Avisar si te falta tu aspecto"
	L.OPT_ASPECT_TEXT = "Escribir el aviso debajo del icono"
	L.OPT_PREFERRED = "Tu aspecto de combate"
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
		"  /municion flechas | balas | ambas | arma  - qué munición marca el mapa",
		"  /municion cerca  - ruta al vendedor útil más cercano",
		"  /municion instructores | comida | faccion | minimapa | continente | clase | boton  - activar o quitar cada opción",
		"  /municion estado  - qué muestra el mapa",
	}
end

ns.L = L
