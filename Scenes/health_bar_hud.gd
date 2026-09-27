extends CanvasLayer

var max_health := 500

@onready var bar: ProgressBar = $ProgressBar
@onready var value_label: Label = $ProgressBar/Value

## fraction: 0..1, cat HP ii mai ramane jucatorului.
func set_max_health(value: float) -> void:
	max_health = maxi(1, roundi(value))

func set_health(fraction: float) -> void:
	var clamped := clampf(fraction, 0.0, 1.0)
	bar.value = clamped * 100.0
	var current_hp := clampi(roundi(clamped * max_health), 0, max_health)
	value_label.text = "HP  %d / %d" % [current_hp, max_health]
