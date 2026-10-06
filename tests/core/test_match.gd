extends GutTest
## Match end, determinism, hidden information and a full match from seed to winner.

const Fixtures := preload("res://tests/support/fixtures.gd")


func test_last_player_standing_wins_immediately() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.state.player(1).hp = 20
	Fixtures.play_and_end(tc, Fixtures.attack(20), 1)
	assert_true(tc.state.is_over())
	assert_eq(tc.state.winner_seat, 0)
	assert_false(tc.state.is_draw)
	var ended := tc.state.events.back() as GameEvents.MatchEnded
	assert_not_null(ended)
	assert_eq(ended.winner_seat, 0)


func test_no_actions_after_the_match_ends() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.state.player(1).hp = 20
	Fixtures.play_and_end(tc, Fixtures.attack(20), 1)
	assert_ne(tc.submit(Intents.EndTurn.new(0)), "")


func test_last_two_dying_to_the_same_card_is_a_draw() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(2).hp = 0
	tc.state.player(2).is_alive = false
	tc.state.player(0).hp = 15
	tc.state.player(1).hp = 15
	Fixtures.play_and_end(tc, Fixtures.attack(15))
	assert_true(tc.state.is_over())
	assert_true(tc.state.is_draw)
	assert_eq(tc.state.winner_seat, -1)


func test_last_two_dying_to_the_same_joker_hit_is_a_draw() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.state.player(0).hp = 10
	tc.state.player(1).hp = 10
	Fixtures.skip_turn(tc)
	Fixtures.skip_turn(tc)
	assert_true(tc.state.is_draw)


func test_joker_can_decide_the_winner() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.state.player(0).hp = 10
	Fixtures.play_and_end(tc, Fixtures.attack(0), 1)  # seat 0: 2 Heat
	Fixtures.skip_turn(tc)  # seat 1: 1 Heat
	assert_true(tc.state.is_over())
	assert_eq(tc.state.winner_seat, 1)


func test_view_hides_other_hands_and_draws() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	var mine: Dictionary = tc.state.get_view_for(0)
	var theirs: Dictionary = tc.state.get_view_for(1)
	assert_true(mine["players"][0].has("hand"))
	assert_false(mine["players"][1].has("hand"))
	assert_eq(mine["players"][1]["hand_size"], 7)
	assert_true(mine.has("pending_draw"))
	assert_false(theirs.has("pending_draw"))
	assert_false(theirs["players"][0].has("hand"))


func test_event_view_hides_drawn_cards_from_others() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	var own_draw: GameEvents.CardsDrawn = null
	var other_draw: GameEvents.CardsDrawn = null
	for event: GameEvent in tc.state.get_events_for(0):
		if event is GameEvents.CardsDrawn:
			own_draw = event
	for event: GameEvent in tc.state.get_events_for(1):
		if event is GameEvents.CardsDrawn:
			other_draw = event
	assert_eq(own_draw.cards.size(), 3)
	assert_eq(other_draw.cards.size(), 0)
	assert_eq(other_draw.count, 3)


# --- Full matches with real cards ------------------------------------------------

## Plays a whole match with a simple scripted policy: keep the first cards, then
## play the first card in hand at the next living seat (collectively if the card
## is locked to it). Returns the controller once the match is over.
func _play_scripted_match(match_seed: int, player_count: int) -> TurnController:
	var deck: Array[CardData] = []
	for i: int in 4:
		deck.append_array(Deck.build_card_list(CardCatalog.load_all()))
	var tc := TurnController.new(match_seed, player_count, deck)
	var guard: int = 0
	while not tc.state.is_over() and guard < 2000:
		guard += 1
		var seat: int = tc.state.current_seat
		if tc.state.phase == GameState.Phase.KEEP:
			assert_eq(Fixtures.keep_first(tc), "")
			continue
		var hand: Array[CardData] = tc.state.player(seat).hand
		if hand.is_empty():
			tc.submit(Intents.EndTurn.new(seat))
			continue
		var card: CardData = hand[0]
		var mode: CardData.Mode = CardData.Mode.TARGETED
		if card.mode_lock == CardData.ModeLock.COLLECTIVE_ONLY:
			mode = CardData.Mode.COLLECTIVE
		var target: int = _next_alive(tc, seat)
		assert_eq(tc.submit(Intents.PlayCard.new(seat, 0, mode, target)), "")
		if not tc.state.is_over() and tc.state.current_seat == seat:
			assert_eq(tc.submit(Intents.EndTurn.new(seat)), "")
	return tc


func _next_alive(tc: TurnController, seat: int) -> int:
	var count: int = tc.state.players.size()
	for offset: int in range(1, count):
		var other: int = (seat + offset) % count
		if tc.state.player(other).is_alive:
			return other
	return -1


func _describe_log(tc: TurnController) -> Array[String]:
	var lines: Array[String] = []
	for event: GameEvent in tc.state.events:
		lines.append(event.describe())
	return lines


func test_full_match_from_seed_to_winner() -> void:
	for player_count: int in [2, 3, 4]:
		var tc: TurnController = _play_scripted_match(1234, player_count)
		assert_true(tc.state.is_over(), "%d players: match finished" % player_count)
		var alive: Array[int] = tc.state.alive_seats()
		if tc.state.is_draw:
			assert_eq(alive.size(), 0)
		else:
			assert_eq(alive, [tc.state.winner_seat])
		assert_true(tc.state.events.back() is GameEvents.MatchEnded)
		var eliminations: int = Fixtures.events_of(tc, GameEvents.PlayerEliminated).size()
		assert_eq(eliminations, player_count - alive.size())


func test_same_seed_and_moves_replay_identically() -> void:
	var a: TurnController = _play_scripted_match(99, 4)
	var b: TurnController = _play_scripted_match(99, 4)
	assert_eq(_describe_log(a), _describe_log(b))


func test_different_seeds_play_out_differently() -> void:
	var a: TurnController = _play_scripted_match(1, 4)
	var b: TurnController = _play_scripted_match(2, 4)
	assert_ne(_describe_log(a), _describe_log(b))
