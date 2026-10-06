class_name RotEffect
extends CardEffect
## Rot: the target's next resist is halved (see Config.ROT_RESIST_MULTIPLIER).


func resolve(ctx: EffectContext) -> void:
	for target_seat: int in ctx.target_seats:
		ctx.rules.apply_rot(target_seat, ctx.source_seat)
