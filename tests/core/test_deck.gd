extends GutTest

const Fixtures := preload("res://tests/support/fixtures.gd")


func _numbered_cards(count: int) -> Array[CardData]:
	var cards: Array[CardData] = []
	for i: int in count:
		var card: CardData = Fixtures.attack(i)
		cards.append(card)
	return cards


func _ids(cards: Array[CardData]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: CardData in cards:
		ids.append(card.id)
	return ids


func test_build_card_list_uses_copies_by_rarity() -> void:
	var common: CardData = Fixtures.attack(1)
	var uncommon: CardData = Fixtures.attack(2)
	uncommon.rarity = CardData.Rarity.UNCOMMON
	var rare: CardData = Fixtures.attack(3)
	rare.rarity = CardData.Rarity.RARE
	var legendary: CardData = Fixtures.attack(4)
	legendary.rarity = CardData.Rarity.LEGENDARY
	var cards: Array[CardData] = Deck.build_card_list([common, uncommon, rare, legendary])
	assert_eq(cards.count(common), 4)
	assert_eq(cards.count(uncommon), 3)
	assert_eq(cards.count(rare), 2)
	assert_eq(cards.count(legendary), 1)


func test_same_seed_shuffles_the_same_way() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 42
	var b := RandomNumberGenerator.new()
	b.seed = 42
	var deck_a := Deck.new(a, _numbered_cards(30))
	var deck_b := Deck.new(b, _numbered_cards(30))
	deck_a.shuffle()
	deck_b.shuffle()
	assert_eq(_ids(deck_a.draw_pile), _ids(deck_b.draw_pile))


func test_different_seeds_shuffle_differently() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 1
	var b := RandomNumberGenerator.new()
	b.seed = 2
	var deck_a := Deck.new(a, _numbered_cards(30))
	var deck_b := Deck.new(b, _numbered_cards(30))
	deck_a.shuffle()
	deck_b.shuffle()
	assert_ne(_ids(deck_a.draw_pile), _ids(deck_b.draw_pile))


func test_draw_takes_from_the_top() -> void:
	var cards: Array[CardData] = _numbered_cards(5)
	var deck := Deck.new(RandomNumberGenerator.new(), cards)
	var drawn: Array[CardData] = deck.draw(2)
	assert_eq(_ids(drawn), _ids(cards.slice(0, 2)))
	assert_eq(deck.draw_pile.size(), 3)


func test_reshuffles_discard_pile_when_empty() -> void:
	var deck := Deck.new(RandomNumberGenerator.new(), _numbered_cards(2))
	deck.discard(_numbered_cards(5))
	var drawn: Array[CardData] = deck.draw(4)
	assert_eq(drawn.size(), 4)
	assert_eq(deck.discard_pile.size(), 0)
	assert_eq(deck.draw_pile.size(), 3)
	assert_eq(deck.reshuffle_count, 1)
	assert_eq(deck.last_reshuffle_size, 5)


func test_draw_returns_fewer_when_both_piles_are_empty() -> void:
	var deck := Deck.new(RandomNumberGenerator.new(), _numbered_cards(1))
	assert_eq(deck.draw(3).size(), 1)
	assert_eq(deck.draw(3).size(), 0)
