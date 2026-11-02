class_name BotBase
extends RefCounted
## Общая база для дилеров. Бот ничего не мутирует — только предлагает ход.

## Возвращает {"card": CardData, "ci": int, "ei": int} или {} если ходов нет.
func choose_move(_state: MatchState, _side: int) -> Dictionary:
	return {}


func all_moves(state: MatchState, side: int) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	var all := state.all_caravans()
	for card in state.hand(side):
		for target in KaravanRules.legal_targets(card, all):
			moves.append({"card": card, "ci": target.x, "ei": target.y})
	return moves


func clone_caravans(state: MatchState) -> Array[CaravanState]:
	var out: Array[CaravanState] = []
	for caravan in state.all_caravans():
		out.append(caravan.clone())
	return out


func index_range(side: int) -> Array[int]:
	if side == MatchState.Side.PLAYER:
		return [0, 1, 2]
	return [MatchState.CARAVAN_COUNT, MatchState.CARAVAN_COUNT + 1, MatchState.CARAVAN_COUNT + 2]


## Пробный ход на копии стола: возвращает копии караванов после apply.
func simulate(state: MatchState, move: Dictionary) -> Array[CaravanState]:
	var clones := clone_caravans(state)
	KaravanRules.apply(move["card"], clones, move["ci"], move["ei"])
	return clones
