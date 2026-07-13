extends EventData

@export var rare_item_pool_ids: Array[ItemData] = []
@export var common_item_pool_ids: Array[ItemData] = []

func custom_event_script(caller) -> void:
	var _ItemsManager: ItemsManager = caller._ItemsManager
	var _GameController: GameController = caller._GameController

	var rng := RandomNumberGenerator.new()
	rng.seed = _GameController.current_hash

	var selected_pool = rare_item_pool_ids if rng.randf() < 0.15 else common_item_pool_ids

	var item_pool: Array[ItemData] = []

	for item in selected_pool:
		var p_item: ItemData = _ItemsManager.items.get(item.id)

		if p_item == null:
			continue

		if p_item.unique and _ItemsManager.get_current_items().any(
			func(e: ItemDataButton):
				return e.item_data and e.item_data.id == p_item.id
		):
			continue

		item_pool.append(p_item)

	if item_pool.is_empty():
		return

	item_pool.sort_custom(func(a, b): return a.id < b.id)

	var selected_item := item_pool[rng.randi_range(0, item_pool.size() - 1)]
	
	if selected_pool == rare_item_pool_ids:
		YesSprite = selected_item.icon

	items_data.append(selected_item)
	force_condition_satisfied = true
	YesResponse = selected_item.description
