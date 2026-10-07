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


func _give(screen: MatchScreen, id: StringName) -> void:
	screen.tc.state.player(screen.tc.state.current_seat).hand.push_front(CardCatalog.by_id(id))
	screen.select_card(-1)  # refresh the hand on screen


func test_clicking_the_draw_pile_draws() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen.confirm_pass()
	assert_eq(screen.click_zone(DropZone.Kind.DRAW, -1), "")
	assert_eq(screen.tc.state.player(0).hand.size(), 8)


func test_dropping_on_a_players_pool_targets_them_then_the_device_moves_on() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen.confirm_pass()
	_give(screen, &"ember")
	assert_true(screen.can_drop(0, DropZone.Kind.PLAYER, 1))
	assert_false(screen.can_drop(0, DropZone.Kind.PLAYER, 0), "not at yourself")
	assert_eq(screen.drop_card(0, DropZone.Kind.PLAYER, 1), "")
	assert_eq(screen.tc.state.player(1).hp, 90)
	assert_eq(screen.end_turn(), "")
	assert_true(screen.awaiting_pass, "the next human gets the pass screen")
	assert_eq(screen.viewer_seat, -1)


func test_dropping_on_the_collective_pool_hits_everyone() -> void:
	var screen: MatchScreen = _screen(["human", "human", "greedy"])
	screen.confirm_pass()
	_give(screen, &"wildfire")
	assert_false(screen.can_drop(0, DropZone.Kind.PLAYER, 1), "Wildfire is pool only")
	assert_eq(screen.drop_card(0, DropZone.Kind.POOL, -1), "")
	for p: PlayerState in screen.tc.state.players:
		assert_eq(p.hp, 85)


func test_dropping_on_the_discard_pile_discards() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen.confirm_pass()
	_give(screen, &"ember")
	assert_eq(screen.drop_card(0, DropZone.Kind.DISCARD, -1), "")
	assert_eq(screen.tc.state.deck.discard_pile.back().id, &"ember")


func test_click_a_card_then_a_pool() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen.confirm_pass()
	_give(screen, &"ember")
	screen.select_card(0)
	assert_eq(screen.selected_index, 0)
	assert_eq(screen.click_zone(DropZone.Kind.PLAYER, 1), "")
	assert_eq(screen.tc.state.player(1).hp, 90)
	assert_eq(screen.selected_index, -1)


func test_type_cards_ask_for_a_type_first() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen.confirm_pass()
	_give(screen, &"convert")
	assert_eq(screen.drop_card(0, DropZone.Kind.PLAYER, 1), "")
	assert_false(screen.pending_play.is_empty(), "type picker open")
	assert_eq(screen.tc.state.player(1).element, Element.Type.NORMAL, "nothing played yet")
	assert_eq(screen.choose_element(Element.Type.FIRE), "")
	assert_eq(screen.tc.state.player(1).element, Element.Type.FIRE)


func test_illegal_drops_are_refused_and_change_nothing() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen.confirm_pass()
	_give(screen, &"cataclysm")
	assert_false(screen.can_drop(0, DropZone.Kind.POOL, -1), "Cataclysm is targeted only")
	assert_ne(screen.drop_card(0, DropZone.Kind.POOL, -1), "")
	assert_ne(screen.message, "")
	assert_eq(screen.tc.state.player(1).hp, 100)


func test_nothing_can_be_dropped_on_someone_elses_turn() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	_give(screen, &"ember")
	assert_false(screen.can_drop(0, DropZone.Kind.PLAYER, 1), "still behind the pass screen")


func test_one_human_never_sees_a_pass_screen() -> void:
	var screen: MatchScreen = _screen(["human", "greedy", "random"])
	assert_false(screen.awaiting_pass)
	assert_eq(screen.viewer_seat, 0)
	screen.end_turn()
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


func test_a_card_click_fires_on_release_so_drags_can_start() -> void:
	var view := CardView.make(CardCatalog.by_id(&"ember"))
	add_child_autofree(view)
	watch_signals(view)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	view._gui_input(press)
	assert_signal_not_emitted(view, "clicked", "pressing must not rebuild the hand")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	view._gui_input(release)
	assert_signal_emitted(view, "clicked")


func test_hand_cards_can_be_dragged_only_on_your_turn() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen.confirm_pass()
	var card: CardView = screen._hand_layer.get_child(0)
	assert_true(card.draggable)
	assert_eq(card.hand_index, 0)
	screen.end_turn()
	assert_true(screen.awaiting_pass, "player 2 is up, behind the pass screen")
	var live: Array[Node] = screen._hand_layer.get_children().filter(
			func(n: Node) -> bool: return not n.is_queued_for_deletion())
	assert_true(live.is_empty(), "no hand (so nothing to drag) behind the pass screen")


func test_turn_timer_is_two_minutes_shown_as_minutes() -> void:
	assert_eq(Config.TURN_TIMER_SECONDS, 120.0)
	assert_eq(MatchScreen._clock(120.0), "2:00")
	assert_eq(MatchScreen._clock(65.2), "1:06")
	assert_eq(MatchScreen._clock(-3.0), "0:00")


func test_two_minutes_are_not_up_after_thirty_seconds() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen.confirm_pass()
	screen._process(31.0)
	assert_eq(screen.tc.state.current_seat, 0, "still player 1's turn")


func _live_hand(screen: MatchScreen) -> Array[CardView]:
	var views: Array[CardView] = []
	for node: Node in screen._hand_layer.get_children():
		if not node.is_queued_for_deletion():
			views.append(node as CardView)
	return views


func _set_hand(screen: MatchScreen, ids: Array[StringName]) -> void:
	var hand: Array[CardData] = screen.tc.state.player(screen.tc.state.current_seat).hand
	hand.clear()
	for id: StringName in ids:
		hand.append(CardCatalog.by_id(id))
	screen.select_card(-1)


func _badge(view: CardView) -> Figures.SlotBadge:
	for node: Node in view.find_children("*", "", true, false):
		if node is Figures.SlotBadge:
			return node
	return null


func test_cards_show_a_star_for_slot_1_and_a_circle_for_slot_2() -> void:
	for id: StringName in [&"backfire", &"stand_down", &"ember", &"venom"]:
		var view := CardView.make(CardCatalog.by_id(id))
		add_child_autofree(view)
		var badge: Figures.SlotBadge = _badge(view)
		assert_not_null(badge, "%s has a slot badge" % id)
		assert_eq(badge.slot, view.card.slot(), "%s badge matches its slot" % id)
	assert_eq(UiStyle.slot_symbol(CardData.Slot.ONE), "star")
	assert_eq(UiStyle.slot_symbol(CardData.Slot.TWO), "circle")


func test_after_a_circle_card_the_other_circle_cards_go_dark() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen.confirm_pass()
	_set_hand(screen, [&"ember", &"backfire", &"venom", &"stand_down"])
	assert_true(_live_hand(screen).all(func(v: CardView) -> bool: return not v.spent), "nothing spent yet")
	assert_eq(screen.drop_card(0, DropZone.Kind.PLAYER, 1), "")
	for view: CardView in _live_hand(screen):
		var circle: bool = view.card.slot() == CardData.Slot.TWO
		assert_eq(view.spent, circle, "%s spent" % view.card.id)
		assert_eq(view.draggable, not circle, "%s draggable" % view.card.id)


func test_clicking_a_spent_card_explains_instead_of_selecting() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen.confirm_pass()
	_set_hand(screen, [&"ember", &"venom"])
	screen.drop_card(0, DropZone.Kind.PLAYER, 1)
	var venom: CardView = _live_hand(screen)[0]
	venom.clicked.emit(venom)
	assert_eq(screen.selected_index, -1)
	assert_string_contains(screen.message, "circle")


func test_silenced_players_see_everything_dark_after_one_card() -> void:
	var screen: MatchScreen = _screen(["human", "human"])
	screen.confirm_pass()
	screen.tc.state.turn_restrictions.append(TurnRestriction.ONE_CARD)
	_set_hand(screen, [&"ember", &"backfire"])
	screen.drop_card(0, DropZone.Kind.PLAYER, 1)
	assert_true(_live_hand(screen).all(func(v: CardView) -> bool: return v.spent))
