@tool
class_name ActionableEvent
extends Node2D

signal started()
signal state_changed(state: int)
signal resolved(result: int, state: int, timing_error: float)
signal feedback_finished()

# ==========================================================================
# 			Configuration and editor visualization
# ==========================================================================

@export var event: QuickTimeEvent = QuickTimeEvent.new():
	set(value):
		if event != null and event.changed.is_connected(_on_configuration_changed):
			event.changed.disconnect(_on_configuration_changed)
		event = value if value != null else QuickTimeEvent.new()
		if not event.changed.is_connected(_on_configuration_changed):
			event.changed.connect(_on_configuration_changed)
		_on_configuration_changed()
## The dispatcher owns input when this event is managed by QuickTimeSystem.
@export var input_managed: bool = false
## Preview the approach in the editor, from start to the perfect hit.
@export_range(0.0, 1.0, 0.01) var preview_progress: float = 0.0:
	set(value):
		preview_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

@onready var c_start_marker: Marker2D = get_node_or_null("TimingBegin")
@onready var c_pstart_marker: Marker2D = get_node_or_null("TimingPStart")
@onready var c_perfect_marker: Marker2D = get_node_or_null("TimingPerfect")
@onready var c_pend_marker: Marker2D = get_node_or_null("TimingPEnd")
@onready var c_end_marker: Marker2D = get_node_or_null("TimingEnd")

# ==========================================================================
# 			Quick time state and result
# ==========================================================================

enum QuicktimeState
{
	STATE_EARLY,
	STATE_PEARLY,
	STATE_PERFECT,
	STATE_PLATE,
	STATE_LATE
}

enum QuicktimeResult
{
	RESULT_NONE,
	RESULT_SUCCESS,
	RESULT_TOO_EARLY,
	RESULT_MISSED,
	RESULT_CANCELLED
}

const TIMING_EPSILON: float = 0.0000001

var quicktime_active: bool = false
var quicktime_state: QuicktimeState = QuicktimeState.STATE_EARLY
var quicktime_result: QuicktimeResult = QuicktimeResult.RESULT_NONE
var timing_error: float = 0.0
var outer_circle_current_radius: float = 0.0

var _active_event: QuickTimeEvent = null
var _elapsed_time: float = 0.0
var _feedback_elapsed: float = 0.0
var _feedback_complete: bool = true
var _last_clock_usec: int = 0
var _clock_running: bool = false
var _attempt_id: int = 0
var _exiting_tree: bool = false

func _enter_tree() -> void:
	_exiting_tree = false
	_last_clock_usec = _get_clock_usec()
	_clock_running = can_process()

func _ready() -> void:
	if not event.changed.is_connected(_on_configuration_changed):
		event.changed.connect(_on_configuration_changed)
	_on_configuration_changed()

func start_quicktime() -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or is_queued_for_deletion() or _exiting_tree:
		return
	_attempt_id += 1
	var attempt_id: int = _attempt_id
	if quicktime_active:
		cancel_quicktime()
	# A result listener may already have started a replacement attempt.
	if attempt_id != _attempt_id or is_queued_for_deletion():
		return
	_active_event = event.duplicate(true) as QuickTimeEvent
	_elapsed_time = 0.0
	_feedback_elapsed = 0.0
	_feedback_complete = false
	_last_clock_usec = _get_clock_usec()
	_clock_running = can_process()
	quicktime_result = QuicktimeResult.RESULT_NONE
	timing_error = 0.0
	quicktime_state = get_state_at_time(0.0)
	outer_circle_current_radius = _active_event.get_approach_radius(0.0)
	quicktime_active = true
	queue_redraw()
	started.emit()
	if attempt_id == _attempt_id and quicktime_active:
		state_changed.emit(quicktime_state)

func cancel_quicktime() -> void:
	if not quicktime_active:
		return
	_sync_clock()
	_resolve_quicktime(QuicktimeResult.RESULT_CANCELLED)

func get_elapsed_time() -> float:
	_sync_clock()
	return _elapsed_time

func get_event_configuration() -> QuickTimeEvent:
	if _active_event != null and not Engine.is_editor_hint():
		return _active_event
	return event

func get_state_at_time(elapsed: float) -> QuicktimeState:
	var configuration: QuickTimeEvent = get_event_configuration()
	var error: float = elapsed - configuration.duration
	# Test acceptable bounds first so a perfect window never extends outside them.
	if error < -configuration.get_allowed_before() - TIMING_EPSILON:
		return QuicktimeState.STATE_EARLY
	if error > configuration.allowed_dur_after + TIMING_EPSILON:
		return QuicktimeState.STATE_LATE
	if error < -configuration.get_perfect_before() - TIMING_EPSILON:
		return QuicktimeState.STATE_PEARLY
	if error > configuration.get_perfect_after() + TIMING_EPSILON:
		return QuicktimeState.STATE_PLATE
	return QuicktimeState.STATE_PERFECT

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_sync_clock()
	if quicktime_active:
		if _elapsed_time > _active_event.get_total_duration() + TIMING_EPSILON:
			_resolve_quicktime(QuicktimeResult.RESULT_MISSED)
		else:
			outer_circle_current_radius = _active_event.get_approach_radius(_elapsed_time)
			var current_state: QuicktimeState = get_state_at_time(_elapsed_time)
			if current_state != quicktime_state:
				quicktime_state = current_state
				state_changed.emit(quicktime_state)
	elif not _feedback_complete and _active_event != null:
		if _feedback_elapsed >= _active_event.feedback_duration:
			_feedback_complete = true
			feedback_finished.emit()
	queue_redraw()

func _resolve_quicktime(result: QuicktimeResult) -> void:
	if not quicktime_active:
		return
	quicktime_active = false
	quicktime_result = result
	quicktime_state = get_state_at_time(_elapsed_time)
	timing_error = _elapsed_time - _active_event.duration
	outer_circle_current_radius = _active_event.get_approach_radius(_elapsed_time)
	_feedback_elapsed = 0.0
	# Cancellation has no hit/miss animation, but still completes on the next frame.
	if result == QuicktimeResult.RESULT_CANCELLED:
		_feedback_elapsed = _active_event.feedback_duration
	queue_redraw()
	# All terminal state is captured before listeners can restart or dispatch events.
	resolved.emit(result, quicktime_state, timing_error)

# ==========================================================================
# 			Input
# ==========================================================================

func _unhandled_input(input_event: InputEvent) -> void:
	if not input_managed and try_input(input_event):
		get_viewport().set_input_as_handled()

func try_input(input_event: InputEvent) -> bool:
	if Engine.is_editor_hint() or not quicktime_active or not is_inside_tree():
		return false
	if not can_process() or not is_visible_in_tree() or is_queued_for_deletion():
		return false
	if not input_event.is_pressed() or input_event.is_echo() or input_event.is_canceled():
		return false
	if not _matches_input(input_event):
		return false
	_sync_clock()
	var current_state: QuicktimeState = get_state_at_time(_elapsed_time)
	if current_state == QuicktimeState.STATE_EARLY and _active_event.ignore_early_input:
		# This prompt owns the matching press even when it deliberately ignores it.
		return true
	match current_state:
		QuicktimeState.STATE_EARLY:
			_resolve_quicktime(QuicktimeResult.RESULT_TOO_EARLY)
		QuicktimeState.STATE_LATE:
			_resolve_quicktime(QuicktimeResult.RESULT_MISSED)
		_:
			_resolve_quicktime(QuicktimeResult.RESULT_SUCCESS)
	return true

func _matches_input(input_event: InputEvent) -> bool:
	if _active_event.event_type == QuickTimeEvent.ActionableEventType.EVENT_CLICK:
		if not input_event is InputEventMouseButton:
			return false
		if input_event.button_index != _active_event.mouse_button:
			return false
		var local_point: Vector2 = make_canvas_position_local(input_event.position)
		return local_point.length_squared() <= _active_event.radius * _active_event.radius
	if _active_event.input_action != &"":
		if not InputMap.has_action(_active_event.input_action):
			return false
		# Keyboard actions also accept synthetic InputEventAction events for accessibility.
		if not input_event is InputEventKey and not input_event is InputEventAction:
			return false
		return input_event.is_action_pressed(_active_event.input_action, false, true)
	return input_event is InputEventKey and input_event.keycode == _active_event.key

# ==========================================================================
# 			A single clock for rendering and input-time judgement
# ==========================================================================

func _get_clock_usec() -> int:
	return Time.get_ticks_usec()

func _sync_clock() -> void:
	var current_clock: int = _get_clock_usec()
	if _clock_running:
		var elapsed: float = maxf(float(current_clock - _last_clock_usec) / 1000000.0, 0.0) * Engine.time_scale
		if quicktime_active:
			_elapsed_time += elapsed
		elif not _feedback_complete:
			_feedback_elapsed += elapsed
	_last_clock_usec = current_clock

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED or what == NOTIFICATION_DISABLED or what == NOTIFICATION_ENABLED:
		_sync_clock()
		_clock_running = is_inside_tree() and can_process()

func _exit_tree() -> void:
	_exiting_tree = true
	_sync_clock()
	_clock_running = false
	if quicktime_active:
		_resolve_quicktime(QuicktimeResult.RESULT_CANCELLED)

# ==========================================================================
# 			Drawing and feedback
# ==========================================================================

func _draw() -> void:
	var configuration: QuickTimeEvent = get_event_configuration()
	var preview: bool = Engine.is_editor_hint()
	if not preview and not quicktime_active and _feedback_complete:
		return
	if not preview and quicktime_result == QuicktimeResult.RESULT_CANCELLED:
		return
	var target_radius: float = configuration.radius
	var ring_radius: float = outer_circle_current_radius
	var ring_color: Color = configuration.approach_color
	var opacity: float = 1.0
	var feedback_progress: float = 0.0
	if preview:
		ring_radius = configuration.get_approach_radius(preview_progress * configuration.duration)
	elif not quicktime_active:
		feedback_progress = clampf(_feedback_elapsed / maxf(configuration.feedback_duration, 0.001), 0.0, 1.0)
		opacity = 1.0 - feedback_progress
		ring_color = configuration.perfect_color if quicktime_result == QuicktimeResult.RESULT_SUCCESS else configuration.failure_color
		target_radius *= 1.0 + 0.12 * sin(feedback_progress * PI * 0.5)
		ring_radius = lerpf(ring_radius, target_radius * 1.18, feedback_progress)
	elif quicktime_state == QuicktimeState.STATE_PERFECT:
		ring_color = configuration.perfect_color
	var fill_color: Color = configuration.target_color
	fill_color.a *= opacity * 0.85
	var border_color: Color = ring_color
	border_color.a *= opacity * 0.65
	ring_color.a *= opacity
	draw_circle(Vector2.ZERO, target_radius, fill_color, true, -1.0, true)
	draw_arc(Vector2.ZERO, target_radius, 0.0, TAU, 128, border_color, 2.5, true)
	draw_arc(Vector2.ZERO, maxf(ring_radius, 0.1), 0.0, TAU, 192, ring_color, 3.0, true)
	var text: String = configuration.get_prompt_text()
	if not preview and not quicktime_active:
		text = get_result_text()
	var font: Font = ThemeDB.fallback_font
	var font_size: int = clampi(roundi(configuration.radius * 0.3), 12, 24)
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if text_width > configuration.radius * 1.7:
		font_size = maxi(8, floori(font_size * configuration.radius * 1.7 / text_width))
		text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_position: Vector2 = Vector2(-text_width * 0.5, (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string(font, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 1.0, 1.0, opacity))

func get_result_text() -> String:
	match quicktime_result:
		QuicktimeResult.RESULT_SUCCESS:
			match quicktime_state:
				QuicktimeState.STATE_PERFECT:
					return "PERFECT"
				QuicktimeState.STATE_PEARLY:
					return "EARLY HIT"
				_:
					return "LATE HIT"
		QuicktimeResult.RESULT_TOO_EARLY:
			return "TOO EARLY"
		QuicktimeResult.RESULT_MISSED:
			return "MISS"
		QuicktimeResult.RESULT_CANCELLED:
			return "CANCELLED"
	return ""

func _on_configuration_changed() -> void:
	if is_node_ready():
		_update_markers()
	queue_redraw()

func _update_markers() -> void:
	if not Engine.is_editor_hint():
		return
	_set_marker(c_start_marker, 0.0)
	_set_marker(c_pstart_marker, event.duration - event.get_allowed_before())
	_set_marker(c_perfect_marker, event.duration)
	_set_marker(c_pend_marker, event.get_total_duration())
	_set_marker(c_end_marker, event.get_total_duration())

func _set_marker(marker: Marker2D, elapsed: float) -> void:
	if marker != null:
		marker.position = Vector2(-event.get_approach_radius(elapsed), 0.0)
