class_name DropZone
extends PanelContainer
## A place on the table cards can be dropped on (or clicked): a player's pool, the
## collective pool, the draw pile or the discard pile. The match screen decides what
## a drop means through the callables it hands over.

enum Kind { PLAYER, POOL, DRAW, DISCARD }

var kind: Kind
## The player this pool belongs to (PLAYER zones only).
var seat: int = -1
var base_color: Color
## func(hand_index: int, kind: Kind, seat: int) -> bool
var can_drop: Callable
## func(hand_index: int, kind: Kind, seat: int) -> void
var on_drop: Callable
## func(kind: Kind, seat: int) -> void
var on_click: Callable
var highlighted: bool = false


func _init(p_kind: Kind, p_seat: int, p_color: Color) -> void:
	kind = p_kind
	seat = p_seat
	base_color = p_color
	mouse_filter = Control.MOUSE_FILTER_STOP
	_restyle()


func set_highlight(on: bool) -> void:
	if highlighted != on:
		highlighted = on
		_restyle()


func _restyle() -> void:
	var border: Color = UiStyle.VALID_DROP_COLOR if highlighted else Color(base_color.lightened(0.45), 0.7)
	var fill: Color = base_color.lerp(Color(UiStyle.VALID_DROP_COLOR, base_color.a), 0.18) if highlighted else base_color
	var style := UiStyle.panel_style(fill, border, 3 if highlighted else 1, 8, 14)
	if highlighted:
		style.shadow_color = Color(UiStyle.VALID_DROP_COLOR, 0.35)
		style.shadow_size = 10
	add_theme_stylebox_override("panel", style)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("hand_index") and can_drop.is_valid() \
			and can_drop.call(int(data["hand_index"]), kind, seat)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	on_drop.call(int(data["hand_index"]), kind, seat)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and on_click.is_valid():
		on_click.call(kind, seat)
