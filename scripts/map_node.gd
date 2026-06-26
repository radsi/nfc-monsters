class_name MapNode
extends Area2D

signal node_pressed(col: int, row: int)

var GameController: Control

@export var type: String = "combat"
@export var col: int = 0
@export var row: int = 0

@export var icon_combat: Texture2D
@export var icon_event: Texture2D
@export var icon_shop: Texture2D
@export var icon_rest: Texture2D
@export var icon_boss: Texture2D

var available: bool = false
var visited: bool = false
var locked: bool = true
var disabled: bool = false

@onready var icon = $Icon
@onready var CircleTexture: TextureRect = $Icon2

func _ready() -> void:
	GameController = get_tree().current_scene
	input_event.connect(_on_input)
	_update_visuals()
	CircleTexture.material = load("res://scripts/shaders/draw clock.tres").duplicate()

func setup(p_col: int, p_row: int, p_type: String) -> void:
	col = p_col
	row = p_row
	type = p_type
	_update_visuals()

func _on_input(viewport, event, shape_idx):
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed and disabled == false and not GameController.doin_animation:
		node_pressed.emit(col, row)

func set_available(value: bool) -> void:

	if visited:
		return
	available = value
	locked = not value
	disabled = not value
	if available:
		modulate = Color(0, 0, 0, 1)
	else:
		modulate = Color(0, 0, 0, 0.25)

func set_current() -> void:
	visited = true
	disabled = true
	modulate = Color(0, 0, 0, 1)
	_draw_circle()

func set_visited() -> void:
	modulate = Color(0, 0, 0, 0.25)

func _draw_circle() -> void:
	create_tween().tween_method(
		func(value): CircleTexture.material.set_shader_parameter("progress", value),
		0.0,
		1.0,
		1.0
	)

func _update_visuals() -> void:
	if icon:
		var textures = {
			"combat": icon_combat,
			"event": icon_event,
			"shop": icon_shop,
			"rest": icon_rest,
			"boss": icon_boss,
		}

		if textures.has(type) and textures[type] != null:
			icon.texture = textures[type]
