class_name KaravanRules
extends RefCounted
## Чистая логика «Каравана». Не знает ни про узлы, ни про анимации, ни про
## очередь хода — только правила: можно ли положить карту и что произойдёт.
##
## Точки входа:
##   can_play(card, caravans, caravan_index, entry_index) -> bool
##   apply(card, caravans, caravan_index, entry_index)    -> Array[Dictionary]
##   legal_targets(card, caravans)                        -> Array[Vector2i]
##
## apply() не трогает колоду и руку: сыгранную карту в сброс отправляет
## контроллер партии (шаг 4). Возвращаемые события нужны UI для анимаций.

const TARGET_MIN := 21
const TARGET_MAX := 26

## Каждый король удваивает номинал (два короля = x4).
const KINGS_STACK := true
## Джокер чистит совпадения по всему столу, а не только в целевом караване.
const JOKER_PURGES_WHOLE_TABLE := true


# --------------------------------------------------------------- проверки

static func can_place_numeric(caravan: CaravanState, card: CardData) -> bool:
	if card == null or not card.is_numeric():
		return false

	var nums := caravan.numeric_entries()
	if nums.is_empty():
		return true
	# Вторая числовая карта задаёт направление — ей можно любую.
	if caravan.direction == 0:
		return true
	# Карта той же масти кладётся в любом порядке.
	if card.suit == caravan.suit:
		return true

	var last_rank: int = nums[nums.size() - 1].base.rank
	if caravan.direction > 0:
		return card.rank > last_rank
	return card.rank < last_rank


static func can_play(card: CardData, caravans: Array[CaravanState], caravan_index: int, entry_index: int = -1) -> bool:
	if card == null:
		return false
	if caravan_index < 0 or caravan_index >= caravans.size():
		return false

	var caravan: CaravanState = caravans[caravan_index]

	if card.is_joker():
		if entry_index < 0 or entry_index >= caravan.entries.size():
			return false
		var target := caravan.entries[entry_index]
		return target.base != null and target.base.is_numeric()

	if card.is_face():
		return entry_index >= 0 and entry_index < caravan.entries.size()

	# Числовая карта кладётся в конец каравана, без выбора позиции.
	return entry_index < 0 and can_place_numeric(caravan, card)


## Все легальные цели для карты: Vector2i(индекс каравана, индекс позиции).
## Для числовых карт entry = -1.
static func legal_targets(card: CardData, caravans: Array[CaravanState]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if card == null:
		return out

	if card.is_numeric():
		for i in caravans.size():
			if can_place_numeric(caravans[i], card):
				out.append(Vector2i(i, -1))
		return out

	for i in caravans.size():
		for e in caravans[i].entries.size():
			if can_play(card, caravans, i, e):
				out.append(Vector2i(i, e))
	return out


# ------------------------------------------------------------------- ходы

## Применяет карту. Возвращает список событий (пустой = ход нелегален).
static func apply(card: CardData, caravans: Array[CaravanState], caravan_index: int, entry_index: int = -1) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not can_play(card, caravans, caravan_index, entry_index):
		return events

	var caravan: CaravanState = caravans[caravan_index]

	if card.is_numeric():
		_place_numeric(caravan, card, caravan_index, events)
	elif card.kind == CardData.Kind.KING:
		caravan.entries[entry_index].attachments.append(card)
		events.append({
			"type": "attach", "caravan": caravan_index, "entry_index": entry_index,
			"card": card, "entry_value": caravan.entries[entry_index].value(),
		})
	elif card.kind == CardData.Kind.QUEEN:
		var entry := caravan.entries[entry_index]
		entry.attachments.append(card)
		caravan.direction = -caravan.direction
		caravan.suit = card.suit
		events.append({
			"type": "attach", "caravan": caravan_index, "entry_index": entry_index,
			"card": card, "entry_value": entry.value(),
		})
		events.append({
			"type": "flip", "caravan": caravan_index, "direction": caravan.direction,
			"suit": caravan.suit,
		})
	elif card.kind == CardData.Kind.JACK:
		_remove_entry(caravans, caravan_index, entry_index, "jack", events)
	elif card.is_joker():
		_purge_with_joker(card, caravans, caravan_index, entry_index, events)

	return events


static func _place_numeric(caravan: CaravanState, card: CardData, caravan_index: int, events: Array[Dictionary]) -> void:
	var before := caravan.numeric_entries()
	var was_empty := before.is_empty()
	var last_rank: int = 0 if was_empty else before[before.size() - 1].base.rank

	var entry := KaravanEntry.new(card)
	caravan.entries.append(entry)
	events.append({
		"type": "place", "caravan": caravan_index,
		"entry_index": caravan.entries.size() - 1, "card": card,
	})

	if was_empty:
		caravan.suit = card.suit
		caravan.direction = 0
	else:
		if before.size() == 1 and caravan.direction == 0:
			caravan.direction = signi(card.rank - last_rank)
		if card.suit != caravan.suit:
			caravan.suit = card.suit


static func _remove_entry(caravans: Array[CaravanState], caravan_index: int, entry_index: int, reason: String, events: Array[Dictionary]) -> void:
	var caravan: CaravanState = caravans[caravan_index]
	var removed := caravan.entries[entry_index]
	caravan.entries.remove_at(entry_index)
	events.append({
		"type": "remove", "caravan": caravan_index, "entry_index": entry_index,
		"entry": removed, "reason": reason,
	})
	_after_removal(caravan, caravan_index, events)


static func _purge_with_joker(joker: CardData, caravans: Array[CaravanState], caravan_index: int, entry_index: int, events: Array[Dictionary]) -> void:
	var target: CardData = caravans[caravan_index].entries[entry_index].base
	var by_suit := target.kind == CardData.Kind.ACE

	for ci in caravans.size():
		if not JOKER_PURGES_WHOLE_TABLE and ci != caravan_index:
			continue
		var caravan: CaravanState = caravans[ci]
		for ei in range(caravan.entries.size() - 1, -1, -1):
			var base: CardData = caravan.entries[ei].base
			if base == null:
				continue
			var matches := (base.suit == target.suit) if by_suit else (base.rank == target.rank)
			if matches:
				_remove_entry(caravans, ci, ei, "joker", events)

	events.append({
		"type": "joker", "caravan": caravan_index, "entry_index": entry_index,
		"by": "suit" if by_suit else "rank", "value": target.suit if by_suit else target.rank,
		"card": joker,
	})


## После удаления карт караван может опустеть — тогда сбрасываем масть
## и направление. Иначе состояние (масть/направление) сохраняется.
static func _after_removal(caravan: CaravanState, caravan_index: int, events: Array[Dictionary]) -> void:
	if caravan.entries.is_empty():
		caravan.suit = CardData.Suit.NONE
		caravan.direction = 0
		events.append({"type": "reset", "caravan": caravan_index})


# ------------------------------------------------------------------ счёт

static func effective_value(caravan: CaravanState) -> int:
	return 0 if caravan.is_busted() else caravan.value()


static func is_in_range(caravan: CaravanState) -> bool:
	return caravan.is_in_range()


static func is_sold(caravan: CaravanState, opponent: CaravanState) -> bool:
	if caravan == null or opponent == null:
		return false
	if not caravan.is_in_range():
		return false
	return caravan.value() > effective_value(opponent)


static func sold_count(own: Array[CaravanState], enemy: Array[CaravanState]) -> int:
	var n := 0
	for i in mini(own.size(), enemy.size()):
		if is_sold(own[i], enemy[i]):
			n += 1
	return n


## 1 — победил первый, -1 — второй, 0 — ещё не решено / ничья.
static func winner(own: Array[CaravanState], enemy: Array[CaravanState]) -> int:
	var a := sold_count(own, enemy)
	var b := sold_count(enemy, own)
	if a >= 2 and a > b:
		return 1
	if b >= 2 and b > a:
		return -1
	return 0


static func direction_label(direction: int) -> String:
	if direction > 0:
		return "↑"
	if direction < 0:
		return "↓"
	return "—"
