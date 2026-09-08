# STARBYTE Controls

## Desktop

### In game
- **←/→** or **A/D** — step one column left or right. One press is one column;
  holding the key does nothing until you press it again. The columns are the
  same ones the enemy formation stands in, so the ship is always dead centre
  under a target. The ship stays on the bottom row — there is no vertical
  movement.
- **SPACE** — hold to fire continuously.
- **Left mouse button** — hold to steer toward the cursor and fire at once.
- **ESC** — pause.

### Menus
- **↑/↓** — move the cursor.
- **ENTER** — confirm.
- **←/→** — adjust a value (volume meters in Settings) or change ship in Ship
  Select.
- **ESC** — back out one screen, and resume from the pause menu.

## Mobile and touch

Touch controls appear automatically when `DisplayServer.is_touchscreen_available()`
reports a touchscreen, and hide again on game over.

- **Virtual joystick** (bottom-left) — one push is one column. It has to come
  back to centre before it steps again, matching the one-press-one-column
  keyboard feel. Auto-centres on release, with a dead zone so a resting thumb does not
  drift the ship.
- **FIRE button** (bottom-right) — hold to fire continuously.
- **Menus** — tap the entries directly; every menu item is also a real `Button`.

## Input priority

All input methods stay live at once, checked in this order:

1. Keyboard (`move_left` / `move_right`, `shoot`)
2. Virtual joystick
3. Mouse

So switching between them mid-run never needs a mode toggle.

## Settings

Master, music and SFX volumes each drive their own audio bus and are saved to
`user://settings.save` along with the fullscreen toggle and the chosen ship.
