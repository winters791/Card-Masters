class_name RandomBot
extends Bot
## Picks uniformly among every legal move (drawing, discarding, playing, ending).


func bot_name() -> String:
	return "random"


func choose(tc: TurnController) -> Intent:
	var moves: Array[Intent] = LegalMoves.for_current_player(tc)
	return moves[rng.randi_range(0, moves.size() - 1)]
