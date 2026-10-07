class_name SetupScreen
extends Control
## Pick 2–4 seats, each a human or a bot, then start a hotseat match.

signal start_requested(seat_kinds: Array[String], match_seed: int)

const KINDS: Array[String] = ["human", "greedy", "random"]
const KIND_LABELS: Array[String] = ["Human", "Bot (greedy)", "Bot (random)"]

var player_count: OptionButton
var seat_pickers: Array[OptionButton] = []
var seed_box: SpinBox
var start_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.make_theme()
	var backdrop := Figures.TableBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stage := HBoxContainer.new()
	center.add_child(stage)
	# The host, waiting for a show.
	var joker := Joker3D.new()
	joker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stage.add_child(joker)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(UiStyle.PANEL_COLOR, UiStyle.PANEL_BORDER, 2, 22, 16, 10))
	stage.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Card Masters"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.45))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var tagline := Label.new()
	tagline.text = "Every card is a weapon. The Joker loves drama."
	tagline.add_theme_color_override("font_color", UiStyle.MUTED_INK)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tagline)
	box.add_child(HSeparator.new())

	var count_row := HBoxContainer.new()
	box.add_child(count_row)
	count_row.add_child(_label("Players:"))
	player_count = OptionButton.new()
	for n: int in range(Config.MIN_PLAYERS, Config.MAX_PLAYERS + 1):
		player_count.add_item(str(n), n)
	player_count.select(player_count.item_count - 1)
	player_count.item_selected.connect(func(_i: int) -> void: _update_seats())
	count_row.add_child(player_count)

	for seat: int in Config.MAX_PLAYERS:
		var row := HBoxContainer.new()
		row.add_child(_label("%s:" % UiStyle.player_name(seat)))
		var picker := OptionButton.new()
		for label: String in KIND_LABELS:
			picker.add_item(label)
		# Default: two humans, bots in the other seats.
		picker.select(0 if seat < 2 else 1)
		row.add_child(picker)
		seat_pickers.append(picker)
		box.add_child(row)

	var seed_row := HBoxContainer.new()
	seed_row.add_child(_label("Seed (0 = random):"))
	seed_box = SpinBox.new()
	seed_box.max_value = 999999
	seed_row.add_child(seed_box)
	box.add_child(seed_row)

	start_button = Button.new()
	start_button.text = "Start match"
	start_button.custom_minimum_size = Vector2(0, 46)
	start_button.add_theme_font_size_override("font_size", 20)
	start_button.pressed.connect(_on_start)
	box.add_child(start_button)
	_update_seats()


func selected_kinds() -> Array[String]:
	var kinds: Array[String] = []
	for seat: int in player_count.get_selected_id():
		kinds.append(KINDS[seat_pickers[seat].selected])
	return kinds


func _update_seats() -> void:
	for seat: int in seat_pickers.size():
		seat_pickers[seat].get_parent().visible = seat < player_count.get_selected_id()


func _on_start() -> void:
	var match_seed: int = int(seed_box.value)
	if match_seed == 0:
		match_seed = randi_range(1, 999999)
	start_requested.emit(selected_kinds(), match_seed)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 170
	return label
