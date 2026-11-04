class_name QuickTimeSystem
extends CanvasLayer

# ==========================================================================
#			Dispatching and completion signals
# ==========================================================================

signal event_started(actionable_event: ActionableEvent)
signal event_resolved(actionable_event: ActionableEvent, result: int, state: int, timing_error: float)
signal sequence_started()
signal sequence_finished()
signal sequence_stopped()

const ACTIONABLE_EVENT_SCENE: PackedScene = preload("res://systems/quicktime/actionable_event/actionable_event.tscn")

@export var dispatches: Array[QuickTimeDispatch] = []
@export var auto_start: bool = false
@export var loop: bool = false
@export_range(0.0, 60.0, 0.01, "or_greater") var loop_delay: float = 0.5:
	set(value):
		loop_delay = maxf(value, 0.0) if is_finite(value) else 0.0
## Temporarily release a captured cursor while visible mouse prompts are active.
@export var manage_mouse_mode: bool = true

var sequence_running: bool = false

var _event_root: Node2D
var _active_events: Array[ActionableEvent] = []
var _event_attempts: Dictionary = {}
var _world_events: Dictionary = {}
var _sequence_events: Dictionary = {}
var _sequence_entries: Array[QuickTimeDispatch] = []
var _sequence_index: int = 0
var _sequence_elapsed: float = 0.0
var _next_dispatch_time: float = 0.0
var _sequence_generation: int = 0
var _waiting_for_loop: bool = false
var _loop_time_left: float = 0.0
var _shutting_down: bool = false

# Cursor ownership is shared so overlapping systems cannot restore it too soon.
static var _mouse_mode_owners: Array[QuickTimeSystem] = []
static var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

func _enter_tree() -> void:
	_shutting_down = false

func _ready() -> void:
	_event_root = get_node_or_null("Events") as Node2D
	if _event_root == null:
		_event_root = Node2D.new()
		_event_root.name = "Events"
		add_child(_event_root)
	visibility_changed.connect(_update_mouse_mode)
	if auto_start:
		start_sequence.call_deferred()

func _process(delta: float) -> void:
	for actionable_event in _active_events.duplicate():
		if is_instance_valid(actionable_event):
			_synchronize_event(actionable_event)
		else:
			_active_events.erase(actionable_event)
			_world_events.erase(actionable_event)
			_sequence_events.erase(actionable_event)
	_update_mouse_mode()
	_advance_sequence(delta)

func _unhandled_input(input_event: InputEvent) -> void:
	if not _can_dispatch() or not can_process() or not visible or not _event_root.is_visible_in_tree():
		return
	var viewport: Viewport = get_viewport()
	# Dispatch order determines ownership when targets or keyboard actions overlap.
	for actionable_event in _active_events.duplicate():
		if not is_instance_valid(actionable_event) or not actionable_event.quicktime_active:
			continue
		_synchronize_event(actionable_event)
		if not is_instance_valid(actionable_event) or not actionable_event.quicktime_active:
			continue
		if actionable_event.try_input(input_event):
			if is_instance_valid(viewport):
				viewport.set_input_as_handled()
			return

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Children can emit cancellation while the system is being freed.
		_shutting_down = true
		_release_mouse_mode()

func _exit_tree() -> void:
	_shutting_down = true
	sequence_running = false
	_sequence_generation += 1
	_release_mouse_mode()
	_active_events.clear()
	_event_attempts.clear()
	_world_events.clear()
	_sequence_events.clear()
	_sequence_entries.clear()

# ==========================================================================
#			Individual events
# ==========================================================================

## screen_position is expressed in viewport pixels, independent of canvas transforms.
func dispatch_event(configuration: QuickTimeEvent, screen_position: Vector2) -> ActionableEvent:
	return _create_event(configuration, screen_position)

## The prompt follows target in the same viewport as this system.
func dispatch_event_3d(configuration: QuickTimeEvent, target: Node3D, camera: Camera3D = null, offset: Vector3 = Vector3.ZERO) -> ActionableEvent:
	if not _valid_world_target(target, camera):
		return null
	return _create_event(configuration, Vector2.ZERO, target, camera, offset)

func cancel_all_events() -> void:
	var events_to_cancel: Dictionary = _capture_attempts(_active_events)
	stop_sequence()
	_cancel_attempts(events_to_cancel)
	_update_mouse_mode()

func _create_event(configuration: QuickTimeEvent, screen_position: Vector2, target: Node3D = null, camera: Camera3D = null, offset: Vector3 = Vector3.ZERO, generation: int = -1) -> ActionableEvent:
	if configuration == null or not _can_dispatch():
		return null
	if not is_instance_valid(_event_root) or not screen_position.is_finite() or not offset.is_finite():
		return null
	var actionable_event: ActionableEvent = ACTIONABLE_EVENT_SCENE.instantiate() as ActionableEvent
	actionable_event.event = configuration
	actionable_event.input_managed = true
	actionable_event.started.connect(_on_event_started.bind(actionable_event))
	actionable_event.resolved.connect(_on_event_resolved.bind(actionable_event))
	actionable_event.feedback_finished.connect(_on_event_feedback_finished.bind(actionable_event))
	actionable_event.tree_exiting.connect(_on_event_exiting.bind(actionable_event))
	_active_events.append(actionable_event)
	if generation >= 0:
		_sequence_events[actionable_event] = generation
	if target != null:
		_world_events[actionable_event] = {
			"target": target,
			"camera": camera,
			"explicit_camera": camera != null,
			"offset": offset
		}
	_event_root.add_child(actionable_event)
	actionable_event.position = _event_root.make_canvas_position_local(screen_position)
	_synchronize_event(actionable_event)
	if not is_instance_valid(actionable_event) or actionable_event.is_queued_for_deletion():
		return null
	actionable_event.start_quicktime()
	if not is_instance_valid(actionable_event) or actionable_event.is_queued_for_deletion():
		_update_mouse_mode()
		return null
	_update_mouse_mode()
	return actionable_event

func _on_event_started(actionable_event: ActionableEvent) -> void:
	if _shutting_down:
		return
	# Restarting a managed node from its result listener creates a new attempt.
	_event_attempts[actionable_event] = int(_event_attempts.get(actionable_event, 0)) + 1
	if not _active_events.has(actionable_event):
		_active_events.append(actionable_event)
	_update_mouse_mode()
	event_started.emit(actionable_event)

func _on_event_resolved(result: int, state: int, timing_error: float, actionable_event: ActionableEvent) -> void:
	# Remove ownership before notifying listeners, which may dispatch another event.
	_active_events.erase(actionable_event)
	_sequence_events.erase(actionable_event)
	_update_mouse_mode()
	if _shutting_down:
		return
	event_resolved.emit(actionable_event, result, state, timing_error)
	_check_sequence_finished()

func _on_event_feedback_finished(actionable_event: ActionableEvent) -> void:
	if not is_instance_valid(actionable_event) or actionable_event.quicktime_active:
		return
	_world_events.erase(actionable_event)
	_event_attempts.erase(actionable_event)
	actionable_event.queue_free()

func _on_event_exiting(actionable_event: ActionableEvent) -> void:
	_active_events.erase(actionable_event)
	_event_attempts.erase(actionable_event)
	_world_events.erase(actionable_event)
	_sequence_events.erase(actionable_event)
	_update_mouse_mode()
	if not _shutting_down:
		_check_sequence_finished.call_deferred()

# ==========================================================================
#			Configured sequences
# ==========================================================================

func start_sequence() -> void:
	var previous_generation: int = _sequence_generation
	stop_sequence()
	# Preserve a replacement sequence started by a cancellation listener.
	if _sequence_generation != previous_generation + 1:
		return
	if not _can_dispatch():
		return
	_sequence_entries.clear()
	for entry in dispatches:
		if entry != null:
			_sequence_entries.append(entry.duplicate(true) as QuickTimeDispatch)
	if _sequence_entries.is_empty():
		return
	_sequence_generation += 1
	var generation: int = _sequence_generation
	sequence_running = true
	_begin_sequence_cycle()
	sequence_started.emit()
	if generation == _sequence_generation and sequence_running:
		_advance_sequence(0.0)

func stop_sequence() -> void:
	var was_running: bool = sequence_running
	sequence_running = false
	_sequence_generation += 1
	_waiting_for_loop = false
	_sequence_entries.clear()
	# Detach the old sequence first; cancellation signals can start a new sequence.
	var events_to_cancel: Dictionary = _capture_attempts(_sequence_events.keys())
	_sequence_events.clear()
	_cancel_attempts(events_to_cancel)
	if was_running and not _shutting_down:
		sequence_stopped.emit()

func _begin_sequence_cycle() -> void:
	_sequence_index = 0
	_sequence_elapsed = 0.0
	_next_dispatch_time = _sequence_entries[0].delay
	_waiting_for_loop = false

func _advance_sequence(delta: float) -> void:
	if not sequence_running or not _can_dispatch() or not can_process():
		return
	if _waiting_for_loop:
		_loop_time_left -= delta
		if _loop_time_left > 0.0:
			return
		# A zero loop delay still starts at most one new cycle per frame.
		delta = -_loop_time_left
		_begin_sequence_cycle()
	_sequence_elapsed += delta
	var generation: int = _sequence_generation
	while sequence_running and _can_dispatch() and generation == _sequence_generation and _sequence_index < _sequence_entries.size():
		if _sequence_elapsed < _next_dispatch_time:
			break
		var entry: QuickTimeDispatch = _sequence_entries[_sequence_index]
		_sequence_index += 1
		if _sequence_index < _sequence_entries.size():
			_next_dispatch_time += _sequence_entries[_sequence_index].delay
		_dispatch_entry(entry, generation)
	if generation == _sequence_generation:
		_check_sequence_finished()

func _dispatch_entry(entry: QuickTimeDispatch, generation: int) -> void:
	if entry.event == null:
		push_warning("Quick time dispatch has no event configuration.")
		return
	if entry.target_path.is_empty():
		var screen_position: Vector2 = get_viewport().get_visible_rect().size * entry.screen_position
		_create_event(entry.event, screen_position, null, null, Vector3.ZERO, generation)
		return
	var target: Node3D = get_node_or_null(entry.target_path) as Node3D
	var camera: Camera3D = null
	if not entry.camera_path.is_empty():
		camera = get_node_or_null(entry.camera_path) as Camera3D
		if camera == null:
			push_warning("Quick time dispatch camera path does not resolve to a Camera3D.")
			return
	if _valid_world_target(target, camera):
		_create_event(entry.event, Vector2.ZERO, target, camera, entry.world_offset, generation)

func _check_sequence_finished() -> void:
	if not sequence_running or not _can_dispatch() or _waiting_for_loop:
		return
	if _sequence_index < _sequence_entries.size() or not _sequence_events.is_empty():
		return
	if loop:
		_waiting_for_loop = true
		_loop_time_left = loop_delay
	else:
		sequence_running = false
		_sequence_entries.clear()
		sequence_finished.emit()

func _capture_attempts(events: Array) -> Dictionary:
	var attempts: Dictionary = {}
	for actionable_event in events:
		if is_instance_valid(actionable_event):
			attempts[actionable_event] = _event_attempts.get(actionable_event, 0)
	return attempts

func _cancel_attempts(attempts: Dictionary) -> void:
	for actionable_event in attempts:
		if not is_instance_valid(actionable_event):
			continue
		# A listener may restart a later event while an earlier one is cancelled.
		if _event_attempts.get(actionable_event, -1) == attempts[actionable_event]:
			actionable_event.cancel_quicktime()

func _can_dispatch() -> bool:
	return is_inside_tree() and not _shutting_down and not is_queued_for_deletion() and is_instance_valid(_event_root) and _event_root.is_inside_tree() and not _event_root.is_queued_for_deletion()

# ==========================================================================
#			Projection from 3D to the quick time overlay
# ==========================================================================

func _valid_world_target(target: Node3D, camera: Camera3D) -> bool:
	if not _can_dispatch() or not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():
		return false
	if target.get_viewport() != get_viewport():
		return false
	if camera != null and (not is_instance_valid(camera) or not camera.is_inside_tree() or camera.is_queued_for_deletion() or camera.get_viewport() != get_viewport()):
		return false
	return true

func _synchronize_event(actionable_event: ActionableEvent) -> void:
	if not _world_events.has(actionable_event):
		return
	var world_event: Dictionary = _world_events[actionable_event]
	if not is_instance_valid(world_event["target"]):
		actionable_event.cancel_quicktime()
		return
	var target: Node3D = world_event["target"] as Node3D
	var camera: Camera3D = null
	if not target.is_inside_tree() or target.is_queued_for_deletion() or target.get_viewport() != get_viewport():
		actionable_event.cancel_quicktime()
		return
	if world_event["explicit_camera"]:
		if not is_instance_valid(world_event["camera"]):
			actionable_event.cancel_quicktime()
			return
		camera = world_event["camera"] as Camera3D
		if not camera.is_inside_tree() or camera.is_queued_for_deletion() or camera.get_viewport() != get_viewport():
			actionable_event.cancel_quicktime()
			return
	else:
		camera = get_viewport().get_camera_3d()
	if not is_instance_valid(camera) or camera.is_queued_for_deletion():
		actionable_event.hide()
		return
	var world_position: Vector3 = target.global_position + world_event["offset"]
	if not world_position.is_finite() or not target.is_visible_in_tree() or camera.is_position_behind(world_position) or not camera.is_position_in_frustum(world_position):
		actionable_event.hide()
		return
	var screen_position: Vector2 = camera.unproject_position(world_position)
	actionable_event.visible = screen_position.is_finite() and get_viewport().get_visible_rect().has_point(screen_position)
	if actionable_event.visible:
		actionable_event.position = _event_root.make_canvas_position_local(screen_position)

# ==========================================================================
#			Temporary mouse ownership for captured-cursor games
# ==========================================================================

func _update_mouse_mode() -> void:
	var needs_cursor: bool = false
	if manage_mouse_mode and visible and _can_dispatch():
		for actionable_event in _active_events:
			if not is_instance_valid(actionable_event) or actionable_event.is_queued_for_deletion() or not actionable_event.quicktime_active or not actionable_event.is_visible_in_tree():
				continue
			if actionable_event.get_event_configuration().event_type == QuickTimeEvent.ActionableEventType.EVENT_CLICK:
				needs_cursor = true
				break
	if needs_cursor:
		_acquire_mouse_mode()
	else:
		_release_mouse_mode()

func _acquire_mouse_mode() -> void:
	if _mouse_mode_owners.has(self):
		return
	if _mouse_mode_owners.is_empty() or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		# Preserve a newer external mode when another system requests the cursor.
		_previous_mouse_mode = Input.mouse_mode
	_mouse_mode_owners.append(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _release_mouse_mode() -> void:
	if not _mouse_mode_owners.has(self):
		return
	_mouse_mode_owners.erase(self)
	if _mouse_mode_owners.is_empty() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = _previous_mouse_mode
