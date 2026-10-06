class_name ExposedEffect
extends CardEffect
## Exposed: every target's hand is shown to everyone until the end of the next round.


func resolve(ctx: EffectContext) -> void:
	for target_seat: int in ctx.target_seats:
		ctx.rules.apply_exposed(target_seat, ctx.source_seat)
