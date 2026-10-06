class_name CardData
extends Resource
## One card definition. Each card is a .tres in res://cards/data/; the deck holds
## several references to the same CardData (copies by rarity).

enum Family {
	ATTACK,
	DAMAGE_OVER_TIME,
	TYPE_MANIPULATION,
	DISRUPTION,
	HEAT_MANIPULATION,
	JOKER_MODIFIER,
	TRAP,
}

enum Slot { ONE = 1, TWO = 2 }
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }
enum Mode { COLLECTIVE, TARGETED }
enum ModeLock { NONE, COLLECTIVE_ONLY, TARGETED_ONLY }

@export var id: StringName
@export var display_name: String
@export var family: Family = Family.ATTACK
@export var element: Element.Type = Element.Type.NORMAL
@export var base_heat: int = 1
@export var rarity: Rarity = Rarity.COMMON
@export var mode_lock: ModeLock = ModeLock.NONE
## Key into EffectRegistry.
@export var effect_id: StringName = &"attack"
## Effect parameters, e.g. {"damage": 20}.
@export var params: Dictionary = {}
@export_multiline var rules_text: String


## Slot 1 = trap or Joker modifier, slot 2 = attack or effect (§3).
func slot() -> Slot:
	if family == Family.TRAP or family == Family.JOKER_MODIFIER:
		return Slot.ONE
	return Slot.TWO


func is_effect() -> bool:
	return slot() == Slot.TWO and family != Family.ATTACK


func deals_direct_damage() -> bool:
	return int(params.get("damage", 0)) > 0


func allows_mode(mode: Mode) -> bool:
	match mode_lock:
		ModeLock.COLLECTIVE_ONLY:
			return mode == Mode.COLLECTIVE
		ModeLock.TARGETED_ONLY:
			return mode == Mode.TARGETED
	return true
