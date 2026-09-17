extends StaticBody3D

signal activated(player: CharacterBody3D)

@export var prompt := "Interacționează"

func get_interaction_prompt() -> String:
	return prompt

func interact(player: CharacterBody3D) -> void:
	activated.emit(player)
