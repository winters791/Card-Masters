extends GutTest
## Round end order (§6): traps -> burns -> poison -> Joker attack.

const Fixtures := preload("res://tests/support/fixtures.gd")


func _end_round(tc: TurnController) -> void:
	var round_number: int = tc.state.round_number
	while tc.state.round_number == round_number and not tc.state.is_over():
		Fixtures.skip_turn(tc)


func test_burns_then_poison_then_joker() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.apply_poison(1, 5, 3, 0)
	tc.apply_burn(1, 10, 0)
	_end_round(tc)
	var order: Array[StringName] = []
	for event: GameEvent in tc.state.events:
		if event is GameEvents.DamageDealt:
			order.append((event as GameEvents.DamageDealt).cause)
	assert_eq(order, [Status.BURN, Status.POISON, &"joker", &"joker"])


func test_burn_kill_ends_the_match_before_poison_and_joker() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.state.player(1).hp = 10
	tc.apply_burn(1, 10, 0)
	tc.apply_poison(0, 5, 3, 1)
	_end_round(tc)
	assert_true(tc.state.is_over())
	assert_eq(tc.state.winner_seat, 0)
	assert_eq(Fixtures.events_of(tc, GameEvents.JokerAttacked).size(), 0)
	assert_eq(tc.state.player(0).hp, 100, "the poison step never ran")


func test_players_killed_by_poison_are_not_joker_targets() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.play_and_end(tc, Fixtures.attack(0, Element.Type.NORMAL, 3), 1)  # seat 0: 6 Heat
	tc.state.player(0).hp = 5
	tc.apply_poison(0, 5, 3, 1)
	_end_round(tc)
	assert_false(tc.state.player(0).is_alive)
	var attack := Fixtures.events_of(tc, GameEvents.JokerAttacked)[0] as GameEvents.JokerAttacked
	assert_eq(attack.target_seats, [1, 2], "the hottest survivors, tied at 1")


# RULE-ASSUMPTION check: all ticks in one step land together, so two last players
# dying to burns in the same step is a draw.
func test_last_players_dying_in_the_same_tick_step_is_a_draw() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.state.player(0).hp = 10
	tc.state.player(1).hp = 10
	tc.apply_burn(0, 10, 1)
	tc.apply_burn(1, 10, 0)
	_end_round(tc)
	assert_true(tc.state.is_draw)
