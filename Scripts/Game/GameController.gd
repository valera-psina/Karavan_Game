class_name GameController
extends Node
## FSM партии: START (стартовая раскладка) -> PLAYER_TURN <-> DEALER_TURN -> GAME_OVER.
## Владеет MatchState, применяет правила и дергает TableView на перерисовку.
##
## Дилер на этом шаге — заглушка «случайный легальный ход». На шаге 5 его
## заменит эвристический бот (_choose_dealer_move).

enum Phase { START, PLAYER_TURN, DEALER_TURN, GAME_OVER }

@export var seed_value := 0
@export var dealer_delay := 0.55
## 0 — Easy, 1 — Hard. Если в меню выбрана сложность, она перекрывает экспорт.
@export var difficulty := 0

var state: MatchState
var phase := Phase.START
var bot: BotBase

var _busy := false
var _start_index := 0
var _start_locked := false
## 1 — игрок, 0 — дилер: пары «игрок → дилер» по одному каравану.
var _start_queue := [1, 0, 1, 0, 1, 0]

@onready var table: TableView = $Table


var game_over: CanvasLayer


func _ready() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		difficulty = settings.difficulty

	bot = HardBot.new() if difficulty == 1 else EasyBot.new()

	table.play_requested.connect(_on_play_requested)
	table.discard_requested.connect(_on_discard_requested)
	table.draw_requested.connect(_on_draw_requested)
	table.pass_requested.connect(_on_pass_requested)
	table.caravan_discard_requested.connect(_on_caravan_discard_requested)
	table.menu_requested.connect(_on_menu_requested)

	game_over = get_node_or_null("GameOver")
	if game_over != null:
		game_over.restart_requested.connect(start_new_game)
		game_over.menu_requested.connect(_on_menu_requested)

	new_game(seed_value)


func new_game(p_seed: int = 0) -> void:
	state = MatchState.new()
	state.start(p_seed)
	phase = Phase.START
	table.setup(state)

	_start_index = 0
	_start_locked = false
	_run_start_step()


# --------------------------------------------------------------- старт партии

## Классическая последовательность: игрок кладёт базу в караван N, дилер
## отвечает в свой караван N, и так для 1, 2, 3. Затем начинается PLAYER_TURN.
func _run_start_step() -> void:
	if _start_index >= _start_queue.size():
		_begin_player_turn()
		return

	var caravan := _start_index / 2

	if _start_queue[_start_index] == 1:
		_start_locked = false
		_update_ui()
		table.set_status("Выложи числовую карту в КАРАВАН %d." % (caravan + 1))
		return

	_start_locked = true
	_update_ui()
	table.set_status("Дилер выкладывает базу в КАРАВАН %d…" % (caravan + 1))
	await get_tree().create_timer(0.4).timeout
	if phase != Phase.START:
		return
	_dealer_initial_step(caravan)
	_start_index += 1
	_start_locked = false
	_update_ui()
	_run_start_step()


func _dealer_initial_step(caravan_index: int) -> void:
	if caravan_index < 0 or caravan_index >= MatchState.CARAVAN_COUNT:
		return
	if not state.dealer_caravans[caravan_index].is_empty():
		return

	var card := _pick_numeric(state.dealer_hand)
	if card == null:
		return
	_apply(MatchState.Side.DEALER, card, MatchState.CARAVAN_COUNT + caravan_index, -1)


func _begin_player_turn() -> void:
	phase = Phase.PLAYER_TURN
	state.turn = 1
	_update_ui()
	table.set_status("Твой ход. Выбери карту и цель или нажми «Ход».")


# ------------------------------------------------------------------ действия

func _on_play_requested(card: CardData, caravan_index: int, entry_index: int) -> void:
	if phase == Phase.START:
		_play_initial(card, caravan_index)
		return
	if phase != Phase.PLAYER_TURN or _busy:
		return
	_do_player_play(card, caravan_index, entry_index)


func player_play(card: CardData, caravan_index: int, entry_index: int = -1) -> bool:
	if phase == Phase.START:
		return _play_initial(card, caravan_index)
	if phase != Phase.PLAYER_TURN or _busy:
		return false
	return _do_player_play(card, caravan_index, entry_index)


func _do_player_play(card: CardData, caravan_index: int, entry_index: int) -> bool:
	if not state.player_hand.has(card):
		return false
	if not KaravanRules.can_play(card, state.all_caravans(), caravan_index, entry_index):
		var retry := -1
		if card.is_numeric() and entry_index >= 0 \
				and KaravanRules.can_play(card, state.all_caravans(), caravan_index, -1):
			retry = -1
		else:
			table.set_status("Так нельзя: %s." % card.describe())
			return false
		entry_index = retry

	var events := _apply(MatchState.Side.PLAYER, card, caravan_index, entry_index)
	table.set_status("%s → %s" % [card.describe(), _events_text(events)])
	_finish_player_action()
	return true


func _play_initial(card: CardData, caravan_index: int) -> bool:
	if _start_locked or phase != Phase.START:
		return false
	var required := _start_index / 2
	if caravan_index != required:
		table.set_status("Сейчас нужен КАРАВАН %d." % (required + 1))
		return false
	if not state.player_hand.has(card):
		return false
	if not card.is_numeric():
		table.set_status("Стартовая карта должна быть числовой (туз или 2–10).")
		return false
	if caravan_index < 0 or caravan_index >= MatchState.CARAVAN_COUNT:
		table.set_status("На старте карта кладётся только в свой караван.")
		return false
	if not state.player_caravans[caravan_index].is_empty():
		table.set_status("В этот караван стартовая карта уже выложена.")
		return false

	var events := _apply(MatchState.Side.PLAYER, card, caravan_index, -1)
	table.set_status("Старт: %s." % _events_text(events))

	_start_index += 1
	_run_start_step()
	return true


func _on_discard_requested(card: CardData) -> void:
	if phase != Phase.PLAYER_TURN or _busy:
		return
	if player_discard(card):
		pass


func player_discard(card: CardData) -> bool:
	if phase != Phase.PLAYER_TURN or _busy:
		return false
	if not state.player_hand.has(card):
		return false
	state.take_card(MatchState.Side.PLAYER, card)
	state.deck.discard(card)
	state.draw_one(MatchState.Side.PLAYER)
	table.set_status("Сброшена карта: %s." % card.describe())
	_finish_player_action()
	return true


func _on_draw_requested() -> void:
	player_draw()


func player_draw() -> bool:
	if phase != Phase.PLAYER_TURN or _busy:
		return false
	var card := state.draw_one(MatchState.Side.PLAYER)
	if card == null:
		table.set_status("Колода и сброс пусты.")
		return false
	_sfx("draw")
	table.set_status("Взята карта: %s." % card.describe())
	_finish_player_action()
	return true


func _on_pass_requested() -> void:
	player_pass()


func player_pass() -> bool:
	if phase != Phase.PLAYER_TURN or _busy:
		return false
	table.set_status("Ход передан дилеру.")
	_finish_player_action()
	return true


func _on_caravan_discard_requested(caravan_index: int) -> void:
	player_discard_caravan(caravan_index)


func player_discard_caravan(caravan_index: int) -> bool:
	if phase != Phase.PLAYER_TURN or _busy:
		return false
	if state.turn <= 1:
		table.set_status("В первый ход сбрасывать караван нельзя.")
		return false
	if caravan_index < 0 or caravan_index >= MatchState.CARAVAN_COUNT:
		return false

	var caravan := state.player_caravans[caravan_index]
	if caravan.is_empty():
		return false

	for entry in caravan.entries:
		for attachment in entry.attachments:
			state.deck.discard(attachment)
		state.deck.discard(entry.base)
	caravan.clear()

	table.set_status("Караван %d сброшен." % (caravan_index + 1))
	_finish_player_action()
	return true


# -------------------------------------------------------------- ход дилера

func _finish_player_action() -> void:
	_busy = true
	_update_ui()
	if _check_game_over():
		_busy = false
		return
	phase = Phase.DEALER_TURN
	_update_ui()
	table.set_status("Ход дилера…")
	_dealer_turn()


func _dealer_turn() -> void:
	await get_tree().create_timer(dealer_delay).timeout
	if phase != Phase.DEALER_TURN:
		_busy = false
		return

	var move := _choose_dealer_move()
	if move.get("action", "") == "discard_caravan":
		_dealer_discard_caravan(int(move["ci"]))
	elif move.is_empty():
		table.set_status("Дилер пропускает ход.")
	else:
		var card: CardData = move["card"]
		var events := _apply(MatchState.Side.DEALER, card, move["ci"], move["ei"])
		table.set_status("Дилер: %s → %s" % [card.describe(), _events_text(events)])

	_busy = false
	if _check_game_over():
		return

	phase = Phase.PLAYER_TURN
	state.turn += 1
	_update_ui()
	table.set_status("Твой ход.")


## Роспуск перегруженного каравана дилером: карты уходят в сброс.
func _dealer_discard_caravan(caravan_index: int) -> void:
	if caravan_index < 0 or caravan_index >= MatchState.CARAVAN_COUNT:
		return
	var caravan := state.dealer_caravans[caravan_index]
	if caravan.is_empty():
		return
	var count := 0
	for entry in caravan.entries:
		for attachment in entry.attachments:
			state.deck.discard(attachment)
			count += 1
		state.deck.discard(entry.base)
		count += 1
	caravan.clear()
	table.set_status("Дилер распускает КАРАВАН %d (перебор) — %d карт в сброс."
		% [caravan_index + 1, count])


## Дилер думает своей стратегией: EasyBot или HardBot (см. Scripts/Bots).
func _choose_dealer_move() -> Dictionary:
	if bot == null:
		return {}
	return bot.choose_move(state, MatchState.Side.DEALER)


# ------------------------------------------------------------------ итоги

## «Заново»: гасим оверлей и полностью перезапускаем партию — стол чистится
## через table.setup(), поэтому старые карты исчезают, а новые раздаются.
func start_new_game() -> void:
	if game_over != null:
		game_over.hide_result()
	_busy = false
	new_game(seed_value)


func _show_result(player_won: bool, is_draw: bool, text: String) -> void:
	if game_over != null:
		game_over.show_result(player_won, is_draw, text)


func _check_game_over() -> bool:
	var result := state.winner_side()
	if result == MatchState.Result.NONE and state.is_out_of_cards():
		result = state.compare_sold()

	if result == MatchState.Result.NONE and not state.is_out_of_cards():
		return false
	if result == MatchState.Result.NONE and state.is_out_of_cards():
		phase = Phase.GAME_OVER
		table.set_interactive(false)
		table.set_turn_text("НИЧЬЯ")
		table.set_status("Карты кончились. Проданных караванов: %d : %d."
			% [state.sold(MatchState.Side.PLAYER), state.sold(MatchState.Side.DEALER)])
		_show_result(false, true, "Карты кончились. Проданных караванов: %d : %d." % [
			state.sold(MatchState.Side.PLAYER), state.sold(MatchState.Side.DEALER)])
		return true

	phase = Phase.GAME_OVER
	table.set_interactive(false)
	var player_won := result == MatchState.Result.PLAYER
	table.set_turn_text("ПОБЕДА" if player_won else "ПОРАЖЕНИЕ")
	_sfx("win" if player_won else "lose", 1.0, 1.0)
	var detail := "%s Проданных караванов: %d : %d." % [
		"Ты собрал 2 каравана." if player_won else "Дилер собрал 2 каравана.",
		state.sold(MatchState.Side.PLAYER),
		state.sold(MatchState.Side.DEALER),
	]
	_show_result(player_won, false, detail)
	table.set_status(detail)
	return true


func _update_ui() -> void:
	table.render_all()
	match phase:
		Phase.START:
			table.set_interactive(not _start_locked)
			table.set_turn_text("НАЧАЛО · %d/%d" % [
				state.initial_count(MatchState.Side.PLAYER), MatchState.INITIAL_PLACEMENTS])
		Phase.PLAYER_TURN:
			table.set_interactive(true)
			table.set_turn_text("ВАШ ХОД · %d" % state.turn)
		Phase.DEALER_TURN:
			table.set_interactive(false)
			table.set_turn_text("ХОД ДИЛЕРА")
		Phase.GAME_OVER:
			table.set_interactive(false)

	table.set_caravan_discard_allowed(phase == Phase.PLAYER_TURN and state.turn > 1)


# ------------------------------------------------------------------ утилиты

func _apply(side: int, card: CardData, caravan_index: int, entry_index: int) -> Array[Dictionary]:
	# Снимок стола: после apply в сброс уходит всё, что со стола исчезло
	# (валет, джокер, выбитые вложения), а сама сыгранная карта остаётся лежать.
	var before := _table_cards()
	var events := KaravanRules.apply(card, state.all_caravans(), caravan_index, entry_index)
	if events.is_empty():
		return events

	state.take_card(side, card)
	state.draw_one(side)
	_sfx("place", 0.9, 1.1)

	var after := _table_cards()
	for table_card in before:
		if not after.has(table_card):
			state.deck.discard(table_card)
	# Джокер со стола не остаётся — уходит в сброс.
	if not after.has(card):
		state.deck.discard(card)

	table.render_all()
	return events


func _table_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for caravan in state.all_caravans():
		for entry in caravan.entries:
			cards.append(entry.base)
			cards.append_array(entry.attachments)
	return cards


func _pick_numeric(cards: Array[CardData]) -> CardData:
	var numeric: Array[CardData] = []
	for card in cards:
		if card.is_numeric():
			numeric.append(card)
	if numeric.is_empty():
		return null
	return numeric[randi() % numeric.size()]


func _on_menu_requested() -> void:
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")


func _sfx(key: String, min_pitch: float = 0.95, max_pitch: float = 1.05) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play(key, min_pitch, max_pitch)


func _events_text(events: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for e in events:
		match e.get("type", ""):
			"place":
				parts.append("положена %s" % e.card.describe())
			"attach":
				parts.append("%s на %d" % [e.card.rank_label(), e.entry_value])
			"flip":
				parts.append("разворот %s" % KaravanRules.direction_label(e.direction))
			"remove":
				parts.append("убрана карта")
			"joker":
				parts.append("джокер: %s" % ("масть" if e.get("by", "") == "suit" else "ранг"))
			"reset":
				pass
	return ", ".join(parts)
