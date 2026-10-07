class_name Figures
extends RefCounted
## Placeholder figures drawn with simple shapes (real art arrives in Phase 7).


## A seated player on a patch of terrain coloured by their type.
class PlayerFigure extends Control:
	var element: Element.Type = Element.Type.NORMAL
	var alive: bool = true
	var active: bool = false
	var eyed: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(76, 92)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x
		var terrain: Color = UiStyle.type_color(element)
		if not alive:
			terrain = terrain.darkened(0.7)
		draw_set_transform(Vector2(w / 2.0, size.y - 10.0), 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, w / 2.0, terrain)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var ink: Color = Color(0.92, 0.9, 0.85) if alive else Color(0.4, 0.4, 0.4)
		if eyed:
			ink = UiStyle.DANGER_COLOR
		elif active:
			ink = UiStyle.HIGHLIGHT_COLOR
		var body := Rect2(w / 2.0 - 20.0, 36.0, 40.0, 42.0)
		draw_rect(body, ink.darkened(0.55))
		draw_rect(body, ink, false, 2.0)
		draw_circle(Vector2(w / 2.0, 22.0), 15.0, ink.darkened(0.55))
		draw_arc(Vector2(w / 2.0, 22.0), 15.0, 0.0, TAU, 32, ink, 2.0)
		if not alive:
			draw_line(Vector2(w / 2.0 - 10, 14), Vector2(w / 2.0 + 10, 30), ink, 2.0)
			draw_line(Vector2(w / 2.0 + 10, 14), Vector2(w / 2.0 - 10, 30), ink, 2.0)


## Slot marker in a card's corner: a star for slot 1 (traps and Joker cards), a
## circle for slot 2 (attacks and effects).
class SlotBadge extends Control:
	var slot: CardData.Slot = CardData.Slot.TWO

	func _init(p_slot: CardData.Slot, badge_size: float) -> void:
		slot = p_slot
		custom_minimum_size = Vector2(badge_size, badge_size)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center: Vector2 = size / 2.0
		var radius: float = minf(size.x, size.y) / 2.0
		var fill := Color(0.98, 0.95, 0.85)
		var outline := Color(0.1, 0.08, 0.12)
		if slot == CardData.Slot.ONE:
			var points := PackedVector2Array()
			for i: int in 10:
				var r: float = radius if i % 2 == 0 else radius * 0.45
				var angle: float = -PI / 2.0 + i * PI / 5.0
				points.append(center + Vector2(cos(angle), sin(angle)) * r)
			draw_colored_polygon(points, fill)
			points.append(points[0])
			draw_polyline(points, outline, 1.5)
		else:
			draw_circle(center, radius * 0.8, fill)
			draw_arc(center, radius * 0.8, 0.0, TAU, 24, outline, 1.5)


## The Joker: a party-hatted host, tinted by the Joker's type.
class JokerFigure extends Control:
	var element: Element.Type = Element.Type.NORMAL

	func _init() -> void:
		custom_minimum_size = Vector2(80, 96)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var cx: float = size.x / 2.0
		var tint: Color = UiStyle.type_color(element).lightened(0.25)
		var ink := Color(0.95, 0.93, 0.88)
		# Hat with a pompom.
		draw_colored_polygon(PackedVector2Array([Vector2(cx, 4), Vector2(cx - 18, 30), Vector2(cx + 18, 30)]), tint)
		draw_circle(Vector2(cx, 4), 4.0, ink)
		# Head, body, arms, legs.
		draw_arc(Vector2(cx, 42), 12.0, 0.0, TAU, 32, tint, 3.0)
		draw_line(Vector2(cx, 54), Vector2(cx, 76), ink, 3.0)
		draw_line(Vector2(cx, 60), Vector2(cx - 16, 70), ink, 3.0)
		draw_line(Vector2(cx, 60), Vector2(cx + 16, 52), ink, 3.0)
		draw_line(Vector2(cx, 76), Vector2(cx - 12, 92), ink, 3.0)
		draw_line(Vector2(cx, 76), Vector2(cx + 12, 92), ink, 3.0)
