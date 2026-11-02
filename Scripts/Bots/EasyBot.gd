class_name EasyBot
extends BotBase
## Простой дилер: первый легальный ход, числовые карты в приоритете.


func choose_move(state: MatchState, side: int) -> Dictionary:
	var moves := all_moves(state, side)
	if moves.is_empty():
		return {}

	for move in moves:
		if (move["card"] as CardData).is_numeric():
			return move
	return moves[0]
