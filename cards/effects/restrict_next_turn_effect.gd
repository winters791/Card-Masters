class_name RestrictNextTurnEffect
extends CardEffect
## Restricts each target's next turn with params.restriction (a TurnRestriction id).


func resolve(ctx: EffectContext) -> void:
	var restriction := StringName(ctx.card.params.get("restriction", ""))
	for target_seat: int in ctx.target_seats:
		ctx.rules.restrict_next_turn(target_seat, restriction)
