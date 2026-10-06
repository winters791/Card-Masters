class_name TypeSnareTrap
extends TrapEffect
## The next player to change type (the covered one, or anyone from the pool) takes
## params.damage (untyped).


func trigger() -> StringName:
	return TrapOccurrence.TYPE_CHANGED


func fire(rules: TurnController, trap: PlacedTrap, occurrence: TrapOccurrence) -> void:
	rules.deal_damage(trap.owner_seat, occurrence.subject_seat, int(trap.card.params.get("damage", 0)),
			Element.Type.NORMAL, &"trap")
