class_name EffectContext
extends RefCounted
## Everything an effect needs to resolve one played card.

var rules: TurnController
var state: GameState
var card: CardData
var source_seat: int
var mode: CardData.Mode
## Who the card hits: the chosen target, or every living player (including the
## source) for collective plays.
var target_seats: Array[int]
## Element.Type picked by the player for Convert / Shed Skin, otherwise -1.
var chosen_element: int = -1


func _init(p_rules: TurnController, p_card: CardData, p_source_seat: int,
		p_mode: CardData.Mode, p_target_seats: Array[int], p_chosen_element: int = -1) -> void:
	chosen_element = p_chosen_element
	rules = p_rules
	state = p_rules.state
	card = p_card
	source_seat = p_source_seat
	mode = p_mode
	target_seats = p_target_seats
