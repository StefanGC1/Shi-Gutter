extends Control

signal back_requested

const MAIN_MENU := "res://menus/main_menu/main_menu.tscn"

## When true (e.g. embedded inside the in-game pause menu), the Back button
## just emits back_requested instead of changing the scene, so the caller
## decides how to return (and the game session is never destroyed).
@export var embedded_mode := false

@onready var display_mode_option: OptionButton = $Center/MenuPanel/Margin/VBox/DisplayModeOption
@onready var resolution_option: OptionButton = $Center/MenuPanel/Margin/VBox/ResolutionOption
@onready var reset_button: Button = $Center/MenuPanel/Margin/VBox/ResetButton
@onready var back_button: Button = $Center/MenuPanel/Margin/VBox/BackButton
@onready var reset_confirm: ConfirmationDialog = $ResetConfirmDialog


func _ready() -> void:
	if not embedded_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_display_mode_option()
	_setup_resolution_option()
	reset_button.pressed.connect(_on_reset_button_pressed)
	reset_confirm.confirmed.connect(_on_reset_confirmed)
	back_button.pressed.connect(_on_back_button_pressed)
	back_button.grab_focus()


func _setup_display_mode_option() -> void:
	display_mode_option.clear()
	display_mode_option.add_item("Window", Data.DisplayMode.WINDOWED)
	display_mode_option.add_item("Fullscreen", Data.DisplayMode.FULLSCREEN)
	display_mode_option.add_item("Borderless Fullscreen", Data.DisplayMode.BORDERLESS_WINDOWED)
	# Saved settings are the source of truth (and are already applied to the
	# window by Data at boot), so read the selection from there.
	display_mode_option.select(display_mode_option.get_item_index(Data.display_mode))
	display_mode_option.item_selected.connect(_on_display_mode_selected)
	_update_resolution_enabled()


func _on_display_mode_selected(index: int) -> void:
	Data.set_display_mode(display_mode_option.get_item_id(index))
	_update_resolution_enabled()


func _update_resolution_enabled() -> void:
	# A specific resolution only means something in windowed mode.
	resolution_option.disabled = Data.display_mode != Data.DisplayMode.WINDOWED


func _setup_resolution_option() -> void:
	resolution_option.clear()
	for res in Data.RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [res.x, res.y])
	var idx := Data.RESOLUTIONS.find(Data.resolution)
	resolution_option.select(idx if idx != -1 else 0)
	resolution_option.item_selected.connect(_on_resolution_selected)


func _on_resolution_selected(index: int) -> void:
	Data.set_resolution(Data.RESOLUTIONS[index])


func _on_reset_button_pressed() -> void:
	reset_confirm.popup_centered()


func _on_reset_confirmed() -> void:
	Data.reset_to_defaults()
	# Re-sync this menu's controls with the values Data just reset to.
	display_mode_option.select(display_mode_option.get_item_index(Data.display_mode))
	var idx: int = Data.RESOLUTIONS.find(Data.resolution)
	resolution_option.select(idx if idx != -1 else 0)
	_update_resolution_enabled()


func _on_back_button_pressed() -> void:
	if embedded_mode:
		back_requested.emit()
	else:
		get_tree().change_scene_to_file(MAIN_MENU)

