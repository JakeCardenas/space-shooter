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

## Project layout

```
project.godot          autoloads, 720x1280 portrait viewport, "left_click" action
scenes/
  main.tscn            the game — background, spawner, player, and all 4 UI screens
  ui.gd                screen switching + HUD (attached to main.tscn's root)
  theme.tres           button styling
  explosion.tscn       reusable, self-freeing explosion effect
scripts/
  global.gd            autoload "Global" — game_on / game_over / score / chosen_ship / mute
  sfx.gd               autoload "Sfx"  — pooled sound player, call Sfx.play("laser")
  bg.gd                scrolling starfield, drawn in code (no texture)
  explosion.gd         expanding ring + fading core
components/
  player.tscn/.gd      the player ship
  enemy.tscn scenes    enemy_one, enemy_two, meteor, powerup — all share enemy.gd
  laser_*.tscn         laser_blue, laser_green, laser_orb — all share laser.gd
  spawner.tscn/.gd     drops enemies in, gets faster over time
art/                   SVG sprites
sfx/                   WAV sound effects
```

## How the pieces talk to each other

Everything that can be hit is an `Area2D` in a group:

- Player ship → group `player`
- Enemy ships and meteors → group `enemy`
- Power-ups → group `powerUp`
- Player shots → group `laser`

`enemy.gd` listens for `area_entered` and calls `take_damage(area.damage)` when a
laser touches it. `player.gd` listens for the same signal and reacts to `enemy`
and `powerUp`. Nothing polls anything — it's all signals.

## Knobs worth turning

- **Difficulty:** `Spawner`'s `start_interval`, `min_interval`, `ramp_per_second`.
- **Enemy stats:** open any of the enemy scenes and edit the exported values in
  the Inspector (`health`, `speed`, `score_value`, `weave_amplitude`, `spin_speed`).
- **Ship feel:** the `match Global.chosen_ship` block in `components/player.gd`
  (`shoot_laser`) sets the fire rate and shot pattern for each ship.
- **Player toughness:** `max_health` on the Player node.
