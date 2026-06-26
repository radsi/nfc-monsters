extends Control

@onready var GameController = $".."
@onready var NodesContainer: Control = $OldPaperPiece/Container

var dragging := false
var velocity := 0.0
var last_y := 0.0
var friction := 12.0

var min_y := 0
var max_y := 1200

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
