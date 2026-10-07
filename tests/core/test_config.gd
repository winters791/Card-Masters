extends GutTest
## Balance overrides for the simulator (Phase 5). The game itself never calls these.


func after_each() -> void:
	Config.override("STARTING_HP", "100")
	Config.override("JOKER_DAMAGE_PER_ROUND", "10")
	Config.override("COPIES_COMMON", "4")


func test_override_changes_a_setting_for_new_matches() -> void:
	assert_eq(Config.override("STARTING_HP", "250"), "")
	assert_eq(Config.STARTING_HP, 250)
	assert_eq(Config.MAX_HP, 250, "the healing cap follows starting HP")
	var tc := TurnController.new(1, 2, Deck.build_card_list(CardCatalog.load_all()))
	assert_eq(tc.state.player(0).hp, 250)


func test_override_joker_growth() -> void:
	Config.override("JOKER_DAMAGE_PER_ROUND", "15")
	assert_eq(JokerState.damage_for_round(3), 40)


func test_override_copies_by_rarity() -> void:
	Config.override("COPIES_COMMON", "2")
	assert_eq(Deck.build_card_list(CardCatalog.load_all()).size(), 117 - 11 * 2)


func test_unknown_and_fixed_settings_are_refused() -> void:
	assert_ne(Config.override("BOGUS", "1"), "")
	assert_ne(Config.override("MAX_PLAYERS", "6"), "", "player count is not a balance dial")


func test_defaults_match_the_design_doc() -> void:
	assert_eq(Config.STARTING_HP, 100)
	assert_eq(Config.JOKER_BASE_DAMAGE, 10)
	assert_eq(Config.JOKER_DAMAGE_PER_ROUND, 10)
