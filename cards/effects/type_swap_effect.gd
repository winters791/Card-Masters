class_name TypeSwapEffect
extends CardEffect
## Type Swap: the player and the target trade types (targeted only). Fails entirely
## if either of them is Rooted.


func resolve(ctx: EffectContext) -> void:
	for target_seat: int in ctx.target_seats:
		ctx.rules.swap_elements(ctx.source_seat, target_seat)
