class_name GiveHeatEffect
extends CardEffect
## Scapegoat: every target gains params.heat.


func resolve(ctx: EffectContext) -> void:
	for target_seat: int in ctx.target_seats:
		ctx.rules.add_heat(target_seat, int(ctx.card.params.get("heat", 0)), ctx.card.id)
