"""Empaqueta el addon para subirlo a CurseForge: release/HunterGod-<versión>.zip

Uso: python -I build_zip.py
El zip lleva dentro la carpeta HunterGod/, que es lo que CurseForge instala en AddOns.
"""
import re
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
addon = root / "HunterGod"
toc = (addon / "HunterGod.toc").read_text(encoding="utf-8")
version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)

out = root / "release" / f"HunterGod-{version}.zip"
out.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for f in sorted(addon.rglob("*")):
        if f.is_file():
            z.write(f, f.relative_to(root).as_posix())
print(out)
for info in zipfile.ZipFile(out).infolist():
    print(f"  {info.file_size:>8}  {info.filename}")
