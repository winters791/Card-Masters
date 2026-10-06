class_name JokerState
extends RefCounted
## The game host (§6). Modifier slots arrive in Phase 2.

var element: Element.Type = Element.Type.NORMAL


static func damage_for_round(round_number: int) -> int:
	return Config.JOKER_BASE_DAMAGE + Config.JOKER_DAMAGE_PER_ROUND * (round_number - 1)
