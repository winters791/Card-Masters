extends GutTest

const Fixtures := preload("res://tests/support/fixtures.gd")


func _joker_attacks(tc: TurnController) -> Array[GameEvent]:
	return Fixtures.events_of(tc, GameEvents.JokerAttacked)


func test_damage_grows_by_ten_each_round() -> void:
	assert_eq(JokerState.damage_for_round(1), 10)
	assert_eq(JokerState.damage_for_round(2), 20)
	assert_eq(JokerState.damage_for_round(5), 50)
	assert_eq(JokerState.damage_for_round(10), 100)


func test_starts_as_normal_type() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_eq(tc.state.joker.element, Element.Type.NORMAL)


func test_hits_the_highest_heat_player_at_round_end() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.play_and_end(tc, Fixtures.attack(0, Element.Type.NORMAL, 2), 1)  # seat 0: 4 Heat
	Fixtures.skip_turn(tc)  # seat 1: 1 Heat
	Fixtures.skip_turn(tc)  # seat 2: 1 Heat, round ends
	var attack := _joker_attacks(tc)[0] as GameEvents.JokerAttacked
	assert_eq(attack.target_seats, [0])
	assert_eq(attack.damage, 10)
	assert_eq(tc.state.player(0).hp, 90)
	assert_eq(tc.state.player(1).hp, 100)


func test_heat_resets_only_for_the_player_hit() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.play_and_end(tc, Fixtures.attack(0, Element.Type.NORMAL, 2), 1)
	Fixtures.skip_turn(tc)
	Fixtures.skip_turn(tc)
	assert_eq(tc.state.player(0).heat, 0)
	assert_eq(tc.state.player(1).heat, 1)
	assert_eq(tc.state.player(2).heat, 1)


func test_ties_hit_everyone_tied_for_full_damage() -> void:
	# Everyone skipping in round 1 ties at 1 Heat (§5).
	var tc: TurnController = Fixtures.new_match(3)
	for i: int in 3:
		Fixtures.skip_turn(tc)
	var attack := _joker_attacks(tc)[0] as GameEvents.JokerAttacked
	assert_eq(attack.target_seats, [0, 1, 2])
	for p: PlayerState in tc.state.players:
		assert_eq(p.hp, 90)
		assert_eq(p.heat, 0)


func test_uses_its_type_against_the_target() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.state.joker.element = Element.Type.FIRE
	tc.state.player(0).element = Element.Type.GRASS
	tc.state.player(1).element = Element.Type.WATER
	Fixtures.skip_turn(tc)
	Fixtures.skip_turn(tc)
	assert_eq(tc.state.player(0).hp, 80, "Fire vs Grass 2x")
	assert_eq(tc.state.player(1).hp, 95, "Fire vs Water 0.5x")


func test_second_round_hits_harder() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	for i: int in 4:
		Fixtures.skip_turn(tc)
	var attacks: Array[GameEvent] = _joker_attacks(tc)
	assert_eq(attacks.size(), 2)
	assert_eq((attacks[1] as GameEvents.JokerAttacked).damage, 20)
	assert_eq(tc.state.player(0).hp, 70)
	assert_eq(tc.state.round_number, 3)
