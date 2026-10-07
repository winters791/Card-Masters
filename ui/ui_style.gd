class_name UiStyle
extends RefCounted
## Shared look: colours per type, panels, the button theme and small drawn icons.
## Still placeholder art (real art arrives in Phase 7), just tidier.

const TYPE_COLORS: Dictionary[Element.Type, Color] = {
	Element.Type.NORMAL: Color(0.55, 0.45, 0.32),
	Element.Type.GRASS: Color(0.22, 0.52, 0.24),
	Element.Type.WATER: Color(0.18, 0.38, 0.68),
	Element.Type.FIRE: Color(0.74, 0.30, 0.14),
}
const PANEL_COLOR: Color = Color(0.11, 0.10, 0.15, 0.92)
const PANEL_BORDER: Color = Color(0.85, 0.70, 0.40, 0.55)
const INK: Color = Color(0.96, 0.93, 0.86)
const MUTED_INK: Color = Color(0.70, 0.67, 0.62)
const HEAL_COLOR: Color = Color(0.40, 0.90, 0.50)
const ROOM_COLOR: Color = Color(0.06, 0.05, 0.09)
const FELT_COLOR: Color = Color(0.10, 0.30, 0.22)
const WOOD_COLOR: Color = Color(0.36, 0.20, 0.11)
const CARD_BACK_COLOR: Color = Color(0.20, 0.10, 0.28)
const STATUS_COLORS: Dictionary[String, Color] = {
	"Poison": Color(0.55, 0.30, 0.70),
	"Burn": Color(0.90, 0.42, 0.12),
	"Healing": Color(0.25, 0.65, 0.35),
	"Rot": Color(0.45, 0.35, 0.20),
	"Rooted": Color(0.20, 0.45, 0.20),
	"Exposed": Color(0.75, 0.62, 0.15),
	"Dry Well": Color(0.25, 0.45, 0.70),
	"Silenced": Color(0.40, 0.40, 0.45),
}
const HIGHLIGHT_COLOR: Color = Color(0.95, 0.80, 0.30)
const DANGER_COLOR: Color = Color(0.85, 0.20, 0.25)
const VALID_DROP_COLOR: Color = Color(0.45, 0.95, 0.55)
const TABLE_COLOR: Color = Color(0.13, 0.20, 0.17)
const POOL_COLOR: Color = Color(0.08, 0.16, 0.30, 0.78)
const PLAYER_POOL_COLOR: Color = Color(0.03, 0.10, 0.07, 0.55)
const PILE_COLOR: Color = Color(0.08, 0.07, 0.12, 0.6)
## Drama meter scale: a full bar means "very likely the Joker's target".
const DRAMA_BAR_MAX: int = 15


static func type_color(element: Element.Type) -> Color:
	return TYPE_COLORS[element]


## Header colour for a card: traps and Joker cards get their own colour, the rest
## show their type.
static func card_color(card: CardData) -> Color:
	match card.family:
		CardData.Family.TRAP:
			return Color(0.12, 0.45, 0.45)
		CardData.Family.JOKER_MODIFIER:
			return Color(0.48, 0.22, 0.55)
	return type_color(card.element)


static func family_name(family: CardData.Family) -> String:
	return {
		CardData.Family.ATTACK: "Attack",
		CardData.Family.DAMAGE_OVER_TIME: "Damage over time",
		CardData.Family.TYPE_MANIPULATION: "Type change",
		CardData.Family.DISRUPTION: "Disruption",
		CardData.Family.HEAT_MANIPULATION: "Drama trick",
		CardData.Family.JOKER_MODIFIER: "Joker card",
		CardData.Family.TRAP: "Trap",
	}[family]


## "star" (slot 1: traps and Joker cards) or "circle" (slot 2: attacks and effects).
static func slot_symbol(slot: CardData.Slot) -> String:
	return "star" if slot == CardData.Slot.ONE else "circle"


static func modifier_name(id: StringName) -> String:
	return String(id).replace("_", " ").capitalize()


static func player_name(seat: int) -> String:
	return "Player %d" % (seat + 1)


static func panel_style(color: Color, border: Color = Color(0, 0, 0, 0), border_width: int = 0,
		margin: int = 8, radius: int = 8, shadow: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.anti_aliasing = true
	if shadow > 0:
		style.shadow_color = Color(0, 0, 0, 0.45)
		style.shadow_size = shadow
		style.shadow_offset = Vector2(0, shadow / 2.0)
	return style


## The buttons and fonts every screen shares.
static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	var gold := Color(0.85, 0.66, 0.30)
	theme.set_stylebox("normal", "Button", panel_style(Color(0.26, 0.17, 0.30), gold, 2, 8, 10, 3))
	theme.set_stylebox("hover", "Button", panel_style(Color(0.36, 0.24, 0.40), HIGHLIGHT_COLOR, 2, 8, 10, 4))
	theme.set_stylebox("pressed", "Button", panel_style(Color(0.18, 0.11, 0.22), HIGHLIGHT_COLOR, 2, 8, 10, 1))
	theme.set_stylebox("disabled", "Button", panel_style(Color(0.16, 0.15, 0.18), Color(0.35, 0.33, 0.35), 1, 8, 10))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.5, 0.48, 0.45))
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	theme.set_constant("outline_size", "Label", 2)
	for kind: String in ["CheckButton", "OptionButton", "SpinBox", "LineEdit"]:
		theme.set_color("font_color", kind, INK)
	theme.set_stylebox("normal", "OptionButton", panel_style(Color(0.20, 0.17, 0.25), gold, 1, 6, 8))
	theme.set_stylebox("hover", "OptionButton", panel_style(Color(0.28, 0.23, 0.33), HIGHLIGHT_COLOR, 1, 6, 8))
	theme.set_stylebox("normal", "LineEdit", panel_style(Color(0.12, 0.11, 0.16), gold, 1, 6, 6))
	return theme


## A small rounded "pill" with text, for types and statuses.
static func chip(text: String, color: Color, font_size: int = 11) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := panel_style(color, color.lightened(0.3), 1, 0, 7)
	style.content_margin_left = 6
	style.content_margin_right = 6
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 0)
	panel.add_child(label)
	return panel


static func status_color(status: String) -> Color:
	return STATUS_COLORS.get(status, Color(0.4, 0.4, 0.45))


## Draws a type's symbol (Fire flame, Water drop, Grass leaf, Normal sparkle) on
## `canvas`, centred on `center`, about `radius` tall either side.
static func draw_type_icon(canvas: CanvasItem, element: Element.Type, center: Vector2, radius: float,
		color: Color) -> void:
	var outline := color.darkened(0.6)
	var points := PackedVector2Array()
	match element:
		Element.Type.FIRE:
			for p: Vector2 in [Vector2(0.1, -1.0), Vector2(0.5, -0.4), Vector2(0.66, 0.2), Vector2(0.48, 0.66),
					Vector2(0.0, 0.88), Vector2(-0.48, 0.66), Vector2(-0.66, 0.2), Vector2(-0.42, -0.25),
					Vector2(-0.22, 0.05), Vector2(-0.12, -0.55)]:
				points.append(center + p * radius)
			canvas.draw_colored_polygon(points, color)
			var inner := PackedVector2Array()
			for p: Vector2 in [Vector2(0.05, -0.25), Vector2(0.32, 0.25), Vector2(0.25, 0.6), Vector2(0.0, 0.72),
					Vector2(-0.25, 0.6), Vector2(-0.3, 0.3)]:
				inner.append(center + p * radius)
			canvas.draw_colored_polygon(inner, color.lightened(0.55))
		Element.Type.WATER:
			points.append(center + Vector2(0, -1.0) * radius)
			for i: int in 17:
				var angle: float = deg_to_rad(-20.0 + i * 220.0 / 16.0)
				points.append(center + (Vector2(0, 0.28) + Vector2(cos(angle), sin(angle)) * 0.6) * radius)
			canvas.draw_colored_polygon(points, color)
			canvas.draw_circle(center + Vector2(-0.22, 0.25) * radius, radius * 0.14, color.lightened(0.6))
		Element.Type.GRASS:
			var tilt := Transform2D(deg_to_rad(30.0), center)
			for i: int in 13:
				var t: float = i / 12.0
				points.append(tilt * (Vector2(sin(PI * t) * 0.5, -0.95 + 1.9 * t) * radius))
			for i: int in range(11, 0, -1):
				var t: float = i / 12.0
				points.append(tilt * (Vector2(-sin(PI * t) * 0.5, -0.95 + 1.9 * t) * radius))
			canvas.draw_colored_polygon(points, color)
			canvas.draw_line(tilt * Vector2(0, -0.8 * radius), tilt * Vector2(0, 1.05 * radius), outline, 1.5)
		_:
			for i: int in 8:
				var r: float = radius if i % 2 == 0 else radius * 0.3
				var angle: float = -PI / 2.0 + i * PI / 4.0
				points.append(center + Vector2(cos(angle), sin(angle)) * r)
			canvas.draw_colored_polygon(points, color)


## Event log lines speak in players (1-based) and Drama, like the game does.
static func humanize(line: String) -> String:
	var seats := RegEx.create_from_string("([Ss]eat) (\\d+)")
	var out: String = ""
	var last: int = 0
	for m: RegExMatch in seats.search_all(line):
		out += line.substr(last, m.get_start() - last)
		out += "Player %d" % (int(m.get_string(2)) + 1)
		last = m.get_end()
	out += line.substr(last)
	var lists := RegEx.create_from_string("seats \\[([0-9, ]*)\\]")
	var listed: RegExMatch = lists.search(out)
	if listed != null:
		var names: PackedStringArray = []
		for part: String in listed.get_string(1).split(",", false):
			names.append("Player %d" % (int(part.strip_edges()) + 1))
		out = out.substr(0, listed.get_start()) + ", ".join(names) + out.substr(listed.get_end())
	return out.replace("Heat", "Drama")


## Short line under a card's name: type, damage and mode lock (Drama is shown apart).
static func card_summary(card: CardData) -> String:
	var parts: PackedStringArray = []
	if card.element != Element.Type.NORMAL or card.family == CardData.Family.ATTACK:
		parts.append(Element.type_name(card.element))
	if card.params.has("damage"):
		parts.append("%d dmg" % int(card.params["damage"]))
	match card.mode_lock:
		CardData.ModeLock.COLLECTIVE_ONLY:
			parts.append("pool only")
		CardData.ModeLock.TARGETED_ONLY:
			parts.append("targeted only")
	return " · ".join(parts)
