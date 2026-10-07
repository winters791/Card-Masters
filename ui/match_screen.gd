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
##
## Bots wait for "Play bot turn" (or the "Auto-play bots" toggle) so playtesters can
## follow every bot turn. Every event is animated by the FxLayer (cards flying,
## damage numbers, the 3D Joker's attack); the animations never touch the rules.

signal back_to_setup

## Pause between bot moves so humans can follow along.
const BOT_STEP_SECONDS: float = 0.7
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
const POOL_RECT: Rect2 = Rect2(430, 170, 420, 160)
const DRAW_RECT: Rect2 = Rect2(525, 342, 110, 150)
const DISCARD_RECT: Rect2 = Rect2(645, 342, 110, 150)
const JOKER_RECT: Rect2 = Rect2(520, -16, 240, 230)
## Where the viewer's hand sits, for cards flying in and out of it.
const HAND_POINT: Vector2 = Vector2(640, 630)
## Seat block pieces, relative to the seat's corner.
const AVATAR_RECT: Rect2 = Rect2(6, 10, 76, 76)
const PLATE_SIZE: Vector2 = Vector2(240, 116)

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

## Playtest switch: bots play their turns on their own instead of waiting for the
## "Play bot turn" button.
var auto_play_bots: bool = false

var _bot_wait: float = 0.0
## The current bot was told to play its turn.
var _bot_running: bool = false
var _seen_turns: int = 0
## How many events have been animated.
var _seen_events: int = 0
## HP and eliminations as the animations have shown them so far (they trail the rules
## by a moment so the numbers change when the hit lands on screen).
var _shown_hp: Dictionary[int, int] = {}
var _shown_dead: Array[int] = []

var _fx: FxLayer
var _joker: Joker3D
var _joker_damage: Label
var _joker_type: HBoxContainer
var _joker_mods: Label
var _joker_eye: Label
var _seat_layer: Control
var _figures: Dictionary[int, Figures.PlayerFigure] = {}
var _hp_bars: Dictionary[int, ProgressBar] = {}
var _hp_labels: Dictionary[int, Label] = {}
var _pool_zone: DropZone
var _pool_box: HFlowContainer
var _draw_zone: DropZone
var _draw_label: Label
var _draw_stack: Figures.PileStack
var _discard_zone: DropZone
var _discard_label: Label
var _discard_top: CenterContainer
var _hand_layer: Control
var _ticker: Label
var _round_label: Label
var _timer_label: Label
var _hint_label: Label
var _end_button: Button
var _bot_button: Button
var _auto_toggle: CheckButton
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
	theme = UiStyle.make_theme()
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
	_seen_events = 0
	_bot_running = false
	_shown_hp.clear()
	_shown_dead.clear()
	for p: PlayerState in tc.state.players:
		_shown_hp[p.seat] = p.hp
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


## True while a bot holds the turn.
func is_bot_turn() -> bool:
	return tc != null and not tc.state.is_over() and bots.has(tc.state.current_seat)


## The "Play bot turn" button: the current bot plays its whole turn, one move at a
## time so the table can show each one.
func play_bot_turn() -> void:
	if is_bot_turn():
		_bot_running = true
		_bot_wait = BOT_STEP_SECONDS
		_refresh_info()


func set_auto_play_bots(on: bool) -> void:
	auto_play_bots = on
	if _auto_toggle != null and _auto_toggle.button_pressed != on:
		_auto_toggle.set_pressed_no_signal(on)
	if tc != null:
		_refresh_info()


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
		# Bots wait for the button (or auto-play), then for the table to catch up.
		if (auto_play_bots or _bot_running) and not _fx.busy():
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
		_bot_running = false
		var seat: int = tc.state.current_seat
		# Hand the device over when the next human isn't the one holding it.
		if is_human(seat) and seat != viewer_seat and not tc.state.is_over():
			awaiting_pass = true
			viewer_seat = -1
	_animate_new_events()
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
	var backdrop := Figures.TableBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# The Joker sits behind the collective pool, with a plaque either side.
	_joker = Joker3D.new()
	_place(_joker, JOKER_RECT)
	var stats := _plaque(Rect2(318, 22, 196, 136))
	stats.add_child(_caption("THE JOKER"))
	_joker_damage = _label("", 30)
	_joker_damage.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	stats.add_child(_joker_damage)
	stats.add_child(_caption("damage at the end of the round"))
	_joker_type = HBoxContainer.new()
	_joker_type.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_child(_joker_type)
	var eye := _plaque(Rect2(766, 22, 196, 136))
	eye.add_child(_caption("EYEING"))
	_joker_eye = _label("", 14)
	_joker_eye.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	eye.add_child(_joker_eye)
	eye.add_child(_caption("MODIFIERS"))
	_joker_mods = _label("", 12)
	eye.add_child(_joker_mods)

	_seat_layer = Control.new()
	_seat_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_seat_layer, Rect2(Vector2.ZERO, Vector2(1280, 720)))

	_pool_zone = _zone(DropZone.Kind.POOL, -1, UiStyle.POOL_COLOR, POOL_RECT)
	var pool_box := VBoxContainer.new()
	pool_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pool_zone.add_child(pool_box)
	var pool_title := _caption("COLLECTIVE POOL  ·  drop a card here to hit everyone")
	pool_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pool_box.add_child(pool_title)
	_pool_box = HFlowContainer.new()
	_pool_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pool_box.alignment = FlowContainer.ALIGNMENT_CENTER
	pool_box.add_child(_pool_box)

	_draw_zone = _zone(DropZone.Kind.DRAW, -1, UiStyle.PILE_COLOR, DRAW_RECT)
	var draw_box := _pile_box(_draw_zone, "DRAW")
	_draw_stack = Figures.PileStack.new()
	_draw_stack.custom_minimum_size = Vector2(80, 76)
	draw_box.add_child(_draw_stack)
	_draw_label = _label("", 11)
	_draw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draw_box.add_child(_draw_label)
	_discard_zone = _zone(DropZone.Kind.DISCARD, -1, UiStyle.PILE_COLOR, DISCARD_RECT)
	var discard_box := _pile_box(_discard_zone, "DISCARD")
	_discard_top = CenterContainer.new()
	_discard_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_discard_top.custom_minimum_size = Vector2(80, 80)
	discard_box.add_child(_discard_top)
	_discard_label = _label("", 11)
	_discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discard_box.add_child(_discard_label)

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
	var ticker_row := HBoxContainer.new()
	ticker_box.add_child(ticker_row)
	var log_button := Button.new()
	log_button.text = "Full log"
	log_button.pressed.connect(func() -> void: _log_overlay.visible = true)
	ticker_row.add_child(log_button)
	_auto_toggle = CheckButton.new()
	_auto_toggle.text = "Auto-play bots"
	_auto_toggle.tooltip_text = "Playtesting: bots take their turns without waiting for the button"
	_auto_toggle.add_theme_font_size_override("font_size", 12)
	_auto_toggle.toggled.connect(set_auto_play_bots)
	ticker_row.add_child(_auto_toggle)

	var info := _panel(Rect2(986, 548, 286, 164), UiStyle.PANEL_COLOR)
	var info_box := VBoxContainer.new()
	info.add_child(info_box)
	_round_label = _label("", 14)
	_timer_label = _label("", 14)
	_hint_label = _label("", 11)
	_hint_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hint_label.add_theme_color_override("font_color", UiStyle.MUTED_INK)
	info_box.add_child(_round_label)
	info_box.add_child(_timer_label)
	info_box.add_child(_hint_label)
	_end_button = Button.new()
	_end_button.pressed.connect(func() -> void: end_turn())
	info_box.add_child(_end_button)
	_bot_button = Button.new()
	_bot_button.pressed.connect(play_bot_turn)
	info_box.add_child(_bot_button)
	_message_label = _label("", 14)
	_message_label.add_theme_color_override("font_color", UiStyle.HIGHLIGHT_COLOR)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(_message_label, Rect2(300, 502, 680, 40))

	_fx = FxLayer.new()
	_place(_fx, Rect2(Vector2.ZERO, Vector2(1280, 720)))
	_fx.idle.connect(_refresh_overlays)

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


func _plaque(rect: Rect2) -> VBoxContainer:
	var panel := _panel(rect, UiStyle.PANEL_COLOR)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	return box


func _pile_box(zone: DropZone, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	zone.add_child(box)
	var caption := _caption(title)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	return box


## Small gold capitals for headings on the table.
func _caption(text: String) -> Label:
	var label := _label(text, 11)
	label.add_theme_color_override("font_color", Color(0.92, 0.75, 0.42))
	return label


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
	overlay.color = Color(0.04, 0.03, 0.07, 0.94)
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
	text.add_theme_font_size_override("font_size", 30)
	text.add_theme_color_override("font_color", Color(0.98, 0.85, 0.55))
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


func _panel(rect: Rect2, color: Color, parent: Control = self) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(color, UiStyle.PANEL_BORDER, 1, 8, 12, 6))
	_place(panel, rect, parent)
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
	_refresh_overlays()


## The pass and end screens. The end screen waits for the last animations.
func _refresh_overlays() -> void:
	if tc == null:
		return
	_pass_overlay.visible = awaiting_pass and not tc.state.is_over()
	_pass_label.text = "Pass the device to %s" % UiStyle.player_name(tc.state.current_seat)
	_end_overlay.visible = tc.state.is_over() and not _fx.busy()
	if tc.state.is_over():
		_end_label.text = ("Draw! Nobody survives." if tc.state.is_draw
				else "%s wins!" % UiStyle.player_name(tc.state.winner_seat)) \
				+ "\n(round %d)" % tc.state.round_number


func _refresh_joker(joker: Dictionary, preview: Array[int]) -> void:
	_joker.set_element(joker["element"])
	_joker.set_eyed(_seat_points(preview))
	_joker_damage.text = str(joker["damage"])
	for child: Node in _joker_type.get_children():
		child.queue_free()
	_joker_type.add_child(UiStyle.chip(Element.type_name(joker["element"]), UiStyle.type_color(joker["element"]), 12))
	var mods: PackedStringArray = []
	if joker["targeting"] != &"":
		mods.append(UiStyle.modifier_name(joker["targeting"]))
	if joker["pattern"] != &"":
		mods.append(UiStyle.modifier_name(joker["pattern"]))
	for id: StringName in joker["effects"]:
		mods.append(UiStyle.modifier_name(id))
	_joker_mods.text = ", ".join(mods) if not mods.is_empty() else "none"
	var eyeing: String = "a random player" if joker["targeting"] == JokerModifier.WILD_CARD else "nobody"
	if not preview.is_empty():
		eyeing = ", ".join(preview.map(func(s: int) -> String: return UiStyle.player_name(s)))
	_joker_eye.text = eyeing


func _refresh_seats(view: Dictionary, preview: Array[int], recent: Dictionary) -> void:
	for child: Node in _seat_layer.get_children():
		child.queue_free()
	_player_zones.clear()
	_figures.clear()
	_hp_bars.clear()
	_hp_labels.clear()
	var traps_on: Dictionary = _traps_by_host(view)
	for p: Dictionary in view["players"]:
		var seat: int = p["seat"]
		var origin: Vector2 = _seat_origin(seat)
		var alive: bool = p["is_alive"] or not _shown_dead.has(seat)
		var is_current: bool = seat == tc.state.current_seat and not tc.state.is_over()
		var eyed: bool = preview.has(seat)

		var border: Color = UiStyle.PANEL_BORDER
		if is_current:
			border = UiStyle.HIGHLIGHT_COLOR
		elif eyed and alive:
			border = UiStyle.DANGER_COLOR
		var plate := PanelContainer.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_theme_stylebox_override("panel", UiStyle.panel_style(UiStyle.PANEL_COLOR, border,
				2 if is_current or eyed else 1, 0, 12, 6))
		_place(plate, Rect2(origin, PLATE_SIZE), _seat_layer)

		var figure := Figures.PlayerFigure.new()
		figure.seat = seat
		figure.element = p["element"]
		figure.alive = alive
		figure.active = is_current
		figure.eyed = eyed
		_place(figure, Rect2(origin + AVATAR_RECT.position, AVATAR_RECT.size), _seat_layer)
		_figures[seat] = figure

		var info := VBoxContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_theme_constant_override("separation", 3)
		_place(info, Rect2(origin + Vector2(88, 6), Vector2(146, 106)), _seat_layer)
		var title: String = UiStyle.player_name(seat)
		if seat == viewer_seat:
			title += " (you)"
		elif not is_human(seat):
			title += " (bot)"
		var name_label := _label(("▶ " if is_current else "") + title, 15)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		if is_current:
			name_label.add_theme_color_override("font_color", UiStyle.HIGHLIGHT_COLOR)
		info.add_child(name_label)
		if not alive:
			var out := _label("Eliminated", 14)
			out.add_theme_color_override("font_color", UiStyle.DANGER_COLOR)
			info.add_child(out)
		else:
			info.add_child(_hp_bar(seat))
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(UiStyle.chip(Element.type_name(p["element"]), UiStyle.type_color(p["element"])))
			row.add_child(_drama_meter(p["heat"], eyed))
			info.add_child(row)
			var chips := HFlowContainer.new()
			chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chips.add_theme_constant_override("h_separation", 3)
			chips.add_theme_constant_override("v_separation", 2)
			for status: String in _statuses(p):
				chips.add_child(UiStyle.chip(status, UiStyle.status_color(status.get_slice(" x", 0)), 10))
			var cards := _label("%d cards" % p["hand_size"], 10)
			cards.autowrap_mode = TextServer.AUTOWRAP_OFF
			cards.add_theme_color_override("font_color", UiStyle.MUTED_INK)
			chips.add_child(cards)
			info.add_child(chips)

		var zone := _zone(DropZone.Kind.PLAYER, seat, UiStyle.PLAYER_POOL_COLOR,
				Rect2(origin + Vector2(0, 122), Vector2(SEAT_SIZE.x, 104)), _seat_layer)
		_player_zones[seat] = zone
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(box)
		box.add_child(_caption("%s'S POOL" % UiStyle.player_name(seat).to_upper()))
		var cards_row := HBoxContainer.new()
		cards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(cards_row)
		_fill_pool(cards_row, recent.get(seat, []), traps_on.get(seat, []))
		if p.has("hand") and seat != viewer_seat:
			box.add_child(_label("Exposed hand: %s" % ", ".join(
					p["hand"].map(func(c: CardData) -> String: return c.display_name)), 10))


## HP as a bar that goes from green to red, showing the HP the animations have reached.
func _hp_bar(seat: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.max_value = Config.MAX_HP
	bar.custom_minimum_size = Vector2(140, 18)
	bar.add_theme_stylebox_override("background", UiStyle.panel_style(Color(0.05, 0.04, 0.06), Color(0, 0, 0, 0.6), 1, 0, 5))
	var label := _label("", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(label)
	_hp_bars[seat] = bar
	_hp_labels[seat] = label
	_show_hp(seat, _shown_hp.get(seat, Config.STARTING_HP))
	return bar


func _show_hp(seat: int, hp: int) -> void:
	if not _hp_bars.has(seat) or not is_instance_valid(_hp_bars[seat]):
		return
	var bar: ProgressBar = _hp_bars[seat]
	var ratio: float = clampf(float(hp) / Config.MAX_HP, 0.0, 1.0)
	var fill: Color = Color(0.85, 0.2, 0.2).lerp(Color(0.3, 0.8, 0.35), ratio)
	bar.add_theme_stylebox_override("fill", UiStyle.panel_style(fill, fill.lightened(0.3), 1, 0, 5))
	if bar.is_inside_tree() and absf(bar.value - hp) > 0.5 and bar.value > 0.0:
		bar.create_tween().tween_property(bar, "value", float(hp), 0.35).set_ease(Tween.EASE_OUT)
	else:
		bar.value = hp
	(_hp_labels[seat] as Label).text = "♥ %d / %d" % [hp, Config.MAX_HP]


func _drama_meter(heat: int, eyed: bool) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := _label("Drama %d" % heat, 12)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.max_value = UiStyle.DRAMA_BAR_MAX
	bar.value = mini(heat, UiStyle.DRAMA_BAR_MAX)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(30, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill_color: Color = UiStyle.DANGER_COLOR if eyed else Color(0.95, 0.6, 0.2)
	bar.add_theme_stylebox_override("fill", UiStyle.panel_style(fill_color, Color(0, 0, 0, 0), 0, 0, 4))
	bar.add_theme_stylebox_override("background", UiStyle.panel_style(Color(0.05, 0.04, 0.06), Color(0, 0, 0, 0), 0, 0, 4))
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
	_draw_stack.count = view["draw_pile_size"]
	_draw_stack.queue_redraw()
	_draw_label.text = "%d cards\n%s" % [view["draw_pile_size"],
			"Click to draw (%d/%d)" % [tc.state.draws_this_turn, Config.MAX_DRAWS_PER_TURN] if drawing else ""]
	var discards: Array = view["discard_pile"]
	for child: Node in _discard_top.get_children():
		child.queue_free()
	if not discards.is_empty():
		_discard_top.add_child(_mini_card(discards.back(), false))
	_discard_label.text = "%d cards\n%s" % [discards.size(), "Drop here to discard" if drawing else ""]


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
		view_card.spent = is_my_turn() and slot_spent((hand[i] as CardData).slot())
		view_card.draggable = is_my_turn() and not view_card.spent
		view_card.selected = i == selected_index
		view_card.hovered.connect(_show_detail)
		view_card.unhovered.connect(func(_v: CardView) -> void: _detail.visible = false)
		view_card.clicked.connect(func(v: CardView) -> void:
			if not is_my_turn():
				return
			if v.spent:
				message = "You've already played a %s card this turn" % UiStyle.slot_symbol(v.card.slot())
				_refresh()
			else:
				select_card(v.hand_index))
		_hand_layer.add_child(view_card)
		var offset: float = i - mid
		view_card.set_rest(Vector2(start_x + spacing * i, 4.0 + offset * offset * 1.2), offset * 3.0)


func _refresh_info() -> void:
	var seat: int = tc.state.current_seat
	_round_label.text = "Round %d  ·  %s's turn" % [tc.state.round_number, UiStyle.player_name(seat)]
	_end_button.visible = is_my_turn()
	_end_button.text = "End turn" if not tc.state.slots_played.is_empty() else "Skip turn (+%d Drama)" % Config.SKIP_HEAT
	_bot_button.visible = is_bot_turn() and not auto_play_bots and not _bot_running
	_bot_button.text = "▶ Play %s's turn" % UiStyle.player_name(seat)
	_auto_toggle.visible = not bots.is_empty()
	if _auto_toggle.button_pressed != auto_play_bots:
		_auto_toggle.set_pressed_no_signal(auto_play_bots)
	if tc.state.is_over():
		_timer_label.text = ""
		_hint_label.text = ""
	elif not is_human(seat):
		var running: bool = auto_play_bots or _bot_running
		_timer_label.text = "%s is %s" % [UiStyle.player_name(seat), "playing…" if running else "waiting"]
		_hint_label.text = "" if running else "Bot turns wait for you so you can watch them. Press Play, or switch on Auto-play bots."
	else:
		_timer_label.text = "Time left: %s" % _clock(time_left)
		var slots: String = "★ trap / Joker: %s    ● attack / effect: %s" % [
			"played" if state_has_slot(CardData.Slot.ONE) else "free",
			"played" if state_has_slot(CardData.Slot.TWO) else "free"]
		if tc.state.phase == GameState.Phase.DRAW:
			_hint_label.text = "Draw up to 3, discard 1 if you like, then drag cards onto a pool: 1 star card + 1 circle card.\n" + slots
		else:
			_hint_label.text = "Drag a card onto a player's pool to target them, or onto the collective pool to hit everyone.\n" + slots
	_message_label.text = message


## Seconds as m:ss for the turn timer.
static func _clock(seconds: float) -> String:
	var total: int = ceili(maxf(seconds, 0.0))
	return "%d:%02d" % [total / 60, total % 60]


func state_has_slot(slot: CardData.Slot) -> bool:
	return tc.state.slots_played.has(slot)


## True when no more cards of this slot can be played this turn: the slot was used,
## or the player is Silenced and has already played their one card.
func slot_spent(slot: CardData.Slot) -> bool:
	if tc.state.slots_played.has(slot):
		return true
	return tc.state.turn_restrictions.has(TurnRestriction.ONE_CARD) and not tc.state.slots_played.is_empty()


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
			"star card: slot 1 (trap / Joker)" if card.slot() == CardData.Slot.ONE
					else "circle card: slot 2 (attack / effect)"])
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


# --- Animations ------------------------------------------------------------------------------

## Queues an animation for every event since the last call, as the viewer may see it.
func _animate_new_events() -> void:
	var events: Array[GameEvent] = tc.state.get_events_for(viewer_seat, _seen_events)
	_seen_events = tc.state.events.size()
	for event: GameEvent in events:
		_animate(event)


func _animate(event: GameEvent) -> void:
	if event is GameEvents.CardPlayed:
		var played := event as GameEvents.CardPlayed
		var from: Vector2 = HAND_POINT if played.seat == viewer_seat else _seat_center(played.seat)
		var to: Vector2 = _pool_center(played.target_seat if played.mode == CardData.Mode.TARGETED else PlacedTrap.POOL)
		if played.card.family == CardData.Family.JOKER_MODIFIER:
			to = _joker_point()
		_fx.enqueue(func() -> void:
			_fx.fly_card(played.card, false, from, to, 0.45, _flourish.bind(played.card, to)), 0.6)
	elif event is GameEvents.TrapPlaced:
		var placed := event as GameEvents.TrapPlaced
		var host: Vector2 = _pool_center(placed.host_seat)
		_fx.enqueue(func() -> void:
			_fx.fly_card(placed.card, true, Vector2(host.x, -60), host, 0.45), 0.55)
	elif event is GameEvents.TrapFired:
		var fired := event as GameEvents.TrapFired
		var at: Vector2 = _pool_center(fired.host_seat)
		_fx.enqueue(func() -> void:
			_fx.ring(at, Color(0.3, 0.95, 0.85), 70.0)
			_fx.burst(at, Color(0.3, 0.95, 0.85), 20)
			_fx.float_text(at, "TRAP! %s" % fired.card.display_name, Color(0.4, 1.0, 0.9), 22, 1.4), 0.7)
	elif event is GameEvents.DamageDealt:
		var hit := event as GameEvents.DamageDealt
		_fx.enqueue(_show_damage.bind(hit), 0.2)
	elif event is GameEvents.Healed:
		var healed := event as GameEvents.Healed
		_fx.enqueue(func() -> void:
			var at: Vector2 = _seat_center(healed.seat)
			_fx.ring(at, UiStyle.HEAL_COLOR, 48.0)
			_fx.float_text(at, "+%d" % healed.amount, UiStyle.HEAL_COLOR, 24)
			_set_shown_hp(healed.seat, healed.hp_after), 0.2)
	elif event is GameEvents.HeatChanged:
		var heat := event as GameEvents.HeatChanged
		if heat.new_heat > heat.old_heat:
			_fx.enqueue(func() -> void:
				_fx.float_text(_seat_center(heat.seat) + Vector2(64, -28), "+%d Drama" % (heat.new_heat - heat.old_heat),
						Color(1.0, 0.65, 0.25), 14), 0.0)
	elif event is GameEvents.TypeChanged:
		var changed := event as GameEvents.TypeChanged
		_fx.enqueue(func() -> void:
			var at: Vector2 = _seat_center(changed.seat)
			var color: Color = UiStyle.type_color(changed.new_element).lightened(0.3)
			_fx.ring(at, color, 64.0)
			_fx.burst(at, color, 12)
			_fx.float_text(at + Vector2(0, -24), Element.type_name(changed.new_element), color, 18), 0.3)
	elif event is GameEvents.TypeChangeBlocked:
		var blocked := event as GameEvents.TypeChangeBlocked
		_fx.enqueue(func() -> void:
			_fx.float_text(_seat_center(blocked.seat), "Rooted: no change", UiStyle.status_color("Rooted").lightened(0.4), 16), 0.25)
	elif event is GameEvents.StatusApplied:
		var status := event as GameEvents.StatusApplied
		var status_name: String = String(status.status).capitalize()
		_fx.enqueue(func() -> void:
			_fx.float_text(_seat_center(status.seat) + Vector2(0, 20), status_name,
					UiStyle.status_color(status_name).lightened(0.35), 16), 0.15)
	elif event is GameEvents.TurnRestricted:
		var restricted := event as GameEvents.TurnRestricted
		var label: String = "Dry Well" if restricted.restriction == TurnRestriction.NO_DISCARD else "Silenced"
		_fx.enqueue(func() -> void:
			_fx.float_text(_seat_center(restricted.seat) + Vector2(0, 20), label, UiStyle.status_color(label).lightened(0.4), 16), 0.15)
	elif event is GameEvents.CardsDrawn:
		var drawn := event as GameEvents.CardsDrawn
		var to: Vector2 = HAND_POINT if drawn.seat == viewer_seat else _seat_center(drawn.seat)
		for i: int in mini(drawn.count, 3):
			_fx.enqueue(func() -> void: _fx.fly_card(null, true, DRAW_RECT.get_center(), to, 0.3), 0.1)
		_fx.enqueue(func() -> void: pass, 0.15)
	elif event is GameEvents.CardDiscarded:
		var discarded := event as GameEvents.CardDiscarded
		var from: Vector2 = HAND_POINT if discarded.seat == viewer_seat else _seat_center(discarded.seat)
		_fx.enqueue(func() -> void: _fx.fly_card(discarded.card, false, from, DISCARD_RECT.get_center(), 0.35), 0.4)
	elif event is GameEvents.DeckReshuffled:
		_fx.enqueue(func() -> void:
			_fx.float_text(DRAW_RECT.get_center(), "Reshuffled", UiStyle.INK, 16), 0.3)
	elif event is GameEvents.PlayerSkipped:
		var skipped := event as GameEvents.PlayerSkipped
		_fx.enqueue(func() -> void:
			_fx.float_text(_seat_center(skipped.seat), "Skip", UiStyle.MUTED_INK, 20), 0.3)
	elif event is GameEvents.TurnStarted:
		var started := event as GameEvents.TurnStarted
		_fx.enqueue(func() -> void: _fx.ring(_seat_center(started.seat), UiStyle.HIGHLIGHT_COLOR, 56.0), 0.15)
	elif event is GameEvents.RoundStarted:
		var round_started := event as GameEvents.RoundStarted
		_fx.enqueue(func() -> void:
			_fx.banner("Round %d" % round_started.round_number, UiStyle.HIGHLIGHT_COLOR,
					"The Joker hits for %d" % round_started.joker_damage, 0.8), 1.2)
	elif event is GameEvents.JokerAttacked:
		var attack := event as GameEvents.JokerAttacked
		var targets: Array[Vector2] = _seat_points(attack.target_seats)
		var color: Color = UiStyle.type_color(attack.element).lightened(0.35)
		_fx.enqueue(func() -> void:
			_joker.struck.connect(func() -> void:
				for point: Vector2 in targets:
					_fx.beam(_joker_point(), point, color), CONNECT_ONE_SHOT)
			_joker.attack(targets), 0.75)
	elif event is GameEvents.JokerStoodDown:
		_fx.enqueue(func() -> void:
			_joker.react()
			_fx.float_text(_joker_point() + Vector2(0, 40), "The Joker stands down", UiStyle.INK, 18, 1.4), 0.6)
	elif event is GameEvents.JokerModified or event is GameEvents.JokerTypeChanged:
		var text: String = UiStyle.modifier_name((event as GameEvents.JokerModified).modifier_id) \
				if event is GameEvents.JokerModified \
				else "Joker turns %s" % Element.type_name((event as GameEvents.JokerTypeChanged).new_element)
		_fx.enqueue(func() -> void:
			_joker.react()
			_fx.ring(_joker_point(), Color(0.75, 0.45, 0.95), 90.0)
			_fx.float_text(_joker_point() + Vector2(0, 50), text, Color(0.85, 0.65, 1.0), 18, 1.3), 0.45)
	elif event is GameEvents.PlayerEliminated:
		var out := event as GameEvents.PlayerEliminated
		_fx.enqueue(func() -> void:
			_shown_dead.append(out.seat)
			_fx.burst(_seat_center(out.seat), UiStyle.DANGER_COLOR, 40, 260.0)
			_fx.banner("%s is out!" % UiStyle.player_name(out.seat), UiStyle.DANGER_COLOR, "", 0.9)
			_refresh_seats_only(), 1.3)


func _show_damage(hit: GameEvents.DamageDealt) -> void:
	var at: Vector2 = _seat_center(hit.target_seat)
	var color: Color = Color(1.0, 0.35, 0.3)
	var text: String = "-%d" % hit.damage
	var font_size: int = 26
	match hit.cause:
		Status.POISON:
			color = UiStyle.status_color("Poison").lightened(0.4)
			text += " poison"
			font_size = 20
		Status.BURN:
			color = UiStyle.status_color("Burn").lightened(0.3)
			text += " burn"
			font_size = 20
	if hit.multiplier > 1.0:
		text += "!"
		font_size += 8
		_fx.float_text(at + Vector2(0, 30), "super effective", Color(1.0, 0.85, 0.3), 13)
	elif hit.multiplier < 1.0:
		_fx.float_text(at + Vector2(0, 30), "resisted", UiStyle.MUTED_INK, 13)
	_fx.float_text(at, text, color, font_size)
	_fx.burst(at, UiStyle.type_color(hit.element).lightened(0.3), 12)
	_fx.flash_circle(at, Color(1.0, 0.2, 0.2), 34.0)
	if _figures.has(hit.target_seat):
		_fx.shake(_figures[hit.target_seat])
	_set_shown_hp(hit.target_seat, hit.hp_after)


## A little extra on arrival, by the card's type: fire rises, water splashes, grass
## scatters leaves, Joker cards make the Joker jump.
func _flourish(card: CardData, at: Vector2) -> void:
	if card.family == CardData.Family.JOKER_MODIFIER:
		_joker.react()
		_fx.ring(at, Color(0.75, 0.45, 0.95), 80.0)
		return
	var color: Color = UiStyle.type_color(card.element).lightened(0.35)
	match card.element:
		Element.Type.FIRE:
			_fx.burst(at, Color(1.0, 0.6, 0.2), 24, 90.0, 110.0)
		Element.Type.WATER:
			_fx.ring(at, color, 70.0)
			_fx.burst(at, color, 18, 140.0)
		Element.Type.GRASS:
			_fx.burst(at, color, 18, 120.0, -60.0)
		_:
			_fx.ring(at, Color(0.95, 0.9, 0.8), 60.0)


func _set_shown_hp(seat: int, hp: int) -> void:
	_shown_hp[seat] = hp
	_show_hp(seat, hp)


## Rebuilds only the seats (safe while a card is being dragged).
func _refresh_seats_only() -> void:
	var view: Dictionary = tc.state.get_view_for(viewer_seat)
	_refresh_seats(view, tc.preview_joker_targets(), _recent_plays())


func _seat_origin(seat: int) -> Vector2:
	return SEAT_SLOTS[tc.state.players.size()][seat]


## The middle of a player's portrait.
func _seat_center(seat: int) -> Vector2:
	return _seat_origin(seat) + AVATAR_RECT.get_center()


func _seat_points(seats: Array[int]) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for seat: int in seats:
		points.append(_seat_center(seat))
	return points


## The middle of a player's pool, or of the collective pool for PlacedTrap.POOL.
func _pool_center(host: int) -> Vector2:
	if host == PlacedTrap.POOL or host < 0:
		return POOL_RECT.get_center()
	return _seat_origin(host) + Vector2(SEAT_SIZE.x / 2.0, 174)


func _joker_point() -> Vector2:
	return JOKER_RECT.position + Vector2(JOKER_RECT.size.x / 2.0, 80)


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
