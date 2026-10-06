class_name SpotlightEffect
extends CardEffect
## Spotlight (collective): everyone tied for the lowest Heat gains params.heat. Heat
## is checked after the player has paid for the card, so they can be among them.


func resolve(ctx: EffectContext) -> void:
	var lowest: int = -1
	for seat: int in ctx.target_seats:
		var heat: int = ctx.state.player(seat).heat
		if lowest < 0 or heat < lowest:
			lowest = heat
	for seat: int in ctx.target_seats:
		if ctx.state.player(seat).heat == lowest:
			ctx.rules.add_heat(seat, int(ctx.card.params.get("heat", 0)), ctx.card.id)
