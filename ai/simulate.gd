extends SceneTree
## Headless simulation runner (roadmap Phase 3).
##
##   godot --headless -s res://ai/simulate.gd -- [--matches=1000] [--players=4]
##       [--bots=greedy | --bots=greedy,random,greedy,random] [--seed=1]
##       [--json=path] [--csv=path]
##       [--set=NAME=value[,NAME=value...]] [--damage-scale=0.75] [--dot-scale=0.5]
##
## Plays N matches with consecutive seeds starting at --seed, prints the summary,
## and optionally writes the summary as JSON and one CSV row per match.
## Balance experiments (Phase 5) can override Config numbers for this run with
## --set (e.g. --set=STARTING_HP=150,JOKER_DAMAGE_PER_ROUND=15) and scale every
## card's direct damage with --damage-scale and every poison / burn tick with
## --dot-scale (rounded, at least 1).


func _init() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var matches: int = int(args.get("matches", "1000"))
	var players: int = int(args.get("players", "4"))
	var first_seed: int = int(args.get("seed", "1"))
	var bot_names: Array[String] = []
	var bot_arg: PackedStringArray = String(args.get("bots", "greedy")).split(",")
	for seat: int in players:
		bot_names.append(bot_arg[seat % bot_arg.size()].strip_edges())

	var tweaks: PackedStringArray = []
	for pair: String in String(args.get("set", "")).split(",", false):
		var parts: PackedStringArray = pair.split("=", true, 1)
		var error: String = Config.override(parts[0].strip_edges(), parts[1].strip_edges() if parts.size() > 1 else "")
		if not error.is_empty():
			push_error(error)
			quit(2)
			return
		tweaks.append(pair)
	var definitions: Array[CardData] = CardCatalog.load_all()
	if args.has("damage-scale"):
		var scale: float = float(args["damage-scale"])
		for card: CardData in definitions:
			if card.params.has("damage"):
				card.params["damage"] = maxi(1, roundi(int(card.params["damage"]) * scale))
		tweaks.append("damage x%s" % args["damage-scale"])
	if args.has("dot-scale"):
		var dot_scale: float = float(args["dot-scale"])
		for card: CardData in definitions:
			if card.params.has("tick_damage"):
				card.params["tick_damage"] = maxi(1, roundi(int(card.params["tick_damage"]) * dot_scale))
		tweaks.append("damage over time x%s" % args["dot-scale"])
	var deck: Array[CardData] = Deck.build_card_list(definitions)
	var results: Array[Dictionary] = []
	var started: int = Time.get_ticks_msec()
	for i: int in matches:
		var tc: TurnController = MatchRunner.play(first_seed + i, bot_names, deck)
		results.append(MatchStats.from_match(tc, bot_names))
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0

	var summary: Dictionary = SimulationReport.summarize(results)
	summary["tweaks"] = tweaks
	print(SimulationReport.to_text(summary))
	if not tweaks.is_empty():
		print("Balance tweaks: %s" % ", ".join(tweaks))
	print("\n(%d matches in %.1f s)" % [matches, seconds])
	if args.has("json"):
		_write(args["json"], JSON.stringify(summary, "  "))
	if args.has("csv"):
		_write(args["csv"], SimulationReport.to_csv(results))
	quit(0 if summary["unfinished"] == 0 else 1)


func _parse_args(raw: PackedStringArray) -> Dictionary:
	var args: Dictionary = {}
	for arg: String in raw:
		if arg.begins_with("--") and "=" in arg:
			var parts: PackedStringArray = arg.substr(2).split("=", true, 1)
			args[parts[0]] = parts[1]
	return args


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Can't write %s" % path)
		return
	file.store_string(text)
	print("Wrote %s" % path)
