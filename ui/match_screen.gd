class_name MatchScreen
extends Control
## Hotseat match screen (Phase 4). Reads GameState only through get_view_for() for
## whoever is holding the device, and talks to the rules only through intents.
## Bots fill any seat not taken by a human.

signal back_to_setup

## Pause between bot moves so humans can follow along.
const BOT_STEP_SECONDS: float = 0.6
const LOG_LINES: int = 120

var tc: TurnController
## "human" or a bot name, per seat.
var seat_kinds: Array[String] = []
var bots: Dictionary[int, Bot] = {}
## Whose private information is on screen (-1: nobody's, e.g. behind the pass screen).
var viewer_seat: int = -1
var awaiting_pass: bool = false
var time_left: float = Config.TURN_TIMER_SECONDS
var message: String = ""

# The card the human is about to play.
var selected_index: int = -1
var selected_mode: int = -1
var selected_target: int = -1
var selected_element: int = -1

var _bot_wait: float = 0.0
var _seen_turns: int = 0

var _round_label: Label
var _timer_label: Label
var _joker_label: Label
var _seats_box: HBoxContainer
var _pool_label: Label
var _log: RichTextLabel
var _hand_box: HBoxContainer
var _actions_box: HFlowContainer
var _message_label: Label
var _pass_overlay: Control
var _pass_label: Label
var _end_overlay: Control
var _end_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_layout()


## Starts a match. Call after the screen is in the tree.
func start_match(kinds: Array[String], match_seed: int) -> void:
	seat_kinds = kinds
	tc = TurnController.new(match_seed, kinds.size(), Deck.build_card_list(CardCatalog.load_all()))
	bots.clear()
	for seat: int in kinds.size():
		if kinds[seat] != "human":
			bots[seat] = MatchRunner.make_bot(kinds[seat], seat, match_seed)
	viewer_seat = -1
	var humans: Array[int] = _human_seats()
	if humans.size() == 1:
		viewer_seat = humans[0]
	_seen_turns = 0
	_after_change()


func is_human(seat: int) -> bool:
	return seat >= 0 and seat < seat_kinds.size() and seat_kinds[seat] == "human"


## Submits an intent for the current player and refreshes the screen.
func submit(intent: Intent) -> String:
	var error: String = tc.submit(intent)
	message = error
	_after_change()
	return error


## Lets the current bot make one move (the screen calls this on a timer).
func step_bot() -> void:
	var seat: int = tc.state.current_seat
	if bots.has(seat) and not tc.state.is_over():
		submit(bots[seat].choose(tc))


## The next human has the device: show their side of the table.
func confirm_pass() -> void:
	awaiting_pass = false
	viewer_seat = tc.state.current_seat
	time_left = Config.TURN_TIMER_SECONDS
	_refresh()


func _process(delta: float) -> void:
	if tc == null or tc.state.is_over():
		return
	var seat: int = tc.state.current_seat
	if bots.has(seat):
		_bot_wait += delta
		if _bot_wait >= BOT_STEP_SECONDS:
			_bot_wait = 0.0
			step_bot()
	elif not awaiting_pass:
		time_left -= delta
		_timer_label.text = "Time: %d s" % ceili(maxf(time_left, 0.0))
		if time_left <= 0.0:
			submit(Intents.Timeout.new(seat))


# --- State changes ---------------------------------------------------------------

func _after_change() -> void:
	var turns: int = tc.state.events.filter(func(e: GameEvent) -> bool: return e is GameEvents.TurnStarted).size()
	if turns != _seen_turns:
		_seen_turns = turns
		_clear_selection()
		time_left = Config.TURN_TIMER_SECONDS
		_bot_wait = 0.0
		var seat: int = tc.state.current_seat
		# Hand the device over when the next human isn't the one holding it.
		if is_human(seat) and seat != viewer_seat and not tc.state.is_over():
			awaiting_pass = true
			viewer_seat = -1
	_refresh()


func _clear_selection() -> void:
	selected_index = -1
	selected_mode = -1
	selected_target = -1
	selected_element = -1


# --- Layout ------------------------------------------------------------------------

func _build_layout() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	_joker_label = Label.new()
	_joker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_joker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_wrap_panel(_joker_label, Color(0.30, 0.12, 0.30)))
	var clock := VBoxContainer.new()
	clock.custom_minimum_size.x = 130
	_round_label = Label.new()
	_timer_label = Label.new()
	clock.add_child(_round_label)
	clock.add_child(_timer_label)
	top.add_child(clock)

	_seats_box = HBoxContainer.new()
	_seats_box.add_theme_constant_override("separation", 6)
	root.add_child(_seats_box)

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(middle)
	_pool_label = Label.new()
	_pool_label.custom_minimum_size = Vector2(300, 0)
	_pool_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	middle.add_child(_wrap_panel(_pool_label, Color(0.12, 0.25, 0.22)))
	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_panel: PanelContainer = _wrap_panel(_log, UiStyle.PANEL_COLOR)
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(log_panel)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size = Vector2(0, 110)
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hand_box = HBoxContainer.new()
	hand_scroll.add_child(_hand_box)
	root.add_child(hand_scroll)

	_actions_box = HFlowContainer.new()
	root.add_child(_actions_box)
	_message_label = Label.new()
	_message_label.add_theme_color_override("font_color", UiStyle.HIGHLIGHT_COLOR)
	root.add_child(_message_label)

	_pass_overlay = _overlay()
	_pass_label = _pass_overlay.get_node("Box/Text")
	var ready_button := Button.new()
	ready_button.name = "Ready"
	ready_button.text = "I'm ready: show my hand"
	ready_button.pressed.connect(confirm_pass)
	_pass_overlay.get_node("Box").add_child(ready_button)

	_end_overlay = _overlay()
	_end_label = _end_overlay.get_node("Box/Text")
	var again := Button.new()
	again.name = "NewMatch"
	again.text = "New match"
	again.pressed.connect(func() -> void: back_to_setup.emit())
	_end_overlay.get_node("Box").add_child(again)


func _overlay() -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.04, 0.08, 0.97)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(box)
	var text := Label.new()
	text.name = "Text"
	text.add_theme_font_size_override("font_size", 28)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	return overlay


## A coloured panel around `content`, taking over its sizing (a wrapping label sized
## only on the inside would collapse to one character wide).
func _wrap_panel(content: Control, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(color))
	panel.size_flags_horizontal = content.size_flags_horizontal
	panel.size_flags_vertical = content.size_flags_vertical
	panel.custom_minimum_size = content.custom_minimum_size
	panel.add_child(content)
	return panel


# --- Refresh -----------------------------------------------------------------------

func _refresh() -> void:
	if tc == null:
		return
	var view: Dictionary = tc.state.get_view_for(viewer_seat)
	var preview: Array[int] = tc.preview_joker_targets()
	_round_label.text = "Round %d" % view["round_number"]
	_timer_label.text = "Time: %d s" % ceili(maxf(time_left, 0.0)) if is_human(tc.state.current_seat) else "Bot thinking..."
	_refresh_joker(view["joker"], preview)
	_refresh_seats(view, preview)
	_refresh_pool(view)
	_refresh_log()
	_refresh_hand(view)
	_refresh_actions()
	_message_label.text = message

	_pass_overlay.visible = awaiting_pass and not tc.state.is_over()
	_pass_label.text = "Pass the device to %s" % UiStyle.player_name(tc.state.current_seat)
	_end_overlay.visible = tc.state.is_over()
	if tc.state.is_over():
		_end_label.text = ("Draw! Nobody survives." if tc.state.is_draw
				else "%s wins!" % UiStyle.player_name(tc.state.winner_seat)) \
				+ "\n(round %d)" % tc.state.round_number


func _refresh_joker(joker: Dictionary, preview: Array[int]) -> void:
	var effects: Array = joker["effects"]
	var lines: PackedStringArray = []
	lines.append("THE JOKER  ·  %s type  ·  hits for %d this round" % [
		Element.type_name(joker["element"]), joker["damage"]])
	lines.append("Targeting: %s   Pattern: %s   Effects: %s" % [
		_or_default(joker["targeting"], "hottest"), _or_default(joker["pattern"], "single"),
		", ".join(effects.map(func(id: StringName) -> String: return String(id))) if not effects.is_empty() else "none"])
	var who: String = "random player" if joker["targeting"] == JokerModifier.WILD_CARD else "nobody"
	if not preview.is_empty():
		who = ", ".join(preview.map(func(s: int) -> String: return UiStyle.player_name(s)))
	lines.append("If the round ended now it would hit: %s" % who)
	_joker_label.text = "\n".join(lines)


func _refresh_seats(view: Dictionary, preview: Array[int]) -> void:
	for child: Node in _seats_box.get_children():
		child.queue_free()
	var traps_on: Dictionary[int, int] = {}
	for trap: Dictionary in view["traps"]:
		traps_on[trap["host_seat"]] = traps_on.get(trap["host_seat"], 0) + 1
	for p: Dictionary in view["players"]:
		var seat: int = p["seat"]
		var is_current: bool = seat == tc.state.current_seat and not tc.state.is_over()
		var border: Color = UiStyle.HIGHLIGHT_COLOR if is_current else Color(0, 0, 0, 0)
		var color: Color = UiStyle.type_color(p["element"])
		if not p["is_alive"]:
			color = color.darkened(0.7)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", UiStyle.panel_style(color, border, 3))
		var box := VBoxContainer.new()
		panel.add_child(box)
		var kind: String = "" if is_human(seat) else "  (bot)"
		box.add_child(_text("%s%s%s" % ["▶ " if is_current else "", UiStyle.player_name(seat), kind], 18))
		if not p["is_alive"]:
			box.add_child(_text("Eliminated"))
			_seats_box.add_child(panel)
			continue
		box.add_child(_text("%s type" % Element.type_name(p["element"])))
		box.add_child(_bar("HP", p["hp"], Config.MAX_HP, Color(0.3, 0.8, 0.35)))
		var drama_color: Color = UiStyle.DANGER_COLOR if preview.has(seat) else Color(0.95, 0.6, 0.2)
		box.add_child(_bar("Drama", p["heat"], UiStyle.DRAMA_BAR_MAX, drama_color))
		box.add_child(_text("Cards in hand: %d" % p["hand_size"]))
		var statuses: PackedStringArray = _statuses(p)
		if traps_on.has(seat):
			statuses.append("%d face-down trap(s)" % traps_on[seat])
		if preview.has(seat):
			statuses.append("Joker target!")
		if not statuses.is_empty():
			box.add_child(_text(", ".join(statuses)))
		if p.has("hand") and seat != viewer_seat:
			var names: Array = p["hand"].map(func(c: CardData) -> String: return c.display_name)
			box.add_child(_text("Exposed hand: %s" % ", ".join(names)))
		_seats_box.add_child(panel)


func _statuses(p: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var poisons: Array = p["poison_rounds_left"]
	if not poisons.is_empty():
		out.append("Poison x%d" % poisons.size())
	if p["burn_stacks"] > 0:
		out.append("Burn x%d" % p["burn_stacks"])
	var heals: Array = p["heal_rounds_left"]
	if not heals.is_empty():
		out.append("Healing x%d" % heals.size())
	if p["is_rotted"]:
		out.append("Rot")
	if p["rooted_until_round"] >= tc.state.round_number:
		out.append("Rooted")
	if p["exposed_until_round"] >= tc.state.round_number:
		out.append("Exposed")
	for restriction: StringName in p["next_turn_restrictions"]:
		out.append({TurnRestriction.NO_DISCARD: "Dry Well next turn", TurnRestriction.ONE_CARD: "Silenced next turn"}
				.get(restriction, String(restriction)))
	return out


func _refresh_pool(view: Dictionary) -> void:
	var pool_traps: int = 0
	var mine: PackedStringArray = []
	for trap: Dictionary in view["traps"]:
		if trap["host_seat"] == PlacedTrap.POOL:
			pool_traps += 1
		if trap.has("card"):
			var spot: String = "pool" if trap["host_seat"] == PlacedTrap.POOL else UiStyle.player_name(trap["host_seat"])
			mine.append("%s (on %s)" % [(trap["card"] as CardData).display_name, spot])
	var lines: PackedStringArray = ["COLLECTIVE POOL", "Face-down traps: %d" % pool_traps]
	if not mine.is_empty():
		lines.append("")
		lines.append("Your traps:")
		lines.append_array(mine)
	lines.append("")
	lines.append("Deck: %d   Discard: %d" % [view["draw_pile_size"], view["discard_pile"].size()])
	_pool_label.text = "\n".join(lines)


func _refresh_log() -> void:
	var events: Array[GameEvent] = tc.state.get_events_for(viewer_seat)
	var lines: PackedStringArray = []
	for i: int in range(maxi(0, events.size() - LOG_LINES), events.size()):
		var event: GameEvent = events[i]
		if event is GameEvents.HeatChanged:
			continue
		lines.append(UiStyle.humanize(event.describe()))
	_log.text = "\n".join(lines)


func _refresh_hand(view: Dictionary) -> void:
	for child: Node in _hand_box.get_children():
		child.queue_free()
	if viewer_seat < 0:
		return
	var hand: Array = view["players"][viewer_seat]["hand"]
	var my_turn: bool = viewer_seat == tc.state.current_seat and not awaiting_pass
	for i: int in hand.size():
		var card: CardData = hand[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(140, 100)
		button.text = "%s\n%s" % [card.display_name, UiStyle.card_summary(card)]
		button.tooltip_text = card.rules_text
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.toggle_mode = true
		button.button_pressed = i == selected_index
		button.disabled = not my_turn
		var style: StyleBoxFlat = UiStyle.panel_style(UiStyle.type_color(card.element).darkened(0.2),
				UiStyle.HIGHLIGHT_COLOR if i == selected_index else Color(0, 0, 0, 0), 3)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("pressed", style)
		button.pressed.connect(select_card.bind(i))
		_hand_box.add_child(button)


# --- Actions -----------------------------------------------------------------------

func select_card(index: int) -> void:
	selected_index = -1 if selected_index == index else index
	selected_mode = -1
	selected_target = -1
	selected_element = -1
	if selected_index >= 0:
		var card: CardData = _selected_card()
		selected_mode = CardData.Mode.COLLECTIVE if card.mode_lock == CardData.ModeLock.COLLECTIVE_ONLY \
				else CardData.Mode.TARGETED
	message = ""
	_refresh()


func select_mode(mode: CardData.Mode) -> void:
	selected_mode = mode
	_refresh()


func select_target(seat: int) -> void:
	selected_target = seat
	_refresh()


func select_element(element: int) -> void:
	selected_element = element
	_refresh()


## The play the current selection describes (target -1 when collective).
func selected_play() -> Intents.PlayCard:
	if selected_index < 0:
		return null
	var target: int = selected_target if selected_mode == CardData.Mode.TARGETED else -1
	return Intents.PlayCard.new(tc.state.current_seat, selected_index, selected_mode as CardData.Mode,
			target, selected_element)


func play_selected() -> String:
	var play: Intents.PlayCard = selected_play()
	if play == null:
		return "Pick a card first"
	var error: String = submit(play)
	if error.is_empty():
		_clear_selection()
		_refresh()
	return error


func discard_selected() -> String:
	if selected_index < 0:
		return "Pick a card to discard"
	var error: String = submit(Intents.DiscardCard.new(tc.state.current_seat, selected_index))
	if error.is_empty():
		_clear_selection()
		_refresh()
	return error


func _selected_card() -> CardData:
	if selected_index < 0 or viewer_seat < 0:
		return null
	var hand: Array[CardData] = tc.state.player(viewer_seat).hand
	return hand[selected_index] if selected_index < hand.size() else null


func _refresh_actions() -> void:
	for child: Node in _actions_box.get_children():
		child.queue_free()
	var seat: int = tc.state.current_seat
	if tc.state.is_over() or awaiting_pass or not is_human(seat) or viewer_seat != seat:
		return
	var in_draw: bool = tc.state.phase == GameState.Phase.DRAW
	if in_draw:
		_action("Draw a card (%d/%d)" % [tc.state.draws_this_turn, Config.MAX_DRAWS_PER_TURN],
				func() -> void: submit(Intents.DrawCard.new(seat)), tc.can_draw())
		_action("Discard selected", func() -> void: discard_selected(), tc.can_discard() and selected_index >= 0)

	var card: CardData = _selected_card()
	if card != null:
		var card_label: Label = _text("  %s:" % card.display_name)
		card_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_actions_box.add_child(card_label)
		for mode: CardData.Mode in [CardData.Mode.COLLECTIVE, CardData.Mode.TARGETED]:
			if card.allows_mode(mode):
				var label: String = "Collective pool" if mode == CardData.Mode.COLLECTIVE else "Targeted"
				_action(("[%s]" % label) if selected_mode == mode else label, select_mode.bind(mode), true)
		if selected_mode == CardData.Mode.TARGETED:
			for other: int in tc.state.alive_seats():
				if other != seat:
					var name: String = UiStyle.player_name(other)
					_action(("[%s]" % name) if selected_target == other else name, select_target.bind(other), true)
		if EffectRegistry.get_effect(card.effect_id).needs_element_choice():
			for element: Element.Type in Element.Type.values():
				var name: String = Element.type_name(element)
				_action(("[%s]" % name) if selected_element == element else name, select_element.bind(element), true)
		var play: Intents.PlayCard = selected_play()
		var cost: String = "Drama when it fires" if card.family == CardData.Family.TRAP \
				else "+%d Drama" % Heat.for_card(card, selected_mode as CardData.Mode)
		_action("Play (%s)" % cost, func() -> void: play_selected(), tc.validate(play).is_empty())

	var end_label: String = "End turn" if not tc.state.slots_played.is_empty() \
			else "Skip turn (+%d Drama)" % Config.SKIP_HEAT
	_action(end_label, func() -> void: submit(Intents.EndTurn.new(seat)), true)


func _action(label: String, callback: Callable, enabled: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.disabled = not enabled
	button.pressed.connect(callback)
	_actions_box.add_child(button)
	return button


# --- Small helpers -----------------------------------------------------------------

func _human_seats() -> Array[int]:
	var seats: Array[int] = []
	for seat: int in seat_kinds.size():
		if is_human(seat):
			seats.append(seat)
	return seats


func _text(text: String, size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _bar(title: String, value: int, max_value: int, color: Color) -> Control:
	var row := HBoxContainer.new()
	var label := _text("%s %d" % [title, value])
	label.custom_minimum_size.x = 80
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.value = mini(value, max_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(90, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return row


func _or_default(id: StringName, fallback: String) -> String:
	return fallback if id == &"" else String(id)
