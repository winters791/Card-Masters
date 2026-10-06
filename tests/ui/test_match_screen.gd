extends GutTest
## Phase 4: setup screen, hotseat match screen, pass-the-device, bots, timer, end.


func _screen(kinds: Array[String], match_seed: int = 5) -> MatchScreen:
	var screen := MatchScreen.new()
	add_child_autofree(screen)
	screen.set_process(false)  # tests drive bots and the timer by hand
	screen.start_match(kinds, match_seed)
	return screen


func test_setup_screen_defaults_and_start() -> void:
	var setup := SetupScreen.new()
	add_child_autofree(setup)
	assert_eq(setup.selected_kinds(), ["human", "human", "greedy", "greedy"] as Array[String])
	watch_signals(setup)
	setup.start_button.pressed.emit()
	assert_signal_emitted(setup, "start_requested")


func test_main_scene_starts_on_the_setup_screen() -> void:
	var main: Control = load("res://ui/main.tscn").instantiate()
	add_child_autofree(main)
	assert_true(main.get_children().any(func(c: Node) -> bool: return c is SetupScreen))


func test_two_humans_start_behind_the_pass_screen() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	assert_true(screen.awaiting_pass)
	assert_eq(screen.viewer_seat, -1, "nobody's hand on screen")
	screen.confirm_pass()
	assert_false(screen.awaiting_pass)
	assert_eq(screen.viewer_seat, 0)


func test_a_human_turn_draws_plays_and_hands_over() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen.confirm_pass()
	assert_eq(screen.submit(Intents.DrawCard.new(0)), "")
	var hand: Array[CardData] = screen.tc.state.player(0).hand
	hand.push_front(CardCatalog.by_id(&"ember"))
	screen.select_card(0)
	screen.select_mode(CardData.Mode.TARGETED)
	screen.select_target(1)
	assert_eq(screen.play_selected(), "")
	assert_eq(screen.tc.state.player(1).hp, 90)
	assert_eq(screen.submit(Intents.EndTurn.new(0)), "")
	assert_true(screen.awaiting_pass, "the next human gets the pass screen")
	assert_eq(screen.viewer_seat, -1)


func test_illegal_plays_show_a_message_and_change_nothing() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen.confirm_pass()
	screen.tc.state.player(0).hand.push_front(CardCatalog.by_id(&"ember"))
	screen.select_card(0)
	screen.select_mode(CardData.Mode.TARGETED)
	assert_ne(screen.play_selected(), "", "no target chosen")
	assert_ne(screen.message, "")
	assert_eq(screen.tc.state.player(1).hp, 100)


func test_one_human_never_sees_a_pass_screen() -> void:
	var screen: MatchScreen = _screen(["human", "greedy", "random"])
	assert_false(screen.awaiting_pass)
	assert_eq(screen.viewer_seat, 0)
	screen.submit(Intents.EndTurn.new(0))
	assert_eq(screen.tc.state.current_seat, 1)
	screen.step_bot()
	screen.step_bot()
	screen.step_bot()
	screen.step_bot()
	assert_false(screen.awaiting_pass)
	assert_eq(screen.viewer_seat, 0, "the device stays with the only human")


func test_the_turn_timer_times_out() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen.confirm_pass()
	screen._process(Config.TURN_TIMER_SECONDS + 1.0)
	assert_eq(screen.tc.state.current_seat, 1)
	assert_eq(screen.tc.state.player(0).heat, Config.SKIP_HEAT, "a timeout with no play is a skip")


func test_timer_waits_behind_the_pass_screen() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen._process(Config.TURN_TIMER_SECONDS + 1.0)
	assert_eq(screen.tc.state.current_seat, 0)


func test_an_all_bot_match_plays_to_the_end_screen() -> void:
	var screen: MatchScreen = _screen(["greedy", "random", "greedy"])
	var guard: int = 0
	while not screen.tc.state.is_over() and guard < MatchRunner.MAX_INTENTS:
		guard += 1
		screen.step_bot()
	assert_true(screen.tc.state.is_over())
	assert_true(screen._end_overlay.visible)
	watch_signals(screen)
	(screen._end_overlay.get_node("Box/NewMatch") as Button).pressed.emit()
	assert_signal_emitted(screen, "back_to_setup")


func test_log_lines_speak_in_players_and_drama() -> void:
	assert_eq(UiStyle.humanize("Seat 0 hits seat 2 for 10"), "Player 1 hits Player 3 for 10")
	assert_eq(UiStyle.humanize("Joker attacks seats [0, 2] for 10"), "Joker attacks Player 1, Player 3 for 10")
	assert_eq(UiStyle.humanize("Seat 1 Heat 0 -> 2 (card)"), "Player 2 Drama 0 -> 2 (card)")


func test_joker_preview_changes_nothing() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	var events_before: int = screen.tc.state.events.size()
	screen.tc.state.player(1).heat = 5
	assert_eq(screen.tc.preview_joker_targets(), [1])
	assert_eq(screen.tc.state.events.size(), events_before)
