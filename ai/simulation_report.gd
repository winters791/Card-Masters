class_name SimulationReport
extends RefCounted
## Aggregates many MatchStats into the Phase 3 report: match length, eliminations
## and wins per seat, draw rate, Heat at the Joker attack, who does the killing,
## and how often each card is played.


static func summarize(matches: Array[Dictionary]) -> Dictionary:
	var total: int = matches.size()
	var seats: int = matches[0]["players"] if total > 0 else 0
	var rounds: Array[int] = []
	var wins: Array[int] = []
	wins.resize(seats)
	wins.fill(0)
	var elim_sum: Array[int] = []
	elim_sum.resize(seats)
	elim_sum.fill(0)
	var elim_count: Array[int] = []
	elim_count.resize(seats)
	elim_count.fill(0)
	var draws: int = 0
	var unfinished: int = 0
	var causes: Dictionary[String, int] = {}
	var plays: Dictionary[String, int] = {}
	var heat: Array[int] = []
	var skips: int = 0

	for m: Dictionary in matches:
		if not m["finished"]:
			unfinished += 1
			continue
		rounds.append(m["rounds"])
		if m["draw"]:
			draws += 1
		elif m["winner"] >= 0:
			wins[m["winner"]] += 1
		for seat: int in seats:
			var r: int = m["elimination_round"][seat]
			if r >= 0:
				elim_sum[seat] += r
				elim_count[seat] += 1
				var cause: String = m["elimination_cause"][seat]
				causes[cause] = causes.get(cause, 0) + 1
		for id: String in m["plays"]:
			plays[id] = plays.get(id, 0) + m["plays"][id]
		heat.append_array(m["heat_at_joker"])
		skips += m["skips"]

	var finished: int = rounds.size()
	rounds.sort()
	heat.sort()
	var win_rate: Array[float] = []
	var avg_elimination_round: Array[float] = []
	for seat: int in seats:
		win_rate.append(_ratio(wins[seat], finished))
		avg_elimination_round.append(_ratio(elim_sum[seat], elim_count[seat]))
	var plays_per_match: Dictionary[String, float] = {}
	for id: String in plays:
		plays_per_match[id] = _ratio(plays[id], finished)
	var total_kills: int = 0
	for cause: String in causes:
		total_kills += causes[cause]
	var kill_share: Dictionary[String, float] = {}
	for cause: String in causes:
		kill_share[cause] = _ratio(causes[cause], total_kills)

	return {
		"matches": total,
		"finished": finished,
		"unfinished": unfinished,
		"players": seats,
		"bots": matches[0]["bots"] if total > 0 else [],
		"rounds": {
			"mean": _mean(rounds), "median": _percentile(rounds, 0.5),
			"min": rounds.front() if finished > 0 else 0, "max": rounds.back() if finished > 0 else 0,
			"histogram": _histogram(rounds),
		},
		"draw_rate": _ratio(draws, finished),
		"win_rate_by_seat": win_rate,
		"avg_elimination_round_by_seat": avg_elimination_round,
		"kill_share_by_cause": kill_share,
		"heat_at_joker": {
			"mean": _mean(heat), "median": _percentile(heat, 0.5),
			"p90": _percentile(heat, 0.9), "max": heat.back() if not heat.is_empty() else 0,
		},
		"skips_per_match": _ratio(skips, finished),
		"plays_per_match": plays_per_match,
	}


static func to_text(summary: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("=== Card Masters simulation ===")
	lines.append("%d matches (%d finished, %d stalled), %d players, bots %s" % [
		summary["matches"], summary["finished"], summary["unfinished"], summary["players"], str(summary["bots"])])
	var r: Dictionary = summary["rounds"]
	lines.append("")
	lines.append("Match length (rounds): mean %.1f, median %d, min %d, max %d" % [r["mean"], r["median"], r["min"], r["max"]])
	for length: int in r["histogram"]:
		lines.append("  %3d rounds: %5d" % [length, r["histogram"][length]])
	lines.append("")
	lines.append("Draw rate: %.1f%%" % (summary["draw_rate"] * 100.0))
	lines.append("Win rate by seat:              %s" % _percent_list(summary["win_rate_by_seat"]))
	lines.append("Avg elimination round by seat: %s" % _number_list(summary["avg_elimination_round_by_seat"]))
	lines.append("")
	lines.append("Who eliminates players:")
	var kills: Dictionary = summary["kill_share_by_cause"]
	for cause: String in _sorted_by_value(kills):
		lines.append("  %-18s %5.1f%%" % [cause, kills[cause] * 100.0])
	var h: Dictionary = summary["heat_at_joker"]
	lines.append("")
	lines.append("Heat at the Joker attack: mean %.1f, median %d, p90 %d, max %d" % [h["mean"], h["median"], h["p90"], h["max"]])
	lines.append("Skips per match: %.1f" % summary["skips_per_match"])
	lines.append("")
	lines.append("Card plays per match:")
	var plays: Dictionary = summary["plays_per_match"]
	for id: String in _sorted_by_value(plays):
		lines.append("  %-18s %5.2f" % [id, plays[id]])
	return "\n".join(lines)


## One CSV row per match, for spreadsheets.
static func to_csv(matches: Array[Dictionary]) -> String:
	var lines: PackedStringArray = ["seed,players,bots,finished,rounds,winner,draw,skips,elimination_rounds,elimination_causes"]
	for m: Dictionary in matches:
		lines.append("%d,%d,%s,%s,%d,%d,%s,%d,%s,%s" % [
			m["seed"], m["players"], "|".join(m["bots"]), m["finished"], m["rounds"], m["winner"], m["draw"],
			m["skips"], "|".join(m["elimination_round"].map(func(x: int) -> String: return str(x))),
			"|".join(m["elimination_cause"])])
	return "\n".join(lines)


static func _ratio(part: int, whole: int) -> float:
	return float(part) / whole if whole > 0 else 0.0


static func _mean(values: Array[int]) -> float:
	var sum: int = 0
	for v: int in values:
		sum += v
	return _ratio(sum, values.size())


## `values` must be sorted.
static func _percentile(values: Array[int], fraction: float) -> int:
	if values.is_empty():
		return 0
	return values[clampi(int(fraction * (values.size() - 1)), 0, values.size() - 1)]


static func _histogram(values: Array[int]) -> Dictionary[int, int]:
	var histogram: Dictionary[int, int] = {}
	for v: int in values:
		histogram[v] = histogram.get(v, 0) + 1
	return histogram


static func _sorted_by_value(values: Dictionary) -> Array:
	var keys: Array = values.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return values[a] > values[b])
	return keys


static func _percent_list(values: Array) -> String:
	return "  ".join(values.map(func(v: float) -> String: return "%5.1f%%" % (v * 100.0)))


static func _number_list(values: Array) -> String:
	return "  ".join(values.map(func(v: float) -> String: return "%6.1f" % v))
