class_name UiStyle
extends RefCounted
## Placeholder look (Phase 4): flat colours per type, simple panels, readable text.

const TYPE_COLORS: Dictionary[Element.Type, Color] = {
	Element.Type.NORMAL: Color(0.55, 0.45, 0.32),
	Element.Type.GRASS: Color(0.22, 0.52, 0.24),
	Element.Type.WATER: Color(0.18, 0.38, 0.68),
	Element.Type.FIRE: Color(0.74, 0.30, 0.14),
}
const PANEL_COLOR: Color = Color(0.17, 0.15, 0.22)
const HIGHLIGHT_COLOR: Color = Color(0.95, 0.80, 0.30)
const DANGER_COLOR: Color = Color(0.85, 0.20, 0.25)
## Drama meter scale: a full bar means "very likely the Joker's target".
const DRAMA_BAR_MAX: int = 15


static func type_color(element: Element.Type) -> Color:
	return TYPE_COLORS[element]


static func player_name(seat: int) -> String:
	return "Player %d" % (seat + 1)


static func panel_style(color: Color, border: Color = Color(0, 0, 0, 0), border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	return style


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


## One-line description of a card for buttons and tooltips.
static func card_summary(card: CardData) -> String:
	var parts: PackedStringArray = []
	if card.element != Element.Type.NORMAL or card.family == CardData.Family.ATTACK:
		parts.append(Element.type_name(card.element))
	if card.params.has("damage"):
		parts.append("%d dmg" % int(card.params["damage"]))
	parts.append("Drama %d" % card.base_heat)
	match card.mode_lock:
		CardData.ModeLock.COLLECTIVE_ONLY:
			parts.append("pool only")
		CardData.ModeLock.TARGETED_ONLY:
			parts.append("targeted only")
	return " · ".join(parts)
