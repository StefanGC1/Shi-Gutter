extends Control

const HUB := "res://maps/hub/hub.tscn"
const MAIN_MENU := "res://menus/main_menu/main_menu.tscn"

var transitioning := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MusicPlayer.play("lobby")
	match Data.SelectPlayer:
		Data.SelectedCharacter.BLUE_PLAYER:
			$HBoxContainer/ButtonBlue.grab_focus()
		Data.SelectedCharacter.PURPLE_PLAYER:
			$HBoxContainer/ButtonPurple.grab_focus()
		_:
			$HBoxContainer/ButtonGreen.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_travel_to(MAIN_MENU)


func _on_button_green_pressed() -> void:
	_select_character(Data.SelectedCharacter.GREEN_PLAYER)

func _on_button_blue_pressed() -> void:
	_select_character(Data.SelectedCharacter.BLUE_PLAYER)


func _on_button_purple_pressed() -> void:
	_select_character(Data.SelectedCharacter.PURPLE_PLAYER)

func _select_character(character: Data.SelectedCharacter) -> void:
	if transitioning:
		return
	var previous_character: Data.SelectedCharacter = Data.SelectPlayer
	Data.SelectPlayer = character
	if not _travel_to(HUB):
		Data.SelectPlayer = previous_character

func _travel_to(path: String) -> bool:
	if transitioning:
		return false
	transitioning = true
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		transitioning = false
		$Label.text = "The scene couldn't be loaded. Please try again."
		push_error("Cannot load scene: %s (error %s)" % [path, error])
		return false
	return true
