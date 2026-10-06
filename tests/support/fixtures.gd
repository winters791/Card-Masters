extends RefCounted
## Shared builders for rules tests. Not a test file (no test_ prefix).


static func attack(damage: int, element: Element.Type = Element.Type.NORMAL, base_heat: int = 1,
		mode_lock: CardData.ModeLock = CardData.ModeLock.NONE) -> CardData:
	var card := CardData.new()
	card.id = StringName("test_%s_%d" % [Element.type_name(element).to_lower(), damage])
	card.display_name = "Test %s %d" % [Element.type_name(element), damage]
	card.family = CardData.Family.ATTACK
	card.element = element
	card.base_heat = base_heat
	card.mode_lock = mode_lock
	card.effect_id = &"attack"
	card.params = {"damage": damage}
	return card


## A deck of `count` identical harmless cards, so tests control every hand explicitly.
static func filler_deck(count: int = 80) -> Array[CardData]:
	var dud: CardData = attack(0)
	dud.id = &"test_dud"
	var cards: Array[CardData] = []
	for i: int in count:
		cards.append(dud)
	return cards


## A match with an unshuffled filler deck. Seat 0 is up and must choose what to keep.
static func new_match(player_count: int = 2, deck: Array[CardData] = filler_deck()) -> TurnController:
	return TurnController.new(1, player_count, deck, false)


## Keeps the first allowed drawn cards for the current player.
static func keep_first(tc: TurnController) -> String:
	var indices: Array[int] = []
	for i: int in tc.keep_count():
		indices.append(i)
	return tc.submit(Intents.KeepCards.new(tc.state.current_seat, indices))


## Puts `card` at the front of the current player's hand (index 0).
static func give(tc: TurnController, seat: int, card: CardData) -> void:
	tc.state.player(seat).hand.push_front(card)


## The current player keeps the default cards and ends the turn without playing (a skip).
static func skip_turn(tc: TurnController) -> void:
	if tc.state.phase == GameState.Phase.KEEP:
		keep_first(tc)
	tc.submit(Intents.EndTurn.new(tc.state.current_seat))


## Plays `card` from the current player, at `target_seat` (or collectively if -1), then ends the turn.
static func play_and_end(tc: TurnController, card: CardData, target_seat: int = -1) -> String:
	var seat: int = tc.state.current_seat
	if tc.state.phase == GameState.Phase.KEEP:
		keep_first(tc)
	give(tc, seat, card)
	var mode: CardData.Mode = CardData.Mode.COLLECTIVE if target_seat < 0 else CardData.Mode.TARGETED
	var error: String = tc.submit(Intents.PlayCard.new(seat, 0, mode, target_seat))
	if not error.is_empty() or tc.state.is_over() or tc.state.current_seat != seat:
		return error
	return tc.submit(Intents.EndTurn.new(seat))


static func events_of(tc: TurnController, event_class: Variant) -> Array[GameEvent]:
	var found: Array[GameEvent] = []
	for event: GameEvent in tc.state.events:
		if is_instance_of(event, event_class):
			found.append(event)
	return found
