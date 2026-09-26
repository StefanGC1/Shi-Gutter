extends Node3D

@export var seat_offset := Vector3(0, -0.258, 0.5)

func _enter_tree() -> void:
	add_to_group("toilet")

func occupant() -> Node:
	if not has_meta(&"occupied_by"):
		return null
	var actor = get_meta(&"occupied_by")
	if is_instance_valid(actor) and actor.is_inside_tree():
		return actor
	return null

func is_available_for(actor: Node) -> bool:
	var owner_actor := occupant()
	return owner_actor == null or owner_actor == actor

func try_reserve(actor: Node) -> bool:
	if not is_instance_valid(actor) or not is_available_for(actor):
		return false
	set_meta(&"occupied_by", actor)
	return true

func release(actor: Node) -> void:
	if has_meta(&"occupied_by") and get_meta(&"occupied_by") == actor:
		remove_meta(&"occupied_by")

func get_interaction_prompt() -> String:
	return "Toilet occupied" if occupant() != null else "Sit on the toilet"

func interact(actor: CharacterBody3D) -> void:
	if actor.has_method("try_sit"):
		actor.try_sit(self)

func seat_transform() -> Transform3D:
	var forward := global_basis.z
	forward.y = 0
	forward = forward.normalized()
	return Transform3D(Basis(Vector3.UP, atan2(-forward.x, -forward.z)), to_global(seat_offset))
