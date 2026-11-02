extends SceneTree
## Проверка: «Заново» полностью очищает стол и раздаёт новые карты.
##   godot --headless --path . --script res://tools/check_restart.gd

var _fails: Array[String] = []


func _init() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)

	var game := (load("res://Scenes/Game.tscn") as PackedScene).instantiate()
	game.dealer_delay = 0.01
	vp.add_child(game)

	for i in 120:
		await process_frame

	# Имитируем конец партии: оверлей показан.
	game.game_over.visible = true
	_check(game.game_over.visible, "оверлей не появился")

	# Накидываем карты на стол, чтобы проверить очистку.
	var view := game.get_node("Table") as TableView
	var before := view.player_hand.get_child_count()

	game.start_new_game()
	await process_frame
	await process_frame

	_check(not game.game_over.visible, "оверлей не скрылся после «Заново»")
	_check(game.phase == GameController.Phase.START, "фаза не сбросилась: %d" % game.phase)
	_check(game.state.player_hand.size() == 8, "в руке не 8 карт: %d" % game.state.player_hand.size())
	_check(view.player_hand.get_child_count() == 8,
		"на столе остались старые карты: %d (было %d)" % [view.player_hand.get_child_count(), before])

	var on_table := 0
	for caravan in view.enemy_views + view.player_views:
		on_table += caravan.card_views().size()
	_check(on_table == 0, "в караванах остались карты: %d" % on_table)


	_finish()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_fails.append(message)


func _finish() -> void:
	print("---")
	if _fails.is_empty():
		print("OK: «Заново» очищает стол и раздаёт заново")
		quit(0)
	else:
		for f in _fails:
			printerr("FAIL: " + f)
		quit(1)
