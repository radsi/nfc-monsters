extends EventData

func custom_event_script(caller) -> void:
	var _ItemsManager: ItemsManager = caller._ItemsManager

	var unlocked_items = Gamemanager.get_unlocked_items()
	var item_pool: Array[ItemData] = []

	for item_id in unlocked_items:
		var p_item: ItemData = _ItemsManager.items.get(item_id)

		if p_item == null:
			continue

		if p_item.type == ItemData.ItemType.Secret or (id == "cardboard" and p_item.type != ItemData.ItemType.Cardboard):
			continue

		if p_item.unique and _ItemsManager.get_current_items().any(
			func(e: ItemDataButton):
				return e.item_data and e.item_data.id == p_item.id
		):
			continue

		item_pool.append(p_item)

	if not item_pool.is_empty():
		item_pool.sort_custom(func(a, b): return a.id < b.id)

		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(Gamemanager.get_map_seed()) + ":" + str(get_parent().NodesContainer) + ":chest")

		var selected_item = item_pool[rng.randi_range(0, item_pool.size() - 1)]

		items_data.append(selected_item)
		GeneralLabel.text = selected_item.description
