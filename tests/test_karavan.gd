extends SceneTree
## Headless-тесты данных и правил «Каравана».
## Запуск:
##   & "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . `
##       --script res://tests/test_karavan.gd

var _checks := 0
var _failures: Array[String] = []

const C := CardData.Suit.CLUBS
const D := CardData.Suit.DIAMONDS
const H := CardData.Suit.HEARTS
const S := CardData.Suit.SPADES


func _init() -> void:
	_test_catalog()
	_test_deck()
	_test_values()
	_test_numeric_flow()
	_test_descending()
	_test_queen()
	_test_jack()
	_test_joker_rank()
	_test_joker_suit()
	_test_scoring()
	_test_legal_targets()

	print("---")
	if _failures.is_empty():
		print("OK: %d проверок пройдено" % _checks)
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		printerr("Провалено %d из %d" % [_failures.size(), _checks])
		quit(1)


# ------------------------------------------------------------------ тесты

func _test_catalog() -> void:
	var problems := CardCatalog.validate()
	_check(problems.is_empty(), "каталог без проблем: " + ", ".join(problems))

	var cards := CardCatalog.all_cards()
	_check(cards.size() == 54, "в каталоге 54 карты, найдено %d" % cards.size())

	var numbers := 0
	var aces := 0
	var jacks := 0
	var queens := 0
	var kings := 0
	var jokers := 0
	for card in cards:
		match card.kind:
			CardData.Kind.NUMBER:
				numbers += 1
			CardData.Kind.ACE:
				aces += 1
			CardData.Kind.JACK:
				jacks += 1
			CardData.Kind.QUEEN:
				queens += 1
			CardData.Kind.KING:
				kings += 1
			CardData.Kind.JOKER:
				jokers += 1
	_check(numbers == 36 and aces == 4 and jacks == 4 and queens == 4 and kings == 4 and jokers == 2,
		"состав колоды: 36/4/4/4/4/2, а не %d/%d/%d/%d/%d/%d" % [numbers, aces, jacks, queens, kings, jokers])

	_check(CardCatalog.resolve_file("2d.png") == "2D.png", "регистр в имени файла (2d -> 2D)")
	_check(CardCatalog.resolve_file("A_spade.png") == "A spade.png", "пробел в имени (A_spade -> A spade)")
	_check(CardCatalog.resolve_file("K_club.png") == "K club.png", "пробел в имени (K_club -> K club)")
	_check(CardCatalog.resolve_file("QSPADE.PNG") == "QSpade.png", "регистр в имени (QSPADE -> QSpade)")
	_check(CardCatalog.resolve_file("joker_cardv2.png") == "Joker cardv2.png", "вариант джокера v2")

	var king := CardCatalog.card_from_file("Kspade.png")
	_check(king != null and king.rank == 13 and king.suit == S, "Kspade.png -> король пик")
	var ace := CardCatalog.card_from_file("A spade.png")
	_check(ace != null and ace.rank == 1 and ace.suit == S and ace.value() == 1, "A spade.png -> туз пик = 1")

	for card in cards:
		if not FileAccess.file_exists(card.texture_path()):
			_check(false, "нет текстуры " + card.texture_path())


func _test_deck() -> void:
	var deck := CardCatalog.standard_deck(1234)
	_check(deck.remaining() == 54, "после раздачи в колоде 54 карты")

	var first := deck.draw()
	_check(first != null and deck.remaining() == 53, "draw() уменьшает колоду")

	var drawn := 0
	while deck.draw() != null:
		drawn += 1
		if drawn > 100:
			break
	_check(drawn == 53, "из колоды вытянулись все 53 оставшиеся карты (%d)" % drawn)
	_check(deck.remaining() == 0, "колода пуста")

	# Сброс возвращается в колоду автоматически.
	var small := DeckData.new()
	var cards: Array[CardData] = [_num(2, C), _num(3, C), _num(4, C)]
	small.setup(cards)
	small.draw()
	small.draw()
	small.discard(small.draw())
	_check(small.remaining() == 0 and small.discard_size() == 1, "сброс учтён")
	var again := small.draw()
	_check(again != null and small.discard_size() == 0, "пустая колода перемешивает сброс")


func _test_values() -> void:
	_check(_num(7, C).value() == 7, "семёрка = 7")
	_check(_ace(H).value() == 1, "туз = 1")
	_check(_face(CardData.Kind.KING, H).value() == 0, "король сам по себе = 0")

	var entry := KaravanEntry.new(_num(5, C))
	_check(entry.value() == 5, "позиция без королей = 5")
	entry.attachments.append(_face(CardData.Kind.KING, H))
	_check(entry.value() == 10, "один король удваивает: 10, получено %d" % entry.value())
	entry.attachments.append(_face(CardData.Kind.KING, S))
	_check(entry.value() == 20, "два короля дают x4: 20, получено %d" % entry.value())


func _test_numeric_flow() -> void:
	var caravans: Array[CaravanState] = [_caravan()]
	_check(KaravanRules.apply(_num(5, C), caravans, 0).size() > 0, "первую карту можно положить")
	_check(caravans[0].value() == 5 and caravans[0].direction == 0 and caravans[0].suit == C,
		"первая карта задаёт масть и не задаёт направление")

	KaravanRules.apply(_num(8, D), caravans, 0)
	_check(caravans[0].direction == 1, "вторая карта задаёт направление вверх")
	_check(caravans[0].suit == D, "масть сменилась на бубны")
	_check(caravans[0].value() == 13, "сумма 5+8 = 13")

	_check(KaravanRules.can_place_numeric(caravans[0], _num(6, D)), "своя масть кладётся против направления")
	KaravanRules.apply(_num(6, D), caravans, 0)
	_check(caravans[0].value() == 19, "сумма 5+8+6 = 19")

	_check(not KaravanRules.can_place_numeric(caravans[0], _num(4, C)), "чужую масть нельзя против направления")
	_check(KaravanRules.apply(_num(4, C), caravans, 0).is_empty(), "нелегальный ход не применяется")
	_check(caravans[0].value() == 19, "сумма не изменилась после нелегального хода")

	_check(KaravanRules.can_place_numeric(caravans[0], _num(9, C)), "чужую масть можно по направлению")
	KaravanRules.apply(_num(9, C), caravans, 0)
	_check(caravans[0].value() == 28 and caravans[0].is_busted(), "перебор >26 фиксируется")


func _test_descending() -> void:
	var caravans: Array[CaravanState] = [_caravan()]
	KaravanRules.apply(_num(10, H), caravans, 0)
	KaravanRules.apply(_num(3, H), caravans, 0)
	_check(caravans[0].direction == -1, "10 -> 3 задаёт направление вниз")

	_check(KaravanRules.can_place_numeric(caravans[0], _num(7, H)), "своя масть вниз можно")
	KaravanRules.apply(_num(7, H), caravans, 0)
	_check(caravans[0].value() == 20, "10+3+7 = 20")

	_check(KaravanRules.can_place_numeric(caravans[0], _num(2, S)), "меньшая карта чужой масти вниз можно")
	_check(not KaravanRules.can_place_numeric(caravans[0], _num(9, S)), "большая карта чужой масти вниз нельзя")


func _test_queen() -> void:
	var caravans: Array[CaravanState] = [_caravan(), _caravan()]
	KaravanRules.apply(_num(5, C), caravans, 0)
	KaravanRules.apply(_num(8, D), caravans, 0)
	_check(caravans[0].direction == 1, "до дамы направление вверх")

	var queen := _face(CardData.Kind.QUEEN, H)
	_check(KaravanRules.can_play(queen, caravans, 0, 0), "даму можно положить на карту")
	KaravanRules.apply(queen, caravans, 0, 0)
	_check(caravans[0].direction == -1, "дама разворачивает направление")
	_check(caravans[0].suit == H, "дама меняет масть каравана на свою")
	_check(caravans[0].entries[0].attachments.size() == 1, "дама остаётся прикреплённой")
	_check(caravans[0].value() == 13, "дама не добавляет очков")

	# Даму можно играть на чужой караван.
	KaravanRules.apply(_num(6, S), caravans, 1)
	var enemy_queen := _face(CardData.Kind.QUEEN, C)
	_check(KaravanRules.can_play(enemy_queen, caravans, 1, 0), "даму можно играть на чужой караван")
	KaravanRules.apply(enemy_queen, caravans, 1, 0)
	_check(caravans[1].suit == C, "дама сменила масть чужого каравана")


func _test_jack() -> void:
	var caravans: Array[CaravanState] = [_caravan(), _caravan()]
	KaravanRules.apply(_num(5, C), caravans, 0)
	KaravanRules.apply(_face(CardData.Kind.KING, H), caravans, 0, 0)
	_check(caravans[0].value() == 10, "король удвоил 5 до 10")

	var jack := _face(CardData.Kind.JACK, D)
	_check(KaravanRules.can_play(jack, caravans, 0, 0), "валета можно положить на карту")
	var events := KaravanRules.apply(jack, caravans, 0, 0)
	_check(caravans[0].is_empty() and caravans[0].value() == 0, "валет убрал карту вместе с королём")
	_check(caravans[0].suit == CardData.Suit.NONE and caravans[0].direction == 0,
		"опустевший караван сбросил масть и направление")
	_check(_has_event(events, "remove"), "валет сообщает событие remove")


func _test_joker_rank() -> void:
	var caravans: Array[CaravanState] = [_caravan(), _caravan()]
	KaravanRules.apply(_num(7, C), caravans, 0)
	KaravanRules.apply(_num(9, H), caravans, 0)
	KaravanRules.apply(_num(7, S), caravans, 1)
	_check(caravans[0].value() == 16 and caravans[1].value() == 7, "до джокера: 16 и 7")

	var joker := _joker()
	_check(KaravanRules.can_play(joker, caravans, 0, 0), "джокера можно играть на числовую карту")
	KaravanRules.apply(joker, caravans, 0, 0)
	_check(caravans[0].value() == 9, "джокер убрал семёрку из своего каравана")
	_check(caravans[1].is_empty(), "джокер убрал семёрку и у противника")


func _test_joker_suit() -> void:
	var caravans: Array[CaravanState] = [_caravan(), _caravan()]
	KaravanRules.apply(_ace(C), caravans, 0)
	KaravanRules.apply(_num(7, C), caravans, 0)
	KaravanRules.apply(_ace(H), caravans, 1)
	_check(caravans[0].value() == 8 and caravans[1].value() == 1, "до джокера: 8 и 1")

	KaravanRules.apply(_joker(), caravans, 0, 0)
	_check(caravans[0].is_empty(), "джокер на тузе убрал все трефы своего каравана")
	_check(caravans[1].value() == 1, "червовый туз уцелел")


func _test_scoring() -> void:
	var own_23 := _caravan_of([10, 9, 4])
	var enemy_20 := _caravan_of([10, 6, 4])
	var own_20 := _caravan_of([10, 6, 4])

	_check(own_23.value() == 23 and enemy_20.value() == 20, "23 и 20 собраны")
	_check(KaravanRules.is_sold(own_23, enemy_20), "23 против 20 — караван продан")
	_check(not KaravanRules.is_sold(own_23, _caravan_of([10, 9, 4])), "23 против 23 — не продано (строго выше)")
	_check(not KaravanRules.is_sold(own_20, enemy_20), "20 вне диапазона 21..26")
	_check(KaravanRules.is_sold(own_23, _caravan_of([10, 10, 9])), "караван противника с перебором не мешает продаже")

	var own: Array[CaravanState] = [_caravan_of([10, 9, 4]), _caravan_of([10, 9, 4]), _caravan_of([10, 6, 4])]
	var enemy: Array[CaravanState] = [_caravan_of([10, 6, 4]), _caravan_of([10, 6, 4]), _caravan_of([10, 6, 4])]
	_check(KaravanRules.winner(own, enemy) == 1, "2 проданных каравана из 3 — победа")

	var enemy_strong: Array[CaravanState] = [_caravan_of([10, 9, 4]), _caravan_of([10, 9, 4]), _caravan_of([10, 6, 4])]
	_check(KaravanRules.winner(own, enemy_strong) == 0, "1:1 по караванам — игра не решена")


func _test_legal_targets() -> void:
	var caravans: Array[CaravanState] = [_caravan(), _caravan()]
	KaravanRules.apply(_num(5, C), caravans, 0)
	KaravanRules.apply(_num(8, D), caravans, 0)
	KaravanRules.apply(_num(6, H), caravans, 1)

	var numeric := KaravanRules.legal_targets(_num(9, C), caravans)
	_check(numeric.size() == 2 and numeric[0] == Vector2i(0, -1), "числовая карта: цели — концы караванов")

	var jack := _face(CardData.Kind.JACK, S)
	var targets := KaravanRules.legal_targets(jack, caravans)
	_check(targets.size() == 3, "валет: по цели на каждую карту стола, найдено %d" % targets.size())

	var joker_targets := KaravanRules.legal_targets(_joker(), caravans)
	_check(joker_targets.size() == 3, "джокер: только по числовым картам, найдено %d" % joker_targets.size())


# --------------------------------------------------------------- утилиты

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _has_event(events: Array[Dictionary], type: String) -> bool:
	for e in events:
		if e.get("type", "") == type:
			return true
	return false


func _num(rank: int, suit: int) -> CardData:
	var c := CardData.new()
	c.kind = CardData.Kind.NUMBER
	c.rank = rank
	c.suit = suit
	return c


func _ace(suit: int) -> CardData:
	var c := CardData.new()
	c.kind = CardData.Kind.ACE
	c.rank = 1
	c.suit = suit
	return c


func _face(kind: int, suit: int) -> CardData:
	var c := CardData.new()
	c.kind = kind
	c.suit = suit
	c.rank = 11 if kind == CardData.Kind.JACK else (12 if kind == CardData.Kind.QUEEN else 13)
	return c


func _joker() -> CardData:
	var c := CardData.new()
	c.kind = CardData.Kind.JOKER
	c.rank = 0
	c.suit = CardData.Suit.NONE
	return c


func _caravan() -> CaravanState:
	return CaravanState.new()


func _caravan_of(ranks: Array) -> CaravanState:
	var c := CaravanState.new()
	for r in ranks:
		c.entries.append(KaravanEntry.new(_num(r, C)))
	return c
