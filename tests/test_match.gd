extends SceneTree
## Проверки MatchState: раздача, руки, подсчёт проданных караванов, победитель.
##
##   godot --headless --path . --script res://tests/test_match.gd

var _passed := 0
var _failed := 0


func _init() -> void:
	_test_start()
	_test_hand_ops()
	_test_sold_and_winner()
	_test_out_of_cards()

	print("---")
	if _failed == 0:
		print("OK: %d проверок пройдено" % _passed)
		quit(0)
	else:
		printerr("FAIL: %d провалено, %d пройдено" % [_failed, _passed])
		quit(1)


func _test_start() -> void:
	var state := MatchState.new()
	state.start(42)

	_check(state.player_hand.size() == MatchState.HAND_SIZE, "рука игрока 8")
	_check(state.dealer_hand.size() == MatchState.HAND_SIZE, "рука дилера 8")
	_check(state.deck.remaining() == CardCatalog.DECK_SIZE - 16, "в колоде 38 после раздачи")
	_check(state.all_caravans().size() == 6, "шесть караванов")
	_check(state.player_caravans[0].owner_id == MatchState.Side.PLAYER, "караваны 0..2 — игрока")
	_check(state.dealer_caravans[0].owner_id == MatchState.Side.DEALER, "караваны 3..5 — дилера")
	_check(state.initial_count(MatchState.Side.PLAYER) == 0, "стартовая раскладка не сделана")
	_check(not state.initial_done(), "старт не завершён")
	_check(state.winner_side() == MatchState.Result.NONE, "победителя нет")


func _test_hand_ops() -> void:
	var state := MatchState.new()
	state.start(7)

	var card: CardData = state.player_hand[0]
	var before := state.deck.remaining()
	_check(state.take_card(MatchState.Side.PLAYER, card), "карта забрана из руки")
	_check(not state.player_hand.has(card), "карты больше нет в руке")
	_check(not state.take_card(MatchState.Side.PLAYER, card), "повторно забрать нельзя")

	var drawn := state.draw_one(MatchState.Side.PLAYER)
	_check(drawn != null, "карта добирается")
	_check(state.deck.remaining() == before - 1, "колода уменьшилась на одну")

	state.draw_to_hand_size(MatchState.Side.DEALER)
	_check(state.dealer_hand.size() <= MatchState.HAND_SIZE, "добор не переполняет руку")


func _test_sold_and_winner() -> void:
	var state := MatchState.new()
	state.start(1)

	# Игрок: 10 + 10 + туз = 21, второй караван 10 + (3 + K) + 7 = 23.
	state.player_caravans[0].entries.append(_entry("10s.png"))
	state.player_caravans[0].entries.append(_entry("10h.png"))
	state.player_caravans[0].entries.append(_entry("A spade.png"))
	state.player_caravans[1].entries.append(_entry("10d.png"))
	var second: KaravanEntry = _entry("3c.png")
	second.attachments.append(_card("K club.png"))
	state.player_caravans[1].entries.append(second)
	state.player_caravans[1].entries.append(_entry("7c.png"))

	# Дилер слабее: 20 и 18.
	var dealer_first: KaravanEntry = _entry("10s.png")
	dealer_first.attachments.append(_card("Kspade.png"))
	state.dealer_caravans[0].entries.append(dealer_first)
	var dealer_second: KaravanEntry = _entry("9h.png")
	dealer_second.attachments.append(_card("K heart.png"))
	state.dealer_caravans[1].entries.append(dealer_second)

	_check(state.player_caravans[0].value() == 21, "первый караван 21, а не %d" % state.player_caravans[0].value())
	_check(state.player_caravans[1].value() == 23, "второй караван 23, а не %d" % state.player_caravans[1].value())
	_check(state.sold(MatchState.Side.PLAYER) == 2, "у игрока два проданных каравана")
	_check(state.winner_side() == MatchState.Result.PLAYER, "игрок победил 2:0")

	# Ломаем один караван перебором — остаётся один проданный, победы нет.
	state.player_caravans[1].entries.append(_entry("9c.png"))
	_check(state.player_caravans[1].is_busted(), "караван перебрал")
	_check(state.sold(MatchState.Side.PLAYER) == 1, "продан только один караван")
	_check(state.winner_side() == MatchState.Result.NONE, "победы нет при 1:0")


func _test_out_of_cards() -> void:
	var state := MatchState.new()
	state.start(3)
	state.player_hand.clear()
	state.dealer_hand.clear()
	var guard := 0
	while state.deck.remaining() > 0 and guard < 100:
		state.deck.draw()
		guard += 1
	_check(state.is_out_of_cards(), "карты кончились")
	_check(state.compare_sold() == MatchState.Result.NONE, "0:0 — ничья")


func _entry(file: String) -> KaravanEntry:
	return KaravanEntry.new(_card(file))


func _card(file: String) -> CardData:
	var card := CardCatalog.card_from_file(file)
	if card == null:
		_fail("нет карты " + file)
	return card


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failed += 1
	printerr("FAIL: " + message)
