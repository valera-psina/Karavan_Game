extends SceneTree
## Проверка: карта игрока вылетает из руки, а не из колоды.
##   godot --headless --path . --script res://tools/check_flight.gd

var _fails: Array[String] = []


func _init() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)

	var game := (load("res://Scenes/Game.tscn") as PackedScene).instantiate()
	game.dealer_delay = 0.01
	vp.add_child(game)

	# Проходим стартовую раскладку: игрок кладёт базу, дилер отвечает.
	var frames := 0
	while game.phase == GameController.Phase.START and frames < 40000:
		frames += 1
		await process_frame
		if game._start_locked:
			continue
		for ci in MatchState.CARAVAN_COUNT:
			if not game.state.player_caravans[ci].is_empty():
				continue
			for hand_card in game.state.player_hand:
				if hand_card.is_numeric():
					game.player_play(hand_card, ci)
					break
			break

	if game.phase != GameController.Phase.PLAYER_TURN:
		_fails.append("не дошли до хода игрока: %d" % game.phase)
		_finish()
		return

	var view := game.get_node("Table") as TableView

	# Даём доиграть полётам стартовой раскладки.
	for f in 400:
		await process_frame

	# Ищем легальный ход из руки.
	var hand_index := -1
	var target := Vector2i(-1, -1)
	for i in game.state.player_hand.size():
		var card: CardData = game.state.player_hand[i]
		var targets := KaravanRules.legal_targets(card, game.state.all_caravans())
		if not targets.is_empty():
			hand_index = i
			target = targets[0]
			break

	if hand_index < 0:
		_fails.append("нет легального хода в руке")
		_finish()
		return

	var card: CardData = game.state.player_hand[hand_index]
	var hand_pos: Vector2 = view._hand_views[hand_index].global_position

	view._on_hand_pressed(card, hand_index)
	if view.selected_card != card:
		_fails.append("карта не выбралась")

	if target.y < 0:
		view._on_slot_pressed(target.x)
	else:
		view._on_entry_pressed(target.x, target.y)

	# Полёт создаётся сразу, в том же кадре (второй может быть ходом дилера).
	var from_hand := false
	for child in view.overlay.get_children():
		var flight := child as Control
		if flight != null and flight.global_position.distance_to(hand_pos) < 4.0:
			from_hand = true
	if not from_hand:
		_fails.append("карта игрока вылетела не из руки")

	_finish()


func _finish() -> void:
	print("---")
	if _fails.is_empty():
		print("OK: карта игрока вылетает из руки")
		quit(0)
	else:
		for f in _fails:
			printerr("FAIL: " + f)
		quit(1)
