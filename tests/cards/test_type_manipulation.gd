extends GutTest
## Type manipulation family (§8): Type Swap, Convert, Rooted, Shed Skin.

const Fixtures := preload("res://tests/support/fixtures.gd")

const N := Element.Type.NORMAL
const G := Element.Type.GRASS
const W := Element.Type.WATER
const F := Element.Type.FIRE


func _card(id: StringName) -> CardData:
	var card: CardData = CardCatalog.by_id(id)
	assert_not_null(card, "card %s exists" % id)
	return card


## The current player plays `card` (at `target_seat`, or collectively if -1) with an
## optional chosen type. Returns the controller's answer.
func _play(tc: TurnController, card: CardData, target_seat: int = -1, chosen: int = -1) -> String:
	var seat: int = tc.state.current_seat
	Fixtures.give(tc, seat, card)
	var mode: CardData.Mode = CardData.Mode.COLLECTIVE if target_seat < 0 else CardData.Mode.TARGETED
	return tc.submit(Intents.PlayCard.new(seat, 0, mode, target_seat, chosen))


func _elements(tc: TurnController) -> Array[Element.Type]:
	var elements: Array[Element.Type] = []
	for p: PlayerState in tc.state.players:
		elements.append(p.element)
	return elements


func _end_round(tc: TurnController) -> void:
	var round_number: int = tc.state.round_number
	while tc.state.round_number == round_number and not tc.state.is_over():
		Fixtures.skip_turn(tc)


func test_card_data() -> void:
	# id: [base heat, rarity, mode lock]
	var expected: Dictionary = {
		&"type_swap": [2, CardData.Rarity.UNCOMMON, CardData.ModeLock.TARGETED_ONLY],
		&"convert": [2, CardData.Rarity.UNCOMMON, CardData.ModeLock.NONE],
		&"rooted": [2, CardData.Rarity.UNCOMMON, CardData.ModeLock.NONE],
		&"shed_skin": [1, CardData.Rarity.COMMON, CardData.ModeLock.NONE],
	}
	for id: StringName in expected:
		var card: CardData = _card(id)
		var row: Array = expected[id]
		assert_eq(card.family, CardData.Family.TYPE_MANIPULATION, "%s family" % id)
		assert_eq(card.slot(), CardData.Slot.TWO, "%s slot" % id)
		assert_eq(card.base_heat, row[0], "%s base heat" % id)
		assert_eq(card.rarity, row[1], "%s rarity" % id)
		assert_eq(card.mode_lock, row[2], "%s mode lock" % id)


# --- Type Swap -------------------------------------------------------------------

func test_type_swap_trades_types() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(0).element = F
	tc.state.player(2).element = W
	assert_eq(_play(tc, _card(&"type_swap"), 2), "")
	assert_eq(_elements(tc), [W, N, F])
	assert_eq(tc.state.player(0).heat, 4)
	assert_eq(Fixtures.events_of(tc, GameEvents.TypeChanged).size(), 2)


func test_type_swap_is_targeted_only() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_ne(_play(tc, _card(&"type_swap")), "")


func test_type_swap_fails_entirely_if_either_player_is_rooted() -> void:
	for rooted_seat: int in [0, 1]:
		var tc: TurnController = Fixtures.new_match(2)
		tc.state.player(0).element = F
		tc.state.player(1).element = W
		tc.apply_root(rooted_seat, 1 - rooted_seat)
		assert_eq(_play(tc, _card(&"type_swap"), 1), "", "still playable")
		assert_eq(_elements(tc), [F, W], "seat %d rooted: nobody changes" % rooted_seat)
		assert_eq(tc.state.player(0).heat, 4, "still costs Heat")
		assert_eq(Fixtures.events_of(tc, GameEvents.TypeChangeBlocked).size(), 1)


func test_type_swap_puts_out_burns_on_both_sides() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.state.player(0).element = F
	tc.apply_burn(0, 10, 1)
	tc.apply_burn(1, 10, 0)
	_play(tc, _card(&"type_swap"), 1)
	assert_true(tc.state.player(0).burns.is_empty())
	assert_true(tc.state.player(1).burns.is_empty())


# --- Convert ---------------------------------------------------------------------

func test_convert_sets_the_target_to_the_chosen_type() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	assert_eq(_play(tc, _card(&"convert"), 1, G), "")
	assert_eq(_elements(tc), [N, G, N])
	assert_eq(tc.state.player(0).heat, 4)


func test_convert_needs_a_type_choice() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_ne(_play(tc, _card(&"convert"), 1), "")
	assert_ne(_play(tc, _card(&"convert"), 1, 9), "")


func test_collective_convert_hits_everyone_but_the_rooted() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.apply_root(2, 1)
	assert_eq(_play(tc, _card(&"convert"), -1, W), "")
	assert_eq(_elements(tc), [W, W, N], "you included; Rooted seat 2 resists")
	assert_eq(tc.state.player(0).heat, 2)


# --- Rooted ----------------------------------------------------------------------

func test_rooted_lasts_until_the_end_of_next_round() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_eq(_play(tc, _card(&"rooted"), 1), "")
	assert_eq(tc.state.player(0).heat, 4)
	assert_true(tc.state.is_rooted(1))
	_end_round(tc)
	assert_eq(tc.state.round_number, 2)
	assert_true(tc.state.is_rooted(1), "still rooted through round 2")
	assert_false(tc.change_element(1, F))
	_end_round(tc)
	assert_false(tc.state.is_rooted(1), "free in round 3")
	assert_true(tc.change_element(1, F))
	var ended: Array[GameEvent] = Fixtures.events_of(tc, GameEvents.StatusEnded)
	assert_eq((ended[0] as GameEvents.StatusEnded).status, Status.ROOTED)


func test_collective_rooted_roots_everyone_including_the_player() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_play(tc, _card(&"rooted"))
	for p: PlayerState in tc.state.players:
		assert_true(tc.state.is_rooted(p.seat), "seat %d" % p.seat)


func test_rooting_again_never_shortens_it() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.apply_root(1, 0)
	_end_round(tc)
	tc.apply_root(1, 0)  # round 2: now through round 3
	assert_eq(tc.state.player(1).rooted_until_round, 3)


# --- Shed Skin -------------------------------------------------------------------

func test_shed_skin_changes_your_type_and_hits_with_it() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(1).element = G
	assert_eq(_play(tc, _card(&"shed_skin"), 1, F), "")
	assert_eq(tc.state.player(0).element, F)
	assert_eq(tc.state.player(1).hp, 80, "10 Fire at 2x vs Grass")
	assert_eq(tc.state.player(0).heat, 3, "Base 1 x2 targeted, +1 for direct damage")


func test_shed_skin_needs_a_different_type() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_ne(_play(tc, _card(&"shed_skin"), 1), "", "no choice")
	assert_ne(_play(tc, _card(&"shed_skin"), 1, N), "", "already Normal")


func test_collective_shed_skin_hits_everyone_including_you() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(2).element = W
	assert_eq(_play(tc, _card(&"shed_skin"), -1, F), "")
	assert_eq(tc.state.player(0).hp, 90, "Fire vs Fire")
	assert_eq(tc.state.player(1).hp, 90, "Fire vs Normal")
	assert_eq(tc.state.player(2).hp, 95, "Fire vs Water")
	assert_eq(tc.state.player(0).heat, 2, "Base 1 collective, +1 for direct damage")


func test_rooted_shed_skin_keeps_your_type_and_hits_with_it() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.state.player(0).element = W
	tc.state.player(1).element = F
	tc.apply_root(0, 1)
	assert_eq(_play(tc, _card(&"shed_skin"), 1, G), "")
	assert_eq(tc.state.player(0).element, W, "the change fails")
	assert_eq(tc.state.player(1).hp, 80, "10 Water at 2x vs Fire")
