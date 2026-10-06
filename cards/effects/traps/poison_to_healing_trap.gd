class_name PoisonToHealingTrap
extends TrapEffect
## Someone stacks poison on the covered player: it becomes healing instead (the same
## amount per round, for the same number of rounds).


func trigger() -> StringName:
	return TrapOccurrence.POISON_APPLIED


func fire(rules: TurnController, trap: PlacedTrap, occurrence: TrapOccurrence) -> void:
	occurrence.cancelled = true
	rules.apply_healing(occurrence.subject_seat, int(occurrence.data.get("damage", 0)),
			int(occurrence.data.get("rounds", 0)), trap.owner_seat)
