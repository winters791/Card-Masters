class_name MatchRunner
extends RefCounted
## Plays whole matches between bots, headless.

## Safety net: a match that needs more intents than this is stopped and reported
## as stalled (it would mean a bot or rule loop, not a real game).
const MAX_INTENTS: int = 20000

const BOT_TYPES: Dictionary[String, GDScript] = {
	"random": preload("res://ai/random_bot.gd"),
	"greedy": preload("res://ai/greedy_bot.gd"),
}


static func make_bot(bot_name: String, seat: int, match_seed: int) -> Bot:
	assert(BOT_TYPES.has(bot_name), "Unknown bot %s" % bot_name)
	return BOT_TYPES[bot_name].new(seat, match_seed)


## One match with one bot per seat (bot_names[i] plays seat i). Pass the physical
## deck to reuse it across matches; by default the full first-batch deck is built.
static func play(match_seed: int, bot_names: Array[String], deck: Array[CardData] = []) -> TurnController:
	if deck.is_empty():
		deck = Deck.build_card_list(CardCatalog.load_all())
	var tc := TurnController.new(match_seed, bot_names.size(), deck)
	var bots: Array[Bot] = []
	for seat: int in bot_names.size():
		bots.append(make_bot(bot_names[seat], seat, match_seed))
	var steps: int = 0
	while not tc.state.is_over() and steps < MAX_INTENTS:
		steps += 1
		var seat: int = tc.state.current_seat
		var error: String = tc.submit(bots[seat].choose(tc))
		if not error.is_empty():
			push_error("%s bot in seat %d made an illegal move: %s" % [bot_names[seat], seat, error])
			tc.submit(Intents.EndTurn.new(seat))
	return tc
