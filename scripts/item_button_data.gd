extends Button
class_name ItemDataButton

@export var item_data: ItemData

func _ready() -> void:
	material = material.duplicate()
