extends "res://actors/npc/toilet_npc.gd"

## Varianta de ToiletNPC pentru "duelul de pipi" din zona de antrenament.
##
## La fiecare intrare in scena alege RANDOM una din toaletele listate in
## `duel_toilets` (in loc de cea mai apropiata, ca la ToiletNPC normal), merge,
## se aseaza cu animatia mostenita din ToiletNPC si, dupa o mica pauza, incepe
## sa traga spre jucator - fara homing: o parte din stropi (`hit_chance`,
## implicit 50%) sunt tintiti spre jucator, restul zboara complet aleator.
## Trage pana ramane fara fuel, apoi sta AFK pana se reincarca 100%, apoi
## reincepe - tot asa, cat timp dureaza duelul (vezi PeeFuel).
##
## Setup in editor: pune scriptul asta pe o instanta a scenei ToiletNPC.tscn
## (poti duplica NpcBunic sau NpcDoamna), apoi in Inspector la "Duel toaleta"
## adauga in `duel_toilets` cate un NodePath spre PracticeToilet si PracticeToilet2.

const PeeStream = preload("res://systems/pee_stream.gd")
# PeeFuel are class_name global (in pee_fuel.gd), deci nu se mai preincarca aici.

@export_group("Duel toaleta")
## Toaletele intre care alege random la fiecare intrare (ex: ../PracticeToilet, ../PracticeToilet2).
@export var duel_toilets: Array[NodePath] = []
## Cat asteapta dupa ce s-a asezat complet, inainte sa inceapa sa traga.
@export var pee_start_delay := 0.5
## Sansa (0-1) ca un strop tras spre jucator sa il nimereasca cu adevarat.
@export_range(0.0, 1.0) var hit_chance := 0.5
## Pozitia locala de unde "pleaca" jetul (aprox in zona pulii, nu la sold).
@export var pee_origin := Vector3(0.0, 0.32, 0.35)

var _pee_stream: Node3D
var _player: Node3D
var _pee_timer := 0.0
var _dueling := false
## Rezerva invizibila a NPC-ului; aceleasi numere ca la player (vezi PeeFuel).
var _fuel := PeeFuel.new()
## Cat timp e true, NPC-ul incearca sa traga; cand ramane fara fuel se opreste
## (AFK) pana se reincarca 100%, apoi reincepe - la nesfarsit, cat dureaza duelul.
var _npc_wants_to_fire := true

func _exit_tree() -> void:
	super._exit_tree()
	_stop_duel()

func _get_player() -> Node3D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player")
	return _player

# ------------------------------------------------------- alegere random toaleta

func _candidate_toilets() -> Array:
	var found: Array = []
	for path in duel_toilets:
		var node := get_node_or_null(path)
		if node is Node3D:
			found.append(node)
	return found

## Suprascrie alegerea din ToiletNPC (care ia mereu cea mai apropiata) cu o
## alegere random dintre `duel_toilets`, ignorand-o pe cea deja ocupata.
func _pick_toilet() -> void:
	var free: Array = []
	for toilet in _candidate_toilets():
		if _is_free(toilet):
			free.append(toilet)
	if free.is_empty():
		_state = State.SEARCH
		return
	_release_toilet()
	_toilet = free[randi() % free.size()]
	if _toilet.has_method("try_reserve"):
		if not _toilet.try_reserve(self):
			_toilet = null
			_state = State.SEARCH
			return
	else:
		_toilet.set_meta(&"occupied_by", self)
	_state = State.WALK
	toilet_chosen.emit(_toilet)

# ------------------------------------------------------------------- duel pipi

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var player := _get_player()
	# Nici NPC-ul nici jucatorul nu incep sa se piseze cat timp jucatorul nu s-a asezat.
	var player_seated: bool = is_instance_valid(player) and player.has_method("is_seated") and player.is_seated()
	if _state == State.SIT and _sit_t >= 1.0 and player_seated:
		if not _dueling:
			_pee_timer += delta
			if _pee_timer >= pee_start_delay:
				_start_duel()
	else:
		_pee_timer = 0.0
		if _dueling:
			_stop_duel()
	if is_instance_valid(_pee_stream):
		# Trage pana ramane fara fuel, apoi sta AFK pana se reincarca 100%, apoi reia.
		if _dueling:
			if _npc_wants_to_fire and _fuel.value <= 0.0:
				_npc_wants_to_fire = false
			elif not _npc_wants_to_fire and _fuel.value >= PeeFuel.MAX_FUEL:
				_npc_wants_to_fire = true
		else:
			_npc_wants_to_fire = true
		# Fuel-ul decide daca chiar trage in cadrul asta (aceleasi reguli ca la player).
		_pee_stream.firing = _fuel.update(delta, _dueling and _npc_wants_to_fire)

## Aduna recursiv RID-urile tuturor PhysicsBody3D din subarborele lui `node`
## (ex: vasul de toaleta are un StaticBody3D cu coliziune pe toata mesh-ul).
func _collect_body_rids(node: Node, out: Array[RID]) -> void:
	if node is PhysicsBody3D:
		out.append((node as PhysicsBody3D).get_rid())
	for child in node.get_children():
		_collect_body_rids(child, out)

func _start_duel() -> void:
	var player := _get_player()
	if _dueling or player == null:
		return
	_dueling = true
	if _pee_stream == null:
		_pee_stream = PeeStream.new()
		_pee_stream.name = "PeeStream"
		add_child(_pee_stream)
	_pee_stream.position = pee_origin
	_pee_stream.source = self
	# Exclude coliziunea propriei toalete: originea jetului e chiar langa/in
	# vas (NPC-ul sta pe el), altfel primul strop se lovea instant de vas si
	# jetul ramanea "blocat in wc" (sau sarea aiurea din cauza normalei de acolo).
	var exclude: Array[RID] = []
	if is_instance_valid(_toilet):
		_collect_body_rids(_toilet, exclude)
	_pee_stream.extra_exclude = exclude
	_pee_stream.aim_target = player
	_pee_stream.aim_target_accuracy = hit_chance
	if player.has_method("begin_auto_duel"):
		player.begin_auto_duel(self)

func _stop_duel() -> void:
	if not _dueling:
		return
	_dueling = false
	if is_instance_valid(_pee_stream):
		_pee_stream.firing = false
		_pee_stream.stop()
	var player := _get_player()
	if player != null and player.has_method("end_auto_duel"):
		player.end_auto_duel()
