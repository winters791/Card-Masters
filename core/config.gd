class_name Config
extends RefCounted
## Every tunable number in the rules lives here. Balancing changes this file,
## not the rules code. Values follow docs/design.md.

# Players (§2)
const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 4
const STARTING_HP: int = 100

# Hand (§3)
const STARTING_HAND_SIZE: int = 7
const MAX_DRAWS_PER_TURN: int = 3
const MAX_DISCARDS_PER_TURN: int = 1
const HAND_CAP: int = 10

# Turn (§3)
const TURN_TIMER_SECONDS: float = 30.0

# Type chart multipliers (§2)
const STRONG_MULTIPLIER: float = 2.0
const RESISTED_MULTIPLIER: float = 0.5
const NEUTRAL_MULTIPLIER: float = 1.0

# Heat (§5)
const COLLECTIVE_HEAT_MULTIPLIER: int = 1
const TARGETED_HEAT_MULTIPLIER: int = 2
const DIRECT_DAMAGE_EFFECT_HEAT_BONUS: int = 1
const SKIP_HEAT: int = 1

# Damage over time and Rot (§8)
## Rot halves the resist bonus: 0.5x becomes 0.75x.
const ROT_RESIST_MULTIPLIER: float = 0.75

# Joker (§6): damage in round r = JOKER_BASE_DAMAGE + JOKER_DAMAGE_PER_ROUND * (r - 1)
const JOKER_BASE_DAMAGE: int = 10
const JOKER_DAMAGE_PER_ROUND: int = 10

# Deck (§3): physical copies of each card by rarity
const COPIES_BY_RARITY: Dictionary[CardData.Rarity, int] = {
	CardData.Rarity.COMMON: 4,
	CardData.Rarity.UNCOMMON: 3,
	CardData.Rarity.RARE: 2,
	CardData.Rarity.LEGENDARY: 1,
}
