extends Node
class_name ItemsManager

signal ItemAdded
signal ItemRemoved

var items: Dictionary = {}

@onready var _GameController = $"../../../../.."
@onready var Shop = $"../../../../../Map/OldPaperPiece/Menus/shop"

func _init() -> void:
	var dir = DirAccess.open("res://prefabs/items")
	if dir == null:
		return
	
	for file in dir.get_files():
		if file.ends_with(".tres"):
			var item: ItemData = load("res://prefabs/items/" + file)
			items[item.id] = item

func _ready() -> void:
	
	await get_tree().process_frame
	
	var arr = Gamemanager.get_player_items()
	var children = get_children()

	for i in range(children.size()):
		if i < arr.size():
			var data: ItemData = items.get(arr[i])
			if data:
				children[i].show()
				children[i].icon = data.icon
				children[i].item_data = data.duplicate()
				children[i].tooltip_text = data.description
				_GameController.apply_item_effect(data)
				children[i].material.set_shader_parameter("dissolve_value", 1)
		else:
			children[i].material.set_shader_parameter("dissolve_value", 0)
			children[i].hide()
	
	Shop.item_bought.connect(func(item):add_item(item))

func add_item(item: ItemData):
	if not items.has(item.id):
		return

	var target: ItemDataButton = null

	for child: ItemDataButton in get_children():
		if child.visible == false:
			target = child
			break

	if not target:
		var last: ItemDataButton = get_child(get_child_count() - 1)
		target = last.duplicate()
		add_child(target)

	target.icon = item.icon
	target.item_data = item.duplicate()
	target.tooltip_text = item.description
	target.show()

	var tween = create_tween()
	tween.tween_method(
		func(value: float): target.material.set_shader_parameter("dissolve_value", value),
		0.0, 1.0, 2.0
	)

	tween.finished.connect(func(): ItemAdded.emit())

	_GameController.apply_item_effect(items.get(item.id))

	var arr = []
	for _item: ItemDataButton in get_children():
		if not _item.item_data:
			continue
		arr.append(_item.item_data.id)

	Gamemanager.save_player_items(arr)
	
	await get_tree().process_frame

	var scroll := get_parent() as ScrollContainer
	scroll.ensure_control_visible(target)

func remove_item(item: ItemData):
	var inv_item: ItemDataButton = null

	for child: ItemDataButton in get_children():
		if child.item_data and child.item_data.id == item.id:
			inv_item = child
			break

	if inv_item == null:
		return

	_GameController.apply_item_effect(items[item.id], true)

	var tween = create_tween()
	tween.tween_method(
		func(value: float):
			inv_item.material.set_shader_parameter("dissolve_value", value),
		1.0,
		0.0,
		2.0
	)

	await tween.finished

	inv_item.hide()
	inv_item.icon = null
	inv_item.tooltip_text = ""
	inv_item.item_data = null

	var arr := []
	for _item: ItemDataButton in get_children():
		if _item.item_data:
			arr.append(_item.item_data.id)

	Gamemanager.save_player_items(arr)

	ItemRemoved.emit()

func get_current_items():
	var result: Array[ItemDataButton] = []
	for child in get_children():
		if child.item_data != null:
			result.append(child)
	return result
