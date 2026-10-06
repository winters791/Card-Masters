class_name FlashpointEffect
extends CardEffect
## Flashpoint (collective): everyone at params.threshold Heat or more gains
## params.heat. Heat is checked after the player has paid for the card.


func resolve(ctx: EffectContext) -> void:
	var threshold: int = int(ctx.card.params.get("threshold", 0))
	var hot: Array[int] = ctx.target_seats.filter(
			func(seat: int) -> bool: return ctx.state.player(seat).heat >= threshold)
	for seat: int in hot:
		ctx.rules.add_heat(seat, int(ctx.card.params.get("heat", 0)), ctx.card.id)
