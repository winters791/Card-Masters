class_name EffectRegistry
extends RefCounted
## Maps CardData.effect_id to its implementation. Add new effects here.

const _EFFECTS: Dictionary[StringName, GDScript] = {
	&"attack": preload("res://cards/effects/attack_effect.gd"),
	&"restrict_next_turn": preload("res://cards/effects/restrict_next_turn_effect.gd"),
	&"poison": preload("res://cards/effects/poison_effect.gd"),
	&"burn": preload("res://cards/effects/burn_effect.gd"),
	&"rot": preload("res://cards/effects/rot_effect.gd"),
	&"type_swap": preload("res://cards/effects/type_swap_effect.gd"),
	&"convert": preload("res://cards/effects/convert_effect.gd"),
	&"rooted": preload("res://cards/effects/rooted_effect.gd"),
	&"shed_skin": preload("res://cards/effects/shed_skin_effect.gd"),
	&"joker_modifier": preload("res://cards/effects/joker_modifier_effect.gd"),
	&"joker_type": preload("res://cards/effects/joker_type_effect.gd"),
	&"trap_poison_to_healing": preload("res://cards/effects/traps/poison_to_healing_trap.gd"),
	&"trap_joker_deflect": preload("res://cards/effects/traps/joker_deflect_trap.gd"),
	&"trap_backfire": preload("res://cards/effects/traps/backfire_trap.gd"),
	&"trap_tripwire": preload("res://cards/effects/traps/tripwire_trap.gd"),
	&"trap_type_snare": preload("res://cards/effects/traps/type_snare_trap.gd"),
	&"trap_grudge": preload("res://cards/effects/traps/grudge_trap.gd"),
	&"trap_wellspring": preload("res://cards/effects/traps/wellspring_trap.gd"),
}


static func has_effect(effect_id: StringName) -> bool:
	return _EFFECTS.has(effect_id)


static func get_effect(effect_id: StringName) -> CardEffect:
	assert(_EFFECTS.has(effect_id), "Unknown effect id: %s" % effect_id)
	return _EFFECTS[effect_id].new()
