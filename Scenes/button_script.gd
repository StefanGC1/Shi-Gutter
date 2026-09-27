extends TextureButton

var _frame: Control
var _tween: Tween

func _ready() -> void:
	_frame = get_parent() as Control
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

func _set_highlighted(highlighted: bool) -> void:
	if not is_instance_valid(_frame):
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_frame, "scale", Vector2.ONE * (1.10 if highlighted else 1.0), 0.10)

func _on_mouse_entered() -> void:
	_set_highlighted(true)

func _on_mouse_exited() -> void:
	if not has_focus():
		_set_highlighted(false)

func _on_focus_entered() -> void:
	_set_highlighted(true)

func _on_focus_exited() -> void:
	if not is_hovered():
		_set_highlighted(false)
