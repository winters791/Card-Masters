extends GutTest
## Damage over time family (§8): Venom, Scorch, Rot.

const Fixtures := preload("res://tests/support/fixtures.gd")


func _card(id: StringName) -> CardData:
	var card: CardData = CardCatalog.by_id(id)
	assert_not_null(card, "card %s exists" % id)
	return card


func _ticks(tc: TurnController, cause: StringName, target_seat: int) -> Array[int]:
	var damages: Array[int] = []
	for event: GameEvent in Fixtures.events_of(tc, GameEvents.DamageDealt):
		var hit := event as GameEvents.DamageDealt
		if hit.cause == cause and hit.target_seat == target_seat:
			damages.append(hit.damage)
	return damages


## Skips turns until `rounds` more rounds have ended.
func _finish_rounds(tc: TurnController, rounds: int) -> void:
	var target_round: int = tc.state.round_number + rounds
	while tc.state.round_number < target_round and not tc.state.is_over():
		Fixtures.skip_turn(tc)


func _poison_card_data_check(id: StringName, base_heat: int, rarity: CardData.Rarity) -> void:
	var card: CardData = _card(id)
	assert_eq(card.family, CardData.Family.DAMAGE_OVER_TIME, "%s family" % id)
	assert_eq(card.slot(), CardData.Slot.TWO, "%s slot" % id)
	assert_eq(card.base_heat, base_heat, "%s base heat" % id)
	assert_eq(card.rarity, rarity, "%s rarity" % id)
	assert_false(card.deals_direct_damage(), "%s has no direct damage" % id)


func test_card_data() -> void:
	_poison_card_data_check(&"venom", 1, CardData.Rarity.COMMON)
	_poison_card_data_check(&"scorch", 1, CardData.Rarity.COMMON)
	_poison_card_data_check(&"rot", 2, CardData.Rarity.UNCOMMON)


# --- Venom -----------------------------------------------------------------------

func test_venom_heat_has_no_direct_damage_bonus() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.play_and_end(tc, _card(&"venom"), 1)
	assert_eq(tc.state.player(0).heat, 2)


func test_venom_ticks_three_for_three_round_ends_starting_this_round() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.play_and_end(tc, _card(&"venom"), 1)
	_finish_rounds(tc, 1)
	assert_eq(_ticks(tc, Status.POISON, 1), [3], "ticks at the end of the round it was applied")
	_finish_rounds(tc, 3)
	assert_eq(_ticks(tc, Status.POISON, 1), [3, 3, 3], "then stops after 3")
	assert_true(tc.state.player(1).poisons.is_empty())
	assert_eq(Fixtures.events_of(tc, GameEvents.StatusEnded).size(), 1)


func test_venom_stacks() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.play_and_end(tc, _card(&"venom"), 2)
	Fixtures.play_and_end(tc, _card(&"venom"), 2)
	_finish_rounds(tc, 1)
	assert_eq(_ticks(tc, Status.POISON, 2), [3, 3])
	assert_eq(tc.state.player(2).poisons.size(), 2)


func test_collective_venom_poisons_everyone_including_the_player() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.play_and_end(tc, _card(&"venom"))
	for p: PlayerState in tc.state.players:
		assert_eq(p.poisons.size(), 1, "seat %d" % p.seat)


# --- Scorch ----------------------------------------------------------------------

func test_scorch_burns_five_every_round_until_type_change() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.play_and_end(tc, _card(&"scorch"), 1)
	_finish_rounds(tc, 4)
	assert_eq(_ticks(tc, Status.BURN, 1), [5, 5, 5, 5])
	assert_eq(tc.state.player(1).burns.size(), 1, "never expires on its own")


func test_scorch_stacks() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.play_and_end(tc, _card(&"scorch"), 2)
	Fixtures.play_and_end(tc, _card(&"scorch"), 2)
	_finish_rounds(tc, 1)
	assert_eq(_ticks(tc, Status.BURN, 2), [5, 5])


func test_changing_type_puts_out_every_burn() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.play_and_end(tc, _card(&"scorch"), 1)
	tc.apply_burn(1, 10, 2)
	tc.change_element(1, Element.Type.WATER)
	assert_true(tc.state.player(1).burns.is_empty())
	var ended := Fixtures.events_of(tc, GameEvents.StatusEnded)[0] as GameEvents.StatusEnded
	assert_eq(ended.status, Status.BURN)
	assert_eq(ended.reason, &"type_changed")
	_finish_rounds(tc, 1)
	assert_eq(_ticks(tc, Status.BURN, 1), [])


func test_setting_the_same_type_keeps_burns() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.apply_burn(1, 10, 0)
	tc.change_element(1, Element.Type.NORMAL)
	assert_eq(tc.state.player(1).burns.size(), 1)


func test_burn_damage_ignores_type() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(1).element = Element.Type.WATER
	tc.state.player(2).element = Element.Type.GRASS
	tc.apply_burn(1, 10, 0)
	tc.apply_burn(2, 10, 0)
	_finish_rounds(tc, 1)
	assert_eq(_ticks(tc, Status.BURN, 1), [10])
	assert_eq(_ticks(tc, Status.BURN, 2), [10])


# --- Rot -------------------------------------------------------------------------

func test_rot_heat() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.play_and_end(tc, _card(&"rot"), 1)
	assert_eq(tc.state.player(0).heat, 4)


func test_rot_halves_the_next_resist_then_is_used_up() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(2).element = Element.Type.WATER
	Fixtures.play_and_end(tc, _card(&"rot"), 2)
	assert_true(tc.state.player(2).is_rotted)
	Fixtures.play_and_end(tc, Fixtures.attack(20, Element.Type.FIRE), 2)  # seat 1
	assert_eq(tc.state.player(2).hp, 85, "20 at 0.75x instead of 0.5x")
	assert_false(tc.state.player(2).is_rotted)
	tc.deal_damage(0, 2, 20, Element.Type.FIRE)
	assert_eq(tc.state.player(2).hp, 75, "back to a normal resist")


func test_rot_ignores_neutral_and_strong_hits() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.state.player(1).element = Element.Type.WATER
	tc.apply_rot(1, 0)
	tc.deal_damage(0, 1, 20, Element.Type.NORMAL)
	tc.deal_damage(0, 1, 10, Element.Type.GRASS)
	assert_eq(tc.state.player(1).hp, 60, "20 + 20, no change")
	assert_true(tc.state.player(1).is_rotted, "still waiting for a resist")


func test_rot_does_not_stack() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(2).element = Element.Type.WATER
	Fixtures.play_and_end(tc, _card(&"rot"), 2)
	Fixtures.play_and_end(tc, _card(&"rot"), 2)
	assert_eq(Fixtures.events_of(tc, GameEvents.StatusApplied).size(), 1, "second Rot does nothing")
	tc.deal_damage(0, 2, 20, Element.Type.FIRE)
	tc.deal_damage(0, 2, 20, Element.Type.FIRE)
	assert_eq(tc.state.player(2).hp, 75, "15 then 10: only one halved resist")


func test_rot_triggers_on_a_resisted_joker_hit() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.state.joker.element = Element.Type.FIRE
	tc.state.player(1).element = Element.Type.WATER
	tc.apply_rot(1, 0)
	Fixtures.skip_turn(tc)
	Fixtures.skip_turn(tc)  # tie: the Joker hits both for 10
	assert_eq(tc.state.player(1).hp, 93, "10 at 0.75x = 7.5, rounds down to 7")
	assert_false(tc.state.player(1).is_rotted)
