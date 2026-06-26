class_name MapNodeStart
extends MapNode

@export var start_icon: Texture2D

func _ready() -> void:
	type = "start"
	col = -1
	if icon and start_icon:
		icon.texture = start_icon
	set_available(true)
