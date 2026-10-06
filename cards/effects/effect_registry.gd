class_name EffectRegistry
extends RefCounted
## Maps CardData.effect_id to its implementation. Add new effects here.

const _EFFECTS: Dictionary[StringName, GDScript] = {
	&"attack": preload("res://cards/effects/attack_effect.gd"),
}


static func has_effect(effect_id: StringName) -> bool:
	return _EFFECTS.has(effect_id)


static func get_effect(effect_id: StringName) -> CardEffect:
	assert(_EFFECTS.has(effect_id), "Unknown effect id: %s" % effect_id)
	return _EFFECTS[effect_id].new()
