extends SceneTree
## Скриншот главного меню: godot --path . --script res://tools/capture_menu.gd

func _init() -> void:
	var scene := load("res://Scenes/MainMenu.tscn") as PackedScene
	if scene == null:
		printerr("Нет MainMenu.tscn")
		quit(1)
		return

	root.add_child(scene.instantiate())
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("Пустой кадр")
		quit(1)
		return

	var path := "res://Docs/menu_preview.png"
	var err := image.save_png(path)
	print("saved %s (%dx%d), err=%d" % [path, image.get_width(), image.get_height(), err])
	quit(0)
