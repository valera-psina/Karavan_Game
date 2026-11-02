extends SceneTree
func _init() -> void:
	await process_frame
	var sfx = load("res://Scripts/Audio/Sfx.gd").new()
	root.add_child(sfx)
	await process_frame
	var missing: Array[String] = []
	for key in sfx.SOUNDS:
		var player = sfx._players.get(key)
		if player == null or player.stream == null:
			missing.append(str(key))
	print("players=%d, missing=%s" % [sfx._players.size(),
		", ".join(missing) if not missing.is_empty() else "нет"])
	sfx.play("click", 0.9, 1.1)
	sfx.play("win", 1.0, 1.0)
	print("play() не упал")
	quit(0)
