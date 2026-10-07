class_name CardView
extends PanelContainer
## One card, drawn as a card. Hovering asks the screen to show its details; cards in
## the hand can be dragged onto a pool or a pile, or clicked to select them.

signal hovered(view: CardView)
signal unhovered(view: CardView)
signal clicked(view: CardView)

const FULL_SIZE: Vector2 = Vector2(110, 152)
const MINI_SIZE: Vector2 = Vector2(66, 78)
## How far a hovered or selected hand card rises.
const LIFT: float = 26.0

var card: CardData
## Index in the viewer's hand, or -1 for cards elsewhere (pools, traps).
var hand_index: int = -1
var draggable: bool = false
var face_down: bool = false
var mini: bool = false
var selected: bool = false
## Its slot was already used this turn: drawn dark and can't be dragged.
var spent: bool = false

var _rest_position: Vector2
var _rest_rotation: float
var _tween: Tween


static func make(p_card: CardData, p_mini: bool = false, p_face_down: bool = false) -> CardView:
	var view := CardView.new()
	view.card = p_card
	view.mini = p_mini
	view.face_down = p_face_down
	return view


func _ready() -> void:
	if spent:
		modulate = Color(0.42, 0.42, 0.42)
	custom_minimum_size = MINI_SIZE if mini else FULL_SIZE
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)


## Where the card sits in a fanned hand when it isn't lifted.
func set_rest(p_position: Vector2, p_rotation_degrees: float) -> void:
	_rest_position = p_position
	_rest_rotation = p_rotation_degrees
	position = p_position
	rotation_degrees = p_rotation_degrees
	if selected:
		_lift(true)


func _build() -> void:
	var face_up: bool = card != null and not face_down
	var header: Color = UiStyle.card_color(card) if face_up else UiStyle.CARD_BACK_COLOR
	var border: Color = UiStyle.HIGHLIGHT_COLOR if selected else Color(0.93, 0.88, 0.76)
	var style := UiStyle.panel_style(header.darkened(0.62), border, 3 if selected else 2,
			3 if mini else 6, 6 if mini else 10, 0 if mini else 5)
	add_theme_stylebox_override("panel", style)
	if not face_up:
		var back := Figures.CardBack.new()
		back.custom_minimum_size = custom_minimum_size - Vector2(8, 8)
		add_child(back)
		return
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 1 if mini else 3)
	add_child(box)
	# Header: slot badge in the corner (star = slot 1, circle = slot 2), then the name.
	var title := _label(card.display_name, 9 if mini else 13, HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar := PanelContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", UiStyle.panel_style(header, header.lightened(0.3), 1, 2 if mini else 3,
			4 if mini else 6))
	var header_row := HBoxContainer.new()
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_theme_constant_override("separation", 2)
	header_row.add_child(Figures.SlotBadge.new(card.slot(), 10.0 if mini else 15.0))
	header_row.add_child(title)
	bar.add_child(header_row)
	box.add_child(bar)
	var art := Figures.CardArt.new(card)
	art.custom_minimum_size = Vector2(0, 26 if mini else 44)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL if mini else Control.SIZE_FILL
	box.add_child(art)
	if mini:
		return
	box.add_child(_label(UiStyle.card_summary(card), 11, HORIZONTAL_ALIGNMENT_CENTER))
	var drama := _label("Drama " + "●".repeat(card.base_heat), 11, HORIZONTAL_ALIGNMENT_CENTER)
	drama.add_theme_color_override("font_color", Color(0.98, 0.65, 0.30))
	box.add_child(drama)
	var family := _label(UiStyle.family_name(card.family), 10, HORIZONTAL_ALIGNMENT_CENTER)
	family.add_theme_color_override("font_color", UiStyle.MUTED_INK)
	family.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	box.add_child(family)


func _label(text: String, font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	# Whole words only: "Venom Fang" may wrap, "Venom" never splits.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 0)
	return label


func _lift(up: bool) -> void:
	if hand_index < 0:
		return
	z_index = 10 if up else 0
	var goal: Vector2 = _rest_position + (Vector2(0, -LIFT) if up else Vector2.ZERO)
	var angle: float = 0.0 if up else _rest_rotation
	if not is_inside_tree():
		position = goal
		rotation_degrees = angle
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", goal, 0.14)
	_tween.tween_property(self, "rotation_degrees", angle, 0.14)
	_tween.tween_property(self, "scale", Vector2.ONE * (1.06 if up else 1.0), 0.14)


func _on_enter() -> void:
	_lift(true)
	hovered.emit(self)


func _on_exit() -> void:
	if not selected:
		_lift(false)
	unhovered.emit(self)


## A click is a release without a drag in between (a drag delivers its release to the
## drop target instead). Reacting on press would rebuild the hand mid-drag.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and not click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not draggable or spent:
		return null
	var preview := CardView.make(card)
	preview.modulate.a = 0.85
	var holder := Control.new()
	holder.add_child(preview)
	preview.position = -FULL_SIZE / 2.0
	set_drag_preview(holder)
	return {"hand_index": hand_index}
