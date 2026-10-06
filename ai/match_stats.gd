class_name MatchStats
extends RefCounted
## Facts about one finished match, read from its event log.


static func from_match(tc: TurnController, bot_names: Array[String]) -> Dictionary:
	var state: GameState = tc.state
	var count: int = state.players.size()
	var elimination_round: Array[int] = []
	elimination_round.resize(count)
	elimination_round.fill(-1)
	var elimination_cause: Array[String] = []
	elimination_cause.resize(count)
	elimination_cause.fill("")
	var plays: Dictionary[String, int] = {}
	var heat_at_joker: Array[int] = []
	var skips: int = 0

	# Replayed while reading the log: current Heat and the cause of the last hit per seat.
	var heat: Array[int] = []
	heat.resize(count)
	heat.fill(0)
	var last_hit_cause: Array[String] = []
	last_hit_cause.resize(count)
	last_hit_cause.fill("")
	var alive: Array[bool] = []
	alive.resize(count)
	alive.fill(true)

	for event: GameEvent in state.events:
		if event is GameEvents.HeatChanged:
			var e := event as GameEvents.HeatChanged
			heat[e.seat] = e.new_heat
		elif event is GameEvents.DamageDealt:
			var e := event as GameEvents.DamageDealt
			last_hit_cause[e.target_seat] = _cause_group(e.cause)
		elif event is GameEvents.PlayerEliminated:
			var e := event as GameEvents.PlayerEliminated
			alive[e.seat] = false
			elimination_round[e.seat] = e.round_number
			elimination_cause[e.seat] = last_hit_cause[e.seat]
		elif event is GameEvents.CardPlayed:
			var id: String = String((event as GameEvents.CardPlayed).card.id)
			plays[id] = plays.get(id, 0) + 1
		elif event is GameEvents.TrapPlaced:
			var id: String = String((event as GameEvents.TrapPlaced).card.id)
			plays[id] = plays.get(id, 0) + 1
		elif event is GameEvents.PlayerSkipped:
			skips += 1
		elif (event is GameEvents.JokerAttacked and (event as GameEvents.JokerAttacked).attack_number == 1) \
				or event is GameEvents.JokerStoodDown:
			for seat: int in count:
				if alive[seat]:
					heat_at_joker.append(heat[seat])

	return {
		"seed": state.match_seed,
		"players": count,
		"bots": bot_names,
		"finished": state.is_over(),
		"rounds": state.round_number,
		"winner": state.winner_seat,
		"draw": state.is_draw,
		"elimination_round": elimination_round,
		"elimination_cause": elimination_cause,
		"plays": plays,
		"skips": skips,
		"heat_at_joker": heat_at_joker,
	}


## Groups damage causes for the "who does the killing" report.
static func _cause_group(cause: StringName) -> String:
	match cause:
		&"card":
			return "card"
		&"joker":
			return "joker"
		Status.POISON, Status.BURN:
			return "damage over time"
		&"trap":
			return "trap"
	return String(cause)
