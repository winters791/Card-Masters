class_name Intents
extends RefCounted
## What players (UI or bots) can ask the core to do. The core validates and applies.


## Draw one card (draw step only; up to 3 per turn, not while holding 10).
class DrawCard extends Intent:
	func _init(p_seat: int) -> void:
		seat = p_seat


## Discard any card from your hand (draw step only; once per turn).
class DiscardCard extends Intent:
	var hand_index: int

	func _init(p_seat: int, p_hand_index: int) -> void:
		seat = p_seat
		hand_index = p_hand_index


## Play a card. The first play ends the draw step.
class PlayCard extends Intent:
	var hand_index: int
	var mode: CardData.Mode
	## Ignored for collective plays.
	var target_seat: int
	## An Element.Type for cards that ask for one (Convert, Shed Skin), otherwise -1.
	var chosen_element: int

	func _init(p_seat: int, p_hand_index: int, p_mode: CardData.Mode, p_target_seat: int = -1,
			p_chosen_element: int = -1) -> void:
		seat = p_seat
		hand_index = p_hand_index
		mode = p_mode
		target_seat = p_target_seat
		chosen_element = p_chosen_element


## Ends the turn. Ending without having played a card is a skip (+1 Heat).
class EndTurn extends Intent:
	func _init(p_seat: int) -> void:
		seat = p_seat


## The 2-minute turn timer ran out (§3). Ends the turn like EndTurn.
class Timeout extends Intent:
	func _init(p_seat: int) -> void:
		seat = p_seat
