extends GutTest

const Fixtures := preload("res://tests/support/fixtures.gd")


func _card(family: CardData.Family, base_heat: int, damage: int = 0) -> CardData:
	var card := CardData.new()
	card.family = family
	card.base_heat = base_heat
	card.params = {"damage": damage}
	return card


func test_collective_is_base_heat() -> void:
	assert_eq(Heat.for_card(_card(CardData.Family.ATTACK, 2, 20), CardData.Mode.COLLECTIVE), 2)


func test_targeted_doubles_base_heat() -> void:
	assert_eq(Heat.for_card(_card(CardData.Family.ATTACK, 1, 10), CardData.Mode.TARGETED), 2)
	assert_eq(Heat.for_card(_card(CardData.Family.ATTACK, 2, 40), CardData.Mode.TARGETED), 4)


func test_attacks_get_no_direct_damage_bonus() -> void:
	assert_eq(Heat.for_card(_card(CardData.Family.ATTACK, 3, 40), CardData.Mode.TARGETED), 6)


func test_damaging_effect_adds_one_after_the_multiplier() -> void:
	# §5: a Base 2 targeted damage effect = 5.
	var effect: CardData = _card(CardData.Family.TYPE_MANIPULATION, 2, 10)
	assert_eq(Heat.for_card(effect, CardData.Mode.TARGETED), 5)
	assert_eq(Heat.for_card(effect, CardData.Mode.COLLECTIVE), 3)


func test_non_damaging_effect_has_no_bonus() -> void:
	var effect: CardData = _card(CardData.Family.DISRUPTION, 1)
	assert_eq(Heat.for_card(effect, CardData.Mode.TARGETED), 2)


func test_joker_modifiers_always_count_as_collective() -> void:
	var modifier: CardData = _card(CardData.Family.JOKER_MODIFIER, 3)
	assert_eq(Heat.for_card(modifier, CardData.Mode.TARGETED), 3)


func test_targeted_attack_in_a_match_adds_heat_to_the_attacker() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.play_and_end(tc, Fixtures.attack(10, Element.Type.FIRE, 2), 1)
	assert_eq(tc.state.player(0).heat, 4)
	assert_eq(tc.state.player(1).heat, 0, "the target gains no Heat")


func test_skip_adds_one_heat() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	Fixtures.skip_turn(tc)
	assert_eq(tc.state.player(0).heat, Config.SKIP_HEAT)
	assert_eq(Fixtures.events_of(tc, GameEvents.PlayerSkipped).size(), 1)
