extends "res://tests/toilet_flow_test.gd"

const CATALOG = preload("res://systems/map_catalog.gd")

func walk_to(player: Player3D, destination: Vector3) -> void:
	var direction := destination - player.global_position
	player.rotation.y = atan2(-direction.x, -direction.z)
	Input.action_press("move_forward")
	for frame in 540:
		await physics_frame
		var horizontal := player.global_position - destination
		horizontal.y = 0
		if horizontal.length() < 0.3:
			break
	Input.action_release("move_forward")
	await frames(8)
	var offset := player.global_position - destination
	offset.y = 0
	check(offset.length() < 0.65, "Walk route blocked at %s, wanted %s" % [player.global_position, destination])

func run() -> void:
	for choice in 3:
		root.get_node("Data").SelectPlayer = choice
		for map_index in [1, 2]:
			check(change_scene_to_file("res://maps/hub/hub.tscn") == OK, "Hub failed to load")
			await frames(12)
			var hub := current_scene
			hub._on_station_activated(hub.new_player)
			check(hub.ui.map_picker.visible and hub.ui.map_picker.item_count == 3, "Terminal must offer all three maps")
			hub.ui.map_picker.select(map_index)
			hub.ui.map_picker.item_selected.emit(map_index)
			check(hub.ui.selected_map_path() == CATALOG.MAPS[map_index].path, "Map choice path mismatch")
			hub.ui.practice.pressed.emit()
			await frames(15)
			var world := current_scene
			var player: Player3D = world.new_player
			check(world.scene_file_path == CATALOG.MAPS[map_index].path, "Terminal opened the wrong map")
			check(get_nodes_in_group("player").size() == 1, "Story map must spawn exactly one player")
			check(player.camera.current and player.is_on_floor(), "Player camera and spawn floor must work")
			check(player.global_position.distance_to(world.get_node("PlayerSpawn").position) < 0.2, "Unexpected spawn")
			check(world.ui.get_node("Root/HUD/Location").text == world.map_title, "Map HUD must not say Playground")
			var toilets := get_nodes_in_group("toilet")
			check(toilets.size() == (2 if map_index == 1 else 3), "Wrong number of toilets")
			if choice == 0:
				if map_index == 1:
					await walk_to(player, Vector3(0, 0, -7))
					var left: Node3D = world.get_node("ToiletLeft")
					var right: Node3D = world.get_node("ToiletRight")
					check(left.global_basis.z.dot((right.position - left.position).normalized()) > 0.99, "Left toilet must face the right toilet")
					check(right.global_basis.z.dot((left.position - right.position).normalized()) > 0.99, "Right toilet must face the left toilet")
					check(world.has_node("GepetoSpawn"), "Train story hook missing")
				else:
					await walk_to(player, Vector3(0, 0, -1.5))
					await walk_to(player, Vector3(-3.2, 0, -1.5))
					await walk_to(player, Vector3(3.3, 0, -1.5))
					check(world.has_node("ErecSpawn"), "School story hook missing")
			for toilet_node in toilets:
				await aim_at_toilet(player, toilet_node)
				await press("interact")
				check(player.is_seated() and toilet_node.occupant() == player, "Every new toilet must work with E")
				if player.is_seated():
					await shoot_for(12)
					await press("interact")
					check(not player.is_seated() and toilet_node.occupant() == null, "Stand-up must release the seat")
			# Exterior walls must physically prevent escaping the map.
			player.global_position = Vector3(0, 0.05, -9 if map_index == 1 else -7.5)
			player.rotation = Vector3.ZERO
			Input.action_press("move_forward")
			await frames(110)
			Input.action_release("move_forward")
			check(player.position.z > (-12.4 if map_index == 1 else -10.0), "Back wall collision failed")
			player.respawn()
			await frames(8)
			await press("ui_cancel")
			check(not world.ui.map_picker.visible and not player.controls_enabled, "Pause must hide map picker and disable movement")
			world.ui.options_button.pressed.emit()
			check(world.ui.is_options_open(), "New maps must retain the team's options menu")
			await press("ui_cancel")
			check(not world.ui.is_options_open() and not player.controls_enabled, "Escape from options returns to pause")
			world.ui.return_hub.pressed.emit()
			await frames(12)
			check(current_scene.is_hub and get_nodes_in_group("player").size() == 1, "Return-to-hub must dispose of old scene")
			print("STORY_MAP_OK: character=", choice, " map=", map_index)
	# Drain scene cleanup and music crossfades before stopping the test process.
	change_scene_to_file("res://menus/main_menu/main_menu.tscn")
	await frames(100)
	for audio_player in root.get_node("MusicPlayer").get_children():
		if audio_player is AudioStreamPlayer:
			audio_player.stop()
			audio_player.stream = null
	await frames(8)
	if failures.is_empty():
		print("STORY_MAPS_OK: terminal selection, all characters, walking routes, facing seats, collisions, options and return")
	quit(0 if failures.is_empty() else 1)
