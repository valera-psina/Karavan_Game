extends SceneTree
## Проверка стека: числовые карты идут вниз, вложения — вправо, есть поворот и z-index.
##   godot --headless --path . --script res://tools/check_stack.gd

var _fails: Array[String] = []


func _init() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)

	var game := (load("res://Scenes/Game.tscn") as PackedScene).instantiate()
	game.dealer_delay = 0.01
	vp.add_child(game)
	await process_frame
	await process_frame

	var ctrl := game as GameController
	var view := ctrl.table

	# Собираем караван вручную: 10, 6, дама на 10, король на 6.
	var caravan := ctrl.state.dealer_caravans[1]
	caravan.entries.clear()
	caravan.entries.append(KaravanEntry.new(_card("10s.png")))
	var queen := KaravanEntry.new(_card("6h.png"))
	queen.attachments.append(_card("Qheart.png"))
	caravan.entries.append(queen)
	caravan.entries.append(KaravanEntry.new(_card("4c.png")))
	view.render_all()
	# Ждём, пока отыграет анимация появления (0.24 с), иначе позиции смещены.
	await create_timer(0.45).timeout

	var cards := view.enemy_views[1].card_views()
	_check(cards.size() == 4, "в караване 4 карты, а не %d" % cards.size())
	if cards.size() < 4:
		_finish()
		return

	# Порядок: 10s, 6h, Qheart (на 6h), 4c.
	var first := cards[0].position
	var second := cards[1].position
	var queen_pos := cards[2].position
	var third := cards[3].position

	_check(absf(second.x - first.x) < 1.0, "вторая числовая не под первой (x)")
	_check(second.y > first.y + 10.0, "вторая числовая не ниже первой (dy=%.1f)" % (second.y - first.y))
	_check(second.y - first.y <= 40.0, "слишком большой шаг вниз: %.1f" % (second.y - first.y))
	_check(third.y > second.y, "третья числовая не ниже второй")
	_check(queen_pos.x > second.x + 10.0, "дама не сдвинута вправо")
	_check(absf(queen_pos.y - second.y) < 1.0, "дама не на уровне своей карты (%.1f vs %.1f)" % [queen_pos.y, second.y])

	var angles: Array[float] = []
	for card in cards:
		angles.append(rad_to_deg(card.rotation))
		_check(absf(rad_to_deg(card.rotation)) <= 3.5, "поворот вне диапазона: %.1f" % rad_to_deg(card.rotation))
	_check(angles.size() == 4, "углы собраны")

	var zs: Array[int] = []
	for card in cards:
		zs.append(card.z_index)
	_check(zs[1] > zs[0] and zs[2] > zs[1] and zs[3] > zs[2], "z-index не растёт: %s" % str(zs))

	# Клик по карте и по пустому полю должен уходить в караван.
	var hit_entry := [-1]
	var hit_slot := [-1]
	var hit_caravan := view.enemy_views[1]
	hit_caravan.entry_pressed.connect(func(_ci: int, ei: int): hit_entry[0] = ei)
	hit_caravan.slot_pressed.connect(func(ci: int): hit_slot[0] = ci)

	var inv := hit_caravan.get_global_transform().affine_inverse()
	var hit_ev := InputEventMouseButton.new()
	hit_ev.button_index = MOUSE_BUTTON_LEFT
	hit_ev.pressed = true

	hit_ev.position = inv * cards[0].get_global_rect().get_center()
	hit_caravan._gui_input(hit_ev)
	_check(hit_entry[0] == 0, "клик по карте не попал в позицию 0: %d" % hit_entry[0])

	hit_ev.position = inv * (hit_caravan.get_global_rect().position + Vector2(hit_caravan.size.x * 0.5, hit_caravan.size.y - 8.0))
	hit_caravan._gui_input(hit_ev)
	_check(hit_slot[0] == 4, "клик по пустому полю не дал слот: %d" % hit_slot[0])
	_finish()


func _finish() -> void:
	print("---")
	if _fails.is_empty():
		print("OK: стек карт рисуется правильно")
		quit(0)
	else:
		for f in _fails:
			printerr("FAIL: " + f)
		quit(1)


func _card(file: String) -> CardData:
	var card := CardCatalog.card_from_file(file)
	if card == null:
		_fails.append("нет карты " + file)
	return card


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails.append(message)
