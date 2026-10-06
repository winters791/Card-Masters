extends GutTest
## The Attacks family (§8): pure typed damage.

const Fixtures := preload("res://tests/support/fixtures.gd")


func _card(id: StringName) -> CardData:
	var card: CardData = CardCatalog.by_id(id)
	assert_not_null(card, "card %s exists" % id)
	return card


## Plays `card` from seat 0 at seat 1 (or collectively) and returns the controller.
func _play(card: CardData, mode: CardData.Mode, defender: Element.Type = Element.Type.NORMAL) -> TurnController:
	var tc: TurnController = Fixtures.new_match(3)
	tc.state.player(1).element = defender
	Fixtures.give(tc, 0, card)
	var target: int = 1 if mode == CardData.Mode.TARGETED else -1
	assert_eq(tc.submit(Intents.PlayCard.new(0, 0, mode, target)), "")
	return tc


func test_catalog_loads_every_card_with_a_known_effect() -> void:
	var cards: Array[CardData] = CardCatalog.load_all()
	var ids: Array[StringName] = []
	for card: CardData in cards:
		ids.append(card.id)
		assert_true(EffectRegistry.has_effect(card.effect_id), "%s has a registered effect" % card.id)
		assert_false(card.display_name.is_empty())
	for id: StringName in [&"ember", &"thornlash", &"tidal_crash", &"wildfire", &"cataclysm"]:
		assert_has(ids, id)


func test_attack_card_data() -> void:
	# id: [element, base heat, damage, rarity, mode lock]
	var expected: Dictionary = {
		&"ember": [Element.Type.FIRE, 1, 10, CardData.Rarity.COMMON, CardData.ModeLock.NONE],
		&"thornlash": [Element.Type.GRASS, 2, 20, CardData.Rarity.UNCOMMON, CardData.ModeLock.NONE],
		&"tidal_crash": [Element.Type.WATER, 2, 20, CardData.Rarity.UNCOMMON, CardData.ModeLock.NONE],
		&"wildfire": [Element.Type.FIRE, 1, 15, CardData.Rarity.COMMON, CardData.ModeLock.COLLECTIVE_ONLY],
		&"cataclysm": [Element.Type.NORMAL, 3, 40, CardData.Rarity.LEGENDARY, CardData.ModeLock.TARGETED_ONLY],
	}
	for id: StringName in expected:
		var card: CardData = _card(id)
		var row: Array = expected[id]
		assert_eq(card.family, CardData.Family.ATTACK, "%s family" % id)
		assert_eq(card.slot(), CardData.Slot.TWO, "%s slot" % id)
		assert_eq(card.element, row[0], "%s element" % id)
		assert_eq(card.base_heat, row[1], "%s base heat" % id)
		assert_eq(card.params["damage"], row[2], "%s damage" % id)
		assert_eq(card.rarity, row[3], "%s rarity" % id)
		assert_eq(card.mode_lock, row[4], "%s mode lock" % id)


func test_ember() -> void:
	var tc: TurnController = _play(_card(&"ember"), CardData.Mode.TARGETED, Element.Type.GRASS)
	assert_eq(tc.state.player(1).hp, 80, "10 Fire at 2x vs Grass")
	assert_eq(tc.state.player(0).heat, 2)


func test_thornlash() -> void:
	var tc: TurnController = _play(_card(&"thornlash"), CardData.Mode.TARGETED, Element.Type.WATER)
	assert_eq(tc.state.player(1).hp, 60, "20 Grass at 2x vs Water")
	assert_eq(tc.state.player(0).heat, 4)


func test_tidal_crash() -> void:
	var tc: TurnController = _play(_card(&"tidal_crash"), CardData.Mode.COLLECTIVE, Element.Type.GRASS)
	assert_eq(tc.state.player(1).hp, 90, "20 Water at 0.5x vs Grass")
	assert_eq(tc.state.player(0).hp, 80, "collective hits the player too")
	assert_eq(tc.state.player(0).heat, 2)


func test_wildfire_is_collective_only() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.give(tc, 0, _card(&"wildfire"))
	assert_ne(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 1)), "")
	assert_eq(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.COLLECTIVE)), "")
	for p: PlayerState in tc.state.players:
		assert_eq(p.hp, 85)
	assert_eq(tc.state.player(0).heat, 1)


func test_cataclysm_is_targeted_only() -> void:
	var tc: TurnController = Fixtures.new_match(3)
	Fixtures.give(tc, 0, _card(&"cataclysm"))
	assert_ne(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.COLLECTIVE)), "")
	assert_eq(tc.submit(Intents.PlayCard.new(0, 0, CardData.Mode.TARGETED, 2)), "")
	assert_eq(tc.state.player(2).hp, 60)
	assert_eq(tc.state.player(0).heat, 6)
