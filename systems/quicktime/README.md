# Quick time events

Instance `quicktime_system.tscn` under a 2D or 3D scene. It draws prompts on a `CanvasLayer`, dispatches configured sequences, and routes each press to one matching active prompt.

The playground remains at `res://maps/test_quicktime_2d/test_quicktime_2d.tscn`. Run that scene to try mouse, keyboard, sequence and moving 3D-target examples. Keys **1–4** select an example, **right-click** retries it, and **Escape** stops it.

## Event configuration

Create a `QuickTimeEvent` resource in the Inspector and assign it to a dispatch entry or use it from code. Resources can be saved as `.tres` presets.

| Property | Meaning |
| --- | --- |
| `event_type` | `EVENT_CLICK` requires a click inside the target; `EVENT_KEY` requires a keyboard press without pointer aiming. |
| `mouse_button` | Required button for mouse events. |
| `key` | Required logical key for keyboard events. Defaults to Space. |
| `input_action` | Optional Input Map action replacing `key`. Use an Input Map physical-key binding when physical keyboard position matters. |
| `duration` | Seconds from appearance until the perfect hit. Minimum 0.05 seconds. |
| `allowed_dur_before` / `allowed_dur_after` | Acceptable early and late error, in seconds. |
| `perfect_margin_of_error` | Perfect tolerance on each side, clipped to the acceptable window. |
| `ignore_early_input` | Keep waiting when the matching input arrives too early. Otherwise that input fails the attempt. |
| `radius` | Target radius in viewport pixels. |
| `approach_scale` | Starting approach-ring radius relative to the target radius. |
| `feedback_duration` | Duration of the hit/miss feedback before the dispatcher frees the prompt. |
| Color properties | Target fill, approach ring, successful hit and failure colors. |

`duration` replaces the prototype's independently configured timer duration and perfect timestamp. The event remains playable until `duration + allowed_dur_after`. There is no independently configured ending radius.

The approach ring moves at constant radial speed until perfect timing, when its radius exactly equals the target radius. It continues smoothly inside the target during the late allowance. Changing duration, radius or approach scale preserves that alignment. The editor markers use the same radius calculation; `preview_progress = 1` previews the perfect alignment on an `ActionableEvent` node.

Early and late allowances stay measured in seconds when you change approach duration. The early allowance is clipped to the available approach time. The perfect allowance is clipped separately on each side, so a very small late allowance cannot accidentally permit a wider perfect interval.

## Dispatch from code

```gdscript
@export var click_event: QuickTimeEvent
@export var keyboard_event: QuickTimeEvent

@onready var quicktime_system: QuickTimeSystem = $QuickTimeSystem

func _ready() -> void:
	quicktime_system.event_resolved.connect(_on_event_resolved)

func start_screen_event() -> void:
	var center: Vector2 = get_viewport().get_visible_rect().get_center()
	quicktime_system.dispatch_event(click_event, center)

func start_world_event(target: Node3D) -> void:
	quicktime_system.dispatch_event_3d(keyboard_event, target)

func _on_event_resolved(event_node: ActionableEvent, result: int, state: int, timing_error: float) -> void:
	if result == ActionableEvent.QuicktimeResult.RESULT_SUCCESS:
		print("Hit: ", event_node.get_result_text(), ", error: ", timing_error)
```

`dispatch_event(configuration, screen_position)` uses viewport pixel coordinates. `dispatch_event_3d(configuration, target, camera, offset)` projects a `Node3D` anchor into the overlay; `camera` defaults to the viewport's current camera, and `offset` is a world-space offset.

Each call returns the `ActionableEvent`, or `null` for invalid dispatch arguments. Use `cancel_quicktime()` on that node to cancel the attempt. Managed nodes are automatically freed after feedback; dispatch a new event for the next attempt instead of retaining the node.

## Configure a sequence

Add `QuickTimeDispatch` resources to the system's `dispatches` array:

| Entry property | Meaning |
| --- | --- |
| `event` | `QuickTimeEvent` preset for this prompt. |
| `delay` | Seconds after the previous dispatch; for the first entry, seconds after sequence start. |
| `screen_position` | Normalized viewport position, such as `(0.5, 0.5)` for the center. |
| `target_path` | Optional `Node3D` anchor path relative to the `QuickTimeSystem` node. Overrides screen positioning. |
| `camera_path` | Optional camera path relative to the system. An empty path follows the viewport's current camera. |
| `world_offset` | World-space offset from the anchor. |

Call `start_sequence()`, or enable `auto_start`. Entries dispatch on their schedule and can overlap. Enable `loop` to repeat after every prompt in the current cycle resolves; `loop_delay` starts at that point.

Starting a sequence replaces the previous sequence. `stop_sequence()` cancels its pending and active entries while preserving manually dispatched events. `cancel_all_events()` stops the sequence and cancels manual events too.

The sequence emits `sequence_started`, `sequence_finished` when a non-looping sequence fully resolves, and `sequence_stopped` when explicitly stopped. Event resources and sequence entries are copied when an attempt or sequence starts, so edits to a shared preset apply to subsequent runs.

## Results and input rules

The system emits `event_started(event_node)` and `event_resolved(event_node, result, state, timing_error)`. An individual node exposes `started`, `state_changed`, `resolved` and `feedback_finished`.

Each attempt resolves once:

| Result | Meaning |
| --- | --- |
| `RESULT_SUCCESS` | Input landed in the acceptable interval; `state` distinguishes accepted early, perfect and accepted late. |
| `RESULT_TOO_EARLY` | Matching input arrived before the acceptable interval. |
| `RESULT_MISSED` | The deadline passed, including input arriving after it. |
| `RESULT_CANCELLED` | Explicit cancellation, replacement or loss of its 3D anchor/camera. |

`timing_error` is the input/resolution timestamp minus the perfect timestamp, in seconds. Negative values are early. Exact acceptable and perfect boundaries are inclusive. Results are captured before signals are emitted, so a result listener may safely dispatch the next event.

Wrong keys, wrong buttons, releases, held-key repeats and off-target clicks are ignored. Hidden prompts reject input. Overlapping targets or matching keyboard prompts are resolved in dispatch order; one press reaches at most one matching event within the system. An ignored early matching press is still consumed by its owning prompt.

The dispatcher uses `_unhandled_input`, allowing GUI controls to intercept input first. If your player polls `Input` directly or handles `_input`, use the system's signals to suspend conflicting movement/combat actions during the challenge; consuming an unhandled event does not undo input already processed elsewhere.

## Timing and 3D integration

One monotonic clock drives both animation and input-time grading. Timing follows `Engine.time_scale` and the node's inherited process mode. With the default process mode, pausing the tree or setting `process_mode` to `PROCESS_MODE_DISABLED` freezes attempts and feedback. Starting while paused waits until processing resumes. Hiding a prompt only hides it and prevents input; its deadline continues.

The system, anchor and camera must belong to the same viewport. Prompts follow moving anchors and remain the configured pixel size regardless of distance. Hidden targets, targets outside the camera frustum, and targets outside the viewport hide their prompts until visible again. This includes the camera's near and far clipping planes. Removing an anchor or an explicitly assigned camera cancels its prompt. When using the current camera implicitly, a temporarily missing camera hides the prompt while its timer continues. Result feedback stays at the hit position. Projection does not perform wall-occlusion raycasts.

For first-person games, `manage_mouse_mode` temporarily makes the cursor visible while visible mouse prompts are active. Ownership is shared across systems, and the previous mode is restored after the last owner releases it, unless other game code has changed the mouse mode. Disable this property if your game already owns cursor transitions.

A standalone `ActionableEvent` scene also works: assign its `event` resource, call `start_quicktime()`, and leave `input_managed` disabled. The dispatcher enables `input_managed` for the nodes it owns.

## Verification

After Godot has imported the project, run:

```text
godot --headless --path . --script res://tests/quicktime_test.gd
```

The regression script checks geometry across parameter combinations, timing boundaries, result ownership, restart and resource snapshots, keyboard and transformed mouse input, pause and disabled processing, feedback cleanup, overlapping input, GUI interception, sequences and 3D projection.
