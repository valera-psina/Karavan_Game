class_name DeckData
extends Resource
## Колода и сброс. Рука игрока живёт в PlayerState (шаг 4), здесь только
## «откуда тянуть» и «куда сбрасывать».

@export var brand: StringName = &"standard"

var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []


func setup(cards: Array[CardData]) -> void:
	draw_pile.clear()
	discard_pile.clear()
	draw_pile.append_array(cards)


## Тасование Фишера—Йетса. seed_value = 0 → случайный, иначе детерминированный
## (нужно для тестов и для воспроизводимых партий).
func shuffle(seed_value: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	for i in range(draw_pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = tmp


## Берёт верхнюю карту. Если колода пуста — автоматически перемешивает сброс.
## Возвращает null, если карт нет вообще.
func draw() -> CardData:
	if draw_pile.is_empty() and not discard_pile.is_empty():
		reshuffle_discard()
	if draw_pile.is_empty():
		return null
	return draw_pile.pop_back()


func discard(card: CardData) -> void:
	if card != null:
		discard_pile.append(card)


func reshuffle_discard() -> void:
	if discard_pile.is_empty():
		return
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	shuffle()


func remaining() -> int:
	return draw_pile.size()


func discard_size() -> int:
	return discard_pile.size()


func total() -> int:
	return draw_pile.size() + discard_pile.size()


func clone() -> DeckData:
	var d := DeckData.new()
	d.brand = brand
	d.draw_pile = draw_pile.duplicate()
	d.discard_pile = discard_pile.duplicate()
	return d
