class_name TrapOccurrence
extends RefCounted
## Something traps can react to. The rules engine builds one at each trigger point,
## lets matching traps fire, then reads back what they changed.

const POISON_APPLIED: StringName = &"poison_applied"
const JOKER_HIT: StringName = &"joker_hit"
const JOKER_HIT_LANDED: StringName = &"joker_hit_landed"
const TARGETED_PLAY: StringName = &"targeted_play"
const COLLECTIVE_PLAY: StringName = &"collective_play"
const TYPE_CHANGED: StringName = &"type_changed"

var trigger: StringName
## The player it happens to (traps on that player, or in the pool, can fire).
var subject_seat: int
## Who caused it (card player, poison source, GameEvent.JOKER_SEAT...).
var actor_seat: int
## The card involved, if any.
var card: CardData
## Trigger-specific data, e.g. {"damage": 5, "rounds": 3} for poison.
var data: Dictionary

## Set by interceptors: the original effect doesn't happen (Poison to Healing).
var cancelled: bool = false
## Set by interceptors: who it happens to instead (Backfire, Joker Deflect), or -1.
var redirect_seat: int = -1


func _init(p_trigger: StringName, p_subject_seat: int, p_actor_seat: int, p_card: CardData = null,
		p_data: Dictionary = {}) -> void:
	trigger = p_trigger
	subject_seat = p_subject_seat
	actor_seat = p_actor_seat
	card = p_card
	data = p_data
