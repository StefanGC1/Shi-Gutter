extends Node2D

# ==========================================================================
#			Quick time playground
# ==========================================================================

enum ExampleType
{
	EXAMPLE_MOUSE,
	EXAMPLE_KEYBOARD,
	EXAMPLE_SEQUENCE,
	EXAMPLE_WORLD
}

@export var mouse_event: QuickTimeEvent
@export var keyboard_event: QuickTimeEvent

var current_example: ExampleType = ExampleType.EXAMPLE_MOUSE
var active_events: Array[ActionableEvent] = []
var world_time: float = 0.0

@onready var quicktime_system: QuickTimeSystem = $QuickTimeSystem
@onready var world: Node3D = $World
@onready var world_target: Node3D = $World/Target
@onready var world_camera: Camera3D = $World/Camera3D
@onready var instructions_label: Label = $Interface/Panel/Margin/Content/InstructionsLabel
@onready var active_label: Label = $Interface/Status/Margin/Content/ActiveLabel
@onready var state_label: Label = $Interface/Status/Margin/Content/StateLabel
@onready var result_label: Label = $Interface/Status/Margin/Content/ResultLabel

func _ready() -> void:
	quicktime_system.event_started.connect(_on_event_started)
	quicktime_system.event_resolved.connect(_on_event_resolved)
	quicktime_system.sequence_finished.connect(_on_sequence_finished)
	$Interface/Panel/Margin/Content/Buttons/MouseButton.pressed.connect(_on_mouse_pressed)
	$Interface/Panel/Margin/Content/Buttons/KeyboardButton.pressed.connect(_on_keyboard_pressed)
	$Interface/Panel/Margin/Content/Buttons/SequenceButton.pressed.connect(_on_sequence_pressed)
	$Interface/Panel/Margin/Content/Buttons/WorldButton.pressed.connect(_on_world_pressed)
	$Interface/Panel/Margin/Content/Buttons/StopButton.pressed.connect(_stop_example)
	world.visible = false
	_update_active_label()

func _process(delta: float) -> void:
	if not world.visible:
		return

	world_time += delta
	world_target.position.x = sin(world_time * 0.75) * 1.25
	world_target.position.y = 0.15 + sin(world_time * 1.1) * 0.2

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_restart_example()
			get_viewport().set_input_as_handled()
		return

	if event is not InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_1:
			_on_mouse_pressed()
		KEY_2:
			_on_keyboard_pressed()
		KEY_3:
			_on_sequence_pressed()
		KEY_4:
			_on_world_pressed()
		KEY_ESCAPE:
			_stop_example()
		_:
			return
	get_viewport().set_input_as_handled()

# ==========================================================================
#			Dispatch examples
# ==========================================================================

func _on_mouse_pressed() -> void:
	current_example = ExampleType.EXAMPLE_MOUSE
	_restart_example()

func _on_keyboard_pressed() -> void:
	current_example = ExampleType.EXAMPLE_KEYBOARD
	_restart_example()

func _on_sequence_pressed() -> void:
	current_example = ExampleType.EXAMPLE_SEQUENCE
	_restart_example()

func _on_world_pressed() -> void:
	current_example = ExampleType.EXAMPLE_WORLD
	_restart_example()

func _restart_example() -> void:
	quicktime_system.stop_sequence()
	quicktime_system.cancel_all_events()
	world.visible = current_example == ExampleType.EXAMPLE_WORLD
	var screen_position: Vector2 = get_viewport_rect().size * Vector2(0.5, 0.54)

	match current_example:
		ExampleType.EXAMPLE_MOUSE:
			instructions_label.text = "Click inside the target when the shrinking ring meets its border. Right-click to retry."
			quicktime_system.dispatch_event(mouse_event, screen_position)
		ExampleType.EXAMPLE_KEYBOARD:
			instructions_label.text = "Press the displayed key when the rings meet. The pointer can be anywhere. Right-click to retry."
			quicktime_system.dispatch_event(keyboard_event, screen_position)
		ExampleType.EXAMPLE_SEQUENCE:
			instructions_label.text = "Follow three prompts: click, keyboard, click. Each has its own timing and position."
			quicktime_system.start_sequence()
		ExampleType.EXAMPLE_WORLD:
			instructions_label.text = "Click the prompt following the moving 3D target when the rings meet. Right-click to retry."
			quicktime_system.dispatch_event_3d(mouse_event, world_target, world_camera)

func _stop_example() -> void:
	quicktime_system.stop_sequence()
	quicktime_system.cancel_all_events()
	state_label.text = "Current window: idle"
	instructions_label.text = "Choose a demo above, or right-click to retry the selected demo."

# ==========================================================================
#			Feedback from the event system
# ==========================================================================

func _on_event_started(event_node: ActionableEvent) -> void:
	active_events.append(event_node)
	event_node.state_changed.connect(_on_state_changed.bind(event_node))
	_update_active_label()
	_on_state_changed(event_node.quicktime_state, event_node)

func _on_state_changed(state: int, event_node: ActionableEvent) -> void:
	if not is_instance_valid(event_node) or not event_node.quicktime_active:
		return
	state_label.text = "Current window: " + _get_state_text(state)

func _on_event_resolved(event_node: ActionableEvent, result: int, state: int, timing_error: float) -> void:
	active_events.erase(event_node)
	_update_active_label()
	if active_events.is_empty():
		state_label.text = "Current window: idle"

	var result_text: String
	var result_color: Color = Color("#f3b86c")
	match result:
		ActionableEvent.QuicktimeResult.RESULT_SUCCESS:
			result_text = _get_state_text(state).to_upper()
			result_color = Color("#70ddba")
		ActionableEvent.QuicktimeResult.RESULT_TOO_EARLY:
			result_text = "TOO EARLY"
		ActionableEvent.QuicktimeResult.RESULT_MISSED:
			result_text = "MISSED — no input before the window closed"
		ActionableEvent.QuicktimeResult.RESULT_CANCELLED:
			result_text = "CANCELLED"
			result_color = Color("#a7b9ca")
		_:
			result_text = "—"

	if result == ActionableEvent.QuicktimeResult.RESULT_SUCCESS or result == ActionableEvent.QuicktimeResult.RESULT_TOO_EARLY:
		var error_ms: int = roundi(absf(timing_error) * 1000.0)
		if error_ms == 0:
			result_text += " · 0 ms"
		else:
			var direction: String = "early" if timing_error < 0.0 else "late"
			result_text += " · %d ms %s" % [error_ms, direction]
	result_label.text = "Last result: " + result_text
	result_label.add_theme_color_override("font_color", result_color)

func _on_sequence_finished() -> void:
	instructions_label.text = "Sequence complete. Right-click to run it again, or choose another demo."

func _update_active_label() -> void:
	active_label.text = "Active events: " + str(active_events.size())

func _get_state_text(state: int) -> String:
	match state:
		ActionableEvent.QuicktimeState.STATE_EARLY:
			return "too early"
		ActionableEvent.QuicktimeState.STATE_PEARLY:
			return "accepted early"
		ActionableEvent.QuicktimeState.STATE_PERFECT:
			return "perfect"
		ActionableEvent.QuicktimeState.STATE_PLATE:
			return "accepted late"
		ActionableEvent.QuicktimeState.STATE_LATE:
			return "too late"
	return "idle"
