extends SceneTree
## Служебная проверка раскладки: грузит Table.tscn, ждёт layout и печатает
## прямоугольники ключевых узлов. Нужна, чтобы ловить выезды за экран и
## наложения без визуального просмотра.
##
##   godot --headless --path . --script res://tools/inspect_table.gd

func _init() -> void:
	var scene := load("res://Scenes/Table.tscn") as PackedScene
	if scene == null:
		printerr("Не загрузилась сцена")
		quit(1)
		return

	# В headless окно 64×64, и stretch-режим считает раскладку не в дизайн-
	# координатах. Кладём сцену в SubViewport 1920×1080 — там canvas 1:1.
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)

	var root_node := scene.instantiate()
	vp.add_child(root_node)
	await process_frame
	await process_frame
	await process_frame

	_dump(root_node)
	_details(root_node)
	quit(0)


func _details(scene: Node) -> void:
	var hand := scene.get_node_or_null("Frame/Felt/Inner/VBox/HandRow/PlayerHand")
	if hand != null:
		print("hand: rect=%s, карт=%d" % [(hand as Control).get_global_rect(), hand.get_child_count()])
		for i in mini(2, hand.get_child_count()):
			var c := hand.get_child(i) as Control
			print("  card%d: %s" % [i, c.get_global_rect()])

	var deck_art := scene.get_node_or_null("Frame/Felt/Inner/VBox/TopBar/DeckBox/DeckArt") as TextureRect
	print("deck art texture: %s" % (deck_art.texture != null if deck_art != null else "нет узла"))

	for row_name in ["EnemyRow", "PlayerRow"]:
		var row := scene.get_node_or_null("Frame/Felt/Inner/VBox/" + row_name)
		if row == null:
			continue
		for caravan in row.get_children():
			var view := caravan as CaravanView
			if view == null:
				continue
			var area := view.card_area
			var rects: Array[String] = []
			for child in area.get_children():
				if child is CardView:
					rects.append(str((child as Control).get_global_rect()))
			print("%s: value=%d, cards=%d, %s" % [view.title, view.state.value() if view.state != null else -1, rects.size(), " | ".join(rects)])


func _dump(node: Node) -> void:
	var screen := Vector2(1920, 1080)
	print("viewport: %s" % root.size)

	var names := ["Table", "Frame", "Felt", "VBox", "TopBar", "EnemyRow", "PlayerRow", "HandRow", "Status"]
	_walk(node, "", names, screen)
	print("---")

	var table := node.get_node_or_null("Frame/Felt/Inner/VBox")
	if table != null:
		for child in table.get_children():
			if child is HBoxContainer and (child.name == "EnemyRow" or child.name == "PlayerRow"):
				for caravan in child.get_children():
					if caravan is Control:
						var r: Rect2 = (caravan as Control).get_global_rect()
						print("%s/%s: %s" % [child.name, caravan.name, r])


func _walk(node: Node, prefix: String, targets: Array, screen: Vector2) -> void:
	if node is Control and targets.has(str(node.name)):
		var rect := (node as Control).get_global_rect()
		var flag := ""
		if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > screen.x or rect.end.y > screen.y:
			flag = "  <-- ЗА ЭКРАНОМ"
		print("%s%s: %s%s" % [prefix, node.name, rect, flag])
	for child in node.get_children():
		_walk(child, prefix + str(node.name) + "/", targets, screen)
