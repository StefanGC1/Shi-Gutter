extends StaticBody3D

signal hit_received(source: Node)

var hits := 0
var _flash_time := 0.0
var _material: StandardMaterial3D
var _in_challenge := false
var _active := false

func show_challenge(active: bool, progress: int, required: int) -> void:
	_in_challenge = true
	_active = active
	_material.albedo_color = Color(1, 0.75, 0.1) if active else Color(0.22, 0.25, 0.28)
	$Label.text = "AIM HERE · %d/%d" % [progress, required] if active else "WAIT"

func show_free_practice() -> void:
	_in_challenge = false
	_active = false
	_material.albedo_color = Color(0.1, 0.55, 0.55)
	$Label.text = "HITS: %d" % hits

func _ready() -> void:
	_material = $Disc.get_active_material(0).duplicate() as StandardMaterial3D
	$Disc.material_override = _material

func receive_pee_hit(source: Node, _point: Vector3, _normal: Vector3) -> void:
	hits += 1
	if not _in_challenge or _active:
		_flash_time = 0.15
	if not _in_challenge:
		$Label.text = "HITS: %d" % hits
	hit_received.emit(source)

func _process(delta: float) -> void:
	_flash_time = maxf(0, _flash_time - delta)
	_material.emission_enabled = _flash_time > 0
	_material.emission = Color(1, 0.75, 0.1)
