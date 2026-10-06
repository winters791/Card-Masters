extends GutTest
## Dry Well (§8, hand and turn disruption): the target can't discard on their next
## turn, so they keep every card they draw; with a full hand they can't draw at all.

const Fixtures := preload("res://tests/support/fixtures.gd")


func _dry_well() -> CardData:
	return CardCatalog.by_id(&"dry_well")


## Seat 0 plays Dry Well at `target_seat` (or collectively if -1) and ends the turn.
func _play(player_count: int, target_seat: int) -> TurnController:
	var tc: TurnController = Fixtures.new_match(player_count)
	assert_eq(Fixtures.play_and_end(tc, _dry_well(), target_seat), "")
	return tc


func test_card_data() -> void:
	var card: CardData = _dry_well()
	assert_not_null(card)
	assert_eq(card.family, CardData.Family.DISRUPTION)
	assert_eq(card.slot(), CardData.Slot.TWO)
	assert_eq(card.base_heat, 1)
	assert_eq(card.rarity, CardData.Rarity.COMMON)
	assert_eq(card.mode_lock, CardData.ModeLock.NONE)


func test_heat_is_base_times_mode_with_no_damage_bonus() -> void:
	assert_eq(_play(2, 1).state.player(0).heat, 2, "targeted")
	assert_eq(_play(2, -1).state.player(0).heat, 1, "collective")


func test_target_cannot_discard_on_their_next_turn() -> void:
	var tc: TurnController = _play(2, 1)
	assert_eq(tc.state.current_seat, 1)
	assert_false(tc.can_discard())
	assert_ne(tc.submit(Intents.DiscardCard.new(1, 0)), "")


func test_target_can_still_draw_up_to_three_and_keeps_them_all() -> void:
	var tc: TurnController = _play(2, 1)
	assert_eq(Fixtures.draw(tc, 3), "")
	assert_eq(tc.state.player(1).hand.size(), 10)
	assert_ne(tc.submit(Intents.DiscardCard.new(1, 9)), "", "can't drop the card just drawn either")


func test_target_with_a_full_hand_cannot_draw() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	for i: int in 3:
		Fixtures.give(tc, 1, Fixtures.attack(i))
	Fixtures.play_and_end(tc, _dry_well(), 1)
	assert_eq(tc.state.player(1).hand.size(), Config.HAND_CAP)
	assert_false(tc.can_draw())
	assert_false(tc.can_discard())


func test_lasts_only_one_turn() -> void:
	var tc: TurnController = _play(2, 1)
	Fixtures.skip_turn(tc)  # seat 1's restricted turn; round 2 starts with seat 1
	assert_eq(tc.state.current_seat, 1)
	assert_true(tc.can_discard())


func test_targeted_play_leaves_the_player_unaffected() -> void:
	var tc: TurnController = _play(2, 1)
	Fixtures.skip_turn(tc)  # seat 1; round 2 starts with seat 1
	Fixtures.skip_turn(tc)  # seat 1 again (rotation); now seat 0
	assert_eq(tc.state.current_seat, 0)
	assert_true(tc.can_discard())


func test_collective_play_hits_everyone_including_the_player_next_turn() -> void:
	var tc: TurnController = _play(3, -1)
	assert_eq(tc.state.current_seat, 1)
	assert_false(tc.can_discard(), "seat 1")
	Fixtures.skip_turn(tc)
	assert_false(tc.can_discard(), "seat 2")
	Fixtures.skip_turn(tc)  # round 2: seats 1, 2, 0
	assert_true(tc.can_discard(), "seat 1 again, restriction used up")
	Fixtures.skip_turn(tc)
	Fixtures.skip_turn(tc)
	assert_eq(tc.state.current_seat, 0)
	assert_false(tc.can_discard(), "the player's own next turn is dry too")


func test_restriction_is_public_and_reported() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.play_and_end(tc, _dry_well(), 2)
	var event := Fixtures.events_of(tc, GameEvents.TurnRestricted)[0] as GameEvents.TurnRestricted
	assert_eq(event.seat, 2)
	assert_eq(event.restriction, TurnRestriction.NO_DISCARD)
	var view: Dictionary = tc.state.get_view_for(1)
	assert_eq(view["players"][2]["next_turn_restrictions"], [TurnRestriction.NO_DISCARD])
