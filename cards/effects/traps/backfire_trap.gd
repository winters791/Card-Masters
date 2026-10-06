class_name BackfireTrap
extends TrapEffect
## The next targeted card that deals direct damage to the covered player hits the
## player who played it instead. They still pay its Heat.


func trigger() -> StringName:
	return TrapOccurrence.TARGETED_PLAY


func matches(_rules: TurnController, _trap: PlacedTrap, occurrence: TrapOccurrence) -> bool:
	return occurrence.card != null and occurrence.card.deals_direct_damage()


func fire(_rules: TurnController, _trap: PlacedTrap, occurrence: TrapOccurrence) -> void:
	occurrence.redirect_seat = occurrence.actor_seat
