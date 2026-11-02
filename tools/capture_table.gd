extends SceneTree
## РЎРЅРёРјР°РµС‚ СЃРєСЂРёРЅС€РѕС‚ РїР°СЂС‚РёРё РІ PNG: СЃС‚Р°СЂС‚РѕРІР°СЏ СЂР°СЃРєР»Р°РґРєР° РїР»СЋСЃ РЅРµСЃРєРѕР»СЊРєРѕ С…РѕРґРѕРІ.
##   godot --path . --script res://tools/capture_table.gd
## РќСѓР¶РµРЅ РЅР°СЃС‚РѕСЏС‰РёР№ РІРёРґРµРѕ-РґСЂР°Р№РІРµСЂ (РЅРµ --headless).

func _init() -> void:
	var scene := load("res://Scenes/Game.tscn") as PackedScene
	if scene == null:
		printerr("РќРµС‚ Game.tscn")
		quit(1)
		return

	if root.size.y > root.size.x:
		root.content_scale_size = Vector2i(1080, 1920)

	var game := scene.instantiate()
	game.dealer_delay = 0.05
	root.add_child(game)
	await process_frame
	await process_frame

	var ctrl := game as GameController
	await _play_a_bit(ctrl)

	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("РџСѓСЃС‚РѕР№ РєР°РґСЂ")
		quit(1)
		return

	var path := "res://Docs/table_preview.png"
	if root.size.y > root.size.x:
		path = "res://Docs/table_portrait.png"
	var err := image.save_png(path)
	print("saved %s (%dx%d), err=%d" % [path, image.get_width(), image.get_height(), err])
	quit(0)


func _play_a_bit(ctrl: GameController) -> void:
	if ctrl == null:
		return

	var guard := 0
	while ctrl.phase == GameController.Phase.START and guard < 40:
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
					ctrl.player_play(card, ci)
					done = true
					break
			if done:
				break
		await _wait_unlock(ctrl)
		if not done:
			break

	for round_index in 3:
		if ctrl.phase != GameController.Phase.PLAYER_TURN:
			break
		var played := false
		for card in ctrl.state.player_hand:
			var targets := KaravanRules.legal_targets(card, ctrl.state.all_caravans())
			if not targets.is_empty():
				ctrl.player_play(card, targets[0].x, targets[0].y)
				played = true
				break
		await _wait_dealer(ctrl)
		if not played:
			break

	# ���� ��������� ����� � ��������� ��������.
	for i in 30:
		await process_frame


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
