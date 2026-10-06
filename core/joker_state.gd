class_name JokerState
extends RefCounted
## The game host (§6): its type and its three modifier slots.

var element: Element.Type = Element.Type.NORMAL
## Targeting slot (Lock-On, Wild Card, Invert); null = hottest player.
var targeting: JokerModifier = null
## Pattern slot (Cone, Double Tap, Stand Down); null = one attack.
var pattern: JokerModifier = null
## Effect slot: stacks (Venom Fang, Overcharge).
var effects: Array[JokerModifier] = []


static func damage_for_round(round_number: int) -> int:
	return Config.JOKER_BASE_DAMAGE + Config.JOKER_DAMAGE_PER_ROUND * (round_number - 1)


func targeting_id() -> StringName:
	return targeting.id if targeting != null else &""


func pattern_id() -> StringName:
	return pattern.id if pattern != null else &""


func effects_with_id(modifier_id: StringName) -> Array[JokerModifier]:
	return effects.filter(func(m: JokerModifier) -> bool: return m.id == modifier_id)


## Extra damage this round from Overcharge (stacks).
func bonus_damage() -> int:
	var bonus: int = 0
	for m: JokerModifier in effects_with_id(JokerModifier.OVERCHARGE):
		bonus += int(m.params.get("bonus", 0))
	return bonus


func all_modifiers() -> Array[JokerModifier]:
	var all: Array[JokerModifier] = []
	if targeting != null:
		all.append(targeting)
	if pattern != null:
		all.append(pattern)
	all.append_array(effects)
	return all
