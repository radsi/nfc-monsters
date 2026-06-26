class_name MapGenerator
extends Node

static func generate(config: MapConfig) -> Dictionary:
	var rng = RandomNumberGenerator.new()
	rng.seed = config.seed

	var map: Dictionary = {}
	var boss_col = randi() % config.columns
	var last_row = config.rows - 1
	var last_normal_row = config.rows - 2

	var history := {}

	for col in range(config.columns):
		history[col] = {
			"last_type": "",
			"consecutive": 0,
			"cooldowns": {}
		}

	for col in range(config.columns):
		for row in range(config.rows):
			if row == last_row:
				continue

			var state = history[col]

			var type = _pick_type_with_rules(
				config.encounter_types,
				config.type_rules,
				rng,
				state,
				row,
				0
			)

			_update_state(state, type, config.type_rules)

			map[[col, row]] = {
				"type": type,
				"connections": [],
				"has_incoming": false
			}

	map[[boss_col, last_row]] = {
		"type": "boss",
		"connections": [],
		"has_incoming": true
	}

	var current_cols = []

	for col in range(config.columns):
		current_cols.append(col)

	for row in range(config.rows - 2):
		var next_cols = []
		var shops_this_row = 0

		for col in current_cols:
			var candidates = []

			candidates.append(col)

			if col - 1 >= 0:
				candidates.append(col - 1)
			if col + 1 < config.columns:
				candidates.append(col + 1)

			if candidates.is_empty():
				continue

			var dest_col = candidates[rng.randi_range(0, candidates.size() - 1)]

			if not map[[col, row]]["connections"].has(dest_col):
				map[[col, row]]["connections"].append(dest_col)

			map[[dest_col, row + 1]]["has_incoming"] = true
			next_cols.append(dest_col)

		current_cols = next_cols

	var used_cols = []
	for col in range(config.columns):
		var node_key = [col, last_normal_row]
		if map.has(node_key):
			if not map[node_key]["connections"].has(boss_col):
				map[node_key]["connections"].append(boss_col)
				map[[boss_col, last_row]]["has_incoming"] = true

	for col in used_cols:
		if not map[[col, last_normal_row]]["connections"].has(boss_col):
			map[[col, last_normal_row]]["connections"].append(boss_col)

	for col in range(config.columns):
		if map.has([col, 0]):
			map[[col, 0]]["has_incoming"] = true

	for col in range(config.columns):
		if col != boss_col:
			map.erase([col, last_row])

	return map


static func _pick_type_with_rules(types: Dictionary, rules: Dictionary, rng: RandomNumberGenerator, state: Dictionary, row: int, shops_this_row: int) -> String:
	var adjusted_types = types.duplicate()

	if shops_this_row > 0 and adjusted_types.has("shop"):
		adjusted_types["shop"] = int(adjusted_types["shop"] * 0.2)

	var valid_types := []

	for type in adjusted_types.keys():
		if type == "boss":
			continue

		var rule = rules.get(type, {"max_consecutive": 999, "cooldown": 0})
		var cooldowns = state.get("cooldowns", {})

		if cooldowns.has(type) and cooldowns[type] > 0:
			continue

		if state.get("last_type") == type and state.get("consecutive") >= rule["max_consecutive"]:
			continue

		valid_types.append(type)

	if valid_types.is_empty():
		valid_types = ["combat"]

	var total = 0
	for t in valid_types:
		total += adjusted_types[t]

	var roll = rng.randi_range(0, total - 1)
	var acc = 0

	for t in valid_types:
		acc += adjusted_types[t]
		if roll < acc:
			return t

	return valid_types[0]


static func _update_state(state: Dictionary, type: String, rules: Dictionary):
	if not state.has("cooldowns"):
		state["cooldowns"] = {}

	var cooldowns = state["cooldowns"]

	if state.get("last_type", "") == type:
		state["consecutive"] = state.get("consecutive", 0) + 1
	else:
		state["last_type"] = type
		state["consecutive"] = 1

	var keys_to_remove = []

	for t in cooldowns.keys():
		cooldowns[t] -= 1
		if cooldowns[t] <= 0:
			keys_to_remove.append(t)

	for t in keys_to_remove:
		cooldowns.erase(t)

	var rule = rules.get(type, {"cooldown": 0})

	if rule["cooldown"] > 0:
		cooldowns[type] = rule["cooldown"]
