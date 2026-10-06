class_name GameEvents
extends RefCounted
## Typed event log entries. The UI animates from these; bots and tests read them.

class MatchStarted extends GameEvent:
	var match_seed: int
	var player_count: int

	func _init(p_seed: int, p_player_count: int) -> void:
		match_seed = p_seed
		player_count = p_player_count

	func describe() -> String:
		return "Match started: %d players, seed %d" % [player_count, match_seed]


class RoundStarted extends GameEvent:
	var round_number: int
	var starting_seat: int
	var joker_damage: int

	func _init(p_round: int, p_starting_seat: int, p_joker_damage: int) -> void:
		round_number = p_round
		starting_seat = p_starting_seat
		joker_damage = p_joker_damage

	func describe() -> String:
		return "Round %d starts with seat %d (Joker hits for %d)" % [round_number, starting_seat, joker_damage]


class TurnStarted extends GameEvent:
	var seat: int

	func _init(p_seat: int) -> void:
		seat = p_seat

	func describe() -> String:
		return "Seat %d's turn" % seat


## Cards drawn are private to the drawer; everyone else only sees the count.
class CardsDrawn extends GameEvent:
	var seat: int
	var count: int
	var cards: Array[CardData]

	func _init(p_seat: int, p_cards: Array[CardData]) -> void:
		seat = p_seat
		count = p_cards.size()
		cards = p_cards

	func view_for(viewer_seat: int) -> GameEvent:
		if viewer_seat == seat:
			return self
		var empty: Array[CardData] = []
		var redacted := CardsDrawn.new(seat, empty)
		redacted.count = count
		return redacted

	func describe() -> String:
		return "Seat %d draws %d" % [seat, count]


class CardsKept extends GameEvent:
	var seat: int
	var kept_count: int
	var discarded_count: int

	func _init(p_seat: int, p_kept: int, p_discarded: int) -> void:
		seat = p_seat
		kept_count = p_kept
		discarded_count = p_discarded

	func describe() -> String:
		return "Seat %d keeps %d, discards %d" % [seat, kept_count, discarded_count]


class DeckReshuffled extends GameEvent:
	var draw_pile_size: int

	func _init(p_size: int) -> void:
		draw_pile_size = p_size

	func describe() -> String:
		return "Discard pile reshuffled into the deck (%d cards)" % draw_pile_size


class CardPlayed extends GameEvent:
	var seat: int
	var card: CardData
	var mode: CardData.Mode
	## -1 for collective plays.
	var target_seat: int

	func _init(p_seat: int, p_card: CardData, p_mode: CardData.Mode, p_target: int) -> void:
		seat = p_seat
		card = p_card
		mode = p_mode
		target_seat = p_target

	func describe() -> String:
		if mode == CardData.Mode.TARGETED:
			return "Seat %d plays %s at seat %d" % [seat, card.display_name, target_seat]
		return "Seat %d plays %s into the collective pool" % [seat, card.display_name]


class HeatChanged extends GameEvent:
	var seat: int
	var old_heat: int
	var new_heat: int
	var reason: StringName

	func _init(p_seat: int, p_old: int, p_new: int, p_reason: StringName) -> void:
		seat = p_seat
		old_heat = p_old
		new_heat = p_new
		reason = p_reason

	func describe() -> String:
		return "Seat %d Heat %d -> %d (%s)" % [seat, old_heat, new_heat, reason]


class DamageDealt extends GameEvent:
	## Seat of the attacker, or GameEvent.JOKER_SEAT.
	var source_seat: int
	var target_seat: int
	var element: Element.Type
	var base_damage: int
	var multiplier: float
	var damage: int
	var hp_after: int

	func _init(p_source: int, p_target: int, p_element: Element.Type, p_base: int,
			p_multiplier: float, p_damage: int, p_hp_after: int) -> void:
		source_seat = p_source
		target_seat = p_target
		element = p_element
		base_damage = p_base
		multiplier = p_multiplier
		damage = p_damage
		hp_after = p_hp_after

	func describe() -> String:
		var source: String = "Joker" if source_seat == JOKER_SEAT else "Seat %d" % source_seat
		return "%s hits seat %d for %d %s (%sx) -> %d HP" % [
			source, target_seat, damage, Element.type_name(element), multiplier, hp_after]


class PlayerSkipped extends GameEvent:
	var seat: int

	func _init(p_seat: int) -> void:
		seat = p_seat

	func describe() -> String:
		return "Seat %d skips" % seat


class TurnEnded extends GameEvent:
	var seat: int

	func _init(p_seat: int) -> void:
		seat = p_seat

	func describe() -> String:
		return "Seat %d ends their turn" % seat


class JokerAttacked extends GameEvent:
	var round_number: int
	var element: Element.Type
	var damage: int
	var target_seats: Array[int]

	func _init(p_round: int, p_element: Element.Type, p_damage: int, p_targets: Array[int]) -> void:
		round_number = p_round
		element = p_element
		damage = p_damage
		target_seats = p_targets

	func describe() -> String:
		return "Joker attacks seats %s for %d" % [str(target_seats), damage]


class PlayerEliminated extends GameEvent:
	var seat: int
	var round_number: int

	func _init(p_seat: int, p_round: int) -> void:
		seat = p_seat
		round_number = p_round

	func describe() -> String:
		return "Seat %d is eliminated in round %d" % [seat, round_number]


class RoundEnded extends GameEvent:
	var round_number: int

	func _init(p_round: int) -> void:
		round_number = p_round

	func describe() -> String:
		return "Round %d ends" % round_number


class MatchEnded extends GameEvent:
	## -1 on a draw.
	var winner_seat: int
	var is_draw: bool

	func _init(p_winner: int, p_is_draw: bool) -> void:
		winner_seat = p_winner
		is_draw = p_is_draw

	func describe() -> String:
		if is_draw:
			return "Match ends in a draw"
		return "Seat %d wins" % winner_seat
