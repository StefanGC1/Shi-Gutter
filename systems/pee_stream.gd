extends Node3D

# Health code can subscribe without coupling this effect to a particular HP API.
signal hit(collider: Node, point: Vector3, normal: Vector3, source: Node)

@export var drops_per_second := 36.0
@export var speed := 16.0
@export var lifetime := 1.6
@export var gravity := Vector3(0, -4, 0)
const MAX_DROPS := 64
const MAX_SPLASHES := 24

var firing := false
var source: CharacterBody3D
## RID-uri suplimentare ignorate de raycast (ex: toaleta pe care sta sursa,
## ca jetul sa nu se blocheze in propriul vas cand porneste de langa el).
var extra_exclude: Array[RID] = []
## Folosit cand tintirea e manuala (jucatorul, cu mouse-ul): jetul urmareste camera.
var aim_camera: Camera3D
## Folosit cand tintirea e automata (NPC-uri): jetul tinteste acest nod (cu o
## sansa `aim_target_accuracy` sa chiar il nimereasca - vezi mai jos). Are
## prioritate fata de aim_camera. NU inseamna "homing": fiecare strop e tras o
## singura data spre un punct calculat la lansare, nu isi corecteaza traiectoria in zbor.
var aim_target: Node3D = null
## Cand e true (fara aim_target sau cand se rateaza tinta): jetul zboara
## complet aleator (in orice directie, inclusiv spre sursa insasi) - fara
## nicio urmarire a vreunei tinte.
var wild_spray := false
## Offset pe verticala fata de aim_target (tinteste cam la piept, nu la picioare).
@export var aim_target_offset := Vector3(0, 1.2, 0)
## Sansa (0-1) ca un strop tras spre aim_target sa il nimereasca cu adevarat;
## restul stropilor sunt complet aleatori (nu doar o mica deviatie) - fara homing.
@export_range(0.0, 1.0) var aim_target_accuracy := 1.0
## Cand e true (doar tintire manuala, cu aim_camera): deseneaza un mic "cerc"
## pe suprafata unde ar ateriza jetul daca ai trage acum.
var show_preview := false

var _clock := 0.0
var _drops: Array[Dictionary] = []
var _splashes: Array[Dictionary] = []
var _mesh: SphereMesh
var _preview: MeshInstance3D

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 0.83, 0.08)
	material.emission_enabled = true
	material.emission = Color(0.55, 0.34, 0.01)
	_mesh = SphereMesh.new()
	_mesh.radius = 0.035
	_mesh.height = 0.07
	_mesh.radial_segments = 6
	_mesh.rings = 3
	_mesh.material = material
	var preview_mesh := CylinderMesh.new()
	preview_mesh.top_radius = 0.32
	preview_mesh.bottom_radius = 0.32
	preview_mesh.height = 0.015
	preview_mesh.radial_segments = 20
	var preview_material := StandardMaterial3D.new()
	preview_material.albedo_color = Color(1, 0.83, 0.08, 0.55)
	preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	preview_mesh.material = preview_material
	_preview = MeshInstance3D.new()
	_preview.mesh = preview_mesh
	_preview.top_level = true
	_preview.visible = false
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview)

func stop() -> void:
	firing = false
	_clock = 0
	for drop in _drops:
		drop.visual.queue_free()
	for splash in _splashes:
		splash.visual.queue_free()
	_drops.clear()
	_splashes.clear()
	if is_instance_valid(_preview):
		_preview.visible = false

func _visual(at: Vector3) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = _mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	visual.top_level = true
	visual.global_position = at
	return visual

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var exclude: Array[RID] = [source.get_rid()]
	exclude.append_array(extra_exclude)
	var query := PhysicsRayQueryParameters3D.create(from, to, 5, exclude)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _random_point() -> Vector3:
	# Complet aleator: orice directie, orice unghi, poate nimeri chiar sursa.
	var random_dir := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	if random_dir.length_squared() < 0.0001:
		random_dir = Vector3.UP
	random_dir = random_dir.normalized()
	return global_position + random_dir * randf_range(1.5, 6.0)

## Returneaza punctul de unde "vine" jetul si punctul spre care tinteste,
## fie dupa camera (tintire manuala), fie dupa aim_target (NPC), fie complet
## aleator. Nu exista homing: fiecare strop primeste o tinta fixa la lansare.
func _aim_from_to() -> Dictionary:
	if aim_target != null and is_instance_valid(aim_target):
		if randf() <= aim_target_accuracy:
			var point := aim_target.global_position + aim_target_offset
			return {"from": global_position, "to": point}
		# Rateaza: complet aleator, nu doar o mica deviatie langa tinta.
		return {"from": global_position, "to": _random_point()}
	if wild_spray:
		return {"from": global_position, "to": _random_point()}
	var aim := aim_camera.global_position - aim_camera.global_basis.z * 25
	return {"from": aim_camera.global_position, "to": aim}

func _emit_drop() -> void:
	if _drops.size() >= MAX_DROPS:
		return
	var aim := _aim_from_to()
	var target_point: Vector3 = aim.to
	var obstruction := _ray(aim.from, target_point)
	if not obstruction.is_empty():
		target_point = obstruction.position
	var origin := global_position
	_drops.append({"visual": _visual(origin), "velocity": origin.direction_to(target_point) * speed, "age": 0.0})

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source):
		return
	var has_aim := (aim_target != null and is_instance_valid(aim_target)) or is_instance_valid(aim_camera)
	if not has_aim:
		return
	if show_preview and is_instance_valid(aim_camera):
		var preview_target := aim_camera.global_position - aim_camera.global_basis.z * 25
		var preview_hit := _ray(aim_camera.global_position, preview_target)
		if not preview_hit.is_empty():
			_preview.visible = true
			_preview.global_position = preview_hit.position + preview_hit.normal * 0.02
			_preview.global_basis = Basis(Quaternion(Vector3.UP, preview_hit.normal))
		else:
			_preview.visible = false
	else:
		_preview.visible = false
	if firing:
		_clock += delta
		while _clock >= 1.0 / drops_per_second:
			_clock -= 1.0 / drops_per_second
			_emit_drop()
	else:
		_clock = 0
	var impacts: Array[Dictionary] = []
	for index in range(_drops.size() - 1, -1, -1):
		var drop := _drops[index]
		drop.age += delta
		var start: Vector3 = drop.visual.global_position
		var end: Vector3 = start + drop.velocity * delta + gravity * delta * delta * 0.5
		drop.velocity += gravity * delta
		var contact := _ray(start, end)
		if not contact.is_empty():
			if _splashes.size() < MAX_SPLASHES:
				var visual := _visual(contact.position + contact.normal * 0.02)
				visual.scale = Vector3.ONE * 2.2
				_splashes.append({"visual": visual, "age": 0.0})
			impacts.append(contact)
		if not contact.is_empty() or drop.age >= lifetime:
			drop.visual.queue_free()
			_drops.remove_at(index)
		else:
			drop.visual.global_position = end
			drop.visual.global_basis = Basis(Quaternion(Vector3.UP, (drop.velocity as Vector3).normalized())).scaled(Vector3(0.55, 4, 0.55))
	for index in range(_splashes.size() - 1, -1, -1):
		var splash := _splashes[index]
		splash.age += delta
		splash.visual.scale = Vector3.ONE * maxf(0.01, 2.2 * (1 - splash.age / 0.3))
		if splash.age >= 0.3:
			splash.visual.queue_free()
			_splashes.remove_at(index)
	# Notify after simulation: a health handler may stop the stream or respawn us.
	for contact in impacts:
		if not is_instance_valid(source) or not source.is_inside_tree():
			break
		var collider := contact.collider as Node
		if is_instance_valid(collider):
			hit.emit(collider, contact.position, contact.normal, source)
			if is_instance_valid(collider) and collider.has_method("receive_pee_hit"):
				collider.receive_pee_hit(source, contact.position, contact.normal)
