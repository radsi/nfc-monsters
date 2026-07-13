extends EventData

func custom_event_choose(option, caller) -> void:
	if option == "NO":
		return

	if not caller.is_condition_satisfied():
		return
	
	Gamemanager.unlock_spell("SpellGamble")

	if caller.rng.randf() < 0.01:
		var _ItemsManager: ItemsManager = caller._ItemsManager

		var unlocked_items = Gamemanager.get_unlocked_items()
		var item_pool: Array[ItemData] = []

		for item_id in unlocked_items:
			var item: ItemData = _ItemsManager.items.get(item_id)

			if item == null:
				continue

			if item.type == ItemData.ItemType.Secret:
				continue

			if item.unique and _ItemsManager.get_current_items().any(
				func(e: ItemDataButton):
					return e.item_data and e.item_data.id == item.id
			):
				continue

			item_pool.append(item)

		if not item_pool.is_empty():
			item_pool.sort_custom(func(a, b): return a.id < b.id)

			var selected_item = item_pool[caller.rng.randi_range(0, item_pool.size() - 1)]
			items_data.append(selected_item)
			YesResponse = "You found %s!" % selected_item.name
	else:
		var coins = caller.rng.randi_range(5, 100)
		Gamemanager.add_coins(coins)
		YesResponse = "You found %d coins!" % coins
