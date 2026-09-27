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
## HP-ul acestui adversar de duel. La 0, se reincarca automat la maxim -
## e un duel de antrenament (bucla nesfarsita), nu un meci cu game-over.
@export var max_health := 300.0

var _pee_stream: Node3D
var _player: Node3D
var _pee_timer := 0.0
var _dueling := false
## Rezerva invizibila a NPC-ului; aceleasi numere ca la player (vezi PeeFuel).
var _fuel := PeeFuel.new()
## Cat timp e true, NPC-ul incearca sa traga; cand ramane fara fuel se opreste
## (AFK) pana se reincarca 100%, apoi reincepe - la nesfarsit, cat dureaza duelul.
var _npc_wants_to_fire := true
## HP-ul adversarului (vezi PeeDamage: 1 HP la fiecare 0.1s de expunere continua).
var _damage: PeeDamage
var _hp_label: Label3D
var _hp_bar_bg: MeshInstance3D
var _hp_bar_fill: MeshInstance3D
var _hp_bar_value: Label3D
var _challenge_hidden := false
var _challenge_hidden_toilet: Node3D = null
var _defeated := false
var _respawn_transform := Transform3D.IDENTITY
const HP_BAR_WIDTH := 2.8
const HP_BAR_HEIGHT := 0.28

func _ready() -> void:
	super._ready()
	_respawn_transform = global_transform
	add_to_group(&"practice_duel_enemy")
	_damage = PeeDamage.new(max_health)
	_hp_label = Label3D.new()
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.font_size = 34
	_hp_label.outline_size = 8
	_hp_label.position = Vector3(0.0, 1.9, 0.0)
	_hp_label.modulate = Color(1, 1, 1)
	add_child(_hp_label)
	
	_hp_bar_bg = MeshInstance3D.new()
	_hp_bar_bg.name = "HPBarBackground"
	_hp_bar_bg.position = Vector3(0.0, 2.25, 0.0)
	_hp_bar_bg.mesh = _make_hp_bar_mesh()
	_hp_bar_bg.material_override = _make_hp_bar_material(Color(0.08, 0.035, 0.12, 0.95))
	add_child(_hp_bar_bg)
	
	_hp_bar_fill = MeshInstance3D.new()
	_hp_bar_fill.name = "HPBarFill"
	_hp_bar_fill.position = Vector3(-HP_BAR_WIDTH * 0.5, 2.25, 0.01)
	_hp_bar_fill.mesh = _make_hp_bar_mesh()
	_hp_bar_fill.material_override = _make_hp_bar_material(Color(0.70, 0.22, 0.95, 1.0))
	add_child(_hp_bar_fill)
	
	_hp_bar_value = Label3D.new()
	_hp_bar_value.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar_value.font_size = 18
	_hp_bar_value.outline_size = 5
	_hp_bar_value.position = Vector3(0.0, 2.25, 0.04)
	_hp_bar_value.modulate = Color(1, 1, 1)
	_hp_bar_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_bar_value.render_priority = 20
	add_child(_hp_bar_value)
	_update_hp_label()

func _make_hp_bar_mesh() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	return quad

func _make_hp_bar_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _update_hp_label() -> void:
	var current := int(ceil(_damage.health))
	var total := int(max_health)
	_hp_label.text = "HP: %d/%d" % [current, total]
	_hp_bar_value.text = "%d / %d" % [current, total]
	var fraction := clampf(_damage.health / max_health, 0.0, 1.0)
	_hp_bar_fill.scale.x = fraction
	_hp_bar_fill.position.x = -HP_BAR_WIDTH * 0.5 + (HP_BAR_WIDTH * fraction) * 0.5

## Hide the opponent and the toilet it is currently using while the local
## target challenge is running. The physics/collisions of the toilet remain
## unchanged; this is intentionally a visual hide only.
func set_challenge_hidden(hidden: bool) -> void:
	_challenge_hidden = hidden
	if hidden:
		_stop_duel()
		if is_instance_valid(_toilet):
			_challenge_hidden_toilet = _toilet
			_challenge_hidden_toilet.visible = false
		visible = false
		set_physics_process(false)
	else:
		if _defeated:
			return
		if is_instance_valid(_challenge_hidden_toilet):
			_challenge_hidden_toilet.visible = true
		_challenge_hidden_toilet = null
		visible = true
		set_physics_process(true)

func is_defeated() -> bool:
	return _defeated

## Respawn the opponent only from the seated practice position.
func respawn_for_practice() -> bool:
	if not _defeated or _challenge_hidden:
		return false
	var player := _get_player()
	if not is_instance_valid(player) or not player.has_method("is_seated") or not player.is_seated():
		return false
	_defeated = false
	_damage.reset()
	_update_hp_label()
	_release_toilet()
	_toilet = null
	global_transform = _respawn_transform
	velocity = Vector3.ZERO
	_pee_timer = 0.0
	_dueling = false
	_npc_wants_to_fire = true
	visible = true
	set_physics_process(true)
	_state = State.SEARCH
	_pick_toilet()
	return true

func _defeat() -> void:
	if _defeated:
		return
	_defeated = true
	_stop_duel()
	_release_toilet()
	_toilet = null
	velocity = Vector3.ZERO
	visible = false
	set_physics_process(false)

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
	if _challenge_hidden:
		return
	super._physics_process(delta)
	_damage.tick(delta)
	_update_hp_label()
	if _damage.is_dead():
		_defeat()
		return
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

## Cheama receive_pee_hit(source, point, normal) pee_stream-ul care te
## nimereste (vezi pee_stream.gd si Player3D.receive_pee_hit pentru simetrie):
## doar inregistreaza lovitura, damage-ul efectiv se calculeaza in
## _physics_process prin PeeDamage (1 HP la fiecare 0.1s de expunere continua).
func receive_pee_hit(_source: Node, _point: Vector3, _normal: Vector3) -> void:
	_damage.register_hit()
