class_name Intents
extends RefCounted
## What players (UI or bots) can ask the core to do. The core validates and applies.


## Choose which of the freshly drawn cards to keep; the rest are discarded.
class KeepCards extends Intent:
	## Indices into GameState.pending_draw.
	var keep_indices: Array[int]

	func _init(p_seat: int, p_keep_indices: Array[int]) -> void:
		seat = p_seat
		keep_indices = p_keep_indices


class PlayCard extends Intent:
	var hand_index: int
	var mode: CardData.Mode
	## Ignored for collective plays.
	var target_seat: int

	func _init(p_seat: int, p_hand_index: int, p_mode: CardData.Mode, p_target_seat: int = -1) -> void:
		seat = p_seat
		hand_index = p_hand_index
		mode = p_mode
		target_seat = p_target_seat


## Ends the turn. Ending without having played a card is a skip (+1 Heat).
class EndTurn extends Intent:
	func _init(p_seat: int) -> void:
		seat = p_seat


## The 30-second turn timer ran out (§3).
class Timeout extends Intent:
	func _init(p_seat: int) -> void:
		seat = p_seat
