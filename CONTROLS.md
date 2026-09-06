# STARBYTE Controls

## Desktop Controls

### Movement
- **WASD Keys** or **Arrow Keys** - Move ship in all directions
- Movement is smooth and responsive with full 360° freedom

### Shooting
- **Spacebar** - Hold to fire continuously
- **Left Mouse Button** - Hold to fly toward cursor AND fire (original control scheme)

### Menu Navigation
- **Arrow Keys** - Select ship (up/down) on title screen
- **Enter** - Start game / Confirm selection
- **ESC** - Pause game (coming in Phase 3)

## Mobile/Touch Controls

### Movement
- **Virtual Joystick** (bottom-left corner)
  - Touch and drag to move ship
  - Auto-centers when released
  - Dead zone prevents accidental micro-movements

### Shooting
- **FIRE Button** (bottom-right corner)
  - Large touch-friendly button
  - Hold to fire continuously
  - Visual feedback when pressed

### Menu Navigation
- **Touch** - Tap buttons directly
- Ship selection works with touch

## Control Priority

The game supports multiple input methods simultaneously:

1. **Keyboard** takes priority (WASD/Arrows for movement, Spacebar for shooting)
2. **Virtual Controls** activate when keyboard is not in use
3. **Mouse** works alongside any other input (click to move + shoot)

This allows seamless switching between control methods without conflicts.

## Platform Detection

- **Desktop:** Keyboard and mouse controls enabled by default
- **Mobile/Tablet:** Virtual controls automatically appear
- **Web:** Detects touch capability and shows appropriate controls

## Coming Soon (Phase 2-3)

- Configurable control schemes
- Button remapping
- Auto-fire toggle option
- Sensitivity settings
- Pause button for mobile
