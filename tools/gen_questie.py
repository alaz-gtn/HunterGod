"""Genera Data.lua del addon a partir de QuestieDB (datos de Forever, GPLv3):
los vendedores de flechas y balas, los instructores de cazadores y los vendedores
de comida de mascota (qué es comida de mascota lo dice PetFood.lua, hecho antes con gen_petfood.py).

Uso: python -I gen_questie.py <carpeta con los .lua de QuestieDB> <salida Data.lua> <PetFood.lua>
"""
import re
import sys
from pathlib import Path

from lupa.luajit21 import LuaRuntime

src = Path(sys.argv[1])
out = Path(sys.argv[2])
pet_food = {int(i): (int(t), int(l)) for i, t, l in
            re.findall(r"\[(\d+)\] = \{ t = (\d+), l = (\d+) \}", Path(sys.argv[3]).read_text(encoding="utf-8"))}
lua = LuaRuntime(unpack_returned_tuples=True)


def load_block(filename, var):
    text = (src / filename).read_text(encoding="utf-8")
    m = re.search(re.escape(var) + r"\s*=\s*\[\[(.*?)\]\]", text, re.S)
    if not m:
        sys.exit(f"no encuentro {var} en {filename}")
    body = m.group(1).strip()
    if len(body) < 200_000:
        return lua.execute(body)
    # LuaJIT no admite más de 65536 constantes por función: se carga por trozos de una entrada por línea
    entries = body[body.index("{") + 1:body.rindex("}")].splitlines()
    merged = lua.table()
    for i in range(0, len(entries), 2000):
        part = lua.execute("return {" + "\n".join(entries[i:i + 2000]) + "}")
        for k, v in part.items():
            merged[k] = v
    return merged


items = load_block("foreverItemDB.lua", "QuestieDB.itemData")
npcs = load_block("foreverNpcDB.lua", "QuestieDB.npcData")
area_override = load_block("areaIdToUiMapId.lua", "ZoneDB.private.areaIdToUiMapIdOverride")
area_base = load_block("areaIdToUiMapId.lua", "ZoneDB.private.areaIdToUiMapId")

# Índices de las tablas de Questie (itemKeys / npcKeys)
I_NAME, I_REQLEVEL, I_CLASS, I_SUBCLASS, I_VENDORS = 1, 10, 12, 13, 14
N_NAME, N_SPAWNS, N_FRIENDLY, N_SUBNAME = 1, 7, 13, 14
PROJECTILE, ARROW, BULLET = 6, 2, 3
TIERS = (10, 25, 40)


def ui_map(area):
    m = area_override[area]
    if m is None:
        m = area_base[area]
    return m or None


def side_of(npc):
    friendly = npc[N_FRIENDLY] or ""
    if "A" in friendly and "H" in friendly:
        return "B"
    return "A" if "A" in friendly else "H" if "H" in friendly else None


def first_spot(npc):
    """El primer sitio de aparición en un mapa conocido: (uiMapID, x, y), o None"""
    for area, coords in sorted((npc[N_SPAWNS] or {}).items()):
        mapid = ui_map(area)
        first = coords[1] if coords else None
        if mapid and first is not None and first[1] >= 0 and first[2] >= 0:
            return int(mapid), float(first[1]), float(first[2])
    return None


vendors = {}
for item_id, item in items.items():
    if item[I_CLASS] != PROJECTILE or item[I_SUBCLASS] not in (ARROW, BULLET) or not item[I_VENDORS]:
        continue
    kind = "arrows" if item[I_SUBCLASS] == ARROW else "bullets"
    for npc_id in item[I_VENDORS].values():
        v = vendors.setdefault(int(npc_id), {"kinds": set(), "best": 0, "items": set()})
        v["kinds"].add(kind)
        v["best"] = max(v["best"], item[I_REQLEVEL] or 0)
        v["items"].add(item[I_NAME])

rows, skipped = [], []
for npc_id, v in vendors.items():
    npc = npcs[npc_id]
    if npc is None:
        skipped.append((npc_id, "no está en npcDB"))
        continue
    side = side_of(npc)
    if side is None:
        skipped.append((npc_id, f"{npc[N_NAME]}: hostil a las dos facciones"))
        continue
    spot = first_spot(npc)  # un pin por vendedor
    if not spot:
        skipped.append((npc_id, f"{npc[N_NAME]}: sin coordenadas en un mapa conocido"))
        continue
    upto = next((t for t in TIERS if t > v["best"]), None)
    rows.append({"id": npc_id, "m": spot[0], "x": spot[1], "y": spot[2], "side": side,
                 "kinds": v["kinds"], "upTo": upto, "name": npc[N_NAME]})

trainers = []
for npc_id, npc in npcs.items():
    if npc[N_SUBNAME] != "Hunter Trainer":
        continue
    side, spot = side_of(npc), first_spot(npc)
    if side is None or not spot:
        skipped.append((int(npc_id), f"{npc[N_NAME]} (instructor): sin facción o sin coordenadas"))
        continue
    trainers.append({"id": int(npc_id), "m": spot[0], "x": spot[1], "y": spot[2], "side": side, "name": npc[N_NAME]})

# Vendedores de comida de mascota: por cada tipo de comida, el nivel más alto que venden
food_sellers = {}
for item_id, (food_type, level) in pet_food.items():
    item = items[item_id]
    if item is None or not item[I_VENDORS]:
        continue
    for npc_id in item[I_VENDORS].values():
        foods = food_sellers.setdefault(int(npc_id), {})
        foods[food_type] = max(foods.get(food_type, 0), level)

food_vendors = []
for npc_id, foods in food_sellers.items():
    npc = npcs[npc_id]
    if npc is None:
        continue
    side, spot = side_of(npc), first_spot(npc)
    if side is None or not spot:
        skipped.append((npc_id, f"{npc[N_NAME]} (comida de mascota): sin facción o sin coordenadas"))
        continue
    food_vendors.append({"id": npc_id, "m": spot[0], "x": spot[1], "y": spot[2], "side": side,
                         "name": npc[N_NAME], "foods": foods})


def num(f):
    return f"{f:.2f}".rstrip("0").rstrip(".")


def luastr(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


lines = [
    "-- Arrow and bullet vendors and hunter trainers in WoW Forever. Generated by tools/gen_questie.py, do not edit by hand.",
    "-- Data derived from QuestieDB (https://github.com/Questie/QuestieDB), used under the GPLv3.",
    "-- m = uiMapID, x/y = map coordinates, side = A (Alliance) / H (Horde) / B (both),",
    "-- upTo = only sells ammo that is useful up to that level.",
    "local _, ns = ...",
    "",
    "ns.vendors = {",
]
for r in sorted(rows, key=lambda r: (r["m"], r["name"])):
    fields = [f"m = {r['m']}", f"x = {num(r['x'])}", f"y = {num(r['y'])}", f'side = "{r["side"]}"']
    if "arrows" in r["kinds"]:
        fields.append("arrows = true")
    if "bullets" in r["kinds"]:
        fields.append("bullets = true")
    if r["upTo"]:
        fields.append(f"upTo = {r['upTo']}")
    fields.append(f"name = {luastr(r['name'])}")
    lines.append(f"\t[{r['id']}] = {{ {', '.join(fields)} }},")
lines += ["}", "", "ns.trainers = {"]
for r in sorted(trainers, key=lambda r: (r["m"], r["name"])):
    lines.append(f"\t[{r['id']}] = {{ m = {r['m']}, x = {num(r['x'])}, y = {num(r['y'])}, "
                 f"side = \"{r['side']}\", name = {luastr(r['name'])} }},")
lines += ["}", "",
          "-- Pet food vendors: food = { [food type] = highest item level they sell }, types as in PetFood.lua.",
          "ns.foodVendors = {"]
for r in sorted(food_vendors, key=lambda r: (r["m"], r["name"])):
    foods = ", ".join(f"[{t}] = {l}" for t, l in sorted(r["foods"].items()))
    lines.append(f"\t[{r['id']}] = {{ m = {r['m']}, x = {num(r['x'])}, y = {num(r['y'])}, "
                 f"side = \"{r['side']}\", name = {luastr(r['name'])}, food = {{ {foods} }} }},")
lines += ["}", ""]
out.write_text("\n".join(lines), encoding="utf-8")

maps = {}
for r in rows:
    maps[r["m"]] = maps.get(r["m"], 0) + 1
print(f"{len(rows)} vendedores en {len(maps)} mapas, {len(trainers)} instructores "
      f"y {len(food_vendors)} vendedores de comida de mascota -> {out}")
print("descartados:", len(skipped))
for s in skipped:
    print("  ", s)
