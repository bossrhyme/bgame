extends Node

## Haptic feedback wrapper for gesture events.
## Wraps Input.vibrate_handheld() — no-ops silently on desktop.
## Test WITH and WITHOUT haptic to assess feel difference for PROTOTYPE_REPORT.

var haptic_enabled: bool = true  # toggle in editor for feel comparison


func pulse() -> void:
	if not haptic_enabled:
		return
	Input.vibrate_handheld(30)  # 30ms — "progress" tick per partial circle


func complete() -> void:
	if not haptic_enabled:
		return
	Input.vibrate_handheld(80)  # 80ms — "done" confirmation on gesture complete
