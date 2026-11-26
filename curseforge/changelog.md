# 1.6.1

- **With every ...God addon on**: on a character of another class this one stays out of the way. It says nothing in the chat (a vendor no longer hears the same line from each addon) and won't enter move mode; it tells you why if you try.

# 1.6.0

- **Herbs and minerals tracking reminder**: if you're a herbalist or a miner and have neither Find Herbs nor Find Minerals on out in the world, its icon joins the row of reminders (the one you had on last), and a click out of combat puts it on. Not in dungeons, raids or battlegrounds, on a flight or in a fight. If you asked for the creature tracking reminder out in the world too, that one wins: a hunter tracks one thing at a time. An option in the Tracking section turns it off.

# 1.5.1

- **Proc animations smaller and more see-through**: they now show at 40% size (was 60%), 60% strength as they proc (was 85%) and 20% while they last (was 35%), so they stay around your character without covering the fight. If you hadn't changed these in the Procs tab, you get the new look on its own; anything you set yourself stays as it was.
- The Procs tab now goes down to 20% size and 10% strength.

# 1.5.0

- **Proc animations**: wind rushing up both sides of you while **Quick Shots** or **Quick Strikes** is up (Deadly Aspects: 30% faster shots or swings for 12 seconds), and a target turning on the ground at your feet with **Rapid Killing** (your next Shot deals 20% more). A burst as each procs, then a calmer version while it lasts, with the seconds it has left. The game itself draws them, so they work in combat too. Colour, size, place and strength in the new Procs tab; `/huntergod procs` shows them.
- **Tracking reminder** in dungeons and raids: when you're tracking herbs, minerals or nothing instead of a creature type. Click it for your creature trackings as bars and pick one; right-click leaves that dungeon alone. Only with points in Improved Tracking (an option), and out in the world too if you want. `/huntergod tracking` shows it anywhere.
- **The reminders in one row**: aspect, Trueshot Aura and tracking side by side above your character, always centred whether one, two or three show, the same size with a thin black edge, and still (no blinking). They move together: if you had moved them, place the row again with Move displays.
- **Click them out of combat**: Trueshot Aura casts it, and the aspect reminder puts on the right aspect for how you fight (Hawk, or Beast in Survival).
- A missing aspect now shows out of combat too (not while travelling in Cheetah or the Pack, on a flight, mounted or dead), and before a pull when you target an enemy, so you can click it.
- **Range**: only "Melee", "Dead zone" or the number. Its colour says the rest, so "In range" and the other states under it are gone, and yd or m after the number is off by default (an option). The switch and where the range goes are now at the top of the Range tab.

# 1.4.0

- **Talent reset price at your trainer**: a note under your hunter trainer's window says when you last reset your talents, what it costs now, and when the price drops and to what. It shows under the trainer's price too, so you can see whether waiting pays. The game doesn't tell addons when you last reset or when the price drops, so HunterGod writes down each reset you pay for from now on and counts from there: a step up with each reset (1, 5, 10, then 5 g more up to 50 g) and a step down for each week since the last one, as players report it. The price the trainer asks always wins. Legacy talents get their own lines. `/huntergod respec` says it anywhere.
- The Trueshot Aura countdown under its icon is finer: the game's narrow font with a thin edge.

# 1.3.0

- **Swing timers**: a bar for each weapon (Auto Shot, main hand and off hand), stacked, with your weapon's icon on its left and the seconds to the next swing. Each bar starts dim, lights up as the swing comes and flashes when it goes. Forever tells the game every swing, so they work in combat too.
- Only the bars for where you stand: the melee ones in melee range, Auto Shot's further away. A bar shows while you attack with that weapon and goes a moment after you stop, and turns grey when your target is out of its reach.
- Auto Shot's last half second is marked: moving then holds the shot back.
- They replace Blizzard's swing timers, which HunterGod turns off while its bars are on (and back on if you untick that option).
- Width, height, colours, which bars, the seconds and the icon in the new Swing timers tab; drag them with Move displays. `/huntergod swing` shows them swinging.

# 1.2.2

- Map pins no longer float in the middle of the screen over your character: a vendor's pin the world map had let go of could show up there (a bullet vendor in Dustwallow Marsh, for one). A pin now only shows on the open world map or on the minimap.
- The low ammo warning no longer pops up by mistake with plenty of arrows: right after a loading screen the game can count your ammo short for a moment, so a low count now has to still be low two seconds later.
- "Dead zone" under the range number while you're in the dead zone, even with the state off. Its own switch in Range, on by default.
- The addon's fonts are applied the way that fixed texts Forever didn't draw.

# 1.2.1

- Forever's newer zones on the map, Mount Hyjal among them: 5 more stable masters (Aili Greenwillow in Mount Hyjal, for one), 6 hunter trainers, 15 ammo vendors and 55 pet food vendors. The data now comes from the QuestieDB addon itself, which is more up to date.

# 1.2.0

- Survival: HunterGod knows from your talents (Strider Kick, Predator's Edge or Expose Prey) that you fight in melee, or you choose it in Combat, How you fight. In melee the range is green up close and yellow "Get closer" further out, with no max range glow and no blinking warnings, and the aspect warning asks for your melee aspect (Beast, or Monkey until you learn it; your choice in the options). `/huntergod style` says which mode you're in and why.
- Stable masters on the map: 46 of them on the zone map, the continent map and the minimap, with their own box in the map's corner and in the options (`/ammo stables`). Click one for a waypoint.
- HEAL YOUR PET! never showed: Forever hides the pet's health from addons. The game itself now turns it into the warning and its number, so it shows again below your line.

# 1.1.0

- Trueshot Aura reminder: its icon with a countdown in its last 2 minutes, grey once it's gone until you cast it again. It keeps counting in combat, when the game hides your buffs. Switch in Combat, Aspects; move it like the other warnings.

# 1.0.9

- The range on the target's nameplate can go above, below, left or right of it, as close or as far as you like (Range, Look: Side of the nameplate and Distance from the nameplate). Below the nameplate, the AGGRO warning moves under it.

# 1.0.8

- The aspect warning is just its icon now: in colour for Cheetah or Pack in combat, grey for the aspect you're missing. A switch in Combat, Aspects brings the words back.

# 1.0.7

- The range turns light blue with a soft glow in the last 5 yards of your reach: 30-35 yards, further with Hawk Eye. It has its own switch and colour in the options. Restart the game after updating: the glow is a new file.
- /huntergod dr logs what the game says about diminishing returns, to see what an addon can use for a Freezing Trap tracker.

# 1.0.6

- The range and the AGGRO warning can be moved again: what you drag is now a spot of their own that never hangs from a nameplate, and they follow it when they aren't on the target's nameplate.

# 1.0.5

- At 8-10 yards Auto Shot can still be too close, past the game's 8 yard check: the range showed out of range at 40 yd there, and now shows the dead zone.
- When Auto Shot can't fire for another reason (a hill in between), the range shows the real distance in grey instead of 40 yd.

# 1.0.4

- Too close for Auto Shot in combat (easy with a big mob) showed out of range at about 40 yd: it now shows the dead zone.

# 1.0.3

- The AGGRO warning can be dragged while the displays are unlocked (it went back to its place), and it starts clear of the range display.

# 1.0.2

- The AGGRO warning shows the same threat as the game's tooltip and target frame (your threat next to your pet's), so it now warns at range too: before, it read the threat that pulls aggro, which at range is 130% of your pet's.

# 1.0.1

- A new options window: a menu with icons, on/off switches, sections and a live preview of the range number.
- AGGRO warning under the target's nameplate before you pull it off your pet, and YOU HAVE AGGRO! when you do.
- Bestial Wrath on your pet's portrait with the seconds it has left.
- Freezing Trap time left beside the frozen mob's nameplate.
- Growl Miss shows sooner, while the mob is still on its way to you, and goes away if the mob turns to your pet after all.
- Map pins without a black square behind them; the map checkboxes always stay on screen.
- A warning if the old Ammo Vendor Map is still installed.
- Pet food: food up to 30 levels below your pet counts, and drinks no longer show up as food.

# 1.0

- First release.
- Range to your target as one number in yards or metres, in a round font with a thick outline, coloured by in range, melee, dead zone or out of range, above the nameplate or anywhere you put it.
- A blinking red MELEE RANGE warning when you're in melee.
- Aspect warnings in combat: Cheetah or Pack on, or your combat aspect missing.
- TRAPS READY when your traps are back after using one in a fight.
- Low ammo warning (1000 by default) and a reminder at vendors that sell your ammo.
- Pet food bar: the food in your bags your pet eats, click to feed; warnings when you run low.
- Growl reminder in dungeons and raids.
- A toast when your pet levels up or earns training points.
- Growl Miss, NOT HAPPY over the pet portrait and a heal-your-pet warning.
- 117 arrow and bullet vendors, 29 hunter trainers and the vendors with food for your pet on the world map, continent map and minimap, with checkboxes on the map.
- Minimap button and options window; every display can be moved.
- English and Spanish.
