# Space Shooter

A small arcade space shooter built in Godot 4.7. Everything it needs is in this
repo — the sprites are SVGs and the sound effects were generated as WAVs, so
there are no missing assets to hunt down.

## Playing

Open the project in Godot and press **F5** (or the Play button).

- **Hold the left mouse button** to fly toward the cursor *and* fire at the same time.
- Release to stop moving and stop shooting.
- You have 3 health. Enemy ships cost 1, meteors cost 2.
- Grab the yellow ⚡ power-up for ~7 seconds of faster fire.

Three ships to pick from:

| Ship | Weapon | Fire rate |
|------|--------|-----------|
| ACE  | Single fast bolt | 0.24s |
| TANK | Triple spread shot | 0.50s |
| ZAP  | Piercing plasma orb (3 damage, passes through) | 0.80s |

## Waves and formations

The game runs in arcade waves. Each wave builds a formation of slots at the top
of the screen, flies the enemies in one at a time along curved paths, then holds
them in a slowly swaying grid while picking divers. Clear every enemy and the
next wave starts.

Formation shapes cycle by wave number: **grid → V → arc → clusters**, growing
wider and deeper as you progress. Every **5th wave is a boss** instead.

Difficulty ramps through enemy speed (`speed_scale`), formation size, and how
often divers are picked (up to 3 at a time).

## Enemy types

| Enemy | Health | Points | Behaviour |
|---|---|---|---|
| Basic (red) | 1 | 10 | Curved dives, often returns to formation |
| Fast (orange) | 1 | 20 | Steep fast dives, usually leaves the screen |
| Strong (purple saucer) | 4 | 30 | Slow straight dives, **shoots at you** |
| Special (teal) | 3 | 100 | Zigzag dives, **drops a power-up** |
| Boss | 26 + 5/wave | 400 + 1000 bonus | Three attack patterns, health bar |

Meteors still fall in as an ambient hazard during waves and still cost 2 health.

## Diving

A diver flashes red for half a second first — that's your warning. Then it
follows a bezier curve down at you. Four patterns: `straight`, `curved`,
`zigzag` and `fast`, set per enemy scene via the `dive_pattern` export.
Survivors loop around the top of the screen and rejoin their slot.

## Scoring

- **Combo** — each kill within 2.2 seconds of the last raises the combo.
  Multiplier is `1 + combo/3`, capped at 8x, shown top-right.
- **Wave clear** — 100 x wave number.
- **No damage** — 250 extra for clearing a wave without being hit.
- **Boss defeated** — 1000 on top of the boss's own value.
- **High score** saves to `user://highscore.save` and shows on the title screen
  and HUD.

## Project layout

```
project.godot          autoloads, 720x1280 portrait viewport, "left_click" action
scenes/
  main.tscn            the game — background, spawner, player, and all 4 UI screens
  ui.gd                screen switching + HUD (attached to main.tscn's root)
  theme.tres           button styling
  explosion.tscn       reusable, self-freeing explosion effect
  floating_text.tscn   the "+100" score popups
scripts/
  global.gd            autoload "Global" — run state, waves, combo, high score
  sfx.gd               autoload "Sfx"  — pooled player, Sfx.play() / Sfx.play_varied()
  bg.gd                scrolling starfield, drawn in code (no texture)
  explosion.gd         shockwave ring, hot core and flying shards
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
  spawner.tscn/.gd     wave manager: layouts, entry paths, dive picking
art/                   SVG sprites
sfx/                   WAV sound effects
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

- **Difficulty:** `_build_layout()` in `components/spawner.gd` controls formation
  size per wave; `BOSS_EVERY` sets the boss interval.
- **Dive frequency:** the `DiveTimer.wait_time` line in `_start_next_wave()`.
- **Enemy stats:** open any of the enemy scenes and edit the exported values in
  the Inspector (`health`, `speed`, `score_value`, `weave_amplitude`, `spin_speed`).
- **Ship feel:** the `match Global.chosen_ship` block in `components/player.gd`
  (`shoot_laser`) sets the fire rate and shot pattern for each ship.
- **Player toughness:** `max_health` on the Player node.
