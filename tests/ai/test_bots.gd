extends GutTest
## Phase 3: legal move lists, RandomBot, GreedyBot, the match runner and the report.

const Fixtures := preload("res://tests/support/fixtures.gd")


func _card(id: StringName) -> CardData:
	return CardCatalog.by_id(id)


## Seat 0 is up with exactly `hand`, past the draw step.
func _decision(player_count: int, hand: Array[CardData]) -> TurnController:
	var tc: TurnController = Fixtures.new_match(player_count)
	tc.state.player(0).hand = hand
	tc.state.draws_this_turn = Config.MAX_DRAWS_PER_TURN
	return tc


func _describe_log(tc: TurnController) -> Array[String]:
	var lines: Array[String] = []
	for event: GameEvent in tc.state.events:
		lines.append(event.describe())
	return lines


# --- Legal moves -------------------------------------------------------------------

func test_every_listed_move_is_legal() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(0).hand = [_card(&"ember"), _card(&"convert"), _card(&"wildfire"), _card(&"grudge")]
	var moves: Array[Intent] = LegalMoves.for_current_player(tc)
	for move: Intent in moves:
		assert_eq(tc.validate(move), "", str(move))
	assert_true(moves.any(func(m: Intent) -> bool: return m is Intents.DrawCard))
	assert_true(moves.any(func(m: Intent) -> bool: return m is Intents.EndTurn))


func test_type_choices_only_for_cards_that_ask() -> void:
	var tc: TurnController = _decision(2, [_card(&"convert"), _card(&"ember")])
	var plays: Array[Intent] = LegalMoves.plays(tc)
	# Convert: 4 types x (collective + 1 target); Ember: collective + 1 target.
	assert_eq(plays.size(), 10)


# --- Bots play whole matches legally -------------------------------------------------

func test_both_bots_finish_matches_with_only_legal_moves() -> void:
	for bot_name: String in ["random", "greedy"]:
		for player_count: int in [2, 3, 4]:
			var names: Array[String] = []
			names.resize(player_count)
			names.fill(bot_name)
			var tc := TurnController.new(7, player_count, Deck.build_card_list(CardCatalog.load_all()))
			var bots: Array[Bot] = []
			for seat: int in player_count:
				bots.append(MatchRunner.make_bot(bot_name, seat, 7))
			var steps: int = 0
			while not tc.state.is_over() and steps < MatchRunner.MAX_INTENTS:
				steps += 1
				var intent: Intent = bots[tc.state.current_seat].choose(tc)
				var error: String = tc.submit(intent)
				if not error.is_empty():
					fail_test("%s bot made an illegal move: %s" % [bot_name, error])
					return
			assert_true(tc.state.is_over(), "%s x%d finished" % [bot_name, player_count])


func test_matches_between_bots_are_replayable() -> void:
	var names: Array[String] = ["greedy", "random", "greedy"]
	assert_eq(_describe_log(MatchRunner.play(42, names)), _describe_log(MatchRunner.play(42, names)))


# --- GreedyBot heuristics ------------------------------------------------------------

func test_greedy_draws_first() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_true(GreedyBot.new(0, 1).choose(tc) is Intents.DrawCard)


func test_greedy_discards_its_weakest_card_when_full() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	var hand: Array[CardData] = []
	for i: int in Config.HAND_CAP:
		hand.append(_card(&"thornlash"))
	hand[4] = _card(&"ember")
	tc.state.player(0).hand = hand
	var intent: Intent = GreedyBot.new(0, 1).choose(tc)
	assert_true(intent is Intents.DiscardCard)
	assert_eq((intent as Intents.DiscardCard).hand_index, 4)


func test_greedy_plays_targeted_against_a_neutral_field() -> void:
	var tc: TurnController = _decision(4, [_card(&"thornlash")])
	var intent := GreedyBot.new(0, 1).choose(tc) as Intents.PlayCard
	assert_not_null(intent)
	assert_eq(intent.mode, CardData.Mode.TARGETED)


func test_greedy_exploits_type_advantage() -> void:
	var tc: TurnController = _decision(3, [_card(&"thornlash")])
	tc.state.player(1).element = Element.Type.FIRE
	tc.state.player(2).element = Element.Type.WATER
	var intent := GreedyBot.new(0, 1).choose(tc) as Intents.PlayCard
	assert_eq(intent.target_seat, 2, "Grass is strong against Water")


func test_greedy_goes_collective_when_the_field_is_weak_to_it() -> void:
	var tc: TurnController = _decision(4, [_card(&"thornlash")])
	tc.state.player(1).element = Element.Type.FIRE
	tc.state.player(2).element = Element.Type.WATER
	tc.state.player(3).element = Element.Type.WATER
	var intent := GreedyBot.new(0, 1).choose(tc) as Intents.PlayCard
	assert_eq(intent.mode, CardData.Mode.COLLECTIVE)


func test_greedy_stands_the_joker_down_when_it_is_the_target() -> void:
	var tc: TurnController = _decision(3, [_card(&"stand_down")])
	tc.state.player(0).heat = 9
	var intent := GreedyBot.new(0, 1).choose(tc) as Intents.PlayCard
	assert_not_null(intent)
	assert_eq(tc.state.player(0).hand[intent.hand_index].id, &"stand_down")


func test_greedy_holds_stand_down_when_someone_else_is_the_target() -> void:
	var tc: TurnController = _decision(3, [_card(&"stand_down")])
	tc.state.player(1).heat = 9
	assert_true(GreedyBot.new(0, 1).choose(tc) is Intents.EndTurn)


# --- Stats and report ----------------------------------------------------------------

func test_match_stats_record_who_eliminated_whom() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(1).hp = 10
	Fixtures.play_and_end(tc, Fixtures.attack(10), 1)
	tc.state.player(2).hp = 1
	Fixtures.skip_turn(tc)  # seat 2 skips -> round end: Joker hits the hottest (seat 0, 2 Heat)
	var names: Array[String] = ["a", "b", "c"]
	var stats: Dictionary = MatchStats.from_match(tc, names)
	assert_eq(stats["elimination_cause"][1], "card")
	assert_eq(stats["elimination_round"][1], 1)
	assert_eq(stats["plays"]["test_normal_10"], 1)


func test_report_adds_up() -> void:
	var names: Array[String] = ["greedy", "greedy", "random"]
	var deck: Array[CardData] = Deck.build_card_list(CardCatalog.load_all())
	var results: Array[Dictionary] = []
	for i: int in 10:
		results.append(MatchStats.from_match(MatchRunner.play(100 + i, names, deck), names))
	var summary: Dictionary = SimulationReport.summarize(results)
	assert_eq(summary["matches"], 10)
	assert_eq(summary["finished"], 10)
	var wins: float = 0.0
	for rate: float in summary["win_rate_by_seat"]:
		wins += rate
	assert_almost_eq(wins + summary["draw_rate"], 1.0, 0.0001, "every match has a winner or is a draw")
	assert_false(SimulationReport.to_text(summary).is_empty())
	assert_eq(SimulationReport.to_csv(results).split("\n").size(), 11, "header + one row per match")
