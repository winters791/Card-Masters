class_name DotStack
extends RefCounted
## One stack of damage over time (a poison or a burn) on a player.

## Rounds left for stacks that never expire on their own (burns).
const UNTIL_REMOVED: int = -1

var damage: int
var rounds_left: int
## Who applied it (for the event log and stats).
var source_seat: int


func _init(p_damage: int, p_rounds_left: int, p_source_seat: int) -> void:
	damage = p_damage
	rounds_left = p_rounds_left
	source_seat = p_source_seat
