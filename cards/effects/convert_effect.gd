class_name ConvertEffect
extends CardEffect
## Convert: every target becomes the type the player chose. Rooted targets resist.


func needs_element_choice() -> bool:
	return true


func validate_play(_state: GameState, intent: Intents.PlayCard) -> String:
	if not Element.Type.values().has(intent.chosen_element):
		return "Choose a type to convert to"
	return ""


func resolve(ctx: EffectContext) -> void:
	for target_seat: int in ctx.target_seats:
		ctx.rules.change_element(target_seat, ctx.chosen_element as Element.Type)
