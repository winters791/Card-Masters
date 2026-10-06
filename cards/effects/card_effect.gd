class_name CardEffect
extends RefCounted
## Base for card effect implementations. One small script per effect id; see
## EffectRegistry.


func resolve(_ctx: EffectContext) -> void:
	push_error("CardEffect.resolve not implemented for %s" % get_script().resource_path)
