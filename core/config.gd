class_name Config
extends RefCounted
## Every tunable number in the rules lives here. Balancing changes this file,
## not the rules code. Values follow docs/design.md.
##
## The balance dials are static vars, not consts, so the simulator can try other
## values for one run (`--set=NAME=value`, see override()). The game itself always
## uses the values written here.

# Players (§2)
const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 4
static var STARTING_HP: int = 100
## Healing never takes a player above this.
static var MAX_HP: int = 100

# Hand (§3)
static var STARTING_HAND_SIZE: int = 7
static var MAX_DRAWS_PER_TURN: int = 3
static var MAX_DISCARDS_PER_TURN: int = 1
static var HAND_CAP: int = 10

# Turn (§3)
static var TURN_TIMER_SECONDS: float = 120.0

# Type chart multipliers (§2)
static var STRONG_MULTIPLIER: float = 2.0
static var RESISTED_MULTIPLIER: float = 0.5
static var NEUTRAL_MULTIPLIER: float = 1.0

# Heat (§5)
static var COLLECTIVE_HEAT_MULTIPLIER: int = 1
static var TARGETED_HEAT_MULTIPLIER: int = 2
static var DIRECT_DAMAGE_EFFECT_HEAT_BONUS: int = 1
static var SKIP_HEAT: int = 1

# Damage over time and Rot (§8)
## Rot halves the resist bonus: 0.5x becomes 0.75x.
static var ROT_RESIST_MULTIPLIER: float = 0.75

# Joker (§6): damage in round r = JOKER_BASE_DAMAGE + JOKER_DAMAGE_PER_ROUND * (r - 1)
static var JOKER_BASE_DAMAGE: int = 10
static var JOKER_DAMAGE_PER_ROUND: int = 10

# Deck (§3): physical copies of each card by rarity
static var COPIES_BY_RARITY: Dictionary[CardData.Rarity, int] = {
	CardData.Rarity.COMMON: 4,
	CardData.Rarity.UNCOMMON: 3,
	CardData.Rarity.RARE: 2,
	CardData.Rarity.LEGENDARY: 1,
}

## Settings a balance experiment may override.
const TUNABLE: Array[String] = [
	"STARTING_HP", "STARTING_HAND_SIZE", "MAX_DRAWS_PER_TURN", "MAX_DISCARDS_PER_TURN", "HAND_CAP",
	"STRONG_MULTIPLIER", "RESISTED_MULTIPLIER", "COLLECTIVE_HEAT_MULTIPLIER", "TARGETED_HEAT_MULTIPLIER",
	"DIRECT_DAMAGE_EFFECT_HEAT_BONUS", "SKIP_HEAT", "ROT_RESIST_MULTIPLIER",
	"JOKER_BASE_DAMAGE", "JOKER_DAMAGE_PER_ROUND",
	"COPIES_COMMON", "COPIES_UNCOMMON", "COPIES_RARE", "COPIES_LEGENDARY",
]


## Overrides one setting for the rest of this process (balance experiments only).
## STARTING_HP also moves the healing cap; COPIES_<RARITY> sets copies per card.
## Returns "" or why the override was refused.
static func override(setting: String, value: String) -> String:
	if not TUNABLE.has(setting):
		return "Unknown or fixed setting: %s" % setting
	if setting.begins_with("COPIES_"):
		var rarity: String = setting.trim_prefix("COPIES_")
		COPIES_BY_RARITY[CardData.Rarity[rarity]] = int(value)
		return ""
	var script: GDScript = load("res://core/config.gd")
	match typeof(script.get(setting)):
		TYPE_INT:
			script.set(setting, int(value))
		TYPE_FLOAT:
			script.set(setting, float(value))
	if setting == "STARTING_HP":
		MAX_HP = int(value)
	return ""
