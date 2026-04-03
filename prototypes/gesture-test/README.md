# Prototype: gesture-test

## Hypothesis

> **We believe** that `InputEventScreenDrag` in Godot 4.6 on Android can
> reliably detect 3 complete clockwise circular gestures within a defined
> radius, triggering a "dough ready" state with < 100ms response time and
> < 5% false positive rate from accidental straight swipes.

This is the single highest-risk unknown for *Ekmek Ustası*. The core ASMR
fantasy — kneading dough with a satisfying circular drag — depends entirely
on this gesture being both reliable and *feel-good*. If the gesture fails
here, the core loop must be redesigned before any production code is written.

## What Is Being Tested

1. **Circular drag detection** — Can `atan2`-based angle accumulation reliably
   count full circles on real hardware with variable input frequency?
2. **Haptic + visual feedback loop** — Does the pulsing dough + vibration
   create the intended ASMR satisfaction?
3. **Timer-based bake loop** — Does `Timer.timeout` (ADR-0003 pattern) fire
   correctly for the idle loop on mobile without battery drain or frame hitches?
4. **GPU particle performance** — Does the coin burst `GPUParticles2D`
   maintain 60 FPS on mid-range Android?

## How to Run

1. Open Godot 4.6
2. `File > Open Project` → select this directory (`prototypes/gesture-test/`)
3. Open scene `scenes/GestureTestMain.tscn`
4. Deploy to Android device via `Remote Debug > Deploy & Run`
5. **Do NOT test on desktop** — gesture detection is `InputEventScreenDrag`
   only; mouse drag will not trigger the circular gesture logic

## Current Status

`in-progress`

## Findings

*(Fill in after testing. See PROTOTYPE_REPORT.md for full analysis.)*

| Metric | Result |
|--------|--------|
| False positive rate | TBD |
| False negative rate | TBD |
| Slow gesture (3s/circle) | TBD |
| Fast gesture (0.8s/circle) | TBD |
| 60 FPS during particles | TBD |
| Haptic feel with/without | TBD |
| Recommendation | TBD |
