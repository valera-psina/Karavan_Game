class_name HardBot
extends BotBase
## Умный дилер: считает, что будет со столами после хода.
##   * добивает свои караваны до 21–26 и не перебирает;
##   * бьёт валетом караваны игрока, которые уже в зачётной зоне;
##   * короля кладёт на свой лучший караван, если не получается перебор;
##   * джокером чистит опасные караваны игрока.

const REWARD_RANGE := 45.0
const PENALTY_BUST := 80.0
const REWARD_BREAK_ENEMY := 95.0
const PENALTY_GIVE_ENEMY_RANGE := 30.0


func choose_move(state: MatchState, side: int) -> Dictionary:
	var moves := all_moves(state, side)
	if moves.is_empty():
		return {}

	# Перегруженный караван: сначала роспуск, если правила позволяют.
	if state.turn > 1:
		var worst := -1
		var worst_value := -1.0
		var mine := state.caravans(side)
		for i in MatchState.CARAVAN_COUNT:
			var caravan := mine[i]
			if not caravan.is_empty() and caravan.is_busted() and caravan.value() > worst_value:
				worst_value = caravan.value()
				worst = i
		if worst >= 0:
			return {"action": "discard_caravan", "ci": worst}

	var best: Dictionary = {}
	var best_score := -INF

	for move in moves:
		var score := _score(state, side, move)
		if score > best_score:
			best_score = score
			best = move
	return best


func _score(state: MatchState, side: int, move: Dictionary) -> float:
	var card: CardData = move["card"]
	var ci: int = move["ci"]
	var ei: int = move["ei"]
	var after := simulate(state, move)

	var my_range := index_range(side)
	var enemy_range := index_range(MatchState.Side.PLAYER if side == MatchState.Side.DEALER else MatchState.Side.DEALER)
	var score := 0.0

	var my_before := state.caravans(side)
	var enemy_before := state.caravans(MatchState.Side.PLAYER if side == MatchState.Side.DEALER else MatchState.Side.DEALER)

	for i in MatchState.CARAVAN_COUNT:
		var my_old := my_before[i]
		var my_new := after[my_range[i]]
		var enemy_old := enemy_before[i]
		var enemy_new := after[enemy_range[i]]

		if not my_old.is_in_range() and my_new.is_in_range():
			score += REWARD_RANGE
		if my_old.is_in_range() and not my_new.is_in_range():
			score -= REWARD_RANGE * 1.4
		if my_new.is_busted():
			score -= PENALTY_BUST
		if my_new.is_in_range():
			score += my_new.value() * 0.15

		if enemy_old.is_in_range() and not enemy_new.is_in_range():
			score += REWARD_BREAK_ENEMY
		if not enemy_old.is_in_range() and enemy_new.is_in_range():
			score -= PENALTY_GIVE_ENEMY_RANGE

	# Осмысленные эффекты поверх общего счёта.
	var target_owner_is_enemy := enemy_range.has(ci)
	var target_old: CaravanState = enemy_before[enemy_range.find(ci)] if target_owner_is_enemy else my_before[my_range.find(ci)]
	var target_new: CaravanState = after[ci]

	match card.kind:
		CardData.Kind.JACK:
			if target_owner_is_enemy and target_old.is_in_range():
				score += 40.0
		CardData.Kind.KING:
			if not target_owner_is_enemy:
				if target_new.value() <= KaravanRules.TARGET_MAX and target_new.value() > target_old.value():
					score += 25.0
				elif target_new.value() > KaravanRules.TARGET_MAX:
					score -= 45.0
		CardData.Kind.QUEEN:
			score -= 5.0
		CardData.Kind.JOKER:
			if target_owner_is_enemy:
				score += 15.0

	if card.is_numeric() and target_owner_is_enemy:
		score -= 10.0

	# Немного шума, чтобы партии не повторялись.
	score += randf_range(0.0, 6.0)
	return score
