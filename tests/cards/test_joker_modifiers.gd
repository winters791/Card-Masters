extends GutTest
## Joker modifiers (§6, §8): Cone, Double Tap, Stand Down, Lock-On, Wild Card,
## Invert, Ignite / Flood / Overgrow, Venom Fang, Overcharge.

const Fixtures := preload("res://tests/support/fixtures.gd")


func _card(id: StringName) -> CardData:
	var card: CardData = CardCatalog.by_id(id)
	assert_not_null(card, "card %s exists" % id)
	return card


## A match where the players start with the given Heat.
func _match(heats: Array[int]) -> TurnController:
	var tc: TurnController = Fixtures.new_match(heats.size())
	for seat: int in heats.size():
		tc.state.player(seat).heat = heats[seat]
	return tc


## The current player plays Joker card `id` (collective) and ends the turn.
func _play_joker(tc: TurnController, id: StringName) -> void:
	assert_eq(Fixtures.play_and_end(tc, _card(id)), "")


## Everyone else skips until the round ends.
func _finish_round(tc: TurnController) -> void:
	var round_number: int = tc.state.round_number
	while tc.state.round_number == round_number and not tc.state.is_over():
		Fixtures.skip_turn(tc)


func _attacks(tc: TurnController) -> Array[Array]:
	var targets: Array[Array] = []
	for event: GameEvent in Fixtures.events_of(tc, GameEvents.JokerAttacked):
		targets.append((event as GameEvents.JokerAttacked).target_seats)
	return targets


func test_card_data() -> void:
	# id: [base heat, rarity]
	var expected: Dictionary = {
		&"cone": [3, CardData.Rarity.RARE],
		&"double_tap": [3, CardData.Rarity.RARE],
		&"stand_down": [2, CardData.Rarity.UNCOMMON],
		&"lock_on": [2, CardData.Rarity.UNCOMMON],
		&"wild_card": [2, CardData.Rarity.UNCOMMON],
		&"invert": [2, CardData.Rarity.UNCOMMON],
		&"ignite": [2, CardData.Rarity.UNCOMMON],
		&"flood": [2, CardData.Rarity.UNCOMMON],
		&"overgrow": [2, CardData.Rarity.UNCOMMON],
		&"venom_fang": [2, CardData.Rarity.UNCOMMON],
		&"overcharge": [3, CardData.Rarity.RARE],
	}
	for id: StringName in expected:
		var card: CardData = _card(id)
		var row: Array = expected[id]
		assert_eq(card.family, CardData.Family.JOKER_MODIFIER, "%s family" % id)
		assert_eq(card.slot(), CardData.Slot.ONE, "%s slot" % id)
		assert_eq(card.mode_lock, CardData.ModeLock.COLLECTIVE_ONLY, "%s mode" % id)
		assert_eq(card.base_heat, row[0], "%s base heat" % id)
		assert_eq(card.rarity, row[1], "%s rarity" % id)


func test_joker_cards_cost_heat_now_and_count_as_collective() -> void:
	var tc: TurnController = _match([0, 0])
	_play_joker(tc, &"cone")
	assert_eq(tc.state.player(0).heat, 3)


func test_a_joker_card_and_an_attack_in_the_same_turn() -> void:
	var tc: TurnController = _match([0, 0])
	Fixtures.give(tc, 0, _card(&"stand_down"))
	assert_eq(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.COLLECTIVE)), "")
	Fixtures.give(tc, 0, Fixtures.attack(10))
	assert_eq(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 1)), "")


# --- Pattern: Cone, Double Tap, Stand Down -----------------------------------------

func test_cone_hits_the_top_three_this_round_only() -> void:
	var tc: TurnController = _match([5, 4, 3, 1])
	_play_joker(tc, &"cone")  # seat 0: 8; others skip: 5, 4, 2
	_finish_round(tc)
	assert_eq(_attacks(tc), [[0, 1, 2]])
	assert_eq(tc.state.joker.pattern, null, "cleared after the round")
	_finish_round(tc)
	assert_eq(_attacks(tc)[1].size(), 1, "back to a single target")


func test_cone_includes_everyone_tied_at_the_cutoff() -> void:
	var tc: TurnController = _match([5, 4, 3, 3])
	_play_joker(tc, &"cone")  # 8, 5, 4, 4
	_finish_round(tc)
	assert_eq(_attacks(tc), [[0, 1, 2, 3]])


func test_double_tap_attacks_twice_and_repicks_targets() -> void:
	var tc: TurnController = _match([0, 5, 3])
	_play_joker(tc, &"double_tap")  # seat 0: 3; skips: 6, 4
	_finish_round(tc)
	assert_eq(_attacks(tc), [[1], [2]], "seat 1's Heat resets, so the second hit goes to seat 2")
	assert_eq(tc.state.player(1).hp, 90)
	assert_eq(tc.state.player(2).hp, 90)


func test_double_tap_stays_until_replaced() -> void:
	var tc: TurnController = _match([0, 0])
	_play_joker(tc, &"double_tap")
	_finish_round(tc)
	assert_eq(tc.state.joker.pattern_id(), JokerModifier.DOUBLE_TAP)
	_play_joker(tc, &"cone")
	assert_eq(tc.state.joker.pattern_id(), JokerModifier.CONE)
	var ended := Fixtures.events_of(tc, GameEvents.JokerModifierEnded)[0] as GameEvents.JokerModifierEnded
	assert_eq(ended.modifier_id, JokerModifier.DOUBLE_TAP)
	assert_eq(ended.reason, &"replaced")


func test_stand_down_skips_the_attack_but_the_joker_still_grows() -> void:
	var tc: TurnController = _match([0, 0])
	_play_joker(tc, &"stand_down")  # seat 0: 2; seat 1 skips: 1
	_finish_round(tc)
	assert_eq(_attacks(tc), [])
	assert_eq(Fixtures.events_of(tc, GameEvents.JokerStoodDown).size(), 1)
	assert_eq(tc.state.player(0).heat, 2, "no hit, so no Heat reset")
	assert_eq(tc.state.joker.pattern, null, "this round only")
	_finish_round(tc)  # 3 vs 2
	assert_eq(_attacks(tc), [[0]])
	assert_eq(tc.state.player(0).hp, 80, "round 2 damage")


# --- Targeting: Lock-On, Wild Card, Invert -----------------------------------------

func test_lock_on_locks_the_hottest_at_play_time() -> void:
	var tc: TurnController = _match([0, 0, 5])
	_play_joker(tc, &"lock_on")  # seat 0: 2; locks seat 2 (5)
	assert_eq(tc.state.joker.targeting.locked_seats, [2])
	tc.state.player(1).heat = 20
	_finish_round(tc)
	assert_eq(_attacks(tc), [[2]], "locked, whatever the Heat")
	_finish_round(tc)
	assert_eq(_attacks(tc)[1], [2], "still locked next round")


func test_lock_on_locks_everyone_tied() -> void:
	var tc: TurnController = _match([0, 4, 4])
	_play_joker(tc, &"lock_on")
	assert_eq(tc.state.joker.targeting.locked_seats, [1, 2])


# The Lock-On card's own Heat lands before it picks.
func test_lock_on_can_lock_its_own_player() -> void:
	var tc: TurnController = _match([0, 1, 1])
	_play_joker(tc, &"lock_on")
	assert_eq(tc.state.joker.targeting.locked_seats, [0])


func test_lock_on_ends_when_every_locked_player_is_gone() -> void:
	var tc: TurnController = _match([0, 0, 5])
	_play_joker(tc, &"lock_on")
	tc.state.player(2).hp = 0
	tc.state.player(2).is_alive = false
	_finish_round(tc)
	assert_eq(tc.state.joker.targeting, null)
	assert_eq(_attacks(tc), [[0]], "back to the hottest")
	var ended := Fixtures.events_of(tc, GameEvents.JokerModifierEnded)[0] as GameEvents.JokerModifierEnded
	assert_eq(ended.reason, &"lock_lost")


func test_wild_card_hits_one_random_player_this_round() -> void:
	var tc: TurnController = _match([0, 0, 0, 0])
	_play_joker(tc, &"wild_card")
	_finish_round(tc)
	assert_eq(_attacks(tc)[0].size(), 1)
	assert_eq(tc.state.joker.targeting, null, "this round only")
	var replay: TurnController = _match([0, 0, 0, 0])
	_play_joker(replay, &"wild_card")
	_finish_round(replay)
	assert_eq(_attacks(replay)[0], _attacks(tc)[0], "same seed, same pick")


func test_invert_targets_the_lowest_heat_and_stays() -> void:
	var tc: TurnController = _match([0, 5, 3])
	_play_joker(tc, &"invert")  # 2, 6, 4
	_finish_round(tc)
	assert_eq(_attacks(tc), [[0]])
	assert_eq(tc.state.joker.targeting_id(), JokerModifier.INVERT)


func test_invert_hits_everyone_tied_for_lowest() -> void:
	var tc: TurnController = _match([0, 1, 2])
	_play_joker(tc, &"invert")  # 2, 2, 3
	_finish_round(tc)
	assert_eq(_attacks(tc), [[0, 1]])


func test_a_new_targeting_card_replaces_the_old_one() -> void:
	var tc: TurnController = _match([0, 0])
	tc.add_joker_modifier(JokerModifier.INVERT, 0)
	tc.add_joker_modifier(JokerModifier.WILD_CARD, 1)
	assert_eq(tc.state.joker.targeting_id(), JokerModifier.WILD_CARD)


# --- Type: Ignite, Flood, Overgrow -------------------------------------------------

func test_type_cards_set_the_jokers_type_for_good() -> void:
	var expected: Dictionary = {
		&"ignite": Element.Type.FIRE,
		&"flood": Element.Type.WATER,
		&"overgrow": Element.Type.GRASS,
	}
	for id: StringName in expected:
		var tc: TurnController = _match([0, 0])
		_play_joker(tc, id)
		assert_eq(tc.state.joker.element, expected[id], "%s" % id)
		_finish_round(tc)
		assert_eq(tc.state.joker.element, expected[id], "%s persists" % id)


func test_joker_type_decides_how_hard_it_hits() -> void:
	var tc: TurnController = _match([0, 0])
	tc.state.player(0).element = Element.Type.GRASS
	_play_joker(tc, &"ignite")  # seat 0: 2
	_finish_round(tc)
	assert_eq(tc.state.player(0).hp, 80, "10 Fire at 2x vs Grass")


# --- Effects: Venom Fang, Overcharge -----------------------------------------------

func test_venom_fang_poisons_every_joker_hit_and_stacks() -> void:
	var tc: TurnController = _match([0, 0])
	_play_joker(tc, &"venom_fang")  # seat 0: 2 -> hit
	tc.add_joker_modifier(JokerModifier.VENOM_FANG, 1, {"tick_damage": 5, "rounds": 3})
	_finish_round(tc)
	assert_eq(tc.state.player(0).poisons.size(), 2, "one poison per fang")
	assert_eq(tc.state.player(1).poisons.size(), 0)
	assert_eq(tc.state.joker.effects.size(), 2, "fangs stay")


func test_overcharge_adds_twenty_this_round_only_and_stacks() -> void:
	var tc: TurnController = _match([0, 0])
	_play_joker(tc, &"overcharge")  # seat 0: 3
	tc.add_joker_modifier(JokerModifier.OVERCHARGE, 1, {"bonus": 20})
	_finish_round(tc)
	assert_eq(tc.state.player(0).hp, 50, "10 + 20 + 20")
	assert_true(tc.state.joker.effects.is_empty(), "this round only")
	_finish_round(tc)
	var last := Fixtures.events_of(tc, GameEvents.JokerAttacked).back() as GameEvents.JokerAttacked
	assert_eq(last.damage, 20, "round 2, no bonus")
