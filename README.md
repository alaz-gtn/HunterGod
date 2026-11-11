# HunterGod

Addon de mejoras para cazadores en WoW Forever: distancia al objetivo, avisos de aspecto, de munición y de comida de la mascota, y vendedores de munición e instructores en el mapa. Se publica en CurseForge con el autor **wowforeverplus**.

## Carpetas

- `HunterGod/`: el addon tal como se instala en `_forever_\Interface\AddOns`. Un archivo por función: `Init.lua` (ajustes, comandos, mover avisos), `Map.lua`, `Range.lua`, `Aspects.lua`, `Ammo.lua`, `Pet.lua`, `MinimapButton.lua` y `Options.lua`.
- `curseforge/`: logo, descripción y registro de cambios para la página del proyecto.
- `release/`: los zips que se suben a CurseForge.
- `tools/`: scripts para regenerar los datos, probar el addon, hacer el logo y empaquetar.

## Sacar una versión nueva

1. Cambia `## Version:` en `HunterGod/HunterGod.toc` y añade la entrada en `curseforge/changelog.md`.
2. Si cambia la comida de mascota: descarga el `Full_DB/ClassicDB_*.sql.gz` de [cmangos/classic-db](https://github.com/cmangos/classic-db) y ejecuta `python -I tools/gen_petfood.py <ese .sql.gz> HunterGod/PetFood.lua`.
3. Si cambian los vendedores, los instructores o la comida de mascota: descarga de [QuestieDB](https://github.com/Questie/QuestieDB) `data/Forever/foreverItemDB.lua`, `data/Forever/foreverNpcDB.lua` y `support/Forever/Zones/areaIdToUiMapId.lua` en una carpeta, y ejecuta `python -I tools/gen_questie.py <esa carpeta> HunterGod/Data.lua HunterGod/PetFood.lua` (necesita `pip install lupa`). Los vendedores de comida salen de cruzar `PetFood.lua` con QuestieDB.
4. Prueba: `python -I tools/test_addon.py HunterGod enUS` y lo mismo con `esES`.
5. Si cambias el logo: `python -I tools/make_logo.py curseforge/logo.png HunterGod/media/icon.tga` (necesita `pip install pillow`).
6. Publica: haz commit, crea la etiqueta `v<versión>` y súbela (`git tag v1.0.2` y `git push origin main v1.0.2`). GitHub Actions (`.github/workflows/release.yml`) prueba el addon en los dos idiomas y lo sube a CurseForge con su nota de cambios (`tools/publish.py`, con la clave de CurseForge en el secreto `CF_API_KEY` del repositorio). Para ver el zip sin subirlo: `python -I tools/build_zip.py`, o `python -I tools/publish.py --dry-run`.

## Datos y licencia

Los vendedores e instructores salen de QuestieDB y la comida de mascota de la base de datos de cmangos; los dos permiten reutilizar sus datos bajo GPLv3. Por eso el addon es GPLv3. Las letras Fredoka One y Changa (en `media/`) son SIL OFL 1.1 y van con su licencia. Los datos de Zygor no se usan: son "All Rights Reserved".

## Combate en Forever

Forever esconde a los addons algunos datos en combate (los "valores secretos"): los bufos del jugador, y a veces la distancia. Por eso el aspecto activo se lee fuera de combate y en combate se sigue por los aspectos que lanzas, y la barra de comida (botones seguros) solo cambia fuera de combate.
