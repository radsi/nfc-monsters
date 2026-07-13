extends EventData

func custom_event_script(caller) -> void:
	var _ItemsManager: ItemsManager = caller._ItemsManager
	var _GameController: GameController = caller._GameController
	var current_items = _ItemsManager.get_current_items()

	var item_pool: Array[ItemData] = []

	for p_item: ItemData in _ItemsManager.items.values():
		if p_item.type == ItemData.ItemType.Secret:
			continue

		if (id == "cardboard" and p_item.type != ItemData.ItemType.Cardboard) or (id != "cardboard" and p_item.type == ItemData.ItemType.Cardboard):
			continue

		if p_item.unique and current_items.any(
			func(e: ItemDataButton):
				return e.item_data and e.item_data.id == p_item.id
		):
			continue

		item_pool.append(p_item)

	if item_pool.is_empty():
		return

	item_pool.sort_custom(func(a: ItemData, b: ItemData): return a.id < b.id)

	caller.rng.seed = caller._GameController.current_hash

	var selected_item: ItemData = item_pool[caller.rng.randi_range(0, item_pool.size() - 1)]

	items_data.append(selected_item)
	FalseConditionResponse = selected_item.description
	$Label/MarginContainer/TextureRect2.texture = selected_item.icon
