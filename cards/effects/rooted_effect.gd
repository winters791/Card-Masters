class_name RootedEffect
extends CardEffect
## Rooted: every target's type is locked until the end of the next round.


func resolve(ctx: EffectContext) -> void:
	for target_seat: int in ctx.target_seats:
		ctx.rules.apply_root(target_seat, ctx.source_seat)
