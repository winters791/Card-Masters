class_name JokerTypeEffect
extends CardEffect
## Ignite / Flood / Overgrow: sets the Joker's type to params.element.


func resolve(ctx: EffectContext) -> void:
	ctx.rules.set_joker_element(int(ctx.card.params.get("element", Element.Type.NORMAL)) as Element.Type,
			ctx.source_seat)
