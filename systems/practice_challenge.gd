extends CanvasLayer

## Local practice only: independent from combat HP and multiplayer state.
@export var toilet_path: NodePath
@export var target_paths: Array[NodePath] = []
@export var enemy_path: NodePath
@export_range(1.0, 120.0) var round_seconds := 30.0
@export_range(1, 20) var hits_per_target := 3

@onready var toilet: Node3D = get_node(toilet_path)
@onready var status: Label = $Panel/Margin/Rows/Status
@onready var details: Label = $Panel/Margin/Rows/Details
@onready var challenge_hud: Panel = $ChallengeHUD
@onready var timer_label: Label = $ChallengeHUD/Margin/Rows/Timer
@onready var score_label: Label = $ChallengeHUD/Margin/Rows/Score
@onready var result_panel: Panel = $ResultPanel
@onready var result_label: Label = $ResultPanel/Margin/Result

var targets: Array[StaticBody3D] = []
var running := false
var time_left := 0.0
var score := 0
var best_score := 0
var active_index := 0
var target_hits := 0
var _result := ""
## Identifies this practice spot across sessions ("<scene path>::<node name>"),
## so its record is kept separately from any other practice toilet.
var _score_key := ""
var _enemy: Node = null

func _ready() -> void:
	_score_key = "%s::%s" % [get_tree().current_scene.scene_file_path, name]
	best_score = Data.get_best_score(_score_key)
	_enemy = get_node_or_null(enemy_path) if not enemy_path.is_empty() else null
	challenge_hud.hide()
	result_panel.hide()
	for path in target_paths:
		var target: StaticBody3D = get_node(path)
		targets.append(target)
		target.hit_received.connect(_on_target_hit.bind(target))
	visible = false

func _player() -> Player3D:
	var candidate = get_parent().get("new_player")
	return candidate as Player3D if is_instance_valid(candidate) else null

func _on_practice_seat(player: Player3D) -> bool:
	return (is_instance_valid(player) and is_instance_valid(toilet)
		and toilet.is_inside_tree() and player.is_seated()
		and player.seated_toilet == toilet and toilet.occupant() == player)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("practice_round") and not event.is_echo():
		if start_round():
			get_viewport().set_input_as_handled()

func start_round() -> bool:
	var player := _player()
	if running or targets.is_empty() or not _on_practice_seat(player) or not player.controls_enabled:
		return false
	# Discard drops fired before the start; they cannot score in the new round.
	player.pee_stream.stop()
	running = true
	time_left = round_seconds
	score = 0
	target_hits = 0
	active_index = 0
	_result = ""
	if is_instance_valid(_enemy) and _enemy.has_method("set_challenge_hidden"):
		_enemy.set_challenge_hidden(true)
	result_panel.hide()
	_update_targets()
	_update_hud()
	return true

func _physics_process(delta: float) -> void:
	var player := _player()
	var seated := _on_practice_seat(player)
	if running and not seated:
		_finish_round(false)
	visible = seated and player.controls_enabled
	if not visible:
		return
	if running:
		time_left = maxf(0.0, time_left - delta)
		if time_left <= 0.0:
			_finish_round(true)
	_update_hud()

func _on_target_hit(source: Node, target: StaticBody3D) -> void:
	var player := _player()
	if not running or time_left <= 0.0 or not _on_practice_seat(player):
		return
	if not player.controls_enabled or source != player or target != targets[active_index]:
		return
	target_hits += 1
	if target_hits >= hits_per_target:
		score += 10
		target_hits = 0
		active_index = (active_index + 1) % targets.size()
	_update_targets()
	_update_hud()

func _update_targets() -> void:
	for index in targets.size():
		targets[index].show_challenge(index == active_index, target_hits, hits_per_target)

func _finish_round(completed: bool) -> void:
	running = false
	if completed:
		if Data.set_best_score(_score_key, score):
			best_score = score
			_result = "NEW BEST · %d points" % score
		else:
			_result = "ROUND FINISHED · %d points" % score
	else:
		_result = "ROUND CANCELLED · you left the toilet"
	if is_instance_valid(_enemy) and _enemy.has_method("set_challenge_hidden"):
		_enemy.set_challenge_hidden(false)
	for target in targets:
		target.show_free_practice()
	_update_hud()

func _update_hud() -> void:
	if running:
		challenge_hud.show()
		result_panel.hide()
		timer_label.text = "%02d" % ceili(time_left)
		timer_label.modulate = Color(1.0, 0.22, 0.22) if time_left < 5.0 else Color(1.0, 0.82, 0.28)
		score_label.text = "SCORE  %d    ·    HIGH SCORE  %d" % [score, best_score]
		status.text = "TARGET %d/%d" % [target_hits, hits_per_target]
		details.text = "+10 points per target · E: leave the toilet"
	else:
		challenge_hud.hide()
		if not _result.is_empty() and not _result.begins_with("ROUND CANCELLED"):
			result_panel.show()
			result_label.text = "SCORE  %d    VS    HIGH SCORE  %d" % [score, best_score]
			result_label.modulate = Color(1.0, 0.82, 0.28)
		else:
			result_panel.hide()
		status.text = _result if not _result.is_empty() else "FREE PRACTICE"
		details.text = "R: %d-second round\nHit only the yellow target %d times.\nHigh score: %d" % [round_seconds, hits_per_target, best_score]
