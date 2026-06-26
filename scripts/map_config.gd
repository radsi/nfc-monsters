@tool
class_name MapConfig
extends Resource

@export var start_scene: PackedScene
@export var seed: int = 0
@export_range(3, 15) var columns: int = 7
@export_range(2, 15) var rows: int = 3
@export var horizontal_separation: float = 200.0
@export var vertical_separation: float = 150.0
@export_range(0.0, 1.0, 0.05) var double_connection_chance: float = 0.4
@export var node_scene: PackedScene
@export var encounter_types: Dictionary = {
	"combat":  55,
	"event":   30,
	"shop":     5,
	"rest":     5,
	"boss":     5,
}
@export var line_color: Color = Color(1, 1, 1, 0.6)
@export var line_width: float = 4.0
@export var type_rules: Dictionary = {
	"combat": {"max_consecutive": 5, "cooldown": 1},
	"event":  {"max_consecutive": 2,   "cooldown": 3},
	"shop":   {"max_consecutive": 1,   "cooldown": 5},
	"rest":   {"max_consecutive": 1,   "cooldown": 8},
}
