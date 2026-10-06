class_name Deck
extends RefCounted
## The one shared deck (§3). draw_pile[0] is the top card.

var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
## How many times the discard pile has been reshuffled in; lets the rules engine
## report reshuffles without the deck knowing about events.
var reshuffle_count: int = 0
## Size of the draw pile right after the latest reshuffle.
var last_reshuffle_size: int = 0
var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator, cards: Array[CardData] = []) -> void:
	_rng = rng
	draw_pile = cards.duplicate()


## One physical copy per Config.COPIES_BY_RARITY for each card definition.
static func build_card_list(definitions: Array[CardData]) -> Array[CardData]:
	var cards: Array[CardData] = []
	for definition: CardData in definitions:
		for i: int in Config.COPIES_BY_RARITY[definition.rarity]:
			cards.append(definition)
	return cards


func shuffle() -> void:
	_shuffle_in_place(draw_pile)


## Draws up to count cards, reshuffling the discard pile into the draw pile when it
## runs out. Returns fewer cards only if both piles are empty.
func draw(count: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	while drawn.size() < count:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			_reshuffle_discard()
		drawn.append(draw_pile.pop_front())
	return drawn


func discard(cards: Array[CardData]) -> void:
	discard_pile.append_array(cards)


func _reshuffle_discard() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	_shuffle_in_place(draw_pile)
	reshuffle_count += 1
	last_reshuffle_size = draw_pile.size()


# Fisher–Yates with the match RNG; Array.shuffle() uses the global RNG and would
# break determinism.
func _shuffle_in_place(cards: Array[CardData]) -> void:
	for i: int in range(cards.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: CardData = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
