extends "res://tests/hub_flow_test.gd"

func shoot_for(count: int) -> void:
	var event := InputEventAction.new()
	event.action = "shoot"
	event.pressed = true
	Input.parse_input_event(event)
	await frames(count)
	event = InputEventAction.new()
	event.action = "shoot"
	event.pressed = false
	Input.parse_input_event(event)
	await frames(4)

func aim_at_toilet(player: Player3D, toilet: Node3D, distance := 1.4) -> void:
	player.global_position = toilet.global_position + toilet.global_basis.z * distance
	player.global_position.y = 0.05
	var direction := toilet.global_position - player.global_position
	player.rotation = Vector3(0, atan2(-direction.x, -direction.z), 0)
	player.camera_pivot.look_at(toilet.to_global(Vector3(0, 0.15, 0)))
	await frames(8)
	player.interactor.refresh_target()

func check_bone_animation(player: Player3D) -> void:
	var bone := player.skeleton.find_bone("hip.l.001")
	player.animation_player.play("locomotion/walk")
	player.animation_player.seek(0.1, true)
	player.skeleton.force_update_all_bone_transforms()
	var before := player.skeleton.get_bone_pose(bone)
	player.animation_player.seek(0.6, true)
	player.skeleton.force_update_all_bone_transforms()
	check(not before.is_equal_approx(player.skeleton.get_bone_pose(bone)), "Walk must actually animate the selected skeleton")
	player.animation_player.stop()
	player.skeleton.reset_bone_poses()

func run() -> void:
	var data := root.get_node("Data")
	for choice in 3:
		data.SelectPlayer = choice
		check(change_scene_to_file("res://maps/playground/playground.tscn") == OK, "Playground failed to load")
		await frames(12)
		var world := current_scene
		var player: Player3D = world.new_player
		var toilet: Node3D = world.get_node("PracticeToilet")
		var target: StaticBody3D = world.get_node("PeeTarget")
		var npc := world.get_node("NpcBunic")
		check_bone_animation(player)
		check(toilet.occupant() == null, "Training toilet must initially be free")
		check(npc._toilet.occupant() == npc, "NPC must reserve its toilet")
		check("ocupată" in npc._toilet.get_interaction_prompt(), "Reserved toilet must show occupied")
		check(not player.try_sit(npc._toilet), "Player cannot steal an NPC's toilet")
		await shoot_for(10)
		check(player.pee_stream._drops.is_empty(), "Shooting while standing must do nothing")
		await aim_at_toilet(player, toilet, 4)
		await press("interact")
		check(not player.is_seated(), "Distant E must not seat the player")
		await aim_at_toilet(player, toilet)
		check(player.interactor.target == toilet, "Ray must resolve the toilet's imported collider to its root")
		# A wall must block both the prompt and the activation.
		var wall := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3, 4, 0.15)
		collision.shape = box
		wall.add_child(collision)
		world.add_child(wall)
		wall.position = Vector3(5, 1, 2.1)
		await frames()
		await press("interact")
		check(not player.is_seated(), "Toilet interaction must not pass through walls")
		wall.queue_free()
		await frames()
		await press("interact")
		check(player.is_seated() and toilet.occupant() == player, "E must sit and reserve the free toilet")
		if not player.is_seated():
			quit(1)
			return
		check(not npc._is_free(toilet), "NPC must respect a player's reservation")
		check(not toilet.try_reserve(npc), "A second actor must not steal the seat")
		check(player.camera.current and player.camera_pivot.position.y < 1.3, "Seated first-person camera must be lowered")
		await frames(85)
		var hip := player.skeleton.get_bone_pose_position(0)
		check(hip.distance_to(player.skeleton.get_bone_rest(0).origin) > 0.15, "Sit animation must actually move the skeleton")
		await frames(85)
		check(hip.is_equal_approx(player.skeleton.get_bone_pose_position(0)), "Sit pose must hold, not loop back to standing")
		var seated_position := player.global_position
		Input.action_press("move_forward")
		Input.action_press("jump")
		await frames(12)
		Input.action_release("move_forward")
		Input.action_release("jump")
		check(player.global_position.is_equal_approx(seated_position), "Seated WASD/jump must not move the player")
		player.camera_pivot.look_at(target.global_position)
		await shoot_for(65)
		check(target.hits > 0, "Seated stream must hit the target and update its counter")
		check(player.pee_stream._drops.size() <= player.pee_stream.MAX_DROPS, "Stream must stay bounded")
		player.pee_stream.stop()
		var previous_hits: int = target.hits
		# Place a broad wall between muzzle and target: no splash or damage behind it.
		wall = StaticBody3D.new()
		collision = CollisionShape3D.new()
		collision.shape = box
		wall.add_child(collision)
		world.add_child(wall)
		wall.position = Vector3(5, 1, 0)
		await frames()
		await shoot_for(45)
		check(target.hits == previous_hits, "Stream must not hit targets through walls")
		wall.queue_free()
		player.pee_stream.stop()
		await frames()
		# Pause cancels an already-held trigger and removes in-flight hits.
		var trigger := InputEventAction.new()
		trigger.action = "shoot"
		trigger.pressed = true
		Input.parse_input_event(trigger)
		await frames(4)
		await press("ui_cancel")
		previous_hits = target.hits
		await frames(40)
		check(not player.pee_stream.firing and player.pee_stream._drops.is_empty(), "Pause must stop and clear the stream")
		check(target.hits == previous_hits, "No hits may be delivered while paused")
		check(toilet.occupant() == player, "Pause must preserve occupancy")
		await press("interact")
		check(player.is_seated(), "E in pause must not stand up")
		await press("ui_cancel")
		await frames(12)
		check(not player.pee_stream.firing, "Resume must require a fresh trigger press")
		trigger.pressed = false
		Input.parse_input_event(trigger)
		# If all exits are occupied, stay seated instead of clipping into a wall.
		wall = StaticBody3D.new()
		collision = CollisionShape3D.new()
		var enclosure := BoxShape3D.new()
		enclosure.size = Vector3(6, 4, 6)
		collision.shape = enclosure
		wall.add_child(collision)
		world.add_child(wall)
		wall.position = Vector3(5, 1.5, 3)
		await frames()
		await press("interact")
		check(player.is_seated() and toilet.occupant() == player, "Blocked exits must not release the seat or clip the player")
		wall.queue_free()
		await frames()
		await press("interact")
		check(not player.is_seated() and toilet.occupant() == null, "E must stand up and release the toilet")
		check(player.camera_pivot.position == player._standing_camera_position, "Standing must restore camera position")
		check(player.is_on_floor(), "Player must stand on the floor, outside toilet geometry")
		await aim_at_toilet(player, toilet)
		await press("interact")
		player.respawn()
		await frames()
		check(not player.is_seated() and toilet.occupant() == null, "Respawn must release the seat")
		check(npc._state == npc.State.SIT, "NPC must still reach and sit on its own toilet")
		check(npc._skeleton.get_bone_pose_position(0).distance_to(npc._skeleton.get_bone_rest(0).origin) > 0.15, "NPC must animate its seated pose")
		# Same-model instances must have independent clips and skeleton poses.
		var second: Player3D = load(player.scene_file_path).instantiate()
		world.add_child(second)
		second.set_physics_process(false)
		second.set_controls_enabled(false)
		check(player.animation_player.get_animation("locomotion/walk") != second.animation_player.get_animation("locomotion/walk"), "Instances must not share mutable animation clips")
		second.animation_player.play("locomotion/sit")
		second.animation_player.seek(1.16, true)
		var second_pose := second.skeleton.get_bone_pose_position(0)
		check_bone_animation(player)
		check(second.skeleton.get_bone_pose_position(0).is_equal_approx(second_pose), "Animating one instance must not affect another")
		second.queue_free()
		await frames()
		player.camera.make_current()
		player.set_controls_enabled(true)
		await aim_at_toilet(player, toilet)
		await press("interact")
		# Removing a seated player releases the toilet even without a stand-up input.
		player.queue_free()
		await frames()
		check(toilet.occupant() == null, "Freeing the player must release occupancy")
		check(toilet.try_reserve(npc), "Released toilet must be claimable again")
		toilet.release(npc)
		print("TOILET_CHARACTER_OK: ", choice)
	# Hub toilets use the same contract; scene switches must destroy the old seat.
	check(change_scene_to_file("res://maps/hub/hub.tscn") == OK, "Hub failed to load")
	await frames(12)
	var hub_player: Player3D = current_scene.new_player
	var hub_toilet: Node3D = current_scene.get_node("ToiletLeft")
	await aim_at_toilet(hub_player, hub_toilet)
	await press("interact")
	check(hub_player.is_seated(), "Hub toilet must be usable with E")
	await press("select_character")
	check(current_scene.name == &"CharacterSelectionScreen", "H must allow changing a seated character")
	check(not is_instance_valid(hub_player) and not is_instance_valid(hub_toilet), "Scene switch must remove both seat and old player")
	current_scene.get_node("HBoxContainer/ButtonGreen").pressed.emit()
	await frames(12)
	hub_player = current_scene.new_player
	hub_toilet = current_scene.get_node("ToiletLeft")
	check(hub_toilet.occupant() == null, "A new scene must not inherit stale reservations")
	await aim_at_toilet(hub_player, hub_toilet)
	await press("interact")
	hub_toilet.queue_free()
	await frames(8)
	check(not hub_player.is_seated(), "A removed toilet must recover the seated player")
	check(hub_player.global_position.distance_to(current_scene.get_node("PlayerSpawn").global_position) < 0.2, "Removed toilet must return player to safe spawn")
	if failures.is_empty():
		print("TOILET_FLOW_OK: three rigs, independent instances, occupied seats, E, shooting, collisions, pause, stand and cleanup")
	quit(0 if failures.is_empty() else 1)
