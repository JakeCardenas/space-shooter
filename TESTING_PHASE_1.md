# Phase 1 Testing Checklist

## Quick Test Guide

### Desktop Testing (Primary - Test in Godot Editor)

1. **Launch the game**
   - Open project in Godot 4.7
   - Press F5 or click Play button

2. **Title Screen**
   - Press **Arrow Up/Down** or **W/S** to select different ships
   - Observe ship preview changes
   - Observe cursor moves to selected ship
   - Verify help text says "WASD OR ARROWS TO MOVE..."

3. **Start Game**
   - Press **Enter** to start
   - Verify virtual controls DO NOT appear

4. **Keyboard Movement Test**
   - Press **W** - ship moves up
   - Press **S** - ship moves down  
   - Press **A** - ship moves left
   - Press **D** - ship moves right
   - Try **diagonal** (W+A, W+D, S+A, S+D) - should move at same speed
   - Verify ship stays within screen bounds

5. **Keyboard Shooting Test**
   - Hold **Spacebar** - ship fires continuously
   - Release **Spacebar** - shooting stops
   - Try moving (WASD) while shooting (Space) - should work simultaneously

6. **Arrow Key Test**
   - Press **Arrow Up** - ship moves up
   - Press **Arrow Down** - ship moves down
   - Press **Arrow Left** - ship moves left
   - Press **Arrow Right** - ship moves right
   - Works identically to WASD

7. **Mouse Controls Test (Original)**
   - Hold **Left Mouse Button**
   - Ship should fly toward cursor
   - Ship should shoot while flying
   - Release mouse - ship stops moving and shooting

8. **Mixed Input Test**
   - Use WASD while holding mouse - keyboard should take priority
   - Use Spacebar while holding mouse - both shooting methods work
   - Switch between keyboard and mouse smoothly

9. **Gameplay Test**
   - Play a few waves
   - Verify all controls feel responsive
   - Check ship tilt animation works
   - Verify shooting rate is correct

### Expected Results (Desktop)

✅ WASD and Arrow keys move ship in all 8 directions
✅ Spacebar shoots continuously when held
✅ Mouse click-to-move still works
✅ No virtual controls visible
✅ No input lag or stuttering
✅ Ship collision boundaries work correctly
✅ All three ship types control identically

---

### Mobile Testing (Requires Device or Simulator)

#### Option A: Test on Real Device
1. Export Android APK or iOS build
2. Install on device
3. Follow mobile test steps below

#### Option B: Test in Browser with Device Simulation
1. Export Web build: `./export_web.sh`
2. Serve: `cd web && python3 -m http.server 8123`
3. Open browser to `http://127.0.0.1:8123`
4. Open DevTools (F12) → Toggle device toolbar
5. Select mobile device (e.g., iPhone 12, Galaxy S21)
6. Follow mobile test steps below

### Mobile Test Steps

1. **Title Screen**
   - Tap ship selection buttons directly
   - Verify they respond to touch
   - Tap "PRESS START" button

2. **Virtual Controls Appear**
   - Verify **Virtual Joystick** appears in bottom-left
   - Verify **FIRE button** appears in bottom-right
   - Controls should be visible and not obstruct gameplay area

3. **Virtual Joystick Test**
   - Touch joystick and drag in circles
   - Ship should follow joystick direction
   - Release - joystick should snap back to center
   - Ship should stop moving when released
   - Verify dead zone (small movements at center do nothing)

4. **Fire Button Test**
   - Tap and hold FIRE button
   - Ship should shoot continuously
   - Release - shooting stops
   - Button should highlight when pressed

5. **Combined Controls Test**
   - Use joystick with left thumb
   - Hold FIRE with right thumb
   - Ship should move AND shoot simultaneously
   - This is the core mobile gameplay loop

6. **Touch Tracking Test**
   - Press FIRE button and slide finger slightly off
   - Button should stay pressed (drag tolerance)
   - Slide finger completely off - button releases

7. **Gameplay Test**
   - Play through first wave with touch controls
   - Verify controls feel responsive
   - Check if joystick/button positions are comfortable
   - Verify controls don't block view of enemies

### Expected Results (Mobile)

✅ Virtual joystick appears bottom-left
✅ Fire button appears bottom-right  
✅ Joystick controls ship smoothly
✅ Fire button shoots when held
✅ Both work simultaneously
✅ Controls hide on menu screens
✅ Controls show during gameplay
✅ No overlap with game HUD
✅ Touch response feels instant

---

## Common Issues & Fixes

### Issue: "Virtual controls don't appear on mobile"
**Check:**
- Is `DisplayServer.is_touchscreen_available()` returning true?
- Did `_setup_mobile_controls()` run?
- Check console for errors

**Fix:**
- Add debug print in `ui.gd _setup_mobile_controls()` to verify it runs
- Force mobile mode by commenting out desktop check

### Issue: "Keyboard doesn't work"
**Check:**
- Input actions in project.godot
- Player.gd `_move()` function

**Fix:**
- Verify input actions exist: `move_up`, `move_down`, `move_left`, `move_right`, `shoot`
- Check if `Input.get_axis()` is being called

### Issue: "Shooting doesn't work with Spacebar"
**Check:**
- `shoot` action in project.godot
- Player.gd `_process()` function

**Fix:**
- Verify `shoot` action exists with Spacebar (keycode 32)
- Check `Input.is_action_pressed("shoot")` logic

### Issue: "Ship moves too fast diagonally"
**Check:**
- Input normalization in player.gd

**Fix:**
- Ensure `keyboard_input.normalized()` is called after combining X and Y

### Issue: "Virtual controls appear on desktop"
**Check:**
- Platform detection logic

**Fix:**
- Verify `is_mobile` detection in `ui.gd _setup_mobile_controls()`
- May need to disable touchscreen emulation in Godot project settings

---

## Performance Testing

### Desktop
- **Target:** 60 FPS stable
- **Test:** Play for 5 minutes, check for frame drops
- **Monitor:** Check CPU/GPU usage in Godot profiler

### Mobile
- **Target:** 60 FPS on mid-range devices, 30+ FPS on low-end
- **Test:** Play through wave 5, check for stuttering
- **Monitor:** Check battery drain and device temperature

---

## Regression Testing

Verify these existing features still work:

✅ Three ships selectable
✅ Ship weapons fire correctly
✅ Enemy formations spawn
✅ Enemy diving attacks work
✅ Boss appears on wave 5
✅ Scoring and combo system work
✅ High score saves
✅ Power-ups spawn and work
✅ Capture mechanic works
✅ Leaderboard entry works
✅ Sound effects play
✅ Music plays

---

## Sign-Off Criteria

Phase 1 is complete when:

- [x] All files created successfully
- [ ] Desktop keyboard controls work perfectly
- [ ] Mobile virtual controls work perfectly  
- [ ] No regressions in existing gameplay
- [ ] No console errors
- [ ] Performance targets met
- [ ] Both control schemes feel responsive
- [ ] Documentation is accurate

---

## Next Phase Preview

After Phase 1 testing is complete and all issues are resolved:

**Phase 2: Responsive UI & HUD**
- Proper anchor-based UI layout
- SafeArea margins for notches
- Larger touch targets
- Mobile pause button
- Responsive HUD scaling
- Better control positioning

**Estimated Time:** 2-3 days

---

**Current Status:** ✅ Implementation complete, ready for testing

Run through this checklist and report any issues found!
