extends SceneTree
## Проверка адаптивной раскладки: стол в портретном и ландшафтном SubViewport.
##   godot --headless --path . --script res://tools/inspect_portrait.gd

var _fails: Array[String] = []


func _init() -> void:
	await _check_orientation(Vector2i(1080, 1920), true)
	await _check_orientation(Vector2i(1920, 1080), false)

	print("---")
	if _fails.is_empty():
		print("OK: раскладка адаптируется")
		quit(0)
	else:
		for f in _fails:
			printerr("FAIL: " + f)
		quit(1)


func _check_orientation(size: Vector2i, portrait: bool) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)

	var game := (load("res://Scenes/Game.tscn") as PackedScene).instantiate()
	game.dealer_delay = 0.01
	vp.add_child(game)
	for i in 4:
		await process_frame

	var view := game.get_node("Table") as TableView
	var bounds := Rect2(Vector2.ZERO, Vector2(size))

	# Караваны всегда в три ряда: 3 сверху (дилер), 3 снизу (игрок).
	_check(view.enemy_row.visible and view.player_row.visible, "%dx%d: ряды скрыты" % [size.x, size.y])

	var enemy_first: Rect2 = view.enemy_views[0].get_global_rect()
	var enemy_third: Rect2 = view.enemy_views[2].get_global_rect()
	_check(absf(enemy_third.position.y - enemy_first.position.y) < 1.0,
		"%dx%d: караваны дилера не в ряд" % [size.x, size.y])
	_check(enemy_third.position.x > enemy_first.position.x,
		"%dx%d: караваны дилера не слева направо" % [size.x, size.y])

	var player_first: Rect2 = view.player_views[0].get_global_rect()
	_check(enemy_first.size.x == player_first.size.x and enemy_first.size.y == player_first.size.y,
		"%dx%d: караваны разного размера: %s vs %s" % [size.x, size.y, enemy_first.size, player_first.size])
	_check(player_first.position.y > enemy_first.position.y,
		"%dx%d: караваны игрока не ниже дилера" % [size.x, size.y])

	for caravan in view.enemy_views + view.player_views:
		var rect: Rect2 = (caravan as Control).get_global_rect()
		if not bounds.encloses(rect):
			_fails.append("%dx%d: %s вылез за экран: %s" % [size.x, size.y, caravan.title, rect])

	for caravan in view.enemy_views + view.player_views:
		_check(caravan.mouse_filter == Control.MOUSE_FILTER_STOP,
			"%dx%d: караван не ловит клики" % [size.x, size.y])
		var cards := caravan.get_node("VBox/Cards") as Control
		_check(cards.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"%dx%d: поле каравана перехватывает клики" % [size.x, size.y])

	var hand_rect: Rect2 = view.player_hand.get_global_rect()
	if not bounds.encloses(hand_rect):
		_fails.append("%dx%d: рука вылезла: %s" % [size.x, size.y, hand_rect])
	_check(hand_rect.position.y > player_first.position.y, "%dx%d: рука не внизу" % [size.x, size.y])

	var buttons: Control = view.btn_draw.get_parent() as Control
	var buttons_rect := buttons.get_global_rect()
	if not bounds.encloses(buttons_rect):
		_fails.append("%dx%d: кнопки вылезли: %s" % [size.x, size.y, buttons_rect])
	_check(buttons_rect.position.y > hand_rect.position.y,
		"%dx%d: кнопки не под рукой: %s" % [size.x, size.y, buttons_rect])
	_check(buttons_rect.size.y >= 44.0, "%dx%d: кнопки мелкие: %.0f" % [size.x, size.y, buttons_rect.size.y])

	if portrait:
		_check(enemy_first.size.x < 400.0, "%dx%d: караван шире, чем нужно: %.0f" % [size.x, size.y, enemy_first.size.x])
		_check(enemy_first.size.x > 120.0, "%dx%d: караван слишком узкий: %.0f" % [size.x, size.y, enemy_first.size.x])

	print("%dx%d: режим=%s, караван=%s, рука=%s, кнопки=%s" % [
		size.x, size.y, "портрет" if portrait else "ландшафт",
		enemy_first, hand_rect, buttons_rect])

	vp.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails.append(message)
