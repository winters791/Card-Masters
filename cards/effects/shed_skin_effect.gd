class_name ShedSkinEffect
extends CardEffect
## Shed Skin: the player changes to the chosen type, then deals params.damage of
## their (new) type to every target. If they're Rooted the change fails and the
## damage uses their current type.


# RULE-ASSUMPTION: "change your own type" means a different type than your current one.
func validate_play(state: GameState, intent: Intents.PlayCard) -> String:
	if not Element.Type.values().has(intent.chosen_element):
		return "Choose a type to change into"
	if intent.chosen_element == state.player(intent.seat).element:
		return "Choose a different type than your current one"
	return ""


func resolve(ctx: EffectContext) -> void:
	ctx.rules.change_element(ctx.source_seat, ctx.chosen_element as Element.Type)
	var damage: int = int(ctx.card.params.get("damage", 0))
	var element: Element.Type = ctx.state.player(ctx.source_seat).element
	for target_seat: int in ctx.target_seats:
		ctx.rules.deal_damage(ctx.source_seat, target_seat, damage, element)
