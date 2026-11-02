extends Node2D

var label_base_text: String = "Current quick time state: "

@onready var actionable_event: ActionableEvent = $ActionableEvent
@onready var active_label: Label = $ActiveLabel
@onready var state_label: Label = $StateLabel

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		actionable_event._start_quicktime()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	active_label.text = "Quicktime active: " + str(actionable_event.quicktime_active)
	if actionable_event.quicktime_active:
		state_label.text = label_base_text + ActionableEvent.QuicktimeState.keys()[actionable_event.quicktime_state]
