class_name CaravanState
extends RefCounted
## Состояние одного каравана (стопки). Чистые данные, без UI.
##
## suit      — текущая масть каравана (её задаёт первая карта, меняет любая
##             карта другой масти или дама);
## direction — 0 пока направление не задано, +1 по возрастанию, -1 по убыванию;
## entries   — карты в порядке выкладывания.

const BUST_LIMIT := 26

var owner_id: int = 0
var suit: int = CardData.Suit.NONE
var direction: int = 0
var entries: Array[KaravanEntry] = []


func value() -> int:
	var total := 0
	for e in entries:
		total += e.value()
	return total


func numeric_entries() -> Array[KaravanEntry]:
	var out: Array[KaravanEntry] = []
	for e in entries:
		if e.base != null and e.base.is_numeric():
			out.append(e)
	return out


func numeric_count() -> int:
	return numeric_entries().size()


func last_numeric_entry() -> KaravanEntry:
	var nums := numeric_entries()
	return nums[nums.size() - 1] if not nums.is_empty() else null


func is_empty() -> bool:
	return entries.is_empty()


func is_in_range() -> bool:
	var v := value()
	return v >= 21 and v <= BUST_LIMIT


func is_busted() -> bool:
	return value() > BUST_LIMIT


func clear() -> void:
	entries.clear()
	suit = CardData.Suit.NONE
	direction = 0


func clone() -> CaravanState:
	var c := CaravanState.new()
	c.owner_id = owner_id
	c.suit = suit
	c.direction = direction
	for e in entries:
		c.entries.append(e.clone())
	return c


func describe() -> String:
	var dir := "—"
	if direction > 0:
		dir = "↑"
	elif direction < 0:
		dir = "↓"
	var parts: Array[String] = []
	for e in entries:
		parts.append(e.describe())
	return "Караван(%s, %s, %d): %s" % [CardData.SUIT_NAME_RU.get(suit, "—"), dir, value(), ", ".join(parts)]
