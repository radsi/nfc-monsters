extends MapMenu

signal item_bought

@onready var ItemsContainer: HBoxContainer = $TextureRect2/hbo
@export var _ItemsManager: ItemsManager

var bought_items := []
var items_pick: Array[ItemData]
var do_discount = true

func _ready() -> void:
	super._ready()
	
	for child in ItemsContainer.get_children():
		var area = child.get_child(1)
		
		if area:
			area.input_event.connect(func(viewport, event, shape_idx):
				_on_input(area, event, shape_idx)
			)
	
	showing_mid_animation.connect(func():
		if items_pick.is_empty(): roll_items()
		)
	
	shown_on_paper.connect(func():
		NfcUsage.connect("nfc_detected", Callable(self, "_on_nfc_detected"))
	)
	
	hidden_from_paper.connect(func():
		roll_items()
		bought_items.clear()
		do_discount = true
		NfcUsage.disconnect("nfc_detected", Callable(self, "_on_nfc_detected"))
	)
	
	await get_tree().process_frame

func _on_nfc_detected(tag_id: String) -> void:
	var data = JSON.parse_string(tag_id)
	if data == null:
		return
	
	if data.get("name") == "SpellDiscount" and items_pick != null and do_discount:
		do_discount = false
		_play_sfx(2)
		var discount = max(0.0, 1.0 - (0.25 + data.get("level") * 0.0625))
		for i in range(items_pick.size()):
			var child = ItemsContainer.get_child(i)
			child.item_data.price = int(child.item_data.price * discount)
			child.find_child("money").text = str(child.item_data.price)

func _on_input(area: Area2D, event, shape_idx):
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		var item = area.get_parent()
		buy_item(item)

func buy_item(item: ItemDataButton):
	if Gamemanager.coins < item.item_data.price or bought_items.has(item):
		return
	
	_play_sfx(1)
	bought_items.append(item)
	item_bought.emit(item.item_data)
	Gamemanager.add_coins(-item.item_data.price)
	_GameController._update_coins()
	
	var tween = create_tween()
	
	tween.tween_method(
			func(value: float): item.material.set_shader_parameter("dissolve_value", value),
			1.0, 0.0, 2.0
		)
	
	if item.item_data.id == 1:
		Gamemanager.unlock_spell("SpellDiscount")
	if item.item_data.id == 5:
		Gamemanager.unlock_item(7)
	if item.item_data.id == 7:
		Gamemanager.unlock_item(3)
	
	Gamemanager.unlock_item(1)

func roll_items() -> void:
	items_pick = pick_n_weighted(4, _GameController.current_hash)

	for n in 4:
		var child: ItemDataButton = ItemsContainer.get_child(n)
		var mod_item = items_pick[n].duplicate()

		if _GameController.shop_price != 0:
			mod_item.price = int(mod_item.price * _GameController.shop_price / 100.0)

		child.item_data = mod_item
		child.icon = mod_item.icon
		child.find_child("Label").text = mod_item.description
		child.find_child("money").text = str(mod_item.price)

		if child.material:
			child.material.set_shader_parameter("dissolve_value", 1.0)

func pick_n_weighted(n: int, hash) -> Array[ItemData]:
	
	var rng = RandomNumberGenerator.new()
	rng.seed = hash
	
	var pool: Array[ItemData] = []

	var current_items = _ItemsManager.get_current_items()

	for item: ItemData in _ItemsManager.items.values():
		if item.unique:
			var already_exists = current_items.any(
				func(e: ItemDataButton): return e.item_data == item
			)

			if already_exists or not Gamemanager.has_unlocked_item(item.id):
				continue

		if item.type == 2 or item.event_only or (item.min_layer > _GameController.layer and item.min_layer != -1):
			continue

		pool.append(item)

	var result: Array[ItemData] = []

	for i in range(n):
		var total := 0.0

		for item in pool:
			total += item.weight

		var r := rng.randf() * total

		for j in range(pool.size()):
			r -= pool[j].weight

			if r <= 0:
				result.append(pool[j].duplicate(true))
				pool.remove_at(j)
				break

	return result
