extends Node

const TRACKS := {
	"menu": "res://assets/audio/music/muzicameniu.mp3",
	"lobby": "res://assets/audio/music/muzicalobby.mp3",
	"game": "res://assets/audio/music/muzicajoc.mp3",
}

const FADE_TIME := 1.0

var _players: Array[AudioStreamPlayer] = []
var _active_index := 0
var _current_track := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(2):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func play(track_name: String, fade_time: float = FADE_TIME) -> void:
	if track_name == _current_track:
		return
	if not TRACKS.has(track_name):
		push_warning("Music: unknown track '%s'" % track_name)
		return
	var stream_path: String = TRACKS[track_name]
	if not ResourceLoader.exists(stream_path):
		push_warning("Music: missing file '%s'" % stream_path)
		return

	var old_player := _players[_active_index]
	_active_index = 1 - _active_index
	var new_player := _players[_active_index]

	new_player.stream = load(stream_path)
	new_player.volume_db = -80.0
	new_player.play()
	_current_track = track_name

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(new_player, "volume_db", 0.0, fade_time)
	if old_player.playing:
		tween.tween_property(old_player, "volume_db", -80.0, fade_time)
		tween.chain().tween_callback(old_player.stop)
