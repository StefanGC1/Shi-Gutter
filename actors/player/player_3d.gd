extends CharacterBody3D


@export var speed := 6.0
@export var acceleration := 22.0
@export var jump_velocity := 6.5
@export var mouse_sensitivity := 0.0025
@export var character_skin: Texture2D

@onready var character_root: Node3D = $Character
@onready var model_root: Node3D = $Character/Model
@onready var idle_animation_source: Node3D = $Character/AnimationSources/Idle
@onready var run_animation_source: Node3D = $Character/AnimationSources/Run
@onready var jump_animation_source: Node3D = $Character/AnimationSources/Jump
@onready var camera: Camera3D = $Camera3D

var _current_state: StringName = &""
var _active_animation_player: AnimationPlayer
var _idle_animation_player: AnimationPlayer
var _run_animation_player: AnimationPlayer
var _jump_animation_player: AnimationPlayer
var _skin_material: StandardMaterial3D


func _ready() -> void:
	_skin_material = StandardMaterial3D.new()
	_skin_material.albedo_texture = character_skin
	_skin_material.roughness = 0.9
	_apply_material(model_root)

	_idle_animation_player = _prepare_animation_player(idle_animation_source)
	_run_animation_player = _prepare_animation_player(run_animation_source)
	_jump_animation_player = _prepare_animation_player(jump_animation_source)
	_set_character_state(&"idle", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_motion := event as InputEventMouseMotion
		rotate_y(-mouse_motion.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(
			camera.rotation.x - mouse_motion.relative.y * mouse_sensitivity,
			deg_to_rad(-85.0),
			deg_to_rad(85.0)
		)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var input_vector := _get_movement_input()
	var camera_forward := -camera.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var camera_right := camera.global_transform.basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var direction := (
		camera_right * input_vector.x
		+ camera_forward * -input_vector.y
	).normalized()

	var target_velocity := direction * speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_velocity

	move_and_slide()

	if not is_on_floor():
		_set_character_state(&"jump")
	elif direction.length_squared() > 0.001:
		_set_character_state(&"run")
	else:
		_set_character_state(&"idle")


func _get_movement_input() -> Vector2:
	var result := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Add WASD without requiring extra project input-map setup.
	if Input.is_physical_key_pressed(KEY_A):
		result.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		result.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		result.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		result.y += 1.0

	return result.limit_length(1.0)


func _prepare_animation_player(source: Node) -> AnimationPlayer:
	var animation_player := _find_animation_player(source)
	if animation_player != null:
		# Animation tracks use Root/Skeleton3D paths. Redirect them to the
		# skeleton in the visible model instead of the animation-only FBX.
		animation_player.root_node = animation_player.get_path_to(model_root)
	return animation_player


func _set_character_state(next_state: StringName, force := false) -> void:
	if next_state == _current_state and not force:
		return

	_current_state = next_state
	if _active_animation_player != null:
		_active_animation_player.stop()

	match next_state:
		&"run":
			_play_animation(_run_animation_player, "Run", true)
		&"jump":
			_play_animation(_jump_animation_player, "Jump", false)
		_:
			_play_animation(_idle_animation_player, "Idle", true)


func _play_animation(animation_player: AnimationPlayer, suffix: String, should_loop: bool) -> void:
	if animation_player == null:
		return

	for animation_name in animation_player.get_animation_list():
		if not String(animation_name).ends_with("|" + suffix):
			continue

		var animation := animation_player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE
		animation_player.play(animation_name)
		_active_animation_player = animation_player
		return


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result

	return null


func _apply_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = _skin_material
		# Keep the full character for shadows and future remote players, but hide
		# it from the local first-person camera to prevent clipping into the head.
		mesh_instance.set_layer_mask_value(1, false)
		mesh_instance.set_layer_mask_value(2, true)

	for child in node.get_children():
		_apply_material(child)
