class_name GameState
extends RefCounted
## All match data. Rules live in TurnController; this is just the state plus
## read-only helpers and per-viewer filtering.

enum Phase {
	## The current player is choosing which drawn cards to keep.
	KEEP,
	## The current player may play cards or end their turn.
	PLAY,
	OVER,
}

var match_seed: int
## The only source of randomness in a match.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var players: Array[PlayerState] = []
var deck: Deck
var joker: JokerState = JokerState.new()
var events: Array[GameEvent] = []

var round_number: int = 0
var phase: Phase = Phase.KEEP
var current_seat: int = -1
## Seats still to act this round, in order (the current seat is already removed).
var turn_queue: Array[int] = []
## Cards drawn this turn, waiting for the keep decision. Private to current_seat.
var pending_draw: Array[CardData] = []
## Slots used by the current player this turn.
var slots_played: Array[CardData.Slot] = []

var winner_seat: int = -1
var is_draw: bool = false


func _init(p_seed: int, player_count: int) -> void:
	match_seed = p_seed
	rng.seed = p_seed
	for seat: int in player_count:
		players.append(PlayerState.new(seat))
	deck = Deck.new(rng)


func is_over() -> bool:
	return phase == Phase.OVER


func player(seat: int) -> PlayerState:
	return players[seat]


func current_player() -> PlayerState:
	return players[current_seat]


func alive_seats() -> Array[int]:
	var seats: Array[int] = []
	for p: PlayerState in players:
		if p.is_alive:
			seats.append(p.seat)
	return seats


func joker_damage() -> int:
	return JokerState.damage_for_round(round_number)


## Everything `viewer_seat` is allowed to know. Hands and pending draws of other
## players are reduced to counts. Use -1 for a spectator who sees no hands.
func get_view_for(viewer_seat: int) -> Dictionary:
	var player_views: Array[Dictionary] = []
	for p: PlayerState in players:
		var view: Dictionary = {
			"seat": p.seat,
			"hp": p.hp,
			"element": p.element,
			"heat": p.heat,
			"is_alive": p.is_alive,
			"hand_size": p.hand.size(),
		}
		if p.seat == viewer_seat:
			view["hand"] = p.hand.duplicate()
		player_views.append(view)
	var result: Dictionary = {
		"viewer_seat": viewer_seat,
		"round_number": round_number,
		"phase": phase,
		"current_seat": current_seat,
		"players": player_views,
		"joker": {"element": joker.element, "damage": joker_damage()},
		"draw_pile_size": deck.draw_pile.size(),
		"discard_pile": deck.discard_pile.duplicate(),
		"pending_draw_size": pending_draw.size(),
		"winner_seat": winner_seat,
		"is_draw": is_draw,
	}
	if viewer_seat == current_seat:
		result["pending_draw"] = pending_draw.duplicate()
	return result


## The event log from `from_index` on, with hidden information removed for viewer_seat.
func get_events_for(viewer_seat: int, from_index: int = 0) -> Array[GameEvent]:
	var visible: Array[GameEvent] = []
	for i: int in range(from_index, events.size()):
		visible.append(events[i].view_for(viewer_seat))
	return visible
