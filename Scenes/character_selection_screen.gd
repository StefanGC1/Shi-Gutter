extends Control

var transitioning:  bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_button_green_pressed() -> void:
	if not transitioning:
		transitioning = true
		


func _on_button_blue_pressed() -> void:
	pass # Replace with function body.


func _on_button_purple_pressed() -> void:
	pass # Replace with function body.
