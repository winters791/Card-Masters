class_name CardCatalog
extends RefCounted
## Loads every card definition from res://cards/data/.

const DATA_DIR: String = "res://cards/data/"


## All card definitions, sorted by id so deck order never depends on the file system.
static func load_all() -> Array[CardData]:
	var cards: Array[CardData] = []
	for file_name: String in ResourceLoader.list_directory(DATA_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var card: CardData = load(DATA_DIR + file_name) as CardData
		assert(card != null, "%s is not a CardData resource" % file_name)
		cards.append(card)
	cards.sort_custom(_id_less_than)
	return cards


static func by_id(id: StringName) -> CardData:
	for card: CardData in load_all():
		if card.id == id:
			return card
	return null


static func _id_less_than(a: CardData, b: CardData) -> bool:
	return String(a.id) < String(b.id)
