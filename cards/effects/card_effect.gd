class_name CardEffect
extends RefCounted
## Base for card effect implementations. One small script per effect id; see
## EffectRegistry.


## Extra legality checks for this effect, e.g. a required type choice. "" if fine.
func validate_play(_state: GameState, _intent: Intents.PlayCard) -> String:
	return ""


func resolve(_ctx: EffectContext) -> void:
	push_error("CardEffect.resolve not implemented for %s" % get_script().resource_path)
