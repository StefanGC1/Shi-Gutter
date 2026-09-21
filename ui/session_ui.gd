extends CanvasLayer

signal close_requested
signal practice_requested
signal hub_requested
signal main_menu_requested

@onready var overlay: Control = $Root/Overlay
@onready var heading: Label = $Root/Overlay/Center/Card/Margin/Content/Heading
@onready var details: Label = $Root/Overlay/Center/Card/Margin/Content/Details
@onready var practice: Button = $Root/Overlay/Center/Card/Margin/Content/Practice
@onready var multiplayer_button: Button = $Root/Overlay/Center/Card/Margin/Content/Multiplayer
@onready var resume: Button = $Root/Overlay/Center/Card/Margin/Content/Resume
@onready var return_hub: Button = $Root/Overlay/Center/Card/Margin/Content/ReturnHub
@onready var main_menu: Button = $Root/Overlay/Center/Card/Margin/Content/MainMenu
var _is_hub := false

func _ready() -> void:
	practice.pressed.connect(func(): practice_requested.emit())
	resume.pressed.connect(func(): close_requested.emit())
	return_hub.pressed.connect(func(): hub_requested.emit())
	main_menu.pressed.connect(func(): main_menu_requested.emit())

func configure(is_hub: bool) -> void:
	_is_hub = is_hub
	$Root/HUD/Location.text = "ULTIMA OPRIRE  /  HUB" if is_hub else "PLAYGROUND  /  MECI DE TEST"
	$Root/HUD/Objective.text = "Mergi la restaurant și folosește terminalul de la tejghea." if is_hub else "Antrenament în dreapta: E pentru așezare · R pentru rundă 30 s · CLICK STÂNGA pentru jet."

func set_prompt(text: String) -> void:
	$Root/HUD/Prompt.text = text
	$Root/HUD/Prompt.visible = not text.is_empty()

func open_match_menu() -> void:
	_open()
	heading.text = "O MASĂ ÎNAINTE DE MECI"
	details.text = "Antrenament local · 1 jucător\nHartă: Playground\n\nIntră pe harta de test. Multiplayer-ul nu este disponibil încă."
	practice.show()
	multiplayer_button.show()
	return_hub.hide()
	main_menu.hide()
	resume.text = "Înapoi la benzinărie"
	practice.grab_focus()

func open_pause() -> void:
	_open()
	heading.text = "MENIU"
	details.text = "Benzinăria te așteaptă." if _is_hub else "Poți continua testul sau te poți întoarce în hub."
	practice.hide()
	multiplayer_button.hide()
	return_hub.visible = not _is_hub
	main_menu.show()
	resume.text = "Continuă"
	resume.grab_focus()

func _open() -> void:
	overlay.show()
	$Root/HUD/Crosshair.hide()
	set_prompt("")

func close_overlay() -> void:
	overlay.hide()
	$Root/HUD/Crosshair.show()

func show_error(text: String) -> void:
	details.text = text
