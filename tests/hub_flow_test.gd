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

func run() -> void:
	check(change_scene_to_file("res://menus/main_menu/main_menu.tscn") == OK, "Main menu failed to load")
	await frames()
	current_scene.get_node("Center/MenuPanel/Margin/VBox/Singleplayer").pressed.emit()
	await frames(12)
	var hub := current_scene
	check(hub.name == &"Hub", "Main menu must open the hub")
	var player := hub.get_node("Player3D") as CharacterBody3D
	check(get_nodes_in_group("player").size() == 1, "Hub must have exactly one player")
	check(player.get_node("Character/Model").scene_file_path.ends_with("PersonajVerde.glb"), "Wrong player model")
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
	await press("ui_cancel")
	current_scene.ui.main_menu.pressed.emit()
	await frames(12)
	check(current_scene.name == &"MainMenu", "Return to main menu failed")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Main menu should keep the cursor visible")
	if failures.is_empty():
		print("HUB_FLOW_OK: character, travel, walking, jumping, range, occlusion, input lock, menus and respawn")
	quit(0 if failures.is_empty() else 1)
