extends CharacterBody3D

## NPC care detecteaza toaletele din scena, merge la cea mai apropiata libera
## si se aseaza pe ea cu animatia "StatToaleta" din GLB.
##
## Detectia se face in doua moduri (in ordine):
##   1. nodurile din grupul `toilet_group` (adauga toaletele in grupul "toilet"),
##   2. daca grupul e gol: orice Node3D al carui nume incepe cu `toilet_name_prefix`
##      (asa prinde automat "Toilet", "Toilet2", "ToiletLeft", "ToiletRight").
##
## Fiecare toaleta e "rezervata" prin meta, deci doi NPC nu aleg aceeasi toaleta.

signal toilet_chosen(toilet: Node3D)
signal seated(toilet: Node3D)

enum State { SEARCH, WALK, TURN, SIT }

@export_group("Model")
## GLB-ul personajului (trebuie sa contina animatiile MersCaracter1 si StatToaleta).
@export var model_scene: PackedScene = preload("res://actors/characters/BunicAlbastru.glb")
## GLB-urile privesc spre +Z, corpul merge spre -Z, deci modelul se roteste cu 180°.
@export var model_yaw_offset := PI
@export var model_offset := Vector3(0.0, 0.082764, 0.0)

@export_group("Miscare")
@export var walk_speed := 1.8
@export var acceleration := 10.0
@export var turn_speed := 7.0
## Cat de aproape trebuie sa ajunga de punctul tinta ca sa-l considere atins.
@export var arrive_tolerance := 0.22

@export_group("Detectie toalete")
@export var toilet_group := &"toilet"
@export var toilet_name_prefix := "Toilet"
## 0 = fara limita de distanta.
@export var detection_radius := 0.0
@export var rescan_interval := 1.0

@export_group("Asezare")
## Distanta la care se opreste in fata toaletei inainte sa se intoarca.
@export var approach_distance := 0.9
## Offset local fata de originea toaletei: X lateral, Y inaltime, Z in fata (spre usa).
## Regleaza Z daca personajul sta prea in fata / prea in spate pe vas.
@export var sit_offset := Vector3(0.0, 0.0, 0.22)
## Cat dureaza alunecarea finala pe vas.
@export var sit_slide_time := 0.45

@export_group("Animatii")
@export var walk_animation := &"MersCaracter1"
@export var sit_animation := &"StatToaleta"

var _state: int = State.SEARCH
var _toilet: Node3D = null
var _model: Node3D = null
var _anim: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _collision: CollisionShape3D = null
var _rescan_timer := 0.0
var _stuck_timer := 0.0
var _unstuck_timer := 0.0
var _unstuck_dir := Vector3.ZERO
var _sit_from := Vector3.ZERO
var _sit_to := Vector3.ZERO
var _sit_t := 0.0
var _current_anim := &""

func _ready() -> void:
	_collision = get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	_spawn_model()
	_pick_toilet()

func _exit_tree() -> void:
	_release_toilet()

# ---------------------------------------------------------------- model / anim

func _spawn_model() -> void:
	var holder := get_node_or_null(^"Character") as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "Character"
		add_child(holder)
	if model_scene == null:
		push_warning("ToiletNPC: model_scene nu e setat.")
		return
	_model = model_scene.instantiate() as Node3D
	holder.add_child(_model)
	_model.position = model_offset
	_model.rotation.y = model_yaw_offset
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_build_animation_library()

func _build_animation_library() -> void:
	if _anim == null:
		return
	var library := AnimationLibrary.new()
	_add_looped(library, &"walk", walk_animation)
	_add_looped(library, &"sit", sit_animation)
	_anim.add_animation_library(&"npc", library)

func _add_looped(library: AnimationLibrary, key: StringName, source: StringName) -> void:
	if not _anim.has_animation(source):
		push_warning("ToiletNPC: animatia '%s' nu exista in GLB." % source)
		return
	var clip := _anim.get_animation(source).duplicate() as Animation
	clip.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(key, clip)

func _play(key: StringName) -> void:
	if _anim == null or _current_anim == key:
		return
	_current_anim = key
	if key == &"":
		_anim.stop()
		if _skeleton != null:
			_skeleton.reset_bone_poses()
		return
	var full := "npc/" + String(key)
	if _anim.has_animation(full):
		_anim.play(full)

# ------------------------------------------------------------------- detectie

func _find_toilets() -> Array:
	var found: Array = []
	for node in get_tree().get_nodes_in_group(toilet_group):
		if node is Node3D:
			found.append(node)
	if found.is_empty() and toilet_name_prefix != "":
		var root := get_tree().current_scene
		if root != null:
			for node in root.find_children(toilet_name_prefix + "*", "Node3D", true, false):
				found.append(node)
	# Elimina nodurile imbricate (ex. copii ai unei toalete deja gasite).
	var clean: Array = []
	for node in found:
		var nested := false
		for other in found:
			if other != node and other.is_ancestor_of(node):
				nested = true
				break
		if not nested:
			clean.append(node)
	return clean

func _is_free(toilet: Node3D) -> bool:
	if not toilet.has_meta(&"occupied_by"):
		return true
	var owner_npc = toilet.get_meta(&"occupied_by")
	return not is_instance_valid(owner_npc) or owner_npc == self

func _pick_toilet() -> void:
	var best: Node3D = null
	var best_distance := INF
	for toilet in _find_toilets():
		if not _is_free(toilet):
			continue
		var distance := global_position.distance_to(toilet.global_position)
		if detection_radius > 0.0 and distance > detection_radius:
			continue
		if distance < best_distance:
			best_distance = distance
			best = toilet
	if best == null:
		_state = State.SEARCH
		return
	_release_toilet()
	_toilet = best
	_toilet.set_meta(&"occupied_by", self)
	_state = State.WALK
	toilet_chosen.emit(_toilet)

func _release_toilet() -> void:
	if is_instance_valid(_toilet) and _toilet.has_meta(&"occupied_by"):
		if _toilet.get_meta(&"occupied_by") == self:
			_toilet.remove_meta(&"occupied_by")

# --------------------------------------------------------- puncte de interes

## Vasul are rezervorul spre -Z local, deci "fata" toaletei (unde stai) e +Z.
func _toilet_forward() -> Vector3:
	var forward := _toilet.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3.FORWARD
	return forward.normalized()

func _approach_point() -> Vector3:
	var point := _toilet.global_position + _toilet_forward() * approach_distance
	point.y = global_position.y
	return point

func _sit_point() -> Vector3:
	var point := _toilet.global_transform * sit_offset
	point.y = global_position.y + sit_offset.y
	return point

# ------------------------------------------------------------------ physics

func _physics_process(delta: float) -> void:
	if not is_on_floor() and _state != State.SIT:
		velocity += get_gravity() * delta

	match _state:
		State.SEARCH:
			_process_search(delta)
		State.WALK:
			_process_walk(delta)
		State.TURN:
			_process_turn(delta)
		State.SIT:
			_process_sit(delta)

func _process_search(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	_play(&"")
	move_and_slide()
	_rescan_timer -= delta
	if _rescan_timer <= 0.0:
		_rescan_timer = rescan_interval
		_pick_toilet()

func _process_walk(delta: float) -> void:
	if not is_instance_valid(_toilet):
		_state = State.SEARCH
		return
	var target := _approach_point()
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() <= arrive_tolerance:
		_state = State.TURN
		return

	var direction := to_target.normalized()
	if _unstuck_timer > 0.0:
		_unstuck_timer -= delta
		direction = (direction + _unstuck_dir).normalized()

	velocity.x = move_toward(velocity.x, direction.x * walk_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * walk_speed, acceleration * delta)
	_face(direction, delta)
	_play(&"walk")
	move_and_slide()
	_check_stuck(delta, direction)

func _check_stuck(delta: float, direction: Vector3) -> void:
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar < walk_speed * 0.25:
		_stuck_timer += delta
		if _stuck_timer > 0.5 and _unstuck_timer <= 0.0:
			_stuck_timer = 0.0
			_unstuck_timer = 0.6
			# Ocoleste lateral, alternand partea.
			_unstuck_dir = direction.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
	else:
		_stuck_timer = 0.0

func _process_turn(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	_play(&"")
	move_and_slide()
	# Se intoarce cu spatele la rezervor: priveste in directia +Z a toaletei.
	var desired := _toilet_forward()
	var aligned := _face(desired, delta)
	if aligned:
		_sit_from = global_position
		_sit_to = _sit_point()
		_sit_t = 0.0
		_state = State.SIT
		velocity = Vector3.ZERO
		if _collision != null:
			_collision.disabled = true
		_play(&"sit")
		seated.emit(_toilet)

func _process_sit(delta: float) -> void:
	if _sit_t < 1.0:
		_sit_t = minf(_sit_t + delta / maxf(sit_slide_time, 0.01), 1.0)
		global_position = _sit_from.lerp(_sit_to, _sit_t)
	_play(&"sit")

## Roteste corpul astfel incat -Z (fata personajului) sa priveasca spre `direction`.
## Returneaza true cand e aliniat.
func _face(direction: Vector3, delta: float) -> bool:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return true
	direction = direction.normalized()
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
	return absf(angle_difference(rotation.y, target_yaw)) < 0.05
