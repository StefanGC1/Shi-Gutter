class_name QuickTimeDispatch
extends Resource

# ==========================================================================
#			Configuration for one entry in a quick time sequence
# ==========================================================================

@export var event: QuickTimeEvent

## Seconds after the previous dispatch, or after sequence start for the first entry.
@export_range(0.0, 60.0, 0.01, "or_greater") var delay: float = 0.0:
	set(value):
		delay = maxf(value, 0.0) if is_finite(value) else 0.0

## Normalized viewport position. Used when target_path is empty.
@export var screen_position: Vector2 = Vector2(0.5, 0.5):
	set(value):
		screen_position = value.clamp(Vector2.ZERO, Vector2.ONE) if value.is_finite() else Vector2(0.5, 0.5)

## Optional Node3D anchor, resolved relative to the QuickTimeSystem node.
@export var target_path: NodePath
## An empty path uses the viewport's current Camera3D each frame.
@export var camera_path: NodePath
## World-space offset from the anchor's global position.
@export var world_offset: Vector3 = Vector3.ZERO:
	set(value):
		world_offset = value if value.is_finite() else Vector3.ZERO
