class_name DiscardRandomEffect
extends CardEffect
## Pickpocket: every target discards params.count random cards.


func resolve(ctx: EffectContext) -> void:
	for target_seat: int in ctx.target_seats:
		ctx.rules.discard_random(target_seat, int(ctx.card.params.get("count", 0)))
