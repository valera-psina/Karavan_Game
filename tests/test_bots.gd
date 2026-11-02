extends SceneTree
## Проверки ботов: Easy играет первый легальный ход, Hard — осмысленно
## (ломает валетом караван игрока в зачётной зоне, королём добивает свой до 21–26).
##
##   godot --headless --path . --script res://tests/test_bots.gd

var _passed := 0
var _failed := 0


func _init() -> void:
	_test_easy_returns_legal()
	_test_hard_jacks_player_caravan()
	_test_hard_kings_own_caravan()
	_test_no_moves()

	print("---")
	if _failed == 0:
		print("OK: %d проверок пройдено" % _passed)
		quit(0)
	else:
		printerr("FAIL: %d провалено, %d пройдено" % [_failed, _passed])
		quit(1)


func _test_easy_returns_legal() -> void:
	var state := _fresh_state()
	state.dealer_hand.append(_card("2c.png"))
	state.dealer_hand.append(_card("K club.png"))
	var bot := EasyBot.new()
	var move := bot.choose_move(state, MatchState.Side.DEALER)

	_check(not move.is_empty(), "Easy находит ход")
	if move.is_empty():
		return
	_check(KaravanRules.can_play(move["card"], state.all_caravans(), move["ci"], move["ei"]),
		"ход Easy легален")


func _test_hard_jacks_player_caravan() -> void:
	var state := _fresh_state()
	state.player_caravans[0].entries.append(_entry("10s.png"))
	state.player_caravans[0].entries.append(_entry("10h.png"))
	state.player_caravans[0].entries.append(_entry("A spade.png"))
	_check(state.player_caravans[0].value() == 21, "у игрока караван на 21")

	state.dealer_hand.clear()
	state.dealer_hand.append(_card("Jspade.png"))
	state.dealer_hand.append(_card("2c.png"))
	state.dealer_hand.append(_card("3c.png"))

	var move := HardBot.new().choose_move(state, MatchState.Side.DEALER)
	_check(not move.is_empty(), "Hard находит ход")
	if move.is_empty():
		return
	_check((move["card"] as CardData).kind == CardData.Kind.JACK, "Hard выбрал валета, а не %s" % move["card"].file)
	_check(move["ci"] == 0, "Hard бьёт караван игрока (ci=%d)" % move["ci"])


func _test_hard_kings_own_caravan() -> void:
	var state := _fresh_state()
	state.dealer_caravans[0].entries.append(_entry("10s.png"))
	state.dealer_caravans[0].entries.append(_entry("A spade.png"))
	_check(state.dealer_caravans[0].value() == 11, "у дилера караван на 11")

	state.dealer_hand.clear()
	state.dealer_hand.append(_card("K club.png"))
	state.dealer_hand.append(_card("2c.png"))
	state.dealer_hand.append(_card("3c.png"))

	var move := HardBot.new().choose_move(state, MatchState.Side.DEALER)
	_check(not move.is_empty(), "Hard находит ход")
	if move.is_empty():
		return
	_check((move["card"] as CardData).kind == CardData.Kind.KING, "Hard выбрал короля, а не %s" % move["card"].file)
	_check(move["ci"] == MatchState.CARAVAN_COUNT, "король идёт в свой караван (ci=%d)" % move["ci"])
	_check(move["ei"] == 0, "король ложится на первую карту (ei=%d)" % move["ei"])


func _test_no_moves() -> void:
	var state := _fresh_state()
	state.dealer_hand.clear()
	_check(HardBot.new().choose_move(state, MatchState.Side.DEALER).is_empty(), "пустая рука — нет хода")
	_check(EasyBot.new().choose_move(state, MatchState.Side.DEALER).is_empty(), "Easy: пустая рука — нет хода")


func _fresh_state() -> MatchState:
	var state := MatchState.new()
	state.start(11)
	state.player_hand.clear()
	state.dealer_hand.clear()
	return state


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
