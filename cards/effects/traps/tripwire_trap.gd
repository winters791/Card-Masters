class_name TripwireTrap
extends TrapEffect
## The next player to play a targeted card (at the covered player, or at anyone from
## the pool) gains params.heat.


func trigger() -> StringName:
	return TrapOccurrence.TARGETED_PLAY


func fire(rules: TurnController, trap: PlacedTrap, occurrence: TrapOccurrence) -> void:
	rules.add_heat(occurrence.actor_seat, int(trap.card.params.get("heat", 0)), &"tripwire")
