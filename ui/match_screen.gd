class_name MatchScreen
extends Control
## Hotseat match screen, laid out like a table (Uday's sketch): the Joker at the top,
## the collective pool in the middle with the draw and discard piles below it, each
## player around the table with their own player pool, and the hand fanned at the
## bottom. Hover a card for details; drag it onto a pool to play it (onto a player's
## pool = targeted at them, onto the collective pool = everyone), click the draw pile
## to draw, drag onto the discard pile to discard. Clicking a card and then a pool
## works too.
##
## Reads GameState only through get_view_for() for whoever holds the device, and talks
## to the rules only through intents. Bots fill any seat not taken by a human.

signal back_to_setup

## Pause between bot moves so humans can follow along.
const BOT_STEP_SECONDS: float = 0.6
const LOG_LINES: int = 200
const TICKER_LINES: int = 7
## Most recent cards shown in a pool this round.
const POOL_RECENT: int = 4

## Top-left corner of each seat block, by player count. Seats go clockwise around the
## table (bottom-left, top-left, top-right, bottom-right), matching turn order.
const SEAT_SLOTS: Dictionary[int, Array] = {
	2: [Vector2(40, 20), Vector2(1000, 20)],
	3: [Vector2(70, 290), Vector2(40, 20), Vector2(1000, 20)],
	4: [Vector2(70, 290), Vector2(40, 20), Vector2(1000, 20), Vector2(970, 290)],
}
const SEAT_SIZE: Vector2 = Vector2(240, 250)
const HAND_RECT: Rect2 = Rect2(300, 540, 680, 180)
const DETAIL_SIZE: Vector2 = Vector2(260, 250)

var tc: TurnController
## "human" or a bot name, per seat.
var seat_kinds: Array[String] = []
var bots: Dictionary[int, Bot] = {}
## Whose private information is on screen (-1: nobody's, e.g. behind the pass screen).
var viewer_seat: int = -1
var awaiting_pass: bool = false
var time_left: float = Config.TURN_TIMER_SECONDS
var message: String = ""
## Hand card picked by clicking (-1 = none).
var selected_index: int = -1
## A play waiting for its type choice (Convert, Shed Skin): {hand_index, kind, seat}.
var pending_play: Dictionary = {}

var _bot_wait: float = 0.0
var _seen_turns: int = 0

var _joker_figure: Figures.JokerFigure
var _joker_label: Label
var _seat_layer: Control
var _pool_zone: DropZone
var _pool_box: HFlowContainer
var _draw_zone: DropZone
var _draw_label: Label
var _discard_zone: DropZone
var _discard_label: Label
var _hand_layer: Control
var _ticker: Label
var _round_label: Label
var _timer_label: Label
var _hint_label: Label
var _end_button: Button
var _message_label: Label
var _detail: PanelContainer
var _detail_label: RichTextLabel
var _player_zones: Dictionary[int, DropZone] = {}
var _log_overlay: Control
var _log_text: RichTextLabel
var _element_overlay: Control
var _element_box: HBoxContainer
var _pass_overlay: Control
var _pass_label: Label
var _end_overlay: Control
var _end_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_table()


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


## True while the human holding the device may act.
func is_my_turn() -> bool:
	return tc != null and not tc.state.is_over() and not awaiting_pass \
			and is_human(tc.state.current_seat) and viewer_seat == tc.state.current_seat


## Submits an intent for the current player and refreshes the table.
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
		_timer_label.text = "Time left: %s" % _clock(time_left)
		if time_left <= 0.0:
			pending_play.clear()
			submit(Intents.Timeout.new(seat))


# --- Playing cards: drops and clicks ---------------------------------------------------

## Whether hand card `hand_index` may be dropped on this zone right now.
func can_drop(hand_index: int, kind: DropZone.Kind, seat: int) -> bool:
	if not is_my_turn():
		return false
	if kind == DropZone.Kind.DISCARD:
		return tc.validate(Intents.DiscardCard.new(tc.state.current_seat, hand_index)).is_empty()
	if kind == DropZone.Kind.DRAW:
		return false
	var card: CardData = _hand_card(hand_index)
	if card == null:
		return false
	for element: int in _element_choices(card):
		if tc.validate(_play_intent(hand_index, kind, seat, element)).is_empty():
			return true
	return false


## Drops hand card `hand_index` on a zone: discard it, or play it collectively (the
## collective pool) or at a player (their player pool). Cards that ask for a type open
## the type picker first. Returns "" or why it didn't work.
func drop_card(hand_index: int, kind: DropZone.Kind, seat: int) -> String:
	if not is_my_turn():
		return "Not your turn"
	var current: int = tc.state.current_seat
	_clear_selection()
	if kind == DropZone.Kind.DISCARD:
		return submit(Intents.DiscardCard.new(current, hand_index))
	if kind == DropZone.Kind.DRAW:
		return ""
	var card: CardData = _hand_card(hand_index)
	if card != null and EffectRegistry.get_effect(card.effect_id).needs_element_choice():
		pending_play = {"hand_index": hand_index, "kind": kind, "seat": seat}
		_refresh()
		return ""
	return submit(_play_intent(hand_index, kind, seat, -1))


## Finishes a pending Convert / Shed Skin with the chosen type.
func choose_element(element: int) -> String:
	if pending_play.is_empty():
		return "Nothing to choose a type for"
	var play: Dictionary = pending_play
	pending_play = {}
	return submit(_play_intent(play["hand_index"], play["kind"], play["seat"], element))


func cancel_pending() -> void:
	pending_play = {}
	_refresh()


## Click a card in the hand: select it (click again to put it back).
func select_card(index: int) -> void:
	selected_index = -1 if selected_index == index else index
	message = ""
	_refresh()


## Click a zone: the draw pile draws; any other zone plays or discards the selected card.
func click_zone(kind: DropZone.Kind, seat: int) -> String:
	if not is_my_turn():
		return ""
	if kind == DropZone.Kind.DRAW:
		return submit(Intents.DrawCard.new(tc.state.current_seat))
	if selected_index < 0:
		message = "Pick a card first (or drag one here)"
		_refresh()
		return message
	return drop_card(selected_index, kind, seat)


func end_turn() -> String:
	pending_play = {}
	return submit(Intents.EndTurn.new(tc.state.current_seat))


func _play_intent(hand_index: int, kind: DropZone.Kind, seat: int, element: int) -> Intents.PlayCard:
	var current: int = tc.state.current_seat
	if kind == DropZone.Kind.PLAYER:
		return Intents.PlayCard.new(current, hand_index, CardData.Mode.TARGETED, seat, element)
	return Intents.PlayCard.new(current, hand_index, CardData.Mode.COLLECTIVE, -1, element)


func _element_choices(card: CardData) -> Array:
	if EffectRegistry.get_effect(card.effect_id).needs_element_choice():
		return Element.Type.values()
	return [-1]


func _hand_card(hand_index: int) -> CardData:
	if viewer_seat < 0:
		return null
	var hand: Array[CardData] = tc.state.player(viewer_seat).hand
	return hand[hand_index] if hand_index >= 0 and hand_index < hand.size() else null


func _clear_selection() -> void:
	selected_index = -1


# --- State changes ---------------------------------------------------------------------

func _after_change() -> void:
	var turns: int = tc.state.events.filter(func(e: GameEvent) -> bool: return e is GameEvents.TurnStarted).size()
	if turns != _seen_turns:
		_seen_turns = turns
		_clear_selection()
		pending_play = {}
		time_left = Config.TURN_TIMER_SECONDS
		_bot_wait = 0.0
		var seat: int = tc.state.current_seat
		# Hand the device over when the next human isn't the one holding it.
		if is_human(seat) and seat != viewer_seat and not tc.state.is_over():
			awaiting_pass = true
			viewer_seat = -1
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if data is Dictionary and (data as Dictionary).has("hand_index"):
			_highlight_zones(int(data["hand_index"]))
	elif what == NOTIFICATION_DRAG_END:
		_highlight_zones(selected_index)


## Lights up every zone the card could go to (or none for -1).
func _highlight_zones(hand_index: int) -> void:
	for zone: DropZone in _all_zones():
		zone.set_highlight(hand_index >= 0 and can_drop(hand_index, zone.kind, zone.seat))


func _all_zones() -> Array[DropZone]:
	var zones: Array[DropZone] = [_pool_zone, _discard_zone]
	zones.append_array(_player_zones.values())
	return zones


# --- Building the table ------------------------------------------------------------------

func _build_table() -> void:
	var felt := ColorRect.new()
	felt.color = UiStyle.TABLE_COLOR
	felt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(felt)

	_joker_figure = Figures.JokerFigure.new()
	_joker_figure.position = Vector2(600, 4)
	_joker_figure.size = Vector2(80, 96)
	add_child(_joker_figure)
	_joker_label = _label("", 13)
	_joker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_joker_label, Rect2(400, 100, 480, 66))

	_seat_layer = Control.new()
	_seat_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_seat_layer, Rect2(Vector2.ZERO, Vector2(1280, 720)))

	_pool_zone = _zone(DropZone.Kind.POOL, -1, UiStyle.POOL_COLOR, Rect2(430, 170, 420, 160))
	var pool_box := VBoxContainer.new()
	pool_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pool_zone.add_child(pool_box)
	var pool_title := _label("COLLECTIVE POOL  ·  drop a card here to hit everyone", 13)
	pool_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pool_box.add_child(pool_title)
	_pool_box = HFlowContainer.new()
	_pool_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pool_box.alignment = FlowContainer.ALIGNMENT_CENTER
	pool_box.add_child(_pool_box)

	_draw_zone = _zone(DropZone.Kind.DRAW, -1, UiStyle.PILE_COLOR, Rect2(525, 342, 110, 150))
	_draw_label = _label("", 13)
	_draw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_draw_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_draw_zone.add_child(_draw_label)
	_discard_zone = _zone(DropZone.Kind.DISCARD, -1, UiStyle.PILE_COLOR, Rect2(645, 342, 110, 150))
	_discard_label = _label("", 13)
	_discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discard_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_discard_zone.add_child(_discard_label)

	_hand_layer = Control.new()
	_hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_hand_layer, HAND_RECT)

	var ticker_panel := _panel(Rect2(8, 548, 286, 164), UiStyle.PANEL_COLOR)
	var ticker_box := VBoxContainer.new()
	ticker_panel.add_child(ticker_box)
	_ticker = _label("", 11)
	_ticker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ticker.clip_text = true
	ticker_box.add_child(_ticker)
	var log_button := Button.new()
	log_button.text = "Full log"
	log_button.pressed.connect(func() -> void: _log_overlay.visible = true)
	ticker_box.add_child(log_button)

	var info := _panel(Rect2(986, 548, 286, 164), UiStyle.PANEL_COLOR)
	var info_box := VBoxContainer.new()
	info.add_child(info_box)
	_round_label = _label("", 14)
	_timer_label = _label("", 14)
	_hint_label = _label("", 11)
	_hint_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_box.add_child(_round_label)
	info_box.add_child(_timer_label)
	info_box.add_child(_hint_label)
	_end_button = Button.new()
	_end_button.pressed.connect(func() -> void: end_turn())
	info_box.add_child(_end_button)
	_message_label = _label("", 13)
	_message_label.add_theme_color_override("font_color", UiStyle.HIGHLIGHT_COLOR)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_message_label, Rect2(300, 502, 680, 40))

	_detail = PanelContainer.new()
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.size = DETAIL_SIZE
	_detail.z_index = 50
	_detail.visible = false
	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.fit_content = true
	_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_label.custom_minimum_size = DETAIL_SIZE - Vector2(16, 16)
	_detail.add_child(_detail_label)
	add_child(_detail)

	_build_overlays()


func _build_overlays() -> void:
	_element_overlay = _overlay("Choose a type")
	_element_box = HBoxContainer.new()
	_element_overlay.get_node("Box").add_child(_element_box)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(cancel_pending)
	_element_overlay.get_node("Box").add_child(cancel)

	_log_overlay = _overlay("Event log")
	_log_text = RichTextLabel.new()
	_log_text.custom_minimum_size = Vector2(760, 480)
	_log_text.scroll_following = true
	_log_overlay.get_node("Box").add_child(_log_text)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func() -> void: _log_overlay.visible = false)
	_log_overlay.get_node("Box").add_child(close)

	_pass_overlay = _overlay("")
	_pass_label = _pass_overlay.get_node("Box/Text")
	var ready_button := Button.new()
	ready_button.name = "Ready"
	ready_button.text = "I'm ready: show my hand"
	ready_button.pressed.connect(confirm_pass)
	_pass_overlay.get_node("Box").add_child(ready_button)

	_end_overlay = _overlay("")
	_end_label = _end_overlay.get_node("Box/Text")
	var again := Button.new()
	again.name = "NewMatch"
	again.text = "New match"
	again.pressed.connect(func() -> void: back_to_setup.emit())
	_end_overlay.get_node("Box").add_child(again)


func _overlay(title: String) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.04, 0.08, 0.95)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.z_index = 100
	add_child(overlay)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(box)
	var text := Label.new()
	text.name = "Text"
	text.text = title
	text.add_theme_font_size_override("font_size", 28)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	return overlay


func _zone(kind: DropZone.Kind, seat: int, color: Color, rect: Rect2, parent: Control = self) -> DropZone:
	var zone := DropZone.new(kind, seat, color)
	zone.can_drop = can_drop
	zone.on_drop = func(hand_index: int, k: DropZone.Kind, s: int) -> void: drop_card(hand_index, k, s)
	zone.on_click = func(k: DropZone.Kind, s: int) -> void: click_zone(k, s)
	_place(zone, rect, parent)
	return zone


func _panel(rect: Rect2, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(color))
	_place(panel, rect)
	return panel


func _place(control: Control, rect: Rect2, parent: Control = self) -> void:
	parent.add_child(control)
	control.position = rect.position
	control.size = rect.size
	control.custom_minimum_size = rect.size


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


# --- Refresh -----------------------------------------------------------------------------

func _refresh() -> void:
	if tc == null:
		return
	_detail.visible = false
	var view: Dictionary = tc.state.get_view_for(viewer_seat)
	var preview: Array[int] = tc.preview_joker_targets()
	var recent: Dictionary = _recent_plays()
	_refresh_joker(view["joker"], preview)
	_refresh_seats(view, preview, recent)
	_refresh_pool(view, recent)
	_refresh_piles(view)
	_refresh_hand(view)
	_refresh_info()
	_refresh_logs()
	_highlight_zones(selected_index)

	_element_overlay.visible = not pending_play.is_empty()
	if not pending_play.is_empty():
		_refresh_element_picker()
	_pass_overlay.visible = awaiting_pass and not tc.state.is_over()
	_pass_label.text = "Pass the device to %s" % UiStyle.player_name(tc.state.current_seat)
	_end_overlay.visible = tc.state.is_over()
	if tc.state.is_over():
		_end_label.text = ("Draw! Nobody survives." if tc.state.is_draw
				else "%s wins!" % UiStyle.player_name(tc.state.winner_seat)) \
				+ "\n(round %d)" % tc.state.round_number


func _refresh_joker(joker: Dictionary, preview: Array[int]) -> void:
	_joker_figure.element = joker["element"]
	_joker_figure.queue_redraw()
	var effects: Array = joker["effects"]
	var mods: PackedStringArray = []
	if joker["targeting"] != &"":
		mods.append(UiStyle.modifier_name(joker["targeting"]))
	if joker["pattern"] != &"":
		mods.append(UiStyle.modifier_name(joker["pattern"]))
	for id: StringName in effects:
		mods.append(UiStyle.modifier_name(id))
	var eyeing: String = "a random player" if joker["targeting"] == JokerModifier.WILD_CARD else "nobody"
	if not preview.is_empty():
		eyeing = ", ".join(preview.map(func(s: int) -> String: return UiStyle.player_name(s)))
	_joker_label.text = "THE JOKER · %s · hits for %d at round end\n%s\nEyeing: %s" % [
		Element.type_name(joker["element"]), joker["damage"],
		"Modifiers: " + ", ".join(mods) if not mods.is_empty() else "No modifiers", eyeing]


func _refresh_seats(view: Dictionary, preview: Array[int], recent: Dictionary) -> void:
	for child: Node in _seat_layer.get_children():
		child.queue_free()
	_player_zones.clear()
	var traps_on: Dictionary = _traps_by_host(view)
	var slots: Array = SEAT_SLOTS[tc.state.players.size()]
	for p: Dictionary in view["players"]:
		var seat: int = p["seat"]
		var origin: Vector2 = slots[seat]
		var is_current: bool = seat == tc.state.current_seat and not tc.state.is_over()

		var figure := Figures.PlayerFigure.new()
		figure.element = p["element"]
		figure.alive = p["is_alive"]
		figure.active = is_current
		figure.eyed = preview.has(seat)
		_place(figure, Rect2(origin, Vector2(76, 92)), _seat_layer)

		var info := VBoxContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_theme_constant_override("separation", 0)
		_place(info, Rect2(origin + Vector2(82, 0), Vector2(158, 118)), _seat_layer)
		var name: String = UiStyle.player_name(seat)
		if seat == viewer_seat:
			name += " (you)"
		elif not is_human(seat):
			name += " (bot)"
		var name_label := _label(("▶ " if is_current else "") + name, 15)
		if is_current:
			name_label.add_theme_color_override("font_color", UiStyle.HIGHLIGHT_COLOR)
		info.add_child(name_label)
		if not p["is_alive"]:
			info.add_child(_label("Eliminated", 13))
		else:
			info.add_child(_label("♥ %d   ·   %s" % [p["hp"], Element.type_name(p["element"])], 14))
			info.add_child(_drama_meter(p["heat"], preview.has(seat)))
			var statuses: PackedStringArray = _statuses(p)
			statuses.append("%d cards" % p["hand_size"])
			info.add_child(_label(", ".join(statuses), 11))

		var zone := _zone(DropZone.Kind.PLAYER, seat, UiStyle.PLAYER_POOL_COLOR,
				Rect2(origin + Vector2(0, 122), Vector2(SEAT_SIZE.x, 104)), _seat_layer)
		_player_zones[seat] = zone
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(box)
		box.add_child(_label("%s's pool" % UiStyle.player_name(seat), 11))
		var cards := HBoxContainer.new()
		cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(cards)
		_fill_pool(cards, recent.get(seat, []), traps_on.get(seat, []))
		if p.has("hand") and seat != viewer_seat:
			box.add_child(_label("Exposed hand: %s" % ", ".join(
					p["hand"].map(func(c: CardData) -> String: return c.display_name)), 10))


func _drama_meter(heat: int, eyed: bool) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _label("Drama %d" % heat, 13)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.max_value = UiStyle.DRAMA_BAR_MAX
	bar.value = mini(heat, UiStyle.DRAMA_BAR_MAX)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(70, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiStyle.DANGER_COLOR if eyed else Color(0.95, 0.6, 0.2)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return row


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
		out.append({TurnRestriction.NO_DISCARD: "Dry Well", TurnRestriction.ONE_CARD: "Silenced"}
				.get(restriction, String(restriction)))
	return out


func _refresh_pool(view: Dictionary, recent: Dictionary) -> void:
	for child: Node in _pool_box.get_children():
		child.queue_free()
	_fill_pool(_pool_box, recent.get(PlacedTrap.POOL, []), _traps_by_host(view).get(PlacedTrap.POOL, []))


## Recent cards and trap markers in one pool. The viewer's own traps show face up.
func _fill_pool(container: Container, cards: Array, traps: Array) -> void:
	for card: CardData in cards:
		container.add_child(_mini_card(card, false))
	for trap: Dictionary in traps:
		container.add_child(_mini_card(trap.get("card"), not trap.has("card")))


func _mini_card(card: CardData, face_down: bool) -> CardView:
	var view := CardView.make(card, true, face_down)
	view.hovered.connect(_show_detail)
	view.unhovered.connect(func(_v: CardView) -> void: _detail.visible = false)
	return view


func _refresh_piles(view: Dictionary) -> void:
	var drawing: bool = is_my_turn() and tc.state.phase == GameState.Phase.DRAW
	_draw_label.text = "DRAW PILE\n%d cards\n\n%s" % [view["draw_pile_size"],
			"Click to draw\n(%d/%d)" % [tc.state.draws_this_turn, Config.MAX_DRAWS_PER_TURN] if drawing else ""]
	var discards: Array = view["discard_pile"]
	var top: String = (discards.back() as CardData).display_name if not discards.is_empty() else "empty"
	_discard_label.text = "DISCARD\n%d cards\ntop: %s\n\n%s" % [discards.size(), top,
			"Drop a card here\nto discard" if drawing else ""]


func _refresh_hand(view: Dictionary) -> void:
	for child: Node in _hand_layer.get_children():
		child.queue_free()
	if viewer_seat < 0:
		return
	var hand: Array = view["players"][viewer_seat]["hand"]
	var count: int = hand.size()
	if count == 0:
		return
	var card_w: float = CardView.FULL_SIZE.x
	var spacing: float = minf(card_w + 6.0, (HAND_RECT.size.x - card_w) / maxf(1.0, count - 1.0))
	var total: float = spacing * (count - 1) + card_w
	var start_x: float = (HAND_RECT.size.x - total) / 2.0
	var mid: float = (count - 1) / 2.0
	for i: int in count:
		var view_card := CardView.make(hand[i])
		view_card.hand_index = i
		view_card.draggable = is_my_turn()
		view_card.selected = i == selected_index
		view_card.hovered.connect(_show_detail)
		view_card.unhovered.connect(func(_v: CardView) -> void: _detail.visible = false)
		view_card.clicked.connect(func(v: CardView) -> void:
			if is_my_turn():
				select_card(v.hand_index))
		_hand_layer.add_child(view_card)
		var offset: float = i - mid
		view_card.set_rest(Vector2(start_x + spacing * i, 4.0 + offset * offset * 1.2), offset * 3.0)


func _refresh_info() -> void:
	var seat: int = tc.state.current_seat
	_round_label.text = "Round %d  ·  %s's turn" % [tc.state.round_number, UiStyle.player_name(seat)]
	_end_button.visible = is_my_turn()
	_end_button.text = "End turn" if not tc.state.slots_played.is_empty() else "Skip turn (+%d Drama)" % Config.SKIP_HEAT
	if tc.state.is_over():
		_timer_label.text = ""
		_hint_label.text = ""
	elif not is_human(seat):
		_timer_label.text = "%s is thinking…" % UiStyle.player_name(seat)
		_hint_label.text = ""
	else:
		_timer_label.text = "Time left: %s" % _clock(time_left)
		var slots: String = "Played: %s / %s" % [
			"trap or Joker card" if state_has_slot(CardData.Slot.ONE) else "-",
			"attack or effect" if state_has_slot(CardData.Slot.TWO) else "-"]
		if tc.state.phase == GameState.Phase.DRAW:
			_hint_label.text = "Draw up to 3 from the draw pile, discard 1 if you like, then drag cards onto a pool to play (1 trap/Joker card + 1 attack/effect).\n" + slots
		else:
			_hint_label.text = "Drag a card onto a player's pool to target them, or onto the collective pool to hit everyone.\n" + slots
	_message_label.text = message


## Seconds as m:ss for the turn timer.
static func _clock(seconds: float) -> String:
	var total: int = ceili(maxf(seconds, 0.0))
	return "%d:%02d" % [total / 60, total % 60]


func state_has_slot(slot: CardData.Slot) -> bool:
	return tc.state.slots_played.has(slot)


func _refresh_logs() -> void:
	var events: Array[GameEvent] = tc.state.get_events_for(viewer_seat)
	var lines: PackedStringArray = []
	for i: int in range(maxi(0, events.size() - LOG_LINES), events.size()):
		var event: GameEvent = events[i]
		if event is GameEvents.HeatChanged:
			continue
		lines.append(UiStyle.humanize(event.describe()))
	_log_text.text = "\n".join(lines)
	_ticker.text = "\n".join(lines.slice(maxi(0, lines.size() - TICKER_LINES)))


func _refresh_element_picker() -> void:
	for child: Node in _element_box.get_children():
		child.queue_free()
	for element: Element.Type in Element.Type.values():
		var button := Button.new()
		button.text = Element.type_name(element)
		button.custom_minimum_size = Vector2(110, 44)
		button.add_theme_stylebox_override("normal", UiStyle.panel_style(UiStyle.type_color(element)))
		var intent: Intents.PlayCard = _play_intent(pending_play["hand_index"], pending_play["kind"],
				pending_play["seat"], element)
		button.disabled = not tc.validate(intent).is_empty()
		button.pressed.connect(choose_element.bind(element))
		_element_box.add_child(button)


# --- Card details on hover -----------------------------------------------------------------

func _show_detail(view: CardView) -> void:
	if view.face_down or view.card == null:
		_detail_label.text = "[b]Face-down trap[/b]\n\nSomeone placed a trap here. What it does, and whose it is, are revealed when it fires."
	else:
		_detail_label.text = _detail_text(view.card)
	var card_rect: Rect2 = view.get_global_rect()
	var pos := Vector2(card_rect.get_center().x - DETAIL_SIZE.x / 2.0, card_rect.position.y - DETAIL_SIZE.y - 8.0)
	if pos.y < 0.0:
		pos.y = card_rect.end.y + 8.0
	pos.x = clampf(pos.x, 8.0, size.x - DETAIL_SIZE.x - 8.0)
	pos.y = clampf(pos.y, 8.0, size.y - DETAIL_SIZE.y - 8.0)
	_detail.position = pos
	_detail.add_theme_stylebox_override("panel",
			UiStyle.panel_style(UiStyle.card_color(view.card).darkened(0.55), Color(0.95, 0.93, 0.85), 2) \
			if view.card != null and not view.face_down else UiStyle.panel_style(UiStyle.PANEL_COLOR))
	_detail.visible = true


func _detail_text(card: CardData) -> String:
	var lines: PackedStringArray = []
	lines.append("[font_size=20][b]%s[/b][/font_size]" % card.display_name)
	lines.append("%s · %s" % [UiStyle.family_name(card.family),
			"slot 1 (trap / Joker)" if card.slot() == CardData.Slot.ONE else "slot 2 (attack / effect)"])
	if card.element != Element.Type.NORMAL or card.family == CardData.Family.ATTACK:
		lines.append("Type: %s" % Element.type_name(card.element))
	lines.append("")
	lines.append(card.rules_text)
	lines.append("")
	var costs: PackedStringArray = []
	if card.allows_mode(CardData.Mode.COLLECTIVE):
		costs.append("collective pool +%d" % Heat.for_card(card, CardData.Mode.COLLECTIVE))
	if card.allows_mode(CardData.Mode.TARGETED):
		costs.append("at a player +%d" % Heat.for_card(card, CardData.Mode.TARGETED))
	var when: String = " (when it fires)" if card.family == CardData.Family.TRAP else ""
	lines.append("Drama: %s%s" % [", ".join(costs), when])
	return "\n".join(lines)


# --- Helpers -------------------------------------------------------------------------------

## Cards played into each pool this round: {seat or PlacedTrap.POOL: [CardData]}.
func _recent_plays() -> Dictionary:
	var recent: Dictionary = {}
	var events: Array[GameEvent] = tc.state.events
	var start: int = 0
	for i: int in range(events.size() - 1, -1, -1):
		if events[i] is GameEvents.RoundStarted:
			start = i
			break
	for i: int in range(start, events.size()):
		var played := events[i] as GameEvents.CardPlayed
		if played == null:
			continue
		var key: int = played.target_seat if played.mode == CardData.Mode.TARGETED else PlacedTrap.POOL
		if not recent.has(key):
			recent[key] = []
		recent[key].append(played.card)
	for key: int in recent:
		var cards: Array = recent[key]
		recent[key] = cards.slice(maxi(0, cards.size() - POOL_RECENT))
	return recent


func _traps_by_host(view: Dictionary) -> Dictionary:
	var by_host: Dictionary = {}
	for trap: Dictionary in view["traps"]:
		var host: int = trap["host_seat"]
		if not by_host.has(host):
			by_host[host] = []
		by_host[host].append(trap)
	return by_host


func _human_seats() -> Array[int]:
	var seats: Array[int] = []
	for seat: int in seat_kinds.size():
		if is_human(seat):
			seats.append(seat)
	return seats
