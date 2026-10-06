class_name AttackEffect
extends CardEffect
## Pure typed damage: params.damage of the card's element to every target.


func resolve(ctx: EffectContext) -> void:
	var damage: int = int(ctx.card.params.get("damage", 0))
	for target_seat: int in ctx.target_seats:
		ctx.rules.deal_damage(ctx.source_seat, target_seat, damage, ctx.card.element)
