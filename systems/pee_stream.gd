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
var aim_camera: Camera3D
var _clock := 0.0
var _drops: Array[Dictionary] = []
var _splashes: Array[Dictionary] = []
var _mesh: SphereMesh

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

func stop() -> void:
	firing = false
	_clock = 0
	for drop in _drops:
		drop.visual.queue_free()
	for splash in _splashes:
		splash.visual.queue_free()
	_drops.clear()
	_splashes.clear()

func _visual(at: Vector3) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = _mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	visual.top_level = true
	visual.global_position = at
	return visual

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 5, [source.get_rid()])
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _emit_drop() -> void:
	if _drops.size() >= MAX_DROPS:
		return
	var aim := aim_camera.global_position - aim_camera.global_basis.z * 25
	var obstruction := _ray(aim_camera.global_position, aim)
	if not obstruction.is_empty():
		aim = obstruction.position
	var origin := global_position
	_drops.append({"visual": _visual(origin), "velocity": origin.direction_to(aim) * speed, "age": 0.0})

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or not is_instance_valid(aim_camera):
		return
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
