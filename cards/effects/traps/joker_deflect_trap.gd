class_name JokerDeflectTrap
extends TrapEffect
## The Joker would hit the covered player: the hit goes 2 living seats anticlockwise
## instead (to the other player if that lands back on them). No Heat reset for them.


func trigger() -> StringName:
	return TrapOccurrence.JOKER_HIT


func fire(rules: TurnController, _trap: PlacedTrap, occurrence: TrapOccurrence) -> void:
	var from: int = occurrence.subject_seat
	var target: int = _living_seat_anticlockwise(rules.state, from, 2)
	if target == from:
		target = _living_seat_anticlockwise(rules.state, from, 1)
	occurrence.redirect_seat = target


## Anticlockwise is the opposite of turn order (lower seat numbers), counting only
## living players.
static func _living_seat_anticlockwise(state: GameState, from: int, steps: int) -> int:
	var count: int = state.players.size()
	var seat: int = from
	var taken: int = 0
	while taken < steps:
		seat = (seat - 1 + count) % count
		if state.player(seat).is_alive:
			taken += 1
	return seat
