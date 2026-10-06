class_name WellspringTrap
extends TrapEffect
## Collective pool only. A Water card enters the collective pool: every Water player
## heals params.heal (after that card has resolved).


func trigger() -> StringName:
	return TrapOccurrence.COLLECTIVE_PLAY


func matches(_rules: TurnController, _trap: PlacedTrap, occurrence: TrapOccurrence) -> bool:
	return occurrence.card != null and occurrence.card.element == Element.Type.WATER


func fire(rules: TurnController, trap: PlacedTrap, _occurrence: TrapOccurrence) -> void:
	for seat: int in rules.state.alive_seats():
		if rules.state.player(seat).element == Element.Type.WATER:
			rules.heal(seat, int(trap.card.params.get("heal", 0)), &"wellspring")
