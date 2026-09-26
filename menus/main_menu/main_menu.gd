extends Control


const CHARACTER_SELECTOR := "res://Scenes/character_selection_screen.tscn"
const OPTIONS_MENU := "res://menus/main_menu/options_menu.tscn"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Center/MenuPanel/Margin/VBox/Singleplayer.grab_focus()
	MusicPlayer.play("menu")


func _on_singleplayer_pressed() -> void:
	get_tree().change_scene_to_file(CHARACTER_SELECTOR)


func _on_multiplayer_pressed() -> void:
	# Placeholder until the multiplayer flow is implemented.
	pass


func _on_options_button_pressed() -> void:
	get_tree().change_scene_to_file(OPTIONS_MENU)
