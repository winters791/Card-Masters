class_name Heat
extends RefCounted
## Heat formula (§5): Base × mode, then +1 for effects that also deal direct damage.


static func mode_multiplier(mode: CardData.Mode) -> int:
	if mode == CardData.Mode.TARGETED:
		return Config.TARGETED_HEAT_MULTIPLIER
	return Config.COLLECTIVE_HEAT_MULTIPLIER


static func for_card(card: CardData, mode: CardData.Mode) -> int:
	# Joker modifiers always count as collective (1x).
	var effective_mode: CardData.Mode = mode
	if card.family == CardData.Family.JOKER_MODIFIER:
		effective_mode = CardData.Mode.COLLECTIVE
	var heat: int = card.base_heat * mode_multiplier(effective_mode)
	if card.is_effect() and card.deals_direct_damage():
		heat += Config.DIRECT_DAMAGE_EFFECT_HEAT_BONUS
	return heat
