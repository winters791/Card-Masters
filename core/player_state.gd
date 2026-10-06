class_name PlayerState
extends RefCounted

var seat: int
var hp: int = Config.STARTING_HP
var element: Element.Type = Element.Type.NORMAL
var heat: int = 0
var hand: Array[CardData] = []
var is_alive: bool = true
## Restrictions that apply to this player's next turn (e.g. &"no_discard" from
## Dry Well). Moved to GameState.turn_restrictions when that turn starts.
var next_turn_restrictions: Array[StringName] = []


func _init(p_seat: int) -> void:
	seat = p_seat
