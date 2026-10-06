extends SceneTree
## Headless simulation runner (roadmap Phase 3).
##
##   godot --headless -s res://ai/simulate.gd -- [--matches=1000] [--players=4]
##       [--bots=greedy | --bots=greedy,random,greedy,random] [--seed=1]
##       [--json=path] [--csv=path]
##
## Plays N matches with consecutive seeds starting at --seed, prints the summary,
## and optionally writes the summary as JSON and one CSV row per match.


func _init() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var matches: int = int(args.get("matches", "1000"))
	var players: int = int(args.get("players", "4"))
	var first_seed: int = int(args.get("seed", "1"))
	var bot_names: Array[String] = []
	var bot_arg: PackedStringArray = String(args.get("bots", "greedy")).split(",")
	for seat: int in players:
		bot_names.append(bot_arg[seat % bot_arg.size()].strip_edges())

	var deck: Array[CardData] = Deck.build_card_list(CardCatalog.load_all())
	var results: Array[Dictionary] = []
	var started: int = Time.get_ticks_msec()
	for i: int in matches:
		var tc: TurnController = MatchRunner.play(first_seed + i, bot_names, deck)
		results.append(MatchStats.from_match(tc, bot_names))
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0

	var summary: Dictionary = SimulationReport.summarize(results)
	print(SimulationReport.to_text(summary))
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
