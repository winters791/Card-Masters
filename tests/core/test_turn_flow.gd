extends GutTest

const Fixtures := preload("res://tests/support/fixtures.gd")


func test_everyone_starts_at_100_hp_normal_type_no_heat() -> void:
	var tc: TurnController = Fixtures.new_match(4)
	for p: PlayerState in tc.state.players:
		assert_eq(p.hp, 100)
		assert_eq(p.element, Element.Type.NORMAL)
		assert_eq(p.heat, 0)
		assert_true(p.is_alive)


func test_deals_seven_cards_each_round_robin() -> void:
	var deck: Array[CardData] = []
	for i: int in 40:
		deck.append(Fixtures.attack(i))
	var tc := TurnController.new(1, 3, deck, false)
	for p: PlayerState in tc.state.players:
		assert_eq(p.hand.size(), 7)
	assert_eq(tc.state.player(0).hand[0], deck[0])
	assert_eq(tc.state.player(1).hand[0], deck[1])
	assert_eq(tc.state.player(0).hand[1], deck[3])
	assert_eq(tc.state.pending_draw, deck.slice(21, 24), "seat 0 draws the next 3")


func test_turn_starts_with_draw_three_keep_two() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_eq(tc.state.current_seat, 0)
	assert_eq(tc.state.phase, GameState.Phase.KEEP)
	assert_eq(tc.state.pending_draw.size(), 3)
	assert_eq(tc.keep_count(), 2)
	var keep: Array[int] = [0, 2]
	var drawn: Array[CardData] = tc.state.pending_draw.duplicate()
	assert_eq(tc.submit(Intents.KeepCards.new(0, keep)), "")
	assert_eq(tc.state.player(0).hand.size(), 9)
	assert_eq(tc.state.deck.discard_pile, [drawn[1]], "the third card is discarded")
	assert_eq(tc.state.phase, GameState.Phase.PLAY)


func test_must_keep_exactly_two_distinct_cards() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	var one: Array[int] = [0]
	var three: Array[int] = [0, 1, 2]
	var repeated: Array[int] = [1, 1]
	var out_of_range: Array[int] = [0, 3]
	assert_ne(tc.submit(Intents.KeepCards.new(0, one)), "")
	assert_ne(tc.submit(Intents.KeepCards.new(0, three)), "")
	assert_ne(tc.submit(Intents.KeepCards.new(0, repeated)), "")
	assert_ne(tc.submit(Intents.KeepCards.new(0, out_of_range)), "")
	assert_eq(tc.state.phase, GameState.Phase.KEEP)


func test_cannot_play_or_end_turn_before_keeping() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_ne(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 1)), "")
	assert_ne(tc.submit(Intents.EndTurn.new(0)), "")


func test_hand_cap_limits_how_many_cards_are_kept() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	# Seat 0 holds 7; give them 2 more so only 1 fits under the cap of 10.
	Fixtures.give(tc, 0, Fixtures.attack(1))
	Fixtures.give(tc, 0, Fixtures.attack(2))
	assert_eq(tc.keep_count(), 1)
	var keep: Array[int] = [2]
	assert_eq(tc.submit(Intents.KeepCards.new(0, keep)), "")
	assert_eq(tc.state.player(0).hand.size(), Config.HAND_CAP)
	assert_eq(tc.state.deck.discard_pile.size(), 2)


func test_at_hand_cap_all_drawn_cards_are_discarded() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.skip_turn(tc)  # round 1, seat 0: hand 9
	Fixtures.skip_turn(tc)  # round 1, seat 1; round 2 starts with seat 1
	for i: int in 3:
		Fixtures.give(tc, 0, Fixtures.attack(i))  # seat 0: hand 12
	Fixtures.skip_turn(tc)  # round 2, seat 1; now seat 0
	assert_eq(tc.state.current_seat, 0)
	assert_eq(tc.state.phase, GameState.Phase.PLAY, "nothing to choose when the hand is full")
	assert_eq(tc.state.player(0).hand.size(), 12)


func test_only_the_current_player_can_act() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	var keep: Array[int] = [0, 1]
	assert_ne(tc.submit(Intents.KeepCards.new(1, keep)), "")


func test_turns_go_clockwise_and_starting_seat_rotates() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	var order: Array[int] = []
	for i: int in 9:
		order.append(tc.state.current_seat)
		Fixtures.skip_turn(tc)
	assert_eq(order, [0, 1, 2, 1, 2, 0, 2, 0, 1])
	var starts: Array[int] = []
	for event: GameEvent in Fixtures.events_of(tc, GameEvents.RoundStarted):
		starts.append((event as GameEvents.RoundStarted).starting_seat)
	assert_eq(starts.slice(0, 3), [0, 1, 2])


func test_eliminated_seats_are_skipped_in_turn_order_and_rotation() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(1).hp = 0
	tc.state.player(1).is_alive = false
	var order: Array[int] = []
	for i: int in 6:
		order.append(tc.state.current_seat)
		Fixtures.skip_turn(tc)
	# Round 2 would start at seat 1, who is out, so seat 2 starts.
	assert_eq(order, [0, 2, 2, 0, 2, 0])


func test_one_card_per_slot_per_turn() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.keep_first(tc)
	Fixtures.give(tc, 0, Fixtures.attack(5))
	Fixtures.give(tc, 0, Fixtures.attack(5))
	assert_eq(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 1)), "")
	assert_ne(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 1)), "", "slot 2 already used")


func test_cannot_target_yourself_or_eliminated_or_missing_seats() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.keep_first(tc)
	Fixtures.give(tc, 0, Fixtures.attack(5))
	tc.state.player(2).is_alive = false
	assert_ne(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 0)), "")
	assert_ne(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 2)), "")
	assert_ne(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 7)), "")
	assert_eq(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 1)), "")


func test_mode_lock_is_enforced() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.keep_first(tc)
	Fixtures.give(tc, 0, Fixtures.attack(5, Element.Type.FIRE, 1, CardData.ModeLock.COLLECTIVE_ONLY))
	assert_ne(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 1)), "")
	assert_eq(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.COLLECTIVE)), "")


func test_played_card_leaves_hand_and_goes_to_discard() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.keep_first(tc)
	var card: CardData = Fixtures.attack(5)
	Fixtures.give(tc, 0, card)
	var hand_size: int = tc.state.player(0).hand.size()
	tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 1))
	assert_eq(tc.state.player(0).hand.size(), hand_size - 1)
	assert_eq(tc.state.deck.discard_pile.back(), card)


func test_playing_a_card_is_not_a_skip() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.play_and_end(tc, Fixtures.attack(5), 1)
	assert_eq(Fixtures.events_of(tc, GameEvents.PlayerSkipped).size(), 0)
	assert_eq(tc.state.player(0).heat, 2)


func test_timeout_during_keep_keeps_first_cards_and_skips() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	var drawn: Array[CardData] = tc.state.pending_draw.duplicate()
	assert_eq(tc.submit(Intents.Timeout.new(0)), "")
	assert_true(tc.state.player(0).hand.has(drawn[0]))
	assert_eq(tc.state.player(0).hand.size(), 9)
	assert_eq(tc.state.player(0).heat, Config.SKIP_HEAT)
	assert_eq(tc.state.current_seat, 1)


func test_timeout_after_playing_costs_no_skip_heat() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.keep_first(tc)
	Fixtures.give(tc, 0, Fixtures.attack(5))
	tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.COLLECTIVE))
	tc.submit(Intents.Timeout.new(0))
	assert_eq(tc.state.player(0).heat, 1, "only the card's Heat")
	assert_eq(tc.state.current_seat, 1)


func test_empty_deck_reshuffles_the_discard_pile_and_reports_it() -> void:
	# 2 players x 7 cards + seat 0's draw of 3 = 17 cards: the deck is now empty.
	var tc: TurnController = Fixtures.new_match(2, Fixtures.filler_deck(17))
	assert_eq(tc.state.deck.draw_pile.size(), 0)
	Fixtures.skip_turn(tc)  # seat 0 discards 1 drawn card
	assert_eq(tc.state.pending_draw.size(), 1, "seat 1 draws the one reshuffled card")
	assert_eq(Fixtures.events_of(tc, GameEvents.DeckReshuffled).size(), 1)
