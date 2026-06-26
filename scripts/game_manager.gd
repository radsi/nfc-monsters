extends Node

const SAVE_PATH := "user://playerdata.cfg"

const DEFAULT_COINS := 0
const DEFAULT_XP := 0
const DEFAULT_HP := [100.0, 100.0]

const DEFAULT_SPELLS: Array[String] = [
	"SpellHit",
	"SpellDefend"
]
const DEFAULT_UNLOCKED_ITEMS := [
	0,
	2,
	5,
	10,
	13
]

var config := ConfigFile.new()

var previous_scenes: Array[String] = []
var card_to_view := {
	"name": ""
}

var coins: int = DEFAULT_COINS
var pending_unlocks: Array = []

var coming_back_from_game := false

func _ready() -> void:
	config.load(SAVE_PATH)

	coins = config.get_value("player", "coins", DEFAULT_COINS)

	if not config.has_section_key("player", "spells_unlocked"):
		config.set_value("player", "spells_unlocked", DEFAULT_SPELLS)

	if not config.has_section_key("player", "unlocked_items"):
		config.set_value("player", "unlocked_items", DEFAULT_UNLOCKED_ITEMS)

func _save() -> void:
	config.save(SAVE_PATH)

func change_scene(path: String) -> void:
	if NfcUsage.nfc_plugin:
		NfcUsage.stop_reading()

	previous_scenes.append(
		get_tree().current_scene.scene_file_path
	)

	get_tree().change_scene_to_file(path)

func return_scene() -> void:
	if previous_scenes.is_empty():
		return

	get_tree().change_scene_to_file(
		previous_scenes.pop_back()
	)

func add_coins(amount: int) -> void:
	coins += amount

	config.set_value(
		"player",
		"coins",
		coins
	)
	
	if get_tree().current_scene.name == "Game": get_tree().current_scene._update_coins()

func upgrade_card(card: String, level: int) -> void:
	config.set_value(
		"player",
		"card_" + card,
		level
	)

func get_card_upgrade_level(card: String) -> int:
	return config.get_value(
		"player",
		"card_" + card,
		0
	)

func unlock_spell(spell_id: String) -> void:
	var spells := get_unlocked_spells()

	if spells.has(spell_id):
		return

	spells.append(spell_id)

	config.set_value(
		"player",
		"spells_unlocked",
		spells
	)

	pending_unlocks.append(spell_id)

func has_unlocked_spell(spell_id: String) -> bool:
	return get_unlocked_spells().has(spell_id)

func get_unlocked_spells() -> Array[String]:
	var result: Array[String] = []

	for spell in config.get_value(
		"player",
		"spells_unlocked",
		DEFAULT_SPELLS
	):
		result.append(str(spell))

	return result

func save_player_xp(xp: int) -> void:
	config.set_value(
		"player",
		"xp",
		xp
	)

func get_player_xp() -> int:
	return config.get_value(
		"player",
		"xp",
		DEFAULT_XP
	)

func save_player_health(hp: float, max_hp: float) -> void:
	config.set_value(
		"player",
		"hp",
		[hp, max_hp]
	)

func get_player_health() -> Array:
	return config.get_value(
		"player",
		"hp",
		DEFAULT_HP
	)

func save_player_items(items: Array) -> void:
	config.set_value(
		"player",
		"items",
		items
	)

func get_player_items() -> Array:
	return config.get_value(
		"player",
		"items",
		[]
	)

func unlock_item(item_id: int) -> void:
	var unlocked := get_unlocked_items()

	if unlocked.has(item_id):
		return

	unlocked.append(item_id)

	config.set_value(
		"player",
		"unlocked_items",
		unlocked
	)

	pending_unlocks.append(item_id)

func has_unlocked_item(item_id: int) -> bool:
	return get_unlocked_items().has(item_id)

func get_unlocked_items() -> Array:
	return config.get_value(
		"player",
		"unlocked_items",
		DEFAULT_UNLOCKED_ITEMS
	)

func clear_game_state() -> void:
	config.erase_section("map")

	config.set_value("player", "hp", DEFAULT_HP)
	config.set_value("player", "items", [])
	config.set_value("player", "coins", 0)
	
	coins = 0

	card_to_view = {
		"name": ""
	}

func save_map_state(current_position: Array, visited_nodes: Array, seed: int, layer: int) -> void:
	config.set_value("map", "current_pos", current_position)
	config.set_value("map", "visited_nodes", visited_nodes)
	config.set_value("map", "seed", seed)
	config.set_value("map", "layer", layer)
	_save()

func get_map_seed() -> int:
	return config.get_value("map", "seed", -1)

func get_map_current_pos() -> Array:
	return config.get_value("map", "current_pos", [])

func get_map_current_layer() -> Array:
	return config.get_value("map", "layer", 0)

func get_map_visited_nodes() -> Array:
	return config.get_value("map", "visited_nodes", [])
