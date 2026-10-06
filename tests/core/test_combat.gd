extends GutTest

const Fixtures := preload("res://tests/support/fixtures.gd")


func test_targeted_attack_damages_only_the_target() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.play_and_end(tc, Fixtures.attack(20), 2)
	assert_eq(tc.state.player(0).hp, 100)
	assert_eq(tc.state.player(1).hp, 100)
	assert_eq(tc.state.player(2).hp, 80)


func test_collective_attack_hits_everyone_including_the_player() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.play_and_end(tc, Fixtures.attack(15))
	for p: PlayerState in tc.state.players:
		assert_eq(p.hp, 85)
	assert_eq(Fixtures.events_of(tc, GameEvents.DamageDealt).size(), 3)


func test_type_multipliers_apply_per_target() -> void:
	var tc: TurnController = Fixtures.new_match(4)
	tc.state.player(0).element = Element.Type.FIRE
	tc.state.player(1).element = Element.Type.GRASS
	tc.state.player(2).element = Element.Type.WATER
	Fixtures.play_and_end(tc, Fixtures.attack(15, Element.Type.FIRE))
	assert_eq(tc.state.player(0).hp, 85, "Fire vs Fire 1x")
	assert_eq(tc.state.player(1).hp, 70, "Fire vs Grass 2x")
	assert_eq(tc.state.player(2).hp, 93, "Fire vs Water 0.5x, 7.5 rounds down")
	assert_eq(tc.state.player(3).hp, 85, "Fire vs Normal 1x")


func test_damage_event_records_the_hit() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.state.player(1).element = Element.Type.WATER
	Fixtures.play_and_end(tc, Fixtures.attack(20, Element.Type.GRASS), 1)
	var hit := Fixtures.events_of(tc, GameEvents.DamageDealt)[0] as GameEvents.DamageDealt
	assert_eq(hit.source_seat, 0)
	assert_eq(hit.target_seat, 1)
	assert_eq(hit.base_damage, 20)
	assert_eq(hit.multiplier, 2.0)
	assert_eq(hit.damage, 40)
	assert_eq(hit.hp_after, 60)


func test_hp_does_not_go_below_zero() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(1).hp = 5
	Fixtures.play_and_end(tc, Fixtures.attack(40), 1)
	assert_eq(tc.state.player(1).hp, 0)


func test_player_at_zero_hp_is_eliminated() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(1).hp = 10
	Fixtures.play_and_end(tc, Fixtures.attack(10), 1)
	assert_false(tc.state.player(1).is_alive)
	var elim := Fixtures.events_of(tc, GameEvents.PlayerEliminated)[0] as GameEvents.PlayerEliminated
	assert_eq(elim.seat, 1)
	assert_false(tc.state.is_over(), "two players remain")
	assert_eq(tc.state.current_seat, 2, "seat 1 loses its turn")


func test_killing_yourself_with_a_collective_card_ends_your_turn() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(0).hp = 10
	Fixtures.keep_first(tc)
	Fixtures.give(tc, 0, Fixtures.attack(10))
	tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.COLLECTIVE))
	assert_false(tc.state.player(0).is_alive)
	assert_eq(tc.state.current_seat, 1)
	assert_eq(Fixtures.events_of(tc, GameEvents.PlayerSkipped).size(), 0)
