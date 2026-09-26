class_name Player3D
extends CharacterBody3D

signal pee_hit(collider: Node, point: Vector3, normal: Vector3, source: Node)
## Emis la fiecare fizica cu fractiunea (0..1) ramasa din rezerva de pipi,
## ca UI-ul sa poata desena bara.
signal fuel_changed(fraction: float)

const CharacterAnimations = preload("res://systems/character_animations.gd")
const PeeStream = preload("res://systems/pee_stream.gd")
# PeeFuel are class_name global (in pee_fuel.gd), deci nu se mai preincarca aici
# (evita eroarea "shadowed global identifier").

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
var seated_toilet: Node3D
var pee_stream: Node3D
var _standing_transform: Transform3D
var _standing_camera_position: Vector3
var _shoot_requested := false
var _aiming := false
var _seated := false
## Cand e setat (de un NPC de duel), jucatorul trage automat spre acest nod,
## indiferent daca sta jos sau nu, pana la end_auto_duel().
var _auto_duel_target: Node3D = null
var _fuel := PeeFuel.new()

func is_seated() -> bool:
	return _seated

func _ready() -> void:
	_spawn_transform = global_transform
	_standing_camera_position = camera_pivot.position
	# Preserve original materials; external cameras can render layer 2.
	for item in model.find_children("*", "MeshInstance3D", true, false):
		(item as MeshInstance3D).layers = 2
	CharacterAnimations.bind_libraries(animation_player, skeleton)
	var library := AnimationLibrary.new()
	library.add_animation(&"walk", CharacterAnimations.local_clip(animation_player.get_animation(&"MersCaracter1"), animation_player, skeleton, true))
	library.add_animation(&"sit", CharacterAnimations.local_clip(animation_player.get_animation(&"StatToaleta"), animation_player, skeleton, false))
	animation_player.add_animation_library(&"locomotion", library)
	pee_stream = PeeStream.new()
	pee_stream.name = "PeeStream"
	pee_stream.position = Vector3(0, 0.5, -0.32)
	pee_stream.source = self
	pee_stream.aim_camera = camera
	add_child(pee_stream)
	pee_stream.hit.connect(func(collider, point, normal, source): pee_hit.emit(collider, point, normal, source))
	interactor.add_exception(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if is_seated():
			camera_pivot.rotation.y = clampf(camera_pivot.rotation.y - event.relative.x * mouse_sensitivity, deg_to_rad(-75), deg_to_rad(75))
		else:
			rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-85.0), deg_to_rad(85.0)
		)
	elif event.is_action_pressed("interact") and not event.is_echo():
		# An interaction can immediately remove this player by changing scenes.
		get_viewport().set_input_as_handled()
		if is_seated():
			stand_up()
		else:
			interactor.try_interact(self)
	elif event.is_action("shoot"):
		_shoot_requested = event.is_pressed() and is_seated()
		get_viewport().set_input_as_handled()
	elif event.is_action("aim"):
		_aiming = event.is_pressed() and is_seated()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Jucatorul NU are homing: pee_stream.aim_target ramane mereu null pentru el,
	# deci fara CLICK DREAPTA (aim) jetul e complet aleator (wild_spray), iar cu
	# CLICK DREAPTA urmareste efectiv camera, la fel ca orice tintire manuala.
	if is_seated():
		if not is_instance_valid(seated_toilet) or not seated_toilet.is_inside_tree():
			respawn()
			return
		velocity = Vector3.ZERO
		# Playerul NU trage niciodata automat - doar cat tine CLICK STANGA apasat.
		var want_fire_seated := controls_enabled and _shoot_requested
		pee_stream.firing = _fuel.update(delta, want_fire_seated)
		# Fara CLICK DREAPTA (aim), jetul e complet aleator; cu aim, urmareste camera.
		pee_stream.wild_spray = _shoot_requested and not _aiming
		pee_stream.show_preview = _aiming
		fuel_changed.emit(_fuel.fraction())
		return
	# Stand in picioare: nu se trage niciodata automat.
	pee_stream.firing = _fuel.update(delta, false)
	pee_stream.wild_spray = false
	pee_stream.show_preview = false
	fuel_changed.emit(_fuel.fraction())
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
	interactor.prompt_override = "[E] Stand up  ·  LEFT CLICK: shoot (random, no aim)  ·  RIGHT CLICK: aim precisely" if value and is_seated() else ""
	interactor.set_interaction_enabled(value and not is_seated())
	if not value:
		_shoot_requested = false
		_aiming = false
		pee_stream.stop()
		velocity.x = 0.0
		velocity.z = 0.0
		_update_locomotion(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE

func respawn() -> void:
	_leave_seat()
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	camera_pivot.rotation = Vector3.ZERO

func _update_locomotion(walking: bool) -> void:
	if is_seated():
		return
	if walking == _walking:
		return
	_walking = walking
	if walking:
		animation_player.play(&"locomotion/walk")
	else:
		# No idle/jump clip in this GLB yet. Use its neutral standing pose.
		animation_player.stop()
		skeleton.reset_bone_poses()

## Apelat de un NPC de duel cand incepe sa te stropeasca. Nu te face sa tragi
## automat (asta a fost eliminat) - doar retine cine e "adversarul" curent,
## in caz ca alt cod vrea sa stie ca esti intr-un duel.
func begin_auto_duel(target: Node3D) -> void:
	_auto_duel_target = target

## Apelat cand duelul se termina (NPC-ul se ridica, iese din scena etc.).
func end_auto_duel() -> void:
	_auto_duel_target = null
	if not is_seated():
		pee_stream.firing = false

func try_sit(toilet: Node3D) -> bool:
	if not controls_enabled or is_seated() or not is_instance_valid(toilet) or not toilet.has_method("try_reserve"):
		return false
	# Recheck the actual ray on activation; scripted/late calls cannot bypass walls.
	interactor.refresh_target()
	if interactor.target != toilet or not toilet.try_reserve(self):
		return false
	_standing_transform = global_transform
	seated_toilet = toilet
	_seated = true
	_shoot_requested = false
	_aiming = false
	_walking = false
	velocity = Vector3.ZERO
	global_transform = toilet.seat_transform()
	camera_pivot.position = Vector3(0, 1.15, 0.16)
	camera_pivot.rotation = Vector3.ZERO
	animation_player.play(&"locomotion/sit")
	set_controls_enabled(true)
	return true

func stand_up() -> bool:
	if not controls_enabled or not is_seated() or not is_instance_valid(seated_toilet):
		return false
	var collision := $CollisionShape3D as CollisionShape3D
	var candidates: Array[Transform3D] = [_standing_transform]
	for offset in [Vector3(0, 0, 1.3), Vector3(1, 0, 0.6), Vector3(-1, 0, 0.6)]:
		var candidate := global_transform
		candidate.origin = seated_toilet.to_global(offset)
		candidate.origin.y = _standing_transform.origin.y
		candidates.append(candidate)
	for candidate in candidates:
		candidate.origin.y += 0.06
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.transform = candidate * collision.transform
		query.collision_mask = collision_mask
		query.exclude = [get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			_leave_seat()
			global_transform = candidate
			return true
	interactor.prompt_override = "The exit is blocked. Clear the spot and press E."
	interactor.refresh_target()
	return false

func _leave_seat() -> void:
	if is_instance_valid(seated_toilet):
		seated_toilet.release(self)
	seated_toilet = null
	_seated = false
	_shoot_requested = false
	_aiming = false
	pee_stream.stop()
	camera_pivot.position = _standing_camera_position
	camera_pivot.rotation = Vector3.ZERO
	animation_player.stop()
	skeleton.reset_bone_poses()
	_walking = false
	velocity = Vector3.ZERO
	set_controls_enabled(controls_enabled)

func _exit_tree() -> void:
	if is_instance_valid(seated_toilet):
		seated_toilet.release(self)
