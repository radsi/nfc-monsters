extends Control

@onready var GameController = $".."
@onready var NodesContainer: Control = $OldPaperPiece/Container
@onready var GoBackButtons := [$"../ConfirmBack/MarginContainer2/HBoxContainer/NO/Area2D", $"../ConfirmBack/MarginContainer2/HBoxContainer/YES/Area2D"]
@onready var BackConfirmPanel = $"../ConfirmBack"

var dragging := false
var velocity := 0.0
var last_y := 0.0
var friction := 12.0

var min_y := 0
var max_y := 1200

func _ready() -> void:
	GoBackButtons[1].input_event.connect(func(_viewport, event, _shape_idx):
		_on_input(GoBackButtons[1], event)
	)

	GoBackButtons[0].input_event.connect(func(_viewport, event, _shape_idx):
		_on_input(GoBackButtons[0], event)
	)

func _on_input(area: Area2D, event):
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		if area.name == "YES": Gamemanager.change_scene("res://scenes/main_menu.tscn")
		else: BackConfirmPanel.hide(); get_parent().ignore_input = false

func _input(event):
	if GameController.doin_animation or (event is InputEventMouseButton and event.position.x > 800) or NodesContainer.visible == false: return
	
	if event is InputEventScreenTouch:
		dragging = event.pressed
		if dragging:
			last_y = event.position.y

	if event is InputEventScreenDrag and dragging:
		var delta_y = event.position.y - last_y
		position.y = clamp(position.y + delta_y, min_y, max_y)
		velocity = delta_y / get_process_delta_time()
		last_y = event.position.y

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging:
				last_y = event.position.y

	if event is InputEventMouseMotion and dragging:
		var delta_y = event.position.y - last_y
		position.y = clamp(position.y + delta_y, min_y, max_y)
		velocity = delta_y / get_process_delta_time()
		last_y = event.position.y

func _process(delta):
	if not dragging and not GameController.doin_animation:
		position.y += velocity * delta
		velocity = lerp(velocity, 0.0, friction * delta)

		position.y = clamp(position.y, min_y, max_y)
