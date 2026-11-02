class_name MatchState
extends RefCounted
## Состояние партии: колода, руки, шесть караванов. Без UI и без FSM.

const CARAVAN_COUNT := 3
const HAND_SIZE := 8
const INITIAL_PLACEMENTS := 3

enum Side { PLAYER, DEALER }
enum Result { NONE, PLAYER, DEALER }

var deck: DeckData
var player_hand: Array[CardData] = []
var dealer_hand: Array[CardData] = []
var player_caravans: Array[CaravanState] = []
var dealer_caravans: Array[CaravanState] = []
var turn := 1


func start(seed_value: int = 0) -> void:
	deck = CardCatalog.standard_deck(seed_value)
	player_hand.clear()
	dealer_hand.clear()
	player_caravans.clear()
	dealer_caravans.clear()

	for i in CARAVAN_COUNT:
		var p := CaravanState.new()
		p.owner_id = Side.PLAYER
		player_caravans.append(p)
		var d := CaravanState.new()
		d.owner_id = Side.DEALER
		dealer_caravans.append(d)

	turn = 1
	for i in HAND_SIZE:
		draw_one(Side.PLAYER)
		draw_one(Side.DEALER)


func hand(side: int) -> Array[CardData]:
	return player_hand if side == Side.PLAYER else dealer_hand


func caravans(side: int) -> Array[CaravanState]:
	return player_caravans if side == Side.PLAYER else dealer_caravans


## Все шесть караванов в порядке, который понимает KaravanRules:
## 0..2 — игрок, 3..5 — дилер.
func all_caravans() -> Array[CaravanState]:
	var out: Array[CaravanState] = []
	out.append_array(player_caravans)
	out.append_array(dealer_caravans)
	return out


func draw_one(side: int) -> CardData:
	var card := deck.draw()
	if card != null:
		hand(side).append(card)
	return card


func draw_to_hand_size(side: int) -> void:
	while hand(side).size() < HAND_SIZE:
		if draw_one(side) == null:
			break


func take_card(side: int, card: CardData) -> bool:
	var cards := hand(side)
	var index := cards.find(card)
	if index < 0:
		return false
	cards.remove_at(index)
	return true


func opponent(side: int) -> int:
	return Side.DEALER if side == Side.PLAYER else Side.PLAYER


func initial_count(side: int) -> int:
	var n := 0
	for caravan in caravans(side):
		if not caravan.is_empty():
			n += 1
	return n


func initial_done() -> bool:
	return initial_count(Side.PLAYER) >= INITIAL_PLACEMENTS and initial_count(Side.DEALER) >= INITIAL_PLACEMENTS


func sold(side: int) -> int:
	return KaravanRules.sold_count(caravans(side), caravans(opponent(side)))


func winner_side() -> int:
	var result := KaravanRules.winner(player_caravans, dealer_caravans)
	if result > 0:
		return Result.PLAYER
	if result < 0:
		return Result.DEALER
	return Result.NONE


func is_out_of_cards() -> bool:
	return deck.remaining() == 0 and deck.discard_size() == 0 and player_hand.is_empty() and dealer_hand.is_empty()


## Оценка «кто лучше» по проданным караванам — для ничьей по кончине колоды.
func compare_sold() -> int:
	var p := sold(Side.PLAYER)
	var d := sold(Side.DEALER)
	if p > d:
		return Result.PLAYER
	if d > p:
		return Result.DEALER
	return Result.NONE
