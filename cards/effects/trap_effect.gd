class_name TrapEffect
extends CardEffect
## Base for traps. Playing a trap only places it (the rules engine does that); the
## trap's effect runs later, when its trigger happens and matches.


## The TrapOccurrence trigger this trap listens for.
func trigger() -> StringName:
	return &""


## Extra conditions beyond the trigger and the trap's spot. "Covers its spot" is
## checked by the engine: a trap on a player only sees occurrences for that player.
func matches(_rules: TurnController, _trap: PlacedTrap, _occurrence: TrapOccurrence) -> bool:
	return true


## The trap's effect. May change the occurrence (cancel or redirect it).
func fire(_rules: TurnController, _trap: PlacedTrap, _occurrence: TrapOccurrence) -> void:
	pass


func resolve(_ctx: EffectContext) -> void:
	push_error("Traps are placed by the rules engine, not resolved")
