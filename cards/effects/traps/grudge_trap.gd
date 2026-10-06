class_name GrudgeTrap
extends TrapEffect
## The covered player is hit by the Joker: the hottest other living player (everyone
## tied) takes the same damage, untyped.


func trigger() -> StringName:
	return TrapOccurrence.JOKER_HIT_LANDED


func fire(rules: TurnController, trap: PlacedTrap, occurrence: TrapOccurrence) -> void:
	var damage: int = int(occurrence.data.get("damage", 0))
	var max_heat: int = -1
	var hottest: Array[int] = []
	for seat: int in rules.state.alive_seats():
		if seat == occurrence.subject_seat:
			continue
		var heat: int = rules.state.player(seat).heat
		if heat > max_heat:
			max_heat = heat
			hottest = [seat]
		elif heat == max_heat:
			hottest.append(seat)
	for seat: int in hottest:
		rules.deal_damage(trap.owner_seat, seat, damage, Element.Type.NORMAL, &"trap")
