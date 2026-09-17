class_name Player3D
extends CharacterBody3D

@export var speed := 5.0
@export var acceleration := 22.0
@export var jump_velocity := 6.5
@export var mouse_sensitivity := 0.0025

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var model: Node3D = $Character/Model
@onready var animation_player: AnimationPlayer = $Character/Model/AnimationPlayer
@onready var interactor: RayCast3D = $CameraPivot/Camera3D/Interactor
@onready var skeleton: Skeleton3D = $Character/Model/Armature/Skeleton3D

var controls_enabled := true
var _walking := false
var _spawn_transform: Transform3D

func _ready() -> void:
	_spawn_transform = global_transform
	# Preserve original materials; external cameras can render layer 2.
	for item in model.find_children("*", "MeshInstance3D", true, false):
		(item as MeshInstance3D).layers = 2
	var walk := animation_player.get_animation(&"MersCaracter1").duplicate() as Animation
	walk.loop_mode = Animation.LOOP_LINEAR
	var library := AnimationLibrary.new()
	library.add_animation(&"walk", walk)
	animation_player.add_animation_library(&"locomotion", library)
	interactor.add_exception(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-85.0), deg_to_rad(85.0)
		)
	elif event.is_action_pressed("interact") and not event.is_echo():
		# An interaction can immediately remove this player by changing scenes.
		get_viewport().set_input_as_handled()
		interactor.try_interact(self)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	if controls_enabled:
		input_vector = (Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			+ Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")).limit_length(1.0)
	# Local -Z matches the camera's horizontal forward, independent of pitch.
	var direction := global_basis * Vector3(input_vector.x, 0.0, input_vector.y)
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif controls_enabled and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	move_and_slide()
	_update_locomotion(is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.15)
	if global_position.y < -10.0:
		respawn()

func set_controls_enabled(value: bool) -> void:
	controls_enabled = value
	interactor.set_interaction_enabled(value)
	if not value:
		velocity.x = 0.0
		velocity.z = 0.0
		_update_locomotion(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE

func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	camera_pivot.rotation = Vector3.ZERO

func _update_locomotion(walking: bool) -> void:
	if walking == _walking:
		return
	_walking = walking
	if walking:
		animation_player.play(&"locomotion/walk")
	else:
		# No idle/jump clip in this GLB yet. Use its neutral standing pose.
		animation_player.stop()
		skeleton.reset_bone_poses()
