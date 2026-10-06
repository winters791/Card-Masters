class_name JokerModifier
extends RefCounted
## One active Joker modifier (§6). Targeting and pattern modifiers replace the one in
## their slot; effect modifiers stack.

enum Slot { TARGETING, PATTERN, EFFECT }

const CONE: StringName = &"cone"
const DOUBLE_TAP: StringName = &"double_tap"
const STAND_DOWN: StringName = &"stand_down"
const LOCK_ON: StringName = &"lock_on"
const WILD_CARD: StringName = &"wild_card"
const INVERT: StringName = &"invert"
const VENOM_FANG: StringName = &"venom_fang"
const OVERCHARGE: StringName = &"overcharge"

## id: [slot, lasts only this round]. "This round" cards clear after the round's
## Joker attack; the others stay until replaced.
const DEFINITIONS: Dictionary[StringName, Array] = {
	CONE: [Slot.PATTERN, true],
	DOUBLE_TAP: [Slot.PATTERN, false],
	STAND_DOWN: [Slot.PATTERN, true],
	LOCK_ON: [Slot.TARGETING, false],
	WILD_CARD: [Slot.TARGETING, true],
	INVERT: [Slot.TARGETING, false],
	VENOM_FANG: [Slot.EFFECT, false],
	OVERCHARGE: [Slot.EFFECT, true],
}

var id: StringName
var slot: Slot
var one_round: bool
var source_seat: int
## Card parameters, e.g. Overcharge's bonus or Venom Fang's poison.
var params: Dictionary
## Lock-On only: the seats locked onto when it was played.
var locked_seats: Array[int] = []


func _init(p_id: StringName, p_source_seat: int, p_params: Dictionary = {}) -> void:
	assert(DEFINITIONS.has(p_id), "Unknown Joker modifier %s" % p_id)
	id = p_id
	slot = DEFINITIONS[p_id][0]
	one_round = DEFINITIONS[p_id][1]
	source_seat = p_source_seat
	params = p_params


static func is_known(modifier_id: StringName) -> bool:
	return DEFINITIONS.has(modifier_id)
