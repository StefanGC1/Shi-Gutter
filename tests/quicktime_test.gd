extends SceneTree

# Run after importing the project:
# godot --headless --path . --script res://tests/quicktime_test.gd

# ==========================================================================
#			Controlled clock and test helpers
# ==========================================================================

class ControlledEvent extends ActionableEvent:

	var now_usec: int = 1000000

	func _get_clock_usec() -> int:
		return now_usec

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _frames(count: int = 2) -> void:
	for frame in count:
		await process_frame

func _new_event(configuration: QuickTimeEvent = null) -> ControlledEvent:
	var actionable_event: ControlledEvent = ControlledEvent.new()
	actionable_event.event = configuration if configuration != null else QuickTimeEvent.new()
	actionable_event.input_managed = true
	root.add_child(actionable_event)
	return actionable_event

func _results(actionable_event: ActionableEvent) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	actionable_event.resolved.connect(func(result: int, state: int, error: float) -> void:
		results.append({"result": result, "state": state, "error": error})
	)
	return results

func _advance(actionable_event: ControlledEvent, duration: float) -> void:
	actionable_event.now_usec += roundi(duration * 1000000.0)

func _click(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = position
	return event

func _key(keycode: Key = KEY_SPACE, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	event.echo = echo
	return event

# ==========================================================================
#			Timing, geometry and result correctness
# ==========================================================================

func _test_configuration() -> void:
	var configuration: QuickTimeEvent = QuickTimeEvent.new()
	configuration.duration = 0.0
	configuration.radius = 0.0
	configuration.approach_scale = 0.0
	configuration.allowed_dur_before = -1.0
	configuration.allowed_dur_after = -1.0
	configuration.perfect_margin_of_error = -1.0
	_check(configuration.duration > 0.0, "Duration must never permit division by zero")
	_check(configuration.radius > 0.0, "Target radius must stay positive")
	_check(configuration.approach_scale > 1.0, "Approach ring must begin outside the target")
	_check(configuration.allowed_dur_before >= 0.0 and configuration.allowed_dur_after >= 0.0, "Allowed windows must reject negative durations")
	_check(configuration.perfect_margin_of_error >= 0.0, "Perfect tolerance must reject negative durations")
	configuration.allowed_dur_before = 2.0
	configuration.allowed_dur_after = 0.01
	configuration.perfect_margin_of_error = 0.05
	configuration.duration = 0.1
	_check(configuration.get_allowed_before() <= configuration.duration, "Early window must fit in the available approach time")
	_check(configuration.get_perfect_before() <= configuration.get_allowed_before(), "Perfect early window must fit in the acceptable window")
	_check(configuration.get_perfect_after() <= configuration.allowed_dur_after, "Perfect late window must fit in the acceptable window")
	_check(is_equal_approx(configuration.get_total_duration(), 0.11), "Total duration must be derived from approach duration plus late allowance")

func _test_geometry() -> void:
	var configuration: QuickTimeEvent = QuickTimeEvent.new()
	for duration in [0.05, 0.2, 1.2, 8.0]:
		configuration.duration = duration
		for radius in [8.0, 64.0, 140.0]:
			configuration.radius = radius
			for approach_scale in [1.2, 2.0, 4.0]:
				configuration.approach_scale = approach_scale
				_check(is_equal_approx(configuration.get_approach_radius(0.0), radius * approach_scale), "Approach scale must size the starting ring relative to the target")
				_check(is_equal_approx(configuration.get_approach_radius(duration), radius), "Changing duration, radius or approach scale must preserve perfect alignment")
				var previous_radius: float = configuration.get_approach_radius(0.0)
				var monotone: bool = true
				for sample in range(1, 101):
					var elapsed: float = configuration.get_total_duration() * float(sample) / 100.0
					var current_radius: float = configuration.get_approach_radius(elapsed)
					monotone = monotone and is_finite(current_radius) and current_radius > 0.0 and current_radius <= previous_radius + 0.00001
					previous_radius = current_radius
				_check(monotone, "Approach ring must shrink continuously without reversing or collapsing")
				var step: float = duration * 0.00001
				var before_speed: float = (radius - configuration.get_approach_radius(duration - step)) / step
				var after_speed: float = (configuration.get_approach_radius(duration + step) - radius) / step
				_check(absf(before_speed - after_speed) <= maxf(0.01, absf(before_speed) * 0.001), "Approach ring must not abruptly change speed at perfect timing")

func _test_timing_windows() -> void:
	var configuration: QuickTimeEvent = QuickTimeEvent.new()
	configuration.duration = 1.0
	configuration.allowed_dur_before = 0.25
	configuration.allowed_dur_after = 0.25
	configuration.perfect_margin_of_error = 0.05
	var actionable_event: ControlledEvent = _new_event(configuration)
	_check(actionable_event.get_state_at_time(0.74) == ActionableEvent.QuicktimeState.STATE_EARLY, "Before the early allowance must be too early")
	_check(actionable_event.get_state_at_time(0.75) == ActionableEvent.QuicktimeState.STATE_PEARLY, "The exact acceptable early boundary must be accepted")
	_check(actionable_event.get_state_at_time(0.95) == ActionableEvent.QuicktimeState.STATE_PERFECT, "The exact early perfect boundary must be perfect")
	_check(actionable_event.get_state_at_time(1.05) == ActionableEvent.QuicktimeState.STATE_PERFECT, "The exact late perfect boundary must be perfect")
	_check(actionable_event.get_state_at_time(1.25) == ActionableEvent.QuicktimeState.STATE_PLATE, "The exact acceptable late boundary must be accepted")
	_check(actionable_event.get_state_at_time(1.26) == ActionableEvent.QuicktimeState.STATE_LATE, "After the late allowance must be too late")
	configuration.allowed_dur_before = 0.01
	configuration.allowed_dur_after = 0.01
	_check(actionable_event.get_state_at_time(0.98) == ActionableEvent.QuicktimeState.STATE_EARLY, "A wide perfect tolerance must not extend the acceptable early window")
	_check(actionable_event.get_state_at_time(1.03) == ActionableEvent.QuicktimeState.STATE_LATE, "A wide perfect tolerance must not extend the acceptable late window")
	configuration.allowed_dur_before = 0.0
	configuration.allowed_dur_after = 0.0
	_check(actionable_event.get_state_at_time(1.0) == ActionableEvent.QuicktimeState.STATE_PERFECT, "Zero-width windows must still define the exact perfect timestamp")
	actionable_event.free()

func _test_attempt_results() -> void:
	for sample in [0.1, 0.8, 1.0, 1.2]:
		var configuration: QuickTimeEvent = QuickTimeEvent.new()
		configuration.duration = 1.0
		configuration.allowed_dur_before = 0.25
		configuration.allowed_dur_after = 0.25
		var actionable_event: ControlledEvent = _new_event(configuration)
		var results: Array[Dictionary] = _results(actionable_event)
		actionable_event.start_quicktime()
		_advance(actionable_event, sample)
		_check(actionable_event.try_input(_click(Vector2.ZERO)), "A matching inside press must be consumed")
		_check(not actionable_event.quicktime_active and results.size() == 1, "Each attempt must produce one terminal result")
		var expected: int = ActionableEvent.QuicktimeResult.RESULT_TOO_EARLY if sample == 0.1 else ActionableEvent.QuicktimeResult.RESULT_SUCCESS
		_check(actionable_event.quicktime_result == expected, "Accepted timing and early failure must have distinct results")
		_check(is_equal_approx(actionable_event.timing_error, sample - 1.0), "Result timing error must come from the input timestamp")
		_check(not actionable_event.try_input(_click(Vector2.ZERO)), "A resolved event must reject further presses")
		actionable_event.cancel_quicktime()
		_check(results.size() == 1, "Cancelling a resolved event must not emit a second result")
		actionable_event.free()
	var actionable_event: ControlledEvent = _new_event()
	var results: Array[Dictionary] = _results(actionable_event)
	actionable_event.start_quicktime()
	_advance(actionable_event, actionable_event.event.get_total_duration() + 0.1)
	actionable_event._process(0.0)
	_check(actionable_event.quicktime_result == ActionableEvent.QuicktimeResult.RESULT_MISSED, "A missed deadline must produce an explicit miss")
	_check(results.size() == 1, "Timeout must emit exactly one result")
	actionable_event._process(0.0)
	_check(results.size() == 1, "Further frames after timeout must not resolve again")
	actionable_event.free()
	actionable_event = _new_event()
	actionable_event.start_quicktime()
	_advance(actionable_event, actionable_event.event.get_total_duration() + 0.1)
	actionable_event.try_input(_click(Vector2.ZERO))
	_check(actionable_event.quicktime_result == ActionableEvent.QuicktimeResult.RESULT_MISSED, "Input beyond the deadline must be a miss regardless of process/input ordering")
	actionable_event.free()

func _test_restart_and_snapshot() -> void:
	var actionable_event: ControlledEvent = _new_event()
	var results: Array[Dictionary] = _results(actionable_event)
	var duration: float = actionable_event.event.duration
	actionable_event.start_quicktime()
	_advance(actionable_event, 0.4)
	actionable_event.start_quicktime()
	_check(results.size() == 1 and results[0].result == ActionableEvent.QuicktimeResult.RESULT_CANCELLED, "Restart must explicitly cancel the previous attempt once")
	_check(is_zero_approx(actionable_event.get_elapsed_time()), "Restart must reset elapsed time")
	actionable_event.event.duration = 5.0
	actionable_event.event.radius = 120.0
	_check(is_equal_approx(actionable_event.get_event_configuration().duration, duration), "Editing a shared resource must not alter an active attempt")
	_advance(actionable_event, duration)
	actionable_event.try_input(_click(Vector2.ZERO))
	_check(actionable_event.quicktime_result == ActionableEvent.QuicktimeResult.RESULT_SUCCESS, "Restarted attempt must survive the original attempt's deadline")
	_check(results.size() == 2, "Restarted attempt must produce its own single result")
	for attempt in range(20):
		actionable_event.start_quicktime()
		_advance(actionable_event, actionable_event.get_event_configuration().get_total_duration() + 0.1)
		actionable_event._process(0.0)
	_check(actionable_event.find_children("*", "Timer", true, false).is_empty(), "Repeated attempts must not accumulate timer nodes")
	actionable_event.free()
	actionable_event = _new_event()
	var restarted: Array[bool] = [false]
	actionable_event.resolved.connect(func(_result: int, _state: int, _error: float) -> void:
		if not restarted[0]:
			restarted[0] = true
			actionable_event.start_quicktime()
	)
	actionable_event.start_quicktime()
	_advance(actionable_event, actionable_event.event.duration)
	actionable_event.try_input(_click(Vector2.ZERO))
	_check(actionable_event.quicktime_active and is_zero_approx(actionable_event.get_elapsed_time()), "A result listener may safely start the next attempt immediately")
	_advance(actionable_event, 0.1)
	actionable_event._process(0.0)
	_check(actionable_event.quicktime_active, "Old result feedback must not finish a replacement attempt")
	actionable_event.free()

# ==========================================================================
#			Input coordinates, keyboard matching and pausing
# ==========================================================================

func _test_tree_removal() -> void:
	var actionable_event: ControlledEvent = _new_event()
	var results: Array[Dictionary] = _results(actionable_event)
	actionable_event.resolved.connect(func(_result: int, _state: int, _error: float) -> void:
		actionable_event.start_quicktime()
	)
	actionable_event.start_quicktime()
	_advance(actionable_event, 0.3)
	root.remove_child(actionable_event)
	_check(results.size() == 1 and results[0].result == ActionableEvent.QuicktimeResult.RESULT_CANCELLED, "Leaving the tree must cancel an active attempt exactly once")
	_check(not actionable_event.quicktime_active, "A cancellation listener must not restart an event while it is leaving the tree")
	_advance(actionable_event, 10.0)
	root.add_child(actionable_event)
	actionable_event.start_quicktime()
	_check(actionable_event.quicktime_active and is_zero_approx(actionable_event.get_elapsed_time()), "A reattached standalone event may start a fresh attempt without counting detached time")
	actionable_event.free()

func _test_input() -> void:
	var actionable_event: ControlledEvent = _new_event()
	actionable_event.position = Vector2(100, 100)
	actionable_event.start_quicktime()
	_check(not actionable_event.try_input(_click(Vector2(600, 600))), "An off-target click must not resolve the event")
	_check(not actionable_event.try_input(_click(actionable_event.position, MOUSE_BUTTON_RIGHT)), "The wrong mouse button must not resolve the event")
	actionable_event.hide()
	_check(not actionable_event.try_input(_click(actionable_event.position)), "A hidden mouse event must not accept input")
	actionable_event.show()
	root.canvas_transform = Transform2D(0.0, Vector2(300, 50))
	_advance(actionable_event, actionable_event.event.duration)
	var viewport_position: Vector2 = actionable_event.get_global_transform_with_canvas() * Vector2.ZERO
	_check(actionable_event.try_input(_click(viewport_position)), "A visible center click must work through a transformed canvas")
	_check(actionable_event.quicktime_result == ActionableEvent.QuicktimeResult.RESULT_SUCCESS, "Canvas transforms must not change input timing")
	root.canvas_transform = Transform2D.IDENTITY
	actionable_event.free()
	var configuration: QuickTimeEvent = QuickTimeEvent.new()
	configuration.event_type = QuickTimeEvent.ActionableEventType.EVENT_KEY
	configuration.key = KEY_SPACE
	actionable_event = _new_event(configuration)
	actionable_event.start_quicktime()
	_check(not actionable_event.try_input(_key(KEY_A)), "Wrong keys must not resolve keyboard events")
	_check(not actionable_event.try_input(_key(KEY_SPACE, true)), "Held-key repeat must not count as a new attempt")
	var release: InputEventKey = _key()
	release.pressed = false
	_check(not actionable_event.try_input(release), "Key release must not count as an attempt")
	actionable_event.hide()
	_check(not actionable_event.try_input(_key()), "A hidden keyboard event must not accept input")
	actionable_event.show()
	_advance(actionable_event, configuration.duration)
	_check(actionable_event.try_input(_key()), "Configured key must be accepted without mouse aiming")
	_check(actionable_event.quicktime_state == ActionableEvent.QuicktimeState.STATE_PERFECT, "Keyboard must use the same input-time grading as mouse")
	actionable_event.free()
	configuration.ignore_early_input = true
	actionable_event = _new_event(configuration)
	actionable_event.start_quicktime()
	actionable_event.try_input(_key())
	_check(actionable_event.quicktime_active, "Ignoring early input must leave the attempt active")
	_advance(actionable_event, configuration.duration)
	actionable_event.try_input(_key())
	_check(actionable_event.quicktime_result == ActionableEvent.QuicktimeResult.RESULT_SUCCESS, "An ignored early key must not prevent a later valid attempt")
	actionable_event.free()
	var action: StringName = &"quicktime_test_key"
	InputMap.add_action(action)
	InputMap.action_add_event(action, _key(KEY_E))
	configuration = QuickTimeEvent.new()
	configuration.event_type = QuickTimeEvent.ActionableEventType.EVENT_KEY
	configuration.input_action = action
	configuration.key = KEY_SPACE
	actionable_event = _new_event(configuration)
	actionable_event.start_quicktime()
	_check(not actionable_event.try_input(_key(KEY_SPACE)), "An Input Map action must replace the direct-key fallback")
	_advance(actionable_event, configuration.duration)
	_check(actionable_event.try_input(_key(KEY_E)), "Keyboard events must support Input Map bindings")
	_check(actionable_event.quicktime_result == ActionableEvent.QuicktimeResult.RESULT_SUCCESS, "Input Map actions must share normal timing judgement")
	InputMap.erase_action(action)
	actionable_event.free()

func _test_pause() -> void:
	var actionable_event: ControlledEvent = _new_event()
	actionable_event.start_quicktime()
	_advance(actionable_event, 0.2)
	var elapsed_before_pause: float = actionable_event.get_elapsed_time()
	paused = true
	_advance(actionable_event, 10.0)
	_check(not actionable_event.try_input(_click(Vector2.ZERO)), "Paused events must reject input")
	paused = false
	_check(is_equal_approx(actionable_event.get_elapsed_time(), elapsed_before_pause), "Pause time must not count toward the deadline")
	_advance(actionable_event, actionable_event.event.duration - elapsed_before_pause)
	actionable_event.try_input(_click(Vector2.ZERO))
	_check(actionable_event.quicktime_result == ActionableEvent.QuicktimeResult.RESULT_SUCCESS, "Resuming must preserve the remaining timing window")
	actionable_event.free()
	paused = true
	actionable_event = _new_event()
	actionable_event.start_quicktime()
	_advance(actionable_event, 10.0)
	paused = false
	_check(is_zero_approx(actionable_event.get_elapsed_time()), "An event started while paused must begin timing only on resume")
	Engine.time_scale = 0.5
	_advance(actionable_event, 0.4)
	_check(is_equal_approx(actionable_event.get_elapsed_time(), 0.2), "Quicktime timing must follow the chosen game time scale")
	Engine.time_scale = 1.0
	actionable_event.free()
	actionable_event = _new_event()
	actionable_event.start_quicktime()
	_advance(actionable_event, 0.2)
	actionable_event.process_mode = Node.PROCESS_MODE_DISABLED
	_advance(actionable_event, 10.0)
	_check(not actionable_event.try_input(_click(Vector2.ZERO)), "A disabled event must reject input")
	actionable_event.process_mode = Node.PROCESS_MODE_INHERIT
	_check(is_equal_approx(actionable_event.get_elapsed_time(), 0.2), "Disabling processing must freeze the clock without discarding time before disable")
	actionable_event.free()

func _test_feedback() -> void:
	var actionable_event: ControlledEvent = _new_event()
	var feedback: Array[bool] = []
	actionable_event.feedback_finished.connect(func() -> void:
		feedback.append(true)
	)
	actionable_event.start_quicktime()
	_advance(actionable_event, actionable_event.event.duration)
	actionable_event.try_input(_click(Vector2.ZERO))
	_advance(actionable_event, actionable_event.event.feedback_duration * 0.5)
	actionable_event._process(0.0)
	_check(feedback.is_empty(), "Result feedback must remain visible for its configured duration")
	_advance(actionable_event, actionable_event.event.feedback_duration)
	actionable_event._process(0.0)
	actionable_event._process(0.0)
	_check(feedback.size() == 1, "Each completed feedback animation must emit exactly once")
	actionable_event.free()
	var system: QuickTimeSystem = _new_system()
	var configuration: QuickTimeEvent = QuickTimeEvent.new()
	configuration.feedback_duration = 0.0
	system.dispatch_event(configuration, Vector2(100, 100))
	system._unhandled_input(_click(Vector2(100, 100)))
	await _frames(3)
	_check(system.get_node("Events").get_child_count() == 0, "The dispatcher must free prompt nodes when result feedback finishes")
	system.free()

# ==========================================================================
#			Dispatching, sequences and projection into 3D scenes
# ==========================================================================

func _new_system() -> QuickTimeSystem:
	var system: QuickTimeSystem = QuickTimeSystem.new()
	system.manage_mouse_mode = false
	root.add_child(system)
	return system

func _test_dispatcher_input() -> void:
	var system: QuickTimeSystem = _new_system()
	var configuration: QuickTimeEvent = QuickTimeEvent.new()
	var center: Vector2 = root.get_visible_rect().get_center()
	var first: ActionableEvent = system.dispatch_event(configuration, center)
	var second: ActionableEvent = system.dispatch_event(configuration, center)
	await _frames()
	root.push_input(_click(center), true)
	_check(not first.quicktime_active and second.quicktime_active, "One overlapping click must resolve only the first dispatched matching event")
	var covering_ui: Control = Control.new()
	covering_ui.position = center - Vector2(100, 100)
	covering_ui.size = Vector2(200, 200)
	covering_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(covering_ui)
	await _frames()
	root.push_input(_click(center), true)
	_check(second.quicktime_active, "GUI controls must intercept clicks before the quicktime dispatcher")
	covering_ui.free()
	system.free()
	system = _new_system()
	var replacement: Array[ActionableEvent] = []
	system.event_resolved.connect(func(_event: ActionableEvent, _result: int, _state: int, _error: float) -> void:
		if replacement.is_empty():
			replacement.append(system.dispatch_event(configuration, center))
	)
	first = system.dispatch_event(configuration, center)
	system._unhandled_input(_click(center))
	_check(replacement.size() == 1 and replacement[0].quicktime_active, "A result listener may dispatch a replacement without reusing the resolving press")
	system.free()
	system = _new_system()
	var entry: QuickTimeDispatch = QuickTimeDispatch.new()
	entry.event = configuration
	system.dispatches = [entry]
	var restarted: Array[bool] = [false]
	system.event_resolved.connect(func(actionable_event: ActionableEvent, result: int, _state: int, _error: float) -> void:
		if result == ActionableEvent.QuicktimeResult.RESULT_CANCELLED and not restarted[0]:
			restarted[0] = true
			actionable_event.start_quicktime()
	)
	system.start_sequence()
	first = system.get_node("Events").get_child(0) as ActionableEvent
	system.cancel_all_events()
	_check(first.quicktime_active, "Cancel-all must not cancel a new attempt restarted by the cancelled attempt's listener")
	system._unhandled_input(_click(first.get_global_transform_with_canvas() * Vector2.ZERO))
	_check(not first.quicktime_active, "A restarted managed node must remain in input routing")
	system.free()
	system = _new_system()
	system.dispatches = [entry, entry]
	var starts: Array[ActionableEvent] = []
	system.event_started.connect(func(actionable_event: ActionableEvent) -> void:
		starts.append(actionable_event)
		system.queue_free()
	)
	system.start_sequence()
	_check(starts.size() == 1, "Queuing the system for deletion during dispatch must prevent subsequent entries")
	await _frames(2)

func _test_sequences() -> void:
	var system: QuickTimeSystem = _new_system()
	var configuration: QuickTimeEvent = QuickTimeEvent.new()
	configuration.duration = 10.0
	var manual: ActionableEvent = system.dispatch_event(configuration, Vector2(40, 40))
	var first_entry: QuickTimeDispatch = QuickTimeDispatch.new()
	first_entry.event = configuration
	first_entry.delay = 0.0
	first_entry.screen_position = Vector2(0.25, 0.5)
	var second_entry: QuickTimeDispatch = QuickTimeDispatch.new()
	second_entry.event = configuration
	second_entry.delay = 0.5
	second_entry.screen_position = Vector2(0.75, 0.5)
	system.dispatches = [first_entry, second_entry]
	var dispatched: Array[ActionableEvent] = []
	system.event_started.connect(func(actionable_event: ActionableEvent) -> void:
		dispatched.append(actionable_event)
	)
	system.start_sequence()
	_check(dispatched.size() == 1, "Zero-delay first entry must dispatch immediately")
	second_entry.delay = 50.0
	configuration.duration = 0.05
	system._advance_sequence(0.49)
	_check(dispatched.size() == 1, "Relative dispatch delay must not fire early")
	system._advance_sequence(0.02)
	_check(dispatched.size() == 2, "Sequence must snapshot its schedule and dispatch the next entry when due")
	if dispatched.size() == 2:
		_check(is_equal_approx(dispatched[1].get_event_configuration().duration, 10.0), "Sequence must snapshot event configuration as well as delays")
		var viewport_center: Vector2 = dispatched[1].get_global_transform_with_canvas() * Vector2.ZERO
		_check(viewport_center.is_equal_approx(root.get_visible_rect().size * Vector2(0.75, 0.5)), "Configured sequence position must use normalized viewport coordinates")
	system.stop_sequence()
	_check(not system.sequence_running and manual.quicktime_active, "Stopping a sequence must preserve manually dispatched events")
	for actionable_event in dispatched:
		_check(not actionable_event.quicktime_active and actionable_event.quicktime_result == ActionableEvent.QuicktimeResult.RESULT_CANCELLED, "Stopping must cancel every unresolved sequence prompt")
	system.cancel_all_events()
	_check(not manual.quicktime_active, "Cancel-all must also cancel manually dispatched events")
	system.free()
	system = _new_system()
	system.dispatches = [first_entry]
	system.sequence_started.connect(system.stop_sequence)
	system.start_sequence()
	_check(not system.sequence_running and system.get_node("Events").get_child_count() == 0, "A sequence-start listener may stop the sequence before its first dispatch")
	system.free()
	system = _new_system()
	configuration.duration = 10.0
	first_entry.event = configuration
	system.dispatches = [first_entry]
	var completed: Array[bool] = []
	system.sequence_finished.connect(func() -> void:
		completed.append(true)
	)
	system.start_sequence()
	var prompt: ActionableEvent = system.get_node("Events").get_child(0) as ActionableEvent
	prompt.cancel_quicktime()
	_check(not system.sequence_running and completed.size() == 1, "Sequence must finish once all scheduled prompts are resolved")
	system.free()
	system = _new_system()
	system.dispatches = [first_entry]
	system.loop = true
	system.loop_delay = 0.2
	var loop_events: Array[ActionableEvent] = []
	system.event_started.connect(func(actionable_event: ActionableEvent) -> void:
		loop_events.append(actionable_event)
	)
	system.start_sequence()
	system._advance_sequence(2.0)
	_check(loop_events.size() == 1, "Looping must wait for the previous cycle's outstanding attempts")
	loop_events[0].cancel_quicktime()
	system._advance_sequence(0.19)
	_check(loop_events.size() == 1 and system.sequence_running, "Loop delay must begin after the cycle resolves")
	system._advance_sequence(0.02)
	_check(loop_events.size() == 2 and loop_events[1].quicktime_active, "Looping must dispatch a fresh cycle after the gap")
	system.stop_sequence()
	system._advance_sequence(100.0)
	_check(loop_events.size() == 2 and not system.sequence_running, "Stopping must prevent future loop cycles")
	system.free()
	system = _new_system()
	system.dispatches = [first_entry]
	var restarted: Array[bool] = [false]
	var restart_events: Array[ActionableEvent] = []
	system.event_started.connect(func(actionable_event: ActionableEvent) -> void:
		restart_events.append(actionable_event)
	)
	system.event_resolved.connect(func(_event: ActionableEvent, result: int, _state: int, _error: float) -> void:
		if result == ActionableEvent.QuicktimeResult.RESULT_CANCELLED and not restarted[0]:
			restarted[0] = true
			system.start_sequence()
	)
	system.start_sequence()
	system.start_sequence()
	_check(system.sequence_running and restart_events.size() == 2 and restart_events[1].quicktime_active, "An inner restart from a cancellation listener must survive the outer restart")
	system.free()

func _test_projection() -> void:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 0, 5)
	camera.make_current()
	var anchor: Node3D = Node3D.new()
	world.add_child(anchor)
	var system: QuickTimeSystem = _new_system()
	var configuration: QuickTimeEvent = QuickTimeEvent.new()
	configuration.duration = 10.0
	var prompt: ActionableEvent = system.dispatch_event_3d(configuration, anchor, camera)
	_check(prompt != null and prompt.visible, "A visible 3D anchor must create a visible overlay prompt")
	if prompt != null:
		var expected: Vector2 = camera.unproject_position(anchor.global_position)
		_check((prompt.get_global_transform_with_canvas() * Vector2.ZERO).is_equal_approx(expected), "3D prompt must align with the camera's projected anchor")
		anchor.position = Vector3(1, 0, 0)
		system._process(0.0)
		expected = camera.unproject_position(anchor.global_position)
		_check((prompt.get_global_transform_with_canvas() * Vector2.ZERO).is_equal_approx(expected), "Overlay prompt must follow a moving 3D anchor")
		anchor.position = Vector3(0, 0, 10)
		system._process(0.0)
		_check(not prompt.visible and not prompt.try_input(_click(expected)), "A target behind the camera must be hidden and reject input")
		anchor.position = Vector3(1000, 0, 0)
		system._process(0.0)
		_check(not prompt.visible, "An offscreen target must not leave a prompt at an invalid screen position")
		anchor.position = Vector3.ZERO
		system._process(0.0)
		_check(prompt.visible and prompt.quicktime_active, "A target returning onscreen may resume presentation while its attempt remains active")
		anchor.hide()
		system._process(0.0)
		_check(not prompt.visible, "A hidden 3D anchor must hide its prompt")
		anchor.show()
		anchor.position = camera.position + Vector3(0, 0, -camera.near * 0.5)
		system._process(0.0)
		_check(not prompt.visible, "A target inside the camera's near clipping plane must hide its prompt")
		anchor.position = camera.position + Vector3(0, 0, -camera.far * 2.0)
		system._process(0.0)
		_check(not prompt.visible, "A target beyond the far clipping plane must hide its prompt")
		anchor.free()
		system._process(0.0)
		_check(not prompt.quicktime_active and prompt.quicktime_result == ActionableEvent.QuicktimeResult.RESULT_CANCELLED, "Removing a 3D anchor must cancel its prompt safely")
	var other_viewport: SubViewport = SubViewport.new()
	root.add_child(other_viewport)
	var other_anchor: Node3D = Node3D.new()
	other_viewport.add_child(other_anchor)
	_check(system.dispatch_event_3d(configuration, other_anchor, camera) == null, "A 3D anchor in a different viewport must be rejected")
	other_viewport.free()
	var queued_anchor: Node3D = Node3D.new()
	world.add_child(queued_anchor)
	queued_anchor.queue_free()
	_check(system.dispatch_event_3d(configuration, queued_anchor, camera) == null, "A 3D anchor queued for deletion must not create an attempt")
	system.free()
	world.free()

# ==========================================================================
#			The actual playground scene, including its camera and interface
# ==========================================================================

func _test_playground() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var playground_scene: PackedScene = load("res://maps/test_quicktime_2d/test_quicktime_2d.tscn") as PackedScene
	var playground: Node2D = playground_scene.instantiate() as Node2D
	viewport.add_child(playground)
	# Advance motion explicitly below so the assertions do not depend on frame rate.
	playground.set_process(false)
	var system: QuickTimeSystem = playground.get_node("QuickTimeSystem") as QuickTimeSystem
	system.manage_mouse_mode = false
	await _frames(3)
	var mouse_button: Button = playground.get_node("Interface/Panel/Margin/Content/Buttons/MouseButton") as Button
	var keyboard_button: Button = playground.get_node("Interface/Panel/Margin/Content/Buttons/KeyboardButton") as Button
	var world_button: Button = playground.get_node("Interface/Panel/Margin/Content/Buttons/WorldButton") as Button
	mouse_button.pressed.emit()
	var active_events: Array = playground.get("active_events")
	_check(active_events.size() == 1 and active_events[0].quicktime_active, "The playground mouse button must dispatch one active prompt")
	if not active_events.is_empty():
		_check(active_events[0].get_event_configuration().event_type == QuickTimeEvent.ActionableEventType.EVENT_CLICK, "The playground mouse example must use mouse input")
	keyboard_button.pressed.emit()
	active_events = playground.get("active_events")
	_check(active_events.size() == 1 and active_events[0].quicktime_active, "Switching playground demos must replace the old prompt")
	if not active_events.is_empty():
		_check(active_events[0].get_event_configuration().event_type == QuickTimeEvent.ActionableEventType.EVENT_KEY, "The playground keyboard example must use keyboard input")
		var keyboard_prompt: ActionableEvent = active_events[0] as ActionableEvent
		playground.call("_unhandled_input", _key(KEY_ESCAPE))
		_check(not keyboard_prompt.quicktime_active and keyboard_prompt.quicktime_result == ActionableEvent.QuicktimeResult.RESULT_CANCELLED, "Escape in the playground must cancel the active prompt")
	active_events = playground.get("active_events")
	_check(active_events.is_empty() and not system.sequence_running, "Escape must leave the playground idle")
	world_button.pressed.emit()
	active_events = playground.get("active_events")
	_check(active_events.size() == 1 and active_events[0].quicktime_active, "The playground 3D button must dispatch an anchored prompt")
	var camera: Camera3D = playground.get_node("World/Camera3D") as Camera3D
	var target: Node3D = playground.get_node("World/Target") as Node3D
	var configuration: QuickTimeEvent = playground.get("mouse_event") as QuickTimeEvent
	var approach_radius: float = configuration.get_approach_radius(0.0)
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	var all_visible: bool = true
	# Both movement frequencies repeat after 40 * PI seconds. Sample the real
	# playground callback throughout that cycle, using its serialized camera.
	for sample in range(241):
		playground.set("world_time", float(sample) * 40.0 * PI / 240.0)
		playground.call("_process", 0.0)
		target.force_update_transform()
		var center: Vector2 = camera.unproject_position(target.global_position)
		minimum = minimum.min(center - Vector2.ONE * approach_radius)
		maximum = maximum.max(center + Vector2.ONE * approach_radius)
		all_visible = all_visible and camera.is_position_in_frustum(target.global_position)
	var header: Control = playground.get_node("Interface/Panel") as Control
	var footer: Control = playground.get_node("Interface/Status") as Control
	_check(all_visible, "The playground target must remain inside its camera frustum throughout its motion")
	_check(minimum.y >= header.get_global_rect().end.y, "The entire 3D approach ring must clear the playground header throughout its motion")
	_check(maximum.y <= footer.get_global_rect().position.y, "The entire 3D approach ring must clear the playground footer throughout its motion")
	_check(minimum.x >= 0.0 and maximum.x <= viewport.size.x, "The entire 3D approach ring must remain within the playground's horizontal bounds")
	playground.call("_unhandled_input", _key(KEY_ESCAPE))
	viewport.queue_free()
	await _frames(2)

func _run() -> void:
	_test_configuration()
	_test_geometry()
	_test_timing_windows()
	_test_attempt_results()
	_test_restart_and_snapshot()
	_test_tree_removal()
	_test_input()
	_test_pause()
	await _test_feedback()
	await _test_dispatcher_input()
	_test_sequences()
	_test_projection()
	await _test_playground()
	if failures.is_empty():
		print("QUICKTIME_OK: ", checks, " checks")
	else:
		print("QUICKTIME_FAILED: ", failures.size(), " failures across ", checks, " checks")
	quit(0 if failures.is_empty() else 1)
