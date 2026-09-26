extends Control

signal back_requested

const MAIN_MENU := "res://menus/main_menu/main_menu.tscn"

## When true (e.g. embedded inside the in-game pause menu), the Back button
## just emits back_requested instead of changing the scene, so the caller
## decides how to return (and the game session is never destroyed).
@export var embedded_mode := false

enum DisplayMode { WINDOWED, FULLSCREEN, BORDERLESS_WINDOWED }

const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

@onready var display_mode_option: OptionButton = $Center/MenuPanel/Margin/VBox/DisplayModeOption
@onready var resolution_option: OptionButton = $Center/MenuPanel/Margin/VBox/ResolutionOption
@onready var back_button: Button = $Center/MenuPanel/Margin/VBox/BackButton


func _ready() -> void:
	if not embedded_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_display_mode_option()
	_setup_resolution_option()
	back_button.pressed.connect(_on_back_button_pressed)
	back_button.grab_focus()


func _setup_display_mode_option() -> void:
	display_mode_option.clear()
	display_mode_option.add_item("Window", DisplayMode.WINDOWED)
	display_mode_option.add_item("Fullscreen", DisplayMode.FULLSCREEN)
	display_mode_option.add_item("Borderless Fullscreen", DisplayMode.BORDERLESS_WINDOWED)

	var selected := DisplayMode.WINDOWED
	var current_mode := DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		selected = DisplayMode.FULLSCREEN
	elif DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		selected = DisplayMode.BORDERLESS_WINDOWED
	display_mode_option.select(display_mode_option.get_item_index(selected))
	display_mode_option.item_selected.connect(_on_display_mode_selected)


func _on_display_mode_selected(index: int) -> void:
	match display_mode_option.get_item_id(index):
		DisplayMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DisplayMode.BORDERLESS_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(DisplayServer.screen_get_size())
			get_window().move_to_center()


func _setup_resolution_option() -> void:
	resolution_option.clear()
	for res in RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [res.x, res.y])
	var current := DisplayServer.window_get_size()
	var idx := RESOLUTIONS.find(current)
	resolution_option.select(idx if idx != -1 else 0)
	resolution_option.item_selected.connect(_on_resolution_selected)


func _on_resolution_selected(index: int) -> void:
	var res: Vector2i = RESOLUTIONS[index]
	DisplayServer.window_set_size(res)
	get_window().move_to_center()


func _on_back_button_pressed() -> void:
	if embedded_mode:
		back_requested.emit()
	else:
		get_tree().change_scene_to_file(MAIN_MENU)

