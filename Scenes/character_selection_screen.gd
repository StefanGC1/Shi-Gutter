extends Control

var transitioning:  bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_button_green_pressed() -> void:
	if not transitioning:
		transitioning = true
		Data.SelectPlayer = Data.SelectedCharacter.GREEN_PLAYER
		
		get_tree().change_scene_to_file("res://maps/playground/playground.tscn")
		


func _on_button_blue_pressed() -> void:
	if not transitioning:
		transitioning = true
		Data.SelectPlayer = Data.SelectedCharacter.BLUE_PLAYER
		get_tree().change_scene_to_file("res://maps/playground/playground.tscn")


func _on_button_purple_pressed() -> void:
	if not transitioning:
		transitioning = true
		Data.SelectPlayer = Data.SelectedCharacter.PURPLE_PLAYER
		get_tree().change_scene_to_file("res://maps/playground/playground.tscn")
