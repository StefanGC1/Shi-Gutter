extends SceneTree

# Run after importing the project:
# godot --headless --path . --script res://tests/hub_flow_test.gd
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count := 4) -> void:
	for frame in count:
		await physics_frame
	await process_frame
	# Scene changes are applied at the end of a process frame.
	await process_frame

func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func check_world(expected_scene: String, expected_speed: float) -> void:
	var player: Player3D = current_scene.new_player
	check(get_nodes_in_group("player").size() == 1, "World must have exactly one player")
	var player_count := 0
	for body in current_scene.find_children("*", "CharacterBody3D", true, false):
		if body is Player3D:
			player_count += 1
	check(player_count == 1, "World contains a second player controller")
	check(player.scene_file_path == expected_scene, "Selected character was not preserved")
	check(is_equal_approx(player.speed, expected_speed), "Character speed changed")
	var cameras := current_scene.find_children("*", "Camera3D", true, false)
	check(cameras.size() == 1, "World must contain exactly one player camera")
	check(root.get_camera_3d() == player.camera, "Selected character must own the active camera")
	var spawn: Marker3D = current_scene.get_node("PlayerSpawn")
	check(player.global_position.distance_to(spawn.global_position) < 0.2, "Player did not start at PlayerSpawn")
	check(player.global_basis.is_equal_approx(spawn.global_basis), "Player must use the spawn orientation")
	player.global_position = Vector3(20, -20, 20)
	await frames()
	check(player.global_position.distance_to(spawn.global_position) < 0.2, "Respawn must return to PlayerSpawn")

func open_character_station() -> void:
	var hub := current_scene
	var player: Player3D = hub.new_player
	player.global_position = Vector3(-3, 0.05, 10)
	player.rotation = Vector3.ZERO
	await frames(8)
	await press("interact")
	check(current_scene == hub and player.interactor.target == null, "Character station must reject distant interaction")
	player.global_position.z = 8
	await frames(8)
	check(current_scene == hub, "Proximity must not automatically open character selection")
	check(player.interactor.target == hub.get_node("CharacterStation"), "Character station is not reachable")
	check(hub.ui.get_node("Root/HUD/Prompt").text == "[E]  Alege personajul", "Character station needs its own interaction prompt")
	await press("ui_cancel")
	await press("interact")
	check(current_scene == hub and hub.mode == hub.Mode.PAUSED, "Paused interaction must not open the selector")
	await press("ui_cancel")
	await press("interact")
	check(current_scene.name == &"CharacterSelectionScreen", "Character station must open the selector with E")
	check(get_nodes_in_group("player").is_empty(), "Character station transition left a background player")

func run() -> void:
	check(change_scene_to_file("res://menus/main_menu/main_menu.tscn") == OK, "Main menu failed to load")
	await frames()
	current_scene.get_node("Center/MenuPanel/Margin/VBox/Singleplayer").pressed.emit()
	await frames(12)
	check(current_scene.name == &"CharacterSelectionScreen", "Singleplayer must open the selector")
	check(get_nodes_in_group("player").is_empty(), "Selector must not keep a background player")
	await press("ui_cancel")
	check(current_scene.name == &"MainMenu", "Escape from selector must return to main menu")
	current_scene.get_node("Center/MenuPanel/Margin/VBox/Singleplayer").pressed.emit()
	await frames()
	var selector := current_scene
	selector.get_node("HBoxContainer/ButtonGreen").pressed.emit()
	# A second click in the same frame must not change the chosen character.
	selector.get_node("HBoxContainer/ButtonBlue").pressed.emit()
	await frames(12)
	var hub := current_scene
	check(hub.name == &"Hub", "Character selection must open the hub")
	await check_world("res://actors/player/player_green_man.tscn", 5.0)
	var player := hub.get_node("Player3D") as CharacterBody3D
	check(get_nodes_in_group("player").size() == 1, "Hub must have exactly one player")
	check(player is GreenMan, "Initial selection must use the green character controller")
	check(not player.has_node("Character/AnimationSources"), "Legacy Kenney animation sources remain")
	check(player.animation_player.has_animation("StatToaleta"), "Seated animation must be preserved")
	check(player.camera.current, "First-person camera is not active")
	check(player.camera.global_position.y - player.global_position.y > 1.5, "Camera must be at eye height")
	check(player.model.global_basis.z.normalized().dot(-player.camera.global_basis.z) > 0.99, "Model face and camera must point in the same direction")
	var mesh := player.model.find_child("Torso", true, false) as MeshInstance3D
	check(mesh != null and mesh.material_override == null, "Character must keep its original materials")
	check((mesh.layers & player.camera.cull_mask) == 0, "Local camera must not clip into the head")

	# Traverse from spawn to the restaurant using actual physics/input.
	Input.action_press("move_forward")
	await frames(200)
	check(player.animation_player.current_animation == "locomotion/walk", "Sustained movement must keep the walk animation playing")
	Input.action_release("move_forward")
	await frames(20)
	check(player.global_position.z < -6.5, "Spawn-to-restaurant walking route is blocked")
	check(hub.mode == hub.Mode.PLAYING, "Proximity must not auto-open the menu")
	player.global_position = Vector3(0, 0.05, -6)
	await frames(8)
	player.interactor.refresh_target()
	check(player.interactor.target == null, "Terminal should not be usable from too far away")
	await press("interact")
	check(hub.mode == hub.Mode.PLAYING, "E outside interaction range should do nothing")
	player.global_position = Vector3(0, 0.05, -7.9)
	await frames(8)
	player.interactor.refresh_target()
	check(player.interactor.target == hub.get_node("MatchStation"), "Terminal must be detected nearby")
	player.rotation.y = PI
	await frames()
	check(player.interactor.target == null, "Looking away must clear the target")
	player.rotation.y = 0.0
	await frames()

	# An actual physics wall must block the ray, even if the terminal is in range.
	var blocker := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 3, 0.2)
	collider.shape = shape
	blocker.add_child(collider)
	hub.add_child(blocker)
	blocker.position = Vector3(0, 1.5, -9)
	await frames()
	check(player.interactor.target == null, "Interaction must not pass through walls")
	await press("interact")
	check(hub.mode == hub.Mode.PLAYING, "Occluded terminal must not open")
	blocker.queue_free()
	await frames()

	await press("interact")
	check(hub.mode == hub.Mode.MATCH_MENU, "E should open the match menu")
	check(not player.controls_enabled, "Match menu must disable movement")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Menu must release the mouse")
	await press("select_character")
	check(current_scene == hub and hub.mode == hub.Mode.MATCH_MENU, "H must not bypass the match menu")
	var original_position := player.global_position
	var original_rotation := player.rotation
	Input.action_press("move_forward")
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(120, 40)
	Input.parse_input_event(mouse)
	await frames(12)
	Input.action_release("move_forward")
	check(player.global_position.distance_to(original_position) < 0.05, "Menu leaked movement input")
	check(player.rotation.is_equal_approx(original_rotation), "Menu leaked mouse-look input")
	await press("interact")
	check(hub.mode == hub.Mode.MATCH_MENU, "Repeated E should not start a match")
	await press("ui_cancel")
	check(hub.mode == hub.Mode.PLAYING and player.controls_enabled, "Escape must restore gameplay")
	if DisplayServer.get_name() != "headless":
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Escape must restore captured mouse")
	await press("interact")
	hub.ui.practice.pressed.emit()
	await frames(12)
	check(current_scene.name == &"Playground", "Test match should load the playground")
	check(get_nodes_in_group("player").size() == 1, "Scene transition duplicated the player")
	check(not current_scene.has_node("PersonajVerde"), "Standalone duplicate character must be removed")
	await check_world("res://actors/player/player_green_man.tscn", 5.0)

	player = current_scene.get_node("Player3D")
	player.global_position = Vector3(0, 0.1, 5)
	player.rotation.y = PI / 2.0
	await frames(12)
	var start := player.global_position
	var forward: Vector3 = -player.camera.global_basis.z
	Input.action_press("move_forward")
	await frames(12)
	Input.action_release("move_forward")
	check((player.global_position - start).dot(forward) > 0.25, "W must follow rotated camera forward")
	var right: Vector3 = player.camera.global_basis.x
	start = player.global_position
	Input.action_press("move_right")
	await frames(12)
	Input.action_release("move_right")
	check((player.global_position - start).dot(right) > 0.25, "D must strafe right relative to the camera")
	check(player.animation_player.current_animation == "locomotion/walk", "Walk animation must play")
	await frames(24)
	check(not player.animation_player.is_playing(), "Walking animation should stop when idle")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(player.velocity.y > 0, "Jump should launch the character")
	await frames(90)
	check(player.is_on_floor(), "Jump should land on the ground")
	player.global_position.y = -20
	await frames()
	check(player.global_position.y > -1, "Falling out of the map should respawn")
	await press("ui_cancel")
	check(current_scene.ui.return_hub.visible, "Practice menu needs a return-to-hub button")
	current_scene.ui.return_hub.pressed.emit()
	await frames(12)
	check(current_scene.name == &"Hub", "Return-to-hub failed")
	check(get_nodes_in_group("player").size() == 1, "Returning to hub duplicated the player")
	await check_world("res://actors/player/player_green_man.tscn", 5.0)

	# Switch via the hub station and H, preserving selection across both worlds.
	for choice in [
		["ButtonBlue", "res://actors/player/player_blue_man.tscn", 3.0],
		["ButtonPurple", "res://actors/player/player_purple_man.tscn", 10.0],
	]:
		if choice[0] == "ButtonBlue":
			await open_character_station()
		else:
			await press("select_character")
		check(current_scene.name == &"CharacterSelectionScreen", "Character switch must open the selector")
		check(get_nodes_in_group("player").is_empty(), "Old player survived the selector transition")
		current_scene.get_node("HBoxContainer/" + choice[0]).pressed.emit()
		await frames(12)
		check(current_scene.name == &"Hub", "Every character must enter the hub")
		await check_world(choice[1], choice[2])
		player = current_scene.new_player
		player.global_position = Vector3(0, 0.05, -7.9)
		await frames(8)
		await press("interact")
		check(current_scene.mode == current_scene.Mode.MATCH_MENU, "Selected character cannot activate terminal")
		current_scene.ui.practice.pressed.emit()
		await frames(12)
		check(current_scene.name == &"Playground", "Selected character cannot enter playground")
		await check_world(choice[1], choice[2])
		await press("ui_cancel")
		await press("select_character")
		check(current_scene.name == &"Playground" and not current_scene.new_player.controls_enabled, "H must not bypass pause")
		current_scene.ui.return_hub.pressed.emit()
		await frames(12)
		await check_world(choice[1], choice[2])
		# Also verify selection opened from playground returns to the hub.
		current_scene.travel_to(current_scene.PRACTICE)
		await frames(12)
		await press("select_character")
		current_scene.get_node("HBoxContainer/" + choice[0]).pressed.emit()
		await frames(12)
		check(current_scene.name == &"Hub", "Selection from playground must return to hub")
		await check_world(choice[1], choice[2])

	await press("ui_cancel")
	current_scene.ui.main_menu.pressed.emit()
	await frames(12)
	check(current_scene.name == &"MainMenu", "Return to main menu failed")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Main menu should keep the cursor visible")
	if failures.is_empty():
		print("HUB_FLOW_OK: all three characters, single player/camera, spawn/respawn, selection, travel, movement, interaction and menus")
	quit(0 if failures.is_empty() else 1)
