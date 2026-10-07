class_name Figures
extends RefCounted
## Placeholder figures drawn with simple shapes (real art arrives in Phase 7).


## A player's portrait: a silhouette in a ring of their type's colour. The current
## player glows gold; whoever the Joker is eyeing gets a red target reticle.
class PlayerFigure extends Control:
	var element: Element.Type = Element.Type.NORMAL
	var alive: bool = true
	var active: bool = false
	var eyed: bool = false
	var seat: int = 0
	var _time: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(76, 76)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if active or eyed:
			_time += delta
			queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size / 2.0
		var radius: float = minf(size.x, size.y) / 2.0 - 4.0
		var ring: Color = UiStyle.type_color(element).lightened(0.15)
		if not alive:
			ring = Color(0.3, 0.3, 0.32)
		if active and alive:
			var glow: float = 0.5 + 0.5 * sin(_time * 4.0)
			for i: int in 4:
				draw_circle(center, radius + 2.0 + i * 1.5, Color(UiStyle.HIGHLIGHT_COLOR, 0.12 + 0.08 * glow), false, 2.0)
		draw_circle(center + Vector2(0, 3), radius + 1.0, Color(0, 0, 0, 0.45))
		draw_circle(center, radius, ring)
		draw_circle(center, radius - 5.0, ring.darkened(0.7) if alive else Color(0.12, 0.12, 0.13))
		# Silhouette: head and shoulders, clipped to the portrait by drawing order.
		var ink: Color = Color(0.92, 0.88, 0.80) if alive else Color(0.35, 0.35, 0.36)
		var inner: float = radius - 5.0
		draw_circle(center + Vector2(0, -inner * 0.22), inner * 0.32, ink)
		var shoulders := PackedVector2Array()
		for i: int in 17:
			var angle: float = PI + i * PI / 16.0
			shoulders.append(center + Vector2(0, inner * 0.62) + Vector2(cos(angle) * inner * 0.62, sin(angle) * inner * 0.5))
		draw_colored_polygon(shoulders, ink)
		UiStyle.draw_type_icon(self, element, center + Vector2(radius * 0.72, radius * 0.72), 9.0,
				ring.lightened(0.3) if alive else ring)
		if not alive:
			draw_line(center + Vector2(-16, -16), center + Vector2(16, 16), UiStyle.DANGER_COLOR, 4.0)
			draw_line(center + Vector2(16, -16), center + Vector2(-16, 16), UiStyle.DANGER_COLOR, 4.0)
		if eyed and alive:
			var spin: float = _time * 1.5
			var red: Color = UiStyle.DANGER_COLOR
			draw_arc(center, radius + 3.0, 0.0, TAU, 40, Color(red, 0.85), 2.0)
			for i: int in 4:
				var angle: float = spin + i * PI / 2.0
				var dir := Vector2(cos(angle), sin(angle))
				draw_line(center + dir * (radius - 2.0), center + dir * (radius + 9.0), red, 3.0)


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


## The picture window of a card: its type symbol on a glowing backdrop, or a trap /
## Joker emblem for those families.
class CardArt extends Control:
	var card: CardData

	func _init(p_card: CardData) -> void:
		card = p_card
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var base: Color = UiStyle.card_color(card)
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, base.darkened(0.55))
		var center: Vector2 = size / 2.0
		for i: int in 6:
			draw_circle(center, size.y * (0.55 - i * 0.07), Color(base.lightened(0.2), 0.10 + i * 0.03))
		var radius: float = size.y * 0.36
		match card.family:
			CardData.Family.TRAP:
				# A sprung jaw: two rows of teeth.
				var teeth := PackedVector2Array()
				for i: int in 7:
					var x: float = -radius * 1.2 + i * radius * 0.4
					teeth.append(center + Vector2(x, -radius * 0.1 if i % 2 == 0 else radius * 0.45))
				draw_polyline(teeth, base.lightened(0.6), 3.0)
				draw_arc(center, radius * 1.1, PI * 1.1, PI * 1.9, 16, base.lightened(0.6), 3.0)
			CardData.Family.JOKER_MODIFIER:
				Figures.draw_jester_hat(self, center + Vector2(0, radius * 0.3), radius * 1.1, base.lightened(0.45))
			_:
				UiStyle.draw_type_icon(self, card.element, center, radius, UiStyle.type_color(card.element).lightened(0.35))
		draw_rect(rect, Color(0, 0, 0, 0.5), false, 1.0)


## The back of a card: a jester's diamond lattice.
class CardBack extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, UiStyle.CARD_BACK_COLOR)
		var gold := Color(0.85, 0.66, 0.30, 0.35)
		var step: float = maxf(10.0, size.x / 5.0)
		var half: float = step * 0.32
		var y: float = step / 2.0
		var row: int = 0
		while y < size.y:
			var x: float = step / 2.0 if row % 2 == 0 else step
			while x < size.x - half:
				var diamond := PackedVector2Array([Vector2(x, y - half), Vector2(x + half, y),
						Vector2(x, y + half), Vector2(x - half, y), Vector2(x, y - half)])
				draw_polyline(diamond, gold, 1.0)
				x += step
			y += step / 2.0
			row += 1
		var center: Vector2 = size / 2.0
		var r: float = minf(size.x, size.y) * 0.28
		draw_circle(center, r + 3.0, UiStyle.CARD_BACK_COLOR.darkened(0.3))
		draw_arc(center, r + 3.0, 0.0, TAU, 32, Color(0.85, 0.66, 0.30), 2.0)
		Figures.draw_jester_hat(self, center + Vector2(0, r * 0.35), r * 0.95, Color(0.85, 0.66, 0.30))


## A face-down stack of cards (the draw pile).
class PileStack extends Control:
	var count: int = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var layers: int = clampi(floori(count / 12.0) + 1, 1, 6) if count > 0 else 0
		var card := Rect2(Vector2(6, 4), size - Vector2(18, 14))
		for i: int in layers:
			var r := Rect2(card.position + Vector2(i * 2.0, i * -2.0 + layers * 2.0), card.size)
			draw_style_box(UiStyle.panel_style(UiStyle.CARD_BACK_COLOR.darkened(0.1 * (layers - i)),
					Color(0.85, 0.66, 0.30, 0.8), 1, 0, 6), r)
		if layers > 0:
			var top := Rect2(card.position + Vector2((layers - 1) * 2.0, 2.0), card.size)
			var center: Vector2 = top.get_center()
			draw_arc(center, 16.0, 0.0, TAU, 32, Color(0.85, 0.66, 0.30), 2.0)
			Figures.draw_jester_hat(self, center + Vector2(0, 5), 15.0, Color(0.85, 0.66, 0.30))


## The room and the oval card table under everything.
class TableBackdrop extends Control:
	const TABLE_CENTER: Vector2 = Vector2(640, 300)
	const TABLE_RADII: Vector2 = Vector2(610, 300)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiStyle.ROOM_COLOR)
		# A pool of warm light from above.
		for i: int in 10:
			draw_circle(Vector2(size.x / 2.0, 260), 700.0 - i * 55.0, Color(0.35, 0.22, 0.15, 0.025))
		var squash := Vector2(1.0, TABLE_RADII.y / TABLE_RADII.x)
		draw_set_transform(TABLE_CENTER + Vector2(0, 14), 0.0, squash)
		draw_circle(Vector2.ZERO, TABLE_RADII.x + 6.0, Color(0, 0, 0, 0.5))
		draw_set_transform(TABLE_CENTER, 0.0, squash)
		draw_circle(Vector2.ZERO, TABLE_RADII.x, UiStyle.WOOD_COLOR.darkened(0.25))
		draw_circle(Vector2.ZERO, TABLE_RADII.x - 6.0, UiStyle.WOOD_COLOR)
		draw_arc(Vector2.ZERO, TABLE_RADII.x - 14.0, 0.0, TAU, 96, UiStyle.WOOD_COLOR.lightened(0.15), 2.0)
		var felt_radius: float = TABLE_RADII.x - 26.0
		for i: int in 16:
			var t: float = i / 15.0
			draw_circle(Vector2.ZERO, felt_radius * (1.0 - t * 0.85),
					UiStyle.FELT_COLOR.darkened(0.35).lerp(UiStyle.FELT_COLOR.lightened(0.08), t))
		draw_arc(Vector2.ZERO, felt_radius - 12.0, 0.0, TAU, 96, Color(0.85, 0.66, 0.30, 0.25), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A jester's three-pointed hat with bells, for card backs and Joker cards.
static func draw_jester_hat(canvas: CanvasItem, base: Vector2, height: float, color: Color) -> void:
	var w: float = height * 0.55
	var tips: Array[Vector2] = [base + Vector2(-w * 1.25, -height * 0.55), base + Vector2(0, -height),
			base + Vector2(w * 1.25, -height * 0.55)]
	var dark := color.darkened(0.35)
	canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-w, 0), tips[0], base + Vector2(-w * 0.2, -height * 0.3)]), dark)
	canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(w, 0), tips[2], base + Vector2(w * 0.2, -height * 0.3)]), dark)
	canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.55, 0), tips[1], base + Vector2(w * 0.55, 0)]), color)
	canvas.draw_rect(Rect2(base + Vector2(-w, -height * 0.08), Vector2(w * 2.0, height * 0.16)), color)
	for tip: Vector2 in tips:
		canvas.draw_circle(tip, maxf(1.5, height * 0.1), color.lightened(0.4))
