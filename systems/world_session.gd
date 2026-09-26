extends Node3D

const HUB := "res://maps/hub/hub.tscn"
const PRACTICE := "res://maps/playground/playground.tscn"
const MAIN_MENU := "res://menus/main_menu/main_menu.tscn"
const CHARACTER_SELECTOR := "res://Scenes/character_selection_screen.tscn"

enum Mode { PLAYING, MATCH_MENU, PAUSED, TRANSITIONING }

@export var is_hub := false
@onready var player_spawn: Marker3D = $PlayerSpawn
@onready var ui: CanvasLayer = $SessionUI
var mode := Mode.PLAYING

var green_player: PackedScene = preload("res://actors/player/player_green_man.tscn")
var blue_player: PackedScene = preload("res://actors/player/player_blue_man.tscn")
var purple_player: PackedScene = preload("res://actors/player/player_purple_man.tscn")
var new_player: Player3D

func _ready() -> void:
	if not is_hub:
		MusicPlayer.play("game")

	ui.configure(is_hub)
	ui.close_requested.connect(close_overlay)
	ui.practice_requested.connect(func(): travel_to(PRACTICE))
	ui.hub_requested.connect(func(): travel_to(HUB))
	ui.main_menu_requested.connect(func(): travel_to(MAIN_MENU))

	match Data.SelectPlayer:
		Data.SelectedCharacter.GREEN_PLAYER:
			new_player = green_player.instantiate()
		Data.SelectedCharacter.BLUE_PLAYER:
			new_player = blue_player.instantiate()
		Data.SelectedCharacter.PURPLE_PLAYER:
			new_player = purple_player.instantiate()
		_:
			new_player = green_player.instantiate()

	# Set the spawn before _ready() records it for respawning.
	new_player.name = "Player3D"
	new_player.transform = player_spawn.transform
	add_child(new_player)
	new_player.camera.make_current()

	new_player.interactor.prompt_changed.connect(ui.set_prompt)
	new_player.fuel_changed.connect(ui.set_fuel)
	var station := get_node_or_null("MatchStation")
	if station != null:
		station.activated.connect(_on_station_activated)
	var character_station := get_node_or_null("CharacterStation")
	if character_station != null:
		character_station.activated.connect(_on_character_station_activated)
	new_player.set_controls_enabled(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo() and mode != Mode.TRANSITIONING:
		get_viewport().set_input_as_handled()
		if mode == Mode.PLAYING:
			mode = Mode.PAUSED
			new_player.set_controls_enabled(false)
			ui.open_pause()
		else:
			close_overlay()

func _on_station_activated(actor: CharacterBody3D) -> void:
	if actor != new_player or mode != Mode.PLAYING:
		return
	mode = Mode.MATCH_MENU
	new_player.set_controls_enabled(false)
	ui.open_match_menu()

func _on_character_station_activated(actor: CharacterBody3D) -> void:
	if actor != new_player or not is_hub or mode != Mode.PLAYING:
		return
	travel_to(CHARACTER_SELECTOR)

func close_overlay() -> void:
	if mode == Mode.TRANSITIONING:
		return
	mode = Mode.PLAYING
	ui.close_overlay()
	new_player.set_controls_enabled(true)

func travel_to(path: String) -> void:
	if mode == Mode.TRANSITIONING:
		return
	mode = Mode.TRANSITIONING
	new_player.set_controls_enabled(false)
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		mode = Mode.PAUSED
		ui.open_pause()
		ui.show_error("Scena nu s-a putut deschide. Poți reveni la joc.")
		push_error("Cannot load scene: %s (error %s)" % [path, error])

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("select_character") and not event.is_echo() and mode == Mode.PLAYING:
		get_viewport().set_input_as_handled()
		travel_to(CHARACTER_SELECTOR)
