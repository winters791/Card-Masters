class_name GameEvent
extends RefCounted
## Base class for everything the core reports. Concrete events live in GameEvents.

## Seat used as the damage source when the Joker hits.
const JOKER_SEAT: int = -1


## The version of this event that `viewer_seat` may see. Override in events that
## carry hidden information.
func view_for(_viewer_seat: int) -> GameEvent:
	return self


## Human-readable line for logs and debugging.
func describe() -> String:
	return get_script().get_global_name()
