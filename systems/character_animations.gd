extends RefCounted

static func bind_libraries(player: AnimationPlayer, skeleton: Skeleton3D) -> void:
	for name in player.get_animation_library_list():
		var original := player.get_animation_library(name)
		var local := AnimationLibrary.new()
		for key in original.get_animation_list():
			var source := original.get_animation(key)
			var clip := local_clip(source, player, skeleton, false)
			clip.loop_mode = source.loop_mode
			local.add_animation(key, clip)
		player.remove_animation_library(name)
		player.add_animation_library(name, local)

# Imported clips can still reference the original armature name after Make Local.
# Always work on a private copy and bind bone tracks to this instance's skeleton.
static func local_clip(source: Animation, player: AnimationPlayer, skeleton: Skeleton3D, loop: bool) -> Animation:
	var clip := source.duplicate(true) as Animation
	clip.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var animation_root := player.get_node(player.root_node)
	var skeleton_path := str(animation_root.get_path_to(skeleton))
	for track in clip.get_track_count():
		var path := clip.track_get_path(track)
		if path.get_subname_count() == 1 and skeleton.find_bone(path.get_subname(0)) >= 0:
			clip.track_set_path(track, NodePath(skeleton_path + ":" + str(path.get_subname(0))))
	return clip
