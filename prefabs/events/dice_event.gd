extends EventData

func custom_event_script(caller) -> void:
	var _ItemsManager: ItemsManager = caller._ItemsManager
	var _GameController: GameController = caller._GameController
	
	var current_items = _ItemsManager.get_current_items()
	var unlocked_items = Gamemanager.get_unlocked_items()

	var rng := RandomNumberGenerator.new()
	rng.seed = _GameController.current_hash

	for current_item in current_items:
		if current_item.item_data == null:
			continue

		var item_pool: Array[ItemData] = []

		for item_id in unlocked_items:
			var p_item: ItemData = _ItemsManager.items.get(item_id)

			if p_item == null:
				continue

			if p_item.unique and _ItemsManager.get_current_items().any(
				func(e: ItemDataButton):
					return e != current_item and e.item_data and e.item_data.id == p_item.id
			):
				continue

			item_pool.append(p_item)

		if item_pool.is_empty():
			continue

		item_pool.sort_custom(func(a, b): return a.id < b.id)

		var selected_item = item_pool[rng.randi_range(0, item_pool.size() - 1)]

		items_data.append(current_item.item_data)
		items_data.append(selected_item)
