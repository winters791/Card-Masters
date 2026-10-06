extends GutTest
## Hand and turn disruption (Pickpocket, Silence, Exposed) and Heat manipulation
## (Scapegoat, Spotlight, Flashpoint), plus the full deck from §3.

const Fixtures := preload("res://tests/support/fixtures.gd")


func _card(id: StringName) -> CardData:
	var card: CardData = CardCatalog.by_id(id)
	assert_not_null(card, "card %s exists" % id)
	return card


func _match(heats: Array[int]) -> TurnController:
	var tc: TurnController = Fixtures.new_match(heats.size())
	for seat: int in heats.size():
		tc.state.player(seat).heat = heats[seat]
	return tc


## The current player plays `card` at `target_seat` (or collectively if -1).
func _play(tc: TurnController, card: CardData, target_seat: int = -1) -> String:
	var seat: int = tc.state.current_seat
	Fixtures.give(tc, seat, card)
	var mode: CardData.Mode = CardData.Mode.COLLECTIVE if target_seat < 0 else CardData.Mode.TARGETED
	return tc.submit(Intents.PlayCard.new(seat, 0, mode, target_seat))


func _finish_round(tc: TurnController) -> void:
	var round_number: int = tc.state.round_number
	while tc.state.round_number == round_number and not tc.state.is_over():
		Fixtures.skip_turn(tc)


func test_card_data() -> void:
	# id: [family, base heat, rarity, mode lock]
	var expected: Dictionary = {
		&"pickpocket": [CardData.Family.DISRUPTION, 1, CardData.Rarity.COMMON, CardData.ModeLock.NONE],
		&"silence": [CardData.Family.DISRUPTION, 2, CardData.Rarity.UNCOMMON, CardData.ModeLock.NONE],
		&"exposed": [CardData.Family.DISRUPTION, 1, CardData.Rarity.COMMON, CardData.ModeLock.NONE],
		&"scapegoat": [CardData.Family.HEAT_MANIPULATION, 2, CardData.Rarity.UNCOMMON, CardData.ModeLock.TARGETED_ONLY],
		&"spotlight": [CardData.Family.HEAT_MANIPULATION, 2, CardData.Rarity.UNCOMMON, CardData.ModeLock.COLLECTIVE_ONLY],
		&"flashpoint": [CardData.Family.HEAT_MANIPULATION, 2, CardData.Rarity.UNCOMMON, CardData.ModeLock.COLLECTIVE_ONLY],
	}
	for id: StringName in expected:
		var card: CardData = _card(id)
		var row: Array = expected[id]
		assert_eq(card.family, row[0], "%s family" % id)
		assert_eq(card.slot(), CardData.Slot.TWO, "%s slot" % id)
		assert_eq(card.base_heat, row[1], "%s base heat" % id)
		assert_eq(card.rarity, row[2], "%s rarity" % id)
		assert_eq(card.mode_lock, row[3], "%s mode lock" % id)


# --- Pickpocket --------------------------------------------------------------------

func test_pickpocket_discards_two_random_cards_publicly() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	assert_eq(_play(tc, _card(&"pickpocket"), 1), "")
	assert_eq(tc.state.player(1).hand.size(), 5)
	assert_eq(Fixtures.events_of(tc, GameEvents.CardDiscarded).size(), 2)
	assert_eq(tc.state.player(0).heat, 2)


func test_pickpocket_takes_what_there_is() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(1).hand.resize(1)
	_play(tc, _card(&"pickpocket"), 1)
	assert_true(tc.state.player(1).hand.is_empty())


func test_collective_pickpocket_hits_everyone_including_you() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_play(tc, _card(&"pickpocket"))
	assert_eq(tc.state.player(0).hand.size(), 5, "7 - 2 (the played card was added for the test)")
	assert_eq(tc.state.player(1).hand.size(), 5)
	assert_eq(tc.state.player(2).hand.size(), 5)


# --- Silence -----------------------------------------------------------------------

func test_silence_allows_only_one_card_next_turn() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_eq(Fixtures.play_and_end(tc, _card(&"silence"), 1), "")
	assert_eq(tc.state.current_seat, 1)
	Fixtures.give(tc, 1, _card(&"tripwire"))
	Fixtures.give(tc, 1, Fixtures.attack(5))
	assert_eq(tc.submit(Intents.PlayCard.new(1, 0, CardData.Mode.TARGETED, 0)), "")
	assert_ne(tc.submit(Intents.PlayCard.new(1, 0, CardData.Mode.COLLECTIVE)), "", "second card blocked")


func test_silence_lasts_one_turn() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.play_and_end(tc, _card(&"silence"), 1)
	Fixtures.skip_turn(tc)  # seat 1's silenced turn; round 2 starts with seat 1 again
	Fixtures.give(tc, 1, _card(&"tripwire"))
	Fixtures.give(tc, 1, Fixtures.attack(5))
	assert_eq(tc.submit(Intents.PlayCard.new(1, 0, CardData.Mode.TARGETED, 0)), "")
	assert_eq(tc.submit(Intents.PlayCard.new(1, 0, CardData.Mode.COLLECTIVE)), "")


# --- Exposed -----------------------------------------------------------------------

func test_exposed_shows_the_hand_to_everyone_until_the_end_of_next_round() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	assert_eq(_play(tc, _card(&"exposed"), 1), "")
	assert_true(tc.state.get_view_for(2)["players"][1].has("hand"))
	assert_false(tc.state.get_view_for(2)["players"][0].has("hand"), "only the target")
	tc.submit(Intents.EndTurn.new(0))
	_finish_round(tc)
	assert_true(tc.state.get_view_for(2)["players"][1].has("hand"), "still shown in round 2")
	_finish_round(tc)
	assert_false(tc.state.get_view_for(2)["players"][1].has("hand"), "hidden again in round 3")


func test_collective_exposed_shows_every_hand() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_play(tc, _card(&"exposed"))
	for p: Dictionary in tc.state.get_view_for(-1)["players"]:
		assert_true(p.has("hand"), "seat %d" % p["seat"])


# --- Scapegoat, Spotlight, Flashpoint -----------------------------------------------

func test_scapegoat_gives_three_and_costs_four() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	assert_eq(_play(tc, _card(&"scapegoat"), 2), "")
	assert_eq(tc.state.player(2).heat, 3)
	assert_eq(tc.state.player(0).heat, 4)
	assert_ne(_play(tc, _card(&"scapegoat")), "", "targeted only")


func test_spotlight_heats_everyone_tied_for_lowest() -> void:
	var tc: TurnController = _match([0, 1, 1, 5])
	assert_eq(_play(tc, _card(&"spotlight")), "")  # seat 0 pays 2 -> 2, 1, 1, 5
	assert_eq(tc.state.player(1).heat, 4)
	assert_eq(tc.state.player(2).heat, 4)
	assert_eq(tc.state.player(0).heat, 2)
	assert_eq(tc.state.player(3).heat, 5)


func test_spotlight_checks_heat_after_you_pay() -> void:
	var tc: TurnController = _match([0, 2, 3])
	_play(tc, _card(&"spotlight"))  # seat 0 pays 2 -> 2, 2, 3: tied lowest
	assert_eq(tc.state.player(0).heat, 5)
	assert_eq(tc.state.player(1).heat, 5)


func test_spotlight_is_collective_only() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_ne(_play(tc, _card(&"spotlight"), 1), "")


func test_flashpoint_heats_everyone_at_six_or_more_including_you_after_paying() -> void:
	var tc: TurnController = _match([4, 6, 5, 9])
	assert_eq(_play(tc, _card(&"flashpoint")), "")  # seat 0 pays 2 -> 6
	assert_eq(tc.state.player(0).heat, 8)
	assert_eq(tc.state.player(1).heat, 8)
	assert_eq(tc.state.player(2).heat, 5)
	assert_eq(tc.state.player(3).heat, 11)


# --- Full deck (§3) ----------------------------------------------------------------

func test_full_deck_matches_the_rarity_table() -> void:
	var definitions: Array[CardData] = CardCatalog.load_all()
	assert_eq(definitions.size(), 37, "37 cards in the first batch")
	var by_rarity: Dictionary = {}
	for card: CardData in definitions:
		by_rarity[card.rarity] = by_rarity.get(card.rarity, 0) + 1
		assert_true(EffectRegistry.has_effect(card.effect_id), "%s is implemented" % card.id)
	assert_eq(by_rarity.get(CardData.Rarity.COMMON, 0), 11)
	assert_eq(by_rarity.get(CardData.Rarity.UNCOMMON, 0), 22)
	assert_eq(by_rarity.get(CardData.Rarity.RARE, 0), 3)
	assert_eq(by_rarity.get(CardData.Rarity.LEGENDARY, 0), 1)
	assert_eq(Deck.build_card_list(definitions).size(), 117)
