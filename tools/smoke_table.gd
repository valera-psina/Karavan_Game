extends SceneTree
## Дымовой тест игрового цикла: поднимает Game.tscn, проходит стартовую
## раскладку, играет несколько ходов и проверяет инварианты.
##
##   godot --headless --path . --script res://tools/smoke_table.gd

var _fails: Array[String] = []


func _init() -> void:
	var scene := load("res://Scenes/Game.tscn") as PackedScene
	if scene == null:
		printerr("Нет сцены Game.tscn")
		quit(1)
		return

	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)

	var game := scene.instantiate()
	game.dealer_delay = 0.01
	vp.add_child(game)
	await process_frame
	await process_frame

	var ctrl := game as GameController
	if ctrl == null or ctrl.state == null:
		printerr("Контроллер не поднялся")
		quit(1)
		return

	_check(ctrl.phase == GameController.Phase.START, "партия начинается со стартовой раскладки")

	# --- стартовая раскладка игрока: по числовой карте в каждый караван
	var guard := 0
	while ctrl.phase == GameController.Phase.START and guard < 60:
		guard += 1
		if ctrl._start_locked:
			await _wait_unlock(ctrl)
			continue
		var done := false
		for ci in MatchState.CARAVAN_COUNT:
			if not ctrl.state.player_caravans[ci].is_empty():
				continue
			for card in ctrl.state.player_hand:
				if card.is_numeric():
					_check(ctrl.player_play(card, ci), "стартовая карта принята")
					done = true
					break
			if done:
				break
		await _wait_unlock(ctrl)
		if not done:
			break

	_check(ctrl.phase == GameController.Phase.PLAYER_TURN, "после старта — ход игрока, а не %d" % ctrl.phase)
	for ci in MatchState.CARAVAN_COUNT:
		_check(ctrl.state.player_caravans[ci].entries.size() == 1, "у игрока база в караване %d" % (ci + 1))
		_check(ctrl.state.dealer_caravans[ci].entries.size() == 1, "у дилера база в караване %d" % (ci + 1))
	_check(ctrl.state.player_hand.size() == 8, "рука игрока 8 карт, а не %d" % ctrl.state.player_hand.size())
	_check(ctrl.state.dealer_hand.size() == 8, "рука дилера 8 карт, а не %d" % ctrl.state.dealer_hand.size())

	# --- несколько полных ходов
	var played := 0
	var passes := 0
	for round_index in 8:
		if ctrl.phase != GameController.Phase.PLAYER_TURN:
			break
		var move := _best_available(ctrl)
		if move.is_empty():
			ctrl.player_pass()
			passes += 1
		else:
			_check(ctrl.player_play(move["card"], move["ci"], move["ei"]), "ход игрока принят")
			played += 1
		await _wait_dealer(ctrl)
		_debug_duplicates(ctrl.state, round_index)

	_check(played + passes > 0, "игрок успел сходить")
	_check(_total_cards(ctrl.state) == CardCatalog.DECK_SIZE,
		"карт в партии %d, а должно быть %d" % [_total_cards(ctrl.state), CardCatalog.DECK_SIZE])
	_check(ctrl.state.player_hand.size() <= 8 and ctrl.state.dealer_hand.size() <= 8, "руки не переполняются")

	print("---")
	print("фаза: %d, ходов игрока: %d, пасов: %d, колода: %d, сброс: %d, продано: %d:%d" % [
		ctrl.phase, played, passes, ctrl.state.deck.remaining(), ctrl.state.deck.discard_size(),
		ctrl.state.sold(MatchState.Side.PLAYER), ctrl.state.sold(MatchState.Side.DEALER),
	])
	if _fails.is_empty():
		print("OK: игровой цикл работает")
		quit(0)
	else:
		for f in _fails:
			printerr("FAIL: " + f)
		quit(1)


func _wait_unlock(ctrl: GameController) -> void:
	var frames := 0
	while ctrl.phase == GameController.Phase.START and ctrl._start_locked and frames < 600:
		frames += 1
		await process_frame


func _wait_dealer(ctrl: GameController) -> void:
	var frames := 0
	while ctrl.phase == GameController.Phase.DEALER_TURN and frames < 600:
		frames += 1
		await process_frame


func _best_available(ctrl: GameController) -> Dictionary:
	var all := ctrl.state.all_caravans()
	for card in ctrl.state.player_hand:
		var targets := KaravanRules.legal_targets(card, all)
		if not targets.is_empty():
			return {"card": card, "ci": targets[0].x, "ei": targets[0].y}
	return {}


func _table_cards(state: MatchState) -> Array[CardData]:
	var cards: Array[CardData] = []
	for caravan in state.all_caravans():
		for entry in caravan.entries:
			cards.append(entry.base)
			cards.append_array(entry.attachments)
	return cards


func _total_cards(state: MatchState) -> int:
	return state.deck.remaining() + state.deck.discard_size() \
		+ state.player_hand.size() + state.dealer_hand.size() \
		+ _table_cards(state).size()


func _debug_duplicates(state: MatchState, round_index: int) -> void:
	var seen := {}
	var dupes: Array[String] = []
	var add := func(card: CardData, where: String) -> void:
		var id := card.get_instance_id()
		if seen.has(id):
			dupes.append("%s: %s и %s" % [card.file, seen[id], where])
		else:
			seen[id] = where

	for card in state.player_hand:
		add.call(card, "рука игрока")
	for card in state.dealer_hand:
		add.call(card, "рука дилера")
	for caravan in state.all_caravans():
		for entry in caravan.entries:
			add.call(entry.base, "стол")
			for attachment in entry.attachments:
				add.call(attachment, "стол")
	for card in state.deck.draw_pile:
		add.call(card, "колода")
	for card in state.deck.discard_pile:
		add.call(card, "сброс")

	if not dupes.is_empty():
		print("round %d: total=%d uniq=%d дубли -> %s" % [round_index, _total_cards(state), seen.size(), "; ".join(dupes)])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails.append(message)
