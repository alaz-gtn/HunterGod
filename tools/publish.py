"""Sube a CurseForge la versión que pone el TOC: el zip, su nombre, la versión del juego y su
entrada de curseforge/changelog.md.

Uso: python -I publish.py            (con la clave de CurseForge en CF_API_KEY)
     python -I publish.py --dry-run  (enseña lo que subiría, sin subir nada)
GitHub Actions lo lanza al subir una etiqueta vX.Y.Z (.github/workflows/release.yml).
"""
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

PROJECT = 1796472
API = "https://wow.curseforge.com/api"

root = Path(__file__).resolve().parent.parent
toc = (root / "HunterGod" / "HunterGod.toc").read_text(encoding="utf-8")
version = re.search(r"^## Version:\s*(\S+)", toc, re.M).group(1)
interface = int(re.search(r"^## Interface:\s*(\d+)", toc, re.M).group(1))
game = f"{interface // 10000}.{interface // 100 % 100}.{interface % 100}"  # 16001 is 1.60.1

tag = os.environ.get("GITHUB_REF_NAME")
if tag and tag != f"v{version}":
    sys.exit(f"La etiqueta {tag} no coincide con la versión del TOC ({version})")

# La entrada de esta versión: de su título al siguiente
log = (root / "curseforge" / "changelog.md").read_text(encoding="utf-8")
entry = re.search(rf"^# {re.escape(version)}[ \t]*\n(.*?)(?=^# |\Z)", log, re.M | re.S)
if not entry:
    sys.exit(f"curseforge/changelog.md no tiene la entrada # {version}")

subprocess.run([sys.executable, "-I", str(root / "tools" / "build_zip.py")], check=True, stdout=subprocess.DEVNULL)
zip_path = root / "release" / f"HunterGod-{version}.zip"

metadata = {
    "changelog": entry.group(1).strip(),
    "changelogType": "markdown",
    "displayName": f"HunterGod {version}",
    "releaseType": "release",
}
if "--dry-run" in sys.argv:
    print(json.dumps({**metadata, "gameVersions": [game]}, indent=2, ensure_ascii=False))
    print(zip_path)
    sys.exit()

token = os.environ.get("CF_API_KEY") or sys.exit("Falta la clave de CurseForge en CF_API_KEY")


def call(path, body=None, content_type=None):
    request = urllib.request.Request(API + path, data=body, headers={"X-Api-Token": token, "User-Agent": "HunterGod"})
    if content_type:
        request.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(request) as response:
            return json.load(response)
    except urllib.error.HTTPError as e:
        sys.exit(f"CurseForge respondió {e.code} a {path}: {e.read().decode(errors='replace')}")


ids = [v["id"] for v in call("/game/versions") if v["name"] == game]
if len(ids) != 1:
    sys.exit(f"CurseForge tiene {len(ids)} versiones del juego llamadas {game}")
metadata["gameVersions"] = ids

boundary = uuid.uuid4().hex
body = b"".join([
    f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n\r\n'.encode(),
    json.dumps(metadata).encode(),
    f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{zip_path.name}"\r\n'
    "Content-Type: application/zip\r\n\r\n".encode(),
    zip_path.read_bytes(),
    f"\r\n--{boundary}--\r\n".encode(),
])
result = call(f"/projects/{PROJECT}/upload-file", body, f"multipart/form-data; boundary={boundary}")
print(f"HunterGod {version} subido a CurseForge (archivo {result['id']}, juego {game})")
