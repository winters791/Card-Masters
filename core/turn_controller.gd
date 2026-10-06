class_name TurnController
extends RefCounted
## The rules engine. Validates intents, applies them to GameState and appends
## events to state.events. UI and bots only ever call validate() / submit().

var state: GameState


## Sets up a match and starts round 1 (seat 0 is already holding its draw).
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
	if intent is Intents.KeepCards:
		return _validate_keep(intent as Intents.KeepCards)
	if intent is Intents.PlayCard:
		return _validate_play(intent as Intents.PlayCard)
	if intent is Intents.EndTurn:
		if state.phase != GameState.Phase.PLAY:
			return "Choose which cards to keep first"
		return ""
	if intent is Intents.Timeout:
		return ""
	return "Unknown intent"


## Applies the intent if legal. Returns "" on success, otherwise the reason it was rejected.
func submit(intent: Intent) -> String:
	var error: String = validate(intent)
	if not error.is_empty():
		return error
	if intent is Intents.KeepCards:
		_apply_keep((intent as Intents.KeepCards).keep_indices)
	elif intent is Intents.PlayCard:
		_apply_play(intent as Intents.PlayCard)
	elif intent is Intents.EndTurn:
		_end_turn()
	elif intent is Intents.Timeout:
		_apply_timeout()
	return ""


## How many of the pending drawn cards the current player must keep.
func keep_count() -> int:
	var room: int = maxi(0, Config.HAND_CAP - state.current_player().hand.size())
	return mini(mini(Config.KEEP_PER_TURN, state.pending_draw.size()), room)


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

func _validate_keep(intent: Intents.KeepCards) -> String:
	if state.phase != GameState.Phase.KEEP:
		return "Not choosing cards to keep right now"
	var needed: int = keep_count()
	if intent.keep_indices.size() != needed:
		return "Must keep exactly %d card(s)" % needed
	var seen: Dictionary[int, bool] = {}
	for index: int in intent.keep_indices:
		if index < 0 or index >= state.pending_draw.size():
			return "Keep index %d is out of range" % index
		if seen.has(index):
			return "Keep index %d is repeated" % index
		seen[index] = true
	return ""


func _validate_play(intent: Intents.PlayCard) -> String:
	if state.phase != GameState.Phase.PLAY:
		return "Choose which cards to keep first"
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


## Seat 1 starts round 1, seat 2 round 2, and so on (§3).
# RULE-ASSUMPTION: rotation follows the original seat numbers; if the scheduled
# seat is eliminated, the next living seat clockwise starts instead.
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


# RULE-ASSUMPTION: the draw-3-keep-2 step happens at the start of the turn, before
# any card is played.
func _begin_turn(seat: int) -> void:
	state.current_seat = seat
	state.slots_played.clear()
	_emit(GameEvents.TurnStarted.new(seat))
	state.pending_draw = _draw(Config.DRAW_PER_TURN)
	_emit(GameEvents.CardsDrawn.new(seat, state.pending_draw.duplicate()))
	state.phase = GameState.Phase.KEEP
	# Nothing to choose (hand at the cap, or the deck is empty): skip straight to play.
	if keep_count() == 0:
		var none: Array[int] = []
		_apply_keep(none)


# RULE-ASSUMPTION: the hand cap is enforced at the keep step. A player near the cap
# keeps only as many drawn cards as fit; the rest are discarded.
func _apply_keep(keep_indices: Array[int]) -> void:
	var p: PlayerState = state.current_player()
	var discarded: Array[CardData] = []
	for i: int in state.pending_draw.size():
		if keep_indices.has(i):
			continue
		discarded.append(state.pending_draw[i])
	for index: int in keep_indices:
		p.hand.append(state.pending_draw[index])
	state.deck.discard(discarded)
	state.pending_draw.clear()
	_emit(GameEvents.CardsKept.new(p.seat, keep_indices.size(), discarded.size()))
	state.phase = GameState.Phase.PLAY


func _apply_play(intent: Intents.PlayCard) -> void:
	var p: PlayerState = state.current_player()
	var card: CardData = p.hand[intent.hand_index]
	p.hand.remove_at(intent.hand_index)
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


# RULE-ASSUMPTION: a timeout keeps the first drawn cards if the keep choice is still
# open, then ends the turn. It only costs skip Heat if no card was played.
func _apply_timeout() -> void:
	if state.phase == GameState.Phase.KEEP:
		var first: Array[int] = []
		for i: int in keep_count():
			first.append(i)
		_apply_keep(first)
	_end_turn()


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
## leaves nobody, the match is a draw (§7).
# RULE-ASSUMPTION: "the last two die to the same hit" generalises to any number of
# remaining players dying to one card or one Joker attack.
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
	state.pending_draw.clear()
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
