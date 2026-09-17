extends Node3D

const HUB := "res://maps/hub/hub.tscn"
const PRACTICE := "res://maps/playground/playground.tscn"
const MAIN_MENU := "res://menus/main_menu/main_menu.tscn"

enum Mode { PLAYING, MATCH_MENU, PAUSED, TRANSITIONING }

@export var is_hub := false
@onready var player: CharacterBody3D = $Player3D
@onready var ui: CanvasLayer = $SessionUI
var mode := Mode.PLAYING

func _ready() -> void:
	ui.configure(is_hub)
	ui.close_requested.connect(close_overlay)
	ui.practice_requested.connect(func(): travel_to(PRACTICE))
	ui.hub_requested.connect(func(): travel_to(HUB))
	ui.main_menu_requested.connect(func(): travel_to(MAIN_MENU))
	player.interactor.prompt_changed.connect(ui.set_prompt)
	var station := get_node_or_null("MatchStation")
	if station != null:
		station.activated.connect(_on_station_activated)
	player.set_controls_enabled(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo() and mode != Mode.TRANSITIONING:
		get_viewport().set_input_as_handled()
		if mode == Mode.PLAYING:
			mode = Mode.PAUSED
			player.set_controls_enabled(false)
			ui.open_pause()
		else:
			close_overlay()

func _on_station_activated(actor: CharacterBody3D) -> void:
	if actor != player or mode != Mode.PLAYING:
		return
	mode = Mode.MATCH_MENU
	player.set_controls_enabled(false)
	ui.open_match_menu()

func close_overlay() -> void:
	if mode == Mode.TRANSITIONING:
		return
	mode = Mode.PLAYING
	ui.close_overlay()
	player.set_controls_enabled(true)

func travel_to(path: String) -> void:
	if mode == Mode.TRANSITIONING:
		return
	mode = Mode.TRANSITIONING
	player.set_controls_enabled(false)
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		mode = Mode.PAUSED
		ui.open_pause()
		ui.show_error("Scena nu s-a putut deschide. Poți reveni la joc.")
		push_error("Cannot load scene: %s (error %s)" % [path, error])
