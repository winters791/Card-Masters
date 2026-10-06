class_name TypeChart
extends RefCounted
## Grass → Water → Fire → Grass (each beats the next); Normal is neutral (§2).

const _BEATS: Dictionary[Element.Type, Element.Type] = {
	Element.Type.GRASS: Element.Type.WATER,
	Element.Type.WATER: Element.Type.FIRE,
	Element.Type.FIRE: Element.Type.GRASS,
}


static func multiplier(attacker: Element.Type, defender: Element.Type) -> float:
	if _BEATS.get(attacker) == defender:
		return Config.STRONG_MULTIPLIER
	if _BEATS.get(defender) == attacker:
		return Config.RESISTED_MULTIPLIER
	return Config.NEUTRAL_MULTIPLIER


## Final damage of a typed hit.
# RULE-ASSUMPTION: fractional damage (e.g. 15 at 0.5x = 7.5) rounds down.
static func apply(base_damage: int, attacker: Element.Type, defender: Element.Type) -> int:
	return floori(base_damage * multiplier(attacker, defender))
