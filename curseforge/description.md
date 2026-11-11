# HunterGod

Quality of life for hunters in **WoW Forever**. HunterGod keeps an eye on the things a hunter forgets: how far the target is, which aspect you're in, how much ammo and pet food you have left, and where to buy more.

Everything is set up from the **minimap button** (or `/huntergod`) in one options window, with a live preview of the range number, and every display can be dragged wherever you want it.

## Range to your target

- The **distance in yards or metres as one number** (for example "32 yd"), coloured by whether your target is **in Auto Shot range**, in **melee**, in the **dead zone** or **out of range**.
- The game only tells addons whether a target is within a few fixed distances; the number is estimated from when your target crosses them and how fast. You can show the range between checks instead ("30-35 yd").
- A big, round font with a thick black outline (Fredoka, or Changa, or the game's font).
- A blinking red **MELEE RANGE** warning when you're in melee of your target, as see-through as you like, that you can move anywhere.
- **AGGRO 92%** under the target's nameplate when you're about to pull it off your pet (from 90%, or wherever you set it), and **YOU HAVE AGGRO!** when you do. Only with your pet out or in a group.
- Above the target's **nameplate**, or anywhere you put it. Pick the size and the colour of each state.

## Aspects and traps

- A pulsing icon when you're in combat with **Aspect of the Cheetah or the Pack** on.
- Another one when your combat aspect (Hawk, Monkey, Wild or any) is **missing**. Below level 10 Monkey counts as Hawk.
- **TRAPS READY** when your traps are back after you used one in a fight (Feign Death and trap included).
- **Freezing Trap time left** beside the frozen mob's nameplate, counted down by the game itself (it works in combat).

## Ammo

- A warning when you have **fewer than 1000 arrows or bullets** (you choose the number), or none at all.
- A reminder in chat when you talk to a vendor that sells the ammo you're running out of.

## Your pet

- A bar with the **food in your bags that your pet eats**, best first. **Click one to feed your pet.**
- Knows your pet's diet and leaves out food that's too low level for it.
- Tells you when you're out of food or running low, and which food a vendor sells that your pet eats.
- **Growl reminder:** in dungeons and raids, a warning when your pet's Growl is on autocast, so it doesn't take the aggro off the tank.
- **Growl Miss:** floats up when Growl doesn't pull the mob onto your pet.
- **NOT HAPPY** blinks over your pet's portrait when it isn't happy, and **HEAL YOUR PET!** shows when its health drops below the line you choose.
- **Bestial Wrath** on your pet's portrait with the seconds it has left.
- **Level ups:** a toast with your pet's portrait when it levels up or earns training points, and how many it has to spend.

## Vendors and trainers on the map

- **117 arrow and bullet vendors** and **29 hunter trainers** on the zone map, the continent map and the minimap.
- **Pet food vendors**: only the ones that sell food the pet you have out eats, at a level it still likes.
- Checkboxes in the corner of the world map to show or hide arrows, bullets, trainers and pet food.
- Vendors that only sell ammo below your level are greyed out. Click a pin to set a waypoint (TomTom too).
- `/ammo nearest` sets a waypoint to the closest vendor that is still useful at your level.
- **Learns as you play:** open a merchant that sells ammo and isn't on the map, and it gets added. This is how the new Forever zones fill in.

## Commands

| Command | What it does |
| --- | --- |
| `/huntergod` | Opens the options |
| `/huntergod unlock`, `/huntergod lock` | Move the displays (or right-click the minimap button) |
| `/huntergod meters`, `/huntergod yards` | The range in metres or yards |
| `/ammo arrows`, `/ammo bullets`, `/ammo both`, `/ammo weapon` | Which ammo the map shows |
| `/ammo nearest` | Waypoint to the nearest useful vendor |
| `/ammo trainers`, `/ammo food`, `/ammo faction`, `/ammo minimap`, `/ammo continent`, `/ammo class` | Toggle each map option |
| `/ammo button` | Show or hide the minimap button |

## About the data

The vendor and trainer lists come from [QuestieDB](https://github.com/Questie/QuestieDB) and the pet food list from the [cmangos Classic database](https://github.com/cmangos/classic-db), both under the GPLv3.

Found a vendor that's missing or in the wrong place? Leave a comment with its name and coordinates.

## Credits

- Vendor and trainer data: [QuestieDB](https://github.com/Questie/QuestieDB) by the Questie team (GPLv3).
- Pet food data: [cmangos classic-db](https://github.com/cmangos/classic-db) (GPLv3).
- Range-check items: from [LibRangeCheck-3.0](https://github.com/WeakAuras/LibRangeCheck-3.0) (MIT). The distance estimate follows the idea of [Good Range](https://www.curseforge.com/wow/addons/good-range).
- Fonts: [Fredoka One](https://github.com/hafontia/Fredoka-One) by Milena Brandão and [Changa](https://github.com/googlefonts/changa-vf) by Eduardo Tunni, both under the SIL Open Font License 1.1 (included).
- Map pins: HereBeDragons by Nevcairiel.
- LibStub and CallbackHandler-1.0.

HunterGod is licensed under the GNU GPL v3 or later.

---

## Español

**HunterGod** son mejoras para cazadores en WoW Forever. Todo se configura desde el **botón del minimapa** (o `/huntergod`) en una ventana de opciones con vista previa de la distancia, y cada aviso se puede arrastrar donde quieras.

- **Aviso de cuerpo a cuerpo:** un CUERPO A CUERPO rojo que parpadea cuando estás a melee de tu objetivo; se puede mover.
- **Aviso de agro:** AGRO 92% bajo la placa del objetivo cuando estás a punto de quitarle el bicho a tu mascota (desde el 90%, o desde donde lo pongas), y ¡TIENES EL AGRO! cuando se lo quitas. Solo con la mascota fuera o en grupo.
- **Distancia al objetivo:** un número en yardas o metros (por ejemplo "32 yd") con letra redondeada y contorno negro, del color de a distancia, cuerpo a cuerpo, zona muerta o fuera de alcance, encima de la placa del objetivo o donde lo pongas. Eliges el estilo, el tamaño y los colores.
- **Aspectos:** te avisa si estás en combate con el Aspecto del guepardo o de la manada, o si te falta tu aspecto de combate.
- **Trampas:** TRAMPAS LISTAS cuando vuelven tus trampas después de usar una en una pelea, y lo que le queda de Trampa congelante al bicho congelado, junto a su placa (funciona en combate).
- **Munición:** te avisa cuando te quedan menos de 1000 flechas o balas (el número lo eliges tú) y te lo recuerda en los vendedores que la tienen.
- **Comida de la mascota:** una barra con la comida de tus bolsas que come tu mascota; haz clic para darle de comer. Te avisa si te queda poca, y en el mapa marca los vendedores con comida que le guste.
- **Gruñido:** en mazmorras y bandas te avisa si tu mascota tiene Gruñido en automático, para que no le quite el aggro al tanque.
- **Gruñido falla:** un aviso que sube y se desvanece cuando Gruñido no le atrae el bicho a tu mascota.
- **NO ESTÁ CONTENTA** parpadea sobre el retrato de tu mascota si no está contenta, y **¡CURA A TU MASCOTA!** sale cuando le baja la vida del porcentaje que elijas.
- **Cólera de las bestias** en el retrato de tu mascota, con los segundos que le quedan.
- **Subidas de nivel:** un aviso con el retrato de tu mascota cuando sube de nivel o gana puntos de entrenamiento, y cuántos tiene para gastar.
- **Mapa:** vendedores de flechas y balas, instructores de cazadores y vendedores de comida para tu mascota, con casillas en la esquina del mapa del mundo para elegir qué se ve.
- Comandos: `/huntergod` (opciones), `/huntergod desbloquear | bloquear`, `/municion flechas | balas | ambas | arma | instructores | comida | cerca | faccion | minimapa | continente | clase | boton`.
