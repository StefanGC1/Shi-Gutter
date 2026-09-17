extends Control


const CHARACTER_SELECTOR := "res://Scenes/character_selection_screen.tscn"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Center/MenuPanel/Margin/VBox/Singleplayer.grab_focus()


func _on_singleplayer_pressed() -> void:
	get_tree().change_scene_to_file(CHARACTER_SELECTOR)


func _on_multiplayer_pressed() -> void:
	# Placeholder until the multiplayer flow is implemented.
	pass
