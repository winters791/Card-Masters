class_name Bot
extends RefCounted
## A computer player. Bots see what their seat may see: public state plus their own
## hand (they read GameState directly, but only those parts).

var seat: int
## The bot's own randomness, separate from the match RNG so bots never change what
## the deck does. Seeded from the match seed and seat, so matches stay replayable.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_seat: int, match_seed: int) -> void:
	seat = p_seat
	rng.seed = hash([match_seed, p_seat, bot_name()])


func bot_name() -> String:
	return "bot"


## The next intent for this bot's turn. Must be legal.
func choose(_tc: TurnController) -> Intent:
	return null
