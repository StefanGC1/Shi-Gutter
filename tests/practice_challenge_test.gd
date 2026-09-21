extends "res://tests/toilet_flow_test.gd"

func run() -> void:
	for choice in 3:
		root.get_node("Data").SelectPlayer = choice
		check(change_scene_to_file("res://maps/playground/playground.tscn") == OK, "Playground failed to load")
		await frames(12)
		var world := current_scene
		var player: Player3D = world.new_player
		var toilet: Node3D = world.get_node("PracticeToilet")
		var challenge := world.get_node("PracticeChallenge")
		await press("practice_round")
		check(not challenge.running and not challenge.visible, "Standing R must not start the challenge")
		await aim_at_toilet(player, toilet)
		await press("interact")
		check(challenge.visible, "Challenge instructions must appear on the practice seat")
		player.camera_pivot.look_at(challenge.targets[0].global_position)
		await shoot_for(35)
		check(challenge.targets[0].hits > 0 and challenge.score == 0, "Free practice must work without scoring")
		await press("practice_round")
		check(challenge.running and challenge.score == 0 and challenge.active_index == 0, "R must start a fresh round")
		var remaining: float = challenge.time_left
		await press("practice_round")
		check(challenge.time_left < remaining, "R during a round must not reset the timer")
		challenge.targets[1].receive_pee_hit(player, Vector3.ZERO, Vector3.UP)
		challenge.targets[0].receive_pee_hit(world.get_node("NpcBunic"), Vector3.ZERO, Vector3.UP)
		check(challenge.target_hits == 0 and challenge.score == 0, "Inactive targets and other actors cannot score")
		# Real ballistic hits must reach all three targets from each character's seat.
		for index in 3:
			check(challenge.active_index == index, "Exactly one target must activate in order")
			player.camera_pivot.look_at(challenge.targets[index].global_position)
			await shoot_for(65)
			player.pee_stream.stop()
			check(challenge.score == (index + 1) * 10, "Each completed target must award exactly ten points")
		check(challenge.active_index == 0, "Target order must wrap after the third target")
		await press("ui_cancel")
		remaining = challenge.time_left
		await frames(40)
		await press("practice_round")
		challenge.targets[0].receive_pee_hit(player, Vector3.ZERO, Vector3.UP)
		check(is_equal_approx(challenge.time_left, remaining), "Pause must freeze the timer; R must do nothing")
		check(challenge.score == 30 and challenge.target_hits == 0, "Pause must reject target hits")
		check(not challenge.visible, "Practice HUD must not cover the pause menu")
		await press("ui_cancel")
		check(challenge.visible and challenge.time_left < remaining, "Resume must restore the HUD and timer")
		# Exercise the same timeout path without waiting a full thirty seconds.
		challenge.time_left = 0.01
		await frames(4)
		check(not challenge.running and challenge.best_score == 30, "Timeout must finish the round and record its score")
		challenge.targets[0].receive_pee_hit(player, Vector3.ZERO, Vector3.UP)
		check(challenge.score == 30, "Late impacts cannot alter the result")
		check(not challenge.targets[0]._in_challenge, "Timeout must restore free-practice targets")
		await press("practice_round")
		check(challenge.running and challenge.score == 0 and challenge.best_score == 30, "Retry resets score but keeps the local best")
		# Cancelling an unfinished round must never replace the completed-round best.
		challenge.score = 100
		await press("interact")
		check(not challenge.running and challenge.best_score == 30, "Standing cancels the round without awarding a best")
		await aim_at_toilet(player, toilet)
		await press("interact")
		await press("practice_round")
		player.respawn()
		await frames()
		check(not challenge.running and not challenge.visible, "Respawn cancels the round and hides the HUD")
		# Another usable toilet must not start this station's minigame.
		var other_toilet: Node3D = load("res://Scenes/Toilet.tscn").instantiate()
		world.add_child(other_toilet)
		other_toilet.position = Vector3(9, 0.258, 6)
		await aim_at_toilet(player, other_toilet)
		await press("interact")
		check(player.is_seated(), "Secondary test toilet must be usable")
		await press("practice_round")
		check(not challenge.running and not challenge.visible, "R on a different toilet must do nothing")
		player.respawn()
		await aim_at_toilet(player, toilet)
		await press("interact")
		await press("practice_round")
		if choice == 0:
			toilet.queue_free()
			await frames(8)
			check(not challenge.running and not challenge.visible, "Removing the practice seat must safely cancel the round")
		elif choice == 1:
			player.queue_free()
			await frames(8)
			check(not challenge.running and not challenge.visible, "Removing the player must safely cancel the round")
		else:
			await press("select_character")
			check(current_scene.name == &"CharacterSelectionScreen" and not is_instance_valid(challenge), "Character selection must dispose of an active challenge")
		print("PRACTICE_CHARACTER_OK: ", choice)
	if failures.is_empty():
		print("PRACTICE_CHALLENGE_OK: real hits for three rigs, scoring, timer, pause, retries, cancellation and cleanup")
	quit(0 if failures.is_empty() else 1)
