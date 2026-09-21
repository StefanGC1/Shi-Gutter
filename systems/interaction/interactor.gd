extends RayCast3D

signal prompt_changed(text: String)

var interaction_enabled := true
var target: Node
var _prompt := ""
var prompt_override := ""

func _physics_process(_delta: float) -> void:
	refresh_target()

func refresh_target() -> void:
	target = null
	if interaction_enabled:
		force_raycast_update()
		if is_colliding():
			var candidate := get_collider() as Node
			# Stop at the first hit, including walls; never search through occluders.
			while candidate != null:
				if candidate.has_method("interact") and candidate.has_method("get_interaction_prompt"):
					target = candidate
					break
				candidate = candidate.get_parent()
	var text := ""
	if is_instance_valid(target):
		text = "[E]  " + str(target.get_interaction_prompt())
	if not prompt_override.is_empty():
		text = prompt_override
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)

func try_interact(player: CharacterBody3D) -> void:
	refresh_target()
	if is_instance_valid(target):
		target.interact(player)

func set_interaction_enabled(value: bool) -> void:
	interaction_enabled = value
	refresh_target()
