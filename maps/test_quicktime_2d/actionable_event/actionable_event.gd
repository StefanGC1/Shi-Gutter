@tool
class_name ActionableEvent
extends Area2D

# ==========================================================================
#			Debugging and visualization of the actionable event area
# ==========================================================================

@onready var c_start_marker = $TimingBegin
@onready var c_pstart_marker = $TimingPStart
@onready var c_perfect_marker = $TimingPerfect
@onready var c_pend_marker = $TimingPEnd
@onready var c_end_marker = $TimingEnd

# ==========================================================================
# ==========================================================================
# ==========================================================================

@export_range(1.0, 1000.0, 1.0, "or_greater") var radius: float = 32.0:
	set(value):
		radius = maxf(value, 1.0)
		if is_node_ready():
			_apply_radius()
			queue_redraw()

# Actionable event will be of two types:
# 	1. Click event
#	2. Key event
enum ActionableEventType
{
	EVENT_CLICK,
	EVENT_KEY
}
			
# Start -------------- Allowed Start -- Perfect Hit -- Allowed End -- End
# /---------------------------/--------------/---------------/---------/
# Indifferent of timer of outer circle, there will be a set in stone duration for
# the interval (allowed start, perfect hit, allowed end). Will be modifiable in editor.

@export var timer_duration: float = 1.0:
	set(value):
		timer_duration = maxf(value, 0.0)
@export var perfect_time: float = 0.5:
	set(value):
		perfect_time = clamp(value, 0.0, timer_duration)
@export var allowed_dur_before: float = 0.25:
	set(value):
		allowed_dur_before = clamp(value, 0.0, timer_duration)
@export var allowed_dur_after: float = 0.25:
	set(value):
		allowed_dur_after = clamp(value, 0.0, timer_duration)

# For the moving / shrinking outer circle, we will compute positions based on timer parameters
# The circle will be only a visual representation
@export var outer_circle_start_radius: float = 64.0:
	set(value):
		outer_circle_start_radius = maxf(value, 1.0)
@export var outer_circle_end_radius: float = 32.0:
	set(value):
		outer_circle_end_radius = maxf(value, 1.0)
var outer_circle_current_radius: float = outer_circle_start_radius
# Compute perfect timing position based on the timer parameters
var perfect_time_position: float:
	get:
		return outer_circle_start_radius + (perfect_time / timer_duration) * (outer_circle_end_radius - outer_circle_start_radius)

func _ready() -> void:
	outer_circle_current_radius = outer_circle_start_radius
	_apply_radius()
	queue_redraw()
	# Move the markers to their respective positions based on the timer parameters only in editor
	_update_markers()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color("#294866"))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color("#142d46"), 2.0, true)

	var o_radius: float
	if Engine.is_editor_hint():
		o_radius = outer_circle_start_radius
	else:
		o_radius = outer_circle_current_radius
	draw_arc(Vector2.ZERO, o_radius, 0.0, TAU, 64, Color("#4a90e2"), 1.0, true)

# =====================================
# 			QUICK TIME LOGIC
# =====================================

enum QuicktimeState
{
	STATE_EARLY,
	STATE_PEARLY,
	STATE_PERFECT,
	STATE_PLATE,
	STATE_LATE
}

var quicktime_active: bool = false

var quicktime_timer: Timer = null

# We also bookkeep the current state of the quicktime event, so we can handle the input events accordingly
var quicktime_state: QuicktimeState = QuicktimeState.STATE_EARLY

func _start_quicktime() -> void:
	_reset_quicktime()
	quicktime_active = true

	quicktime_timer = Timer.new()
	quicktime_timer.wait_time = timer_duration
	quicktime_timer.one_shot = true
	quicktime_timer.connect("timeout", Callable(self, "_on_quicktime_timeout"))
	add_child(quicktime_timer)
	quicktime_timer.start()

func _stop_quicktime() -> void:
	quicktime_active = false
	if quicktime_timer != null:
		quicktime_timer.stop()
		quicktime_timer.queue_free()
		quicktime_timer = null
	queue_redraw()

func _reset_quicktime() -> void:
	quicktime_active = false
	quicktime_state = QuicktimeState.STATE_EARLY
	outer_circle_current_radius = outer_circle_start_radius
	queue_redraw()

func _process(delta: float) -> void:
	# Update the markers positions in editor
	if Engine.is_editor_hint():
		_update_markers()

	if not quicktime_active:
		return

	# Update the outer circle radius based on the progress of the timer
	var current_time: float = timer_duration - quicktime_timer.time_left
	var procentage_done: float = current_time / timer_duration
	outer_circle_current_radius = outer_circle_start_radius + (procentage_done) * (outer_circle_end_radius - outer_circle_start_radius)

	# Update the state of the quicktime event based on the current time left
	var perfect_margin_of_error: float = 0.05 # Allow a small margin of error for perfect timing
	if current_time < (perfect_time - allowed_dur_before):
		quicktime_state = QuicktimeState.STATE_EARLY
	elif current_time < (perfect_time - perfect_margin_of_error):
		quicktime_state = QuicktimeState.STATE_PEARLY
	elif current_time < (perfect_time + perfect_margin_of_error):
		quicktime_state = QuicktimeState.STATE_PERFECT
	elif current_time < (perfect_time + allowed_dur_after):
		quicktime_state = QuicktimeState.STATE_PLATE
	else:
		quicktime_state = QuicktimeState.STATE_LATE
	queue_redraw()

func _on_quicktime_timeout() -> void:
	# Currently only reset the quicktime event
	quicktime_active = false
	outer_circle_current_radius = outer_circle_start_radius
	queue_redraw()

# Catch mouse input events 
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				# Handle left mouse button press'
				print("Left mouse button pressed at: ", event.position)
				# Check if inside the actionable event area
				if not _is_point_inside(event.position):
					return
				print("Click is inside the actionable event area")

				# Check if quicktime is active
				if not quicktime_active:
					print("Quicktime is not active")
					return
				
				# Output state of the quicktime event
				match quicktime_state:
					QuicktimeState.STATE_EARLY:
						print("Quicktime state: EARLY")
					QuicktimeState.STATE_PEARLY:
						print("Quicktime state: PEARLY")
					QuicktimeState.STATE_PERFECT:
						print("Quicktime state: PERFECT")
					QuicktimeState.STATE_PLATE:
						print("Quicktime state: PLATE")
					QuicktimeState.STATE_LATE:
						print("Quicktime state: LATE")
				
				_stop_quicktime()
	if event is InputEventKey:
		if event.pressed:
			if event.scancode == KEY_SPACE:
				# Handle spacebar press
				print("Spacebar pressed")
				pass


# ======================================
# 				HELPERS
# ======================================

func _apply_radius() -> void:
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return

	var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
	if circle_shape == null:
		circle_shape = CircleShape2D.new()
		collision_shape.shape = circle_shape
	circle_shape.radius = radius

func _is_point_inside(point: Vector2) -> bool:
	var local_point = to_local(point)
	return local_point.length() <= radius

func _update_markers() -> void:
	if not Engine.is_editor_hint():
		return
	c_start_marker.position = Vector2(-outer_circle_start_radius, 0)
	c_pstart_marker.position = Vector2(-outer_circle_start_radius + (perfect_time - allowed_dur_before) / timer_duration * (outer_circle_start_radius - outer_circle_end_radius), 0)
	c_perfect_marker.position = Vector2(-outer_circle_start_radius + (perfect_time / timer_duration) * (outer_circle_start_radius - outer_circle_end_radius), 0)
	c_pend_marker.position = Vector2(-outer_circle_start_radius + (perfect_time + allowed_dur_after) / timer_duration * (outer_circle_start_radius - outer_circle_end_radius), 0)
	c_end_marker.position = Vector2(-outer_circle_end_radius, 0)
