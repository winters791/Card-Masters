class_name PoisonEffect
extends CardEffect
## Venom: a poison stack of params.tick_damage per round for params.rounds rounds.


func resolve(ctx: EffectContext) -> void:
	var damage: int = int(ctx.card.params.get("tick_damage", 0))
	var rounds: int = int(ctx.card.params.get("rounds", 0))
	for target_seat: int in ctx.target_seats:
		ctx.rules.apply_poison(target_seat, damage, rounds, ctx.source_seat)
