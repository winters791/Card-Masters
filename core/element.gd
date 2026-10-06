class_name Element
extends RefCounted
## The four types (§2). Called "Element" in code to avoid clashing with GDScript's
## own notion of types.

enum Type { NORMAL, GRASS, WATER, FIRE }


static func type_name(type: Type) -> String:
	return Type.keys()[type].capitalize()
