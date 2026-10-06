class_name JokerModifierEffect
extends CardEffect
## Puts params.modifier (a JokerModifier id) on the Joker, passing the card's other
## params along (Overcharge's bonus, Venom Fang's poison).


func resolve(ctx: EffectContext) -> void:
	var params: Dictionary = ctx.card.params.duplicate()
	var modifier_id := StringName(params.get("modifier", ""))
	assert(JokerModifier.is_known(modifier_id), "%s has no valid modifier" % ctx.card.id)
	params.erase("modifier")
	ctx.rules.add_joker_modifier(modifier_id, ctx.source_seat, params)
