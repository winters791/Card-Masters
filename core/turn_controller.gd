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
			and not state.turn_restrictions.has(TurnRestriction.NO_DISCARD) \
			and not state.current_player().hand.is_empty()


## Deals typed damage to a living player. Eliminations are resolved by the caller
## once the whole action is done, so simultaneous hits can end in a draw.
## A rotted target's resist is halved, which uses up the Rot.
func deal_damage(source_seat: int, target_seat: int, base_damage: int, element: Element.Type,
		cause: StringName = &"card") -> int:
	var target: PlayerState = state.player(target_seat)
	if not target.is_alive:
		return 0
	var multiplier: float = TypeChart.multiplier(element, target.element)
	if target.is_rotted and multiplier == Config.RESISTED_MULTIPLIER:
		multiplier = Config.ROT_RESIST_MULTIPLIER
		target.is_rotted = false
		_emit(GameEvents.StatusEnded.new(target_seat, Status.ROT, &"triggered"))
	# Fractional damage rounds down (§2).
	var damage: int = floori(base_damage * multiplier)
	target.hp = maxi(0, target.hp - damage)
	_emit(GameEvents.DamageDealt.new(source_seat, target_seat, element, base_damage, multiplier,
			damage, target.hp, cause))
	return damage


## Venom: a new poison stack ticking each round end for `rounds` rounds.
func apply_poison(seat: int, damage: int, rounds: int, source_seat: int) -> void:
	var p: PlayerState = state.player(seat)
	if not p.is_alive:
		return
	p.poisons.append(DotStack.new(damage, rounds, source_seat))
	_emit(GameEvents.StatusApplied.new(seat, Status.POISON, source_seat))


## Scorch: a new burn stack ticking each round end until the player changes type.
func apply_burn(seat: int, damage: int, source_seat: int) -> void:
	var p: PlayerState = state.player(seat)
	if not p.is_alive:
		return
	p.burns.append(DotStack.new(damage, DotStack.UNTIL_REMOVED, source_seat))
	_emit(GameEvents.StatusApplied.new(seat, Status.BURN, source_seat))


## Rot doesn't stack: on an already rotted player it does nothing.
func apply_rot(seat: int, source_seat: int) -> void:
	var p: PlayerState = state.player(seat)
	if not p.is_alive or p.is_rotted:
		return
	p.is_rotted = true
	_emit(GameEvents.StatusApplied.new(seat, Status.ROT, source_seat))


## Changes a living player's type, unless they're Rooted (then it fails). Changing
## type puts out every burn on them (Scorch). Returns false if the change was blocked.
func change_element(seat: int, element: Element.Type) -> bool:
	var p: PlayerState = state.player(seat)
	if not p.is_alive:
		return false
	if state.is_rooted(seat):
		_emit(GameEvents.TypeChangeBlocked.new(seat))
		return false
	if p.element == element:
		return true
	var old: Element.Type = p.element
	p.element = element
	_emit(GameEvents.TypeChanged.new(seat, old, element))
	if not p.burns.is_empty():
		p.burns.clear()
		_emit(GameEvents.StatusEnded.new(seat, Status.BURN, &"type_changed"))
	return true


## Type Swap: both players trade types. If either is Rooted the whole swap fails.
func swap_elements(seat_a: int, seat_b: int) -> bool:
	var blocked: bool = false
	for seat: int in [seat_a, seat_b]:
		if state.is_rooted(seat):
			_emit(GameEvents.TypeChangeBlocked.new(seat))
			blocked = true
	if blocked:
		return false
	var element_a: Element.Type = state.player(seat_a).element
	change_element(seat_a, state.player(seat_b).element)
	change_element(seat_b, element_a)
	return true


## Puts a modifier on the Joker. Targeting and pattern modifiers replace the one in
## their slot; effects stack. Lock-On locks onto whoever is hottest right now
## (everyone tied), so the Heat of the Lock-On card itself already counts.
func add_joker_modifier(modifier_id: StringName, source_seat: int, params: Dictionary = {}) -> void:
	var joker: JokerState = state.joker
	var modifier := JokerModifier.new(modifier_id, source_seat, params)
	var replaced: JokerModifier = null
	match modifier.slot:
		JokerModifier.Slot.TARGETING:
			replaced = joker.targeting
			joker.targeting = modifier
		JokerModifier.Slot.PATTERN:
			replaced = joker.pattern
			joker.pattern = modifier
		JokerModifier.Slot.EFFECT:
			joker.effects.append(modifier)
	if modifier_id == JokerModifier.LOCK_ON:
		modifier.locked_seats = _hottest_alive()
	if replaced != null:
		_emit(GameEvents.JokerModifierEnded.new(replaced.id, &"replaced"))
	_emit(GameEvents.JokerModified.new(modifier_id, source_seat,
			replaced.id if replaced != null else &"", modifier.locked_seats.duplicate()))


## Ignite / Flood / Overgrow: the Joker's type. Persists until changed again.
func set_joker_element(element: Element.Type, source_seat: int) -> void:
	var old: Element.Type = state.joker.element
	if old == element:
		return
	state.joker.element = element
	_emit(GameEvents.JokerTypeChanged.new(old, element, source_seat))


## Rooted: the player's type can't change until the end of the next round. Rooting
## again only ever extends it.
func apply_root(seat: int, source_seat: int) -> void:
	var p: PlayerState = state.player(seat)
	if not p.is_alive:
		return
	p.rooted_until_round = maxi(p.rooted_until_round, state.round_number + 1)
	_emit(GameEvents.StatusApplied.new(seat, Status.ROOTED, source_seat))


## Restricts `seat`'s next turn. Repeats don't stack: a restriction is on or off.
func restrict_next_turn(seat: int, restriction: StringName) -> void:
	var p: PlayerState = state.player(seat)
	if not p.is_alive:
		return
	if not p.next_turn_restrictions.has(restriction):
		p.next_turn_restrictions.append(restriction)
	_emit(GameEvents.TurnRestricted.new(seat, restriction))


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
	if state.turn_restrictions.has(TurnRestriction.NO_DISCARD):
		return "Can't discard this turn (Dry Well)"
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
	var effect_error: String = EffectRegistry.get_effect(card.effect_id).validate_play(state, intent)
	if not effect_error.is_empty():
		return effect_error
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
	var p: PlayerState = state.player(seat)
	state.turn_restrictions = p.next_turn_restrictions.duplicate()
	p.next_turn_restrictions.clear()
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
	EffectRegistry.get_effect(card.effect_id).resolve(
			EffectContext.new(self, card, p.seat, intent.mode, targets, intent.chosen_element))
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


## Round end order (§6): traps, then burns, then poison, then the Joker attack.
## Eliminations are checked after each step; if the match ends, later steps don't run.
## All ticks within one step land together, so the last players dying in the same
## burn or poison step is a draw.
func _end_round() -> void:
	# Traps arrive with the trap family (Phase 2).
	for step: Callable in [_tick_burns, _tick_poisons, _joker_attack]:
		step.call()
		_resolve_eliminations()
		if state.is_over():
			return
	_expire_joker_modifiers()
	_expire_roots()
	_emit(GameEvents.RoundEnded.new(state.round_number))
	_start_round(state.round_number + 1)


## The Joker's round-end attack, shaped by its modifiers (§6). By default it hits
## every living player tied for the most Heat, for full damage each (§5). Heat
## resets only for players actually hit.
func _joker_attack() -> void:
	var joker: JokerState = state.joker
	if joker.pattern_id() == JokerModifier.STAND_DOWN:
		_emit(GameEvents.JokerStoodDown.new(state.round_number))
		return
	var attacks: int = 2 if joker.pattern_id() == JokerModifier.DOUBLE_TAP else 1
	var damage: int = state.joker_damage() + joker.bonus_damage()
	for attack_number: int in range(1, attacks + 1):
		# Double Tap's second attack picks targets again, after the first hit's Heat reset.
		if attack_number > 1:
			_resolve_eliminations()
			if state.is_over():
				return
		var targets: Array[int] = _joker_targets()
		if targets.is_empty():
			return
		_emit(GameEvents.JokerAttacked.new(state.round_number, joker.element, damage, targets, attack_number))
		for seat: int in targets:
			deal_damage(GameEvent.JOKER_SEAT, seat, damage, joker.element, &"joker")
			_set_heat(state.player(seat), 0, &"joker_hit")
			for fang: JokerModifier in joker.effects_with_id(JokerModifier.VENOM_FANG):
				apply_poison(seat, int(fang.params.get("tick_damage", 0)), int(fang.params.get("rounds", 0)),
						fang.source_seat)


## Who the Joker hits: the first group of its targeting order (everyone tied), or
## for Cone the top 3, widened to include everyone tied at the cutoff.
func _joker_targets() -> Array[int]:
	var groups: Array[Array] = _joker_target_order()
	var wanted: int = 3 if state.joker.pattern_id() == JokerModifier.CONE else 1
	var targets: Array[int] = []
	for group: Array in groups:
		if targets.size() >= wanted:
			break
		for seat: int in group:
			targets.append(seat)
	return targets


## Living players ordered by the targeting slot, as groups of tied players.
# RULE-ASSUMPTION: targeting and pattern combine through this order. Cone + Invert
# hits the 3 coldest, Cone + Wild Card 3 random players, Cone + Lock-On the locked
# players first and then the hottest others.
func _joker_target_order() -> Array[Array]:
	var joker: JokerState = state.joker
	var alive: Array[int] = state.alive_seats()
	match joker.targeting_id():
		JokerModifier.INVERT:
			return _group_by_heat(alive, false)
		JokerModifier.WILD_CARD:
			var shuffled: Array[int] = alive.duplicate()
			for i: int in range(shuffled.size() - 1, 0, -1):
				var j: int = state.rng.randi_range(0, i)
				var tmp: int = shuffled[i]
				shuffled[i] = shuffled[j]
				shuffled[j] = tmp
			var singles: Array[Array] = []
			for seat: int in shuffled:
				singles.append([seat])
			return singles
		JokerModifier.LOCK_ON:
			var locked: Array[int] = joker.targeting.locked_seats.filter(
					func(seat: int) -> bool: return state.player(seat).is_alive)
			if locked.is_empty():
				joker.targeting = null
				_emit(GameEvents.JokerModifierEnded.new(JokerModifier.LOCK_ON, &"lock_lost"))
				return _group_by_heat(alive, true)
			var others: Array[int] = alive.filter(func(seat: int) -> bool: return not locked.has(seat))
			var order: Array[Array] = [locked]
			order.append_array(_group_by_heat(others, true))
			return order
	return _group_by_heat(alive, true)


## Seats grouped by equal Heat, hottest first (or coldest first).
func _group_by_heat(seats: Array[int], hottest_first: bool) -> Array[Array]:
	var by_heat: Dictionary[int, Array] = {}
	for seat: int in seats:
		var heat: int = state.player(seat).heat
		if not by_heat.has(heat):
			by_heat[heat] = []
		by_heat[heat].append(seat)
	var heats: Array[int] = by_heat.keys()
	heats.sort()
	if hottest_first:
		heats.reverse()
	var groups: Array[Array] = []
	for heat: int in heats:
		groups.append(by_heat[heat])
	return groups


func _hottest_alive() -> Array[int]:
	var groups: Array[Array] = _group_by_heat(state.alive_seats(), true)
	var hottest: Array[int] = []
	if not groups.is_empty():
		hottest.assign(groups[0])
	return hottest


## "This round" modifiers (Cone, Stand Down, Wild Card, Overcharge) clear after the
## round's Joker attack.
func _expire_joker_modifiers() -> void:
	var joker: JokerState = state.joker
	for modifier: JokerModifier in joker.all_modifiers():
		if modifier.one_round:
			_emit(GameEvents.JokerModifierEnded.new(modifier.id, &"expired"))
	if joker.targeting != null and joker.targeting.one_round:
		joker.targeting = null
	if joker.pattern != null and joker.pattern.one_round:
		joker.pattern = null
	joker.effects = joker.effects.filter(func(m: JokerModifier) -> bool: return not m.one_round)


## Damage over time is untyped (Normal, so always 1x) and each stack is its own hit.
func _tick_burns() -> void:
	for p: PlayerState in state.players:
		if not p.is_alive:
			continue
		for stack: DotStack in p.burns:
			deal_damage(stack.source_seat, p.seat, stack.damage, Element.Type.NORMAL, Status.BURN)


## A poison ticks at the end of the round it was applied in, so Venom's 3 rounds
## are that round and the next two.
func _tick_poisons() -> void:
	for p: PlayerState in state.players:
		if not p.is_alive or p.poisons.is_empty():
			continue
		for stack: DotStack in p.poisons:
			deal_damage(stack.source_seat, p.seat, stack.damage, Element.Type.NORMAL, Status.POISON)
			stack.rounds_left -= 1
		var remaining: Array[DotStack] = p.poisons.filter(func(s: DotStack) -> bool: return s.rounds_left > 0)
		for i: int in p.poisons.size() - remaining.size():
			_emit(GameEvents.StatusEnded.new(p.seat, Status.POISON, &"expired"))
		p.poisons = remaining


func _expire_roots() -> void:
	for p: PlayerState in state.players:
		if p.is_alive and p.rooted_until_round == state.round_number:
			p.rooted_until_round = 0
			_emit(GameEvents.StatusEnded.new(p.seat, Status.ROOTED, &"expired"))


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
