extends GutHookScript
## Runs once before every GUT run (see .gutconfig.json).
##
## The rules tests were written against 100 HP, which keeps their arithmetic
## easy to read ("the Joker's round-10 hit of 100 knocks out a neutral player").
## The design default is 250 (balance pass 1, option B); test_config.gd checks
## that default through Config.default_value().


const TEST_HP: int = 100


func run() -> void:
	Config.override("STARTING_HP", str(TEST_HP))
