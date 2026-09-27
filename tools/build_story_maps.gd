extends SceneTree

## Offline authoring tool. Bakes editable nodes into .tscn; not run by the game.
## Explicit regeneration overwrites ONLY the two generated story-map scenes.
const UI = preload("res://ui/session_ui.tscn")
const TOILET = preload("res://Scenes/Toilet.tscn")
const WEATHERED = preload("res://maps/shared/weathered.gdshader")

var scene: Node3D
var geometry: Node3D
var decor: Node3D
var rng := RandomNumberGenerator.new()
var serial := 0
var materials: Dictionary = {}
var blob_mesh: SphereMesh
var world_script: Script

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	if not "--rebuild-story-maps" in OS.get_cmdline_user_args():
		push_error("Pass -- --rebuild-story-maps to explicitly regenerate these scenes.")
		quit(1)
		return
	# Autoload identifiers exist only after the custom SceneTree initializes.
	world_script = load("res://systems/world_session.gd")
	if not world_script.can_instantiate():
		push_error("World session script did not compile; maps were not written.")
		quit(1)
		return
	blob_mesh = SphereMesh.new()
	blob_mesh.radial_segments = 7
	blob_mesh.rings = 4
	blob_mesh.radius = 1.0
	blob_mesh.height = 2.0
	make_materials()
	build_train()
	if not save_map("res://maps/cfr_train/cfr_train.tscn"):
		quit(1)
		return
	build_school()
	if not save_map("res://maps/vlad_tepes/vlad_tepes.tscn"):
		quit(1)
		return
	print("STORY_MAPS_BUILT: CFR carriage and fictional Vlad Tepes school")
	quit()

func attach(node: Node, parent: Node, label: String) -> void:
	node.name = label
	parent.add_child(node)
	node.owner = scene

func group(label: String) -> Node3D:
	var node := Node3D.new()
	attach(node, scene, label)
	return node

func surface(key: String, color: Color, dirt: float, tiles := 0.0) -> void:
	var material := ShaderMaterial.new()
	material.shader = WEATHERED
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("dirt_color", Color(0.075, 0.054, 0.023))
	material.set_shader_parameter("dirt_amount", dirt)
	material.set_shader_parameter("tile_size", tiles)
	materials[key] = material

func plain(key: String, color: Color, emission := 0.0) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	if emission > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	materials[key] = material

func make_materials() -> void:
	surface("ivory", Color("a79872"), 0.83)
	surface("blue", Color("284351"), 0.8)
	surface("floor", Color("53524a"), 0.86, 0.5)
	surface("ceiling", Color("827d68"), 0.84)
	surface("seat", Color("754736"), 0.75)
	surface("rust", Color("63402c"), 0.65)
	surface("plaster", Color("b0a18d"), 0.46)
	surface("green", Color("48665b"), 0.5)
	surface("wood", Color("816348"), 0.7)
	surface("concrete", Color("73776d"), 0.55, 1.5)
	surface("brick", Color("915c44"), 0.65)
	plain("metal", Color("29383b"))
	plain("dark", Color("101c23"))
	plain("glass", Color("284354"), 0.35)
	plain("chalk", Color("c8c7aa"))
	plain("paper", Color("b4a77f"))
	plain("red", Color("962e25"))
	plain("lamp", Color("ffd28c"), 2.2)
	plain("cold_lamp", Color("b2d5b9"), 1.8)
	plain("sludge", Color("38200c"))
	plain("sludge_wet", Color("574014"))
	plain("sludge_glow", Color("96742d"), 0.65)

func begin_map(label: String, title: String, objective: String, spawn: Vector3, seed_value: int) -> void:
	rng.seed = seed_value
	serial = 0
	scene = Node3D.new()
	scene.name = label
	scene.set_script(world_script)
	scene.set("map_title", title)
	scene.set("map_objective", objective)
	geometry = group("Architecture")
	decor = group("SetDressing")
	var player_spawn := Marker3D.new()
	player_spawn.position = spawn
	attach(player_spawn, scene, "PlayerSpawn")
	attach(UI.instantiate(), scene, "SessionUI")

func box(label: String, at: Vector3, size: Vector3, material: String, solid := true, parent: Node3D = null) -> Node3D:
	serial += 1
	if parent == null:
		parent = geometry if solid else decor
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.position = at
	attach(node, parent, "%s_%03d" % [label, serial])
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	shape.material = materials[material]
	mesh.mesh = shape
	attach(mesh, node, "Mesh")
	if solid:
		var collider := CollisionShape3D.new()
		var volume := BoxShape3D.new()
		volume.size = size
		collider.shape = volume
		attach(collider, node, "Collision")
	return node

func label3d(text: String, at: Vector3, size := 40, yaw := 0.0, color := Color("d7caa7")) -> Label3D:
	serial += 1
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.rotation.y = yaw
	label.font_size = size
	label.pixel_size = 0.007
	label.outline_size = 3
	label.modulate = color
	label.no_depth_test = false
	attach(label, decor, "Lettering_%03d" % serial)
	return label

func light_at(label: String, at: Vector3, color: Color, energy: float, reach: float) -> void:
	serial += 1
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = false
	attach(lamp, decor, "%s_%03d" % [label, serial])

func environment(night: bool) -> void:
	var node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111e2a") if night else Color("6e838b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6f8590") if night else Color("a6b5b6")
	env.ambient_light_energy = 0.3 if night else 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	node.environment = env
	attach(node, scene, "WorldEnvironment")
	if not night:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-52, -30, 0)
		sun.light_color = Color("cfdbdf")
		sun.light_energy = 0.8
		sun.shadow_enabled = true
		attach(sun, scene, "OvercastSun")

func stain(at: Vector3, normal: Vector3, radius: float, glowing := false) -> void:
	var patch := Node3D.new()
	serial += 1
	attach(patch, decor, "EmissiveSludge_%03d" % serial if glowing else "Sludge_%03d" % serial)
	patch.position = at
	patch.quaternion = Quaternion(Vector3.UP, normal)
	for i in 3:
		var mesh := MeshInstance3D.new()
		mesh.mesh = blob_mesh
		mesh.material_override = materials["sludge_glow" if glowing and i > 0 else "sludge"]
		mesh.position = Vector3(rng.randf_range(-radius * 0.4, radius * 0.4), 0, rng.randf_range(-radius * 0.4, radius * 0.4))
		mesh.scale = Vector3(radius * rng.randf_range(0.65, 1.1), 0.013 + i * 0.009, radius * rng.randf_range(0.35, 0.9))
		mesh.rotation.y = rng.randf_range(0, TAU)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		attach(mesh, patch, "Smear%d" % i)

func rubbish(at: Vector3, count: int, extent: Vector2) -> void:
	for i in count:
		var position := at + Vector3(rng.randf_range(-extent.x, extent.x), 0, rng.randf_range(-extent.y, extent.y))
		var paper := box("Litter", position, Vector3(0.21, 0.014, 0.3), "paper" if i % 3 else "rust", false)
		paper.rotation.y = rng.randf_range(0, TAU)

func toilet(label: String, at: Vector3, yaw: float) -> void:
	var instance := TOILET.instantiate() as Node3D
	instance.position = at
	instance.rotation.y = yaw
	attach(instance, scene, label)

func story_marker(label: String, at: Vector3, role: String) -> void:
	var marker := Marker3D.new()
	marker.position = at
	marker.set_meta("story_role", role)
	attach(marker, scene, label)

func build_train() -> void:
	begin_map("CFRTrain", "CFR / ULTIMUL VAGON", "Explore the carriage · E: use either toilet · ESC: return to hub", Vector3(0, 0.1, 10.5), 13013)
	environment(true)
	box("CarriageFloor", Vector3(0, -0.15, 0), Vector3(6.3, 0.3, 25), "floor")
	box("Ceiling", Vector3(0, 3.5, 0), Vector3(6.3, 0.2, 25), "ceiling")
	for side in [-1.0, 1.0]:
		box("BlueWainscot", Vector3(side * 3, 0.5, 0), Vector3(0.2, 1, 25), "blue")
		box("UpperPanel", Vector3(side * 3, 2.95, 0), Vector3(0.2, 1.1, 25), "ivory")
		box("WindowSill", Vector3(side * 2.91, 1.03, 0), Vector3(0.27, 0.1, 25), "rust")
		for bay in 8:
			var z := -10.8 + bay * 3.1
			box("Window", Vector3(side * 3.02, 1.75, z), Vector3(0.08, 1.4, 2.6), "glass")
			box("WindowPost", Vector3(side * 3, 1.75, z + 1.45), Vector3(0.25, 1.5, 0.5), "ivory")
			for end in [-1.0, 1.0]:
				box("WindowFrame", Vector3(side * 2.88, 1.75, z + end * 1.31), Vector3(0.12, 1.45, 0.065), "metal", false)
		for z in [2.5, 5.5, 8.5]:
			box("Bench", Vector3(side * 2.02, 0.52, z), Vector3(1.3, 0.25, 2.25), "seat")
			box("BenchBack", Vector3(side * 2.61, 1.04, z), Vector3(0.19, 0.9, 2.3), "seat")
			box("BenchBase", Vector3(side * 2.02, 0.22, z), Vector3(1.07, 0.44, 2), "metal")
			box("LuggageRack", Vector3(side * 2.42, 2.52, z), Vector3(0.85, 0.06, 2.4), "rust", false)
			for rail in 6:
				box("RackBar", Vector3(side * 2.42, 2.66, z - 1.05 + rail * 0.4), Vector3(0.85, 0.035, 0.035), "metal", false)
	for z in [-12.4, 12.4]:
		box("EndWall", Vector3(0, 1.75, z), Vector3(6.2, 3.5, 0.2), "blue")
		box("EndDoor", Vector3(0, 1.25, z - signf(z) * 0.12), Vector3(1.45, 2.5, 0.09), "metal", false)
		box("DoorGlass", Vector3(0, 1.65, z - signf(z) * 0.18), Vector3(1.05, 0.9, 0.035), "glass", false)
	box("ToiletBayLeft", Vector3(-2.0, 1.4, -3.5), Vector3(1.8, 2.8, 0.16), "ivory")
	box("ToiletBayRight", Vector3(2.0, 1.4, -3.5), Vector3(1.8, 2.8, 0.16), "ivory")
	box("ToiletBayHeader", Vector3(0, 3.06, -3.5), Vector3(6, 0.68, 0.2), "blue")
	label3d("WC  /  FAȚĂ ÎN FAȚĂ", Vector3(0, 3.05, -3.37), 35)
	label3d("CFR  •  CLASA A III-A", Vector3(0, 2.85, -12.25), 39)
	label3d("ÎNTÂRZIERE: ∞", Vector3(0, 1.8, -12.16), 25, 0, Color("d4a557"))
	label3d("NU ÎNTREBA DE MIROS", Vector3(-1.95, 1.9, -3.38), 20, 0.0, Color("452215"))
	label3d("ULTIMA OPRIRE", Vector3(2, 1.9, -3.38), 21, 0, Color("452215"))
	toilet("ToiletLeft", Vector3(-1.9, 0.258, -7.0), PI / 2)
	toilet("ToiletRight", Vector3(1.9, 0.258, -7.0), -PI / 2)
	story_marker("GepetoSpawn", Vector3(-1.8, 0.05, -10.5), "Gepeto or a fictional passenger; no NPC or story logic assigned yet")
	story_marker("DuelCenter", Vector3(0, 0.05, -7), "Future training/encounter center")
	for z in [-10.0, -5.0, 1.0, 7.0]:
		box("DeadFluorescent", Vector3(0, 3.34, z), Vector3(0.35, 0.08, 1.4), "metal", false)
	# Brown smears physically cover walls, window panes, ceiling and floor.
	for side in [-1.0, 1.0]:
		for i in 48:
			stain(Vector3(side * 2.875, rng.randf_range(0.2, 3.22), rng.randf_range(-12, 12)), Vector3(-side, 0, 0), rng.randf_range(0.15, 0.62), i % 7 == 0)
	for i in 42:
		stain(Vector3(rng.randf_range(-2.8, 2.8), 0.025, rng.randf_range(-12, 12)), Vector3.UP, rng.randf_range(0.12, 0.48))
	for i in 30:
		stain(Vector3(rng.randf_range(-2.6, 2.6), 3.385, rng.randf_range(-12, 12)), Vector3.DOWN, rng.randf_range(0.2, 0.6), i % 6 == 0)
	for z in [-10.0, -5.0, 1.0, 7.0]:
		for side in [-1.0, 1.0]:
			stain(Vector3(side * 2.875, 2.65, z), Vector3(-side, 0, 0), 0.48, true)
			light_at("SludgeLight", Vector3(side * 2.55, 2.45, z), Color("d5b252"), 1.0, 4.6)
	light_at("BlueWindowBounce", Vector3(0, 2.8, -7), Color("819db2"), 0.7, 4.5)
	for at in [Vector3(-2.6, 0.08, -8.8), Vector3(2.5, 0.08, -5.2), Vector3(-2.3, 0.08, 0.1)]:
		for tier in 4:
			var lump := MeshInstance3D.new()
			lump.mesh = blob_mesh
			lump.material_override = materials["sludge_wet"]
			lump.position = at + Vector3(sin(tier * 2.0) * 0.07, tier * 0.095, 0)
			lump.scale = Vector3(0.29 - tier * 0.05, 0.09, 0.24 - tier * 0.04)
			serial += 1
			attach(lump, decor, "FloorPile_%03d" % serial)
	rubbish(Vector3(0, 0.035, 0), 40, Vector2(2.65, 11.5))

func desk(at: Vector3, tipped := false) -> void:
	var desk_root := Node3D.new()
	serial += 1
	attach(desk_root, decor, "SchoolDesk_%03d" % serial)
	desk_root.position = at
	box("Desktop", Vector3(0, 0.82, 0), Vector3(1.4, 0.09, 0.62), "wood", true, desk_root)
	for side in [-1.0, 1.0]:
		box("DeskLeg", Vector3(side * 0.56, 0.4, 0), Vector3(0.055, 0.8, 0.5), "metal", true, desk_root)
	box("ChairSeat", Vector3(0, 0.46, 0.72), Vector3(0.58, 0.08, 0.54), "wood", true, desk_root)
	box("ChairBack", Vector3(0, 0.79, 0.96), Vector3(0.58, 0.55, 0.07), "green", true, desk_root)
	box("ChairBase", Vector3(0, 0.21, 0.72), Vector3(0.43, 0.42, 0.43), "metal", true, desk_root)
	if tipped:
		desk_root.rotation.z = -1.1
		desk_root.position.y = 0.65

func school_window(at: Vector3) -> void:
	box("WindowInset", at, Vector3(0.12, 1.8, 2.2), "glass")
	for z in [-1.12, 0.0, 1.12]:
		box("WindowMullion", at + Vector3(0.12, 0, z), Vector3(0.18, 1.95, 0.065), "paper", false)
	for y in [-0.93, 0.93]:
		box("WindowLintel", at + Vector3(0.12, y, 0), Vector3(0.2, 0.07, 2.35), "paper", false)

func facade_window(at: Vector3, boarded := false) -> void:
	box("FacadeWindowFrame", at, Vector3(1.9, 1.85, 0.12), "paper", false)
	box("FacadeWindowGlass", at + Vector3(0, 0, 0.08), Vector3(1.68, 1.64, 0.04), "glass", false)
	box("FacadeMullion", at + Vector3(0, 0, 0.12), Vector3(0.07, 1.7, 0.06), "paper", false)
	box("FacadeCrossbar", at + Vector3(0, 0.25, 0.12), Vector3(1.75, 0.06, 0.06), "paper", false)
	box("FacadeSill", at + Vector3(0, -0.98, 0.08), Vector3(2.1, 0.12, 0.28), "concrete", false)
	if boarded:
		for y in [-0.4, 0.2]:
			var plank := box("BrokenWindowBoard", at + Vector3(0, y, 0.19), Vector3(2.05, 0.18, 0.06), "wood", false)
			plank.rotation.z = 0.18 if y < 0 else -0.22

func build_school() -> void:
	begin_map("VladTepes", "VLAD ȚEPEȘ / DUPĂ ORE", "Explore the corridor, classroom and WC · E: interact · ESC: return to hub", Vector3(0, 0.1, 20), 198913)
	environment(false)
	box("Courtyard", Vector3(0, -0.18, 7), Vector3(29, 0.36, 36), "concrete")
	box("SchoolFloor", Vector3(0, -0.08, -1), Vector3(24, 0.16, 18), "floor")
	box("SchoolRoof", Vector3(0, 3.75, -1), Vector3(24.5, 0.3, 18.5), "concrete")
	# Upper story is a closed scenic shell, not an unfinished accessible floor.
	box("UpperStory", Vector3(0, 5.65, -1), Vector3(24, 3.5, 18), "plaster")
	box("UpperRoof", Vector3(0, 7.48, -1), Vector3(24.5, 0.2, 18.5), "concrete")
	box("FacadeBelt", Vector3(0, 3.85, 8.19), Vector3(24, 0.2, 0.18), "green", false)
	for x in [-9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0]:
		facade_window(Vector3(x, 5.55, 8.17), x == -6.0 or x == 9.0)
	for x in [-9.0, -5.0, 5.0, 9.0]:
		facade_window(Vector3(x, 2.12, 8.2), x == 5.0)
	for x in [-12.0, 12.0]:
		box("OuterWall", Vector3(x, 1.8, -1), Vector3(0.3, 3.6, 18), "plaster")
		box("DampBase", Vector3(x - signf(x) * 0.17, 0.65, -1), Vector3(0.05, 1.3, 18), "green", false)
	box("BackWall", Vector3(0, 1.8, -10), Vector3(24, 3.6, 0.3), "plaster")
	for x in [-7.0, 7.0]:
		box("Facade", Vector3(x, 1.8, 8), Vector3(10, 3.6, 0.3), "plaster")
		box("FacadeBase", Vector3(x, 0.6, 8.18), Vector3(10, 1.2, 0.12), "green", false)
	box("EntryHeader", Vector3(0, 3.15, 8), Vector3(4, 0.9, 0.3), "plaster")
	box("SchoolSign", Vector3(0, 3.27, 8.22), Vector3(7.6, 0.65, 0.12), "blue", false)
	label3d("LICEUL VLAD ȚEPEȘ", Vector3(0, 3.28, 8.3), 64)
	box("EntryCanopy", Vector3(0, 2.95, 8.8), Vector3(4.2, 0.12, 1.5), "rust", false)
	label3d("ARIPĂ ÎNCHISĂ  /  1989", Vector3(0, 2.64, 8.22), 20, 0, Color("555442"))
	# A central corridor with real 2m doorways into the classroom and WC.
	for side in [-1.0, 1.0]:
		for segment in [Vector3(3.75, 8.5, 0), Vector3(-6.25, 7.5, 0)]:
			box("CorridorWall", Vector3(side * 2, 1.8, segment.x), Vector3(0.2, 3.6, segment.y), "plaster")
			box("CorridorPaint", Vector3(side * 1.87, 0.66, segment.x), Vector3(0.06, 1.32, segment.y), "green", false)
		box("DoorHeader", Vector3(side * 2, 3.18, -1.5), Vector3(0.25, 0.85, 2.0), "green")
		for z in [-2.53, -0.47]:
			box("DoorJamb", Vector3(side * 2, 1.4, z), Vector3(0.3, 2.8, 0.09), "wood", false)
		for z in [2.0, 5.2]:
			box("NoticeBoard", Vector3(side * 1.84, 1.9, z), Vector3(0.08, 1.0, 1.9), "wood", false)
			for i in 4:
				box("Notice", Vector3(side * 1.78, 1.75 + (i % 2) * 0.28, z - 0.55 + (i / 2) * 0.6), Vector3(0.02, 0.22, 0.42), "paper", false)
	label3d("XII B", Vector3(-1.83, 2.85, -1.5), 32, PI / 2)
	label3d("WC", Vector3(1.83, 2.85, -1.5), 36, -PI / 2)
	box("EndNotice", Vector3(0, 1.9, -9.8), Vector3(2.2, 1.15, 0.06), "green", false)
	label3d("ABSENȚELE RĂMÂN.\nTU?", Vector3(0, 1.9, -9.73), 33, 0, Color("d6c792"))
	# Classroom occupies the west wing, with a chalkboard and disordered desks.
	box("ChalkboardFrame", Vector3(-7, 1.9, -9.77), Vector3(6.2, 1.5, 0.12), "wood", false)
	box("Chalkboard", Vector3(-7, 1.9, -9.68), Vector3(5.95, 1.3, 0.04), "green", false)
	label3d("TEZĂ: CUM AM AJUNS AICI?\nEREC A FOST AICI", Vector3(-7, 1.95, -9.63), 38)
	for row in 3:
		for column in 3:
			desk(Vector3(-10 + column * 2.6, 0, -6 + row * 3.3), row == 2 and column == 0)
	box("TeacherDesk", Vector3(-7, 0.75, -8.2), Vector3(2.1, 0.13, 0.85), "wood")
	box("TeacherBase", Vector3(-7, 0.35, -8.2), Vector3(1.9, 0.7, 0.65), "green")
	for z in [-6.5, -2.5, 1.5, 5.5]:
		school_window(Vector3(-11.78, 2.0, z))
		box("Radiator", Vector3(-11.65, 0.52, z), Vector3(0.25, 0.8, 1.8), "rust")
	# East wing: peeling washroom, three open cubicles and a broken sink bank.
	for z in [-5.5, -1.5, 2.5]:
		box("CubicleDivider", Vector3(9.4, 1.05, z - 1.5), Vector3(4.9, 2.1, 0.1), "green")
		toilet("SchoolToilet%d" % int(z + 6), Vector3(10.85, 0.258, z), -PI / 2)
		box("CisternPipe", Vector3(11.64, 1.0, z), Vector3(0.065, 1.5, 0.065), "rust", false)
		stain(Vector3(11.81, 1.5, z), Vector3.LEFT, 0.6)
	for z in [3.8, 5.6]:
		box("Sink", Vector3(3.15, 0.85, z), Vector3(1, 0.25, 0.85), "ivory")
		box("SinkBasin", Vector3(3.15, 0.985, z), Vector3(0.65, 0.018, 0.56), "dark", false)
		box("Mirror", Vector3(2.16, 1.65, z), Vector3(0.04, 0.9, 0.75), "metal", false)
	label3d("NU CURGE APA.\nCURGE ANUL.", Vector3(6, 1.9, -9.77), 30, 0, Color("633523"))
	# Broken plaster patches, exposed brick and debris; keep walking paths clear.
	for i in 35:
		var x := -11.8 if i % 2 == 0 else 11.8
		stain(Vector3(x, rng.randf_range(0.3, 3.3), rng.randf_range(-9.5, 7.5)), Vector3(-signf(x), 0, 0), rng.randf_range(0.15, 0.45))
	for i in 10:
		var x := -10.5 + i * 2.3
		if absf(x) < 2.7:
			continue
		box("ExposedBrick", Vector3(x, 0.6 + (i % 3) * 0.2, 8.26), Vector3(1.25, 0.5, 0.06), "brick", false)
	for i in 24:
		stain(Vector3(rng.randf_range(-11, 11), 0.018, rng.randf_range(-9, 7)), Vector3.UP, rng.randf_range(0.2, 0.55))
	rubbish(Vector3(0, 0.04, -1), 60, Vector2(11.5, 8.5))
	# Courtyard with boundary fencing, faded basketball markings and benches.
	for x in [-14.0, 14.0]:
		box("BoundaryPlinth", Vector3(x, 0.25, 7), Vector3(0.25, 0.5, 36), "concrete")
		for z in range(-10, 26, 2):
			box("FencePost", Vector3(x, 1.2, z), Vector3(0.06, 2.4, 0.06), "rust", false)
		# Invisible boundary uses a proper collision, independent of decorative bars.
		var barrier := box("FenceCollision", Vector3(x, 1.2, 7), Vector3(0.15, 2.4, 36), "metal")
		barrier.get_node("Mesh").visible = false
		for y in [0.8, 1.8]:
			box("FenceRail", Vector3(x, y, 7), Vector3(0.06, 0.04, 36), "rust", false)
	box("BackBoundary", Vector3(0, 1, -10.8), Vector3(28, 2, 0.2), "concrete")
	box("FrontBoundary", Vector3(0, 1.0, 25), Vector3(28, 2, 0.2), "concrete")
	for x in [-8.0, 8.0]:
		box("CourtLine", Vector3(x, 0.012, 16), Vector3(0.07, 0.012, 12), "chalk", false)
		box("YardBench", Vector3(x, 0.48, 10.5), Vector3(3.5, 0.16, 0.65), "wood")
		for dx in [-1.25, 1.25]:
			box("BenchFoot", Vector3(x + dx, 0.2, 10.5), Vector3(0.18, 0.4, 0.5), "metal")
	for z in [10.0, 22.0]:
		box("CourtLine", Vector3(0, 0.012, z), Vector3(16, 0.012, 0.07), "chalk", false)
	box("BasketPost", Vector3(10.5, 1.6, 17), Vector3(0.13, 3.2, 0.13), "rust")
	box("BasketBoard", Vector3(10.4, 3.05, 17), Vector3(0.12, 1.0, 1.65), "paper", false)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.24
	torus.outer_radius = 0.28
	torus.rings = 12
	torus.ring_segments = 6
	torus.material = materials["rust"]
	ring.mesh = torus
	ring.position = Vector3(10, 2.75, 17)
	attach(ring, decor, "BentBasketRing")
	for z in [-7.0, -1.0, 5.0]:
		box("CorridorLamp", Vector3(0, 3.52, z), Vector3(0.25, 0.08, 1.3), "cold_lamp", false)
		light_at("CorridorLight", Vector3(0, 2.95, z), Color("bccab0"), 1.0, 4.0)
	for x in [-7.0, 7.0]:
		for z in [-5.0, 3.0]:
			light_at("RoomLight", Vector3(x, 3.0, z), Color("b3c4bd"), 1.0, 6.5)
	story_marker("ErecSpawn", Vector3(-4.0, 0.1, 5.5), "Erec's future story encounter; no character model assigned")
	story_marker("ClassroomEncounter", Vector3(-7.0, 0.1, -3.0), "Future mission trigger")

func save_map(path: String) -> bool:
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Cannot create map directory: " + directory)
		return false
	var packed := PackedScene.new()
	var error := packed.pack(scene)
	if error == OK:
		error = ResourceSaver.save(packed, path)
	scene.free()
	if error != OK:
		push_error("Map bake failed: %s (%s)" % [path, error])
		return false
	return true
