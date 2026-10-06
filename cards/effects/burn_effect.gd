class_name BurnEffect
extends CardEffect
## Scorch: a burn stack of params.tick_damage per round until the target changes type.


func resolve(ctx: EffectContext) -> void:
	var damage: int = int(ctx.card.params.get("tick_damage", 0))
	for target_seat: int in ctx.target_seats:
		ctx.rules.apply_burn(target_seat, damage, ctx.source_seat)
