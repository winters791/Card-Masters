extends GutTest
## Traps (§4, §8): placement, firing, and the seven trap cards.

const Fixtures := preload("res://tests/support/fixtures.gd")

const W := Element.Type.WATER


func _card(id: StringName) -> CardData:
	var card: CardData = CardCatalog.by_id(id)
	assert_not_null(card, "card %s exists" % id)
	return card


## Puts a trap straight onto the table: on `host_seat`, or in the pool if -1.
func _plant(tc: TurnController, id: StringName, owner_seat: int, host_seat: int) -> PlacedTrap:
	var mode: CardData.Mode = CardData.Mode.COLLECTIVE if host_seat < 0 else CardData.Mode.TARGETED
	var trap := PlacedTrap.new(tc.state.next_trap_id, _card(id), owner_seat, host_seat, mode)
	tc.state.next_trap_id += 1
	tc.state.traps.append(trap)
	return trap


## The current player plays `card` at `target_seat` (or collectively if -1).
func _play(tc: TurnController, card: CardData, target_seat: int = -1, chosen: int = -1) -> String:
	var seat: int = tc.state.current_seat
	Fixtures.give(tc, seat, card)
	var mode: CardData.Mode = CardData.Mode.COLLECTIVE if target_seat < 0 else CardData.Mode.TARGETED
	return tc.submit(Intents.PlayCard.new(seat, 0, mode, target_seat, chosen))


func _finish_round(tc: TurnController) -> void:
	var round_number: int = tc.state.round_number
	while tc.state.round_number == round_number and not tc.state.is_over():
		Fixtures.skip_turn(tc)


func _fired(tc: TurnController) -> Array[StringName]:
	var ids: Array[StringName] = []
	for event: GameEvent in Fixtures.events_of(tc, GameEvents.TrapFired):
		ids.append((event as GameEvents.TrapFired).card.id)
	return ids


func test_card_data() -> void:
	# id: [base heat, rarity, mode lock]
	var expected: Dictionary = {
		&"poison_to_healing": [1, CardData.Rarity.COMMON, CardData.ModeLock.NONE],
		&"joker_deflect": [2, CardData.Rarity.UNCOMMON, CardData.ModeLock.NONE],
		&"backfire": [2, CardData.Rarity.UNCOMMON, CardData.ModeLock.NONE],
		&"tripwire": [1, CardData.Rarity.COMMON, CardData.ModeLock.NONE],
		&"type_snare": [2, CardData.Rarity.UNCOMMON, CardData.ModeLock.NONE],
		&"grudge": [2, CardData.Rarity.UNCOMMON, CardData.ModeLock.NONE],
		&"wellspring": [1, CardData.Rarity.COMMON, CardData.ModeLock.COLLECTIVE_ONLY],
	}
	for id: StringName in expected:
		var card: CardData = _card(id)
		var row: Array = expected[id]
		assert_eq(card.family, CardData.Family.TRAP, "%s family" % id)
		assert_eq(card.slot(), CardData.Slot.ONE, "%s slot" % id)
		assert_eq(card.base_heat, row[0], "%s base heat" % id)
		assert_eq(card.rarity, row[1], "%s rarity" % id)
		assert_eq(card.mode_lock, row[2], "%s mode lock" % id)


# --- Placement ---------------------------------------------------------------------

func test_placing_costs_no_heat_and_keeps_the_card_on_the_table() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	assert_eq(_play(tc, _card(&"backfire"), 1), "")
	assert_eq(tc.state.player(0).heat, 0, "Heat lands when it fires")
	assert_eq(tc.state.traps.size(), 1)
	assert_eq(tc.state.traps[0].host_seat, 1)
	assert_false(tc.state.deck.discard_pile.has(_card(&"backfire")))
	assert_eq(Fixtures.events_of(tc, GameEvents.CardPlayed).size(), 0, "not revealed as a normal play")


func test_placing_a_trap_is_not_a_skip() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	_play(tc, _card(&"tripwire"))
	tc.submit(Intents.EndTurn.new(0))
	assert_eq(Fixtures.events_of(tc, GameEvents.PlayerSkipped).size(), 0)


func test_cannot_place_a_trap_on_yourself_but_can_in_the_pool() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_ne(_play(tc, _card(&"backfire"), 0), "")
	tc.state.player(0).hand.pop_front()
	assert_eq(_play(tc, _card(&"backfire")), "")
	assert_eq(tc.state.traps[0].host_seat, PlacedTrap.POOL)


func test_others_see_where_a_trap_is_but_not_what_or_whose() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_play(tc, _card(&"grudge"), 2)
	var theirs: Dictionary = tc.state.get_view_for(1)
	assert_eq(theirs["traps"], [{"trap_id": 1, "host_seat": 2}])
	var mine: Dictionary = tc.state.get_view_for(0)
	assert_eq(mine["traps"][0]["card"], _card(&"grudge"))
	var placed: GameEvents.TrapPlaced = null
	for event: GameEvent in tc.state.get_events_for(1):
		if event is GameEvents.TrapPlaced:
			placed = event
	assert_eq(placed.host_seat, 2)
	assert_eq(placed.card, null)
	assert_eq(placed.owner_seat, -1)


# --- Firing ------------------------------------------------------------------------

func test_firing_reveals_the_trap_and_lands_its_heat_once() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"tripwire", 2, 1)  # on seat 1: 1 x2 = 2 Heat when it fires
	_play(tc, Fixtures.attack(0), 1)
	var fired := Fixtures.events_of(tc, GameEvents.TrapFired)[0] as GameEvents.TrapFired
	assert_eq(fired.owner_seat, 2)
	assert_eq(fired.card.id, &"tripwire")
	assert_eq(tc.state.player(2).heat, 2)
	assert_true(tc.state.traps.is_empty(), "one-shot")
	assert_true(tc.state.deck.discard_pile.has(_card(&"tripwire")))


func test_pool_traps_cost_base_heat_when_they_fire() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"tripwire", 2, -1)
	_play(tc, Fixtures.attack(0), 1)
	assert_eq(tc.state.player(2).heat, 1)


func test_a_trap_on_a_player_only_watches_that_player() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"tripwire", 2, 1)
	_play(tc, Fixtures.attack(0), 2)
	assert_eq(_fired(tc), [])
	assert_eq(tc.state.traps.size(), 1)


func test_only_the_oldest_of_two_identical_traps_fires() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	var oldest: PlacedTrap = _plant(tc, &"tripwire", 2, 1)
	_plant(tc, &"tripwire", 2, 1)
	_play(tc, Fixtures.attack(0), 1)
	assert_eq(_fired(tc), [&"tripwire"])
	assert_false(tc.state.traps.has(oldest))
	assert_eq(tc.state.traps.size(), 1)


func test_traps_on_an_eliminated_player_are_removed() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"grudge", 0, 1)
	tc.state.player(1).hp = 10
	_play(tc, Fixtures.attack(10), 1)
	assert_true(tc.state.traps.is_empty())
	assert_eq(Fixtures.events_of(tc, GameEvents.TrapRemoved).size(), 1)


# --- Poison to Healing -------------------------------------------------------------

func test_poison_to_healing_turns_the_poison_into_healing() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"poison_to_healing", 2, 1)
	tc.state.player(1).hp = 70
	_play(tc, _card(&"venom"), 1)
	assert_true(tc.state.player(1).poisons.is_empty())
	assert_eq(tc.state.player(1).heals.size(), 1)
	assert_eq(tc.state.player(2).heat, 2)
	tc.submit(Intents.EndTurn.new(0))
	_finish_round(tc)
	assert_eq(tc.state.player(1).hp, 73, "heals 3 in the poison step")


func test_healing_never_goes_above_100() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	tc.state.player(1).hp = 98
	assert_eq(tc.heal(1, 10, &"test"), 2)
	assert_eq(tc.state.player(1).hp, 100)


func test_pool_poison_to_healing_catches_venom_fang_too() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	_plant(tc, &"poison_to_healing", 1, -1)
	tc.add_joker_modifier(JokerModifier.VENOM_FANG, 1, {"tick_damage": 5, "rounds": 3})
	_finish_round(tc)
	assert_eq(_fired(tc), [&"poison_to_healing"])
	var poisoned: int = tc.state.player(0).poisons.size() + tc.state.player(1).poisons.size()
	assert_eq(poisoned, 1, "the first poison turned into healing, the second landed")


# --- Joker Deflect -----------------------------------------------------------------

func test_joker_deflect_sends_the_hit_two_seats_anticlockwise() -> void:
	var tc: TurnController = Fixtures.new_match(4)
	_plant(tc, &"joker_deflect", 0, 3)
	tc.state.player(3).heat = 10
	_finish_round(tc)
	assert_eq(tc.state.player(3).hp, 100)
	assert_eq(tc.state.player(3).heat, 11, "not hit, so no Heat reset")
	assert_eq(tc.state.player(1).hp, 90, "3 -> 2 -> 1")
	assert_eq(tc.state.player(1).heat, 0)
	assert_eq(tc.state.player(0).heat, 5, "skip 1 + Deflect 2 x2")


func test_joker_deflect_counts_living_players_only() -> void:
	var tc: TurnController = Fixtures.new_match(4)
	tc.state.player(2).hp = 0
	tc.state.player(2).is_alive = false
	_plant(tc, &"joker_deflect", 0, 3)
	tc.state.player(3).heat = 10
	_finish_round(tc)
	assert_eq(tc.state.player(0).hp, 90, "3 -> (2 is out) 1 -> 0")


func test_joker_deflect_with_two_players_goes_to_the_other_one() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	_plant(tc, &"joker_deflect", 1, -1)
	tc.state.player(1).heat = 10
	_finish_round(tc)
	assert_eq(tc.state.player(1).hp, 100)
	assert_eq(tc.state.player(0).hp, 90)


# --- Backfire ----------------------------------------------------------------------

func test_backfire_bounces_a_damage_card_back_at_its_player() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"backfire", 2, 1)
	tc.state.player(0).element = Element.Type.WATER
	assert_eq(_play(tc, _card(&"thornlash"), 1), "")
	assert_eq(tc.state.player(1).hp, 100)
	assert_eq(tc.state.player(0).hp, 80, "10 Grass at 2x vs its Water player")
	assert_eq(tc.state.player(0).heat, 4, "still pays the card's Heat")


func test_backfire_ignores_cards_without_direct_damage() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"backfire", 2, 1)
	_play(tc, _card(&"venom"), 1)
	assert_eq(tc.state.player(1).poisons.size(), 1)
	assert_eq(tc.state.traps.size(), 1, "still waiting")


func test_backfire_bounces_shed_skin_damage_but_not_the_type_change() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"backfire", 2, 1)
	_play(tc, _card(&"shed_skin"), 1, Element.Type.FIRE)
	assert_eq(tc.state.player(0).element, Element.Type.FIRE)
	assert_eq(tc.state.player(0).hp, 95)
	assert_eq(tc.state.player(1).hp, 100)


# --- Tripwire ----------------------------------------------------------------------

func test_tripwire_heats_the_next_targeted_player() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"tripwire", 2, 1)
	_play(tc, _card(&"venom"), 1)
	assert_eq(tc.state.player(0).heat, 5, "Venom 2 + Tripwire 3")


func test_pool_tripwire_catches_a_trap_placed_on_a_player() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"tripwire", 2, -1)
	_play(tc, _card(&"grudge"), 1)
	assert_eq(tc.state.player(0).heat, 3)


func test_tripwire_ignores_collective_plays() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"tripwire", 2, -1)
	_play(tc, Fixtures.attack(0))
	assert_eq(_fired(tc), [])


# --- Type Snare --------------------------------------------------------------------

func test_type_snare_hits_the_next_player_to_change_type() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"type_snare", 2, 1)
	_play(tc, _card(&"convert"), 1, Element.Type.GRASS)
	assert_eq(tc.state.player(1).element, Element.Type.GRASS)
	assert_eq(tc.state.player(1).hp, 90)


func test_type_snare_ignores_failed_changes() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"type_snare", 2, 1)
	tc.apply_root(1, 0)
	_play(tc, _card(&"convert"), 1, Element.Type.GRASS)
	assert_eq(_fired(tc), [])


# --- Grudge ------------------------------------------------------------------------

func test_grudge_passes_the_joker_hit_to_the_hottest_other_player() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"grudge", 0, 1)
	tc.state.player(1).heat = 10
	tc.state.player(2).heat = 6
	_finish_round(tc)
	assert_eq(tc.state.player(1).hp, 90)
	assert_eq(tc.state.player(2).hp, 90, "hottest other player (7), same 10")
	assert_eq(tc.state.player(0).hp, 100, "owner at 1 + 4 Heat = 5")


func test_grudge_owner_heat_lands_first_and_can_make_them_the_hottest() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"grudge", 0, 1)
	tc.state.player(1).heat = 10
	tc.state.player(2).heat = 4
	_finish_round(tc)  # owner 1 + 4 = 5 ties seat 2 at 5
	assert_eq(tc.state.player(0).hp, 90)
	assert_eq(tc.state.player(2).hp, 90)


# --- Wellspring --------------------------------------------------------------------

func test_wellspring_is_pool_only() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	assert_ne(_play(tc, _card(&"wellspring"), 1), "")


func test_wellspring_heals_water_players_after_a_water_card_hits_the_pool() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	_plant(tc, &"wellspring", 2, -1)
	tc.state.player(1).element = W
	tc.state.player(2).element = W
	assert_eq(_play(tc, _card(&"tidal_crash")), "")
	assert_eq(tc.state.player(0).hp, 90, "Normal: hit, not healed")
	assert_eq(tc.state.player(1).hp, 100, "Water: hit for 10, healed 10")
	assert_eq(tc.state.player(2).hp, 100)


func test_wellspring_ignores_other_cards() -> void:
	var tc: TurnController = Fixtures.new_match(2)
	_plant(tc, &"wellspring", 1, -1)
	_play(tc, _card(&"ember"))
	assert_eq(_fired(tc), [])
