extends Node

@export var config: MapConfig
@onready var nodes_container = $Nodes
@onready var lines_container = $Lines
@onready var Menus = $"../Menus"
@onready var _GameController = $"../../.."
@onready var PaperBG = $".."

var map_data: Dictionary = {}
var current_pos: Array = []
var instantiated_nodes: Dictionary = {}
var visited_nodes: Array = []

var connection_lines: Dictionary = {}

func _ready() -> void:
	generate_map()
	_load_map_state()

func _load_map_state() -> void:
	var saved_pos = Gamemanager.get_map_current_pos()
	var saved_visited = Gamemanager.get_map_visited_nodes()

	if saved_pos.is_empty():
		return

	current_pos = saved_pos
	visited_nodes = saved_visited

	for key in instantiated_nodes:
		var node = instantiated_nodes[key]

		if visited_nodes.has(key):
			node.set_visited()

		node.set_available(false)

	if instantiated_nodes.has(current_pos):
		instantiated_nodes[current_pos].set_current()

	_redraw_full_path()

	_mark_next_available(current_pos[0], current_pos[1])

func _redraw_full_path() -> void:
	var ordered: Array = visited_nodes.duplicate()

	var start_key = [-1, config.rows]
	if not ordered.has(start_key):
		ordered.append(start_key)

	if not ordered.has(current_pos):
		ordered.append(current_pos)

	ordered.sort_custom(func(a, b):
		if a[0] == -1:
			return true
		if b[0] == -1:
			return false
		return a[1] < b[1]
	)

	for i in range(ordered.size() - 1):
		var from_key = ordered[i]
		var to_key = ordered[i + 1]

		if not instantiated_nodes.has(from_key) or not instantiated_nodes.has(to_key):
			continue

		_draw_instant_line(
			instantiated_nodes[from_key].position,
			instantiated_nodes[to_key].position
		)

func _draw_instant_line(from: Vector2, to: Vector2) -> void:
	var radius = 35.0
	var direction = (to - from).normalized()

	var start = from + direction * radius
	var end = to - direction * radius

	var line = Line2D.new()
	line.width = config.line_width
	line.default_color = config.line_color

	line.add_point(start)
	line.add_point(end)

	lines_container.add_child(line)

func generate_map() -> void:
	if not config:
		push_error("Map: missing MapConfig in inspector")
		return

	var saved_seed = Gamemanager.get_map_seed()

	if saved_seed != -1:
		config.seed = saved_seed
	else:
		config.seed = randi() % 1000
		Gamemanager.save_map_state([], [], config.seed, _GameController.layer)

	map_data = MapGenerator.generate(config)
	_clear()
	_instantiate_nodes()
	_draw_lines()
	_instantiate_start_node()

func reset_map_for_new_floor(seed: int = -1) -> void:
	if seed == -1:
		seed = randi()

	current_pos.clear()
	visited_nodes.clear()
	connection_lines.clear()

	config.seed = seed

	Gamemanager.save_map_state([], [], seed, _GameController.layer+1)

	generate_map()

func _clear() -> void:
	for child in nodes_container.get_children():
		child.queue_free()

	for child in lines_container.get_children():
		child.queue_free()

	instantiated_nodes.clear()
	connection_lines.clear()

func _instantiate_nodes() -> void:
	for key in map_data.keys():
		var col: int = key[0]
		var row: int = key[1]
		var data = map_data[key]
		var node: MapNode = config.node_scene.instantiate()
		node.setup(col, row, data["type"])
		node.position = _screen_position(col, row)
		node.node_pressed.connect(_on_node_pressed)
		nodes_container.add_child(node)
		instantiated_nodes[[col, row]] = node

		var has_outgoing = not data["connections"].is_empty()
		var is_last_row = row == config.rows - 1
		node.visible = data["has_incoming"] and (has_outgoing or is_last_row)

func _instantiate_start_node() -> void:
	if not config.start_scene:
		push_error("Map: missing start_scene in MapConfig")
		return
	var start: MapNode = config.start_scene.instantiate()
	var center_col = config.columns / 2
	start.col = -1
	start.row = config.rows
	start.position = Vector2(center_col * config.horizontal_separation, config.vertical_separation)
	start.set_available(true)
	start.node_pressed.connect(_on_node_pressed)
	nodes_container.add_child(start)
	instantiated_nodes[[-1, config.rows]] = start
	_draw_start_lines()
	current_pos = [start.col, start.row]

func _draw_start_lines() -> void:
	var start_pos = instantiated_nodes[[-1, config.rows]].position
	for col in range(config.columns):
		if not instantiated_nodes.has([col, 0]):
			continue
		if not instantiated_nodes[[col, 0]].visible:
			continue
		_draw_dashed_line(start_pos, _screen_position(col, 0), [-1, config.rows], [col, 0])

func _draw_dashed_line(from: Vector2, to: Vector2, key_from: Array, key_to: Array) -> void:
	var radius = 35.0

	var direction = (to - from).normalized()
	var total_length = from.distance_to(to)

	var start = from + direction * radius
	var end = to - direction * radius

	total_length = start.distance_to(end)

	var dash_length = 10.0
	var gap_length = 8.0
	var current = 0.0
	var drawing = true

	while current < total_length:
		if drawing:
			var dash_end = min(current + dash_length, total_length)

			var line = Line2D.new()
			line.width = config.line_width
			line.default_color = config.line_color

			line.add_point(start + direction * current)
			line.add_point(start + direction * dash_end)

			lines_container.add_child(line)
			
			var key = [key_from, key_to]

			if not connection_lines.has(key):
				connection_lines[key] = []

			connection_lines[key].append(line)

			current += dash_length
		else:
			current += gap_length

		drawing = not drawing

func _draw_full_line(from: Vector2, to: Vector2) -> void:
	var radius = 35.0
	var direction = (to - from).normalized()

	var start = from + direction * radius
	var end = to - direction * radius

	var line = Line2D.new()
	line.width = config.line_width
	line.default_color = config.line_color

	line.add_point(start)
	line.add_point(start)

	lines_container.add_child(line)

	var duration = 0.5
	var elapsed = 0.0

	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

		var t = clamp(elapsed / duration, 0.0, 1.0)
		var current_pos = start.lerp(end, t)

		line.set_point_position(1, current_pos)

	line.set_point_position(1, end)

func _draw_lines() -> void:
	for key in map_data.keys():
		var col: int = key[0]
		var row: int = key[1]
		if instantiated_nodes.has(key) and not instantiated_nodes[key].visible:
			continue
		for dest_col in map_data[key]["connections"]:
			var dest_key = [dest_col, row + 1]
			if instantiated_nodes.has(dest_key) and not instantiated_nodes[dest_key].visible:
				continue
			_draw_dashed_line(
				_screen_position(col, row),
				_screen_position(dest_col, row + 1),
				[col, row],
				[dest_col, row + 1]
			)

func _mark_next_available(col: int, row: int) -> void:
	if col == -1:
		for c in range(config.columns):
			var key = [c, 0]
			if instantiated_nodes.has(key) and instantiated_nodes[key].visible:
				instantiated_nodes[key].set_available(true)
		for c in range(config.columns):
			var key = [c, 0]
			if instantiated_nodes.has(key) and instantiated_nodes[key].visible:
				_mark_reachable_from(c, 0)
		return
	if not map_data.has([col, row]):
		return
	for dest_col in map_data[[col, row]]["connections"]:
		var key = [dest_col, row + 1]
		if instantiated_nodes.has(key) and instantiated_nodes[key].visible:
			instantiated_nodes[key].set_available(true)
			_mark_reachable_from(dest_col, row + 1)

func _mark_reachable_from(col: int, row: int) -> void:
	if not map_data.has([col, row]):
		return
	for dest_col in map_data[[col, row]]["connections"]:
		var key = [dest_col, row + 1]
		if instantiated_nodes.has(key) and instantiated_nodes[key].visible:
			if not instantiated_nodes[key].available:
				instantiated_nodes[key].set_available(true)
				_mark_reachable_from(dest_col, row + 1)

func _on_node_pressed(col: int, row: int) -> void:
	var prev_col = current_pos[0]
	var prev_row = current_pos[1]
	if not current_pos.is_empty():
		if prev_col == -1:
			if row != 0:
				return
		else:
			if not map_data.has([prev_col, prev_row]):
				return

			var connections = map_data[[prev_col, prev_row]]["connections"]

			if row != prev_row + 1 or not connections.has(col):
				return

		var is_last_row = current_pos[1] == config.rows - 1
		if not is_last_row:
			instantiated_nodes[current_pos].set_visited()
			if not visited_nodes.has(current_pos):
				visited_nodes.append(current_pos)

	current_pos = [col, row]

	instantiated_nodes[current_pos].set_current()

	for key in instantiated_nodes:
		instantiated_nodes[key].set_available(false)
	_mark_next_available(col, row)

	if col == -1:
		return
	var type = map_data[[col, row]]["type"]
	
	var seed_string = str(Gamemanager.get_map_seed()) + ":" + str(current_pos) + ":" + type
	_GameController.current_hash = hash(seed_string)
	
	"""
	var key = [[prev_col, prev_row], [col, row]]
	var reverse_key = [[col, row], [prev_col, prev_row]]

	if connection_lines.has(key):
		for line in connection_lines[key]:
			line.queue_free()
		connection_lines.erase(key)
	elif connection_lines.has(reverse_key):
		for line in connection_lines[reverse_key]:
			line.queue_free()
		connection_lines.erase(reverse_key)
	"""
	var from_pos = instantiated_nodes[[-1, config.rows]].position if prev_col == -1 else _screen_position(prev_col, prev_row)

	_draw_full_line(from_pos, _screen_position(col, row))
	
	var is_boss = false
	
	if type == "boss": 
		type = "combat"
		is_boss = true
	
	var node = Menus.find_child(type);
	if node:
		if is_boss: node.is_boss = true
		await get_tree().create_timer(0.5).timeout
		node.show_on_paper()
	
	_GameController.last_map_pos = PaperBG.global_position
	
	print("Entering node: ", type, " at (", col, ", ", row, ")")

func _screen_position(col: int, row: int) -> Vector2:
	return Vector2(
		col * config.horizontal_separation,
		-(row * config.vertical_separation)
	)

func _mark_column_available(col: int) -> void:
	for row in range(config.rows):
		var key = [col, row]
		if instantiated_nodes.has(key) and instantiated_nodes[key].visible:
			instantiated_nodes[key].set_available(true)
