"""Revisión estática de un addon de la familia ...God, antes de publicar.

Busca lo que las pruebas no ven y en el juego da error:
- TOC: archivos que lista y no existen, y .lua que existen y no lista.
- Sintaxis: cada .lua tiene que compilar (lupa/LuaJIT).
- Textos: cada L.CLAVE que usa el código tiene que existir en Locales.lua.
- Eventos sin pcall que no son de la lista conocida: un evento que el juego no tiene corta el archivo.
- Textos escritos sin fuente: un FontString creado sin plantilla al que se le hace SetText antes
  de darle fuente en la misma función.

Uso: python -I tools/lint_addon.py . <Nombre>   (copia de ClassGods/lint_addon.py: se cambia allí y se copia)
Sale con 1 si encuentra algo.
"""
import re
import sys
from pathlib import Path

# Eventos que existen en el cliente de Forever y se usan sin pcall en la familia
KNOWN_EVENTS = {
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED", "PLAYER_TARGET_CHANGED", "UNIT_AURA", "UNIT_SPELLCAST_SUCCEEDED", "SPELLS_CHANGED",
    "BAG_UPDATE_DELAYED", "BAG_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_HEALTH", "UNIT_PET", "MERCHANT_SHOW", "MERCHANT_CLOSED",
    "GOSSIP_SHOW", "GOSSIP_CLOSED", "SPELL_UPDATE_COOLDOWN", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
    "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "GROUP_ROSTER_UPDATE", "UPDATE_INVENTORY_DURABILITY",
    "UNIT_ABSORB_AMOUNT_CHANGED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "CHAT_MSG_LOOT", "CHAT_MSG_MONEY",
    "PLAYER_MONEY", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED", "CONFIRM_TALENT_WIPE", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_FAILED", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "UPDATE_SHAPESHIFT_FORM",
    "UPDATE_SHAPESHIFT_FORMS", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "UNIT_SPELLCAST_SENT",
    "PLAYER_TARGET_SET_ATTACKING", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "UNIT_COMBO_POINTS",
    "PLAYER_UPDATE_RESTING", "PET_BAR_UPDATE", "UNIT_HAPPINESS", "MINIMAP_UPDATE_TRACKING",
    "UNIT_LEVEL", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "PLAYER_FLAGS_CHANGED",
    "UNIT_FLAGS", "UPDATE_MOUSEOVER_UNIT", "CURSOR_CHANGED", "TRADE_SKILL_SHOW", "LOOT_OPENED", "LOOT_CLOSED",
    "CHAT_MSG_SYSTEM", "QUEST_TURNED_IN", "PLAYER_XP_UPDATE", "TIME_PLAYED_MSG", "UNIT_PORTRAIT_UPDATE",
}
LUA_GLOBALS = set("""_G assert error ipairs pairs next pcall xpcall select tonumber tostring type unpack rawget rawset
setmetatable getmetatable math string table format floor ceil max min abs strlower strupper strsplit strtrim wipe
tinsert tremove print date time sort""".split())


def strip_comments(src):
    src = re.sub(r"--\[(=*)\[.*?\]\1\]", "", src, flags=re.S)
    return re.sub(r"--[^\n]*", "", src)


def strip_strings(src):
    src = re.sub(r"\[(=*)\[.*?\]\1\]", '""', src, flags=re.S)
    return re.sub(r'"(?:\\.|[^"\\\n])*"|\'(?:\\.|[^\'\\\n])*\'', '""', src)


def main(project, name):
    root = Path(project) / name
    toc = root / f"{name}.toc"
    problems = []
    listed = [l.strip().replace("\\", "/") for l in toc.read_text(encoding="utf-8").splitlines()
              if l.strip() and not l.startswith("#")]
    for f in listed:
        if not (root / f).exists() and not f.startswith("Libs/"):
            problems.append(f"TOC: lista {f} pero no existe")
    own = sorted(p.relative_to(root).as_posix() for p in root.rglob("*.lua") if not p.relative_to(root).as_posix().startswith("Libs/"))
    for f in own:
        if f not in listed:
            problems.append(f"TOC: {f} existe pero no está en el TOC (no se carga)")

    try:
        try:
            from lupa import luajit21 as lupa
        except ImportError:
            import lupa
        lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        compile_ = lua.eval("function(src, name) local f, err = (loadstring or load)(src, name) return err end")
    except Exception:
        compile_ = None

    locales = (root / "Locales.lua").read_text(encoding="utf-8") if (root / "Locales.lua").exists() else ""
    defined = set(re.findall(r"^\s*([A-Z][A-Z0-9_]*)\s*=", locales, re.M)) | set(re.findall(r"\bL\.([A-Z][A-Z0-9_]*)\s*=", locales))

    for f in own:
        path = root / f
        src = path.read_text(encoding="utf-8")
        if compile_:
            err = compile_(src, f)
            if err:
                problems.append(f"{f}: no compila: {err}")
                continue
        code = strip_comments(src)
        bare = strip_strings(code)
        # Textos que faltan
        if f != "Locales.lua":
            for key in sorted(set(re.findall(r"\bL\.([A-Z][A-Z0-9_]*)\b", bare))):
                if key not in defined:
                    problems.append(f"{f}: usa L.{key}, que no existe en Locales.lua")
        # Eventos sin pcall que el juego puede no tener
        for i, line in enumerate(bare.splitlines(), 1):
            for ev in re.findall(r":Register(?:Unit)?Event\(\s*\"\"", line):
                pass
        for i, line in enumerate(code.splitlines(), 1):
            if "pcall" in line:
                continue
            for ev in re.findall(r":Register(?:Unit)?Event\(\s*\"([A-Z_]+)\"", line):
                if ev not in KNOWN_EVENTS:
                    problems.append(f"{f}:{i}: RegisterEvent(\"{ev}\") sin pcall: si el juego no lo tiene, corta el archivo")
        # Texto escrito sin fuente: CreateFontString sin plantilla y SetText antes de darle fuente
        lines = code.splitlines()
        for i, line in enumerate(lines):
            m = re.search(r"([\w.\[\]]+)\s*=\s*[\w.:\[\]]+:CreateFontString\(([^)]*)\)", line)
            if not m:
                continue
            var, args = m.group(1), [a.strip() for a in m.group(2).split(",")]
            if len(args) >= 3 and args[2] not in ("", "nil"):
                continue  # con plantilla: ya tiene fuente
            for j in range(i + 1, min(i + 40, len(lines))):
                nxt = lines[j]
                if re.search(re.escape(var) + r"\s*[,)]", nxt) and re.search(r"Font|UseFont|ThinFont|Fancy", nxt):
                    break
                if re.search(re.escape(var) + r":Set(?:Font|FontObject)\b", nxt):
                    break
                if re.search(re.escape(var) + r":Set(?:Formatted)?Text\(", nxt):
                    problems.append(f"{f}:{j + 1}: {var} recibe texto antes de tener fuente (creado en la línea {i + 1})")
                    break
                if re.match(r"^\s*end\s*$", nxt) and not nxt.startswith("\t\t"):
                    break
    for p in problems:
        print(p)
    print(f"{name}: {len(problems)} problema(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
