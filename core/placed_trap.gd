class_name PlacedTrap
extends RefCounted
## A trap waiting on the table (§4). Everyone sees where it is; only its owner knows
## what it is until it fires.

## Host seat for traps in the collective pool.
const POOL: int = -1

var trap_id: int
var card: CardData
var owner_seat: int
## The player it watches, or POOL (watches everyone).
var host_seat: int
## Placement mode, for the Heat that lands when it fires (pool 1x, on a player 2x).
var mode: CardData.Mode


func _init(p_trap_id: int, p_card: CardData, p_owner_seat: int, p_host_seat: int, p_mode: CardData.Mode) -> void:
	trap_id = p_trap_id
	card = p_card
	owner_seat = p_owner_seat
	host_seat = p_host_seat
	mode = p_mode
