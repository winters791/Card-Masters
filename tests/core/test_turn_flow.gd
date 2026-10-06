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
	Fixtures.draw(tc, 1)
	assert_eq(tc.state.player(0).hand.back(), deck[21], "seat 0's first draw is the next card")


func test_turn_opens_with_the_draw_step_and_nothing_drawn_yet() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_eq(tc.state.current_seat, 0)
	assert_eq(tc.state.phase, GameState.Phase.DRAW)
	assert_eq(tc.state.player(0).hand.size(), 7)
	assert_true(tc.can_draw())
	assert_true(tc.can_discard())


func test_draws_one_card_at_a_time_up_to_three() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	for expected_size: int in [8, 9, 10]:
		assert_eq(tc.submit(Intents.DrawCard.new(0)), "")
		assert_eq(tc.state.player(0).hand.size(), expected_size)
	assert_ne(tc.submit(Intents.DrawCard.new(0)), "", "max 3 draws per turn")
	assert_eq(Fixtures.events_of(tc, GameEvents.CardsDrawn).size(), 3)


func test_can_keep_all_three_drawn_cards() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.draw(tc, 3)
	Fixtures.skip_turn(tc)
	assert_eq(tc.state.player(0).hand.size(), 10)
	assert_eq(tc.state.deck.discard_pile.size(), 0, "discarding is optional")


func test_drawing_is_optional() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.draw(tc, 1)
	assert_eq(tc.submit(Intents.EndTurn.new(0)), "")
	assert_eq(tc.state.player(0).hand.size(), 8)
	Fixtures.skip_turn(tc)  # seat 1 draws nothing at all
	assert_eq(tc.state.player(1).hand.size(), 7)


func test_discard_any_card_from_hand_once_per_turn() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	var old_card: CardData = Fixtures.attack(3)
	Fixtures.give(tc, 0, old_card)
	Fixtures.draw(tc, 1)
	assert_eq(tc.submit(Intents.DiscardCard.new(0, 0)), "", "an old card, not one just drawn")
	assert_eq(tc.state.deck.discard_pile, [old_card])
	var discarded := Fixtures.events_of(tc, GameEvents.CardDiscarded)[0] as GameEvents.CardDiscarded
	assert_eq(discarded.card, old_card)
	assert_ne(tc.submit(Intents.DiscardCard.new(0, 0)), "", "only one discard per turn")
	assert_eq(Fixtures.draw(tc, 2), "", "drawing continues after a discard")
	assert_eq(tc.state.player(0).hand.size(), 10)


func test_discard_index_must_be_in_hand() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_ne(tc.submit(Intents.DiscardCard.new(0, 7)), "")
	assert_ne(tc.submit(Intents.DiscardCard.new(0, -1)), "")


func test_at_hand_cap_must_discard_before_drawing() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	for i: int in 3:
		Fixtures.give(tc, 0, Fixtures.attack(i))
	assert_eq(tc.state.player(0).hand.size(), Config.HAND_CAP)
	assert_false(tc.can_draw())
	assert_ne(tc.submit(Intents.DrawCard.new(0)), "")
	assert_eq(tc.submit(Intents.DiscardCard.new(0, 0)), "")
	assert_eq(tc.submit(Intents.DrawCard.new(0)), "")
	assert_eq(tc.state.player(0).hand.size(), Config.HAND_CAP)
	assert_ne(tc.submit(Intents.DrawCard.new(0)), "", "full again and the discard is used up")


func test_playing_a_card_ends_the_draw_step() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.give(tc, 0, Fixtures.attack(5))
	assert_eq(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 1)), "")
	assert_eq(tc.state.phase, GameState.Phase.PLAY)
	assert_ne(tc.submit(Intents.DrawCard.new(0)), "")
	assert_ne(tc.submit(Intents.DiscardCard.new(0, 0)), "")


func test_cannot_draw_from_an_empty_deck_and_discard_pile() -> void:
	var tc: TurnController = Fixtures.new_match(2, Fixtures.filler_deck(14))
	assert_false(tc.can_draw())
	assert_ne(tc.submit(Intents.DrawCard.new(0)), "")


func test_only_the_current_player_can_act() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_ne(tc.submit(Intents.DrawCard.new(1)), "")
	assert_ne(tc.submit(Intents.EndTurn.new(1)), "")


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
	Fixtures.give(tc, 0, Fixtures.attack(5))
	Fixtures.give(tc, 0, Fixtures.attack(5))
	assert_eq(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 1)), "")
	assert_ne(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 1)), "", "slot 2 already used")


func test_cannot_target_yourself_or_eliminated_or_missing_seats() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.give(tc, 0, Fixtures.attack(5))
	tc.state.player(2).is_alive = false
	assert_ne(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 0)), "")
	assert_ne(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 2)), "")
	assert_ne(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 7)), "")
	assert_eq(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 1)), "")


func test_mode_lock_is_enforced() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.give(tc, 0, Fixtures.attack(5, Element.Type.FIRE, 1, CardData.ModeLock.COLLECTIVE_ONLY))
	assert_ne(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 1)), "")
	assert_eq(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.COLLECTIVE)), "")


func test_played_card_leaves_hand_and_goes_to_discard() -> void:
	var tc: TurnController = Fixtures.new_match(2)
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


func test_timeout_ends_the_turn_and_keeps_cards_drawn_so_far() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.draw(tc, 2)
	assert_eq(tc.submit(Intents.Timeout.new(0)), "")
	assert_eq(tc.state.player(0).hand.size(), 9)
	assert_eq(tc.state.player(0).heat, Config.SKIP_HEAT, "nothing played: counts as a skip")
	assert_eq(tc.state.current_seat, 1)


func test_timeout_after_playing_costs_no_skip_heat() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.give(tc, 0, Fixtures.attack(5))
	tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.COLLECTIVE))
	tc.submit(Intents.Timeout.new(0))
	assert_eq(tc.state.player(0).heat, 1, "only the card's Heat")
	assert_eq(tc.state.current_seat, 1)


func test_empty_deck_reshuffles_the_discard_pile_and_reports_it() -> void:
	# 2 players x 7 cards = 14: the draw pile is empty after the deal.
	var tc: TurnController = Fixtures.new_match(2, Fixtures.filler_deck(14))
	assert_eq(tc.submit(Intents.DiscardCard.new(0, 0)), "")
	assert_eq(tc.submit(Intents.DrawCard.new(0)), "", "the discard is reshuffled in")
	assert_eq(tc.state.player(0).hand.size(), 7)
	assert_eq(Fixtures.events_of(tc, GameEvents.DeckReshuffled).size(), 1)
