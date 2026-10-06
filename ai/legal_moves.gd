class_name LegalMoves
extends RefCounted
## Every legal intent for the current player, checked against the rules engine.


static func for_current_player(tc: TurnController) -> Array[Intent]:
	var moves: Array[Intent] = []
	if tc.state.is_over():
		return moves
	var seat: int = tc.state.current_seat
	if tc.can_draw():
		moves.append(Intents.DrawCard.new(seat))
	if tc.can_discard():
		for i: int in tc.state.current_player().hand.size():
			moves.append(Intents.DiscardCard.new(seat, i))
	moves.append_array(plays(tc))
	moves.append(Intents.EndTurn.new(seat))
	return moves


## Every legal card play: each card, mode, target and (if the card asks) type choice.
static func plays(tc: TurnController) -> Array[Intent]:
	var moves: Array[Intent] = []
	var state: GameState = tc.state
	var seat: int = state.current_seat
	var hand: Array[CardData] = state.current_player().hand
	var others: Array[int] = state.alive_seats().filter(func(s: int) -> bool: return s != seat)
	for i: int in hand.size():
		var card: CardData = hand[i]
		var choices: Array = [-1]
		if EffectRegistry.get_effect(card.effect_id).needs_element_choice():
			choices = Element.Type.values()
		for mode: CardData.Mode in [CardData.Mode.COLLECTIVE, CardData.Mode.TARGETED]:
			if not card.allows_mode(mode):
				continue
			var targets: Array[int] = others
			if mode == CardData.Mode.COLLECTIVE:
				targets = [-1]
			for target: int in targets:
				for choice: int in choices:
					var intent := Intents.PlayCard.new(seat, i, mode, target, choice)
					if tc.validate(intent).is_empty():
						moves.append(intent)
	return moves
