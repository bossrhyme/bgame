# Prototype Report: gesture-test

**Status:** `in-progress` — fill in findings after device testing

---

## Hypothesis

> `InputEventScreenDrag` in Godot 4.6 on Android can reliably detect 3 complete
> clockwise circular gestures within a defined radius, triggering a "dough ready"
> state with < 100ms response time and < 5% false positive rate from accidental
> straight swipes.

---

## Approach

Built a minimal standalone Godot 4.6 project (independent from `src/`) containing:

- **`gesture_detector.gd`** — `atan2`-based angle accumulation tracking absolute
  finger position (accumulated from `InputEventScreenDrag.relative` deltas off the
  initial touch point). Counts circles when `cumulative_angle` crosses multiples of
  `TAU`. Handles ±π wrap-around via delta normalization.
- **`dough_controller.gd`** — visual + haptic feedback (scale tween, color lerp,
  `Input.vibrate_handheld()`)
- **`bake_timer.gd`** — 8-second `Timer.timeout` idle loop (no `_process()`)
- **`coin_counter.gd`** — harvest → `GPUParticles2D` burst + coin popup

Deliberately skipped: art assets, audio, save/load, economy system — only the
gesture and the core loop feedback were in scope.

---

## Testing Protocol

Run on physical Android device (mid-range, e.g. Samsung Galaxy A-series or equivalent).
Perform each test 20 times. Record results.

### Test 1: Normal circular gesture (20 trials)
- Perform 3 deliberate clockwise circles over ~2 seconds
- Expected: gesture_completed fires, dough turns golden

| Trial | Result | Notes |
|-------|--------|-------|
| 1 | | |
| ... | | |
| 20 | | |
| **Pass rate** | **TBD / 20** | |

### Test 2: False positive — straight swipe (20 trials)
- Swipe straight across screen
- Expected: NO gesture_completed

| Trial | Result | Notes |
|-------|--------|-------|
| 1 | | |
| ... | | |
| 20 | | |
| **False positive rate** | **TBD / 20** | |

### Test 3: Fast circles (0.8s per circle, 20 trials)

| Pass rate | TBD |
|-----------|-----|

### Test 4: Slow circles (3s per circle, 20 trials)

| Pass rate | TBD |
|-----------|-----|

### Test 5: Haptic feel (qualitative, 10 minutes play)

- Haptic ON feel: TBD (1–5 satisfaction rating)
- Haptic OFF feel: TBD (1–5 satisfaction rating)
- Notes: TBD

### Test 6: GPU Particle FPS (Godot Remote Profiler)

- Peak frame time during coin burst: TBD ms
- Sustained FPS during burst: TBD
- Target: ≥ 60 FPS (≤ 16.6ms)

### Test 7: Timer accuracy (wall clock comparison)

- Measured elapsed for 8.0s timer: TBD seconds
- Acceptable variance: ± 100ms

---

## Results

*(Fill in after testing)*

| Metric | Target | Actual | Pass? |
|--------|--------|--------|-------|
| Normal gesture pass rate | ≥ 18/20 | TBD | TBD |
| Straight swipe false positive | ≤ 1/20 | TBD | TBD |
| Fast gesture (0.8s/circle) pass rate | ≥ 15/20 | TBD | TBD |
| Slow gesture (3s/circle) pass rate | ≥ 18/20 | TBD | TBD |
| Haptic satisfaction (with) | ≥ 4/5 | TBD | TBD |
| GPU Particle FPS | ≥ 60 | TBD | TBD |
| Timer accuracy (8s) | ± 100ms | TBD | TBD |

---

## Edge Cases Encountered

*(Document any unexpected behavior during testing)*

- [ ] ±π wrap-around triggered false circle count: Y/N
- [ ] Finger lift mid-gesture silently accumulated: Y/N
- [ ] Multi-touch interference: Y/N
- [ ] `InputEventScreenDrag` event frequency drop on low-battery mode: Y/N

---

## Architectural Notes for Production Rewrite

*(Differences the production `src/core/touch_gesture_input/` implementation must address)*

- [ ] Center point must be injected (not captured on first touch) — needed for
  multi-oven UX where gesture must be anchored to a specific dough node
- [ ] `circles_required` exported as variable (not `const`) for config-driven tuning
- [ ] `MIN_RADIUS` and `MAX_RADIUS` must come from config resource
- [ ] Production version must respect `SettingsSystem.get_haptic_enabled()`
- [ ] `gesture_progress(fraction)` signal must be emitted for UI data binding
- [ ] Finger-lift mid-gesture must emit `gesture_cancelled` with accumulated progress
  (for potential partial-knead save state)

---

## Recommendation

**PROCEED / PIVOT / KILL** — *TBD after testing*

### If PROCEED:
> Circular drag detection is reliable and feels satisfying. Proceed to production
> implementation of Touch/Gesture Input system (D-08 GDD) using lessons above.

### If PIVOT (example — replace with actual findings):
> Circular drag unreliable at < 1.5s/circle on mid-range hardware.
> Recommend switching to **tap-count** mechanic (3 taps = dough ready) as fallback.
> Revise `bread-master-core-design.md` Section 3 before any Alpha code begins.

### If KILL:
> Core ASMR loop is not achievable with Godot 4.6 touch input on target hardware.
> Full game concept redesign required.

---

## Lessons Learned

*(Fill in after testing)*

- TBD
