@tool
class_name QuickTimeEvent
extends Resource

# ==========================================================================
# 			Input required for the quick time event
# ==========================================================================

enum ActionableEventType
{
	EVENT_CLICK,
	EVENT_KEY
}

@export var event_type: ActionableEventType = ActionableEventType.EVENT_CLICK:
	set(value):
		event_type = value
		emit_changed()
@export var mouse_button: MouseButton = MOUSE_BUTTON_LEFT:
	set(value):
		mouse_button = value
		emit_changed()
@export var key: Key = KEY_SPACE:
	set(value):
		key = value
		emit_changed()
## Optional Input Map action for keyboard events. An empty action uses key instead.
@export var input_action: StringName = &"":
	set(value):
		input_action = value
		emit_changed()
## Ignore matching presses before the allowed window instead of failing the attempt.
@export var ignore_early_input: bool = false

# ==========================================================================
# 			Timing, in seconds
# ==========================================================================

# Start ------------ Allowed Start -- Perfect Hit -- Allowed End
# Duration is the time until the perfect hit. The late allowance comes after it.
# Changing duration never moves the perfect hit away from the target border.
@export_group("Timing")
@export_range(0.05, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 1.2:
	set(value):
		duration = maxf(value, 0.05) if is_finite(value) else 1.2
		emit_changed()
@export_range(0.0, 1.0, 0.01, "or_greater", "suffix:s") var allowed_dur_before: float = 0.2:
	set(value):
		allowed_dur_before = maxf(value, 0.0) if is_finite(value) else 0.2
		emit_changed()
@export_range(0.0, 1.0, 0.01, "or_greater", "suffix:s") var allowed_dur_after: float = 0.2:
	set(value):
		allowed_dur_after = maxf(value, 0.0) if is_finite(value) else 0.2
		emit_changed()
@export_range(0.0, 0.5, 0.005, "or_greater", "suffix:s") var perfect_margin_of_error: float = 0.05:
	set(value):
		perfect_margin_of_error = maxf(value, 0.0) if is_finite(value) else 0.05
		emit_changed()

# ==========================================================================
# 			Appearance
# ==========================================================================

@export_group("Appearance")
@export_range(8.0, 300.0, 1.0, "or_greater", "suffix:px") var radius: float = 64.0:
	set(value):
		radius = maxf(value, 8.0) if is_finite(value) else 64.0
		emit_changed()
## Starting ring radius as a multiple of the target radius.
@export_range(1.05, 4.0, 0.05) var approach_scale: float = 2.2:
	set(value):
		approach_scale = clampf(value, 1.05, 4.0) if is_finite(value) else 2.2
		emit_changed()
@export_range(0.0, 2.0, 0.05, "suffix:s") var feedback_duration: float = 0.35:
	set(value):
		feedback_duration = maxf(value, 0.0) if is_finite(value) else 0.35
		emit_changed()
@export var target_color: Color = Color("#294866"):
	set(value):
		target_color = value
		emit_changed()
@export var approach_color: Color = Color("#79bfff"):
	set(value):
		approach_color = value
		emit_changed()
@export var perfect_color: Color = Color("#80e4bb"):
	set(value):
		perfect_color = value
		emit_changed()
@export var failure_color: Color = Color("#ff918c"):
	set(value):
		failure_color = value
		emit_changed()

# ==========================================================================
# 			Derived values, shared by judgement and visualization
# ==========================================================================

func get_allowed_before() -> float:
	return minf(allowed_dur_before, duration)

func get_perfect_before() -> float:
	return minf(perfect_margin_of_error, get_allowed_before())

func get_perfect_after() -> float:
	return minf(perfect_margin_of_error, allowed_dur_after)

func get_total_duration() -> float:
	return duration + allowed_dur_after

func get_approach_radius(elapsed: float) -> float:
	var progress: float = maxf(elapsed, 0.0) / duration
	var travel: float = approach_scale - 1.0
	if progress <= 1.0:
		# Constant speed makes the approaching border easy to predict.
		return radius * (1.0 + travel * (1.0 - progress))
	# Continue smoothly inside the target during the late allowance. This has the
	# same speed at the perfect hit and cannot cross zero with a long late window.
	return radius * exp(-travel * (progress - 1.0))

func get_prompt_text() -> String:
	if event_type == ActionableEventType.EVENT_CLICK:
		match mouse_button:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
		return "MOUSE " + str(mouse_button)
	if input_action != &"" and InputMap.has_action(input_action):
		for input_event: InputEvent in InputMap.action_get_events(input_action):
			if input_event is InputEventKey:
				return input_event.as_text().replace(" (Physical)", "")
		return str(input_action)
	return OS.get_keycode_string(key)
