extends Control
## Switches between the setup screen and a match.

var _screen: Control


func _ready() -> void:
	show_setup()


func show_setup() -> void:
	var setup := SetupScreen.new()
	setup.start_requested.connect(start_match)
	_swap(setup)


func start_match(seat_kinds: Array[String], match_seed: int) -> void:
	var screen := MatchScreen.new()
	screen.back_to_setup.connect(show_setup)
	_swap(screen)
	screen.start_match(seat_kinds, match_seed)


func _swap(screen: Control) -> void:
	if _screen != null:
		_screen.queue_free()
	_screen = screen
	add_child(screen)
