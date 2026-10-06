class_name GreedyBot
extends Bot
## Simple heuristics, one decision at a time (roadmap Phase 3):
## - draws up to 3 cards, discarding its weakest card first if its hand is full;
## - scores every legal play and makes the best one if it beats ending the turn;
## - a play scores its damage (with type multipliers, so it exploits advantages and
##   goes collective when a target resists), plus a rough value for effects, minus
##   the risk of becoming the Joker's target from the Heat it costs.
## Values are deliberately rough; they only need to make sensible-looking matches.

## How sure the bot is that being hottest now means being hit at round end (others
## still get to act).
const HOT_RISK: float = 0.7
## Extra value for knocking a player out.
const KILL_BONUS: float = 30.0
## Damage the bot takes counts this much more than damage it deals.
const SELF_DAMAGE_WEIGHT: float = 1.5


func bot_name() -> String:
	return "greedy"


func choose(tc: TurnController) -> Intent:
	var state: GameState = tc.state
	var me: PlayerState = state.player(seat)
	if state.phase == GameState.Phase.DRAW:
		if tc.can_draw():
			return Intents.DrawCard.new(seat)
		if me.hand.size() >= Config.HAND_CAP and tc.can_discard() \
				and state.draws_this_turn < Config.MAX_DRAWS_PER_TURN:
			return Intents.DiscardCard.new(seat, _weakest_card(me.hand))

	var best: Intent = null
	# Ending the turn without a play is a skip and costs Heat; after a play it's free.
	var best_score: float = 0.0 if not state.slots_played.is_empty() else -_heat_risk(state, Config.SKIP_HEAT)
	for play: Intent in LegalMoves.plays(tc):
		var score: float = _score_play(state, play as Intents.PlayCard)
		if score > best_score:
			best_score = score
			best = play
	return best if best != null else Intents.EndTurn.new(seat)


# --- Scoring ---------------------------------------------------------------------

func _score_play(state: GameState, play: Intents.PlayCard) -> float:
	var card: CardData = state.player(seat).hand[play.hand_index]
	var targets: Array[int] = [play.target_seat]
	if play.mode == CardData.Mode.COLLECTIVE:
		targets = state.alive_seats()
	var heat: int = Heat.for_card(card, play.mode)
	# Trap Heat only lands if it fires, maybe much later.
	var heat_weight: float = 0.5 if card.family == CardData.Family.TRAP else 1.0
	var value: float = 0.0
	match card.family:
		CardData.Family.ATTACK:
			value = _damage_value(state, targets, int(card.params.get("damage", 0)), card.element)
		CardData.Family.DAMAGE_OVER_TIME:
			value = _per_target(state, targets, {&"venom": 12.0, &"scorch": 18.0, &"rot": 4.0}.get(card.id, 3.0))
		CardData.Family.TYPE_MANIPULATION:
			value = _type_value(state, card, play, targets)
		CardData.Family.DISRUPTION:
			value = _per_target(state, targets, 5.0)
		CardData.Family.HEAT_MANIPULATION:
			value = _heat_card_value(state, card, play)
		CardData.Family.JOKER_MODIFIER:
			value = _joker_card_value(state, card, heat)
		CardData.Family.TRAP:
			value = _trap_value(state, card)
	return value - heat_weight * _heat_risk(state, heat)


## Damage to opponents is good, damage to the bot is bad, knock-outs are great.
func _damage_value(state: GameState, targets: Array[int], base: int, element: Element.Type) -> float:
	var value: float = 0.0
	var weight: float = _opponent_weight(state)
	for target: int in targets:
		var p: PlayerState = state.player(target)
		var damage: int = TypeChart.apply(base, element, p.element)
		if target == seat:
			value -= damage * SELF_DAMAGE_WEIGHT
		else:
			value += damage * weight
			if damage >= p.hp:
				value += KILL_BONUS
	return value


## A flat value per opponent hit, negative for hitting the bot itself.
func _per_target(state: GameState, targets: Array[int], each: float) -> float:
	var value: float = 0.0
	for target: int in targets:
		value += -each * SELF_DAMAGE_WEIGHT if target == seat else each * _opponent_weight(state)
	return value


## In a free-for-all, hurting one opponent only helps against the rest of the field,
## so damage to each opponent is worth less the more opponents there are. This is
## what makes the bot play targeted by default and collective when the target resists.
func _opponent_weight(state: GameState) -> float:
	return minf(1.0, 2.0 / maxf(1.0, state.alive_seats().size() - 1.0))


func _type_value(state: GameState, card: CardData, play: Intents.PlayCard, targets: Array[int]) -> float:
	var joker_element: Element.Type = state.joker.element
	match card.id:
		&"shed_skin":
			# Damage with the new type, plus a bonus for resisting the Joker afterwards.
			var new_element := play.chosen_element as Element.Type
			var value: float = _damage_value(state, targets, int(card.params.get("damage", 0)), new_element)
			value += 8.0 * (1.0 - TypeChart.multiplier(joker_element, new_element))
			return value
		&"convert":
			# Make opponents weak to the Joker (and never ourselves).
			var value: float = 0.0
			for target: int in targets:
				var gain: float = TypeChart.multiplier(joker_element, play.chosen_element as Element.Type) \
						- TypeChart.multiplier(joker_element, state.player(target).element)
				value += -gain * 10.0 if target == seat else gain * 10.0
			return value
		&"type_swap":
			var mine: float = TypeChart.multiplier(joker_element, state.player(seat).element)
			var theirs: float = TypeChart.multiplier(joker_element, state.player(play.target_seat).element)
			return (mine - theirs) * 10.0
	return _per_target(state, targets, 3.0)


func _heat_card_value(state: GameState, card: CardData, play: Intents.PlayCard) -> float:
	match card.id:
		&"scapegoat":
			# Worth it if it pushes someone else above the bot.
			var their_heat: int = state.player(play.target_seat).heat + int(card.params.get("heat", 0))
			return 8.0 if their_heat > state.player(seat).heat + Heat.for_card(card, play.mode) else 1.0
	# Spotlight / Flashpoint: good when the bot is cold, bad when it is hot.
	return 4.0 if _hottest_others(state) > state.player(seat).heat else -4.0


## Joker cards: worth the Joker damage they steer away from the bot (or onto others).
func _joker_card_value(state: GameState, card: CardData, heat_cost: int) -> float:
	var damage: float = float(state.joker_damage())
	var my_heat: int = state.player(seat).heat + heat_cost
	var hottest_other: int = _hottest_others(state)
	var i_am_target: bool = my_heat >= hottest_other
	var params: Dictionary = card.params
	match StringName(params.get("modifier", "")):
		JokerModifier.STAND_DOWN:
			return damage if i_am_target else -2.0
		JokerModifier.WILD_CARD:
			var alive: float = float(state.alive_seats().size())
			return damage * (1.0 - 1.0 / alive) if i_am_target else -damage / alive
		JokerModifier.INVERT:
			return damage if i_am_target and my_heat > _coldest_others(state) else -damage
		JokerModifier.LOCK_ON:
			return damage * 0.5 if not i_am_target else -damage
		JokerModifier.CONE:
			return -damage if _rank(state, my_heat) < 3 else damage * 0.8
		JokerModifier.DOUBLE_TAP:
			return -damage if _rank(state, my_heat) < 2 else damage * 0.8
		JokerModifier.OVERCHARGE, JokerModifier.VENOM_FANG:
			return -damage if i_am_target else damage * 0.5
	if card.effect_id == &"joker_type":
		# Turn the Joker into a type that's strong against its likely target.
		var element := int(params.get("element", Element.Type.NORMAL)) as Element.Type
		var target: PlayerState = state.player(seat) if i_am_target else state.player(_hottest_other_seat(state))
		var gain: float = TypeChart.multiplier(element, target.element) - TypeChart.multiplier(state.joker.element, target.element)
		return -gain * damage if i_am_target else gain * damage
	return 0.0


func _trap_value(state: GameState, card: CardData) -> float:
	var i_am_target: bool = state.player(seat).heat >= _hottest_others(state)
	var damage: float = float(state.joker_damage())
	match card.id:
		&"joker_deflect", &"grudge":
			return damage * 0.6 if i_am_target else 2.0
		&"wellspring":
			return 3.0 if state.player(seat).element == Element.Type.WATER else 0.5
	return 3.0


# --- Heat risk -----------------------------------------------------------------------

## Expected extra Joker damage from gaining `heat` now: being (or becoming) the
## hottest player makes the round-end hit likely.
func _heat_risk(state: GameState, heat: int) -> float:
	var before: float = _hit_chance(state.player(seat).heat, _hottest_others(state))
	var after: float = _hit_chance(state.player(seat).heat + heat, _hottest_others(state))
	var mult: float = TypeChart.multiplier(state.joker.element, state.player(seat).element)
	return (after - before) * state.joker_damage() * mult + heat * 0.5


func _hit_chance(my_heat: int, hottest_other: int) -> float:
	if my_heat > hottest_other:
		return HOT_RISK
	if my_heat == hottest_other:
		return HOT_RISK * 0.8
	return 0.0


func _hottest_others(state: GameState) -> int:
	var hottest: int = 0
	for s: int in state.alive_seats():
		if s != seat:
			hottest = maxi(hottest, state.player(s).heat)
	return hottest


func _hottest_other_seat(state: GameState) -> int:
	var best: int = -1
	for s: int in state.alive_seats():
		if s != seat and (best < 0 or state.player(s).heat > state.player(best).heat):
			best = s
	return best


func _coldest_others(state: GameState) -> int:
	var coldest: int = 1 << 30
	for s: int in state.alive_seats():
		if s != seat:
			coldest = mini(coldest, state.player(s).heat)
	return coldest


## How many other players are strictly hotter than `my_heat` (0 = the bot is top).
func _rank(state: GameState, my_heat: int) -> int:
	var hotter: int = 0
	for s: int in state.alive_seats():
		if s != seat and state.player(s).heat > my_heat:
			hotter += 1
	return hotter


## The card the bot would miss least: the lowest damage, with traps and effects at 5.
func _weakest_card(hand: Array[CardData]) -> int:
	var weakest: int = 0
	var weakest_value: int = 1 << 30
	for i: int in hand.size():
		var value: int = int(hand[i].params.get("damage", 5))
		if value < weakest_value:
			weakest_value = value
			weakest = i
	return weakest
