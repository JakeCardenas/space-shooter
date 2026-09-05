# STARBYTE

A vertical arcade space shooter built in Godot 4.7. Everything it needs is in
this repo — the sprites are pixel-grid SVGs, the font is a generated bitmap
font, and the sound effects are WAVs, so there are no missing assets.

## Web build and deployment

The repository ships a ready-to-serve Godot Web export in **`web/`**. Vercel is
configured to serve that folder as a static site — there is no Node build step.

### Requirements (one time)

Web export needs Godot's **export templates** for your exact version
(4.7.2.stable). In the editor: *Editor -> Manage Export Templates -> Download
and Install*. Without them the export fails with "No export template found".

### Export for Web

From the project root:

```bash
GODOT="/Applications/Godot.app/Contents/MacOS/Godot" ./export_web.sh
```

If `godot` is already on your PATH, just `./export_web.sh`. The script wipes
`web/`, re-imports assets, then exports the `Web` preset from
`export_presets.cfg` to `web/index.html`.

You can also do it from the editor: *Project -> Export -> Web -> Export
Project*, saving to `web/index.html`.

The export produces `index.html`, `index.js`, `index.wasm`, `index.pck`, the
audio worklets and the icons. **All of them must be committed** — Vercel serves
them as-is.

### Test locally

Browsers refuse to load `.wasm` from `file://`, so serve it over HTTP:

```bash
cd web && python3 -m http.server 8123
```

Then open <http://127.0.0.1:8123>.

### Push to GitHub

```bash
git add -A && git commit -m "Update Web export" && git push origin main
```

### Deploy to Vercel

Import the repo at <https://vercel.com/new>, then set:

| Setting | Value |
|---|---|
| Framework Preset | **Other** |
| Build Command | *(leave empty)* |
| Output Directory | **`web`** |
| Install Command | *(leave empty)* |

Vercel redeploys on every push to `main`. `vercel.json` sets the
`Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` headers Godot
needs for cross-origin isolation, the correct `Content-Type` for `.wasm` and
`.pck`, and long-lived caching for the build assets while keeping `index.html`
uncached so new deploys appear immediately.

> The `Web` preset has `variant/thread_support=false`, so the build also runs on
> static hosts that cannot set those headers. If you turn threads back on, the
> headers in `vercel.json` become mandatory.

## Playing

Open the project in Godot and press **F5** (or the Play button).

- **Hold the left mouse button** to fly toward the cursor *and* fire at the same time.
- Release to stop moving and stop shooting.
- On the title screen, **←/→** pick a ship and **ENTER** starts. **ENTER** also restarts from game over.
- You have 3 health. Enemy ships cost 1, meteors cost 2.
- Grab the ⚡ power-up for ~7 seconds of faster fire.

Three ships to pick from:

| Ship | Weapon | Fire rate |
|------|--------|-----------|
| ACE  | Single fast bolt | 0.24s |
| TANK | Triple spread shot | 0.50s |
| ZAP  | Piercing plasma orb (3 damage, passes through) | 0.80s |

## Presentation

The game runs at a fixed **840x1080** portrait viewport with
`stretch/aspect = keep`, so it letterboxes like an upright arcade cabinet
instead of stretching the HUD. That is exactly **7:9** — the Galaga-era arcade
ratio (224x288) — and at that width a 60px sprite is **7.14%** of the playfield,
the same proportion a 16px sprite has on a 224px arcade screen. Column pitch
(78px) is 9.3% of the width, matching the arcade formation density.
All textures use **nearest-neighbour filtering** (`default_texture_filter = 0`)
and every sprite is drawn on a 4-unit pixel grid, so nothing ever goes blurry.

All sprites are drawn as insectoid creatures in bold arcade primaries — red,
blue, yellow, green, purple — with white eye bands, yellow antenna tips and
two-tone wing shading. Creatures and ships sit on a 2-unit pixel grid (60px
wide, 7.14% of the 840px playfield); props and shots use a 3-unit grid.

- `art/font/starbyte.fnt` + `.png` — a 5x8 bitmap font covering A-Z, 0-9 and
  punctuation, with lowercase mapped onto the uppercase glyphs. It is the
  `default_font` of `scenes/theme.tres`, so every label picks it up. **Use font
  sizes that are multiples of 8** (16, 24, 32, 40, 48…) to keep glyphs on exact
  integer scales.
- `scripts/logo.gd` — the STARBYTE wordmark, drawn as a blocky grid with a hue
  sweep across the letters and an occasional marquee flicker.
- `scripts/bg.gd` — square, colour-varied pixel stars that twinkle and snap to
  whole pixels.

## Screens

**Title / attract** — a cabinet attract screen: `1UP` / `HIGH SCORE` header row
(red labels, white values), the logo, a large preview of the selected ship, a
`▶` cursor menu listing ACE / TANK / ZAP, the ship blurb, a flashing
`PRESS START` and a copyright footer. Up/down (or left/right) moves the cursor,
ENTER starts. After 6 seconds without input, `scripts/attract.gd` flies
decorative enemy squads across the background. Those are plain `Sprite2D`s, not
real enemies, so attract mode never touches the gameplay systems.

**HUD** — blinking `1UP` and score top-left, `HIGH SCORE` top-centre, combo
top-right, lives as ship icons bottom-left, and **stage flags** bottom-right
(`scripts/stage_flags.gd` — one blue flag per ten stages, one small orange flag
for each stage after that).

**Game over** — score, wave reached, and a high-score table mixing the fictional
cabinet entries in `Global.RANKS` with your own best, highlighted as `YOU`.

## Stages and formations

Every stage opens with the arcade beat sequence — `STAGE n` in cyan, then
`READY` in red (or `WARNING / ELITE WAVE` on a boss stage) — before the
formation flies in. The very first stage also shows `START`.

The formation is one **tiered block**, built in `_build_layout()`:

```
        [ elites ]          <- top row, narrow, centred
     [  mid-tier   ]        <- second row
   [   light enemies   ]    <- wide rows
   [   light enemies   ]
   [   light enemies   ]    <- added from stage 4
```

Enemy type follows the row rather than being random: the top row is Crabs (and
Guards from stage 8), the second row Dragonflies (and Wasps from stage 4), and
the wide rows below are Bats. One Moth is swapped in per stage. The block widens
from 6 to 8 columns as you progress, and the whole thing sways as a unit.

Enemies enter in **squads of six that share one route** (`SQUAD_SIZE`), each
launching 0.09s after the one ahead, so a squad trails head-to-tail like a
snake. A route sweeps in low from one side, carves a **full circle**, then
climbs to the formation, where the squad fans out into its own slots. There are
four routes (left/right x high/low loop) and they alternate between squads.

`begin_entry()` in `components/enemy.gd` walks a **polyline** at constant speed
rather than a single bezier, which is what makes a real loop possible — it
carries leftover distance across segment boundaries so the circle stays smooth. Clear every enemy and the next stage starts after a short bonus pause.
Every **5th stage is an elite/boss stage**.

## Enemy types

| Enemy | From | Health | Points | Behaviour |
|---|---|---|---|---|
| **Bat** (red/blue) | wave 1 | 1 | 10 | Curved dives, often returns to formation |
| **Dragonfly** (blue/yellow) | wave 2 | 1 | 20 | Steep fast dives, usually leaves the screen |
| **Crab** (red/purple) | wave 3 | 4 | 30 | Slow straight dives, **shoots at you** |
| **Wasp** (cyan/yellow) | wave 4 | 2 | 40 | Zigzag dives, **shoots**, quick and erratic |
| **Guard** (teal armour) | wave 8 | 6 | 60 | Sweeping dives, tanky, big explosion |
| **Moth** (green/purple) | wave 2 | 3 | 100 | One per wave, zigzag dives, **drops a power-up** |
| **Hive Queen** (boss) | every 5th | 26 + 5/wave | 400 + 1000 bonus | Three attack patterns, health bar |

Meteors fall in as an ambient hazard during waves and cost 2 health. Boss waves
skip meteors and drop power-ups instead so the fight stays readable.

## Diving

A diver flashes red for half a second first — that's your warning. Then it
follows a bezier curve down at you. Five patterns: `straight`, `curved`,
`zigzag`, `fast` and `sweep`, set per enemy scene via the `dive_pattern` export.
Survivors loop around the top of the screen and rejoin their slot.

## Difficulty progression

`_apply_difficulty()` in `components/spawner.gd` ramps one factor at a time
rather than everything at once:

- **wave 6+** — a quarter of the formation switches to the `sweep` dive
- **any wave** — enemies that already shoot fire progressively faster
- **wave 7+** — ordinary enemies start returning fire, up to a 30% chance

On top of that, formations grow, `speed_scale` rises, and the dive timer
shortens (up to 3 divers at once).

## Scoring

- **Combo** — each kill within 2.2 seconds of the last raises the combo.
  Multiplier is `1 + combo/3`, capped at 8x, shown once it reaches 2x.
- **Wave clear** — 100 x wave number.
- **No damage** — 250 extra for clearing a wave without being hit.
- **Boss defeated** — 1000 on top of the boss's own value.
- **High score** is kept in memory during a run and written to
  `user://highscore.save` when the run ends (`Global.end_run()`) and on exit, so
  a hot streak does not rewrite the file on every kill. It shows on the title
  screen, the HUD and the game over board.

## Project layout

```
project.godot          autoloads, 720x1280 portrait, nearest filtering, "left_click"
scenes/
  main.tscn            the game — background, attract, spawner, player, 3 UI screens
  ui.gd                screen switching, ship select, HUD (attached to main.tscn's root)
  theme.tres           square arcade button styling + the pixel font as default_font
  explosion.tscn       reusable, self-freeing explosion effect
  floating_text.tscn   the "+100" score popups
scripts/
  global.gd            autoload "Global" — run state, waves, combo, high score, rankings
  sfx.gd               autoload "Sfx"  — pooled player, Sfx.play() / Sfx.play_varied()
  logo.gd              the drawn STARBYTE wordmark
  stage_flags.gd       bottom-right stage flags, drawn in code
  attract.gd           idle attract-mode fly-bys on the title screen
  bg.gd                scrolling pixel starfield, drawn in code (no texture)
  explosion.gd         pixel-block shockwave, chunky shards and a hot core
  camera_shake.gd      listens to Global.shake_requested
  trail.gd             player engine trail
  floating_text.gd     floats a label up and fades it
components/
  player.tscn/.gd      the player ship
  enemy.gd             shared by enemy_one, enemy_fast, enemy_two, enemy_special,
                       meteor and powerup — a small state machine
  boss.tscn/.gd        mini-boss with three attack patterns
  enemy_bullet.tscn    enemy projectile
  laser_*.tscn         laser_blue, laser_green, laser_orb — all share laser.gd
  spawner.tscn/.gd     wave manager: layouts, entry paths, dive picking, difficulty
art/                   pixel-grid SVG sprites
art/font/              generated bitmap pixel font
sfx/                   WAV sound effects
export_presets.cfg     the "Web" export preset (exports to web/index.html)
export_web.sh          one-command Web export
vercel.json            static-host headers for the Godot Web build
web/                   committed Web export — this is Vercel's Output Directory
```

## How the pieces talk to each other

Everything that can be hit is an `Area2D` in a group:

- Player ship → group `player`
- Enemy ships, meteors and the boss → group `enemy`
- Power-ups → group `powerUp`
- Player shots → group `laser`
- Enemy shots → group `enemyLaser`

`enemy.gd` listens for `area_entered` and calls `take_damage(area.damage)` when a
laser touches it. `player.gd` listens for the same signal and reacts to `enemy`
and `powerUp`. Nothing polls anything — it's all signals.

## Knobs worth turning

- **Difficulty:** `_build_layout()` (block size and tiers), `_pick_types()`
  (which enemy sits in which row) and `_apply_difficulty()` in
  `components/spawner.gd`; `BOSS_EVERY` sets the boss interval.
- **Stage intro timing:** the two `_sleep()` calls in `_start_next_wave()`.
- **Entry choreography:** `_entry_path()` (loop radius, route positions) and
  `SQUAD_SIZE` plus the two `_sleep()` values in `_spawn_formation()`.
- **Dive frequency:** the `DiveTimer.wait_time` line in `_start_next_wave()`.
- **Enemy stats:** open any enemy scene and edit the exported values in the
  Inspector (`health`, `speed`, `score_value`, `dive_pattern`, `shoots`).
- **Ship feel:** the `match Global.chosen_ship` block in `components/player.gd`
  (`shoot_laser`) sets the fire rate and shot pattern for each ship.
- **Cabinet rankings:** `Global.RANKS` in `scripts/global.gd`.
- **Attract mode:** `idle_delay` and `squad_gap` on the `Attract` node.
