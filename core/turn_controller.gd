class_name TurnController
extends RefCounted
## The rules engine. Validates intents, applies them to GameState and appends
## events to state.events. UI and bots only ever call validate() / submit().

var state: GameState


## Sets up a match and starts round 1 (seat 0 is up, in the draw step).
## deck_cards are the physical cards (see Deck.build_card_list). Pass
## shuffle = false to keep their order, e.g. in tests: deck_cards[0] is dealt first.
func _init(match_seed: int, player_count: int, deck_cards: Array[CardData], shuffle: bool = true) -> void:
	assert(player_count >= Config.MIN_PLAYERS and player_count <= Config.MAX_PLAYERS,
			"Player count must be %d-%d" % [Config.MIN_PLAYERS, Config.MAX_PLAYERS])
	state = GameState.new(match_seed, player_count)
	state.deck = Deck.new(state.rng, deck_cards)
	if shuffle:
		state.deck.shuffle()
	_emit(GameEvents.MatchStarted.new(match_seed, player_count))
	_deal_starting_hands()
	_start_round(1)


# --- Public API ------------------------------------------------------------

## Empty string if the intent is legal right now, otherwise the reason it isn't.
func validate(intent: Intent) -> String:
	if state.is_over():
		return "The match is over"
	if intent.seat != state.current_seat:
		return "It is not seat %d's turn" % intent.seat
	if intent is Intents.DrawCard:
		return _validate_draw()
	if intent is Intents.DiscardCard:
		return _validate_discard(intent as Intents.DiscardCard)
	if intent is Intents.PlayCard:
		return _validate_play(intent as Intents.PlayCard)
	if intent is Intents.EndTurn or intent is Intents.Timeout:
		return ""
	return "Unknown intent"


## Applies the intent if legal. Returns "" on success, otherwise the reason it was rejected.
func submit(intent: Intent) -> String:
	var error: String = validate(intent)
	if not error.is_empty():
		return error
	if intent is Intents.DrawCard:
		_apply_draw()
	elif intent is Intents.DiscardCard:
		_apply_discard((intent as Intents.DiscardCard).hand_index)
	elif intent is Intents.PlayCard:
		_apply_play(intent as Intents.PlayCard)
	elif intent is Intents.EndTurn or intent is Intents.Timeout:
		# A timeout just ends the turn; anything drawn so far stays in hand.
		_end_turn()
	return ""


func can_draw() -> bool:
	return _validate_draw().is_empty()


func can_discard() -> bool:
	return state.phase == GameState.Phase.DRAW \
			and state.discards_this_turn < Config.MAX_DISCARDS_PER_TURN \
			and not state.current_player().hand.is_empty()


## Deals typed damage to a living player. Eliminations are resolved by the caller
## once the whole action is done, so simultaneous hits can end in a draw.
func deal_damage(source_seat: int, target_seat: int, base_damage: int, element: Element.Type) -> int:
	var target: PlayerState = state.player(target_seat)
	if not target.is_alive:
		return 0
	var multiplier: float = TypeChart.multiplier(element, target.element)
	var damage: int = TypeChart.apply(base_damage, element, target.element)
	target.hp = maxi(0, target.hp - damage)
	_emit(GameEvents.DamageDealt.new(source_seat, target_seat, element, base_damage, multiplier, damage, target.hp))
	return damage


func add_heat(seat: int, amount: int, reason: StringName) -> void:
	var p: PlayerState = state.player(seat)
	_set_heat(p, p.heat + amount, reason)


# --- Validation ------------------------------------------------------------

func _validate_draw() -> String:
	if state.phase != GameState.Phase.DRAW:
		return "Drawing is over once you play a card"
	if state.draws_this_turn >= Config.MAX_DRAWS_PER_TURN:
		return "Already drew %d cards this turn" % Config.MAX_DRAWS_PER_TURN
	if state.current_player().hand.size() >= Config.HAND_CAP:
		return "Hand is full (%d): discard a card first" % Config.HAND_CAP
	if state.deck.draw_pile.is_empty() and state.deck.discard_pile.is_empty():
		return "No cards left to draw"
	return ""


func _validate_discard(intent: Intents.DiscardCard) -> String:
	if state.phase != GameState.Phase.DRAW:
		return "Discarding is over once you play a card"
	if state.discards_this_turn >= Config.MAX_DISCARDS_PER_TURN:
		return "Already discarded this turn"
	if intent.hand_index < 0 or intent.hand_index >= state.current_player().hand.size():
		return "Hand index %d is out of range" % intent.hand_index
	return ""


func _validate_play(intent: Intents.PlayCard) -> String:
	var hand: Array[CardData] = state.current_player().hand
	if intent.hand_index < 0 or intent.hand_index >= hand.size():
		return "Hand index %d is out of range" % intent.hand_index
	var card: CardData = hand[intent.hand_index]
	if not EffectRegistry.has_effect(card.effect_id):
		return "%s is not implemented yet" % card.display_name
	if state.slots_played.has(card.slot()):
		return "Already played a slot %d card this turn" % card.slot()
	if not card.allows_mode(intent.mode):
		return "%s can't be played in that mode" % card.display_name
	if intent.mode == CardData.Mode.TARGETED:
		if intent.target_seat < 0 or intent.target_seat >= state.players.size():
			return "Target seat %d does not exist" % intent.target_seat
		if intent.target_seat == intent.seat:
			return "You can't target yourself"
		if not state.player(intent.target_seat).is_alive:
			return "Target seat %d is eliminated" % intent.target_seat
	return ""


# --- Turn flow ---------------------------------------------------------------

func _deal_starting_hands() -> void:
	for i: int in Config.STARTING_HAND_SIZE:
		for p: PlayerState in state.players:
			p.hand.append_array(_draw(1))


func _start_round(round_number: int) -> void:
	state.round_number = round_number
	var start_seat: int = _starting_seat(round_number)
	state.turn_queue.clear()
	var count: int = state.players.size()
	for offset: int in count:
		var seat: int = (start_seat + offset) % count
		if state.player(seat).is_alive:
			state.turn_queue.append(seat)
	_emit(GameEvents.RoundStarted.new(round_number, start_seat, state.joker_damage()))
	_start_next_turn()


## Seat 1 starts round 1, seat 2 round 2, and so on (§3). Rotation follows the
## original seat numbers; if the scheduled seat is eliminated, the next living seat
## clockwise starts instead.
func _starting_seat(round_number: int) -> int:
	var count: int = state.players.size()
	for offset: int in count:
		var seat: int = (round_number - 1 + offset) % count
		if state.player(seat).is_alive:
			return seat
	return -1


func _start_next_turn() -> void:
	while not state.turn_queue.is_empty():
		var seat: int = state.turn_queue.pop_front()
		# Players eliminated earlier this round lose their turn.
		if state.player(seat).is_alive:
			_begin_turn(seat)
			return
	_end_round()


## Each turn opens with the draw step (§3): draw up to 3 cards one at a time and
## optionally discard 1 card from hand, in any order. Playing a card ends it.
func _begin_turn(seat: int) -> void:
	state.current_seat = seat
	state.slots_played.clear()
	state.draws_this_turn = 0
	state.discards_this_turn = 0
	state.phase = GameState.Phase.DRAW
	_emit(GameEvents.TurnStarted.new(seat))


func _apply_draw() -> void:
	var p: PlayerState = state.current_player()
	var drawn: Array[CardData] = _draw(1)
	p.hand.append_array(drawn)
	state.draws_this_turn += 1
	_emit(GameEvents.CardsDrawn.new(p.seat, drawn))


func _apply_discard(hand_index: int) -> void:
	var p: PlayerState = state.current_player()
	var card: CardData = p.hand[hand_index]
	p.hand.remove_at(hand_index)
	state.deck.discard([card])
	state.discards_this_turn += 1
	_emit(GameEvents.CardDiscarded.new(p.seat, card))


func _apply_play(intent: Intents.PlayCard) -> void:
	var p: PlayerState = state.current_player()
	var card: CardData = p.hand[intent.hand_index]
	p.hand.remove_at(intent.hand_index)
	state.phase = GameState.Phase.PLAY
	state.slots_played.append(card.slot())

	var targets: Array[int] = []
	if intent.mode == CardData.Mode.TARGETED:
		targets.append(intent.target_seat)
		_emit(GameEvents.CardPlayed.new(p.seat, card, intent.mode, intent.target_seat))
	else:
		# Collective plays hit every living player, including the one who played it (§4).
		targets = state.alive_seats()
		_emit(GameEvents.CardPlayed.new(p.seat, card, intent.mode, -1))

	add_heat(p.seat, Heat.for_card(card, intent.mode), &"card")
	EffectRegistry.get_effect(card.effect_id).resolve(EffectContext.new(self, card, p.seat, intent.mode, targets))
	state.deck.discard([card])

	_resolve_eliminations()
	if state.is_over():
		return
	if not p.is_alive:
		_end_turn()


## Ending the turn without playing a card is a skip (+1 Heat). A timeout counts the
## same way: it is only a skip if nothing was played.
func _end_turn() -> void:
	var p: PlayerState = state.current_player()
	if state.slots_played.is_empty() and p.is_alive:
		_emit(GameEvents.PlayerSkipped.new(p.seat))
		add_heat(p.seat, Config.SKIP_HEAT, &"skip")
	_emit(GameEvents.TurnEnded.new(p.seat))
	_start_next_turn()


func _end_round() -> void:
	_joker_attack()
	_resolve_eliminations()
	if state.is_over():
		return
	_emit(GameEvents.RoundEnded.new(state.round_number))
	_start_round(state.round_number + 1)


## The Joker hits every living player tied for the most Heat, for full damage each
## (§5). Heat resets only for players actually hit.
func _joker_attack() -> void:
	var alive: Array[int] = state.alive_seats()
	var max_heat: int = -1
	for seat: int in alive:
		max_heat = maxi(max_heat, state.player(seat).heat)
	var targets: Array[int] = []
	for seat: int in alive:
		if state.player(seat).heat == max_heat:
			targets.append(seat)

	var damage: int = state.joker_damage()
	_emit(GameEvents.JokerAttacked.new(state.round_number, state.joker.element, damage, targets))
	for seat: int in targets:
		deal_damage(GameEvent.JOKER_SEAT, seat, damage, state.joker.element)
		_set_heat(state.player(seat), 0, &"joker_hit")


# --- Elimination and match end -------------------------------------------------

## Eliminates everyone at 0 HP at once. If that leaves one player, they win; if it
## leaves nobody (all remaining players died to the same card or Joker attack), the
## match is a draw (§7).
func _resolve_eliminations() -> void:
	var eliminated_any: bool = false
	for p: PlayerState in state.players:
		if p.is_alive and p.hp <= 0:
			p.is_alive = false
			eliminated_any = true
			_emit(GameEvents.PlayerEliminated.new(p.seat, state.round_number))
	if not eliminated_any:
		return
	var alive: Array[int] = state.alive_seats()
	if alive.size() == 1:
		_finish(alive[0], false)
	elif alive.is_empty():
		_finish(-1, true)


func _finish(winner_seat: int, is_draw: bool) -> void:
	state.winner_seat = winner_seat
	state.is_draw = is_draw
	state.phase = GameState.Phase.OVER
	_emit(GameEvents.MatchEnded.new(winner_seat, is_draw))


# --- Helpers -----------------------------------------------------------------

func _draw(count: int) -> Array[CardData]:
	var reshuffles_before: int = state.deck.reshuffle_count
	var drawn: Array[CardData] = state.deck.draw(count)
	if state.deck.reshuffle_count != reshuffles_before:
		_emit(GameEvents.DeckReshuffled.new(state.deck.last_reshuffle_size))
	return drawn


func _set_heat(p: PlayerState, value: int, reason: StringName) -> void:
	if p.heat == value:
		return
	var old: int = p.heat
	p.heat = value
	_emit(GameEvents.HeatChanged.new(p.seat, old, value, reason))


func _emit(event: GameEvent) -> void:
	state.events.append(event)
