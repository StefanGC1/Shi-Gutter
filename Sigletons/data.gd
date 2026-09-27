extends Node

## Single autoload that owns everything that should survive a full game
## restart: which character is selected, the window/resolution settings, and
## each practice toilet's best score. Everything here is loaded once at boot
## and written back to SAVE_PATH every time something changes.

const SAVE_PATH := "user://save.cfg"

enum SelectedCharacter {
	GREEN_PLAYER,
	BLUE_PLAYER,
	PURPLE_PLAYER,
}

enum DisplayMode { WINDOWED, FULLSCREEN, BORDERLESS_WINDOWED }

## Explicitly typed as Array[Vector2i] (not just `:=`) so static typing carries
## across the autoload boundary: an untyped const array is seen as Variant
## from other scripts, which is what made `Data.RESOLUTIONS.find(...)` return
## Variant instead of int and broke `:=` inference in options_menu.gd.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

const DEFAULT_CHARACTER := SelectedCharacter.GREEN_PLAYER
const DEFAULT_DISPLAY_MODE := DisplayMode.FULLSCREEN
const DEFAULT_RESOLUTION := Vector2i(1920, 1080) # Full HD

var SelectPlayer: SelectedCharacter = DEFAULT_CHARACTER
var display_mode: DisplayMode = DEFAULT_DISPLAY_MODE
var resolution: Vector2i = DEFAULT_RESOLUTION
## Best practice-challenge score per toilet, keyed by "<scene path>::<node name>"
## so every practice spot (current and future ones) keeps its own record.
var best_scores: Dictionary = {}

func _ready() -> void:
	# Persists across scene changes and keeps loading/saving even while paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	apply_display_mode(display_mode)
	apply_resolution(resolution)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return # First run, or no save yet: keep the defaults above.
	SelectPlayer = cfg.get_value("player", "selected_character", SelectPlayer)
	display_mode = cfg.get_value("display", "mode", display_mode)
	resolution = cfg.get_value("display", "resolution", resolution)
	best_scores = cfg.get_value("practice", "best_scores", best_scores)

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "selected_character", SelectPlayer)
	cfg.set_value("display", "mode", display_mode)
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("practice", "best_scores", best_scores)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Data: could not save %s (error %s)" % [SAVE_PATH, err])

## --------------------------------------------------------------- character

func set_selected_character(character: SelectedCharacter) -> void:
	SelectPlayer = character
	save()

## ------------------------------------------------------------------ display

## Actually changes the window; does not save (used both from set_display_mode
## below and once at boot, when saving again would be pointless).
func apply_display_mode(mode: DisplayMode) -> void:
	display_mode = mode
	match mode:
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

func set_display_mode(mode: DisplayMode) -> void:
	apply_display_mode(mode)
	save()

func apply_resolution(res: Vector2i) -> void:
	resolution = res
	# A specific resolution only makes sense in windowed mode; fullscreen
	# already fills the screen and borderless was just sized to it above.
	if display_mode == DisplayMode.WINDOWED:
		DisplayServer.window_set_size(res)
		get_window().move_to_center()

func set_resolution(res: Vector2i) -> void:
	apply_resolution(res)
	save()

## ----------------------------------------------------------------- practice

## Reports whether this is a new record (so callers can show/hide a message).
func set_best_score(key: String, score: int) -> bool:
	var previous: int = best_scores.get(key, 0)
	if score <= previous:
		return false
	best_scores[key] = score
	save()
	return true

func get_best_score(key: String) -> int:
	return best_scores.get(key, 0)

## --------------------------------------------------------------------- reset

## Wipes everything back to first-run defaults (character, display settings,
## practice records), re-applies the window state, and saves immediately so
## the reset survives a crash/relaunch. Callers (e.g. the Options menu)
## should refresh their own UI afterwards to reflect the new values.
func reset_to_defaults() -> void:
	SelectPlayer = DEFAULT_CHARACTER
	best_scores = {}
	apply_display_mode(DEFAULT_DISPLAY_MODE)
	apply_resolution(DEFAULT_RESOLUTION)
	save()
